from filemap import *
import json

a = REPO_NAMES[0]
b = REPO_NAMES[1]

def get_time(data, file):
    if file in data:
        return float(data[file]["t"][0]), float(data[file]["p"][0])
    return 0, 0

with open("/home/root/output/file_time.json", "r") as file:
    times = json.load(file)
    results = []
    for (comp, sections) in COMPONENT_MAP.items():
        gp1_type_time = 0
        gp1_ver_time = 0

        gp2_type_time = 0
        gp2_ver_time = 0

        for section in sections:
            (gp1, gp2) = FILE_MAP[section]

            for file_name in gp1:
                t, v = get_time(times[a], file_name)
                gp1_type_time += t
                gp1_ver_time += v
    
            for file_name in gp2:
                t, v = get_time(times[b], file_name)
                gp2_type_time += t
                gp2_ver_time += v

        items = [comp, round(gp1_type_time, 2), round(gp1_ver_time, 2), round(gp2_type_time, 2), round(gp2_ver_time, 2)]
        print(items)
        results.append(items)

def percent_reduction(a, b):
    return (a - b) / a

import numpy as np
import matplotlib.pyplot as plt

comp_num = len(results)

dtype_time = []
d_adj_ver_time = []
ltype_time = []
l_adj_ver_time = []

for comp in results:
    dtype_time.append(comp[1])
    d_adj_ver_time.append(comp[2] - comp[1])
    ltype_time.append(comp[3])
    l_adj_ver_time.append(comp[4] - comp[3])

labels = list(COMPONENT_MAP.keys())

ind = np.arange(comp_num) # the x locations for the groups
width = 0.25
fig, ax = plt.subplots(figsize=(17, 5))

d_ver_time = np.add(d_adj_ver_time, dtype_time)
l_ver_time = np.add(l_adj_ver_time, ltype_time)
print(np.sum(d_adj_ver_time), np.sum(l_adj_ver_time))
print(percent_reduction(np.sum(d_ver_time), np.sum(l_ver_time)))

patterns = [ "///" , "xx" , "." , "o" ]

ax.bar(ind, dtype_time, width, color='blue', edgecolor='black', hatch=patterns[0])
ax.bar(ind, d_adj_ver_time, width, bottom=dtype_time, color='CornflowerBlue', edgecolor='black', hatch=patterns[0])
ax.bar(ind+width, ltype_time, width, color='chocolate', edgecolor='black', hatch=patterns[1])
ax.bar(ind+width, l_adj_ver_time, width, bottom=ltype_time, color='orange', edgecolor='black', hatch=patterns[1])

plt.ylabel('seconds', fontsize=20)
plt.xticks(ind+0.35*width, labels)

plt.tick_params(axis='x', length = 0, labelsize=20)
plt.tick_params(axis='y', labelsize=20)

ax.legend(labels=['VeriBetrKV-DF-TC', 'VeriBetrKV-DF-SMT', "VeriBetrKV-LT-TC", "VeriBetrKV-LT-SMT"], bbox_to_anchor=(0,1.02,1,0.2), loc="lower left", mode="expand", borderaxespad=0, ncol=4, prop={"size":19})
plt.savefig("/home/root/output/figures/module-vertime.png")

print("module verification time graph exported")