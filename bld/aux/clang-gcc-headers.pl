#!/usr/bin/perl

# use clang and cpp to determine the header file dependencies of a c source file(main.c)
# and print a list of unique headers for each method and compare the lists.  they should
# be the same.  actually, some standard headers like stddef.h and stdarg.h have different
# locations than standard directories.  also, if header files are needed then the cmds
# must be modified to find them.

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

