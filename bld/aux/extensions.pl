#!/usr/bin/perl


# LICENSE and COPYRIGHT and (DISCLAIMER OF) WARRANTY

# Copyright (c) 1998-2015, Richard A Hogaboom - richard.hogaboom@gmail.com
# All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:

# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.

# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.

# * Neither the name of the {organization} nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. :-)


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

