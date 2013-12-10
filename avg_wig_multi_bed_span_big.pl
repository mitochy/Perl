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
my ($wigfile, $cbool, $cache_root, @bedfile) = @ARGV;

checksanity($wigfile, $cbool, $cache_root, @bedfile);

print "\n\****************

***** WARNING: MAKE SURE THAT YOUR WIG FILE IS ORDERED BY CHROMOSOME *****
***** 		   OTHERWISE THIS SCRIPT WILL NOT WORK!              *****
***** MAKE SURE YOUR BED FILE IS ORDERED BY CHROMOSOME TOO OTHERWISE *****
*****             IT WILL TAKE VERY LONG TIME                        *****
***** sort -n command

Your input:
Wig File 	= $wigfile
Bed File 	= @bedfile
Cache Root	= $cache_root
Cache Option 	= $cbool ";
print "(reprocess wig file)\n\****************\n\n" if defined($cbool) and $cbool == 1;
print "(Use existing wigfile cache)\n\****************\n\n" if defined($cbool) and $cbool == 0;
if ($cbool == 1) {
	print "Are you sure you want to delete EVERY SINGLE CHROMOSOME CACHE about this wig file? (Y/N)\n";
	my $respond = <STDIN>;
	print "Cancelled\n" and exit 0 if ($respond eq "N" or $respond eq "n");
}
my (@splitwigname) = split("\/", $wigfile);
my $wigname = $splitwigname[@splitwigname-1];
@splitwigname = split(/\./, $wigname);
$wigname = $splitwigname[0];

# Cache setup and process wigfile
my $cache = new Cache::FileCache();
$cache -> set_cache_root($cache_root);

print "- Loading Wig file $wigfile ... (This might take a couple minutes depending on the size of your Wig file)\n";

if ($cbool == 1) {
	process_wig($wigfile)
}

# Process the final result 
my @output_name;
my $curr_chr = "INIT";
my %wig;
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
		#print "\n\nprocessing $chr\n";
		if ($chr ne $curr_chr) {
			#print "getting cache from $wigfile\.$chr\.cache\n";
			my $wig = $cache -> get("$wigfile\.$chr\.cache");
			if (not defined($wig)) {
				#print "Undefined at chr $chr\n";
				$wig{$chr} = ();
			}
			else {
				%wig = %{$wig};
			}
			$curr_chr = $chr;
		}
		$curr_chr = $chr;
		#print "Processing start $start end $end start_index_mega $bed_index_start_mega to end_index_mega $bed_index_end_mega and start_index_kilo $bed_index_start_kilo to end_index_kilo $bed_index_end_kilo\n";
		$bed{$ID}{val} = 0 if not defined($bed{$ID}{val});
		for (my $i = $bed_index_start_mega; $i <= $bed_index_end_mega; $i++) {
			next if not defined($wig{$chr}{$i});
			for (my $j = $bed_index_start_kilo; $j <= $bed_index_end_kilo; $j++) {
				next if not defined($wig{$chr}{$i}{$j});
				foreach my $pos (sort {$a <=> $b} keys %{$wig{$chr}{$i}{$j}}) {
					my $val = $wig{$chr}{$i}{$j}{$pos}{val};
					my $span = $wig{$chr}{$i}{$j}{$pos}{span};
					my $wigstart = $pos;
					my $wigend   = $pos + $span - 1;
					#print "WIG: $wigstart - $wigend val $val (span = $span)\nBED: $start - $end\n";
					#print "Last! Since bed end $end is smaller than wig start $wigstart\n" and last if $end < $wigstart;
					#print "Next! Since bed start is already bigger than wig end\n" and next if $start > $wigend;
					#print "\tDo they overlap? (Curr val = $bed{$ID}{val})\n";
					if (overlap($wigstart, $wigend, $start, $end) == 1) {
						my $overlap = find_overlap($wigstart, $wigend, $start, $end);
						#print "\tWIG $wigstart-$wigend vs BED $start-$end: Overlap $overlap bp!\n";
						$bed{$ID}{val}   += $val*($overlap);
						$bed{$ID}{count} += $overlap;
					}
					#print "\tplus $val * overlap total $bed{$ID}{val} count $bed{$ID}{count}\n";
				}
			}
		}
		#print "\n";
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
			my $ratio = int($bed{$ID}{val} / $bed{$ID}{count}*1000)/1000;
			printf OUT "$chr\t$start\t$end\t$ratio\t$stuff\n";
			#printf OUT "$chr\t$start\t$end\t$ratio\_$bed{$ID}{val}\_$bed{$ID}{count}\t$stuff\n";
		}
		else {
			printf OUT "$chr\t$start\t$end\tNA\t$stuff\n";
		}
	}
	#print " Done!\n";
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
			($chr, $span) = $line =~ /chrom=(.+) span=(\d+)/i;
			$span = 1 if $span == 0;
			if ($chr ne $curr_chr and $curr_chr ne "INIT") {
				print "setting $curr_chr cache at $fh\.$curr_chr\.cache\n";
				$cache -> set("$fh\.$curr_chr\.cache", \%wig);
				%wig = ();
			}
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

	print "setting $curr_chr cache at $fh\.$curr_chr\.cache\n";
	$cache -> set("$fh\.$chr\.cache", \%wig);
	%wig = ();
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
		#next if $line !~ /^chr/;
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
	my ($wigfile, $cbool, $cache_root, @bedfile) = @_;
	print "\n\****************\nChecking sanity of input files\n";
	die "\nError: No input detected\nusage: $0 <wigfile>  <cache_opt [0 to use cache, 1 to ignore/clear]> <cache_root> <multiple_bed_files>\n\n" unless @ARGV > 2;
	die "\nError: Wigfile not defined\nusage: $0 <wigfile>  <cache_opt [0 to use cache, 1 to ignore/clear]> <cache_root> <multiple_bed_files>\n\n" unless defined($wigfile);
	die "\nError: Cache root not defined\nusage: $0 <wigfile>  <cache_opt [0 to use cache, 1 to ignore/clear]> <cache_root> <multiple_bed_files>\n\n" unless defined($cache_root);
	die "\nError: Cache option not defined\nusage: $0 <wigfile>  <cache_opt [0 to use cache, 1 to ignore/clear]> <cache_root> <multiple_bed_files>\n\n" unless defined($cbool);
	die "\nError: Bedfile not defined\nusage: $0 <wigfile>  <cache_opt [0 to use cache, 1 to ignore/clear]> <cache_root> <multiple_bed_files>\n\n" unless defined($bedfile[0]);
	die "\nError: Wigfile $wigfile does not exists: $!\n\n"  unless -e $wigfile;
	die "\nError: Cache root folder $cache_root does not exists: $!\n\n"  unless -d $cache_root;

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

sub find_overlap {
	my ($start1, $end1, $start2, $end2)  = @_;

	#1 		-------------?
	#2 --------------------------?

	if ($start1 <= $end2 and $start1 >= $start2) {

	#1 		-------------
	#2 --------------------------------------------
		if ($end1 <= $end2) {
			return($end1 - $start1+1);
		}
	#1 		--------------------------
	#2 --------------------------
		if ($end1 >= $end2) {
			return($end2 - $start1+1);
		}
	}

	#1 --------------------------?
	#2 	      ---------------?
	elsif ($start2 <= $end1 and $start2 >= $start1) {
		
	#1 --------------------------------------------
	#2 	      ---------------
		if ($end2 <= $end1) {
			return($end2 - $start2+1)
		}

	#1 --------------------------
	#2 	      --------------------------------
		if ($end2 >= $end1) {
			return($end1 - $start2+1);
		}
	}
	else {
	 	die "what is this: $start1 $end1 $start2 $end2\n";
	}
	
}
__END__
Naked juice can only be obtained once
