# python3 scripts/generate_loc_csv.py

import csv
import json
import filemap

dynamic="veribetrkv-dynamic-frames"
linear="veribetrkv-linear"

def basename(name, idx) :
    basename = ""
    for base in filemap.FILE_MAP:
        for filename in filemap.FILE_MAP[base][idx]:
            if filename.startswith(name+"."):
                return base
    return basename

def get_category(name):
    for m in filemap.CHANGES_MAP:
        if name in filemap.CHANGES_MAP[m]:
            return m
    return ""

def csv_for_module_loc(data, repos, csvfile):
    results = {}

    for i in range(len(repos)):
        repo = repos[i]
        if repo not in results:
            results[repo] = {}
        for file in data[repo]:
            category = get_category(basename(file, i))
            if category == "":
                continue
            if category not in results[repo]:
                results[repo][category] = {}

            for proc in data[repo][file]:
                loc = data[repo][file][proc]['loc']
                proc_type = "code" if data[repo][file][proc]['type'] == "method" else "proof"
                if proc_type in results[repo][category]:
                    results[repo][category][proc_type] = results[repo][category][proc_type] + loc
                else:
                    results[repo][category][proc_type] = loc

    with open(csvfile, "w+") as file:
        writer = csv.writer(file, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)
        categories = list(filemap.CHANGES_MAP.keys())
        row = ['type'] + categories
        writer.writerow(row)

        types = [('dynamic-proof', repos[0], 'proof'), ('dynamic-code', repos[0], 'code'), 
            ('linear-proof', repos[1], 'proof'), ('linear-code', repos[1], 'code')]

        for t in types:
            sum = 0
            row = [t[0]]
            for c in categories:
                row.append(results[t[1]][c][t[2]])
                sum = sum + (results[t[1]][c][t[2]])
            writer.writerow(row)
            print(row)
            print(t[0]+": "+str(sum))

with open("/root/output/proc_info.json", 'r') as file:
    data = json.load(file)
    csv_for_module_loc(data, [dynamic, linear], "/root/output/loc.csv")
