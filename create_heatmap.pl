#!/usr/bin/perl

use strict; use warnings; use Getopt::Std; use R_toolbox; use mitochy;
use vars qw($opt_c $opt_d $opt_r $opt_t);
getopts("c:d:rt");

die "
usage: $0 [options] <Data Files>

Options:
-t: Test input correctness (e.g. color/break - not creating anything)
-r: Toggle to create image
-d: Directory of output file (string)
-c: Cluster file containing list of names/id at first column (tab separated)
Whether there are data on second, third, fourth, etc does not matter
But make sure name of cluster and name in data files are the same
Example:
NAME	1	425	6
NAME2	2414125,662

Output:
1. <directory>/<name>.sorted: Contain sorted gene list
2. <directory>/<name>.png: PNG image if -r is on

" unless @ARGV;

my @dataFiles = @ARGV;
my $directory = defined($opt_d) ? $opt_d : "./";
mkdir $directory if not -d $directory;
my $clusterFile = $opt_c if defined($opt_c);
foreach my $dataFile (@dataFiles) {
	print "Processing $dataFile\n";
	my $outName = mitochy::getFilename($dataFile);
	$outName = $directory . "/" . $outName;
	main($dataFile, $outName);
}

sub main {
	my ($dataFile, $outName) = @_;
	my $Rscript;

	# Get colors and breaks from input	
	my $colors = get_colors($dataFile);
	my $breaks = get_breaks($dataFile);

	last if ($opt_t);	
	# Get heatmap data
	my ($data, $ncol) = process_heatmapFile($dataFile);
	my %data = %{$data};
		
	my ($clusterNameArr, $clusterNameHash) = get_cluster($clusterFile) if defined($clusterFile);
	
	# Sort heatmap (either by clusterFile or high-low) and put into R data format, 
	# Get number of row, and number of column
	my ($Rdata, $Rnames, $RdataBig, $nrow) = sort_heatmap(\%data, $clusterNameHash, $clusterNameArr, $clusterFile, $outName, $ncol);

	#my @Rdata = split("\n", $Rdata);
	#for (my $i = 0; $i < @Rdata; $i++) {
	#	my ($name, $data) = $Rdata[$i] =~ /^(.+)(<-.+)$/;
	#	$name =~ tr/\!\@\#\$\%\^\&\*\(\)\-\+\=\/\?\>\<\,\/ /____________________/;
	#	$Rdata[$i] = "$name$data";
	#}
	#$Rnames =~ tr/\!\@\#\$\%\^\&\*\(\)\-\+\=\/\?\>\<\,\/ /____________________/;
	#$RdataBig =~ tr/\!\@\#\$\%\^\&\*\(\)\-\+\=\/\?\>\<\,\/ /____________________/;

	
	# Create R script
	$Rscript .= "

	library(GMD);
	library(RColorBrewer);
	
	# All Data
	$Rdata
	
	# Names
	$Rnames
	
	# Sample
	# sample <- c(name1, name2, etc)
	$RdataBig
	# Combined Data into Matrix
	dm <- matrix(c(sample), ncol=$ncol, nrow=$nrow, byrow=TRUE)
	
	# Histogram
	hist <- c(sample)
	h = hist(hist)
	h\$breaks
	h\$counts
	
	# PDF output
	#pdf(\"$outName.pdf\", compress=TRUE)
	png(\"$outName\.png\", res=300, width=200, height=2500)
	
	# Row names
	rownames(dm) = name
	
	# Colors
	mycol=function(x) {$colors}
	
	# Heatmap
	h <- heatmap.3(
	dm,
	Rowv=FALSE,
	Colv=FALSE,
	key=FALSE,
	main=NA,
	dendrogram=\"none\",
	cluster.by.row=FALSE,
	cluster.by.col=FALSE,
	labRow=FALSE,
	labCol=FALSE,
	breaks=$breaks,
	plot.row.partition = FALSE,
	color.FUN = mycol,
	mapsize=11.5,
	)
	
	";

	open (my $out, ">", "$outName.R") or die "Cannot write to $outName.R: $!\n";
	print $out $Rscript;
	close $out;
	if ($opt_r) {
		system("R --no-save < $outName.R > dump 2>%1") == 0 or die "Failed to run R script $outName.R: $!\n";
		unlink "$outName.R";
		system("convert -trim $outName.png $outName.tmp");
		system("mv $outName.tmp $outName.png");
		#compress_pdf_to_png($outName);
		unlink "$outName.pdf";
	}
}

sub get_colors {
	my ($input) = @_;
	my $colors;
	$colors = "c(\"darkblue\",brewer.pal(9,\"Reds\"))" if $input =~ /H3K4me1/i;
	$colors = "c(\"darkblue\",brewer.pal(9,\"Reds\"))" if $input =~ /H3K4me3/i;
	$colors = "c(\"darkblue\",brewer.pal(9,\"Reds\"))" if $input =~ /H3K27me3/i;
	$colors = "c(\"darkblue\",brewer.pal(9,\"Reds\"))" if $input =~ /H3K36me3/i;
	$colors = "c(\"darkblue\",brewer.pal(9,\"Reds\"))" if $input =~ /H3K9me3/i;
	$colors = "c(\"darkblue\",brewer.pal(9,\"Reds\"))" if $input =~ /H3K9ac/i;
	$colors = "c(\"darkblue\",brewer.pal(9,\"Reds\"))" if $input =~ /RNA/i;
	$colors = "c(\"darkblue\",brewer.pal(9,\"Reds\"))" if $input =~ /DRIP/i;
	$colors = "c(\"darkred\",brewer.pal(9,\"Blues\"))" if $input =~ /CpG/i or $input =~ /dens/i;
	$colors = "c(\"darkred\",brewer.pal(9,\"Greens\"))" if $input =~ /GC/i or $input =~ /cont/i;
	$colors = "c(\"black\",rev(brewer.pal(11,\"RdBu\")))" if $input =~ /SKEW/i;
	$colors = "c(\"lightblue\",brewer.pal(9,\"Reds\"))" if $input =~ /RRBS/i or $input =~ /meth/i;
	$colors = "c(\"darkblue\",brewer.pal(9,\"Reds\"))" if $input =~ /GROSEQ/i;
	die "Colors of input $input undefined\n" if not defined($colors);
	return($colors);
}

sub get_breaks {
	my ($input) = @_;
	my $breaks;
	$breaks = "c(-999999,1,2,4,6,8,10,12,14,16,max(dm))" if $input =~ /H3K4me1/i;
	$breaks = "c(-999999,min(dm),1,5,10,15,20,25,30,35,max(dm))" if $input =~ /H3K4me3/i;
	$breaks = "c(-999999,min(dm),1,2.5,5,7.5,10,12.5,15,17.5,max(dm))" if $input =~ /H3K27me3/i;
	$breaks = "c(-999999,min(dm),1,2.5,5,7.5,10,12.5,15,17.5,max(dm))" if $input =~ /H3K36me3/i;
	$breaks = "c(-999999,min(dm),1,2.5,5,7.5,10,12.5,15,17.5,max(dm))" if $input =~ /H3K9me3/i;
	$breaks = "c(-999999,min(dm),1,5,10,15,20,25,30,35,max(dm))" if $input =~ /H3K9ac/i;
	$breaks = "c(-999999,0,5,10,15,20,25,30,35,40,max(dm))" if $input =~ /RNA/i;
	$breaks = "c(-999999,0,1,2,3,4,5,6,7,8,max(dm))" if $input =~ /DRIP/i;
	$breaks = "c(-999999,0,0.15,0.3,0.45,0.6,0.75,0.9,1.05,1.2,max(dm))" if $input =~ /CPG/i or $input =~ /dens/i;
	$breaks = "c(-999999,0,0.2,0.26,0.32,0.38,0.44,0.5,0.56,0.62,max(dm))" if $input =~ /GC/i or $input =~ /cont/i;
        $breaks = "c(-999999,-1,-0.25,-0.2,-0.15,-0.1,-0.05,0.05,0.01,0.15,0.2,0.25,max(dm))" if $input =~ /SKEW/i;
	#$breaks = "c(0,0.0001,0.15,0.3,0.45,0.6,0.75,0.9,0.95,0.99,max(dm))" if $input =~ /RRBS/i or $input =~ /meth/i;
	$breaks = "c(-999999,-1,5,10,15,20,25,30,35,40,max(dm))" if $input =~ /RRBS/i or $input =~ /meth/i;
	$breaks = "c(-999999,min(dm),0.5,1,1.5,2,2.5,3,3.5,4,max(dm))" if $input =~ /GROSEQ/i;
	die "Breaks of input $input undefined\n" if not defined($breaks);
	return($breaks);
}

sub process_heatmapFile {
	my ($input) = @_;
	my %data;
	my $ncol;
	open (my $in, "<", $input) or die "Cannot read from $input: $!\n";
	while (my $line = <$in>) {
		chomp($line);
		
		# Next if there is a blank space or header
		next if $line =~ /^\n$/;
		next if $line =~ /\#/;

		# Get name and value array
		my ($name, @value) = split("\t", $line);
		my $valueCount = @value;
		if (not defined($ncol)) {
			$ncol = @value;
			$ncol = 2 if $ncol == 1;
		}
		die "$input: Column number ncol ($ncol) is not identical between data ($valueCount)\n" if defined($ncol) and scalar(@value) > 1 and ($ncol != scalar @value);
		die "$input: Column number ncol ($ncol-1) is not identical between data ($valueCount)\n" if defined($ncol) and scalar(@value) == 1 and ($ncol-1 != scalar @value);
		foreach my $values (@value) {
			$data{$name}{total} += $values if $values =~ /^\d+\.?\d*$/;
		}
		@{$data{$name}{value}} = @value;
		$data{$name}{total} = -999999 if not defined($data{$name}{total});
	}
	return(\%data, $ncol);
}

sub get_cluster {
	my ($clusterFile) = @_;
	my %clusterName;
	my @clusterName;
	open (my $in, "<", $clusterFile) or die "Cannot read from $clusterFile: $!\n";
	while (my $line = <$in>) {
		chomp($line);
		my ($name) = split("\t", $line);
		$clusterName{$name} = 1;
		push(@clusterName, $name);
	}
	close $in;
	return(\@clusterName, \%clusterName);
}

sub sort_heatmap {
	my ($data, $clusterNameHash, $clusterNameArr, $clusterFile, $outName, $ncol) = @_;
	my %data = %{$data};
	my @clusterName;
	if (defined($clusterFile)) {
		@clusterName = @{$clusterNameArr};# if defined($clusterFile);
	}

	# If clusterFile does not exist, cluster by high-low. Otherwise, cluster by clusterFile
	else {
		foreach my $name (sort {$data{$b}{total} <=> $data{$a}{total}} keys %data) {
			push(@clusterName, $name);
		}
	}

	my $total = (keys %data);
	my $nrow  = @clusterName;
	my $skip  = $total - $nrow;
	my $Rdata;
	
	open (my $out, ">", "$outName\.sorted") or die "Cannot write to $outName\.sorted: $!\n";
	for (my $i = 0; $i < @clusterName; $i++) {
		my $name = $clusterName[$i];
		my @value;

		# If name does not exist in %data then print the data of that name as all -999999 (NA)
		if (not defined($data{$name}{value})) {
			for (my $i = 0; $i < $ncol; $i++) {
				push(@value, "NA");
			}
		}

		# Ncol record value per data. If values of all data are not consistent then die.
		else {
			@value = @{$data{$name}{value}};
		}

		print $out "$name\t";
		my @tempValue;
		# Change NA to -999999 which will have a black color
		for (my $i = 0; $i < @value; $i++) {
			my $tempValue = $value[$i];
			$tempValue = -999999 if $tempValue eq "NA";
			$tempValue = "$tempValue, $tempValue" if @value == 1;
			print $out "$tempValue";
			print $out "\t" if $i != @value - 1;
			push(@tempValue, $tempValue);
		}
		print $out "\n";
		@value = @tempValue;
	
		# Store value into R array format
		# $name -> c(\@value)
		my $Rvalue = R_toolbox::newRArray(\@value, $name);
		$Rdata .= "$Rvalue\n";
	}
	close $out;


	# R arrays that store name and matrix
	my $Rnames = R_toolbox::newRArray(\@clusterName, "name", "with_quote");
	my $RdataBig = R_toolbox::newRArray(\@clusterName, "sample");

	return($Rdata, $Rnames, $RdataBig, $nrow);
}

sub compress_pdf_to_png {

	my ($outName) = @_;
	my $cmd1 = "cpdf $outName.pdf -hflip -o $outName.2 > /dev/null 2>&1 && cpdf $outName.2 -mediabox \"0pt 0pt 451pt 452pt\" -o $outName.3 > /dev/null 2>&1 && cpdf $outName.3 -hflip -o $outName.2 > /dev/null 2>&1";
	my $cmd2 = "convert -density 400 $outName.2 -trim -quality 100 -depth 8 $outName.png > /dev/null 2>&1";
	#my $cmd2 = "convert -density 400 $outName -trim -quality 100 -depth 8 $outName\_temp.png > /dev/null 2>&1";
	system($cmd1) == 0 or die "Failed to run $cmd1: $!\n";
	system($cmd2) == 0 or die "Failed to run $cmd2: $!\n";
	unlink "$outName.2";
	unlink "$outName.3";
}

__END__


