#!/usr/bin/env perl
use Test2::Bundle::Extended;
use Log::Any::Adapter 'TAP';
use strictures 2;

use Test::Consul;

my $consul = Test::Consul->new(
    binary => 'foooooooobaaaaaaaar',
);

ok(
    (! $consul->is_binary_available() ),
    'missing binary detected',
);

$consul = Test::Consul->new(
    binary => 'echo',
);

ok(
    $consul->is_binary_available(),
    'available binary detected',
);

done_testing;
