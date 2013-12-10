#!/usr/bin/perl

use strict; use warnings;

my ($bedfile) = @ARGV;
die "Usage: $0 <bedfile>\n" unless @ARGV;

my %stats;
open (my $in, "<", $bedfile) or die;
#open (my $out, ">", "$bedfile.stats") or die;
while (my $line = <$in>) {
	chomp($line);
	next if $line =~ /track/;
	next if $line =~ /\#/;
	my ($chr, $start, $end) = split("\t", $line);
	$stats{length} += $end - $start + 1;
}
#close $out;
close $in;
$stats{length} = 0 if not defined($stats{length});
my $length_in_million = int($stats{length} / 10000) / 100;
print "$bedfile\t$stats{length} bp ($length_in_million Mbp)\n";
