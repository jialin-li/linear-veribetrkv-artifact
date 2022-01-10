from equivmap import *
from filemap import *
import pprint
import json
import csv

pp = pprint.PrettyPrinter(indent=2)

dynamic = "veribetrkv-dynamic-frames"
linear = "veribetrkv-linear"

def get_vertime(entry):
  time = 0
  for type in entry:
    time = time + float(entry[type][0])
  return time

def update_term(toks):
  result = []
  for tok in toks:
    if "_" in tok:
      tok = '__'.join(tok.split("_"))
    if "constructor" in tok:
      tok = "__ctor"
    if tok.endswith(">"):
      tok = tok.split("<")[0]
    result.append(tok)
  return result    

# transform the proc name into vertime format name
def to_vname(name):
  toks = update_term(name.split("/"))
  if len(toks) == 2:
    return ".".join([toks[0], "__default", toks[1]])
  return ".".join(toks)

def find_vertime_entry(name, entries):
  vname = to_vname(name)
  if vname in entries:
    return True, vname
  else:
    assert vname != ""
    print("no entry: ["+ name+ "] -> ["+ vname+"]")
  return False, ""

def get_method_vertime(repo_methods, repo_time_data):
  result = {}
  for file in repo_methods:
    vfile = file + ".i.dfy" 
  
    if vfile not in repo_time_data:
      print("file "+ file +" does not exist in vertime")
      continue

    for method in repo_methods[file]:      
      found, vmethod = find_vertime_entry(method, repo_time_data[vfile])
      if found:
        assert method not in result
        result[method] = repo_time_data[vfile][vmethod]
  return result

def has_equiv(method, data):
  if method in data:
    return True, method

  base_idx = method.rfind('/')
  prefix = method[:base_idx]
  base = method[base_idx+1:]

  if prefix in EQUIV_MAP:
    for dprefix in EQUIV_MAP[prefix]["dname"]:
      if base in EQUIV_MAP[prefix]["methods"]:
        dmethod = "/".join([dprefix, EQUIV_MAP[prefix]["methods"][base]])
      else:
        dmethod = "/".join([dprefix, base])

      if dmethod in data:
        return True, dmethod
  return False, ""

def write_csv(result, out):
  writer = csv.writer(out, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)
  writer.writerow(["dl-diff-vtime-relative"])
  for entry in result:
    writer.writerow([entry[1]["reltime"]])

methods_data = {}
time_data = {}
methods_list = {}

with open("/home/root/output/proc_time.json", "r") as ptime:
  time_data = json.load(ptime)
with open("/home/root/output/methods_list.json", "r") as mlist:
  methods_list = json.load(mlist)
  
dyanmic_methods = get_method_vertime(methods_list[dynamic], time_data[dynamic])
linear_methods = get_method_vertime(methods_list[linear], time_data[linear])

# print(">>>> dynamic <<<<<")
# print(dyanmic_methods)
# print("------- linear ------")
# print(linear_methods)
# print("dmethods: "+str(len(dyanmic_methods))+ ", lmethods: "+str(len(linear_methods)))
    
skipped = 0
# looking for direct comparison of linearized methods
for lmethod in linear_methods:
  same, dmethod = has_equiv(lmethod, dyanmic_methods)
  if not same:
    skipped = skipped + 1
    print("No corresponding method in dynamic " + lmethod)
    continue

  # found corresponding dynamic frame method, add to methods_data
  methods_data[lmethod] = {
    "linear" : get_vertime(linear_methods[lmethod]),
    "dynamic" : get_vertime(dyanmic_methods[dmethod])
  }

# print(str(skipped))
# print(str(len(methods_data)))

# some linear methods are split up so we want to add back 
# the verification time of the splitted methods to be semantically equivalent
for prefix in EQUIV_MAP: 
  if "splits" in EQUIV_MAP[prefix]:
    for proc in EQUIV_MAP[prefix]["splits"]:
      xproc = "/".join([prefix, EQUIV_MAP[prefix]["splits"][proc]])
      # this will be true if we have verified data of the full system
      # but not true if we just have a subset of the system
      if xproc in linear_methods:
        proc = "/".join([prefix, proc])
        assert proc in methods_data
        methods_data[proc]["linear"] = methods_data[proc]["linear"] + get_vertime(linear_methods[xproc])

# export the direct method verification time comparison into a json file
with open("/home/root/output/method_df_linear.json", "w+") as out:
  json.dump(methods_data, out)

# we compute the relative execution time for methods that took over 5s to verify
over5s = {}

for m in methods_data:
  if methods_data[m]["dynamic"] > 5:
    reltime = methods_data[m]["linear"] / methods_data[m]["dynamic"] * 100
    over5s[m] = {}
    over5s[m]["vtime"] = methods_data[m]
    over5s[m]["reltime"] = reltime

sorted_reltime = sorted(over5s.items(), key=lambda kv: kv[1]["reltime"])
pp.pprint(sorted_reltime)

with open("/home/root/output/method_diff_relative_5s.csv", "w+") as out:
  write_csv(sorted_reltime, out)

print("done")