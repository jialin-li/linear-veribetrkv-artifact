#! /bin/bash

# Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
# SPDX-License-Identifier: BSD-2-Clause


frequency=$1
shift

set -x
set -e

apt-get update
apt-get install -y tmux locales

echo "LC_ALL=en_US.UTF-8" >> /etc/environment
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
locale-gen en_US.UTF-8

cd /veribetrfs
rm -R .veribetrfs-storage || true
mkdir .veribetrfs-storage

set +e
rm build/*.o
rm build/framework/*.o
rm build/Veribetrfs
set -e

make CC=clang++ CCFLAGS="-g -fno-omit-frame-pointer" build/Veribetrfs

echo "==== starting benchmark ===="
echo "flags: $@"

./build/Veribetrfs $@ &
PID=$!
read -n 1 -s -r -p "Press any key to start recording"
perf record -p $PID -g -F$frequency &
PERF_PID=$!
sleep 1
read -n 1 -s -r -p "Press any key to stop recording"

set +e
kill $PID
sleep 2

echo "==== starting benchmark ===="

tmux \
  new-session  "perf report -g graph,0.1,callee,function,percent" \; \
  split-window "echo \"The upper pane is perf with callee trees, this is with caller trees. In tmux, use C-b Up and C-b Down to switch panes. If perf is crashing, try with a shorter trace.\"; read -n 1 -s -r -p \"Press any key to start loading this pane\"; perf report -g graph,0.4,caller,function,percent" \; \
  attach \;

