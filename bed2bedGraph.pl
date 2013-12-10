#!/usr/bin/perl

use strict; use warnings; use mitochy;

my ($input) = @ARGV;
die "usage: $0 <bed>\n" unless @ARGV;

my ($folder, $name) = mitochy::get_filename($input);
open (my $in, "<", $input) or die "Cannot read from $input: $!\n";
open (my $out, ">", "$name.bg") or die "Cannot write to $name.bg: $!\n";
while (my $line = <$in>) {
	chomp($line);
	print "$line\n" and next if $line =~ /track/;
	next if $line =~ /\#/;
	my ($chr, $start, $end, $name, $value, $strand) = split("\t", $line);
	print $out "$chr\t$start\t$end\t$value\n";
}
close $in;
close $out;
