import os, sys, re
from measure_vertime import RESULT_ROOT
from filemap import *
import json

times = dict()
time_pattern = re.compile("([0-9\.]+)user ([0-9\.]+)system ([0-9\.\:]+)elapsed")

def parse_output(file_path, measure, end, repo_result):
    f = open(file_path)
    time = None
    for line in f:
        match = re.match(time_pattern, line)
        if match:
            time = [float(match.group(1)), float(match.group(2)), match.group(3)]
    f.close()
    assert time

    file_name = file_path.split("/")[-1]
    file_name = file_name.replace(end, "")

    if file_name not in repo_result:
        repo_result[file_name] = dict()
    
    repo_result[file_name][measure] = time

def parse_repo_times(repo_times_dir, measure, repo_result):
    end = f".{measure}.out"
    for file_name in os.listdir(repo_times_dir):
        if file_name.endswith(end):
            print(file_name)
            path = os.path.join(repo_times_dir, file_name)
            parse_output(path, measure, end, repo_result)

for dir_name in os.listdir(RESULT_ROOT):
    times[dir_name] = dict()
    for measure in {"t", "p"}:
        parse_repo_times(os.path.join(RESULT_ROOT,dir_name), measure, times[dir_name])

with open("/home/root/output/file_time.json", "w") as f:
    f.write(json.dumps(times))
