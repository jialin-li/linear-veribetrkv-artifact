import os, sys, re
import json

from measure_vertime import RESULT_ROOT

from filemap import *

wf_pattern = re.compile("Verifying CheckWellformed\$\$([a-zA-Z0-9\_\.]+)")
impl_pattern = re.compile("Verifying Impl\$\$([a-zA-Z0-9\_\.]+)")
time_pattern = re.compile("  \[([0-9\.]+) s, ([0-9]+) proof obligation(s)*\]")

def parse_wf(lines, i, file_result, adj_set):
    match1 = re.match(wf_pattern, lines[i])
    assert match1
    match2 = re.search(time_pattern, lines[i+1])
    assert match2

    proc_name = match1.group(1)
    adjusted = proc_name.split(".")[-1] in adj_set

    if proc_name not in file_result:
        file_result[proc_name] = dict()

    file_result[proc_name]["wf"] = [float(match2.group(1)), int(match2.group(2)), adjusted]
    return i + 1

def parse_impl(lines, i, file_result, adj_set):
    match1 = re.match(impl_pattern, lines[i])
    assert match1
    match2 = re.search(time_pattern, lines[i+1])
    assert match2

    proc_name = match1.group(1)
    adjusted = proc_name.split(".")[-1] in adj_set

    if proc_name not in file_result:
        file_result[proc_name] = dict()
    
    file_result[proc_name]["impl"] = [float(match2.group(1)), int(match2.group(2)), adjusted]
    return i + 1

def parse_file_traces(file_path, repo_result):
    f = open(file_path)
    lines = f.readlines()
    i = 0

    adjusted_set = set()
    file_name = file_path.split("/")[-1]
    file_name = file_name.replace(".p.out", "")

    if file_name not in repo_result:
        repo_result[file_name] = dict()

    while i < len(lines):
        line = lines[i]

        match1 = "Verifying CheckWellformed" in line
        match2 = "Verifying Impl" in line

        if "Parsing " in line:
            src_path = line[8:].strip()

        if match1:
            i = parse_wf(lines, i, repo_result[file_name], adjusted_set)
        elif match2:
            i = parse_impl(lines, i, repo_result[file_name], adjusted_set)
        else:
            # print(line)
            pass
        i += 1

def parse_repo_traces(repo_times_dir, repo_result):
    for file_name in os.listdir(repo_times_dir):
        if file_name.endswith(".p.out"):
            path = os.path.join(repo_times_dir, file_name)
            parse_file_traces(path, repo_result)

traces = dict()

for dir_name in os.listdir(RESULT_ROOT):
    traces[dir_name] = dict()
    parse_repo_traces(os.path.join(RESULT_ROOT, dir_name), traces[dir_name])

with open("/home/root/output/proc_time.json", "w") as f:
    f.write(json.dumps(traces))
