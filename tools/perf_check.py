#!/usr/bin/env python3
"""Safety net for optimisations of the simulation (no game, no Godot needed, only the headless executable and Victoria 2).

An optimisation must not change what the simulation does: the CHECKSUM of the state after every day has to stay exactly the same.
  python tools/perf_check.py --save-baseline   # on the commit BEFORE your changes: writes docs/perf/baseline_checksums.json
  python tools/perf_check.py                   # after the changes: compares with the baseline, exit code 1 if anything differs
  python tools/perf_check.py --profile         # prints the times of the parts of the tick (the F12 scopes) over 120 days
Add --exe <path to openvic-simulation.headless> and --vic2 <path to Victoria 2> if they are not found by themselves
(the same search as in tools/run_tests.py). Run tools/run_tests.py as well before you push.

The baseline is only valid for the commit it was made on. A change that is MEANT to change the game (balance, rules) needs a new
baseline in its own commit (and a new Replay.hpp SIMULATION_VERSION if saved games are affected).
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASELINE = os.path.join(ROOT, "docs", "perf", "baseline_checksums.json")
TIMESTAMP = re.compile(r"^\[[^\]]*\]\s*")

# name -> arguments of the headless run (all with the CHECKSUM of every day); every run is repeated with one and with four threads
RUNS = {
    "default_60_days": ["-C", "-e", "60"],
    "ai_and_wars_30_days": ["-C", "-A", "-e", "30"],
}


def find_exe(given):
    if given:
        return given
    for folder in ("out/build/sim-selftest/bin/RelWithDebInfo", "out/build/sim-selftest/bin/Release", "out/build/sim-selftest"):
        for name in ("openvic-simulation.headless.exe", "openvic-simulation.headless"):
            path = os.path.join(ROOT, folder, name)
            if os.path.isfile(path):
                return path
    sys.exit("The headless executable was not found: build it (python tools/run_tests.py --build) or give --exe")


def find_vic2(given):
    for candidate in (given, os.environ.get("OPENVIC_VIC2_PATH"), os.path.join(ROOT, "Victoria 2 Heart of Darkness")):
        if candidate and os.path.isdir(candidate):
            return candidate
    sys.exit("Victoria 2 was not found: give --vic2 or set OPENVIC_VIC2_PATH")


def run(exe, vic2, arguments, threads):
    command = [exe, "-b", vic2] + arguments + (["-j", str(threads)] if threads else [])
    started = time.time()
    result = subprocess.run(command, capture_output=True, text=True, errors="replace")
    lines = [TIMESTAMP.sub("", line) for line in result.stdout.splitlines() if "CHECKSUM" in line]
    if not lines:
        sys.exit("No CHECKSUM lines (the run failed?): " + " ".join(command) + "\n" + result.stdout[-1500:] + result.stderr[-1500:])
    digest = hashlib.sha256("\n".join(lines).encode()).hexdigest()
    return {"lines": len(lines), "last": lines[-1], "sha256": digest, "seconds": round(time.time() - started, 1)}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--exe")
    parser.add_argument("--vic2")
    parser.add_argument("--save-baseline", action="store_true")
    parser.add_argument("--profile", action="store_true")
    args = parser.parse_args()
    exe = find_exe(args.exe)
    vic2 = find_vic2(args.vic2)

    if args.profile:
        result = subprocess.run([exe, "-b", vic2, "-e", "120", "-F"], capture_output=True, text=True, errors="replace")
        for line in result.stdout.splitlines():
            if line.startswith("PROFILE"):
                print(line)
        return 0

    results = {}
    for name, arguments in RUNS.items():
        for threads in (1, 4):
            key = "%s_j%d" % (name, threads)
            results[key] = run(exe, vic2, arguments, threads)
            print("%-28s %s (%d days, %.0f s)" % (key, results[key]["sha256"][:16], results[key]["lines"], results[key]["seconds"]))
        if results[name + "_j1"]["sha256"] != results[name + "_j4"]["sha256"]:
            print("FAIL: %s differs between 1 and 4 threads: the simulation is not deterministic (a data race?)" % name)
            return 1

    if args.save_baseline:
        os.makedirs(os.path.dirname(BASELINE), exist_ok=True)
        with open(BASELINE, "w", encoding="utf8") as file:
            json.dump({key: value["sha256"] for key, value in results.items()}, file, indent=2)
        print("Baseline written:", BASELINE)
        return 0

    if not os.path.isfile(BASELINE):
        print("No baseline yet: run with --save-baseline on the commit before your changes")
        return 1
    with open(BASELINE, encoding="utf8") as file:
        baseline = json.load(file)
    failed = [key for key, value in results.items() if baseline.get(key) != value["sha256"]]
    if failed:
        print("FAIL: the state of the simulation changed in", ", ".join(failed), "- the optimisation changed the behaviour")
        return 1
    print("OK: identical to the baseline (every day of every run)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
