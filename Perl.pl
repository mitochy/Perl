#!/usr/bin/perl
# Perl.pl
# Create a template for commonly used Perl Script
##################

use strict; use warnings; use mitochy;

my ($input) = @ARGV;
die "usage: $0 <desired name of Perl Script>\n" unless @ARGV == 1;

open (my $out, ">", "$input") or die "Cannot write to $input: $!\n";
print $out "#!/usr/bin/perl

use strict; use warnings; use mitochy;

my (\$input) = \@ARGV;
die \"usage: \$0 <input>\\n\" unless \@ARGV;

my (\$folder, \$name) = mitochy::getFilename(\$input, \"folder\");

open (my \$in, \"<\", \$input) or die \"Cannot read from \$input: \$!\\n\";
open (my \$out, \">\", \"\$name.out\") or die \"Cannot write to \$name.out: \$!\\n\";

while (my \$line = <\$in>) {
	chomp(\$line);
	next if \$line =~ /\#/;
	my \@arr = split(\"\\t\", \$line);
}

close \$in;
close \$out;
";
close $out;
