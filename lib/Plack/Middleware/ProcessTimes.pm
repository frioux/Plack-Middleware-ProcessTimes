package Plack::Middleware::ProcessTimes;

use strict;
use warnings;

use Time::HiRes qw(gettimeofday tv_interval);

use parent 'Plack::Middleware';

sub call {
  my ($self, $env) = @_;

  my $res = $self->app->($env);

  return $self->response_cb($res, sub{
    my $inner = shift;

    return;
  });
}

1;

