#!/usr/bin/env perl
use strict;
use warnings;
use Time::HiRes qw(time);

# Each phase reports: name, elapsed seconds, checked result.
my $start = time;
my @records;
for my $i (0 .. 199_999) {
    $records[$i] = sprintf('record-%08d-%s', $i, 'x' x 32);
}
my $elapsed = time - $start;
print "records $elapsed ", scalar(@records), "\n";

$start = time;
my @a;
for my $i (0 .. $#records) { $a[$i] = $records[$i]; }
$elapsed = time - $start;
print "array_build $elapsed ", scalar(@a), "\n";

my $sum = 0;
$start = time;
for (1 .. 20) { $sum += length($_) for @a; }
$elapsed = time - $start;
print "array_scan $elapsed $sum\n";

$start = time;
my @keys;
for my $i (1 .. 100_000) { push @keys, "K$i"; }
$elapsed = time - $start;
print "keys $elapsed ", scalar(@keys), "\n";

$start = time;
my %h;
for my $i (0 .. $#keys) { $h{$keys[$i]} = $i + 1; }
$elapsed = time - $start;
print "table_build $elapsed ", scalar(keys %h), "\n";

$sum = 0;
$start = time;
for (1 .. 20) { $sum += $h{$_} for @keys; }
$elapsed = time - $start;
print "lookup $elapsed $sum\n";
