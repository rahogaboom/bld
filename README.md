```
bld
===

bld(1.0.5) is a simple flexible non-hierarchical perl program that builds a single C/C++/
Objective C/Objective C++/Assembler target(executable or library(static or shared)) and,
unlike 'make', uses SHA1 signatures(no dates) for building software and GNU cpp for
automatic header file dependency checking.  The operation of bld depends entirely on the
construction of the Bld(bld specification) and Bld.gv(bld global values) files.  See the
bld.README file.  There are no cmd line arguments and no environment variables.  Complex
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

    The following are examples of building complex multi-target projects.  They are
    provided with releases. Unpack them in the main bld directory in the same place as
    the bld.example and Bld.example directories:
        bld-1.0.5-git.tar.gz -
            the git project http://git-scm.com/
        bld-1.0.5-svn.tar.gz -
            the subversion project http://subversion.apache.org/
        bld-1.0.5-systemd.tar.gz -
            the systemd project http://www.freedesktop.org/wiki/Software/systemd/

 Dependencies:
     Required for execution:
         experimental.pm(3pm) - for smartmatch and switch features
         cpp(1) - gnu cpp cmd is required for dependency determination
         ldd(1) - used for library dependency determination

         Do: cpan install cpanm
             cpanm experimental.pm

     Required for test:
         gcc(1)/g++(1) (http://gcc.gnu.org/)
         clang(1) (http://llvm.org/)
         yacc(1)/flex(1)

cd bld
Do './bld -h' for the usage msg.
Do 'perldoc bld' for the full man page.
Do './bld' to build the exec-c executable "Hello, world!" program.  This creates the
    bld.info, bld.warn and Bld.sig files which along with the Bld(and Bld.gv) file
    gives an illustration of how to construct Bld files and the output that bld
    creates.  This "Hello, world!" program has several stub do nothing routines that
    are just there to help illustrate various features of how to construct a Bld file.
Examine the bld.info, bld.warn, bld.fatal, bld.chg(-s), Bld.sig, Bld(and Bld.gv) files.
```
