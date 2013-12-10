#!/usr/bin/perl
# avg_wig_multi_bed.pl by Stella Hartono
# clean up slightly by Yoong Wearn Lim
# Major code revision for speed and correctness by Stella on 23 July 2013
# input a wig and a bed file
# for each entry in the bed file
# find the mean value in the wig file
# should be fast because it uses cache!
#########################################

use strict; use warnings; use Cache::FileCache; use mitochy; use Getopt::Std;
use vars qw($opt_p $opt_w $opt_t $opt_c $opt_r);
getopts("ptw:cr:");
my (@bedfile) = @ARGV;

my $wigfile    = $opt_w;
my $cbool      = defined($opt_c) ? 1 : 0; # If not defined, auto check/auto create. If defined, force create.
my $cache_root = $opt_r;

checksanity($wigfile, $cache_root, @bedfile);

my $wigname = mitochy::getFilename($wigfile);

# Cache setup and process wigfile
my $cache = new Cache::FileCache();
$cache -> set_cache_root($cache_root);
my $fileName = mitochy::getFilename($wigfile, "fullname");
my $test = $cache->get($fileName);

if ($opt_c or not defined($test)) {
	if ($opt_t and not $opt_c) {
		print "Cache for file $fileName does not exists\n\n";
		exit;
	}
	process_wig($wigfile);
}
if ($opt_t) {
	print "Cache for file $fileName exists\n\n";
	exit;
}

print "- Loading Wig file $wigfile ... (This might take a couple minutes depending on the size of your Wig file)\n";

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

	my $count = 0;

	my %final;
	foreach my $ID (sort {$a <=> $b} keys %bed) {
		$count++;
		my $bed_index_start_kilo = $bed{$ID}{bed_index_start_kilo};
		my $bed_index_end_kilo   = $bed{$ID}{bed_index_end_kilo};
		my $bed_index_start_mega = $bed{$ID}{bed_index_start_mega};
		my $bed_index_end_mega 	 = $bed{$ID}{bed_index_end_mega};
		my $start		 = $bed{$ID}{start};
		my $end			 = $bed{$ID}{end};
		my $chr			 = $bed{$ID}{chr};
		if ($chr ne $curr_chr) {
			my $wig = $cache -> get("$fileName\.$chr\.cache");
			if (not defined($wig)) {
				$wig{$chr} = ();
			}
			else {
				%wig = %{$wig};
			}
			$curr_chr = $chr;
		}
		$curr_chr = $chr;
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
					if (not $opt_p and overlap($wigstart, $wigend, $start, $end) == 1) {
						my $overlap = find_overlap($wigstart, $wigend, $start, $end);
						#print "\tWIG $wigstart-$wigend vs BED $start-$end: Overlap $overlap bp!\n";
						$bed{$ID}{val}   += $val*($overlap);
						$bed{$ID}{count} += $overlap;
					}
                                        if ($opt_p and intersect($wigstart, $wigend, $start, $end) == 1) {
                                                for (my $k = $wigstart; $k <= $wigend; $k++) {
                                                        $bed{$ID}{val} .= "$k,$val\_" if intersect($k, $k, $start, $end) == 1;
                                                }
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
		}
		elsif ($opt_p) {
			my $val = defined($bed{$ID}{val}) ? $bed{$ID}{val} : 0;
			printf OUT "$chr\t$start\t$end\t$val\t$stuff\n";
		}
		else {
			printf OUT "$chr\t$start\t$end\tNA\t$stuff\n";
		}
	}
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

	my ($name) = mitochy::getFilename($fh, "fullname");
	print "NAME = $name\n";

	my %wig;
	my $linenumber = 0;
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
				print "setting $curr_chr cache at $name\.$curr_chr\.cache\n";
				$cache -> set("$name\.$curr_chr\.cache", \%wig);
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

	print "setting $curr_chr ($chr) cache at $name\.$curr_chr\.cache\n";
	$cache -> set("$name\.$curr_chr\.cache", \%wig);
	$cache -> set($name, "1");
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
	my ($wigfile, $cache_root, @bedfile) = @_;

	my $usage = "$0 -w <wigfile> -r <cache root> <bedfiles>
-t: Test run, check cache, etc but not doing anything.
-c: Force re-creating wig file cache. Unless specified, it will automatically use the stored one/automatically create if it does not exists.
-p: Point map
";

	print "\n\****************\nChecking sanity of input files\n";
	die "\n$usage\nError: No bed file specified\n\n" 				unless @bedfile >= 1;
	die "\n$usage\nError: Wigfile not defined\n\n" 					unless defined($wigfile);
	die "\n$usage\nError: Cache root not defined\n\n" 				unless defined($cache_root);
	die "\n$usage\nError: Cache option not defined\n\n" 				unless defined($cbool);
	die "\n$usage\nError: Bedfile not defined\n\n" 					unless defined($bedfile[0]);
	die "\n$usage\nError: Wigfile $wigfile does not exists: $!\n\n"  		unless -e $wigfile;
	die "\n$usage\nError: Cache root folder $cache_root does not exists: $!\n\n"  	unless -d $cache_root;
	foreach my $bedfile (@bedfile) {
		die "\n$usage\nError: Bedfile $bedfile does not exists: $!\n\n" unless -e $bedfile;
	}

	print "Sanity check complete. All files seem to be sane.\n\****************\n";

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

";

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

sub intersect {
        my ($start1, $end1, $start2, $end2) = @_;
        return 1 if $start1 >= $start2 and $start1 <= $end2;
        return 1 if $start2 >= $start1 and $start2 <= $end1;
        return 0;
}
__END__
Naked juice can only be obtained once
