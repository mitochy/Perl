#!/usr/bin/perl
# this script print line randomly
# randomly but not repeating (e.g. line N won't be printed twice)
# e.g. you want 1000 random line printed out of 1000000 lines
# therefore if you
use strict; use warnings;

my ($input, $rand) = @ARGV;

die "usage: $0 <input> <random (not more than total line!)\n" unless @ARGV == 2;

open (my $in, "<", $input) or die "Cannot read from $input: $!\n";
open (my $out, ">", "$input\.random\.$rand") or die "Cannot write to $input\.random\.$rand: $!\n";
#my ($linetotal) = `wc -l` =~ /^(\d+) /;
#die "random line number is more than total line, not gonna work\n" if $rand > $linetotal;
#print "random line number is more than 80% of total line, gonna take long\n" if $rand > 0.8 * $linetotal;
my %line;

while (1) {
	my $random = int(rand($rand));
	if (not defined($line{$random})) {
		$line{$random}++;
		my $key = keys %line;
		#print "$key\n";
	}
	last if (keys %line) == $rand;
}
my $linecount = 0;
while (my $line = <$in>) {
	chomp($line);
	print $out "$line\n" if defined($line{$linecount});
	$linecount++;
}
close $in;
close $out;
