#!/bin/bash

# Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
# SPDX-License-Identifier: BSD-2-Clause


set -e

tools/configure-cgroups.sh

echo "Clearing page cache (requesting sudo access) ..."
sudo tools/clear-os-page-cache.sh
echo "Page cache cleared."

cgexec -g memory:VeribetrfsExp "$@"
