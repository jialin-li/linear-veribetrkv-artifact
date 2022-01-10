#!/bin/bash

# Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
# SPDX-License-Identifier: BSD-2-Clause

# example: rename.sh MapSpec.s.dfy
newname=$1
basename=`echo $newname | sed s/\.[is].dfy$/.dfy/`
find /home/jonh/veribetrfs -type f -name \*.dfy | xargs sed -i "s/$basename/$newname/g"
mv $basename $newname
git rm $basename
git add $newname
git add --all
