package Plack::Middleware::ProcessTimes;

use strict;
use warnings;

use Time::HiRes qw(gettimeofday tv_interval);

use parent 'Plack::Middleware';

sub call {
  my ($self, $env) = @_;

  my @times = (time, times);

  my $res = $self->app->($env);

  return $self->response_cb($res, sub{
    my $inner = shift;

    ## reap any children so child CPU is correct
    # 1 while waitpid(-1, 1) > 0;
    ## when commented out:
    ## overall end-to-end times and performance are better
    ## but the child-user and child-sys times will always be 0

    ## compute delta
    @times = map { $_ - shift @times } time, times;

    my $CPU = 0;
    $CPU += $times[$_] for 1..4;
    push @times, $CPU;

    @times = map { sprintf "%.3f", $_ } @times;

    #DEBUG# warn "times: @times\n"; 	# for now

    ## make these values available to the log formatter:
    @$env{qw( HTTP_REAL HTTP_CPUUSER HTTP_CPUSYS HTTP_CPUCUSER HTTP_CPU )} = @times;

    return;
  });
}

1;

