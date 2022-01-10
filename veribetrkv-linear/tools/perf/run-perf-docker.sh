#! /bin/bash

# Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
# SPDX-License-Identifier: BSD-2-Clause


# NOTE: pass the sampling rate (Hz) as first argument, followed by parameters to the benchmarker (i.e. ./tools/perf/run-perf-docker.sh 1000 --benchmark=random-inserts)
# 1000Hz is a good choice for longer experiments (a few minutes), higher rates are recommended for shorter experiments
# if you don't see enough detail, try and increase the sampling rate

echo "==== capturing at frequency $1 ===="

echo "==== making the cpp bundle ===="
make build/Bundle.cpp

echo "==== running docker ===="
docker run --rm --cap-add SYS_ADMIN -it -v `pwd`:/veribetrfs utaal/debian-make-clang-perf /bin/bash /veribetrfs/tools/perf/run-perf-docker-internal.sh $@

