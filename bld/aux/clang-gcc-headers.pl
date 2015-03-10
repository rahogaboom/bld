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
# use clang and cpp to determine the header file dependencies of a c source file(main.c)
# and print a list of unique headers for each method and compare the lists.  they should
# be the same.  actually, some standard headers like stddef.h and stdarg.h have different
# locations than standard directories.  also, if header files are needed then the cmds
# must be modified to find them.
#

# clang will not do header file dependency checking on .l or .y files - cpp will

my $a = `clang -E main.c`;

while ( $a =~ m/^.*"(.*?\.[h]+)".*$/gm )
{
    my $b = $1;
    $h{$b} = undef;
}

foreach my $k ( keys %h )
{
    print "$k\n";
}

print "\n\n";

my $c = `cpp -M -H main.c 2>&1`;

while ( $c =~ m/^(.*)$/gm )
{
    my $b = $1;
    $b =~ s{[.]+\s+}{};
    if ( $b =~ m/^\S+[.][h]+$/ )
    {
        $g{$b} = undef;
    }
}

foreach my $k ( keys %g )
{
    print "$k\n";
}

