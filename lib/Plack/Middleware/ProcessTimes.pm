package Plack::Middleware::ProcessTimes;

use strict;
use warnings;

# ABSTRACT: Include process times of a request in the Plack env

use Time::HiRes qw(time);
use parent 'Plack::Middleware';
use Plack::Util::Accessor qw( measure_children );

sub call {
  my ($self, $env) = @_;

  my @times = (time, times);

  my $res = $self->app->($env);

  return $self->response_cb($res, sub{
    my $inner = shift;

    if ($self->measure_children) {
       1 while waitpid(-1, 1) > 0;
    }

    @times = map { $_ - shift @times } time, times;

    my $CPU = 0;
    $CPU += $times[$_] for 1..4;
    push @times, $CPU;

    @times = map { sprintf "%.3f", $_ } @times;

    push @{$inner->[1]},
      x_time_real      => $times[0],
      x_time_cpu_user  => $times[1],
      x_time_cpu_sys   => $times[2];

    if ($self->measure_children) {
      push @{$inner->[1]},
        x_time_cpu_cuser => $times[3],
        x_time_cpu_csys  => $times[4];
    } else {
      push @{$inner->[1]},
        x_time_cpu_cuser => '-',
        x_time_cpu_csys  => '-';
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
    enable 'AccessLog::Timed',
       format => '%r %t [%{x-time-real}o %{x-time-cpu-user}o %{x-time-cpu-sys}o]';

    enable 'ProcessTimes';

    $app
 };

=head1 DESCRIPTION

C<Plack::Middleware::ProcessTimes> defines some response headers based on the
L<perlfunc/times> function.  The following times are defined:

=over

=item * C<X-Time-Real> - Actual recorded wallclock time

=item * C<X-Time-CPU-User>

=item * C<X-Time-CPU-Sys>

=item * C<X-Time-CPU-CUser>

=item * C<X-Time-CPU-CSys>

=back

Look up C<times(2)> in your system manual for what these all mean.

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

