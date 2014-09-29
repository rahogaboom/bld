```
bld
===

bld(1.0.0) is a simple flexible non-hierarchical perl program that builds a single C/C++/
Objective C/Objective C++/Assembler target(executable or library(static or shared)) and,
unlike 'make', uses SHA1 signatures(no dates) for building software and GNU cpp for
automatic header file dependency checking.  The operation of bld depends entirely on the
construction of the Bld(bld specification) and Bld.gv(bld global values) files.  See the
bld.README file.  There are no cmd line arguments or options(except for -h(this msg)) or
$HOME/.bldrc or ./.bldrc files and no environment variables are used.  Complex
multi-target projects are built with the use of:

    Bld.<project>         - Bld files and target bld output files directory
    bld.<project>         - project source directory
    bld.<project>         - target construction script
    bld.<project>.rm      - target and bld.<info|warn|fatal>.<target> file removal script
    Bld.<project>.gv      - project global values file
    bld.<project>.install - target and file install script
    bld.<project>.README  - project specific documentation file

Current example projects:

    Bld.example - several examples intended to show how to create Bld and Bld.gv files

    The following are examples of bld'ing complex multi-target projects.  They are
    provided with releases. Unpack them in the main bld directory in the same place as
    the bld.example and Bld.example directories:
        bld.git.git-1.9.rc0.tar.gz -
            the git project http://git-scm.com/
        bld.svn.subversion-1.8.5.tar.gz -
            the subversion project http://subversion.apache.org/
        bld.systemd.systemd-208.tar.gz -
            the systemd project http://www.freedesktop.org/wiki/Software/systemd/

cd bld
Read bld.README.
Do './bld -h' for the usage msg.
Do 'perldoc bld' for the full man page.
Do './bld' to build the exec-c executable "Hello, world!" program.  This creates the
    bld.info, bld.warn and Bld.sig files which along with the Bld file gives an
    illustration of how to construct Bld files and the output that bld creates.
```
