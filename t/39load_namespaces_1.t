#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../t/lib";
use DBICNSTest::Result::A;

plan tests => 7;

my $warnings;
eval {
    local $SIG{__WARN__} = sub { $warnings .= shift };
    package DBICNSTest;
    use base qw/DBIx::Class::Schema/;
    __PACKAGE__->load_namespaces;
};
ok(!$@) or diag $@;
like($warnings, qr/load_namespaces found ResultSet class C with no corresponding Result class/);

my $source_a = DBICNSTest->source('A');
isa_ok($source_a, 'DBIx::Class::ResultSource::Table');
my $rset_a   = DBICNSTest->resultset('A');
isa_ok($rset_a, 'DBICNSTest::ResultSet::A');

my $source_b = DBICNSTest->source('B');
isa_ok($source_b, 'DBIx::Class::ResultSource::Table');
my $rset_b   = DBICNSTest->resultset('B');
isa_ok($rset_b, 'DBIx::Class::ResultSet');
ok(
   $source_b->source_name
   eq DBICNSTest::Result::B->result_source_instance->source_name
);