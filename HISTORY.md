
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

 bld-1.0.4.tar.gz - entirely perldoc updates.  example projects - bld-1.0.4-git.tar.gz, bld-1.0.4-svn.tar.gz
                    and bld-1.0.4-systemd.tar.gz.

 Why are there no releases beyond the latest three?  For now, I only intend to maintain and answer questions
 about the most recent releases.  This may change in future.

