#!/bin/bash

# C++ build script

set -v

if [ "$1" == 'clean' ]
then
    rm -f MKRdxPat_test
    exit
fi

# compile test program - using MKRdxPat.hpp
clang++ -std=gnu++14 -g -pedantic -Wall -o MKRdxPat_test MKRdxPat_test.cpp -lstdc++

