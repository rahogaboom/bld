```
 bld-1.0.9.tar.gz - changes related to:
     a. minor code and doc changes to bld itself.
     b. changes to multi-target bld scripts:

            Bld.<project>/<version>/bld.<project>
            Bld.<project>/<version>/bld.<project>.rm

        that allow bld'ing of targets(executables or libraries) of the same
        name differentiated by the directory containing them e.g. from git -
        xdiff/lib.a and vcs-svn/lib.a.
     c. removed git versions 1.9.0, 2.3.0 and 2.9.2.  added git version 2.12.0.
        the git bld is NOT a vetted full construction of the git code.  it is
        used to illustrate the successful compilation of all git execuatables
        and libraries to bld complex multi-target projects.
     d. verify example and git code correct operation with latest:
        1. gcc/g++ - gcc (GCC) 6.3.1 20161221 (Red Hat 6.3.1-1)
        2. clang   - clang version 3.8.1 (tags/RELEASE_381/final)
     e. use perl 5.24.1

 bld-1.0.8.tar.gz - changes related to:
     a. remove svn as an example.  this allows greater focus on multiple versions
        of git as the single example of a complex project build.  added git
        version 2.9.2.
     b. modify bld.<project> and bld.<project>.rm to work with all target files
        under the same target named directory.  this unclutters the project
        directory to hold only target directories and the project build
        configuration and build executables.
     c. minor code changes.

 bld-1.0.7.tar.gz - changes related to:
     a. upgrade to perl 5.24.0
     b. remove systemd as an example.  ./configure is complicated by many
        dependencies.
     c. update license to Boost
     d. remove Obj C and yacc/lex examples.  requires dependencies.  I
        wanted the examples to run with only gcc/g++/clang more or less.

 bld-1.0.6.tar.gz - changes related to:
     a. fixes for two gcc warnings in the example code(rdx and daa)
     b. use 'print STDERR' for all prints - more immediate output
     c. doc updates

 bld-1.0.5.tar.gz - changes related to:
     a. change {cmds} block execution from 'system "cmds";' to '`{ cmds } 2>&1`;'
     b. add -c option to create bld.chg file with any file changes during a bld run
     c. add $ENV{HOME}/.bldrc and .bldrc files
     d. doc updates

 bld-1.0.4.tar.gz - changes related to:
     a. entirely perldoc updates
     b. example projects:
        bld-1.0.4-git.tar.gz
        bld-1.0.4-svn.tar.gz
        bld-1.0.4-systemd.tar.gz

 Why are there no releases beyond the latest three?  For now, I only intend to maintain and answer questions
 about the most recent releases.  This may change in future.

```
