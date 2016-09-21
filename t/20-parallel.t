#!perl

use strict;
use warnings;

use Test::Consul;

use Test::More;
use Test::Exception;
use File::Which qw(which);
use HTTP::Tiny;

my $bin = which("consul");

SKIP: {
    skip "consul not found on \$PATH", 6 unless $bin;

    my $tc1;
    lives_ok { $tc1 = Test::Consul->start } "start method returned successfully on first instance";
    ok $tc1->running, "guard thinks consul one is running";

    my $tc2;
    lives_ok { $tc2 = Test::Consul->start } "start method returned successfully on second instance";
    ok $tc2->running, "guard thinks consul two is running";
}

done_testing;
