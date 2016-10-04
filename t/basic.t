#!/usr/bin/env perl

use strict;
use warnings;

use Plack::Test;
use Plack::Builder;
use Scalar::Util 'looks_like_number';
use Test::More;
use Time::HiRes qw(gettimeofday tv_interval sleep);
use HTTP::Request::Common;

my $last_env;

sub _num {
   my ($val, $message) = @_;

   ok(looks_like_number($val), $message)
      or diag "Expected number, got $val";
}

subtest no_measure_children => sub {
   my $app = builder {
      enable '+A::TestMW';
      enable 'ProcessTimes';

      sub { [200, [content_type => 'text/plain'], ['hello!']] };
   };

   test_psgi $app, sub {
      my $cb = shift;

      my $res = $cb->(GET '/');

      my $e = $A::TestMW::ENV;
      _num($e->{'pt.real'},     'Real measured');
      _num($e->{'pt.cpu-user'}, 'CPU-User measured');
      _num($e->{'pt.cpu-sys'},  'CPU-Sys measured');
      is(  $e->{'pt.cpu-cuser'},'-',  'CPU-CUser not measured');
      is(  $e->{'pt.cpu-csys'}, '-',  'CPU-CSys not measured');
   };
};

subtest measure_children => sub {
   my $app = builder {
      enable '+A::TestMW';
      enable 'ProcessTimes', measure_children => 1;

      sub { [200, [content_type => 'text/plain'], ['hello!']] };
   };

   test_psgi $app, sub {
      my $cb = shift;

      my $res = $cb->(GET '/');

      my $e = $A::TestMW::ENV;
      _num($e->{'pt.real'},      'Real measured');
      _num($e->{'pt.cpu-user'},  'CPU-User measured');
      _num($e->{'pt.cpu-sys'},   'CPU-Sys measured');
      _num($e->{'pt.cpu-cuser'}, 'CPU-CUser measured');
      _num($e->{'pt.cpu-csys'},  'CPU-CSys measured');
   };
};

my $parent = $$;
subtest 'actual numbers' => sub {
   my $app = builder {
      enable '+A::TestMW';
      enable 'ProcessTimes', measure_children => 1;

      sub {
         sleep 0.25;

         my $x = rand();
         my $t0 = [gettimeofday];

         fork for 1..3;

         while (tv_interval($t0) < 0.25) {
            $x *= rand();
            mkdir $x;
            rmdir $x;
         }
         [200, [content_type => 'text/plain'], ['hello!']]
      };
   };

   test_psgi $app, sub {
      my $cb = shift;

      my $res = $cb->(GET '/');

      exit unless $$ == $parent;

      note( $res->headers->as_string);

      my $e = $A::TestMW::ENV;
      _num($e->{'pt.real'},      'Real measured');
      _num($e->{'pt.cpu-user'},  'CPU-User measured');
      _num($e->{'pt.cpu-sys'},   'CPU-Sys measured');
      _num($e->{'pt.cpu-cuser'}, 'CPU-CUser measured');
      _num($e->{'pt.cpu-csys'},  'CPU-CSys measured');
   };
} if $ENV{AUTHOR_TESTING};

done_testing;

BEGIN {
package A::TestMW;

$INC{'A/TestMW.pm'} = __FILE__;

use base 'Plack::Middleware';

our $ENV;

sub call {
   my ($self, $env) = @_;

   $ENV = $env;

   $self->app->( $env );
}
}
