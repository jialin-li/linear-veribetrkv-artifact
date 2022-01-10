import os, sys
from subprocess import Popen, PIPE, STDOUT
from os.path import exists

dfny_tool = "tools/local-dafny.sh /compile:0 /timeLimit:40 "
dfny_nl_tool = "tools/local-dafny-nonlinear.sh /compile:0 /timeLimit:40 "

RESULT_ROOT = "/home/root/output/time-data"

nl_files = {"BookkeepingModel.i.dfy",
    "IOImpl.i.dfy",
    "IOModel.i.dfy",
    "SyncImpl.i.dfy",
    "BookkeepingImpl.i.dfy",
    "Mkfs.i.dfy",
    "MkfsModel.i.dfy",
    "MarshallingImpl.i.dfy"}

def run_on_file(repo, output_dir, measure, path):
    file_name = path.split("/")[-1]
    print(file_name)
    assert(file_name.endswith(".dfy"))

    ouput_file = f"{output_dir}/{file_name}.{measure}.out"
    if exists(ouput_file):
        print(ouput_file + " already exists")
        return

    print("measuring", output_dir, path)
    if "veribetrkv-linear" in output_dir and path in nl_files:
        command = f"time {dfny_nl_tool} {path}"
        print("enabling nl")
    else:
        command = f"time {dfny_tool} {path}"

    if measure == "t":
        command += " /noVerify"
    if measure == "p":
        command += " /trace"

    p = Popen(command, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True, cwd=repo)
    output = p.stdout.read().decode("utf-8")

    with open(ouput_file, "w") as of:
        of.write(output)

def list_full_paths(dir_path):
    l = []
    for file_name in os.listdir(dir_path):
        if not file_name.endswith(".dfy"):
            continue
        full_path = os.path.join(dir_path, file_name)
        l.append(full_path)
    return l

def run_on_repo(repo, measure):
    files = list_full_paths(repo + "/Impl")
    files += list_full_paths(repo + "/lib/DataStructures")
    files += list_full_paths(repo + "/lib/Marshalling")
    files += list_full_paths(repo + "/lib/Buckets")

    repo_name = repo.split("/")[-1]
    output_dir = os.path.join(RESULT_ROOT, repo_name) 
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    for path in files:
        run_on_file(repo, output_dir, measure, path)

def run_on_small_files(repo, measure):
    files = list_full_paths(repo + "/Impl")
    repo_name = repo.split("/")[-1]

    output_dir = os.path.join(RESULT_ROOT, repo_name)
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    for f in files:
        if "Committer" in f:
            run_on_file(repo, output_dir, measure, f)

if __name__ == "__main__":
    repo = sys.argv[1]
    measure = sys.argv[2]

    assert measure in {"t", "v", "p"}

    if len((sys.argv)) == 4 and sys.argv[3] == "small":
        run_on_small_files(repo, measure)
    else:
        run_on_repo(repo, measure)