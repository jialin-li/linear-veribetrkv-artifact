#! /bin/bash

input=$1
mkdir -p /home/root/output/figures

if [ -z "$input" ]; then
    echo "Please specify an experiment to run: all | loc | vertime | error-msg | loc-raw | basic-test | vertime-small"
    exit
fi

files_dir=clean-files
if [ $2 ]; then
   files_dir=$2
fi

run_loc() {
    log="/home/root/output/loc-log"

    python3 /home/root/scripts/count_proc_loc.py --input $files_dir > $log
    python3 /home/root/scripts/generate_loc_csv.py >> $log
    python3 /home/root/scripts/graph_loc.py >> $log
}

run_vertime() {
    log="/home/root/output/vtime-log"

    if [ -d "/home/root/output/time-data" ]; then
        rm -rf "/home/root/output/time-data"
    fi

    measures=("t" "p")
    repos=("/home/root/veribetrkv-dynamic-frames" "/home/root/veribetrkv-linear")

    echo "starting verification time measurements" > $log

    for repo in "${repos[@]}"; do
        for measure in "${measures[@]}"; do
            echo "measuring: $repo $measure" >> $log
            python3 /home/root/scripts/measure_vertime.py $repo $measure $1 >> $log
        done
    done

    # parse result and graph
    python3 /home/root/scripts/parse_file_time.py >> $log
    python3 /home/root/scripts/graph_vertime_module.py >> $log

    python3 /home/root/scripts/parse_proc_time.py >> $log
    python3 /home/root/scripts/filter_methods.py --input clean-files >> $log
    python3 /home/root/scripts/generate_vtime_csv.py >> $log
    python3 /home/root/scripts/graph_method_diff.py >> $log
}

run_error() {
    log="/home/root/output/error-log"

    echo "Copying over error files" > $log
    echo "" >> $log
    cp /home/root/error-files/df-CacheImpl.i.dfy /home/root/veribetrkv-dynamic-frames/Impl/
    cp /home/root/error-files/df-BucketImpl.i.dfy /home/root/veribetrkv-dynamic-frames/lib/Buckets/
    cp /home/root/error-files/l-CacheImpl.i.dfy /home/root/veribetrkv-linear/Impl/

    echo "------> Testing dynamic frames MutCache example:" >> $log
    echo "" >> $log
    cd /home/root/veribetrkv-dynamic-frames
    tools/local-dafny.sh Impl/df-CacheImpl.i.dfy /compile:0 /trace /proc "*Insert*" /timeLimit 60  >> $log
    echo "" >> $log
    cat -n Impl/df-CacheImpl.i.dfy | awk '{if(NR>=111 &&  NR<=131) print $0}' >> $log
    echo "" >> $log
    echo "" >> $log

    echo "------>Testing dynamic frames MutBucket example:" >> $log
    echo "" >> $log
    tools/local-dafny.sh lib/Buckets/df-BucketImpl.i.dfy /compile:0 /trace /proc "*Insert*" >> $log
    echo "" >> $log
    cat -n lib/Buckets/df-BucketImpl.i.dfy | awk '{if(NR>=131 &&  NR<=171) print $0}' >> $log
    echo "" >> $log
    echo "" >> $log

    echo "------>Testing linear MutCache example:" >> $log
    echo "" >> $log
    cd /home/root/veribetrkv-linear
    tools/local-dafny.sh Impl/l-CacheImpl.i.dfy /compile:0 >> $log
    echo "" >> $log
    cat -n Impl/l-CacheImpl.i.dfy | awk '{if(NR>=88 &&  NR<=102) print $0}' >> $log
    echo "" >> $log
    echo "" >> $log

    echo "Removing error files" >> $log
    rm /home/root/veribetrkv-dynamic-frames/Impl/df-CacheImpl.i.dfy
    rm /home/root/veribetrkv-dynamic-frames/lib/Buckets/df-BucketImpl.i.dfy
    rm /home/root/veribetrkv-linear/Impl/l-CacheImpl.i.dfy
}

run_basic() {
    log="/home/root/output/basic-log"

    # basic testing: make sure we can verify files
    echo "Basic testing: verify a dynamic frame file" > $log
    cd /home/root/veribetrkv-dynamic-frames
    tools/local-dafny.sh Impl/CacheImpl.i.dfy /compile:0 /trace >> $log
    echo "" >> $log
    echo "" >> $log

    # basic testing: make sure we can verify files
    echo "Basic testing: verify a linear file" >> $log
    cd /home/root/veribetrkv-linear
    tools/local-dafny.sh Impl/CacheImpl.i.dfy /compile:0 /trace >> $log
}

if [[ $input == "loc" ]]; then
    run_loc
elif [[ $input == "loc-raw" ]]; then
    scripts/loc-raw-collect.sh &> /home/root/output/log
elif [[ $input == "vertime" ]]; then
    run_vertime
elif [[ $input == "vertime-small" ]]; then
    run_vertime small
elif [[ $input == "error-msg" ]]; then
    run_error
elif [[ $input == "all" ]]; then
    run_loc
    run_vertime
    run_error
elif [[ $input == "basic-test" ]]; then
    run_basic
else
    echo "Not a valid option"
fi
