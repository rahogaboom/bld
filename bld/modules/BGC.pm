#!/usr/bin/perl

#
# BGC.pm - bld global initialized constants
#

package BGC
{
    $VERSION = "1.0.1";

    # file names
    $SIGFN = "Bld.sig";       # SIGnature File Name
    $BFN   = "Bld";           # Bld File Name
    $BGVFN = "Bld.gv";        # Bld Global Variable File Name
    $BIFN  = "bld.info";      # Bld Info File Name
    $BWFN  = "bld.warn";      # Bld Warn File Name
    $BFFN  = "bld.fatal";     # Bld Fatal File Name

    # usage msg
    $USAGE = "\n".
             " bld($BGC::VERSION) is a simple flexible non-hierarchical perl program that builds a single C/C++/\n".
             " Objective C/Objective C++/Assembler target(executable or library(static or shared)) and,\n".
             " unlike 'make', uses SHA1 signatures(no dates) for building software and GNU cpp for\n".
             " automatic header file dependency checking.  The operation of bld depends entirely on the\n".
             " construction of the Bld(bld specification) and Bld.gv(bld global values) files.  See the\n".
             " bld.README file.  There are no cmd line arguments or options(except for -h(this msg)) or\n".
             " \$HOME/.bldrc or ./.bldrc files and no environment variables are used.  Complex\n".
             " multi-target projects are built with the use of:\n\n".
             "     Bld.<project>         - Bld files and target bld output files directory\n".
             "     bld.<project>         - project source directory\n".
             "     bld.<project>         - target construction script\n".
             "     bld.<project>.rm      - target and bld.<info|warn|fatal>.<target> file removal script\n".
             "     Bld.<project>.gv      - project global values file\n".
             "     bld.<project>.install - target and file install script\n".
             "     bld.<project>.README  - project specific documentation file\n\n".
             " Current example projects:\n\n".
             "     Bld.example - several examples intended to show how to create Bld and Bld.gv files\n\n".
             "     The following are examples of bld'ing complex multi-target projects.  They are\n".
             "     provided with releases. Unpack them in the main bld directory in the same place as\n".
             "     the bld.example and Bld.example directories:\n".
             "         bld.git.git-1.9.rc0.tar.gz -\n".
             "             the git project http://git-scm.com/\n".
             "         bld.svn.subversion-1.8.5.tar.gz -\n".
             "             the subversion project http://subversion.apache.org/\n".
             "         bld.systemd.systemd-208.tar.gz -\n".
             "             the systemd project http://www.freedesktop.org/wiki/Software/systemd/\n\n".
             " Dependencies:\n".
             "     Required for execution:\n".
             "         experimental.pm(3pm) - for smartmatch and switch features\n".
             "         cpp(1) - gnu cpp cmd is required for dependency determination\n".
             "         ldd(1) - used for library dependency determination\n".
             "     Required for test:\n".
             "         gcc(1)/g++(1) (http://gcc.gnu.org/)\n".
             "         clang(1) (http://llvm.org/)\n\n".
             " cd bld\n".
             " Read bld.README.\n".
             " Do './bld -h' for the usage msg.\n".
             " Do 'perldoc bld' for the full man page.\n".
             " Do './bld' to build the exec-c executable \"Hello, world!\" program.  This creates the\n".
             "     bld.info, bld.warn and Bld.sig files which along with the Bld file gives an\n".
             "     illustration of how to construct Bld files and the output that bld creates.\n".
             "     This \"Hello, world!\" program has several stub do nothing routines that are just\n".
             "     there to help illustrate various features of how to construct a Bld file.\n\n";

    # signature related
        # the following are constants used to index the second subscript of the %Sigdata($Sigdata{}[])
        # and %SigdataNew($SigdataNew{}[]) hashes.  the first index(the {}) is the full path or
        # relative path file name starting at the bld home directory of the source(code or header or library) file.
        $SIG_SRC = 0;     # constant subscript indexing the signature of the source, header file or library
        $SIG_CMD = 1;     # constant subscript indexing the signature of the build command
        $SIG_TGT = 2;     # constant subscript indexing the signature of the target file
        $HDR_DEP = 3;     # constant subscript indexing header file dependencies in the next level hash
        $LIB_DEP = 4;     # constant subscript indexing library file dependencies in the next level hash

    # regex related
        # match all header file extensions(without the period)
        $RGX_HDR_EXT = qr{
                                 (?:
                                     h   | # C
                                     hh  | # C++
                                     hp  | # C++
                                     hxx | # C++
                                     hpp | # C++
                                     HPP | # C++
                                     h++ | # C++
                                     tcc   # C++
                                 )
                             }x;

        # match all source file extensions(without the period)
        $RGX_SRC_EXT = qr{
                                 (?:
                                     c   | # C
                                     cc  | # C++
                                     cp  | # C++
                                     cxx | # C++
                                     cpp | # C++
                                     CPP | # C++
                                     c++ | # C++
                                     C   | # C++
                                     m   | # ObjC
                                     mm  | # ObjC++
                                     M   | # ObjC++
                                     S   | # Assembler
                                     sx  | # Assembler
                                     i   | # C - no headers
                                     ii  | # C++ - no headers
                                     mi  | # ObjC - no headers
                                     mii | # ObjC++ - no headers
                                     s   | # Assembler - no headers
                                     l   | # lex
                                     y     # yacc
                                 )
                             }x;

        # match any file name extension(without the period)
        $RGX_FILE_EXT = qr{
                              (
                                  [^.\/\\\ ]+? # file extension - no periods, forward/back slashes or spaces
                              )$
                          }x;

        # match all valid chars for full and relative path file names e.g. "/usr/include/_G_config.h"  or  "src/C/a b/m.c"
        $RGX_VALID_PATH_CHARS = qr{ [\]\[\\\ \/A-Za-z0-9(){}'!@#$%^&_+-=;,.~`] }x;

        # match a valid $BFN file DIRS section line
        $RGX_VALID_DIRS_LINE  = qr{
                                      ^.*: # directory field
                                       .*: # regex field
                                       .*$ # cmd field
                                  }x;

        # match a blank line
        $RGX_BLANK_LINE       = qr{ ^\s*$ }x;

        # match a comment line
        $RGX_COMMENT_LINE     = qr{ ^\s*\# }x;

        # match a DIRS section cmd block
        $RGX_CMD_BLOCK        = qr{ ^{.*}$ }x;

        # match all valid libraries
        $RGX_LIBS             = qr{
                                      (?:
                                          lib.*?[.]so.*? | # shared object libraries
                                          lib.*?[.]a       # static libraries
                                      )
                                  }x;

    # constant strings
    $COLON = q{:};
    $EMPTY = q{};
    $SPACE = q{ };

    # primary program data structures
        our %Depend;
            # dependencies - specify valid relationships between different file types(identified by file extensions)
            #
            # the hash will be five levels:
            # $Depend{'<hdr or nothdr>'}{'<cmd line option or n>'}{'<source file name extension>'}{'<ext or file>'}{'<target file name extension or file name>'} = undef
            #     a. the first level hash has a key of 'hdr' or 'nothdr' indicating if the source is/is not hdr processible
            #        e.g. 'c'(header processible) or 's'(not header processible)
            #     b. the second level hash has a key of the cmd line option(without the -) or n for no option e.g. 'c' - generate object file
            #     c. the third level hash has a key of the source file name extension(without the .) e.g. 'c' - a C source file
            #     d. the fourth level hash has a key of 'ext' or 'file' indicating that the next level(fifth) keys are file name extensions(ext) or file names(file)
            #     e. the fifth level hash has a key of the target file name extension for the generated file e.g. 'o' - an object file
            #     f. the values are undef
            #
            # Example: # C(hdr dependencies) code with .c extension and -S cmd line option and target file extension of 's'
            #          $Depend{'hdr'}{'S'}{'c'}{'ext'}{'s'} = undef;
            #
            #          # yacc specification(hdr dependencies) with .y file extension and with no cmd line option and target file of 'y.tab.c'
            #          $Depend{'hdr'}{'n'}{'y'}{'file'}{'y.tab.c'} = undef;
            #
            #          # yacc specification(hdr dependencies) with .y file extension and no cmd line option and target file extension of 'c'
            #          $Depend{'hdr'}{'n'}{'y'}{'ext'}{'c'} = undef;
            #
            #          # assembler code(no hdr dependencies) with .s extension and -c cmd line option and target file extension of 'o'
            #          $Depend{'nothdr'}{'c'}{'s'}{'ext'}{'o'} = undef;
            #
            #          # C(no hdr dependencies) code with .i extension and -c cmd line option and target file extension of 'o'
            #          $Depend{'nothdr'}{'c'}{'i'}{'ext'}{'o'} = undef;
            #
            # Purpose: to specify the valid processing path of source files to produce the correct target file from a given cmd line option.

    # hdr processible files

        # C source code
        $Depend{'hdr'}{'c'}{'c'}{'ext'}{'o'} = undef;
        $Depend{'hdr'}{'S'}{'c'}{'ext'}{'s'} = undef;
        $Depend{'hdr'}{'E'}{'c'}{'ext'}{'i'} = undef;

        # C++ source code
        $Depend{'hdr'}{'c'}{'cc'}{'ext'}{'o'} = undef;
        $Depend{'hdr'}{'S'}{'cc'}{'ext'}{'s'} = undef;
        $Depend{'hdr'}{'E'}{'cc'}{'ext'}{'ii'} = undef;

        $Depend{'hdr'}{'c'}{'cp'}{'ext'}{'o'} = undef;
        $Depend{'hdr'}{'S'}{'cp'}{'ext'}{'s'} = undef;
        $Depend{'hdr'}{'E'}{'cp'}{'ext'}{'ii'} = undef;

        $Depend{'hdr'}{'c'}{'cxx'}{'ext'}{'o'} = undef;
        $Depend{'hdr'}{'S'}{'cxx'}{'ext'}{'s'} = undef;
        $Depend{'hdr'}{'E'}{'cxx'}{'ext'}{'ii'} = undef;

        $Depend{'hdr'}{'c'}{'cpp'}{'ext'}{'o'} = undef;
        $Depend{'hdr'}{'S'}{'cpp'}{'ext'}{'s'} = undef;
        $Depend{'hdr'}{'E'}{'cpp'}{'ext'}{'ii'} = undef;

        $Depend{'hdr'}{'c'}{'CPP'}{'ext'}{'o'} = undef;
        $Depend{'hdr'}{'S'}{'CPP'}{'ext'}{'s'} = undef;
        $Depend{'hdr'}{'E'}{'CPP'}{'ext'}{'ii'} = undef;

        $Depend{'hdr'}{'c'}{'c++'}{'ext'}{'o'} = undef;
        $Depend{'hdr'}{'S'}{'c++'}{'ext'}{'s'} = undef;
        $Depend{'hdr'}{'E'}{'c++'}{'ext'}{'ii'} = undef;

        $Depend{'hdr'}{'c'}{'C'}{'ext'}{'o'} = undef;
        $Depend{'hdr'}{'S'}{'C'}{'ext'}{'s'} = undef;
        $Depend{'hdr'}{'E'}{'C'}{'ext'}{'ii'} = undef;

        # objective C source code
        $Depend{'hdr'}{'c'}{'m'}{'ext'}{'o'} = undef;
        $Depend{'hdr'}{'S'}{'m'}{'ext'}{'s'} = undef;

        # objective C++ source code
        $Depend{'hdr'}{'c'}{'mm'}{'ext'}{'o'} = undef;
        $Depend{'hdr'}{'S'}{'mm'}{'ext'}{'s'} = undef;

        $Depend{'hdr'}{'c'}{'M'}{'ext'}{'o'} = undef;
        $Depend{'hdr'}{'S'}{'M'}{'ext'}{'s'} = undef;

        # assembler source code
        $Depend{'hdr'}{'c'}{'S'}{'ext'}{'o'} = undef;
        $Depend{'hdr'}{'c'}{'sx'}{'ext'}{'o'} = undef;

        # lex specification
        $Depend{'hdr'}{'n'}{'l'}{'ext'}{'c'} = undef;
        $Depend{'hdr'}{'n'}{'l'}{'ext'}{'cc'} = undef;
        $Depend{'hdr'}{'n'}{'l'}{'file'}{'lex.yy.c'} = undef;

        # yacc specification
        $Depend{'hdr'}{'n'}{'y'}{'ext'}{'c'} = undef;
        $Depend{'hdr'}{'n'}{'y'}{'file'}{'y.tab.c'} = undef;

    # not hdr processible files

        # C source code
        $Depend{'nothdr'}{'c'}{'i'}{'ext'}{'o'} = undef;

        # C++ source code
        $Depend{'nothdr'}{'c'}{'ii'}{'ext'}{'o'} = undef;

        # objective C source code
        $Depend{'nothdr'}{'c'}{'mi'}{'ext'}{'o'} = undef;

        # objective C++ source code
        $Depend{'nothdr'}{'c'}{'mii'}{'ext'}{'o'} = undef;

        # assembler source code
        $Depend{'nothdr'}{'c'}{'s'}{'ext'}{'o'} = undef;
}

1;

