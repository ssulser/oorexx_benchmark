#!/usr/bin/env perl
use strict;
use warnings;

my $re = qr/^[A-Z][A-Z][0-9][0-9][0-9][0-9]-[a-z]+$/;

my $good = 'AB4711-winterthur';
my $bad  = 'A94711-Winterthur';

my $matches = 0;

for my $i (1 .. 1_000_000) {
    my $s = ($i & 1) ? $good : $bad;
    ++$matches if $s =~ $re;
}

print "$matches\n";
