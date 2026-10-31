#!/usr/bin/env perl
use strict;
use warnings;
use Time::HiRes qw(time);

my ($mode, $path) = @ARGV;
die "usage: $0 prepare|write|read PATH\n"
    unless defined($path) && defined($mode) && $mode =~ /\A(?:prepare|write|read)\z/;

if ($mode eq 'write' || $mode eq 'prepare') {
    # Formatting is outside the measured write phase.
    my @lines = map { sprintf("record-%08d-The quick brown fox jumps over the lazy dog\n", $_) } 1 .. 200_000;
    my $start = time;
    open my $out, '>', $path or die "$path: $!";
    print {$out} $_ or die "$path: $!" for @lines;
    close $out or die "$path: $!";
    my $elapsed = time - $start;
    print "io_write $elapsed 12000000 200000\n" if $mode eq 'write';
} else {
    my ($bytes, $lines) = (0, 0);
    my $start = time;
    open my $in, '<', $path or die "$path: $!";
    while (my $line = <$in>) {
        $bytes += length($line);
        ++$lines;
    }
    eof($in) or die "$path: read failed: $!";
    close $in or die "$path: $!";
    my $elapsed = time - $start;
    print "io_read $elapsed $bytes $lines\n";
}
