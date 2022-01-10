# coding: utf-8

import pandas
import matplotlib.pyplot as plt
import matplotlib.ticker as mtick
import numpy as np

data = pandas.read_csv('/root/output/method_diff_relative_5s.csv')

def graph_refline(x, arr, p, **kwargs):
    y = np.interp(x, arr, p)
    plt.plot([x, x, 0], [0, y, y], **kwargs)
    print("("+str(x) + ","+ str(y)+")")
    return y

def find_x(y, arr, p):
    x = np.interp(y, p, arr)
    return x

def graph_y_based_refline(y, arr, p, ax):
    x = find_x(y, arr, p)
    graph_refline(x, arr, p, color="k", lw=1, dashes=[2, 2])
    x_str = str(round(x))+"%"
    y_str = str(round(y*100))+"%"
    ax.text(x+2, y-0.05, y_str+" of linear methods verify within "+x_str+" of their previous verification time", fontsize=16)

fig, ax = plt.subplots(figsize=(16, 4))
for col in data.columns:
    arr = np.array(data[col])
    arr = arr[~np.isnan(arr)]
    arr = np.sort(arr)
    print(col, arr)
    p = 1. * np.arange(len(arr)) / (len(arr) - 1)

    plt.plot(arr, p, label=col, lw=2)

    graph_y_based_refline(0.25, arr, p, ax)
    graph_y_based_refline(0.5, arr, p, ax)

    y = graph_refline(100, arr, p, color="k", lw=1, dashes=[2, 2])
    y_str = str(round(y*100))+"%"
    ax.text(102, y-0.05, y_str+" of linear methods verify faster than before", fontsize=16)

ax.xaxis.set_major_formatter(mtick.PercentFormatter())

# plt.xlabel("Method Verification Time Relative to VeriBetrKV-DF", fontsize=16)
plt.tick_params(axis='x', labelsize=14)
plt.tick_params(axis='y', labelsize=14)
plt.legend(labels=["VeriBetrKV-LT-Method"], loc=4, prop={"size":16})
plt.savefig('/root/output/figures/method-diff-cdf.png')
