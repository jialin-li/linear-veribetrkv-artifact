import pprint
import strbalance

pp = pprint.PrettyPrinter(indent=2)
default_proc_list = ["method", "constructor", "function", "predicate", "lemma"]
type_map = {
    "method" : "method",
    "constructor": "method",
    "function" : "function",
    "predicate" : "function",
    "lemma": "lemma"
}

def parse_procedure_name(line):
    name = line.split("(")[0]
    toks = name.split("<") # get rid of templates
    return toks[0].split()[-1]

def unique_proc(data, name):
    if name in data:
        return unique_proc(data, name + "1")
    else:
        return name

def add_procedure(data, name, type, loc, line, file):
    name = unique_proc(data, name)
    data[name] = {}
    data[name]["type"] = type
    data[name]["loc"] = loc

def parse_procedure_type(line, proc_type_list):
    for type in proc_type_list:
        if type in line:
            return type_map[type]
    return ""

def is_procedure(line, proc_type_list):
    for token in line.split():
        for type in proc_type_list:
            if token == type:
                return True
    return False

def find_str_after(line, keyword):
    toks = list(filter(None, line.split(' ')))
    for i in range(0, len(toks)):
        if toks[i] == keyword:
            return toks[i+1]
    print("found no "+keyword)
    return ""

def prefix_append(prefix, str):
    return str if prefix == "" else prefix + "/" + str

def prefix_remove(prefix):
    i = prefix.rfind('/')
    return prefix[:i] if prefix[i] == '/' else ""

def update_scope_prefix(scope, line, prefix):
    scope = scope + line
    if strbalance.is_unbalanced(scope) == None:
        scope = ""
        prefix = prefix_remove(prefix)
    return scope, prefix

def has_pre_post(line):
    toks = line.split()
    for tok in toks:
        if "requires" == tok or "ensures" == tok or "decreases" == tok or "modifies" == tok or "reads" == tok:
            return True
    return False

# parse file
def parse_file(file, filename, proc_type_list):
    data = {}
    prefix = ""

    # tracks content of lines within scope 
    module_scope = ""
    datatype_scope = ""
    class_scope = ""
    proc_scope = ""

    proc_loc = 0
    proc_name = ""
    proc_type = ""

    for line in file:
        # continues until the first line without comment or warning
        if line.startswith("/"):
            continue

        # found a module, reset module scope
        if "module" in line:
            module_scope, prefix = update_scope_prefix("", line, find_str_after(line, "module"))
        else:
            if "class" in line:
                assert class_scope == ""
                class_scope, prefix = update_scope_prefix("", line,  prefix_append(prefix, find_str_after(line, "class")))
            elif "datatype" in line:
                assert datatype_scope == ""
                datatype_scope, prefix = update_scope_prefix("", line, prefix_append(prefix, find_str_after(line, "datatype")))
            else:
                new_proc = is_procedure(line, proc_type_list)
                if new_proc:
                    proc_type = parse_procedure_type(line, proc_type_list)
                    if proc_type_list == default_proc_list or proc_type != "method": 
                        proc_name = prefix_append(prefix, parse_procedure_name(line))
                    elif proc_type == "method":
                        proc_name = parse_procedure_name(line)
                    else:
                        assert False
                    proc_scope = line
                    proc_loc = 1
                else:
                    if proc_loc > 0:
                        proc_scope = proc_scope + line
                        proc_loc = proc_loc + 1
                        if has_pre_post(line):
                            continue
                        if strbalance.is_unbalanced(proc_scope) == None:
                            add_procedure(data, proc_name, proc_type, proc_loc, line, filename)
                            proc_scope = ""
                            proc_type = ""
                            proc_loc = 0
                    else:
                        assert proc_loc == 0
                        if class_scope != "":
                            class_scope, prefix = update_scope_prefix(class_scope, line, prefix)
                        elif datatype_scope != "":
                            datatype_scope, prefix = update_scope_prefix(datatype_scope, line, prefix)
                        elif module_scope != "":
                            module_scope, prefix = update_scope_prefix(module_scope, line, prefix)
    # pp.pprint(data)
    return data
