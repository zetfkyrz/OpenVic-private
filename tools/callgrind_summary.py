#!/usr/bin/env python3
"""Reads a callgrind output file (valgrind --tool=callgrind) and prints what costs the instructions. No callgrind_annotate needed.

  valgrind --tool=callgrind --callgrind-out-file=cg.out openvic-simulation.headless -b <Vic2> -e 35 -j 1
  python tools/callgrind_summary.py cg.out                       # the 40 functions with the most instructions of their own
  python tools/callgrind_summary.py cg.out --inclusive Politics  # functions whose name contains the text, with what they call (inclusive)
  python tools/callgrind_summary.py cg.out --callees monthly_update   # what a function spends its instructions on

-e 35 contains the load of the game (the map, the files: about a third of the instructions) and one monthly tick; use -j 1 (callgrind runs threads one
after another anyway). Work done by the thread pool is counted in the functions of the pool's tasks, not in the function that started it.
"""
import argparse
import collections
import re


def parse(path):
    names = {}
    own = collections.Counter()
    calls = collections.Counter()
    callees = collections.defaultdict(collections.Counter)
    current = target = None
    after_calls = False

    def name_of(token):
        match = re.match(r"\((\d+)\)\s*(.*)", token)
        if not match:
            return token
        if match.group(2):
            names[match.group(1)] = match.group(2)
        return names.get(match.group(1), match.group(1))

    for line in open(path, errors="replace"):
        line = line.rstrip("\n")
        if line.startswith("fn="):
            current = name_of(line[3:])
            after_calls = False
        elif line.startswith("cfn="):
            target = name_of(line[4:])
        elif line.startswith("calls="):
            after_calls = True
        elif line and (line[0].isdigit() or line[0] in "+-*"):
            parts = line.split()
            if len(parts) < 2:
                continue
            cost = int(parts[1])
            if after_calls:
                calls[current] += cost
                callees[current][target] += cost
                after_calls = False
            else:
                own[current] += cost
    return own, calls, callees


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("file")
    parser.add_argument("--inclusive", help="functions whose name contains this text")
    parser.add_argument("--callees", help="what the functions whose name contains this text call")
    parser.add_argument("--top", type=int, default=40)
    args = parser.parse_args()
    own, calls, callees = parse(args.file)
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
    else:
        for function, cost in own.most_common(args.top):
            print("%14d %s" % (cost, function[:160]))


if __name__ == "__main__":
    main()
