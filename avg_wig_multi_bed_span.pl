#!/usr/bin/perl
# avg_wig_multi_bed.pl by Stella Hartono
# clean up slightly by Yoong Wearn Lim
# Major code revision for speed and correctness by Stella on 23 July 2013
# input a wig and a bed file
# for each entry in the bed file
# find the mean value in the wig file
# should be fast because it uses cache!
#########################################

use strict; use warnings; use Cache::FileCache;
my ($wigfile, $cbool, $cache_folder, @bedfile) = @ARGV;

checksanity($wigfile, $cbool, $cache_folder, @bedfile);

print "\n\****************
Your input:
Wig File 	= $wigfile
Bed File 	= @bedfile
Cache Option 	= $cbool ";
print "(Clear cache and/or process wig file)\n\****************\n\n" if defined($cbool) and $cbool == 1;
print "(Use existing wigfile cache)\n\****************\n\n" if defined($cbool) and $cbool == 0;


my (@splitwigname) = split("\/", $wigfile);
my $wigname = $splitwigname[@splitwigname-1];
@splitwigname = split(/\./, $wigname);
$wigname = $splitwigname[0];

# Cache setup and process wigfile
my $cache = new Cache::FileCache();
$cache -> set_cache_root('$cache_folder');

print "- Loading Wig file $wigfile ... (This might take a couple minutes depending on the size of your Wig file)\n";
my $wig;
$cache -> clear("$wigfile\.cache") if defined($cbool) and $cbool == 1;		# clear cache
$wig = $cache -> get("$wigfile\.cache") if defined($cbool) and $cbool == 0;	# do not clear cache

if (not defined($wig) or $cbool == 1) {
	$wig = process_wig($wigfile, 1);
}
my %wig = %{$wig};

# Process the final result 
my @output_name;
foreach my $bedfile (@bedfile) {

	print "- Loading Bed file $bedfile ...\n";
	# Process bedfile
	my %bed = %{process_bed($bedfile)};
	my @splitbedname = split("\/", $bedfile);
	my $bedname = $splitbedname[@splitbedname-1];
	@splitbedname = split(/\./, $bedname);
	$bedname = $splitbedname[0];
	print "- Mapping $bedfile to $wigfile ...";

	#my ($total) = `wc -l $bedfile` =~ /^(\d+)/;

	#my ($total_line) = `wc -l $bedfile` =~ /^(\d+) /;
	my $count = 0;

	my %final;
	foreach my $ID (sort {$a <=> $b} keys %bed) {
		$count++;
		#printf "Processed %.2f %% of $total ($count / $total)\n", $count / $total * 100 if $count % 1000 == 0;
		my $bed_index_start_kilo = $bed{$ID}{bed_index_start_kilo};
		my $bed_index_end_kilo   = $bed{$ID}{bed_index_end_kilo};
		my $bed_index_start_mega = $bed{$ID}{bed_index_start_mega};
		my $bed_index_end_mega 	 = $bed{$ID}{bed_index_end_mega};
		my $start		 = $bed{$ID}{start};
		my $end			 = $bed{$ID}{end};
		my $chr			 = $bed{$ID}{chr};
		#print "Processing $start $end $bed_index_start_mega to $bed_index_end_mega and $bed_index_start_kilo to $bed_index_end_kilo\n";

		for (my $i = $bed_index_start_mega; $i <= $bed_index_end_mega; $i++) {
			next if not defined($wig{$chr}{$i});
			for (my $j = $bed_index_start_kilo; $j <= $bed_index_end_kilo; $j++) {
				next if not defined($wig{$chr}{$i}{$j});
				foreach my $pos (sort {$a <=> $b} keys %{$wig{$chr}{$i}{$j}}) {
					my $val = $wig{$chr}{$i}{$j}{$pos}{val};
					my $span = $wig{$chr}{$i}{$j}{$pos}{span};
					#print "pos $pos span $span start $start end $end\n";
					next if $end < $pos;
					last if $start > $pos+$span;
					#print "Not nexted. Does $pos, $pos+$span, overlap with $start, $end?\n";
					if (overlap($pos, $pos+$span, $start, $end) == 1) {
					#	print "$pos-$pos+$span overlap with $start-$end!\n";
						$bed{$ID}{val}   += $val*($end - $start + 1);
						$bed{$ID}{count} += $end - $start + 1;
					}
					#print "At $ID $chr $start $end found at index $i $j pos $pos val $bed{$ID}{val} plus $wig{$chr}{$i}{$j}{$pos} count $bed{$ID}{count}\n";
				}
			}
		}
	}

	# CHANGE HOW YOUR OUTPUT IS NAMED HERE #
	# currently it use $bedfile.txt, but feel 
	# free to change it to whatever u want
	# e.g. $bedfile.output.txt
	open (OUT, ">", "$wigname\_$bedname.txt") or die "Error writing to $wigname\_bedname.txt\n";
	push(@output_name, "$wigname\_$bedname.txt");
	# CHANGE HOW YOUR OUTPUT IS NAMED HERE #

	#OUTPUT
	foreach my $ID (sort {$a <=> $b} keys %bed) {
		my $start = $bed{$ID}{start};
		my $end   = $bed{$ID}{end};
		my $chr   = $bed{$ID}{chr};
		
		my @stuff = @{$bed{$ID}{stuff}};
		my $stuff = "";
		for (my $i = 0; $i < @stuff; $i++) {
			$stuff .= "$stuff[$i]\t" if $i < @stuff-1;
			$stuff .= "$stuff[$i]" if $i == @stuff-1;
		}
		if (defined($bed{$ID}{count})) {
			printf OUT "$chr\t$start\t$end\t%.2f\t$stuff\n", $bed{$ID}{val} / $bed{$ID}{count};
		}
		else {
			printf OUT "$chr\t$start\t$end\tNA\t$stuff\n";
		}
	}
	print " Done!\n";
}

print "\nOutput file(s):\n";
for (my $i = 0; $i < @output_name; $i++) {
	my $num = $i + 1;
	print "$num. Output of $bedfile[$i]: $output_name[$i]\n";
}
print "\n";
################
## Subroutine ##
################

sub process_wig {
	my ($fh, $cbool) = @_;

	#print "Processing Wigfile because cache doesn't exist\n";
	my %wig;
	my $linenumber = 0;
	#my $total = `wc -l $fh`;
	#($total) = $total =~ /^(\d+) /;
	open (my $in, "<", $fh) or die "Cannot read from $fh: $!\n";
	my $chr = "INIT";
	my $curr_chr = "INIT";
	my $span;
	while (my $line = <$in>) {
		chomp($line);

		$linenumber++;
		#printf "$linenumber / $total (%.2f)\n", $linenumber / $total * 100 if ($linenumber % 1000000 == 0);
		if ($line !~ /^\d/) {
			next if $line  !~ /chrom=/;
			($chr, $span) = $line =~ /chrom=(chr.+) span=(\d+)/i;
			$curr_chr = $chr;
		}
		else {
			my ($pos, $val) 	= split("\t", $line)		;
			my $wig_index_mega   	= int($pos/1000000)		;
			my $wig_index_kilo 	= int($pos/1000)		;
			$wig{$chr}{$wig_index_mega}{$wig_index_kilo}{$pos}{val} = $val;
			$wig{$chr}{$wig_index_mega}{$wig_index_kilo}{$pos}{span} = $span;
		}
	}
	close $in;

	#print "Done processing $fh, putting into cache $fh\.cache \n";
	$cache -> set("$fh\.cache", \%wig) if defined($cbool);
	return(\%wig);
}

sub process_sam {
	my ($fh, $cbool) = @_;

	my %sam;
	open (my $in, "<", $fh) or die "Cannot read from $fh: $!\n";
	while (my $line = <$in>) {
		chomp($line);	
		next if ($line =~ /^@/);
		my ($QNAME, $FLAG, $RNAME, $POS, $MAPQ, $CIGAR, $RNEXT, $PNEXT, $TLEN, $SEQ, $QUAL) = split("\t", $line);
		my $sam_index_mega = int($POS/1000000);
		my $sam_index_kilo = int($POS/1000)   ;
		my @CIGAR = split("M", $CIGAR);
		my $span;
		foreach my $CIGAR (@CIGAR) {
			my $mapped = $CIGAR =~ /(\d+)$/;
			$span += $mapped;
		}
		$sam{$RNAME}{$sam_index_mega}{$sam_index_kilo}{$POS}{val} = 1;
		$sam{$RNAME}{$sam_index_mega}{$sam_index_kilo}{$POS}{span} = $span;
	
	}
	close $in;
	return(\%sam);
}
sub process_bed {
	my ($fh) = @_;

	my %bed;
	open (my $in, "<", $fh) or die "Cannot read from $fh: $!\n";
	my $linenumber = 0;
	#my $total = `wc -l $fh`;
	#($total) = $total =~ /^(\d+) /;

	while (my $line = <$in>) {
		chomp($line);
		$linenumber++;
		#printf "$linenumber / $total (%.2f)\n", $linenumber / $total * 100 if ($linenumber % 1000000 == 0);
		next if $line !~ /^chr/;
		next if $line =~ /track/;
		next if $line =~ /\#/;
		my ($chr, $start, $end, @stuff) = split("\t", $line);
		my $ID = (keys %bed); # ID increment as bed increase
		$bed{$ID}{chr} 	= $chr;
		$bed{$ID}{bed_index_start_kilo} = int($start / 1000)	;
		$bed{$ID}{bed_index_end_kilo}   = int($end   / 1000)	;
		$bed{$ID}{bed_index_start_mega} = int($start / 1000000)	;
		$bed{$ID}{bed_index_end_mega}   = int($end   / 1000000)	;
		$bed{$ID}{start}		= $start		;
		$bed{$ID}{end}			= $end  		;
		$bed{$ID}{stuff}		= \@stuff  		;
	}
	
	return(\%bed);
	close $in;
}

sub checksanity {
	my ($wigfile, $cbool, $cache_folder, @bedfile) = @_;
	print "\n\****************\nChecking sanity of input files\n";
	die "\nError: No input detected\nusage: $0 <wigfile> <cache_opt [0 to use cache, 1 to ignore/clear]> <cache_folder> <multiple_bed_files>\n\n" unless @ARGV > 2;
	die "\nError: Wigfile not defined\nusage: $0 <wigfile> <cache_opt [0 to use cache, 1 to ignore/clear]> <cache_folder> <multiple_bed_files>\n\n" unless defined($wigfile);
	die "\nError: Cache option not defined\nusage: $0 <wigfile> <cache_opt [0 to use cache, 1 to ignore/clear]> <cache_folder> <multiple_bed_files>\n\n" unless defined($cbool);
	die "\nError: Bedfile not defined\nusage: $0 <wigfile> <cache_opt [0 to use cache, 1 to ignore/clear]> <cache_folder> <multiple_bed_files>\n\n" unless defined($bedfile[0]);
	die "\nError: Cache folder $cache_folder does not exists: $!\n\n"  unless -d $cache_folder;
	die "\nError: Wigfile $wigfile does not exists: $!\n\n"  unless -e $wigfile;

	# Check cbool must be 0 or 1
	die "\nError: cbool must be either 0 or 1 (currently: $cbool)\n\n" unless $cbool == 0 or $cbool == 1;

	# Check for wig file name
	my (@splitwigname) = split("\/", $wigfile);
	my $wigname = $splitwigname[@splitwigname-1];
	@splitwigname = split(/\./, $wigname);
	$wigname = $splitwigname[0];

	if (not defined($wigname)) {
		die "\nError: If this message ever appear, YWL can have naked juice\n\n";
	}
	
	foreach my $bedfile (@bedfile) {
		die "\nError: Bedfile $bedfile does not exists: $!\n\n" unless -e $bedfile;

		# Check for bed file name
		my @splitbedname = split("\/", $bedfile);
		my $bedname = $splitbedname[@splitbedname-1];
		@splitbedname = split(/\./, $bedname);
		$bedname = $splitbedname[0];
	
		if (not defined($bedname)) {
			die "\nError: If this message ever appear, YWL can have naked juice\n\n";
		}
	}

	print "Sanity check complete. All files seem to be sane.\n\****************\n";
}

sub overlap {
	my ($start1, $end1, $start2, $end2) = @_;
	return 1 if $start1 >= $start2 and $start1 <= $end2;
	return 1 if $start2 >= $start1 and $start2 <= $end1;
	return 0;
}
__END__
Naked juice can only be obtained once
