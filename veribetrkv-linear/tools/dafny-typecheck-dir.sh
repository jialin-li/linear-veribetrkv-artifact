#!/bin/bash

# Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
# SPDX-License-Identifier: BSD-2-Clause


# Build a file which includes all the files in the directory.
# (This is a lot faster than running dafny on each one individually.)

TMP=".includeall.dfy"
echo "" > $TMP
for dfy in *.dfy; do
    [ -f "$dfy" ] || break
    echo "$dfy"
    echo "include \"$dfy\"" >> $TMP
done

# Run the type-checker, but don't verify or compile anything.
dafny "$TMP" /dafnyVerify:0 /compile:0
