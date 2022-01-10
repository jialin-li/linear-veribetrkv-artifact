#! /bin/bash

# Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
# SPDX-License-Identifier: BSD-2-Clause

# install linear dafny
tools/install-dafny.sh
mv .dafny .dafny-linear

# install linear dafny that unwinds generated 
# inout syntax to collect accurate loc
tools/install-dafny.sh 1f8ef17398d8cc62fd06ec13614f8c9539b3bf54
mv .dafny .dafny-inout

ln -s .dafny-linear .dafny