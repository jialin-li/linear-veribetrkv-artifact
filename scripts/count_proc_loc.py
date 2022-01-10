from parse_lib import *
import argparse
import pprint
import json
import copy
import csv
import os

parser = argparse.ArgumentParser(description="Parse dafny code on a per method basis.")
parser.add_argument("--input", dest="input", help="directory to read from", required=True)

pp = pprint.PrettyPrinter(indent=2)

dynamic="veribetrkv-dynamic-frames"
linear="veribetrkv-linear"

def parse_output(dir):
    result = {}
    result_code = {}
    print("parse results from " + dir)

    for filename in os.listdir(dir):
        name = filename.split(".")[0]
        if filename.endswith("-ghost"):
            with open(os.path.join(dir, filename), "r") as file:
                result[name] = parse_file(file, filename, default_proc_list)
        elif filename.endswith("-real"):
            with open(os.path.join(dir, filename), "r") as file:
                result_code[name] = parse_file(file, filename, default_proc_list) 
    print("done collecting loc data " + dir)

    return result, result_code

def parse_linear(dir):
    valid_ghost_result = {}
    result_method = {}
    result_method_code = {}
    print("parse results from " + dir)

    for filename in os.listdir(dir):
        name = filename.split(".")[0]
        if filename.endswith("-ghost"):
            with open(os.path.join(dir, filename), "r") as file:
                valid_ghost_result[name] = parse_file(file, filename, default_proc_list)
    print("done collecting ghost data")

    inout_dir = dir+"-inout"
    for filename in os.listdir(inout_dir):
        name = filename.split(".")[0]
        file_result = {}

        with open(os.path.join(inout_dir, filename), "r") as file:
            file_result = parse_file(file, filename, ["method", "constructor"])

        if filename.endswith("-ghost"):
            result_method[name] = file_result
        else:
            assert filename.endswith("-real")
            result_method_code[name] = file_result
    print("done collecting method data")

    return valid_ghost_result, result_method, result_method_code

def generate_linear_json(data, data_method):
    result = copy.deepcopy(data_method)

    for file in data:
        if file not in data_method:
            print("file "+file+" in linear but not linear-inout")
            result[file] = data[file]
            continue
        for proc in data[file]:
            if data[file][proc]["type"] != "method":
                result[file][proc] = data[file][proc]

    return result

# generate json file that separates compilable code and inline proof
def generate_code_json(data, data_code):
    print(">> generate_code_json start")
    result =  {}

    for file in data:
        result[file] = {}
        if file not in data_code:
            result[file] = data[file]
            continue
        for proc in data[file]:
            if data[file][proc]["type"] == "method":
                if proc not in data_code[file]:
                    continue
                assert proc in data_code[file]
                assert data[file][proc]["loc"] >= data_code[file][proc]["loc"]

                result[file][proc] = data_code[file][proc]
                result[file][proc+"-proof"] = { 
                    "loc": data[file][proc]["loc"]-data_code[file][proc]["loc"],
                    "type": "inlined proof"}
            else:
                if proc in data_code[file]:
                    print(data_code[file][proc])
                assert proc not in data_code[file]
                result[file][proc] = data[file][proc]
    print(">> generate_code_json end")

    # pp.pprint(result_clean)
    return result

def main():
    args = parser.parse_args()
    srcdir = args.input

    if not os.path.isdir(srcdir):
        print(args.input + " is not a directory.")
        exit(1)

    proc_data = {}

    # ghost result counts inline proof within a method as lines of the method
    # code result counts only executable lines of a method as its LoC

    dynamic_ghost, dynamic_code = parse_output(os.path.join(srcdir, dynamic))
    proc_data[dynamic] = generate_code_json(dynamic_ghost, dynamic_code)

    linear_ghost, linear_inout_code, linear_code = parse_linear(os.path.join(srcdir, linear))
    linear_combined = generate_linear_json(linear_ghost, linear_inout_code)
    proc_data[linear] = generate_code_json(linear_combined, linear_code)

    with open("/home/root/output/proc_info.json", "w+") as out:
        json.dump(proc_data, out)

    print("tada!~")

main()
