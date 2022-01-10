#!/usr/bin/python3

# Copyright 2018-2021 VMware, Inc., Microsoft Inc., Carnegie Mellon University, ETH Zurich, and University of Washington
# SPDX-License-Identifier: BSD-2-Clause


from automation import *
from suite import *

parser = argparse.ArgumentParser(parents=[automation_argparser])
args = parser.parse_args()

common_vars = [
    Variable("ops", "run_btree", [
        Value("2pows", "ops=[1,2,3,4,5,6,7,8]") ]),
    Variable("seed", "run_btree", [
        Value("seed0", "seed=348725789"),
        Value("seed1", "seed=34578699348"),
        Value("seed2", "seed=23945765203"),
        Value("seed3", "seed=625478238923"),
        Value("seed4", "seed=657843290874"),
        Value("seed5", "seed=9526729840202"),
        ]),
    ]
repr_suite = Suite(
    "repr",
    Variable("git_branch", "git_branch", [Value("master", "eval-btree-master")]),
    *common_vars)
linear_suite = Suite(
    "linear",
    Variable("git_branch", "git_branch", [Value("linear", "eval-btree-linear")]),
    *common_vars)
suite = ConcatSuite("silver-btree-millions-cc", linear_suite, repr_suite)

MBTREE_PATH="./tools/run-btree-config-experiment.py"

def cmd_for_idx(idx, worker):
    variant = suite.variants[idx]
    cmd = (ssh_cmd_for_worker(worker) + [
        "cd", "veribetrfs", ";",
        "git", "clean", "-fd", ".", ";",
        "sh", "tools/clean-for-build.sh", variant.git_branch(), ";",
        ] + ["python3", MBTREE_PATH] + ["git_branch=" + variant.git_branch()] + [variant.valmap[var].param_value for var in variant.vars_of_type("run_btree")] + ["output=../"+variant.outfile()]
        )
    return Command(str(variant), cmd)

def main():
    set_logfile(suite.logpath())
    log("PLOT tools/aws/pull-results.py")
    log("VARIANTS %s" % suite.variants)

    workers = retrieve_running_workers(workers_file=args.workers_file, ssd=False)
    blacklist = [
        "veri-worker-b00",
        "veri-worker-b01",
        "veri-worker-b02",
        "veri-worker-b03",
        "veri-worker-b04",
        "veri-worker-b05",
    ]
    workers = [w for w in workers if w["Name"] not in blacklist]
    worker_pipes = launch_worker_pipes(workers, len(suite.variants), cmd_for_idx, dry_run=args.dry_run)
    monitor_worker_pipes(worker_pipes)

main()
