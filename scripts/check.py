import json

test_data = {}
curr_data = {}

with open("test.json", 'r') as file:
    test_data = json.load(file)

with open("proc_info.json", 'r') as file:
    curr_data = json.load(file)

test_lt="oopsla2022-linear-code"
curr_lt="veribetrkv-linear"

for file in test_data[test_lt]:
    if file not in curr_data[curr_lt]:
        print("file not in ! "+curr_lt+"    "+file)
        continue
    
    for proc in test_data[test_lt][file]:
        if proc.endswith("-proof"):
            continue

        if proc not in curr_data[curr_lt][file]:
            print("proc not in ! "+file+"    "+proc)
        else:
            test_loc = test_data[test_lt][file][proc]["loc"]
            curr_loc = curr_data[curr_lt][file][proc]["loc"]

            if test_loc != curr_loc:
                print("loc differs for "+file+"   "+proc+"   paper: "+str(test_loc)+", us: "+str(curr_loc))
        
        # assert proc in curr_data[curr_lt][file]
        # print("file "+file+" not in the current proc_info")
        # print(test_data[test_lt][file])
        # assert file in curr_data[curr_lt]

print("done!")