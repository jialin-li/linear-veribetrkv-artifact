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

def filter_for_methods(data):
    methods=[]
    for entry in data:
        if data[entry]["type"] == "method":
            methods.append(entry)
    return methods

def get_methods(dir):
    result = {}
    print("get_methods from " + dir)

    for filename in os.listdir(dir):
        name = filename.split(".")[0]
        if filename.endswith("-ghost"):
            with open(os.path.join(dir, filename), "r") as file:
                data = parse_file(file, filename, default_proc_list)
                result[name] = filter_for_methods(data)

    print("done collecting methods: " + dir)
    return result

def main():
    args = parser.parse_args()
    srcdir = args.input

    if not os.path.isdir(srcdir):
        print(args.input + " is not a directory.")
        exit(1)

    methods_data = {}
    methods_data[dynamic] = get_methods(os.path.join(srcdir, dynamic))
    methods_data[linear] = get_methods(os.path.join(srcdir, linear))

    with open("/home/root/output/methods_list.json", "w+") as out:
        json.dump(methods_data, out)

    print("done generate methods!~")

main()
