#!/usr/bin/env perl
use FindBin;
use lib $FindBin::Bin.'/../thirdparty/lib/perl5';
use lib $FindBin::Bin.'/../lib';


use Test::More;
use Test::Mojo;


use_ok 'OktDB';

$ENV{OktDB_CONFIG} = $FindBin::RealBin."/oktdb.yaml";

my $t = Test::Mojo->new('OktDB');

$t->post_ok('/QX-JSON-RPC', json => {
    id => 1,
    service => 'default',
    method => 'ping'
})
  ->status_is(200)
  ->content_type_is('application/json; charset=utf-8')
  ->json_is({id => 1,result => "pong"});

done_testing();
