#!/usr/bin/perl

#
# extensions.pl - program to execute the 'find . -name '*'' cmd in the current directory
# and list the number of file name extensions for each detected unique extension
#

use strict;
use warnings;
use diagnostics;
use Carp;

use Getopt::Long;

my
(
    %files,
    %extension,

    # cmd line options or cmd line related variables
    $opt_h,       # -h cmd line option, see ext -h
    $opt_s,       # -s cmd line option, see ext -h
);


GetOptions
(
    "h" => \$opt_h,
    "s" => \$opt_s
) or fatal("GetOptions() failed(use bld -h).");

# help msg
opt_help() if $opt_h;

croak("No arguments allowed.") if @ARGV != 0;

my @files = `find . -name '*';`;

croak("'find' cmd found no files.") if @files == 0;

foreach my $line ( @files )
{
    if ( $line =~ m/.*\.([^.\/\\]*?)$/ )
    {
        my $extension = $1;

        $extension{$extension} += 1;
        push @{$files{$extension}}, $line;
    }
}

my @k = sort keys %extension;

my $total_extensions = scalar @k;
print "Total extensions: $total_extensions\n\n";

foreach my $k ( @k )
{
    printf "extension: %20s  count: %6d\n", $k, $extension{$k};

    if ( not $opt_s )
    {
        foreach my $k ( @{$files{$k}} )
        {
            printf "%s", $k;
        }
        print "\n\n";
    }
}

sub opt_help
{
    print "usage: extensions [-h] [-s] <file>\n";
    print "   -h          - this message.(exit)\n";
    print "   -s          - exclude printing of relative path file names\n";

    exit;
}

