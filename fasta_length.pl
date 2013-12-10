#!/usr/bin/perl

use strict; use warnings; use FAlite;

my ($input) = @ARGV;
die "usage: $0 <fasta>\n" unless @ARGV;
open (my $in, "<", $input) or die "Cannot read from $input: $!\n";
my $fasta = new FAlite($in);
while (my $entry = $fasta->nextEntry()) {
	my $length = length($entry->seq);
	my $def    = $entry->def;
	print "$def: $length\n";
}
close $in;
