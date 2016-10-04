package Plack::Middleware::ProcessTimes;

use strict;
use warnings;

# ABSTRACT: Include process times of a request in the Plack env

use Time::HiRes qw(gettimeofday tv_interval);
use parent 'Plack::Middleware';
use Plack::Util::Accessor qw( measure_children );
use Unix::Getrusage;

sub call {
  my ($self, $env) = @_;

  my $t0 = [gettimeofday()];
  my $rusage0 = getrusage();
  my $rusagec0;
  $rusagec0 = getrusage_children()
    if $self->measure_children;

  my $res = $self->app->($env);

  return $self->response_cb($res, sub{
    my $inner = shift;

    if ($self->measure_children) {
       1 while waitpid(-1, 1) > 0;
    }

    my $new_rusage = getrusage();

    $env->{'pt.real'}     = tv_interval($t0);
    $env->{'pt.cpu-user'} = $new_rusage->{ru_utime} - $rusage0->{ru_utime};
    $env->{'pt.cpu-sys'}  = $new_rusage->{ru_stime} - $rusage0->{ru_stime};

    if ($self->measure_children) {
      my $new_rusagec = getrusage_children();
      $env->{'pt.cpu-cuser'} = $new_rusagec->{ru_utime} - $rusagec0->{ru_utime};
      $env->{'pt.cpu-csys'}  = $new_rusagec->{ru_stime} - $rusagec0->{ru_stime};
    } else {
      $env->{'pt.cpu-cuser'} = '-';
      $env->{'pt.cpu-csys'}  = '-';
    };

    return;
  });
}

1;

__END__

=pod

=head1 SYNOPSIS

 # in app.psgi
 use Plack::Builder;

 builder {
    enable 'AccessLog::Structured',
       extra_field => {
         'pt.cpu-user' => 'CPU-User-Time',
         'pt.cpu-sys'  => 'CPU-Sys-Time',
       };

    enable 'ProcessTimes';

    $app
 };

=head1 DESCRIPTION

C<Plack::Middleware::ProcessTimes> defines some environment values based on the
C<getrusage(2)> system call.  The following values are defined:

=over

=item * C<pt.real> - Actual recorded wallclock time

=item * C<pt.cpu-user>

=item * C<pt.cpu-sys>

=item * C<pt.cpu-cuser>

=item * C<pt.cpu-csys>

=back

The above are meant to be a C<perlfunc/times> like interface using C<getrusage>
for more accuracy.

=head1 CONFIGURATION

=head2 measure_children

Setting C<measure_children> to true will L<perlfunc/waitpid> for children so
that child times can be measured.  If set responses will be somewhat slower; if
not set, the headers will be set to C<->.

=head1 THANKS

This module was originally written for Apache by Randal L. Schwartz
<merlyn@stonehenge.com> for the L<ZipRecruiter|https://www.ziprecruiter.com/>
codebase.  Thanks to both Randal and ZipRecruiter for allowing me to publish
this module!

=cut

