#!/usr/bin/perl

#
# BldRoutines.pm
#

# import bld global constants
use lib ".";
use BGC;

package BldRoutines
{
    use vars qw(@ISA @EXPORT);
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT = qw
    (
        &init_blddotinfo
        &read_Blddotsig
        &rebuild_target_bool
        &rebuild_exec
        &multiple_sigs
        &buildopt
        &tgtextorfile
        &tgt_signature
        &dirs_pro
        &cvt_dirs_to_array
        &expand_R_specification
        &Bld_section_extract
        &sig_file_update
        &hdr_depend
        &rebuild_src_bool
        &file_sig_calc
        &system_error_msg
        &warning
        &opt_help
    );

    use warnings;
    use diagnostics;
    use autodie;
    use English;
    use File::Find;

    # extract_multiple - for parsing the $BFN DIRS section
    # extract_bracketed - used by extract_multiple for finding '{}''s
    use Text::Balanced qw(
                             extract_multiple
                             extract_bracketed
                         );

    # croak() - used in &main::fatal() to die with better info than die()
    # cluck() - used for full stack trace debugging, outputs to stdout
    # shortmess() - used for full stack trace debugging, returns stack trace
    use Carp qw(
                   croak
                   cluck
                   shortmess
               );

    # sha1_hex - the bld program SHA1 generator
    use Digest::SHA qw(
                          sha1_hex
                      );

    #
    # installed modules
    #

    #use Modern::Perl 2011;

    # this module allows the use of experimental perl language features(given, when, ~~) without generating warnings.
    # to see exactly where smartmatch features are being used just comment out this line.  bld will run, but with warnings
    # everyplace an experimental smartmatch feature is used.
    #use experimental 'smartmatch';
    use experimental 'switch';


    #
    # SUBROUTINES SECTION - Global data independent
    #
    #     Note: All subroutine data comes from their arguments(except globally defined constants).
    #           They return all data thru their return lists.  No global data is used.  Some routines
    #           write to files e.g. bld.warn, bld.info.  Some subroutines read files in order to
    #           calculate signatures.
    #


    # 
    # Usage      : init_blddotinfo( $bld, $bldcmd, $lib_dirs, $opt_s, $opt_r, $opt_lib, $comment_section );
    #
    # Purpose    : write initial info to the bld.info file
    #
    # Parameters : $bld             - the target to built e.g. executable or libx.a or libx.so
    #            : $bldcmd          - cmd used in perl system() call to build $bld object - requires '$bld' and '$O'(object files) internally
    #            : $lib_dirs        - space separated list of directories to search for libraries
    #            : $opt_s           - to use system header files in dependency checking("system" or "nosystem")
    #            : $opt_r           - to inform about any files that will require rebuilding, but do not rebuild("rebuild" or "norebuild")
    #            : $opt_lib         - to do dependency checking on libraries("nolibcheck", "libcheck", "warnlibcheck" or "fatallibcheck")
    #            : $comment_section - holds comment section in Bld file for printing in $BGC::BIFN file
    #
    # Returns    : None
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : None
    #
    sub init_blddotinfo
    {
	my (
	       $bld,
	       $bldcmd,
	       $lib_dirs,
	       $opt_s,
	       $opt_r,
	       $opt_lib,
	       $comment_section,
	   ) = @_;


	open my $bifnfh, ">>", $BGC::BIFN;

	print {$bifnfh} "\nOS: $OSNAME\n";

	print {$bifnfh} "\nbld version: $BGC::VERSION\n\n";

	my $perl = `which perl 2>&1`;
	chomp $perl;
	if ( $perl =~ m{which:\sno} )
	{
	    print {$bifnfh} sprintf "perl full path: No perl in \$PATH\n";
	}
	else
	{
	    print {$bifnfh} sprintf "perl full path: %s\n", $perl;
	    print {$bifnfh} sprintf "perl version: %s\n", `perl -V 2>&1`;
	}

	my $cpp = `which cpp 2>&1`;
	chomp $cpp;
	if ( $cpp =~ m{which:\sno} )
	{
	    print {$bifnfh} sprintf "cpp full path: No cpp in \$PATH\n";
	}
	else
	{
	    print {$bifnfh} sprintf "cpp full path: %s\n", $cpp;
	    print {$bifnfh} sprintf "cpp version: %s\n", `cpp --version 2>&1`;
	}

	my $gcc = `which gcc 2>&1`;
	chomp $gcc;
	if ( $gcc =~ m{which:\sno} )
	{
	    print {$bifnfh} sprintf "gcc full path: No gcc in \$PATH\n";
	}
	else
	{
	    print {$bifnfh} sprintf "gcc full path: %s\n", $gcc;
	    print {$bifnfh} sprintf "gcc version: %s\n", `gcc --version 2>&1`;
	}

	my $gpp = `which g++ 2>&1`;
	chomp $gpp;
	if ( $gpp =~ m{which:\sno} )
	{
	    print {$bifnfh} sprintf "g++ full path: No g++ in \$PATH\n";
	}
	else
	{
	    print {$bifnfh} sprintf "g++ full path: %s\n", $gpp;
	    print {$bifnfh} sprintf "g++ version: %s\n", `g++ --version 2>&1`;
	}

	my $clang = `which clang 2>&1`;
	chomp $clang;
	if ( $clang =~ m{which:\sno} )
	{
	    print {$bifnfh} sprintf "clang full path: No clang in \$PATH\n";
	}
	else
	{
	    print {$bifnfh} sprintf "clang full path: %s\n", $clang;
	    print {$bifnfh} sprintf "clang version: %s\n", `clang --version 2>&1`;
	}

	print {$bifnfh} "\n####################################################################################################\n";
	print {$bifnfh} "comments section of Bld file:\n";
	print {$bifnfh} "$comment_section";

	print {$bifnfh} "\n####################################################################################################\n";
	print {$bifnfh} "EVAL section expansion of \$bld, \$bldcmd and \$lib_dirs mandatory variables(\$O is object files):\n\n";
	print {$bifnfh} "\$bld = $bld\n";
	print {$bifnfh} "\$bldcmd = \"$bldcmd\"\n";
	print {$bifnfh} "\$lib_dirs = \"$lib_dirs\"\n\n";
	print {$bifnfh} "EVAL section expansion of \$opt_s and \$opt_r and \$opt_lib mandatory option variables:\n\n";
	print {$bifnfh} "\$opt_s = \"$opt_s\"\n";
	print {$bifnfh} "\$opt_r = \"$opt_r\"\n";
	print {$bifnfh} "\$opt_lib = \"$opt_lib\"\n";
	close $bifnfh;
    }


    # 
    # Usage      : read_Blddotsig( $bld, \%Sigdata );
    #
    # Purpose    : read $BGC::SIGFN file data into %Sigdata
    #
    # Parameters : $bld      - the target to built e.g. executable or libx.a or libx.so
    #            : \%Sigdata - hash holding $BGC::SIGFN file signature data
    #
    # Returns    : None
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : None
    #
    sub read_Blddotsig
    {
	my (
	       $bld,
	       $Sigdata_ref,
	   ) = @_;


	if ( not -e "$BGC::SIGFN" )
	{
	    return;
	}

	my $RGX_SHA1 = "[0-9a-f]\{40\}";  # regex to validate SHA1 signatures - 40 chars and all 0-9a-f

	# open $BGC::SIGFN signature file
	open my $sigfn, "<", $BGC::SIGFN;

	# build hash of $BGC::SIGFN file signatures with source file names as keys
	while ( my $line = <$sigfn> )
	{
	    next if $line =~ $BGC::RGX_BLANK_LINE;

	    given ( $line )
	    {
		when ( m{^'(.*?)'\s($RGX_SHA1)$} )
		{
		    my $file = $1;
		    my $sigsource = $2;

		    if ( $sigsource !~ m{^$RGX_SHA1$} )
		    {
			&main::fatal("FID 12: Malformed $BGC::SIGFN file - invalid SHA1 signature \$sigsource:\n$line");
		    }

		    $Sigdata_ref->{$file}[$BGC::SIG_SRC] = $sigsource;

		    if ( $file =~ m{$BGC::RGX_LIBS} )
		    {
			$Sigdata_ref->{$bld}[$BGC::LIB_DEP]{$file} = undef;
		    }
		}
		when ( m{^'(.*?)'\s($RGX_SHA1)\s($RGX_SHA1)\s($RGX_SHA1)$} )
		{
		    my $file = $1;
		    my $sigsource = $2;
		    my $sigcmd = $3;
		    my $sigtarget = $4;

		    if ( $sigsource !~ m{^$RGX_SHA1$} )
		    {
			&main::fatal("FID 13: Malformed $BGC::SIGFN file - invalid SHA1 signature \$sigsource:\n$line");
		    }

		    if ( $sigcmd !~ m{^$RGX_SHA1$} )
		    {
			&main::fatal("FID 14: Malformed $BGC::SIGFN file - invalid SHA1 signature \$sigcmd:\n$line");
		    }

		    if ( $sigtarget !~ m{^$RGX_SHA1$} )
		    {
			&main::fatal("FID 15: Malformed $BGC::SIGFN file - invalid SHA1 signature \$sigtarget:\n$line");
		    }

		    $Sigdata_ref->{$file}[$BGC::SIG_SRC] = $sigsource;
		    $Sigdata_ref->{$file}[$BGC::SIG_CMD] = $sigcmd;
		    $Sigdata_ref->{$file}[$BGC::SIG_TGT] = $sigtarget;
		}
		default
		{
		    &main::fatal("FID 16: Malformed $BGC::SIGFN file - invalid format line:\n$line");
		}
	    }
	}
	close $sigfn;
    }


    # 
    # Usage      : my $rebuild = rebuild_target_bool( $bld, $bldcmd, $lib_dirs, $opt_lib, \%Sigdata, \%SigdataNew );
    #
    # Purpose    : boolean indicating to rebuild target if any of three conditions is true:
    #            :     1. target is missing
    #            :     2. signature of target does not exit in $BGC::SIGFN signature file
    #            :     3. signature of target exists in signature file but is changed from actual existing target
    #
    # Parameters : $bld         - the target to built e.g. executable or libx.a or libx.so
    #            : $bldcmd      - cmd used in perl system() call to build $bld object - requires '$bld' and '$O'(object files) internally
    #            : $lib_dirs    - space separated list of directories to search for libraries
    #            : $opt_lib     - to do dependency checking on libraries("nolibcheck", "libcheck", "warnlibcheck" or "fatallibcheck")
    #            : \%Sigdata    - hash holding $BGC::SIGFN file signature data
    #            : \%SigdataNew - hash holding bld calculated command, source, header, library and target file signature data
    #
    # Returns    : $rebuild - bool to rebuild target
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : None
    #
    sub rebuild_target_bool
    {
	my (
	       $bld,
	       $bldcmd,
	       $lib_dirs,
	       $opt_lib,
	       $Sigdata_ref,
	       $SigdataNew_ref,
	   ) = @_;

	my ( $rebuild ) = "false";


	# if $bld does not exists return "true"
	if ( not -f $bld )
	{
	    $rebuild = "true";
	    return $rebuild;
	}

	my $sig = file_sig_calc( $bld, $bld, $bldcmd, $lib_dirs );

	# signature of $bld is defined as the signature of the concatenation of the file $bld and "$bld . $bldcmd . $lib_dirs".
	# this ensures that any change to the file or these mandatory defines forces a rebuild.
	if (
	       (not $bld ~~ %{$Sigdata_ref}) or
	       ($Sigdata_ref->{$bld}[$BGC::SIG_SRC] ne $sig)
	   )
	{
	    # rebuild exec if $bld signature does not exist or signature is different
	    $rebuild = "true";
	    return $rebuild;
	}

	if ( $opt_lib ne "nolibcheck" )
	{
	    my @libs_removed;

	    # do ldd on target executable or library and set target library dependencies and calculate library signatures
	    my $ldd = `ldd $bld 2>&1`;

	    # to do dependency checking on libraries("nolibcheck", "libcheck", "warnlibcheck" or "fatallibcheck")
	    if ( $ldd =~ m{not a dynamic executable} )
	    {
		&main::fatal("FID 20: ldd return: $bld is 'not a dynamic executable'");
	    }

	    # scan ldd return for full path library strings
	    while ( $ldd =~ m{ ^\s+(\S+)\s=>\s(\S+)\s.*$ }gxm )
	    {
		my $libname = $1;
		my $lib = $2;

		# the $lib variable should have either a full path library name or the word 'not'
		if ( $lib =~ m{not} )
		{
		    warning("WID 1: ldd return: $libname library is 'not found'");
		}
		else
		{
		    $SigdataNew_ref->{$bld}[$BGC::LIB_DEP]{$lib} = undef;
		    $SigdataNew_ref->{$lib}[$BGC::SIG_SRC] = file_sig_calc( $lib );
		}
	    }

	    # compare %Sigdata(populated from $BGC::BFN) and %SigdataNew(populated from ldd) for removed libraries
	    foreach my $l ( sort keys %{$Sigdata_ref->{$bld}[$BGC::LIB_DEP]} )
	    {
		if ( not $l ~~ %{$Sigdata_ref->{$bld}[$BGC::LIB_DEP]} )
		{
		    push @libs_removed, $l;
		}
	    }

	    # if removed libraries rebuild and warn/fatal
	    if ( @libs_removed )
	    {
		$rebuild = "true";
		warning("WID 2: Libraries removed: @libs_removed") if $opt_lib eq "warnlibcheck";
		&main::fatal("FID 21: Libraries removed: @libs_removed") if $opt_lib eq "fatallibcheck";
	    }

	    # check each library file for this target and set $rebuild to true if library is new or library has changed
	    foreach my $l ( keys %{$SigdataNew_ref->{$bld}[$BGC::LIB_DEP]} )
	    {
		if ( $l ~~ %{$Sigdata_ref} )
		{
		    # rebuild if library has changed
		    if ( $Sigdata_ref->{$l}[$BGC::SIG_SRC] ne $SigdataNew_ref->{$l}[$BGC::SIG_SRC] )
		    {
			$rebuild = "true";
			warning("WID 3: Library changed: $l") if $opt_lib eq "warnlibcheck";
			&main::fatal("FID 22: Library changed: $l") if $opt_lib eq "fatallibcheck";
		    }
		    next;
		}
		else
		{
		    # rebuild if library is new
		    $rebuild = "true";
		    warning("WID 4: Libraries added: @libs_removed") if $opt_lib eq "warnlibcheck";
		    &main::fatal("FID 23: Libraries added: @libs_removed") if $opt_lib eq "fatallibcheck";
		    next;
		}
	    }
	}

	if ( $rebuild eq "false" )
	{
	    # add old signature to %SigdataNew to output to $BGC::SIGFN file
	    $SigdataNew_ref->{$bld}[$BGC::SIG_SRC] = $Sigdata_ref->{$bld}[$BGC::SIG_SRC];
	}

	return $rebuild;
    }


    # 
    # Usage      : rebuild_exec( $bld, $bldcmd, $lib_dirs, $opt_lib, \%Objects, \%SigdataNew );
    #
    # Purpose    : use $bldcmd with $bld and $O to rebuild the target
    #
    # Parameters : $bld         - the target to built e.g. executable or libx.a or libx.so
    #            : $bldcmd      - cmd used in perl system() call to build $bld object - requires '$bld' and '$O'(object files) internally
    #            : $lib_dirs    - space separated list of directories to search for libraries
    #            : $opt_lib     - to do dependency checking on libraries("nolibcheck", "libcheck", "warnlibcheck" or "fatallibcheck")
    #            : \%Objects    - object files for the build
    #            : \%SigdataNew - hash holding bld calculated command, source, header, library and target file signature data
    #
    # Returns    : None
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : None
    #
    sub rebuild_exec
    {
	my (
	       $bld,
	       $bldcmd,
	       $lib_dirs,
	       $opt_lib,
	       $Objects_ref,
	       $SigdataNew_ref,
	   ) = @_;


	my ( $tmp, $status, $error_msg, $O );

	# extract %Objects hash object file keys and concatenate onto $O
	foreach my $o ( sort keys %{$Objects_ref} )
	{
	   $O .= "$o ";
	}

	$tmp = $bldcmd;
	$tmp =~ s{(\$\w+)}{$1}gee;

	$tmp =~ s{!!!}{\n}g;

	# use $bld and %Objects to rebuild target
	$status = system "$tmp";

	if ( $status != 0 )
	{
	    $error_msg = system_error_msg( $CHILD_ERROR, $ERRNO );

	    &main::fatal("FID 24: Error msg: $error_msg\nCmd: \"$tmp\"\nFail status: $status");
	}

	$SigdataNew_ref->{$bld}[$BGC::SIG_SRC] = file_sig_calc( $bld, $bld, $bldcmd, $lib_dirs );

	if ( $opt_lib ne "nolibcheck" )
	{
	    # do ldd on target executable or library and set target library dependencies and calculate library signatures
	    my $ldd = `ldd $bld 2>&1`;

	    if ( $ldd =~ m{not a dynamic executable} )
	    {
		&main::fatal("FID 25: ldd return: $bld is 'not a dynamic executable'");
	    }

	    while ( $ldd =~ m{ ^\s+(\S+)\s=>\s(\S+)\s.*$ }gxm )
	    {
		my $libname = $1;
		my $lib = $2;

		# the $lib variable should have either a full path library name or the word 'not'
		if ( $lib =~ m{not} )
		{
		    warning("WID 5: ldd return: $libname library is 'not found'");
		}
		else
		{
		    $SigdataNew_ref->{$bld}[$BGC::LIB_DEP]{$lib} = undef;
		    $SigdataNew_ref->{$lib}[$BGC::SIG_SRC] = file_sig_calc( $lib );
		}
	    }
	}

	print "$tmp\n";
	print "$bld rebuilt.\n";
    }


    # 
    # Usage      : multiple_sigs( \%SourceSig );
    #
    # Purpose    : if %SourceSig, for a given $signature(first subscript), has more than one source or library file entry(second subscript)
    #            : then there is a source or library of the same signature in two different places
    #
    # Parameters : \%SourceSig - source signatures - see above
    #
    # Returns    : None
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : 1. adds all warnings to the bld.warn file
    #
    # See Also   : None
    #
    sub multiple_sigs
    {
	my (
	       $SourceSig_ref,
	   ) = @_;


	my $printonce = 0;

	# loop over all unique source file signatures
	foreach my $signature ( sort keys %{$SourceSig_ref} )
	{
	    # get the number of unique source file paths for a given source signature
	    my $n = keys %{$SourceSig_ref->{$signature}};

	    if ( $n > 1 )
	    {
		my ( $warn );

		if ( $printonce == 0 )
		{
		    $warn = "Multiple source files with the same signature:\n";
		    $warn .= "--------------------------------------------------------------------------------------\n";
		    $printonce = 1;
		    chomp $warn;
		    warning("WID 6: $warn");
		}

		$warn = sprintf "%*d  %s\n", 31, $n, $signature;

		# loop over all source file names with $signature
		foreach my $file ( sort keys %{$SourceSig_ref->{$signature}} )
		{
		    $warn .= sprintf "%*s\n", 86, $file;
		}
		chomp $warn;
		warning("WID 7: $warn");
	    }
	}
    }


    # 
    # Usage      : $buildopt = buildopt( $s, $cmd_var_sub, $hdr, $srcext, $Depend_ref, $Objects_ref );
    #
    # Purpose    : return which cmd line option(-c or -S or -E or (none of these)) is in effect
    #
    # Parameters : $s           - code source file
    #            : $cmd_var_sub - the $cmd field of rebuild cmds that has been variable substituted
    #            : $hdr         - set to 'hdr' or 'nothdr' depending on if $s is header processible
    #            : $srcext      - the extension of $s
    #            : \%Depend     - source file extension dependencies e.g. c -> o and m -> o
    #            : \%Objects    - all object files for the build - see above
    #
    # Returns    : $buildopt('c', 'S', 'E', 'n')
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : None
    #
    sub buildopt
    {
        my (
               $s,
               $cmd_var_sub,
               $hdr,
               $srcext,
               $Depend_ref,
               $Objects_ref,
           ) = @_;

        my ( $buildopt );


        # the GNU gcc documentation in chapter '3.2 Options Controlling the Kind of Output' specifies the actions taken by the -c -S -E options.
        # -c
        # Compile or assemble the source files, but do not link. The linking stage simply is not done. The ultimate output is in the form of an object file for each source file.
        # By default, the object file name for a source file is made by replacing the suffix ‘.c’, ‘.i’, ‘.s’, etc., with ‘.o’.
        # Unrecognized input files, not requiring compilation or assembly, are ignored. 
        # 
        # -S
        # Stop after the stage of compilation proper; do not assemble. The output is in the form of an assembler code file for each non-assembler input file specified.
        # By default, the assembler file name for a source file is made by replacing the suffix ‘.c’, ‘.i’, etc., with ‘.s’.
        # Input files that don't require compilation are ignored. 
        # 
        # -E
        # Stop after the preprocessing stage; do not run the compiler proper. The output is in the form of preprocessed source code, which is sent to the standard output.
        # Input files that don't require preprocessing are ignored.

        # process differently depending on which cmd line option(-c or -S or -E or (none of these)) is in effect
        given ( $cmd_var_sub )
        {
            when ( m{\s-c\s} and not m{\s-S\s} and not m{\s-E\s} )
            {
                my ( $n );

                if ( not exists ${$Depend_ref}{$hdr}{'c'}{$srcext}{'ext'} )
                {
                    &main::fatal("FID 29: Invalid combination of source extension: $srcext and build option: -c.");
                }

                # check if '-c' specified multiple times
                $n++ while $cmd_var_sub =~ m{\s-c\s}gx;
                if ( $n > 1 )
                {
                    my ( $tmp );

                    $tmp = $cmd_var_sub;
                    $tmp =~ s{!!!}{\\n}g;
                    warning("WID 8: Multiple instances of '-c' detected in compile options(might just be conditional compilation).\n--->$tmp");
                }

                # change any suffix to .o suffix and push on %Objects for use in rebuild
                my $basenametgt = $s;
                $basenametgt =~ s{$BGC::RGX_FILE_EXT}{o}; # replace from last period to end of string with .o

                # if $basenametgt is already in %Objects fail - two different sources are producing the same object file in
                # the same place e.g. source files a.c and a.m in the same directory will both produce a.o
                foreach my $o ( keys %{$Objects_ref} )
                {
                    if ( $o eq $basenametgt )
                    {
                        &main::fatal("FID 30: Object file conflict - $s produces an object file $basenametgt that already exists.");
                    }
                }

                ${$Objects_ref}{"'$basenametgt'"} = undef;

                $buildopt = 'c';
            }
            when ( not m{\s-c\s} and m{\s-S\s} and not m{\s-E\s} )
            {
                my ( $n );

                if ( not exists ${$Depend_ref}{'hdr'}{'S'}{$srcext}{'ext'} )
                {
                    &main::fatal("FID 31: Invalid combination of source extension: $srcext and build option: -S.");
                }

                # check if '-S' specified multiple times
                $n++ while $cmd_var_sub =~ m{\s-S\s}gx;
                if ( $n > 1 )
                {
                    my ( $tmp );

                    $tmp = $cmd_var_sub;
                    $tmp =~ s{!!!}{\\n}g;
                    warning("WID 9: Multiple instances of '-S' detected in compile options(might just be conditional compilation).\n--->$tmp");
                }

                $buildopt = 'S';
            }
            when ( not m{\s-c\s} and not m{\s-S\s} and m{\s-E\s} )
            {
                my ( $n );

                if ( not exists ${$Depend_ref}{'hdr'}{'E'}{$srcext}{'ext'} )
                {
                    &main::fatal("FID 32: Invalid combination of source extension: $srcext and build option: -E.");
                }

                # check if '-E' specified multiple times
                $n++ while $cmd_var_sub =~ m{\s-E\s}gx;
                if ( $n > 1 )
                {
                    my ( $tmp );

                    $tmp = $cmd_var_sub;
                    $tmp =~ s{!!!}{\\n}g;
                    warning("WID 10: Multiple instances of '-E' detected in compile options(might just be conditional compilation).\n--->$tmp");
                }

                $buildopt = 'E';
            }
            when ( not m{\s-c\s} and not m{\s-S\s} and not m{\s-E\s} )
            {
                if ( not exists ${$Depend_ref}{'hdr'}{'n'}{$srcext}{'ext'} )
                {
                    &main::fatal("FID 33: Invalid combination of source extension: $srcext and build option: non of -c/-S/-E exists.");
                }

                $buildopt = 'n';
            }
            default
            {
                &main::fatal("FID 34: Multiple options -c/-S/-E specified in cmd: $cmd_var_sub.");
            }
        }

        return $buildopt;
    }


    # 
    # Usage      : $tgtextorfile = tgtextorfile( $s, $hdr, $srcext, $srcpath, $srcfile, $buildopt, $SigdataNew_tmp_ref, $Depend_ref );
    #
    # Purpose    : return the $s target extension or file name
    #            : Also:
    #            :     a. if multiple target files in the $srcpath directory &main::fatal()
    #            :     b. if already existing target file calculate then save the signature
    #
    # Parameters : $s               - code source file
    #            : $hdr             - set to 'hdr' or 'nothdr' depending on if $s is header processible
    #            : $srcext          - the extension of $s
    #            : $srcpath         - the file path from $s from File::Spec->splitpath()
    #            : $srcfile         - the file name from $s from File::Spec->splitpath()
    #            : $buildopt        - which cmd line option(-c or -S or -E or (none of these)) is in effect
    #            : \%SigdataNew_tmp - if already existing target file calculate then save the signature
    #            : \%Depend         - source file extension dependencies e.g. c -> o and m -> o
    #
    # Returns    : $tgtextorfile - the $s target extension or file name
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : None
    #
    sub tgtextorfile
    {
        my (
               $s,
               $hdr,
               $srcext,
               $srcpath,
               $srcfile,
               $buildopt,
               $SigdataNew_tmp_ref,
               $Depend_ref,
           ) = @_;

        my ( $tgtextorfile );


        my ( @tgtfiles );
        my ( $tgtfilesboolean ) = "false"; # indicates that the target file is not derived from a file name extension,
				       # but is specified in %Depend as an actual file name

        # accumulate source files in $srcpath
        opendir my ( $dirfh ), $srcpath;
        my @Sources = grep { -f "$srcpath/$_" } readdir $dirfh;
        closedir $dirfh;

        if ( exists ${$Depend_ref}{$hdr}{$buildopt}{$srcext}{'file'} )
        {
	    foreach my $tgtfile ( keys ${$Depend_ref}{$hdr}{$buildopt}{$srcext}{'file'} )
	    {
	        if ( $tgtfile ~~ @Sources )
	        {
		    push @tgtfiles, $tgtfile;
		    $tgtfilesboolean = "true";
	        }
	    }
        }

        if ( exists ${$Depend_ref}{$hdr}{$buildopt}{$srcext}{'ext'} )
        {
	    foreach my $tgtext ( keys ${$Depend_ref}{$hdr}{$buildopt}{$srcext}{'ext'} )
	    {
	        my ( $tmp );

	        $tmp = $srcfile;
	        $tmp =~ s{$BGC::RGX_FILE_EXT}{$tgtext};
	        if ( $tmp ~~ @Sources )
	        {
		    push @tgtfiles, $tmp;
		    $tgtfilesboolean = "false";
	        }
	    }
        }

        # check for multiple target files in the $srcpath directory.  if more than one target file do &main::fatal().
        if ( @tgtfiles > 1 )
        {
	    &main::fatal("FID 35: More than one target file for $srcfile in $srcpath: @tgtfiles");
        }

        if ( @tgtfiles == 1 )
        {
	    if ( $tgtfilesboolean eq "true" )
	    {
	        # save file name
	        $tgtextorfile = $tgtfiles[0];
	    }
	    else
	    {
	        # save file name extension
	        if ( $tgtfiles[0] =~ m{.*[.]$BGC::RGX_FILE_EXT} )
	        {
		    $tgtextorfile = $1;
	        }
	    }

	    # calculate signature of previously already existing target file - if no target file ignore.
	    # why?  if the old target file has been corrupted or compromised then it's signature will not match
	    # the signature in $BGC::BFN even if the source and the cmd to build the source have not changed.  this
	    # should cause a rebuild.  if a re-compile is triggered by either a source change, a build cmd change
	    # or a change in the target file signature then the signature calculated here will be overwritten
	    # by the after compile new signature.
	    ${$SigdataNew_tmp_ref}{$s}[$BGC::SIG_TGT] = file_sig_calc( "$srcpath/$tgtfiles[0]" );
        }
        else
        {
	    # no previous target file in $srcpath directory
	    $tgtextorfile = $BGC::EMPTY;
        }

        return $tgtextorfile;
    }


    # 
    # Usage      : tgt_signature( $s, $hdr, $srcext, $srcpath, $srcfile, $buildopt, $SigdataNew_tmp_ref, $Depend_ref, \@difference, $Targets_ref);
    #
    # Purpose    : calculate the new target file signature and return it in the @SigdataNew_tmp array
    #            :     a. if more than one target file created by $cmd_var_sub do &main::fatal()
    #            :     b. if an identical target file was created earlier do &main::fatal()
    #
    # Parameters : $s               - code source file
    #            : $hdr             - set to 'hdr' or 'nothdr' depending on if $s is header processible
    #            : $srcext          - the extension of $s
    #            : $srcpath         - the file path from $s from File::Spec->splitpath()
    #            : $srcfile         - the file name from $s from File::Spec->splitpath()
    #            : $buildopt        - which cmd line option(-c or -S or -E or (none of these)) is in effect
    #            : \%SigdataNew_tmp - if already existing target file calculate then save the signature
    #            : \%Depend         - source file extension dependencies e.g. c -> o and m -> o
    #            : \@difference     - array of new files created by "$cmd_var_sub" execution
    #            : \%Targets        - all target files for the build - see above
    #
    # Returns    : None
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : None
    #
    sub tgt_signature
    {
        my (
               $s,
               $hdr,
               $srcext,
               $srcpath,
               $srcfile,
               $buildopt,
               $SigdataNew_tmp_ref,
               $Depend_ref,
               $difference_ref,
               $Targets_ref,
           ) = @_;

        my ( $tgtextorfile );


        my ( @tgtfiles );

        if ( exists ${$Depend_ref}{$hdr}{$buildopt}{$srcext}{'file'} )
        {
	    foreach my $tgtfile ( keys ${$Depend_ref}{$hdr}{$buildopt}{$srcext}{'file'} )
	    {
	        if ( $tgtfile ~~ @{$difference_ref} )
	        {
		    push @tgtfiles, $tgtfile;
	        }
	    }
        }

        if ( exists ${$Depend_ref}{$hdr}{$buildopt}{$srcext}{'ext'} )
        {
	    foreach my $tgtext ( keys ${$Depend_ref}{$hdr}{$buildopt}{$srcext}{'ext'} )
	    {
	        my ( $tmp );

	        $tmp = $srcfile;
	        $tmp =~ s{$BGC::RGX_FILE_EXT}{$tgtext};
	        if ( $tmp ~~ @{$difference_ref} )
	        {
		    push @tgtfiles, $tmp;
	        }
	    }
        }

        if ( @tgtfiles == 0 )
        {
	    &main::fatal("FID 38: No target file for $srcfile in $srcpath: @tgtfiles");
        }

        # check for multiple target files created by $cmd_var_sub.  if more than one target file created do &main::fatal().
        if ( @tgtfiles > 1 )
        {
	    &main::fatal("FID 39: More than one target file for $srcfile in $srcpath: @tgtfiles");
        }

        # calculate signature of target
        ${$SigdataNew_tmp_ref}{$s}[$BGC::SIG_TGT] = file_sig_calc( $tgtfiles[0] );

        if ( exists $Targets_ref->{"${srcpath}$tgtfiles[0]"} )
        {
	    &main::fatal("FID 40: An identical target file(name) has been created twice: ${srcpath}$tgtfiles[0]");
        }
        else
        {
	    $Targets_ref->{"${srcpath}$tgtfiles[0]"} = undef;
        }
    }


    # 
    # Usage      : @dirs = dirs_pro( $dirs, $opt_s );
    #
    # Purpose    : Process $BGC::BFN file DIRS section
    #            :     Sequentially, the following tasks are performed:
    #            :     1. compress the DIRS section by eliminating unnecessary white space and unnecessary newlines
    #            :        and converting the input $dirs scalar to the @dirs array with lines of format '$dir:$regex_srcs:$cmd'
    #            :     2. print @dirs lines to $BGC::BIFN - before 'R ' lines recursive expansion
    #            :     3. expand @dirs lines that start with 'R '(recursive).  this will replace the 'R ' line with one or more
    #            :        lines that have recursively the directories below the 'R ' line $dir and the same $regex_srcs and $cmd expressions
    #            :     4. check DIRS section compressed lines for valid format i.e. "^.*:.*:.*$"(DIRS section three field specification)
    #            :        or "^{.*}$"(DIRS section cmd block)
    #            :     5. accumulate lines to be printed to the $BGC::BIFN file:
    #            :        a. DIRS section specification lines with a line count number
    #            :        b. variable interpolated(except for \$s) specification line cmd field
    #            :        c. matching compilation unit source file(s)
    #            :        d. source file header dependencies
    #            :        e. check for the following error conditions:
    #            :           1. either a directory or a source file is not readable
    #            :           2. multiple build entries in $BGC::BFN file DIRS section lines matching same source file
    #            :           3. Bad char(not [\/A-Za-z0-9-_.]) in directory specification "$dir"
    #            :           4. Invalid regular expression - "$regex_srcs"
    #            :           5. No '$s' variable specified in DIRS line command field
    #            :           6. No sources matched in $BGC::BFN DIRS section line $line
    #            :           7. Source file specified in more than one DIRS line specification
    #
    # Parameters : $dirs  - all the DIRS section lines of $BGC::BFN in a single scalar variable
    #            : $opt_s - to use system header files in dependency checking("system" or "nosystem")
    #
    # Returns    : @dirs - the fully processed DIRS section lines of $BGC::BFN in an array
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : None
    #
    sub dirs_pro
    {
        my (
               $dirs,
               $opt_s,
           ) = @_;

        my ( @dirs );


        if ( not defined $dirs )
        {
            &main::fatal("FID 42: $BGC::BFN DIRS section is empty.");
        }

        #  convert $dirs scalar to @dirs array.  $dirs holds the entire contents of the Bld
        # file DIRS section.  @dirs will have one cmd block({}) or one '[R] dir:regex:{cmds}'
        # specification per array element
        @dirs = cvt_dirs_to_array( $dirs );

        if ( @dirs == 0 )
        {
            &main::fatal("FID 46: $BGC::BFN DIRS section is empty.");
        }

        {
            # print @dirs lines to $BGC::BIFN - before 'R ' lines recursive expansion

            open my $bifnfh, ">>", $BGC::BIFN;

            print {$bifnfh} "\n####################################################################################################\n";
            print {$bifnfh} "$BGC::BFN file DIRS section specification lines with irrelevant white space compressed out:\n\n";

            foreach my $line ( @dirs )
            {
                my ( $tmp );

                $tmp = $line;
                $tmp =~ s{!!!}{\\n}g;
                print {$bifnfh} "$tmp\n";
            }
            print {$bifnfh} "\n";
            close $bifnfh;
        }

        # expand @dirs lines that start with 'R '(recursive)
        @dirs = expand_R_specification( @dirs );

        {
            # print @dirs lines to $BGC::BIFN - after 'R ' lines recursive expansion

            open my $bifnfh, ">>", $BGC::BIFN;

            print {$bifnfh} "\n####################################################################################################\n";
            print {$bifnfh} "R recursively expanded and numbered DIRS section specification lines:\n\n";

            # log @dirs to $BGC::BIFN
            {
                my $count = 0;
                foreach my $line ( @dirs )
                {
                    my ( $tmp );

                    $tmp = $line;
                    $tmp =~ s{!!!}{\\n}g;

                    $count++;
                    printf {$bifnfh} "%4d  %s\n", $count, $tmp;
                }
            }
            print {$bifnfh} "\n";
            close $bifnfh;
        }

        # check DIRS section compressed lines for valid format i.e. "^.*:.*:.*$"(DIRS section three field specification)
        # or "$BGC::RGX_CMD_BLOCK"(DIRS section cmd block)
        foreach my $line ( @dirs )
        {
            if ( not $line =~ m{^.*:.*:.*$} and not $line =~ m{$BGC::RGX_CMD_BLOCK} )
            {
                &main::fatal("FID 47: $BGC::BFN DIRS section line is incorrectly formatted(see $BGC::BIFN): $line");
            }
        }

        {
	    # accumulate lines to be printed to the $BGC::BIFN file:
	    #     a. DIRS section specification lines with a line count number
	    #     b. variable interpolated(except for \$s) specification line cmd field
	    #     c. matching compilation unit source file(s)
	    #     d. source file header dependencies
	    #     e. check for the following error conditions:
	    #        1. either a directory or a source file is not readable
	    #        2. multiple build entries in $BGC::BFN file DIRS section lines matching same source file
	    #        3. Bad char(not [\/A-Za-z0-9-_.]) in directory specification "$dir"
	    #        4. Invalid regular expression - "$regex_srcs"
	    #        5. No '$s' variable specified in DIRS line command field
	    #        6. No sources matched in $BGC::BFN DIRS section line $line
	    #        7. Source file specified in more than one DIRS line specification
	    my ( @tmp ) = &main::accum_blddotinfo_output( $opt_s, @dirs );

	    my $fatal_not_readable = shift @tmp;
	    my $fatal_multiple_sources = shift @tmp;
	    my @bldcmds =  @tmp;

	    # write fatal msg to $BGC::BFFN
	    if ( $fatal_not_readable eq "true" )
	    {
	        {
		    open my $bffnfh, ">>", $BGC::BFFN;
		    print {$bffnfh} "Directory or source file specification in $BGC::BFN file DIRS line cannot be read.\n";
		    close $bffnfh;
	        }
	    }

	    # write fatal msg to $BGC::BFFN
	    if ( $fatal_multiple_sources eq "true" )
	    {
	        {
		    open my $bffnfh, ">>", $BGC::BFFN;
		    print {$bffnfh} "Multiple build entries in $BGC::BFN file DIRS section lines matching same source file.\n";
		    close $bffnfh;
	        }
	    }

	    if ( $fatal_not_readable eq "true" or $fatal_multiple_sources eq "true" )
	    {
	        my $msg = "$BGC::BFN DIRS section has one or more of:\n".
		          "a. Directory or source file specification cannot be read\n".
		          "b. No sources matched\n".
		          "c. Multiple build entries matching same source file";

	        warning("WID 15: $msg");

	        &main::fatal("FID 54: $msg   - see $BGC::BWFN.\n");
	    }

	    {
	        open my $bifnfh, ">>", $BGC::BIFN;

	        print {$bifnfh} "\n####################################################################################################\n";
	        print {$bifnfh} "a. DIRS section specification lines\n".
		          "    b. variable interpolated(except for \$s) specification line cmd field\n".
		          "        c. matching compilation unit source file(s)\n".
		          "            d. source file header dependencies:\n\n";

	        foreach my $line ( @bldcmds )
	        {
		    $line =~ s{!!!}{\\n}g;
		    print {$bifnfh} "$line";
	        }
	        close $bifnfh;
	    }
        }

        return @dirs;
    }


    # 
    # Usage      : @dirs = cvt_dirs_to_array( $dirs );
    #
    # Purpose    : convert $dirs scalar to @dirs array.  $dirs holds the entire contents of the Bld
    #            : file DIRS section.  @dirs will have one cmd block({}) or one '[R] dir:regex:{cmds}'
    #            : specification per array element.
    #            :     1. compress out irrelevant whitespace.  some spaces are important to preserve e.g. "-I.  -c"
    #            :     2. to "-I. -c", keeps a single space between command line options.  this also makes rebuilding
    #            :     3. insensitive to the number of spaces between command line options.  other spaces are
    #            :     4. irrelevant, such as the spaces before and after the chars "{};:\n" and are eliminated.
    #
    # Parameters : $dirs - all the DIRS section lines of $BGC::BFN in a single scalar variable
    #
    # Returns    : @dirs - @dirs will have one cmd block({}) or one '[R] dir:regex:{cmds}' specification per array element
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : None
    #
    sub cvt_dirs_to_array
    {
        my (
               $dirs,
           ) = @_;

        my ( @dirs );


        # this should return an array with either the '$dir:$regex:' string followed by the '$cmd' string or a cmd block string '{}' by itself
        my @fields = extract_multiple(
				         $dirs,                                      # extract fields from DIRS section
				         [ sub { extract_bracketed($_[0],'{}') } ],  # extract {} stuff
				         undef,                                      # match till end of string
				         0                                           # return unmatched strings as well - the stuff outside of {}
				     );

        foreach my $line ( @fields )
        {
	    if ( $line =~ m{^[{].*[}]$}s ) # matches a line of '{stuff}' exactly - a $cmd
	    {
	        $line =~ s{\n}{!!!}gs; # translate \n's in a '{}' to '!!!'
	    }

	    # compress multiple whitespace chars([ \t\n\r\f\v]) to a single space
	    $line =~ s{\s+}{ }g;
	    $line =~ s{^\s+}{}g;
	    $line =~ s{!!!\s}{!!!}g;

	    # all of the following substitutions are designed to eliminate single spaces before/after the four chars "{};:"
	    $line =~ s{\s\{}{\{}g;
	    $line =~ s{\{\s}{\{}g;
	    $line =~ s{\s\}}{\}}g;
	    $line =~ s{\}\s}{\}}g;
	    $line =~ s{\s\;}{\;}g;
	    $line =~ s{\;\s}{\;}g;
	    $line =~ s{\s:}{:}g;
	    $line =~ s{:\s}{:}g;
        }

        # reassemble '$dir:$regex:' and '$cmd' strings to a single string '$dir:$regex:$cmd' and push on @dirs
        # or push a cmd block string '{}' by itself onto @dirs
        my $prevline = "cmd";
        my $dir_regex;
        foreach my $line ( @fields )
        {
	    next if $line =~ $BGC::RGX_BLANK_LINE;

	    if ( $line =~ m{^[{].*[}]$} ) # matches a line of '{stuff}' exactly - a $cmd
	    {
	        if ( $prevline eq "cmd" )
	        {
		    if ( not $line =~ m{$BGC::RGX_CMD_BLOCK} )
		    {
		        &main::fatal("FID 43: $BGC::BFN DIRS section line is not valid(doesn't match $BGC::RGX_CMD_BLOCK): $line");
		    }

		    # lone cmd block string
		    push @dirs, $line;
	        }
	        else
	        {
		    if ( not $dir_regex.$line =~ m{$BGC::RGX_VALID_DIRS_LINE} )
		    {
		        &main::fatal("FID 44: $BGC::BFN DIRS section line is not valid(doesn't match $BGC::RGX_VALID_DIRS_LINE): $dir_regex.$line");
		    }

		    # concatenate '$dir:$regex:' and '$cmd' strings
		    push @dirs, $dir_regex.$line;
		    $prevline = "cmd";
	        }
	    }
	    else
	    {
	        if ( not $line =~ m{$BGC::RGX_VALID_DIRS_LINE} )
	        {
		    &main::fatal("FID 45: $BGC::BFN DIRS section line is not valid(doesn't match $BGC::RGX_VALID_DIRS_LINE): $line");
	        }

	        # save '$dir:$regex:' line for next loop iteration
	        $dir_regex = $line;
	        $prevline = "dir_regex";
	    }
        }

        return @dirs;
    }


    # 
    # Usage      : @dirs = expand_R_specification( @dirs );
    #
    # Purpose    : expand DIRS section @dirs lines that start with 'R '(recursive) in the directory first field
    #
    # Parameters : @dirs - @dirs will have one cmd block({}) or one '[R] dir:regex:{cmds}' specification per array element
    #
    # Returns    : @tmp - R(recursive) line specification expanded @dirs
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : None
    #
    sub expand_R_specification
    {
        my (
               @dirs,
           ) = @_;


        my ( %dirs ); # hash holding unique subdirs of the "$dir" directory
        my ( @tmp );

        # accumulate expanded and unexpanded DIRS lines in @tmp
        foreach my $line ( @dirs )
        {
	    # if '\s*R\s+' appears at the start of a DIRS line then do recursive build.  replace each R line with one or
	    # more lines - each line with the same regex field and build command field, but each line directory first
	    # field is the start directory and all recursive subdirectories
	    if ( $line =~ m{^\s*R\s+(.*?)\s*(:.*)} )
	    {
	        my $dir = $1;
	        my $restofline = $2;

	        %dirs = ();
	        # recursively find all subdirs from $dir as the start point
	        # Note: if a directory is empty find() will not find it.  this is not a problem since a DIRS section
	        #       line with no source files to match cause a &main::fatal() error.
	        find(sub {no warnings 'File::Find'; $dirs{"$File::Find::dir"} = 1;}, $dir);

	        # push recursively expanded dirs onto @tmp
	        foreach my $k ( sort keys %dirs )
	        {
		    push @tmp, "$k$restofline";
	        }
	    }
	    else
	    {
	        push @tmp, $line;
	    }
        }

        # replace @dirs with new expanded array
        return @tmp;
    }


    # 
    # Usage      : my ( @tmp ) = Bld_section_extract();
    #
    # Purpose    : scan $BGC::BFN file accumulating EVAL lines(in @eval) and DIRS lines(in $dirs) for later processing.
    #
    # Parameters : None
    #
    # Returns    : $comment_section - 
    #            : @eval - 
    #            : $dirs - 
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : None
    #
    sub Bld_section_extract
    {
        my (
           ) = @_;

        my ( @eval );
        my ( $bfnfile );
        my ( $dirs, $comment_section, $eval_section, $dirs_section );

        # slurp in whole file to scalar
        if ( not -e "$BGC::BFN" )
        {
	    &main::fatal("FID 3: $BGC::BFN file missing.");
        }
        open my $bfnfh, "<", "Bld";
        my @bfnfile = <$bfnfh>;
        foreach my $e ( @bfnfile ){ $bfnfile .= $e }
        close $bfnfh;

        # match $BGC::BFN for EVAL and DIRS sections and extract them
        if (
	       $bfnfile =~ m{
			        (.*?)  # matches comment section - minimal match guarantees that only first EVAL will match
			        ^EVAL$ # matches ^EVAL$ line
			        (.*?)  # matches EVAL section lines - minimal match guarantees that only first DIRS will match
			        ^DIRS$ # matches ^DIRS$ line
			        (.*)   # matches DIRS section lines - maximal match picks up rest of file
			    }xms
           )
        {
	    $comment_section = $1;
	    $eval_section = $2;
	    $dirs_section = $3;
        }
        else
        {
	    &main::fatal("FID 4: $BGC::BFN invalid format - need EVAL and DIRS sections.");
        }

        # accumulate EVAL section lines in @eval
        while ( $eval_section =~ m{ ^(.*)$ }gxm )
        {
	    my $eval_line = $1;

	    # ignore if comment or blank line(s)
	    next if ( $eval_line =~ $BGC::RGX_COMMENT_LINE or $eval_line =~ $BGC::RGX_BLANK_LINE );

	    push @eval, $eval_line;
        }

        # accumulate DIRS section lines in $dirs - including newlines
        while ( $dirs_section =~ m{ ^(.*)$ }gxm )
        {
	    my $dirs_line = $1;

	    # ignore if comment or blank line(s)
	    next if ( $dirs_line =~ $BGC::RGX_COMMENT_LINE or $dirs_line =~ $BGC::RGX_BLANK_LINE );

	    $dirs .= "$dirs_line\n";
        }

        return ( $comment_section, @eval, $dirs );
    }


    # 
    # Usage      : sig_file_update( $bld, \%SigdataNew );
    #
    # Purpose    : replace $BGC::SIGFN file with new %SigdataNew entries and write $BGC::BIFN file source files section
    #
    # Parameters : $bld         - the target to built e.g. executable or libx.a or libx.so
    #            : \%SigdataNew - hash holding bld calculated command, source, header, library and target file signature data
    #
    # Returns    : None
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : None
    #
    sub sig_file_update
    {
        my (
               $bld,
               $SigdataNew_ref,
           ) = @_;

        my ( @system_hdrs, @user_hdrs, @system_libraries, @user_libraries, @code, @exec );
        my ( @bifn, @sigfn );
        my ( $vol, $path, $file );


        # for each source decide which array it belongs in
        foreach my $s ( sort keys %{$SigdataNew_ref} )
        {
            ( $vol, $path, $file ) = File::Spec->splitpath( $s );

            given ( $s )
            {
                when ( m{ ^\/.*[.]$BGC::RGX_HDR_EXT$ }x )
                {
                    # collect system header files
                    push @system_hdrs, sprintf "%s", $s;
                }
                when ( m{ ^[^\/].*[.]$BGC::RGX_HDR_EXT$ }x )
                {
                    # collect not full path header files
                    push @user_hdrs, sprintf "%s", $s;
                }
                when (
                         (
                             $path =~ m{^\/.*} and
                             $file =~ m{$BGC::RGX_LIBS}
                         )
                         and not
                         (
                             # don't pick up the build target
                             $file =~ m{$bld} and
                             $path eq $BGC::EMPTY
                         )
                     )
                {
                    # collect library files
                    push @system_libraries, sprintf "%s", $s;
                }
                when (
                         (
                             $path =~ m{^[^\/].*} and
                             $file =~ m{$BGC::RGX_LIBS}
                         )
                         and not
                         (
                             # don't pick up the build target
                             $file =~ m{$bld} and
                             $path eq $BGC::EMPTY
                         )
                     )
                {
                    # collect library files
                    push @user_libraries, sprintf "%s", $s;
                }
                when ( defined $SigdataNew_ref->{$s}[$BGC::SIG_CMD] and defined $SigdataNew_ref->{$s}[$BGC::SIG_TGT] )
                {
                    # collect code files
                    push @code, sprintf "%s", $s;
                }
                default
                {
                    # collect executable
                    push @exec, sprintf "%s", $s;
                }
            }
        }

        @system_hdrs = sort sourcesort @system_hdrs if ( @system_hdrs > 1 );
        @user_hdrs = sort sourcesort @user_hdrs if ( @user_hdrs > 1 );
        @system_libraries = sort sourcesort @system_libraries if ( @system_libraries > 1 );
        @user_libraries = sort sourcesort @user_libraries if ( @user_libraries > 1 );
        @code = sort sourcesort @code if ( @code > 1 );

        push @bifn, "--------------------------------------------------\n";
        push @bifn, "System headers:\n";
        foreach my $s ( @system_hdrs )
        {
            push @bifn, "'$s'\n";
            push @sigfn, sprintf "'%s' %s\n", $s, $SigdataNew_ref->{$s}[$BGC::SIG_SRC];
        }
        push @bifn, "\n";
        push @sigfn, "\n";

        push @bifn, "--------------------------------------------------\n";
        push @bifn, "User headers:\n";
        foreach my $s ( @user_hdrs )
        {
            push @bifn, "'$s'\n";
            push @sigfn, sprintf "'%s' %s\n", $s, $SigdataNew_ref->{$s}[$BGC::SIG_SRC];
        }
        push @bifn, "\n";
        push @sigfn, "\n";

        push @bifn, "--------------------------------------------------\n";
        push @bifn, "System libraries:\n";
        foreach my $s ( @system_libraries )
        {
            push @bifn, "'$s'\n";
            push @sigfn, sprintf "'%s' %s\n", $s, $SigdataNew_ref->{$s}[$BGC::SIG_SRC];
        }
        push @bifn, "\n";
        push @sigfn, "\n";

        push @bifn, "--------------------------------------------------\n";
        push @bifn, "User libraries:\n";
        foreach my $s ( @user_libraries )
        {
            push @bifn, "'$s'\n";
            push @sigfn, sprintf "'%s' %s\n", $s, $SigdataNew_ref->{$s}[$BGC::SIG_SRC];
        }
        push @bifn, "\n";
        push @sigfn, "\n";

        push @bifn, "--------------------------------------------------\n";
        push @bifn, "Source files:\n";
        foreach my $s ( @code )
        {
            push @bifn, "'$s'\n";
            push @sigfn, sprintf "'%s' %s %s %s\n", $s, $SigdataNew_ref->{$s}[$BGC::SIG_SRC], $SigdataNew_ref->{$s}[$BGC::SIG_CMD], $SigdataNew_ref->{$s}[$BGC::SIG_TGT];
        }
        push @bifn, "\n";
        push @sigfn, "\n";

        push @bifn, "--------------------------------------------------\n";
        push @bifn, "Build target:\n";
        foreach my $s ( @exec )
        {
            push @bifn, "'$s'\n";
            push @sigfn, sprintf "'%s' %s\n", $s, $SigdataNew_ref->{$s}[$BGC::SIG_SRC];
        }

        open my $bifnfh, ">>", $BGC::BIFN;
        print {$bifnfh} "\n####################################################################################################\n";
        print {$bifnfh} "List of all build - System headers(full path)\n".
                        "                    User headers(relative path)\n".
                        "                    System libraries(full path)\n".
                        "                    User libraries(relative path)\n".
                        "                    Source files(relative path)\n".
                        "                    Build target(bld directory):\n\n";

        foreach my $line ( @bifn )
        {
            print {$bifnfh} "$line";
        }
        close $bifnfh;

        open my $sigfn, ">", $BGC::SIGFN;
        foreach my $line ( @sigfn )
        {
            print $sigfn "$line";
        }
        close $sigfn;
    }


    # 
    # Usage      : @hdeps = hdr_depend( $cmd_var_sub, $s, $addoption );
    #
    # Purpose    : use the cpp cmd to determine header file dependencies
    #
    # Parameters : $cmd_var_sub - a build command that has been variable expanded(Command Variable Substitution)
    #            : $s           - source file to do dependency checking on
    #            : $addoption   - additional cpp options
    #
    # Returns    : @hdeps - list of header file dependencies of the form: 
    #            :              src/include/head.h   # header file relative to the bld directory
    #            :              /usr/include/sys/cdefs.h  # full path system header file
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : 1. cpp: -H  - print the name of each header file used
    #            :         -M  - Instead of outputting the result of preprocessing, output a rule suitable for make
    #            :               describing the dependencies of the main source file
    #            :         -MG - do not require that header file dependencies are present in the path
    #            : 2. the directives -I(include directories), -D(defines), and -U(undefines) are passed to cpp
    #            : 3. header file dependency checking is done by cpp for both the gnu gcc and clang compiler systems
    #            :    since 'clang -E' will not work on .l or .y files
    #
    # See Also   : 'man cpp'(www.gnu.org) and http://gcc.gnu.org/onlinedocs/cpp/
    #
    sub hdr_depend
    {
        my (
               $cmd_var_sub,
               $s,
               $addoption,
           ) = @_;

        my ( $IDU );


        # copy -I(include directories), -D(define), and -U(undefine) directives from $cmd_var_sub to $IDU
        $IDU = $BGC::EMPTY;
        while ( $cmd_var_sub =~ m{ (-I\s*\S+|-D\s*\S+|-U\s*\S+) }gx )
        {
            $IDU .= $1.$BGC::SPACE;
        }

        my ( %hdr_dep, @hdr_dep );

        # use cpp to determine header file dependencies - redirect stderr to stdout so `` will collect it to the $cppret return variable.
        #
        # if header files are missing or have syntax errors, msgs of the following form are returned - each with the word 'error' embedded.
        #     if a header file is missing:
        #         c/main.c:1:18: fatal error: head.h: No such file or directory
        #         compilation terminated.
        #     if a header file has syntax errors:
        #         . h/head.h
        #         h/head.h:6:2: error: invalid preprocessing directive #i
        #
        my $cppret = `cpp -H -M $addoption $IDU "$s" 2>/dev/null`;

        # if the word ' error '(spaces required) appears in the cpp output &main::fatal()
        if ( $cppret =~ m{\serror\s}m )
        {
            my ( $cpperror );

            $cpperror = "Error: 'cpp -H -M $addoption $IDU $s' return:\n";
            $cpperror .= "BEGIN\n";
            # indents $cppret output by four spaces
            while ( $cppret =~ m{ ^(.*)$ }gxm )
            {
                $cpperror .= "    $1\n";
            }
            $cpperror .= "END\n\n";

            print "$cpperror\n";

            &main::fatal("FID 58: $cpperror");
        }

        # populate %hdr_dep with all unique header files returned by cpp
        while ( $cppret =~ m{ (\S+[.]$BGC::RGX_HDR_EXT)\b }gx )
        {
            $hdr_dep{$1} = undef;
        }

        # extract hash keys and sort them - if you don't do this then each time the hash keys are extracted, even with the same data in the hash,
        # 'keys %hash' will return randomly ordered keys due to hash keys return uncertainty
        @hdr_dep = sort sourcesort (keys %hdr_dep);

        return @hdr_dep;
    }


    # 
    # Usage      : $boolean = rebuild_src_bool( $s, $tgtextorfile, $Sigdata_ref, \%SigdataNew_tmp )
    #
    # Purpose    : determine if source file $s needs to be rebuilt based on signature data in %Sigdata and %SigdataNew
    #
    # Parameters : $s               - relative path source file name starting from the bld home directory,
    #            :                    should only be compilation units(not header files)
    #            : $tgtextorfile    - the file name extension of the target file to be built from $s
    #            : \%Sigdata        - reference to hash holding $BGC::SIGFN file data
    #            : \%SigdataNew_tmp - hash holding bld calculated command, source, header, library and target file signature data
    #
    # Returns    : "true"(rebuild $s) or "false"(do not rebuild $s)
    #            :     the following conditions return "true" on the $s source file
    #            :     1. source is new
    #            :     2. source signature has changed
    #            :     3. build command has changed
    #            :     4. no target file extension found
    #            :     5. target file does not exist
    #            :     6. target signature does not currently exist
    #            :     7. target has changed
    #            :     8. header is new
    #            :     9. header has changed
    #            :     10. library is new
    #            :     11. library has changed
    #            : otherwise return "false"
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : None
    #
    sub rebuild_src_bool
    {
        my (
               $s,
               $tgtextorfile,
               $Sigdata_ref,
               $SigdataNew_ref,
           ) = @_;

        my ( $tgtfile );


        # rebuild if source is new
        return "true" if not $s ~~ %{$Sigdata_ref};

        # rebuild if source signature has changed
        return "true" if $Sigdata_ref->{$s}[$BGC::SIG_SRC] ne $SigdataNew_ref->{$s}[$BGC::SIG_SRC];

        # rebuild if build command has changed
        return "true" if $Sigdata_ref->{$s}[$BGC::SIG_CMD] ne $SigdataNew_ref->{$s}[$BGC::SIG_CMD];

        # rebuild if no target file extension found
        return "true" if $tgtextorfile eq $BGC::EMPTY;

        # if $tgtextorfile has an embedded period, then it is a full file name
        if ( $tgtextorfile =~ m{ [.] }x )
        {
            my ( $vol, $path, $file ) = File::Spec->splitpath( $s );
            $tgtfile = $path . $tgtextorfile;
        }
        else
        {
            $tgtfile = $s;
            $tgtfile =~ s{$BGC::RGX_FILE_EXT}{$tgtextorfile}; # replace from last period to end of string with .$tgtextorfile
        }

        # rebuild if target file does not exist
        return "true" if not -e "$tgtfile";

        # rebuild if target signature does not currently exist
        return "true" if not defined $Sigdata_ref->{$s}[$BGC::SIG_TGT] or not defined $SigdataNew_ref->{$s}[$BGC::SIG_TGT];

        # rebuild if target has changed
        return "true" if $Sigdata_ref->{$s}[$BGC::SIG_TGT] ne $SigdataNew_ref->{$s}[$BGC::SIG_TGT];

        # check each header file for this source
        foreach my $h ( keys %{$SigdataNew_ref->{$s}[$BGC::HDR_DEP]} )
        {
            # rebuild if header is new
            return "true" if not $h ~~ %{$Sigdata_ref};

            # rebuild if header has changed
            return "true" if $Sigdata_ref->{$h}[$BGC::SIG_SRC] ne $SigdataNew_ref->{$h}[$BGC::SIG_SRC];
        }

        return "false";
    }


    # 
    # Usage      : $sig = file_sig_calc( $filename );
    #            : $sig = file_sig_calc( $bld, $bld, $bldcmd, $lib_dirs );
    #            : $sig = file_sig_calc( $filename, @otherstrings );
    #
    # Purpose    : calculate SHA1 signature of $filename and all remaining arguments concatenated together
    #
    # Parameters : $filename     - file that will be opened and read in
    #            : @otherstrings - other strings to be concatenated to $filename
    #
    # Returns    : if $filename exists
    #            :     return SHA1 signature of "$filename . @otherstrings"
    #            : else
    #            :     &main::fatal()
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : Digest::SHA
    #
    sub file_sig_calc
    {
        my (
               $filename,
               @otherstrings,
           ) = @_;

        my ( $inputfile, $inputfilesize );


        # calculate signature of $filename . @otherstrings

        if ( not -e $filename )
        {
            &main::fatal("FID 59: File: $filename does not exit.");
        }

        if ( not -e $BGC::BFN )
        {
            &main::fatal("FID 60: File: open() error on $filename.");
        }
        open my $fh, "<", $filename;

        $inputfilesize = -s "$filename";

        if ( $inputfilesize == 0 )
        {
            &main::fatal("FID 61: File: $filename is of zero size - a useful signature cannot be taken of an empty file.");
        }

        read $fh, $inputfile, $inputfilesize;
        close $fh;

        my $otherstrings = $BGC::EMPTY;
        foreach my $string ( @otherstrings )
        {
            $otherstrings .= $string;
        }

        return sha1_hex( $inputfile . $otherstrings );
    }


    # 
    # Usage      : $error_msg = system_error_msg( $CHILD_ERROR, $ERRNO );
    #
    # Purpose    : evaluate the error return from the system() call perl builtin
    #
    # Parameters : $?($CHILD_ERROR) - the special variable used to indicate the status return from the system() call
    #            : $!($OS_ERROR     - the special variable used to indicate the C(errno) value returned on error
    #
    # Returns    : $error_msg - an error msg
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : $exit_value  = $CHILD_ERROR >> 8;
    #            : $signal_num  = $CHILD_ERROR & 127;
    #            : $dumped_core = $CHILD_ERROR & 128;
    #
    # See Also   : The perldoc.perl.org perlvar "Error Variables" section
    #
    sub system_error_msg
    {
        my (
               $child_error,
               $os_error,
           ) = @_;

        my ( $error_msg );


        if ( $child_error == -1 )
        {
            $error_msg = "failed to execute: $os_error";
        }
        elsif ( $child_error & 127 )
        {
            my ( $signal, $dump );

            $signal = ($child_error & 127);
            $dump = ($child_error & 128) ? 'with' : 'without';
            $error_msg = "child died with signal $signal, $dump coredump";
        }
        else
        {
            my ( $return );

            $return = $child_error >> 8;
            $error_msg = "child exited with value $return";
        }

        return $error_msg;
    }


    # 
    # Usage      : warning("warning msg");
    #
    # Purpose    : accept msg as arg and append it to $BGC::BWFN file, then return.
    #
    # Parameters : $msg - a single scalar msg
    #
    # Returns    : None
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : &main::fatal()
    #
    sub warning
    {
        my (
               $msg,
           ) = @_;

        my ( $package, $filename, $line ) = caller;

        open my $bwfnfh, ">>", $BGC::BWFN;
        printf {$bwfnfh} "line: %4d - %s\n\n", $line, $msg;
        close $bwfnfh;

        return;
    }


    # 
    # Usage      : bld -h
    #
    # Purpose    : help option
    #
    # Parameters : None
    #
    # Returns    : Does not return
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : Do 'perldoc bld'
    #
    sub opt_help
    {
        print "usage: bld [-h]\n";
        print "    -h          - this message.(exit)\n";

        print "$BGC::USAGE";

        exit;
    }


    #
    # file local routines
    #
 
    # 
    # Usage      : @system_hdrs = sort sourcesort @system_hdrs if ( @system_hdrs > 1 );
    #            : @user_hdrs = sort sourcesort @user_hdrs if ( @user_hdrs > 1 );
    #            : @system_libraries = sort sourcesort @system_libraries if ( @system_libraries > 1 );
    #            : @user_libraries = sort sourcesort @user_libraries if ( @user_libraries > 1 );
    #            : @code = sort sourcesort @code if ( @code > 1 );
    #
    # Purpose    : for sorting $SIGFN and $BIFN source output - for file "base.ext" sort on base first and then on ext
    #
    # Parameters : None
    #
    # Returns    : None
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : 1. always used with the sort builtin e.g. 'sort sourcesort @array'
    #
    # See Also   : None
    #
    sub sourcesort
    {
        my ( $vol, $path, $basea, $baseb );
        my ( $na, $nb, $afile, $bfile, $aext, $bext );


        $na = $nb = 0;

        given( $a )
        {
            when( m{ ^\/.*[.]$BGC::RGX_HDR_EXT$ }x )    { $na = 1; }
            when( m{ ^\/.*$BGC::RGX_LIBS$ }x )          { $na = 2; }
            when( m{ ^[^\/].*$BGC::RGX_LIBS$ }x )       { $na = 3; }
            when( m{ ^[^\/].*[.]$BGC::RGX_HDR_EXT$ }x ) { $na = 4; }
            when( m{ .*[.]$BGC::RGX_SRC_EXT$ }x )       { $na = 5; }
            default { &main::fatal("FID 62: Invalid source format - $a"); }
        }

        given( $b )
        {
            when( m{ ^\/.*[.]$BGC::RGX_HDR_EXT$ }x )    { $nb = 1; }
            when( m{ ^\/.*$BGC::RGX_LIBS$ }x )          { $nb = 2; }
            when( m{ ^[^\/].*$BGC::RGX_LIBS$ }x )       { $nb = 3; }
            when( m{ ^[^\/].*[.]$BGC::RGX_HDR_EXT$ }x ) { $nb = 4; }
            when( m{ .*[.]$BGC::RGX_SRC_EXT$ }x )       { $nb = 5; }
            default { &main::fatal("FID 63: Invalid source format - $b"); }
        }

        ( $vol, $path, $basea ) = File::Spec->splitpath( $a );
        if ( $basea =~ m{(.*)[.]$BGC::RGX_FILE_EXT} )
        {
            $afile = $1;
            $aext = $2;
        }
        else
        {
            &main::fatal("FID 64: Valid file extension not found in $basea");
        }

        ( $vol, $path, $baseb ) = File::Spec->splitpath( $b );
        if ( $baseb =~ m{(.*)[.]$BGC::RGX_FILE_EXT} )
        {
            $bfile = $1;
            $bext = $2;
        }
        else
        {
            &main::fatal("FID 65: Valid file extension not found in $baseb");
        }

        # DEBUG
=for
        print "DEBUG:\n".
              "a: %1s %16s %8s %64s     b: %1s %16s %8s %64s\n", $na, $afile, $aext, $a, $nb, $bfile, $bext, $b;
              "ENDDEBUG\n";
=cut

        $na cmp $nb or
        $afile cmp $bfile or
        $aext cmp $bext;
    }
}

1;

