#!/usr/bin/perl

use strict; use warnings; use Getopt::Std;

use vars qw($opt_c $opt_r $opt_o);
getopts("c:r:o:");

my ($input) = @ARGV;

my $usage = "
usage: $0 [options] <input>
options:
-c: column of value (default: 5)
-r: Remove value less than this (default: Not removing anything)
-o: Output

Note: column does not start from zero:
col1	col2	col3	col4	col5
chrom	start	end	name	value

-r 5 will keep value at least 5
-r -255 will keep value at least -255

Make sure output name is not the same as input name (will remove both)
";

die $usage unless @ARGV == 1;
my $outputName = getFilename($input);
my $output = "$outputName.wig";
if ($output eq $input) {
	die "Fatal error: Input $input and output $output is the same file!\n";
}

my $val_column = defined($opt_c) ? $opt_c : 5;
my $val_filter = $opt_r if defined($opt_r);
if (defined($val_filter)) {
	die $usage if $val_filter !~ /^(\d+)\.?\d*$/;
}

my $chrom = "INIT";
my $span  = "INIT";
open (my $in, "<", $input) or die "Cannot read from input $input: $!\n";
open (my $out, ">", "$output") or die "Cannot write to output $output: $!\n";
while (my $line = <$in>) {
	chomp($line);
	next if $line =~ /^track/i;
	next if $line =~ /\#/;
	my @arr = split("\t", $line);
	my ($chr, $start, $end, $val) = ($arr[0], $arr[1], $arr[2], $arr[$val_column-1]);
	next if defined($val_filter) and $val < $val_filter;

	die "died because undefined chromosome at line: $line\n" if not defined($chr);
	print "Example chromosome, start position, and value:\nChr: $chr\nStart: $start\nValue: $val\n" if $span eq "INIT";

	my $span2 = $end - $start;
	if ($chr ne $chrom or $span2 ne $span) {
		print $out "variableStep chrom=$chr span=$span2\n";
		print $out "$start\t$val\n";
		$span  = $span2;
		$chrom = $chr;
	}
	else {
		print $out "$start\t$val\n";
	}
}
close $in;
close $out;


sub getFilename {
        my ($fh, $type) = @_;
        my (@splitname) = split("\/", $fh);
        my $name = $splitname[@splitname-1];
        my @tempfolder = pop(@splitname);
        my $folder = join("\/", @tempfolder);
        @splitname = split(/\./, $name);
        $name = $splitname[0];
        return($name) if not defined($type);
        return($folder, $name) if defined($type);
}
