requires 'Time::HiRes';
requires 'Unix::Getrusage';
requires 'Plack' => 1.0037;

on test => sub {
   requires 'Test::More' => 0.94;
   requires 'HTTP::Message' => 6.10;
};
