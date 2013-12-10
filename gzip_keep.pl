#!/usr/bin/perl

use strict; use warnings;

my ($input) = @ARGV;
die "uasge: $0 <input>\n" unless @ARGV == 1;

my $cmd = "gzip -c $input > $input.gz";
system($cmd);
