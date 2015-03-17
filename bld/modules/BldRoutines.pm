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
# BldRoutines.pm
#

package BldRoutines
{
    # import bld global constants
    use lib ".";
    use BGC;

    use vars qw(@ISA @EXPORT);
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT = qw
    (
        src_pro
        accum_blddotinfo_output
        variable_match
        init_blddotinfo
        read_Blddotsig
        rebuild_target_bool
        rebuild_exec
        multiple_sigs
        buildopt
        tgtextorfile
        tgt_signature
        dirs_pro
        cvt_dirs_to_array
        expand_R_specification
        Bld_section_extract
        sig_file_update
        hdr_depend
        rebuild_src_bool
        file_sig_calc
        system_error_msg
        warning
        fatal
        opt_help
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

    # longmess() - used for full stack trace debugging, returns stack trace
    use Carp qw(
                   longmess
               );

    # sha1_hex - the bld program SHA1 generator
    use Digest::SHA qw(
                          sha1_hex
                      );

    #
    # installed modules
    #

    #use Modern::Perl 2014;

    # this module allows the use of experimental perl language features(given, when, ~~) without generating warnings.
    # to see exactly where smartmatch features are being used just comment out this line.  bld will run, but with warnings
    # everyplace an experimental smartmatch feature is used.
    use experimental 'switch';


    #
    # GLOBAL DATA INDEPENDENT SUBROUTINES
    #
    #     Note: All subroutine data comes from their arguments(except globally defined constants).
    #           They return all data thru their return lists.  No global data is used.  Some routines
    #           write to files e.g. bld.warn, bld.info.  Some subroutines read files in order to
    #           calculate signatures.
    #


    # 
    # Usage      : $truefalse = src_pro( $s, $cmd_var_sub, $bld, $opt_s, $opt_r, \%Sigdata, \%Depend, \%SigdataNew, \%SourceSig, \%Objects, \%Targets );
    #
    # Purpose    : source file processing
    #
    # Parameters : $s           - code source file
    #            : $cmd_var_sub - rebuild cmds - all perl variables should already be interpolated
    #            : $bld         - the target to built e.g. executable or libx.a or libx.so
    #            : $opt_s       - to use system header files in dependency checking("system" or "nosystem")
    #            : $opt_r       - to inform about any files that will require rebuilding, but do not rebuild("rebuild" or "norebuild")
    #            : \%Sigdata    - hash holding $SIGFN file signature data
    #            : \%Depend     - source file extension dependencies e.g. c -> o and m -> o
    #            : \%SigdataNew - hash holding bld calculated command, source, header, library and target file signature data
    #            : \%SourceSig  - source signatures - see above
    #            : \%Objects    - all object files for the build - see above
    #            : \%Targets    - all target files for the build - see above
    #
    # Returns    : boolean("true"/"false") to indicate that any source file was re-built and thus $bld will need rebuilding
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : None
    #
    sub src_pro
    {
        my (
               $s,
               $cmd_var_sub,
               $bld,
               $opt_s,
               $opt_r,
               $Sigdata_ref,
               $Depend_ref,
               $SigdataNew_ref,
               $SourceSig_ref,
               $Objects_ref,
               $Targets_ref,
           ) = @_;

        if ( @_ != 11 )
        {
            my $msg = "FATAL: src_pro(): wrong number of args";
            fatal($msg);
        }

        my ( $hdr, $srcext, $tgtextorfile );
        my ( $buildopt );
        my ( $srcvol, $srcpath, $srcfile );
        my ( %SigdataNew_tmp );


        ( $srcvol, $srcpath, $srcfile ) = File::Spec->splitpath( $s );

        # set $srcext for later use
        if ( $srcfile =~ m{.*[.]$RGX_FILE_EXT} )
        {
            $srcext = $1;
        }
        else
        {
            my $msg = sprintf "FATAL: Valid file extension not found in %s", $s;
            fatal($msg);
        }

        # set $hdr to indicate the $s source file is or is not header processible
        given ( $srcext )
        {
            when (
                     $srcext ~~ $Depend{'hdr'}{'c'} or
                     $srcext ~~ $Depend{'hdr'}{'S'} or
                     $srcext ~~ $Depend{'hdr'}{'E'} or
                     $srcext ~~ $Depend{'hdr'}{'n'}
                 )
            {
                # $s is a hdr processible file
                $hdr = "hdr";
            }
            when ( $srcext ~~ $Depend{'nothdr'}{'c'} )
            {
                # $s is a not hdr processible file
                $hdr = "nothdr";
            }
            default
            {
                my $msg = sprintf "FATAL: %s DIRS section source file %s has no recognizable extension(see %Depend)", $BFN, $s;
                fatal($msg);
            }
        }

        # calculate signature of source file and save in %SigdataNew
        $SigdataNew_tmp{$s}[$SIG_SRC] = file_sig_calc( $s );

        {
            my ( $cmd_sig );

            # for the signature calculation only compress out '!!!'s - this makes the signature insensitive to
            # bracketing changes or added/deleted newlines.  when the cmd is executed and printed, however, the
            # '!!!'s will be translated back to newlines.
            $cmd_sig = $cmd_var_sub;
            $cmd_sig =~ s{!!!}{}g;

            # calculate signature of variable substituted source $cmd_sig
            $SigdataNew_tmp{$s}[$SIG_CMD] = sha1_hex( $cmd_sig );
        }

        # populate source signature hash %SourceSig - see definition above
        ${$SourceSig_ref}{"$SigdataNew_tmp{$s}[$SIG_SRC]"}{$s} = undef;

        # return which cmd line option(-c or -S or -E or (none of these)) is in effect
        $buildopt = buildopt( $s, $cmd_var_sub, $hdr, $srcext, $Depend_ref, $Objects_ref );

        # return the $s target extension or file name
        $tgtextorfile = tgtextorfile( $s, $hdr, $srcext, $srcpath, $srcfile, $buildopt, \%SigdataNew_tmp, $Depend_ref );

        if ( $hdr eq "hdr" )
        {
            my ( @hdeps );

            # calculate signatures of header files for this source code file($s).
            # For each header file $h(in @hdeps):
            #     a. add $SigdataNew{$h}[SIG_SRC] = sha1_hex( $h );
            #     b. add $SigdataNew{$s}[HDR_DEP]{$h} = undef;

            # for interpolated $cmd_var_sub of this source find the header file dependencies.
            # do not require header files to be searched for in the path(-MG).
            @hdeps = hdr_depend( $cmd_var_sub, $s, "-MG" );

            foreach my $h ( @hdeps )
            {
                if ( $opt_s eq "nosystem" and $h =~ m{ ^\/.*[.]$RGX_HDR_EXT$ }x ) {next;}

                # calculate signature of header file
                if ( not $h ~~ %SigdataNew_tmp )
                {
                    $SigdataNew_tmp{$h}[$SIG_SRC] = file_sig_calc( $h );
                }

                # add header files to %SigdataNew header dependencies
                $SigdataNew_tmp{$s}[$HDR_DEP]{$h} = undef;
            } # END: foreach my $line ( @hdeps ){}
        }

        # DEBUG
=for
        print "DEBUG:\n".
              "\$s = $s\n".
              "\$buildopt = $buildopt\n".
              "\$srcext = $srcext\n".
              "\$tgtextorfile = $tgtextorfile\n".
              "\$srcvol = $srcvol\n".
              "\$srcpath = $srcpath\n".
              "\$srcfile = $srcfile\n".
              "ENDDEBUG\n";
=cut

        # see if $s should be re-built by testing %Sigdata against %SigdataNew
        if ( rebuild_src_bool( $s, $tgtextorfile, $Sigdata_ref, \%SigdataNew_tmp ) eq "true" )
        {
            # print source file names that will be re-built, but do not rebuild
            if ( $opt_r eq "norebuild" )
            {
                print "---WILL--- be re-built: $s\n";
            }
            else
            {
                my ( $status, $error_msg );
                my ( %before, %after, @difference );
                my ( $dirfh );

                # create hash of files in the bld directory before "$cmd_var_sub" execution
                opendir $dirfh, ".";
                while ( readdir $dirfh )
                {
                    $_ =~ s{\n}{};
                    $before{"$_"} = undef;
                }
                closedir $dirfh;

                $cmd_var_sub =~ s{!!!}{\n}g;

                # execute $cmd's
                $status = system "$cmd_var_sub";

                if ( $status != 0 )
                {
                    $error_msg = system_error_msg( $CHILD_ERROR, $ERRNO );

                    my $msg = sprintf "FATAL: Error msg: %s\nCmd: \"%s\"\nFail status: %s", $error_msg, $cmd_var_sub, $status;
                    fatal($msg);
                }

                print "$cmd_var_sub\n";

                # create hash of files in the bld directory after "$cmd_var_sub" execution
                opendir $dirfh, ".";
                while ( readdir $dirfh )
                {
                    $_ =~ s{\n}{};
                    $after{"$_"} = undef;
                }
                closedir $dirfh;

                # create array of new files created by "$cmd_var_sub" execution
                foreach my $f ( keys %after )
                {
                    if ( not exists $before{$f} )
                    {
                        push @difference, $f;
                    }
                }

                if ( @difference == 0 )
                {
                    my $msg = sprintf "FATAL: No new target files created by command:\nCmd: \"%s\"", $cmd_var_sub;
                    fatal($msg);
                }

                # 
                tgt_signature( $s, $hdr, $srcext, $srcpath, $srcfile, $buildopt, \%SigdataNew_tmp, $Depend_ref, \@difference, $Targets_ref);

                # move all new files in the bld directory created by "$cmd_var_sub" execution
                # to the directory of the $s source
                while ( @difference )
                {
                    my ( $newfile );

                    $newfile = shift @difference;

                    $status = system "mv", "$newfile", "$srcpath";

                    if ( $status != 0 )
                    {
                        $error_msg = system_error_msg( $CHILD_ERROR, $ERRNO );

                        my $msg = sprintf "FATAL: Error msg: %s\n\"mv %s %s\" fail status: %s", $error_msg, $newfile, $srcpath, $status;
                        fatal($msg);
                    }
                }
            }

            # since the $cmd_var_sub has built successfully add the tmp data stored in the local
            # hash %SigdataNew_tmp to the passed in \%SigdataNew hash references
            $SigdataNew_ref->{$s}[$SIG_SRC] = $SigdataNew_tmp{$s}[$SIG_SRC];
            $SigdataNew_ref->{$s}[$SIG_CMD] = $SigdataNew_tmp{$s}[$SIG_CMD];
            $SigdataNew_ref->{$s}[$SIG_TGT] = $SigdataNew_tmp{$s}[$SIG_TGT];

            # populate source signature hash %SourceSig - see definition above
            ${$SourceSig_ref}{"$SigdataNew_tmp{$s}[$SIG_SRC]"}{$s} = undef;

            if ( $hdr eq "hdr" )
            {
                foreach my $h ( keys %SigdataNew_tmp )
                {
                    if ( $h ne $s )
                    {
                        $SigdataNew_ref->{$h}[$SIG_SRC] = $SigdataNew_tmp{$h}[$SIG_SRC];
                        $SigdataNew_ref->{$s}[$HDR_DEP]{$h} = $SigdataNew_tmp{$s}[$HDR_DEP]{$h};

                        # populate source signature hash %SourceSig - see definition above
                        ${$SourceSig_ref}{"$SigdataNew_tmp{$h}[$SIG_SRC]"}{$h} = undef;
                    }
                }
            }

            return "true";
        }
        else
        {
            # print source file names that will not be re-built
            if ( $opt_r eq "norebuild" )
            {
                print "$s will NOT be re-built.\n";
            }
            else
            {
                print "$s is up to date.\n";
            }

            # since the $cmd_var_sub has built successfully add the tmp data stored in the local
            # hash %SigdataNew_tmp to the passed in \%SigdataNew hash references
            $SigdataNew_ref->{$s}[$SIG_SRC] = $SigdataNew_tmp{$s}[$SIG_SRC];
            $SigdataNew_ref->{$s}[$SIG_CMD] = $SigdataNew_tmp{$s}[$SIG_CMD];
            $SigdataNew_ref->{$s}[$SIG_TGT] = $SigdataNew_tmp{$s}[$SIG_TGT];

            # populate source signature hash %SourceSig - see definition above
            ${$SourceSig_ref}{"$SigdataNew_tmp{$s}[$SIG_SRC]"}{$s} = undef;

            if ( $hdr eq "hdr" )
            {
                foreach my $h ( keys %SigdataNew_tmp )
                {
                    if ( $h ne $s )
                    {
                        # move header file signatures and source header file dependencies to \%SigdataNew
                        $SigdataNew_ref->{$h}[$SIG_SRC] = $SigdataNew_tmp{$h}[$SIG_SRC];
                        $SigdataNew_ref->{$s}[$HDR_DEP]{$h} = $SigdataNew_tmp{$s}[$HDR_DEP]{$h};

                        # populate source signature hash %SourceSig - see definition above
                        ${$SourceSig_ref}{"$SigdataNew_tmp{$h}[$SIG_SRC]"}{$h} = undef;
                    }
                }
            }

            return "false";
        }
    }


    # 
    # Usage      : my ( @tmp ) = accum_blddotinfo_output( $opt_s, @dirs );
    #
    # Purpose    : accumulate lines to be printed to the $BIFN file:
    #            :     a. DIRS section specification lines with a line count number
    #            :     b. variable interpolated(except for \$s) specification line cmd field
    #            :     c. matching compilation unit source file(s)
    #            :     d. source file header dependencies
    #            :     e. check for the following error conditions:
    #            :        1. either a directory or a source file is not readable
    #            :        2. multiple build entries in $BFN file DIRS section lines matching same source file
    #            :        3. Bad char(not [\/A-Za-z0-9-_.]) in directory specification "$dir"
    #            :        4. Invalid regular expression - "$regex_srcs"
    #            :        5. No '$s' variable specified in DIRS line command field
    #            :        6. No sources matched in $BFN DIRS section line $line
    #            :        7. Same source file specified in more than one DIRS line specification
    #
    # Parameters : $opt_s - to use system header files in dependency checking("system" or "nosystem")
    #            : @dirs  - @dirs will have one cmd block({}) or one '[R] dir:regex:{cmds}' specification per array element
    #
    # Returns    : @bldcmds - output for Bld.info
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : None
    #
    sub accum_blddotinfo_output
    {
        my (
               $opt_s,
               @dirs,
           ) = @_;

        # output for Bld.info
        my ( @bldcmds );

        # hash with keys of the source file names(basename only) for detection of multiple source
        # files of the same name in different DIRS line specifications.  if a file name is detected
        # in multiple directories warning() and print all of the directories.  if a file name is
        # specified twice in the same directory fatal() and print the directory/filename.
        my ( %s );

        # integer count of the DIRS section specification lines
        my ( $count ) = 0;


        foreach my $line ( @dirs )
        {
            $count++;

            push @bldcmds, sprintf "----------\n%4d  %s\n", $count, $line;

            given ( $line )
            {
                when ( m{$RGX_CMD_BLOCK} )
                {
                    # DIRS section cmd block
                    my $cmd = $line;

                    # variable interpolate cmd block
                    my $cmd_var_sub = &main::var_sub( $cmd );

                    push @bldcmds, "      $cmd_var_sub\n";
                    push @bldcmds, "\n";
                }
                when ( m{$RGX_VALID_DIRS_LINE} )
                {
                    # DIRS section three field specification line
                    my ($dir, $regex_srcs, $cmd);

                    chomp $line;
                    ($dir, $regex_srcs, $cmd) = split $COLON, $line;

                    # variable interpolate $dir variable
                    $dir = &main::var_sub( $dir );

                    # check $dir for existence and readability
                    if ( not -e "$dir" or not -r "$dir" )
                    {
                        my $msg = sprintf "FATAL: Directory %s does not exist or is not readable in %s file DIRS line:\n   %4d  %s", $dir, $BFN, $count, $line;
                        fatal($msg);
                    }

                    # check $dir for invalid chars
                    if ( $dir !~ m{^$RGX_VALID_PATH_CHARS+$} )
                    {
                        my $msg = sprintf "FATAL: Bad(really weird) char(not %s) in directory specification: %s", $RGX_VALID_PATH_CHARS, $dir;
                        fatal($msg);
                    }

                    # check $regex_srcs for valid regular expression
                    eval { $EMPTY =~ m{$regex_srcs} };
                    if ( $EVAL_ERROR )
                    {
                        my $msg = sprintf "FATAL: Invalid regular expression - \"%s\".", $regex_srcs;
                        fatal($msg);
                    }

                    # variable interpolate $cmd - exclude $s interpolation
                    my $cmd_var_sub = &main::var_sub( $cmd, '$s' );

                    # scan $cmd_var_sub for '$s' and fatal() if none found and warning() if more than one found
                    {
                        my ( $n );

                        while ( $cmd_var_sub =~ m{ \$s }gx )
                        {
                            $n++;
                        }

                        if ( $n == 0 )
                        {
                            my $msg = sprintf "FATAL: No '\$s' variable specified in DIRS line command field: %s", $cmd_var_sub;
                            fatal($msg);
                        }

                        if ( $n > 1 )
                        {
                            my $msg = sprintf "WARNING: Multiple(%s) '\$s' variables specified in DIRS line command field: %s", $n, $cmd_var_sub;
                            warning($msg);
                        }
                    }

                    push @bldcmds, "      $cmd_var_sub\n";

                    # accumulate source files that match this directory search criteria
                    opendir my ( $dirfh ), $dir;
                    my @Sources = map { "$dir/$_" } grep { $_ =~ m{$regex_srcs} and -f "$dir/$_" } readdir $dirfh;
                    closedir $dirfh;

                    if ( @Sources == 0 )
                    {
                        my $msg = sprintf "FATAL: No sources matched in %s DIRS section line: %s", $BFN, $line;
                        fatal($msg);
                    }

                    {
                        # dummy variable
                        my ( $vol );

                        # directory path
                        my ( $path );

                        # source file name(with extension)
                        my ( $basename );


                        # loop over all source files matched by this ($dir, $regex_srcs, $cmd) DIRS line specification $regex_srcs
                        foreach my $s ( @Sources )
                        {
                            # check $s for existence and readability
                            if ( not -e "$s" or not -r "$s" )
                            {
                                my $msg = sprintf "FATAL: Source file %s does not exist or is not readable.\n   %4d  %s", $s, $count, $line;
                                fatal($msg);
                            }

                            # extract the basename
                            ( $vol, $path, $basename ) = File::Spec->splitpath( $s );

                            {
                                my ( $dirs_line );

                                # save DIRS line, $dirs_line, in %s indexed by $basename and $path
                                $dirs_line = sprintf "%4d  %s", $count, $line;
                                $s{"$basename"}{"$path"}{"$dirs_line"} = undef;
                            }

                            push @bldcmds, "          $s\n";

                            my ( @hdeps, $srcext );

                            # capture file name extension
                            if ( $s =~ m{.*[.]$RGX_FILE_EXT} )
                            {
                                $srcext = $1;
                            }
                            else
                            {
                                my $msg = sprintf "FATAL: Valid file extension not found in %s", $s;
                                fatal($msg);
                            }

                            given ( $srcext )
                            {
                                when (
                                         $srcext ~~ $Depend{'hdr'}{'c'} or
                                         $srcext ~~ $Depend{'hdr'}{'S'} or
                                         $srcext ~~ $Depend{'hdr'}{'E'} or
                                         $srcext ~~ $Depend{'hdr'}{'n'}
                                     )
                                {
                                    # $s is a hdr processible file
                                    # find all header file dependencies of source file
                                    @hdeps = hdr_depend( $cmd_var_sub, $s, "" );
                                }
                                when ( $srcext ~~ $Depend{'nothdr'}{'c'} )
                                {
                                    ; # noop for recognizable not header file processible $srcext
                                }
                                default
                                {
                                    my $msg = sprintf "FATAL: %s DIRS section source file %s has no recognizable extension(see %Depend)", $BFN, $s;
                                    fatal($msg);
                                }
                            }

                            # accumulate header file in @bldcmds appropriate for $opt_s
                            foreach my $h ( @hdeps )
                            {
                                # 
                                if ( $opt_s eq "nosystem" and $h =~ m{ ^\/.*[.]$RGX_HDR_EXT$ }x ) {next;}

                                push @bldcmds, "              $h\n";
                            } # END: foreach my $line ( @hdeps ){}
                        } # END: foreach my $s ( @Sources ){}
                    }
                    push @bldcmds, "\n";
                }
                default
                {
                    my $msg = sprintf "FATAL: %s DIRS section line is incorrectly formatted(see %s): %s", $BFN, $BIFN, $line;
                    fatal($msg);
                }
            } # END: given ( $line ){}
        } # END: foreach my $line ( @dirs ){}

        {
            # %s - $s{"$basename"}{"$path"}{"$dirs_line"} - is indexed by the source file name, the
            # path to that source file and the DIRS line that will build that source file.
            # examine %s for instances of source files specifed in multiple directories(warning) or
            # source files specified in the same directory(fatal).  %s is built from source files
            # actually matched in the source file tree.

            my ( $warning_msg, $fatal_msg );

            my @basename = sort keys %s;
            my $basename_size = scalar @basename;
            foreach my $basename ( @basename )
            {
                my @path = sort keys $s{$basename};
                my $path_size = scalar @path;
                if ( $path_size > 1 )
                {
                    $warning_msg .= "Same source file \'$basename\' specified in more than one directory:\n";
                    foreach my $path ( @path )
                    {
                        $warning_msg .= "$path\n";
                        my @dirs_line = sort keys $s{$basename}{$path};
                        my $dirs_line_size = scalar @dirs_line;
                        foreach my $dirs_line ( @dirs_line )
                        {
                            $warning_msg .= "$dirs_line\n";
                        }
                    }
                }
                foreach my $path ( @path )
                {
                    my @dirs_line = sort keys $s{$basename}{$path};
                    my $dirs_line_size = scalar @dirs_line;
                    if ( $dirs_line_size > 1 )
                    {
                        $fatal_msg .= "Same source file \'$basename\' specified in same directory:\n";
                        $fatal_msg .= "$path\n";
                        foreach my $dirs_line ( @dirs_line )
                        {
                            $fatal_msg .= "$dirs_line\n";
                        }
                    }
                }
            }

            if ( length $warning_msg )
            {
                my $msg = sprintf "WARNING: %s", $warning_msg;
                warning($msg);
            }
            if ( length $fatal_msg )
            {
                my $msg = sprintf "FATAL: %s", $fatal_msg;
                fatal($msg);
            }
        }

        return ( @bldcmds );
    }


    # 
    # Usage      : variable_match( \@eval, \@dirs );
    #
    # Purpose    : scan EVAL section code for scalar variables and make %eval_vars hash.  scan DIRS section cmd fields and make %dirs_vars hash.
    #            : compare the two hashes.  if %eval_vars variables are not in %dirs_vars, issue warnings.  if %dirs_vars variables are not in
    #            : %eval_vars then issue warnings and fatal errors.
    #
    # Parameters : $eval_ref - reference to array of EVAL section lines
    #              $dirs_ref - reference to array of DIRS section lines
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
    sub variable_match
    {
        my (
               $eval_ref,
               $dirs_ref,
           ) = @_;

        my ( %eval_vars, %dirs_vars );


        # scan EVAL section and make %eval_vars hash
        foreach my $line ( @{$eval_ref} )
        {
            chomp $line;

            # create hash of all variable name/variable value pairs in $eval_vars with all mandatory defines excluded
            my %eval_vars_tmp = &main::var_sub( $line, '$bld', '$bldcmd', '$lib_dirs', '$O', '$opt_s', '$opt_r', '$opt_lib' );
            %eval_vars = ( %eval_vars, %eval_vars_tmp );

            if ( "\$s" ~~ %eval_vars )
            {
                my $msg = "FATAL: The scalar variable \$s may not be specified in the EVAL section, as this is used in the DIRS".
                          " section command field to signify matched source files.";
                fatal($msg);
            }
        }

        # scan DIRS section and substitute scalar variables and make %dirs_vars hash
        foreach my $line ( @{$dirs_ref} )
        {
            chomp $line;

            given ( $line )
            {
                when ( m{$RGX_CMD_BLOCK} )
                {
                    # DIRS section cmd block
                    my $cmd = $line;

                    my %dirs_vars_tmp = &main::var_sub( $cmd );
                    %dirs_vars = ( %dirs_vars, %dirs_vars_tmp );
                }
                when ( m{$RGX_VALID_DIRS_LINE} )
                {
                    # DIRS section three field specification line
                    my ($dir, $regex_srcs, $cmd);

                    ($dir, $regex_srcs, $cmd) = split $COLON, $line;

                    my %dirs_vars_tmp = &main::var_sub( $cmd, '$s' );
                    %dirs_vars = ( %dirs_vars, %dirs_vars_tmp );
                }
                default
                {
                    my $msg = sprintf "FATAL: %s DIRS section line is incorrectly formatted(see %s): %s", $BFN, $BIFN, $line;
                    fatal($msg);
                }
            }
        }

        {
            # if %eval_vars variables not in %dirs_vars then issue warnings and if %dirs_vars variables not in
            # %eval_vars then issue warnings and fatal errors

            my (@evalextra, @dirsextra);

            # find all variables in EVAL section that are not in DIRS cmds excluding mandatory defines
            foreach my $key ( keys %eval_vars )
            {
                if ( not $key ~~ %dirs_vars )
                {
                    push @evalextra, $key;
                }
            }

            # find all variables in DIRS cmds that are not in EVAL section(excluding $s)
            foreach my $key ( keys %dirs_vars )
            {
                if ( not $key ~~ %eval_vars )
                {
                    push @dirsextra, $key;
                }
            }

            if ( not @evalextra == 0 )
            {
                my $msg = sprintf "WARNING: EVAL defined variable(s) not used in DIRS cmds: @evalextra", @evalextra;
                warning($msg);
            }

            if ( not @dirsextra == 0 )
            {
                my $msg = sprintf "FATAL: Extra unused variable(s), @dirsextra, in DIRS section - see %s.", @dirsextra, $BWFN;
                fatal($msg);
            }
        }

        {
            open my $bifnfh, ">>", $BIFN;

            # print expansion of eval{} section defined variables that appear in $cmd's
            print {$bifnfh} "\n####################################################################################################\n";
            print {$bifnfh} "EVAL section expansion of defined variables used in DIRS section cmd fields:\n\n";
            foreach my $key ( sort keys %eval_vars )
            {
                print {$bifnfh} "$key = $eval_vars{$key}\n";
            }
            print {$bifnfh} "\n";
            close $bifnfh;
        }

        return;
    }


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
    #            : $comment_section - holds comment section in Bld file for printing in $BIFN file
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


        open my $bifnfh, ">>", $BIFN;

        {
            my $date = localtime();
            print {$bifnfh} "\n$date\n";
        }

        print {$bifnfh} "\nOS: $OSNAME\n";

        print {$bifnfh} "\nbld version: $VERSION\n\n";

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
    # Purpose    : read $SIGFN file data into %Sigdata
    #
    # Parameters : $bld      - the target to built e.g. executable or libx.a or libx.so
    #            : \%Sigdata - hash holding $SIGFN file signature data
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


        if ( not -e "$SIGFN" )
        {
            return;
        }

        my $RGX_SHA1 = "[0-9a-f]\{40\}";  # regex to validate SHA1 signatures - 40 chars and all 0-9a-f

        # open $SIGFN signature file
        open my $sigfn, "<", $SIGFN;

        # build hash of $SIGFN file signatures with source file names as keys
        while ( my $line = <$sigfn> )
        {
            next if $line =~ $RGX_BLANK_LINE;

            given ( $line )
            {
                when ( m{^'(.*?)'\s($RGX_SHA1)$} )
                {
                    my $file = $1;
                    my $sigsource = $2;

                    if ( $sigsource !~ m{^$RGX_SHA1$} )
                    {
                        my $msg = sprintf "FATAL: Malformed %s file - invalid SHA1 signature \$sigsource:\n%s", $SIGFN, $line;
                        fatal($msg);
                    }

                    $Sigdata_ref->{$file}[$SIG_SRC] = $sigsource;

                    if ( $file =~ m{$RGX_LIBS} )
                    {
                        $Sigdata_ref->{$bld}[$LIB_DEP]{$file} = undef;
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
                        my $msg = sprintf "FATAL: Malformed %s file - invalid SHA1 signature \$sigsource:\n%s", $SIGFN, $line;
                        fatal($msg);
                    }

                    if ( $sigcmd !~ m{^$RGX_SHA1$} )
                    {
                        my $msg = sprintf "FATAL: Malformed %s file - invalid SHA1 signature \$sigcmd:\n%s", $SIGFN, $line;
                        fatal($msg);
                    }

                    if ( $sigtarget !~ m{^$RGX_SHA1$} )
                    {
                        my $msg = sprintf "FATAL: Malformed %s file - invalid SHA1 signature \$sigtarget:\n%s", $SIGFN, $line;
                        fatal($msg);
                    }

                    $Sigdata_ref->{$file}[$SIG_SRC] = $sigsource;
                    $Sigdata_ref->{$file}[$SIG_CMD] = $sigcmd;
                    $Sigdata_ref->{$file}[$SIG_TGT] = $sigtarget;
                }
                default
                {
                    my $msg = sprintf "FATAL: Malformed %s file - invalid format line:\n%s", $SIGFN, $line;
                    fatal($msg);
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
    #            :     2. signature of target does not exit in $SIGFN signature file
    #            :     3. signature of target exists in signature file but is changed from actual existing target
    #
    # Parameters : $bld         - the target to built e.g. executable or libx.a or libx.so
    #            : $bldcmd      - cmd used in perl system() call to build $bld object - requires '$bld' and '$O'(object files) internally
    #            : $lib_dirs    - space separated list of directories to search for libraries
    #            : $opt_lib     - to do dependency checking on libraries("nolibcheck", "libcheck", "warnlibcheck" or "fatallibcheck")
    #            : \%Sigdata    - hash holding $SIGFN file signature data
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


        # if $bld does not exists or is zero length return "true"
        if ( not -f $bld or -z $bld )
        {
            $rebuild = "true";
            return $rebuild;
        }

        my $sig = file_sig_calc( $bld, $bld, $bldcmd, $lib_dirs );

        # signature of $bld is defined as the signature of the concatenation of the file $bld and "$bld . $bldcmd . $lib_dirs".
        # this ensures that any change to the file or these mandatory defines forces a rebuild.
        if (
               (not $bld ~~ %{$Sigdata_ref}) or
               ($Sigdata_ref->{$bld}[$SIG_SRC] ne $sig)
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
                my $msg = sprintf "FATAL: ldd return: %s is 'not a dynamic executable'", $bld;
                fatal($msg);
            }

            # scan ldd return for full path library strings
            while ( $ldd =~ m{ ^\s+(\S+)\s=>\s(\S+)\s.*$ }gxm )
            {
                my $libname = $1;
                my $lib = $2;

                # the $lib variable should have either a full path library name or the word 'not'
                if ( $lib =~ m{not} )
                {
                    my $msg = sprintf "WARNING: ldd return: %s library is 'not found'", $libname;
                    warning($msg);
                }
                else
                {
                    $SigdataNew_ref->{$bld}[$LIB_DEP]{$lib} = undef;
                    $SigdataNew_ref->{$lib}[$SIG_SRC] = file_sig_calc( $lib );
                }
            }

            # compare %Sigdata(populated from $BFN) and %SigdataNew(populated from ldd) for removed libraries
            foreach my $l ( sort keys %{$Sigdata_ref->{$bld}[$LIB_DEP]} )
            {
                if ( not $l ~~ %{$Sigdata_ref->{$bld}[$LIB_DEP]} )
                {
                    push @libs_removed, $l;
                }
            }

            # if removed libraries rebuild and warn/fatal
            if ( @libs_removed )
            {
                $rebuild = "true";
                if ( $opt_lib eq "warnlibcheck" )
                {
                    my $msg = sprintf "WARNING: Libraries removed: %s", @libs_removed;
                    warning($msg);
                }
                if ( $opt_lib eq "fatallibcheck" )
                {
                    my $msg = sprintf "FATAL: Libraries removed: %s", @libs_removed;
                    fatal($msg);
                }
            }

            # check each library file for this target and set $rebuild to true if library is new or library has changed
            foreach my $l ( keys %{$SigdataNew_ref->{$bld}[$LIB_DEP]} )
            {
                if ( $l ~~ %{$Sigdata_ref} )
                {
                    # rebuild if library has changed
                    if ( $Sigdata_ref->{$l}[$SIG_SRC] ne $SigdataNew_ref->{$l}[$SIG_SRC] )
                    {
                        $rebuild = "true";
                        if ( $opt_lib eq "warnlibcheck" )
                        {
                            my $msg = sprintf "WARNING: Library changed: %s", $l;
                            warning($msg);
                        }
                        if ( $opt_lib eq "fatallibcheck" )
                        {
                            my $msg = sprintf "FATAL: Library changed: %s", $l;
                            fatal($msg);
                        }
                    }
                    next;
                }
                else
                {
                    # rebuild if library is new
                    $rebuild = "true";
                    if ( $opt_lib eq "warnlibcheck" )
                    {
                        my $msg = sprintf "WARNING: Libraries added: %s", @libs_removed;
                        warning($msg);
                    }
                    if ( $opt_lib eq "fatallibcheck" )
                    {
                        my $msg = sprintf "FATAL: Libraries added: %s", @libs_removed;
                        fatal($msg);
                    }
                    next;
                }
            }
        }

        if ( $rebuild eq "false" )
        {
            # add old signature to %SigdataNew to output to $SIGFN file
            $SigdataNew_ref->{$bld}[$SIG_SRC] = $Sigdata_ref->{$bld}[$SIG_SRC];
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

            my $msg = sprintf "FATAL: Error msg: %s\nCmd: \"%s\"\nFail status: %s", $error_msg, $tmp, $status;
            fatal($msg);
        }

        $SigdataNew_ref->{$bld}[$SIG_SRC] = file_sig_calc( $bld, $bld, $bldcmd, $lib_dirs );

        if ( $opt_lib ne "nolibcheck" )
        {
            # do ldd on target executable or library and set target library dependencies and calculate library signatures
            my $ldd = `ldd $bld 2>&1`;

            if ( $ldd =~ m{not a dynamic executable} )
            {
                my $msg = sprintf "FATAL: ldd return: %s is 'not a dynamic executable'", $bld;
                fatal($msg);
            }

            while ( $ldd =~ m{ ^\s+(\S+)\s=>\s(\S+)\s.*$ }gxm )
            {
                my $libname = $1;
                my $lib = $2;

                # the $lib variable should have either a full path library name or the word 'not'
                if ( $lib =~ m{not} )
                {
                    warning("WARNING: ldd return: $libname library is 'not found'");
                }
                else
                {
                    $SigdataNew_ref->{$bld}[$LIB_DEP]{$lib} = undef;
                    $SigdataNew_ref->{$lib}[$SIG_SRC] = file_sig_calc( $lib );
                }
            }
        }

        print "$tmp\n";
        print "$bld re-built.\n";
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

        my ( $printonce ) = 0;


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
                    warning("WARNING: $warn");
                }

                $warn = sprintf "%*d  %s\n", 3, $n, $signature;

                # loop over all source file names with $signature
                foreach my $file ( sort keys %{$SourceSig_ref->{$signature}} )
                {
                    $warn .= sprintf "%*s\n", 123, $file;
                }
                chomp $warn;
                warning("WARNING: $warn");
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
                    my $msg = sprintf "FATAL: Invalid combination of source extension: %s and build option: -c.", $srcext;
                    fatal($msg);
                }

                # check if '-c' specified multiple times
                $n++ while $cmd_var_sub =~ m{\s-c\s}gx;
                if ( $n > 1 )
                {
                    my ( $tmp );

                    $tmp = $cmd_var_sub;
                    $tmp =~ s{!!!}{\\n}g;
                    my $msg = sprintf "WARNING: Multiple instances of '-c' detected in compile options(might just be conditional compilation).\n--->%s", $tmp;
                    warning($msg);
                }

                # change any suffix to .o suffix and push on %Objects for use in rebuild
                my $basenametgt = $s;
                $basenametgt =~ s{$RGX_FILE_EXT}{o}; # replace from last period to end of string with .o

                # if $basenametgt is already in %Objects fail - two different sources are producing the same object file in
                # the same place e.g. source files a.c and a.m in the same directory will both produce a.o
                foreach my $o ( keys %{$Objects_ref} )
                {
                    if ( $o eq $basenametgt )
                    {
                        my $msg = sprintf "FATAL: Object file conflict - %s produces an object file %s that already exists.", $s, $basenametgt;
                        fatal($msg);
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
                    my $msg = sprintf "FATAL: Invalid combination of source extension: %s and build option: -S.", $srcext;
                    fatal($msg);
                }

                # check if '-S' specified multiple times
                $n++ while $cmd_var_sub =~ m{\s-S\s}gx;
                if ( $n > 1 )
                {
                    my ( $tmp );

                    $tmp = $cmd_var_sub;
                    $tmp =~ s{!!!}{\\n}g;
                    my $msg = sprintf "WARNING: Multiple instances of '-S' detected in compile options(might just be conditional compilation).\n--->%s", $tmp;
                    warning($msg);
                }

                $buildopt = 'S';
            }
            when ( not m{\s-c\s} and not m{\s-S\s} and m{\s-E\s} )
            {
                my ( $n );

                if ( not exists ${$Depend_ref}{'hdr'}{'E'}{$srcext}{'ext'} )
                {
                    my $msg = sprintf "FATAL: Invalid combination of source extension: %s and build option: -E.", $srcext;
                    fatal($msg);
                }

                # check if '-E' specified multiple times
                $n++ while $cmd_var_sub =~ m{\s-E\s}gx;
                if ( $n > 1 )
                {
                    my ( $tmp );

                    $tmp = $cmd_var_sub;
                    $tmp =~ s{!!!}{\\n}g;
                    my $msg = sprintf "WARNING: Multiple instances of '-E' detected in compile options(might just be conditional compilation).\n--->%s", $tmp;
                    warning($msg);
                }

                $buildopt = 'E';
            }
            when ( not m{\s-c\s} and not m{\s-S\s} and not m{\s-E\s} )
            {
                if ( not exists ${$Depend_ref}{'hdr'}{'n'}{$srcext}{'ext'} )
                {
                    my $msg = sprintf "FATAL: Invalid combination of source extension: %s and build option: non of -c/-S/-E exists.", $srcext;
                    fatal($msg);
                }

                $buildopt = 'n';
            }
            default
            {
                my $msg = sprintf "FATAL: Multiple options -c/-S/-E specified in cmd: %s.", $cmd_var_sub;
                fatal($msg);
            }
        }

        return $buildopt;
    }


    # 
    # Usage      : $tgtextorfile = tgtextorfile( $s, $hdr, $srcext, $srcpath, $srcfile, $buildopt, $SigdataNew_tmp_ref, $Depend_ref );
    #
    # Purpose    : return the $s target extension or file name
    #            : Also:
    #            :     a. if multiple target files in the $srcpath directory fatal()
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
        my ( $tgtfilesboolean ) = "false"; # indicates that the target file is not derived from a file name extension,
                                           # but is specified in %Depend as an actual file name
        my ( @tgtfiles );

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
                $tmp =~ s{$RGX_FILE_EXT}{$tgtext};
                if ( $tmp ~~ @Sources )
                {
                    push @tgtfiles, $tmp;
                    $tgtfilesboolean = "false";
                }
            }
        }

        # check for multiple target files in the $srcpath directory.  if more than one target file do fatal().
        if ( @tgtfiles > 1 )
        {
            my $msg = sprintf "FATAL: More than one target file for %s in %s: %s", $srcfile, $srcpath, @tgtfiles;
            fatal($msg);
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
                if ( $tgtfiles[0] =~ m{.*[.]$RGX_FILE_EXT} )
                {
                    $tgtextorfile = $1;
                }
            }

            # calculate signature of previously already existing target file - if no target file ignore.
            # why?  if the old target file has been corrupted or compromised then it's signature will not match
            # the signature in $BFN even if the source and the cmd to build the source have not changed.  this
            # should cause a rebuild.  if a re-compile is triggered by either a source change, a build cmd change
            # or a change in the target file signature then the signature calculated here will be overwritten
            # by the after compile new signature.
            ${$SigdataNew_tmp_ref}{$s}[$SIG_TGT] = file_sig_calc( "$srcpath/$tgtfiles[0]" );
        }
        else
        {
            # no previous target file in $srcpath directory
            $tgtextorfile = $EMPTY;
        }

        return $tgtextorfile;
    }


    # 
    # Usage      : tgt_signature( $s, $hdr, $srcext, $srcpath, $srcfile, $buildopt, $SigdataNew_tmp_ref, $Depend_ref, \@difference, $Targets_ref);
    #
    # Purpose    : calculate the new target file signature and return it in the @SigdataNew_tmp array
    #            :     a. if more than one target file created by $cmd_var_sub do fatal()
    #            :     b. if an identical target file was created earlier do fatal()
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
                $tmp =~ s{$RGX_FILE_EXT}{$tgtext};
                if ( $tmp ~~ @{$difference_ref} )
                {
                    push @tgtfiles, $tmp;
                }
            }
        }

        if ( @tgtfiles == 0 )
        {
            my $msg = sprintf "FATAL: No target file for %s in %s: %s", $srcfile, $srcpath, @tgtfiles;
            fatal($msg);
        }

        # check for multiple target files created by $cmd_var_sub.  if more than one target file created do fatal().
        if ( @tgtfiles > 1 )
        {
            my $msg = sprintf "FATAL: More than one target file for %s in %s: %s", $srcfile, $srcpath, @tgtfiles;
            fatal($msg);
        }

        # calculate signature of target
        ${$SigdataNew_tmp_ref}{$s}[$SIG_TGT] = file_sig_calc( $tgtfiles[0] );

        if ( exists $Targets_ref->{"${srcpath}$tgtfiles[0]"} )
        {
            my $msg = sprintf "FATAL: An identical target file(name) has been created twice: %s%s", $srcpath, $tgtfiles[0];
            fatal($msg);
        }
        else
        {
            $Targets_ref->{"${srcpath}$tgtfiles[0]"} = undef;
        }
    }


    # 
    # Usage      : @dirs = dirs_pro( $dirs, $opt_s );
    #
    # Purpose    : Process $BFN file DIRS section
    #            :     Sequentially, the following tasks are performed:
    #            :     1. compress the DIRS section by eliminating unnecessary white space and unnecessary newlines
    #            :        and converting the input $dirs scalar to the @dirs array with lines of format '$dir:$regex_srcs:$cmd'
    #            :     2. print @dirs lines to $BIFN - before 'R ' lines recursive expansion
    #            :     3. expand @dirs lines that start with 'R '(recursive).  this will replace the 'R ' line with one or more
    #            :        lines that have recursively the directories below the 'R ' line $dir and the same $regex_srcs and $cmd expressions
    #            :     4. check DIRS section compressed lines for valid format i.e. "^.*:.*:.*$"(DIRS section three field specification)
    #            :        or "^{.*}$"(DIRS section cmd block)
    #            :     5. accumulate lines to be printed to the $BIFN file:
    #            :        a. DIRS section specification lines with a line count number
    #            :        b. variable interpolated(except for \$s) specification line cmd field
    #            :        c. matching compilation unit source file(s)
    #            :        d. source file header dependencies
    #            :        e. check for the following error conditions:
    #            :           1. either a directory or a source file is not readable
    #            :           2. multiple build entries in $BFN file DIRS section lines matching same source file
    #            :           3. Bad char(not [\/A-Za-z0-9-_.]) in directory specification "$dir"
    #            :           4. Invalid regular expression - "$regex_srcs"
    #            :           5. No '$s' variable specified in DIRS line command field
    #            :           6. No sources matched in $BFN DIRS section line $line
    #            :           7. Source file specified in more than one DIRS line specification
    #
    # Parameters : $dirs  - all the DIRS section lines of $BFN in a single scalar variable
    #            : $opt_s - to use system header files in dependency checking("system" or "nosystem")
    #
    # Returns    : @dirs - the fully processed DIRS section lines of $BFN in an array
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
            my $msg = sprintf "FATAL: %s DIRS section is empty.", $BFN;
            fatal($msg);
        }

        #  convert $dirs scalar to @dirs array.  $dirs holds the entire contents of the Bld
        # file DIRS section.  @dirs will have one cmd block({}) or one '[R] dir:regex:{cmds}'
        # specification per array element
        @dirs = cvt_dirs_to_array( $dirs );

        if ( @dirs == 0 )
        {
            my $msg = sprintf "FATAL: %s DIRS section is empty.", $BFN;
            fatal($msg);
        }

        {
            # print @dirs lines to $BIFN - before 'R ' lines recursive expansion

            open my $bifnfh, ">>", $BIFN;

            print {$bifnfh} "\n####################################################################################################\n";
            print {$bifnfh} "$BFN file DIRS section specification lines with irrelevant white space compressed out:\n\n";

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
            # print @dirs lines to $BIFN - after 'R ' lines recursive expansion

            open my $bifnfh, ">>", $BIFN;

            print {$bifnfh} "\n####################################################################################################\n";
            print {$bifnfh} "R recursively expanded and numbered DIRS section specification lines:\n\n";

            # log @dirs to $BIFN
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
        # or "$RGX_CMD_BLOCK"(DIRS section cmd block)
        foreach my $line ( @dirs )
        {
            if ( not $line =~ m{^.*:.*:.*$} and not $line =~ m{$RGX_CMD_BLOCK} )
            {
                my $msg = sprintf "FATAL: %s DIRS section line is incorrectly formatted(see %s): %s", $BFN, $BIFN, $line;
                fatal($msg);
            }
        }

        {
            # accumulate lines to be printed to the $BIFN file:
            #     a. DIRS section specification lines with a line count number
            #     b. variable interpolated(except for \$s) specification line cmd field
            #     c. matching compilation unit source file(s)
            #     d. source file header dependencies
            #     e. check for the following error conditions:
            #        1. either a directory or a source file is not readable
            #        2. multiple build entries in $BFN file DIRS section lines matching same source file
            #        3. Bad char(not [\/A-Za-z0-9-_.]) in directory specification "$dir"
            #        4. Invalid regular expression - "$regex_srcs"
            #        5. No '$s' variable specified in DIRS line command field
            #        6. No sources matched in $BFN DIRS section line $line
            #        7. Source file specified in more than one DIRS line specification
            my ( @tmp ) = accum_blddotinfo_output( $opt_s, @dirs );

            my @bldcmds =  @tmp;

            {
                open my $bifnfh, ">>", $BIFN;

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
    # Parameters : $dirs - all the DIRS section lines of $BFN in a single scalar variable
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
            next if $line =~ $RGX_BLANK_LINE;

            if ( $line =~ m{^[{].*[}]$} ) # matches a line of '{stuff}' exactly - a $cmd
            {
                if ( $prevline eq "cmd" )
                {
                    if ( not $line =~ m{$RGX_CMD_BLOCK} )
                    {
                        my $msg = sprintf "FATAL: %s DIRS section line is not valid(doesn't match %s): %s", $BFN, $RGX_CMD_BLOCK, $line;
                        fatal($msg);
                    }

                    # lone cmd block string
                    push @dirs, $line;
                }
                else
                {
                    if ( not $dir_regex.$line =~ m{$RGX_VALID_DIRS_LINE} )
                    {
                        my $msg = sprintf "FATAL: %s DIRS section line is not valid(doesn't match %s): %s.%s", $BFN, $RGX_VALID_DIRS_LINE, $dir_regex, $line;
                        fatal($msg);
                    }

                    # concatenate '$dir:$regex:' and '$cmd' strings
                    push @dirs, $dir_regex.$line;
                    $prevline = "cmd";
                }
            }
            else
            {
                if ( not $line =~ m{$RGX_VALID_DIRS_LINE} )
                {
                    my $msg = sprintf "FATAL: %s DIRS section line is not valid(doesn't match %s): %s", $BFN, $RGX_VALID_DIRS_LINE, $line;
                    fatal($msg);
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
                #       line with no source files to match cause a fatal() error.
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
    # Purpose    : scan $BFN file accumulating EVAL lines(in @eval) and DIRS lines(in $dirs) for later processing.
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
        if ( not -e "$BFN" )
        {
            my $msg = sprintf "FATAL: %s file missing.", $BFN;
            fatal($msg);
        }
        open my $bfnfh, "<", "Bld";
        my @bfnfile = <$bfnfh>;
        foreach my $e ( @bfnfile ){ $bfnfile .= $e }
        close $bfnfh;

        # match $BFN for EVAL and DIRS sections and extract them
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
            my $msg = sprintf "FATAL: %s invalid format - need EVAL and DIRS sections.", $BFN;
            fatal($msg);
        }

        # accumulate EVAL section lines in @eval
        while ( $eval_section =~ m{ ^(.*)$ }gxm )
        {
            my $eval_line = $1;

            # ignore if comment or blank line(s)
            next if ( $eval_line =~ $RGX_COMMENT_LINE or $eval_line =~ $RGX_BLANK_LINE );

            push @eval, $eval_line;
        }

        # accumulate DIRS section lines in $dirs - including newlines
        while ( $dirs_section =~ m{ ^(.*)$ }gxm )
        {
            my $dirs_line = $1;

            # ignore if comment or blank line(s)
            next if ( $dirs_line =~ $RGX_COMMENT_LINE or $dirs_line =~ $RGX_BLANK_LINE );

            $dirs .= "$dirs_line\n";
        }

        return ( $comment_section, @eval, $dirs );
    }


    # 
    # Usage      : sig_file_update( $bld, \%SigdataNew );
    #
    # Purpose    : replace $SIGFN file with new %SigdataNew entries and write $BIFN file source files section
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
                when ( m{ ^\/.*[.]$RGX_HDR_EXT$ }x )
                {
                    # collect system header files
                    push @system_hdrs, sprintf "%s", $s;
                }
                when ( m{ ^[^\/].*[.]$RGX_HDR_EXT$ }x )
                {
                    # collect not full path header files
                    push @user_hdrs, sprintf "%s", $s;
                }
                when (
                         (
                             $path =~ m{^\/.*} and
                             $file =~ m{$RGX_LIBS}
                         )
                         and not
                         (
                             # don't pick up the build target
                             $file =~ m{$bld} and
                             $path eq $EMPTY
                         )
                     )
                {
                    # collect library files
                    push @system_libraries, sprintf "%s", $s;
                }
                when (
                         (
                             $path =~ m{^[^\/].*} and
                             $file =~ m{$RGX_LIBS}
                         )
                         and not
                         (
                             # don't pick up the build target
                             $file =~ m{$bld} and
                             $path eq $EMPTY
                         )
                     )
                {
                    # collect library files
                    push @user_libraries, sprintf "%s", $s;
                }
                when ( defined $SigdataNew_ref->{$s}[$SIG_CMD] and defined $SigdataNew_ref->{$s}[$SIG_TGT] )
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
            push @sigfn, sprintf "'%s' %s\n", $s, $SigdataNew_ref->{$s}[$SIG_SRC];
        }
        push @bifn, "\n";
        push @sigfn, "\n";

        push @bifn, "--------------------------------------------------\n";
        push @bifn, "User headers:\n";
        foreach my $s ( @user_hdrs )
        {
            push @bifn, "'$s'\n";
            push @sigfn, sprintf "'%s' %s\n", $s, $SigdataNew_ref->{$s}[$SIG_SRC];
        }
        push @bifn, "\n";
        push @sigfn, "\n";

        push @bifn, "--------------------------------------------------\n";
        push @bifn, "System libraries:\n";
        foreach my $s ( @system_libraries )
        {
            push @bifn, "'$s'\n";
            push @sigfn, sprintf "'%s' %s\n", $s, $SigdataNew_ref->{$s}[$SIG_SRC];
        }
        push @bifn, "\n";
        push @sigfn, "\n";

        push @bifn, "--------------------------------------------------\n";
        push @bifn, "User libraries:\n";
        foreach my $s ( @user_libraries )
        {
            push @bifn, "'$s'\n";
            push @sigfn, sprintf "'%s' %s\n", $s, $SigdataNew_ref->{$s}[$SIG_SRC];
        }
        push @bifn, "\n";
        push @sigfn, "\n";

        push @bifn, "--------------------------------------------------\n";
        push @bifn, "Source files:\n";
        foreach my $s ( @code )
        {
            push @bifn, "'$s'\n";
            push @sigfn, sprintf "'%s' %s %s %s\n", $s, $SigdataNew_ref->{$s}[$SIG_SRC], $SigdataNew_ref->{$s}[$SIG_CMD], $SigdataNew_ref->{$s}[$SIG_TGT];
        }
        push @bifn, "\n";
        push @sigfn, "\n";

        push @bifn, "--------------------------------------------------\n";
        push @bifn, "Build target:\n";
        foreach my $s ( @exec )
        {
            push @bifn, "'$s'\n";
            push @sigfn, sprintf "'%s' %s\n", $s, $SigdataNew_ref->{$s}[$SIG_SRC];
        }

        open my $bifnfh, ">>", $BIFN;
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

        open my $sigfn, ">", $SIGFN;
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
        $IDU = $EMPTY;
        while ( $cmd_var_sub =~ m{ (-I\s*\S+|-D\s*\S+|-U\s*\S+) }gx )
        {
            $IDU .= $1.$SPACE;
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

        # if the word ' error '(spaces required) appears in the cpp output fatal()
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

            my $msg = sprintf "FATAL: %s", $cpperror;
            fatal($msg);
        }

        # populate %hdr_dep with all unique header files returned by cpp
        while ( $cppret =~ m{ (\S+[.]$RGX_HDR_EXT)\b }gx )
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
    # Purpose    : determine if source file $s needs to be re-built based on signature data in %Sigdata and %SigdataNew
    #
    # Parameters : $s               - relative path source file name starting from the bld home directory,
    #            :                    should only be compilation units(not header files)
    #            : $tgtextorfile    - the file name extension of the target file to be built from $s
    #            : \%Sigdata        - reference to hash holding $SIGFN file data
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
        return "true" if $Sigdata_ref->{$s}[$SIG_SRC] ne $SigdataNew_ref->{$s}[$SIG_SRC];

        # rebuild if build command has changed
        return "true" if $Sigdata_ref->{$s}[$SIG_CMD] ne $SigdataNew_ref->{$s}[$SIG_CMD];

        # rebuild if no target file extension found
        return "true" if $tgtextorfile eq $EMPTY;

        # if $tgtextorfile has an embedded period, then it is a full file name
        if ( $tgtextorfile =~ m{ [.] }x )
        {
            my ( $vol, $path, $file ) = File::Spec->splitpath( $s );
            $tgtfile = $path . $tgtextorfile;
        }
        else
        {
            $tgtfile = $s;
            $tgtfile =~ s{$RGX_FILE_EXT}{$tgtextorfile}; # replace from last period to end of string with .$tgtextorfile
        }

        # rebuild if target file does not exist
        return "true" if not -e "$tgtfile";

        # rebuild if target signature does not currently exist
        return "true" if not defined $Sigdata_ref->{$s}[$SIG_TGT] or not defined $SigdataNew_ref->{$s}[$SIG_TGT];

        # rebuild if target has changed
        return "true" if $Sigdata_ref->{$s}[$SIG_TGT] ne $SigdataNew_ref->{$s}[$SIG_TGT];

        # check each header file for this source
        foreach my $h ( keys %{$SigdataNew_ref->{$s}[$HDR_DEP]} )
        {
            # rebuild if header is new
            return "true" if not $h ~~ %{$Sigdata_ref};

            # rebuild if header has changed
            return "true" if $Sigdata_ref->{$h}[$SIG_SRC] ne $SigdataNew_ref->{$h}[$SIG_SRC];
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
    #            :     fatal()
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
            my $msg = sprintf "FATAL: File: %s does not exit.", $filename;
            fatal($msg);
        }

        if ( not -e $BFN )
        {
            my $msg = sprintf "FATAL: File: open() error on %s.", $filename;
            fatal($msg);
        }
        open my $fh, "<", $filename;

        $inputfilesize = -s "$filename";

        if ( $inputfilesize == 0 )
        {
            my $msg = sprintf "FATAL: File: %s is of zero size - a useful signature cannot be taken of an empty file.", $filename;
            fatal($msg);
        }

        read $fh, $inputfile, $inputfilesize;
        close $fh;

        my $otherstrings = $EMPTY;
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
    # Usage      : warning($msg);
    #
    # Purpose    : report warnings
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
    # See Also   : fatal()
    #
    sub warning
    {
        my (
               $msg,
           ) = @_;

        my ( $package, $filename, $line );
        my ( $output );


        # get package, filename and line of error in calling file
        ( $package, $filename, $line ) = caller;

        $output  = sprintf "Package: %s  Filename: %s  Line: %4d - %s\n\n", $package, $filename, $line, $msg;

        open my $bwfnfh, ">>", $BWFN;
        printf {$bwfnfh} "$output";
        close $bwfnfh;

        return;
    }


    # 
    # Usage      : fatal($msg);
    #
    # Purpose    : report fatal errors - write identical diagnostic information to
    #            : the $BFFN file and standard output - then exit.
    #
    # Parameters : $msg - a single scalar msg
    #
    # Returns    : exit;
    #
    # Globals    : None
    #
    # Throws     : None
    #
    # Notes      : None
    #
    # See Also   : warning()
    #
    sub fatal
    {
        my (
               $msg,
           ) = @_;

        my ( $package, $filename, $line );
        my ( $output );


        # get package, filename and line of error in calling file
        ( $package, $filename, $line ) = caller;

        $output  = sprintf "Package: %s  Filename: %s  Line: %4d\n\n", $package, $filename, $line;
        $output .= sprintf "Fatal: %s\n\n", $msg;
        $output .= sprintf "Stack Trace: %s\n\n", longmess("longmess()");

        open my $bffnfh, ">>", $BFFN;
        printf {$bffnfh} "$output";
        close $bffnfh;

        print "$output";

        exit;
    }


    # 
    # Usage      : bld -h
    #
    # Purpose    : print Usage msg
    #
    # Parameters : None
    #
    # Returns    : exit;
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

        print "$USAGE";

        exit;
    }


    #
    # FILE LOCAL SUBROUTINES
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
            when( m{ ^\/.*[.]$RGX_HDR_EXT$ }x )    { $na = 1; }
            when( m{ ^\/.*$RGX_LIBS$ }x )          { $na = 2; }
            when( m{ ^[^\/].*$RGX_LIBS$ }x )       { $na = 3; }
            when( m{ ^[^\/].*[.]$RGX_HDR_EXT$ }x ) { $na = 4; }
            when( m{ .*[.]$RGX_SRC_EXT$ }x )       { $na = 5; }
            my $msg = sprintf "";
            default {
                        my $msg = sprintf "FATAL: Invalid source format - $a";
                        fatal($msg);
                    }
        }

        given( $b )
        {
            when( m{ ^\/.*[.]$RGX_HDR_EXT$ }x )    { $nb = 1; }
            when( m{ ^\/.*$RGX_LIBS$ }x )          { $nb = 2; }
            when( m{ ^[^\/].*$RGX_LIBS$ }x )       { $nb = 3; }
            when( m{ ^[^\/].*[.]$RGX_HDR_EXT$ }x ) { $nb = 4; }
            when( m{ .*[.]$RGX_SRC_EXT$ }x )       { $nb = 5; }
            default {
                        my $msg = sprintf "FATAL: Invalid source format - %s", $b;
                        fatal($msg);
                    }
        }

        ( $vol, $path, $basea ) = File::Spec->splitpath( $a );
        if ( $basea =~ m{(.*)[.]$RGX_FILE_EXT} )
        {
            $afile = $1;
            $aext = $2;
        }
        else
        {
            my $msg = sprintf "FATAL: Valid file extension not found in %s", $basea;
            fatal($msg);
        }

        ( $vol, $path, $baseb ) = File::Spec->splitpath( $b );
        if ( $baseb =~ m{(.*)[.]$RGX_FILE_EXT} )
        {
            $bfile = $1;
            $bext = $2;
        }
        else
        {
            my $msg = sprintf "FATAL: Valid file extension not found in %s", $baseb;
            fatal($msg);
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

