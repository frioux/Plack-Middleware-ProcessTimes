#!/usr/bin/env perl

use strict;
use warnings;

use Plack::Test;
use Plack::Builder;
use Test::More;
use Time::HiRes qw(gettimeofday tv_interval sleep);
use HTTP::Request::Common;

my $num = qr/^\d+\.\d{3}$/;

subtest no_measure_children => sub {
   my $app = builder {
      enable 'ProcessTimes';

      sub { [200, [content_type => 'text/plain'], ['hello!']] };
   };

   test_psgi $app, sub {
      my $cb = shift;

      my $res = $cb->(GET '/');

      like($res->header('X-Time-Real'),     $num, 'Real measured');
      like($res->header('X-Time-CPU-User'), $num, 'CPU-User measured');
      like($res->header('X-Time-CPU-Sys'),  $num, 'CPU-Sys measured');
      is($res->header('X-Time-CPU-CUser'),  '-',  'CPU-CUser not measured');
      is($res->header('X-Time-CPU-CSys'),   '-',  'CPU-CSys not measured');
   };
};

subtest measure_children => sub {
   my $app = builder {
      enable 'ProcessTimes', measure_children => 1;

      sub { [200, [content_type => 'text/plain'], ['hello!']] };
   };

   test_psgi $app, sub {
      my $cb = shift;

      my $res = $cb->(GET '/');

      like($res->header('X-Time-Real'),      $num, 'Real measured');
      like($res->header('X-Time-CPU-User'),  $num, 'CPU-User measured');
      like($res->header('X-Time-CPU-Sys'),   $num, 'CPU-Sys measured');
      like($res->header('X-Time-CPU-CUser'), $num, 'CPU-CUser measured');
      like($res->header('X-Time-CPU-CSys'),  $num, 'CPU-CSys measured');
   };
};

my $parent = $$;
subtest 'actual numbers' => sub {
   my $app = builder {
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

      like($res->header('X-Time-Real'),      $num, 'Real measured');
      like($res->header('X-Time-CPU-User'),  $num, 'CPU-User measured');
      like($res->header('X-Time-CPU-Sys'),   $num, 'CPU-Sys measured');
      like($res->header('X-Time-CPU-CUser'), $num, 'CPU-CUser measured');
      like($res->header('X-Time-CPU-CSys'),  $num,  'CPU-CSys measured');
   };
} if $ENV{AUTHOR_TESTING};

done_testing;
