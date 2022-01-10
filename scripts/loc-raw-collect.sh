#!/bin/bash

TMP_DIR=/tmp
OUTPUT_DIR=/home/root/output
INPUT_DIR_LIST=("./lib/DataStructures" "./lib/Marshalling" "./lib/Buckets" "./Impl")

dynamic="veribetrkv-dynamic-frames"
linear="veribetrkv-linear"

collect_counts() {
    repo=$1
    repo_result=$2
    cd $repo

    mkdir -p $repo_result
    rm -rf $repo_result/*

    for dir in "${INPUT_DIR_LIST[@]}"; do
        for filename in $dir/*.i.dfy; do
            python3 tools/line_counter.py --mode=raw --input $filename --output ""
        done
        mv /tmp/inspect/$dir/* $repo_result/
    done
    
    echo "$repo done, result at $repo_result"
    cd /home/root
}

main() {
    mkdir -p $OUTPUT_DIR
    
    if [ -d "$linear/.dafny" ]; then
        rm $linear/.dafny
    fi

    collect_counts $dynamic $OUTPUT_DIR/$dynamic

    ln -s .dafny-linear $linear/.dafny
    collect_counts $linear $OUTPUT_DIR/$linear
    rm $linear/.dafny

    ln -s .dafny-inout $linear/.dafny
    collect_counts $linear $OUTPUT_DIR/$linear-inout
    rm $linear/.dafny

    ln -s .dafny-linear $linear/.dafny
}

main
