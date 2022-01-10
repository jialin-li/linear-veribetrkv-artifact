import matplotlib.pyplot as plt
import numpy as np
import csv

def p2c_str(proof, code):
    p2c = proof/code
    rounded = round(p2c, 1)
    if rounded.is_integer():
        rounded = int(rounded)
    return str(rounded)+":1"

def rel_diff(d_proof, l_proof):
    diff = 1 - l_proof/d_proof 
    rel_diff = round(diff *100, 1)
    return "-"+str(rel_diff)+"%"

with open("/home/root/output/loc.csv", "r") as file:
    reader = csv.reader(file)
    data = list(reader)

    types = ["Entire System", "Linearized", "Linearized & No Models", "Replaced Impl.", "Nonlinear"]

    lists = []
    for i in range(1, len(data)):
        lists.append([int(i) for i in data[i][1:]])            

    # right group
    d_ghost = lists[0]
    d_method = lists[1]
    l_ghost = lists[2]
    l_method = lists[3]

    bar_width = 0.25
    pos = np.array([0, 1.75, 3, 4.25, 5.5])

    fig, ax = plt.subplots(figsize=(10, 3))

    xticks_pos = np.array([0, 1.75, 3, 4.3, 5.5])
    plt.xticks(xticks_pos+1.5*bar_width, types)

    # this is the data for entire system
    print([sum(d_ghost)] + d_ghost)
    print([sum(d_method)] + d_method)
    print([sum(l_ghost)] + l_ghost)
    print([sum(l_method)] + l_method)

    plt.bar(pos, [sum(d_ghost)] + d_ghost, bar_width, color='CornflowerBlue', edgecolor='black')
    plt.bar(pos+bar_width, [sum(d_method)] + d_method, bar_width, color='CornflowerBlue', edgecolor='black', hatch='/////')
    plt.bar(pos+2*bar_width, [sum(l_ghost)] + l_ghost, bar_width, color='lightsteelblue', edgecolor='black')
    plt.bar(pos+3*bar_width, [sum(l_method)] + l_method, bar_width, color='lightsteelblue', edgecolor='black', hatch='xxxx')

    # left group labels
    ax.text(pos[0]+0.55*bar_width, 4500, p2c_str(sum(d_ghost), sum(d_method)), fontsize=10)
    ax.text(pos[0]+2.6*bar_width, 4500, p2c_str(sum(l_ghost), sum(l_method)), fontsize=10)
    ax.text(pos[0]+1.23*bar_width, 15000, rel_diff(sum(d_ghost), sum(l_ghost)), fontsize=10)

    # right group labels
    ax.text(pos[1]+0.52*bar_width, 2250, p2c_str(d_ghost[0], d_method[0]), fontsize=10)
    ax.text(pos[1]+2.63*bar_width, 2250, p2c_str(l_ghost[0], l_method[0]), fontsize=10)
    ax.text(pos[1]+1.3*bar_width, 9600, rel_diff(d_ghost[0], l_ghost[0]), fontsize=10)

    ax.text(pos[2]+0.52*bar_width, 1450, p2c_str(d_ghost[1], d_method[1]), fontsize=10)
    ax.text(pos[2]+2.66*bar_width, 1450, p2c_str(l_ghost[1], l_method[1]), fontsize=10)
    ax.text(pos[2]+1.3*bar_width, 3000, rel_diff(d_ghost[1], l_ghost[1]), fontsize=10)

    plt.tick_params(axis='x', length = 0)
    plt.tick_params(axis='y')

    plt.ylabel("LoC", loc="top")

    plt.legend(['VeriBetrKV-DF-proof', 'VeriBetrKV-DF-code', 'VeriBetrKV-LT-proof', 'VeriBetrKV-LT-code'], loc=1)

    plt.figtext(0.18, 0.01, "Figure (a)", wrap=True, weight="bold")
    plt.figtext(0.52, 0.01, "Figure (b)", wrap=True, weight="bold")

    plt.axvline(x=1.25, dashes=[2,2])
    plt.savefig( "/home/root/output/figures/loc-breakdown.png", transparent=False)

    print("loc breakdown graph exported")