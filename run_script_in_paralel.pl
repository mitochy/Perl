#!/usr/bin/perl

use strict; use warnings; use mitochy; use Getopt::Std;
use vars qw($opt_t $opt_m);
getopts("t:m:");

my ($script, $folder, $ext, $mode) = @ARGV;
$SIG{INT} = \&interrupt;

my $checkTime = defined($opt_t) ? $opt_t : 10;
my $maxRun    = defined($opt_m) ? $opt_m : 50;

if ($checkTime !~ /^\d+$/) {
	print "Format error on check time (-t) ($checkTime), using default 10s\n";
	$checkTime = 10;
}

if ($maxRun !~ /^\d+$/) {
	print "Format error on check time (-m) ($maxRun), using default 50\n";
	$maxRun = 50;
}

die "usage: $0 [Option] <YourScript_and_argv_and_argv2_and_etc> <folder> <file extension/wild card name in that folder> <mode>

Option: 
-t: Time (seconds) to check between script (mode 2 only). Default: 10s
Must be non-negative integer

Script should be more than 5 character long so it is unique

Mode:
- Mode can be no mode, which means run one by one
- 1 to run files in array
- 2 to run in paralel
argv is the options for your script

Example:

Folder MONTHS contain these files
myscript.pl
data1_JANUARY.TXT
data2_JANUARY.TXT
data3_JANUARY.TXT
data4_JANUARY.TXT
data5_JANUARY.TXT
data6_JANUARY.TXT
data1_FEBRUARY.TXT
data1_DEC.TXT
data1_YESTERDAY.TXT
data2_FEBRUARY.TXT
data3_.TXT
data1_JANUARY.TXT
You want to run script myscript.pl on files that end with _JANUARY.TXT in folder MONTHS

- No mode
Say myscript.pl usage statement is: <myscript.pl> <data file> <option 1: window size> <option 2: step size>
in which you want myscript.pl to run one by one:
myscript.pl data1_JANUARY.TXT 2000 1 &&
myscript.pl data2_JANUARY.TXT 2000 1 &&
myscript.pl data3_JANUARY.TXT 2000 1 &&
etc

From folder MONTHS this is the command:
run_script_in_paralel.pl myscript.pl_and_2000_and_1 ./ _JANUARY.txt

- In paralel (mode option 2)

myscript.pl usage statement is the same as above: <myscript.pl> <data file> <option 1: window size> <option 2: step size>
in which you want myscript.pl to run in paralel like this:
myscript.pl data1_JANUARY.TXT 2000 1 &
myscript.pl data2_JANUARY.TXT 2000 1 &
myscript.pl data3_JANUARY.TXT 2000 1 &
etc

From folder MONTHS this is the command:
run_script_in_paralel.pl myscript.pl_and_2000_and_1 ./ _JANUARY.txt 2

- Run all files in array (mode option 1)

Say myscript.pl usage statement is
<myscript.pl> <option 1: window size> <option 2: step size> <data file 1> < data file 2> <data file 3> <etc>
In which you want myscript.pl to run like this:
myscript.pl 2000 1 data1_JANUARY.TXT data2_JANUARY.TXT data3_JANUARY.TXT data4_JANUARY.TXT data5_JANUARY.TXT

instead of typing all files you do option 1:
run_script_in_paralel.pl myscript.pl_and_2000_and_1 ./ _JANUARY.txt 1
" unless @ARGV >= 3;
$mode = 0 if not defined($mode);

print "
SCRIPT	= $script
FOLDER	= $folder
EXT   	= $ext
MODE  	= $mode
FILES	= $folder\/*.$ext

";

my @files = <$folder/*$ext>;
if (@files == 0) {
	print "Warning: File with full extension \"$ext\" does not exist. Are you sure you want to run wildcard search (*$ext*) instead? (Enter to continue, Ctrl+C to exit)\n";
	<STDIN>;
	@files = <$folder/*$ext*>;
}
if (@files == 0) {
	print "Fatal Error: Exited because file with extension or wild card \"*$ext*\" not found in folder $folder\n\n";
	exit;
}

if ($mode == 3) {
	my @cmd;
	foreach my $file (@files) {
		my ($scripts, @ARGV) = split("_and_", $script);
	        my $perlthis = "$scripts $file @ARGV";
	
	        $perlthis = "$scripts ";
	        foreach my $ARGV (@ARGV) {
			$ARGV =~ s/_/ /i if defined($ARGV) and ($ARGV =~ /\-/i);
	                $perlthis .= "$ARGV " if defined($ARGV) and ($ARGV) =~ /\-/i;
	        }
	
	        $perlthis .= "$file ";
	        foreach my $ARGV (@ARGV) {
	                $perlthis .= "$ARGV " if defined($ARGV) and ($ARGV) !~ /\-/i;
	        }
		if (-e "/home/mitochi/Desktop/Work/Codes/Perl/essential/$scripts") {push(@cmd, "/home/mitochi/Desktop/Work/Codes/Perl/essential/$perlthis & ")}
		elsif (-e "/home/mitochi/Desktop/Work/Codes/Perl/batchscript/$scripts") {push(@cmd, "/home/mitochi/Desktop/Work/Codes/Perl/batchscript/$perlthis & ")}
		else {push(@cmd, "$perlthis & ")}
	        print "$perlthis\n";
		#system($perlthis) == 0 or die "Error running $script: $!\n";
	}
	foreach my $cmd (sort @cmd) {
		print "$cmd\n";
	}
	exit;
}
if ($mode == 1 ) {
	my ($scripts, @ARGV) = split("_and_", $script);
	my $perlthis = "$scripts @ARGV @files";
	print "$perlthis\n";
	system($perlthis) == 0 or die "Error running $scripts: $!\n";
	exit;
}

if ($mode == 2) {
	my @cmd;
	foreach my $file (@files) {
		my ($scripts, @ARGV) = split("_and_", $script);
	        my $perlthis = "$scripts $file @ARGV";
	
	        $perlthis = "$scripts ";
	        foreach my $ARGV (@ARGV) {
			$ARGV =~ s/_/ /i if defined($ARGV) and ($ARGV =~ /\-/i);
	                $perlthis .= "$ARGV " if defined($ARGV) and ($ARGV) =~ /\-/i;
	        }
	
	        $perlthis .= "$file ";
	        foreach my $ARGV (@ARGV) {
	                $perlthis .= "$ARGV " if defined($ARGV) and ($ARGV) !~ /\-/i;
	        }
		if (-e "/home/mitochi/Desktop/Work/Codes/Perl/essential/$scripts") {push(@cmd, "/home/mitochi/Desktop/Work/Codes/Perl/essential/$perlthis & ")}
		elsif (-e "/home/mitochi/Desktop/Work/Codes/Perl/batchscript/$scripts") {push(@cmd, "/home/mitochi/Desktop/Work/Codes/Perl/batchscript/$perlthis & ")}
		else {push(@cmd, "$perlthis & ")}
	}

	
	if (@cmd <= $maxRun) {
		foreach my $cmd (sort @cmd) {
			print "Running $cmd\n";
			system($cmd);
		}
	}

	else {
		# Get script name to be pgrep'd
		my $script_to_check = check_script($script);

		# The run script
		for (my $i = 0; $i < @cmd; $i++) {

			# Get number of script still running
			my $number_of_script_still_running = `pgrep $script_to_check | wc -l`;
			chomp($number_of_script_still_running);
			# If currently running script is more than $maxRun-1, we pause for 10s
			if ($number_of_script_still_running >= $maxRun) {
				print "Number of script still running is more than $maxRun-1 ($number_of_script_still_running): Check every $checkTime seconds until they are less than $maxRun\n";
				while (1) {
					$number_of_script_still_running = `pgrep $script_to_check | wc -l`;
					chomp($number_of_script_still_running);
					last if $number_of_script_still_running < $maxRun;
					sleep $checkTime;
				}
			}
			print "Running $cmd[$i] (Number of script $script still running = $number_of_script_still_running)\n";
			system($cmd[$i]);

		}
	}
	exit;
}

foreach my $file (sort @files) {
	my ($scripts, @ARGV) = split("_and_", $script);
	my $perlthis = "$scripts $file @ARGV";
	
	$perlthis = "$scripts ";
	foreach my $ARGV (@ARGV) {
		$ARGV =~ s/_/ /ig if defined($ARGV) and ($ARGV =~ /\-/i);
		$perlthis .= "$ARGV " if defined($ARGV) and ($ARGV) =~ /\-/i;
	}

	$perlthis .= "$file ";
	foreach my $ARGV (@ARGV) {
		$perlthis .= "$ARGV " if defined($ARGV) and ($ARGV) !~ /\-/i;
	}
	print STDERR "$perlthis\n";
	system($perlthis) == 0 or die "Error running $script: $!\n";
}

sub check_script {
	my ($script) = @_;

	# Get script name to be checked
	my ($script_to_check) = mitochy::getFilename($script);
	die "Fatal Error: Your script name cannot be determined using mitochy.pm getFilename function. (Your script: $script)\n" unless defined($script_to_check) and $script_to_check !~ /^$/;
	print "Full script name = $script\nShort script name = $script_to_check\n\n";

	# If length of script is less than 6, then attach script extension to script name
	if (length($script_to_check) < 6) {
		my ($script_extension) = $script =~ /\.(\w+)$/;

		# If there is no extenstion, exit because the name might be non unique
		if (not defined($script_extension)) {
			die "Fatal Error on Script $script: Name of your script ($script_to_check) is less than 6 character long.\nTherefore to make it unique, it must have an extension.\nE.g. \"my.pl\" instead of just \"my\" - Your Script: $script\n";
		}

		$script_to_check .= ".$script_extension";
	}

	# Else, we only use first 5 characters of script
	elsif (length($script_to_check) > 15) {
		($script_to_check) = $script_to_check =~ /^(.{15})/;
	}
	return($script_to_check);
}

sub interrupt {
	print "\n Exited by user: $SIG{INT}",@_,"\n";
	exit;
}
