#!/usr/bin/env python3
"""Reads a callgrind output file (valgrind --tool=callgrind) and prints what costs the instructions. No callgrind_annotate needed.

  valgrind --tool=callgrind --callgrind-out-file=cg.out openvic-simulation.headless -b <Vic2> -e 35 -j 1
  python tools/callgrind_summary.py cg.out                       # the 40 functions with the most instructions of their own
  python tools/callgrind_summary.py cg.out --inclusive Politics  # functions whose name contains the text, with what they call (inclusive)
  python tools/callgrind_summary.py cg.out --callees monthly_update   # what a function spends its instructions on
  python tools/callgrind_summary.py cg.out --callers get_good_instance_by_index   # who calls a function and how much that costs
  python tools/callgrind_summary.py cg.out --lines add_pops_aggregate   # the source lines (also of inlined code) a function spends its instructions on

-e 35 contains the load of the game (the map, the files: about a third of the instructions) and one monthly tick; use -j 1 (callgrind runs threads one
after another anyway). Work done by the thread pool is counted in the functions of the pool's tasks, not in the function that started it.
"""
import argparse
import collections
import re


def parse(path, event="Ir"):
    names = {}
    files = {}
    own = collections.Counter()
    calls = collections.Counter()
    callees = collections.defaultdict(collections.Counter)
    callers = collections.defaultdict(collections.Counter)
    counts = collections.defaultdict(collections.Counter)
    call_count = 0
    lines = collections.defaultdict(collections.Counter)
    current = target = None
    current_file = None
    last_line = 0
    after_calls = False

    def name_of(token):
        match = re.match(r"\((\d+)\)\s*(.*)", token)
        if not match:
            return token
        if match.group(2):
            names[match.group(1)] = match.group(2)
        return names.get(match.group(1), match.group(1))

    def file_of(token):
        match = re.match(r"\((\d+)\)\s*(.*)", token)
        if not match:
            return token
        if match.group(2):
            files[match.group(1)] = match.group(2)
        return files.get(match.group(1), match.group(1))

    top_file = None
    column = 1
    for line in open(path, errors="replace"):
        line = line.rstrip("\n")
        if line.startswith("events:"):
            events = line.split()[1:]
            if event in events:
                column = 1 + events.index(event)
        elif line.startswith("fl="):
            top_file = current_file = file_of(line[3:])
        elif line.startswith("fi=") or line.startswith("fe="):
            current_file = file_of(line[3:])
        elif line.startswith("fn="):
            current = name_of(line[3:])
            current_file = top_file
            after_calls = False
        elif line.startswith("cfn="):
            target = name_of(line[4:])
        elif line.startswith("cfi=") or line.startswith("cfl="):
            file_of(line[4:])  # only to learn the name that the id stands for (the file of a call is not the file of the line)
        elif line.startswith("cob=") or line.startswith("ob="):
            pass
        elif line.startswith("calls="):
            after_calls = True
            call_count = int(line[6:].split()[0])
        elif line and (line[0].isdigit() or line[0] in "+-*"):
            parts = line.split()
            if len(parts) <= column:
                continue
            position = parts[0]
            if position == "*":
                pass
            elif position[0] in "+-":
                last_line += int(position)
            else:
                last_line = int(position)
            cost = int(parts[column])
            if after_calls:
                calls[current] += cost
                callees[current][target] += cost
                callers[target][current] += cost
                counts[target][current] += call_count
                after_calls = False
            else:
                own[current] += cost
                lines[current][(current_file, last_line)] += cost
    return own, calls, callees, callers, lines, counts


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("file")
    parser.add_argument("--inclusive", help="functions whose name contains this text")
    parser.add_argument("--callees", help="what the functions whose name contains this text call")
    parser.add_argument("--callers", help="who calls the functions whose name contains this text")
    parser.add_argument("--lines", help="the source lines the functions whose name contains this text spend their own instructions on")
    parser.add_argument("--top", type=int, default=40)
    parser.add_argument("--event", default="Ir", help="the event to count: Ir (instructions), or with --cache-sim=yes also D1mr, DLmr (misses of the first and the last cache level, reads)")
    args = parser.parse_args()
    own, calls, callees, callers, lines, counts = parse(args.file, args.event)
    if args.inclusive:
        rows = [(own[f] + calls[f], f) for f in own if args.inclusive in f]
        for cost, name in sorted(rows, reverse=True)[: args.top]:
            print("%14d %s" % (cost, name[:160]))
    elif args.callees:
        for function in own:
            if args.callees in function:
                print("FN %s (own %d)" % (function[:140], own[function]))
                for target, cost in callees[function].most_common(15):
                    print("   %12d %s" % (cost, target[:140]))
    elif args.callers:
        for function in callers:
            if args.callers in function:
                print("FN %s" % function[:140])
                for caller, cost in callers[function].most_common(15):
                    print("   %12d  (%d calls) %s" % (cost, counts[function][caller], caller[:130]))
    elif args.lines:
        for function in own:
            if args.lines in function:
                print("FN %s (own %d)" % (function[:140], own[function]))
                for (file_name, line_number), cost in lines[function].most_common(args.top):
                    print("   %12d %s:%d" % (cost, (file_name or "?").split("/")[-1], line_number))
    else:
        for function, cost in own.most_common(args.top):
            print("%14d %s" % (cost, function[:160]))


if __name__ == "__main__":
    main()
