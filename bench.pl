#!/usr/bin/env perl
use strict;
use warnings;

my ($test, $path) = @ARGV;
die "usage: $0 TEST [PATH]\n" unless defined $test;

if ($test eq 'cpu') {
    my $sum = 0;
    for my $i (1 .. 5_000_000) {
        $sum += $i % 97;
    }
    print "$sum\n";
}
elsif ($test eq 'strings') {
    my $source = 'The quick brown fox jumps over the lazy dog 0123456789';
    my $sum = 0;
    for (1 .. 1_000_000) {
        my $s = uc($source);
        $s = substr($s, 5, 20);
        $sum += length($s);
    }
    print "$sum\n";
}
elsif ($test eq 'array') {
    my @a;
    for my $i (0 .. 199_999) {
        $a[$i] = sprintf('record-%08d-%s', $i, 'x' x 32);
    }
    my $sum = 0;
    $sum += length($_) for @a;
    print "$sum\n";
}
elsif ($test eq 'lookup') {
    my %h;
    for my $i (1 .. 100_000) {
        $h{"K$i"} = $i;
    }
    my $sum = 0;
    for my $i (1 .. 2_000_000) {
        my $key = 'K' . (($i % 100_000) + 1);
        $sum += $h{$key};
    }
    print "$sum\n";
}

elsif ($test eq 'parse') {
    my $line = '4711|Simon Sulser|Winterthur|1975|1234.56';
    my $sum = 0;

    for (1 .. 1_000_000) {
        my ($id, $name, $city, $year, $amount) = split /\|/, $line, 5;
        $sum += length($id) + length($name) + length($city)
              + length($year) + length($amount);
    }
    print "$sum\n";
}
elsif ($test eq 'io') {
    die "io test requires a path\n" unless defined $path;
    open my $out, '>', $path or die "$path: $!";
    for my $i (1 .. 200_000) {
        printf {$out} "record-%08d-The quick brown fox jumps over the lazy dog\n", $i;
    }
    close $out or die "$path: $!";

    open my $in, '<', $path or die "$path: $!";
    my $sum = 0;
    $sum += length($_) while <$in>;
    close $in;
    print "$sum\n";
}
elsif ($test eq 'noop') {
    print "ok\n";
}
else {
    die "unknown test: $test\n";
}
