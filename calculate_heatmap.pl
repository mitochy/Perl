#!/usr/bin/perl

use strict; use warnings; use Getopt::Std; use Thread::Queue; use mitochy;
use vars qw($opt_w $opt_s);
getopts("w:s:");

my ($input) = @ARGV;
my $window  = defined($opt_w) ? $opt_w : 200;
my $step    = defined($opt_s) ? $opt_s : 10;

# Check that inputs are sane
check_sanity($input, $window, $step);
my ($outName) = mitochy::getFilename($input);

# Open outputs
open (my $outHeat, ">", "$outName.tsv") or die "Cannot write to $outName.tsv: $!\n";

# Get values of each gene and put in job (Q) for multi-thread
my ($Q, $names) = process_bed($input);
my @names = @{$names};

# Calculate average value for each gene in a sliding window
my %data = %{calculate_data($Q, $window, $step)};

# Print out
for (my $i = 0; $i < @names; $i++) {
	my $name = $names[$i];
	print $outHeat "$data{$name}{data}\n";
}


sub check_sanity {
	my ($input, $window, $step) = @_;
	print "Window: $window\nStep: $step\n";
	my $errorMessage;
	
	$errorMessage .= "Input not defined\n" unless defined($input);
	$errorMessage .= "Input does not exist: $input\n" if defined($input) and not -e ($input);
	$errorMessage .= "Window has to be integer above 0: $window\n" unless $window =~ /^\d+$/;
	$errorMessage .= "Step has to be integer above 0: $step\n"     unless $step   =~ /^\d+$/;
	
	print_usage() and die "$errorMessage\n" if defined($errorMessage);
}

sub print_usage {

	print "
usage: $0 [options] <Data File>
Options:

-w: Window Size (integer) [default: 200]
-s: Step Size (integer) [default: 10]

";
}

sub process_bed {
	# Get each value in bed file into %bed hash
	open (my $in, "<", $input) or die "Cannot read from $input: $!\n";
	my @names;
	my $Q = new Thread::Queue;
	while (my $line = <$in>) {
		chomp($line);
		my ($chr, $start, $end, $val, $name, $type, $strand) = split("\t", $line);
		my @job = ($name, $chr, $start, $end, $val, $type, $strand);
		$Q -> enqueue(\@job);
		push(@names, $name);
	}
	close $in;
	$Q -> end;
	return( $Q, \@names);
}

sub calculate_data {
	my ($Q, $window, $step) = @_;

	# Use multi-thread
	my $total = $Q->pending;
	while ($Q->pending) {
		my $job_count = ($total - $Q->pending);
		#print "$input: Processed $job_count out of $total\n" if $job_count % 5000 == 0;

		my ($name, $chr, $start, $end, $val, $type, $strand) = @{$Q->dequeue};
		my $data     = "$name\t";

		# 1. Get data values per gene
		# Data Values are all NA if value is displayed as NA
		if ($val eq "NA") {
			for (my $i = $start; $i <= $end - $window; $i += $step) {
				$data .= "NA";
				$data .= "\t" if $i != $end - $window;
			}

			$data{$name}{data} = $data;
		}

		else {
	
			# Print values if not NA
			# Data format:
			# Coor1,Val1_Coor2,Val2_Coor3,Val3
			# Split by "_" to get each position and value
			# Then split by "," to get each position's value
			my @values = split("_", $val);
			my %position_value;
			for (my $i = 0; $i < @values; $i++) {
				my ($coor, $coorValue) = split(",", $values[$i]);
				$position_value{$coor} = $coorValue;
			}
	
			# 2. Calculate average methylation in a binned window from start to end
			# Coordinate of the bin window is it's middle point
			# E.g. Start is 1000-2000, window is 200, step is 20
			# Position bin 1 is 1100 (1000 + 200/2 + 0*20) (bin = (1100-1100/20)+1)
			# Position bin 2 is 1120 (1000 + 200/2 + 1*20) (bin = (1120-1100/20)+1)
			# Position bin 3 is 1140 (1000 + 200/2 + 2*20)
			# Etc until bin 42 (1900)
			# Bin number = (position-$start+$window/2)/20 + 1
			# At position 1900: bin = (1900-1100/20)+1 = 41
			for (my $i = 0; $i <= $end - $start - $window; $i += $step) {
				my $totalValue = 0;
				my $totalCount = 0;
				for (my $j = $start + $i; $j < $start + $i + $window; $j++) {
					my $currentValue = $position_value{$j};
					if (defined($currentValue) and $currentValue =~ /^\-?\d+\.?\d*$/) {
						$totalValue += $currentValue;
						$totalCount ++;
					}
				}
	
				# Total value is NA if no data is found, otherwise we average it
				$totalValue = $totalValue / $totalCount if $totalCount > 0;
				$totalValue = "NA" if $totalCount == 0;
				
				# Store value in $data
				$data .= $totalValue;
				$data .= "\t" if $i != $end - $start - $window;
			}
	
			$data{$name}{data} = $data;
		}
		if ($strand eq "-") {
			my ($name, @data) = split("\t", $data{$name}{data});
			@data = reverse(@data);
			$data{$name}{data} = "$name\t" . join("\t", @data);
		}
	}
	return(\%data);
}
