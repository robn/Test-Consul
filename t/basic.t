#!/usr/bin/env perl
use Test2::Bundle::Extended;
use Log::Any::Adapter 'TAP';
use strictures 2;

use Test::Consul;
use Furl;

my $consul = Test::Consul->new();
$consul->skip_all_if_binary_unavailable();

ok( (! $consul->is_running() ), 'not running' );
$consul->start();
ok( $consul->is_running(), 'is running' );

my $furl = Furl->new();
my $api_url = $consul->api_v1_url();

my $res = $furl->get( "$api_url/agent/self" );

like(
    $res->decoded_content(),
    qr{DevMode},
    'basic api response looks right',
);

$consul->stop();
ok( (! $consul->is_running() ), 'not running' );

done_testing;
