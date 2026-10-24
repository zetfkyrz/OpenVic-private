#!/usr/bin/env python3
"""Runs the self tests of the simulation with one command:

    python tools/run_tests.py [--vic2 PATH] [--exe PATH] [--build] [--pure-only]

1. finds (or with --build builds) the headless executable of the simulation,
2. runs the tests that need no game files (rates, defines, replay, save header),
3. runs the tests on a real game (determinism, save games, conservation of money) when the folder of Victoria 2 is known:
   --vic2, the environment variable OPENVIC_VIC2_PATH, the path in vic2.cfg of the game (base_defines_path) or a folder
   "Victoria 2 Heart of Darkness" in the root of the repository.
Exit code 0 only if every check passed. The tests are in extension/deps/openvic-simulation/src/headless/SelfTest.cpp.
"""
import argparse
import configparser
import glob
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIM = os.path.join(ROOT, "extension", "deps", "openvic-simulation")
EXE_NAME = "openvic-simulation.headless" + (".exe" if os.name == "nt" else "")
BUILD_DIR = os.path.join(ROOT, "out", "build", "sim-selftest")


def find_exe(explicit):
    candidates = [explicit, os.environ.get("OPENVIC_HEADLESS")]
    for base in (BUILD_DIR, os.path.join(ROOT, "build"), os.path.join(ROOT, "out", "build")):
        candidates += glob.glob(os.path.join(base, "**", EXE_NAME), recursive=True)
    for path in candidates:
        if path and os.path.isfile(path):
            return path
    return None


def build():
    """Builds only the simulation and its headless executable (no Godot needed)."""
    configure = ["cmake", "-S", SIM, "-B", BUILD_DIR, "-DCMAKE_BUILD_TYPE=RelWithDebInfo", "-DOPENVIC_SIM_BUILD_TESTS=OFF",
                 "-DOPENVIC_SIM_BUILD_HEADLESS=ON"]
    if subprocess.call(configure) != 0:
        return False
    return subprocess.call(["cmake", "--build", BUILD_DIR, "--target", "openvic-simulation-headless", "--parallel"]) == 0


def vic2_from_cfg():
    paths = [
        os.path.join(os.environ.get("APPDATA", ""), "OpenVic", "vic2.cfg"),
        os.path.expanduser("~/.local/share/godot/app_userdata/OpenVic/vic2.cfg"),
        os.path.expanduser("~/Library/Application Support/Godot/app_userdata/OpenVic/vic2.cfg"),
    ]
    for path in paths:
        if os.path.isfile(path):
            parser = configparser.ConfigParser()
            try:
                parser.read(path, encoding="utf-8")
                value = parser.get("victoria_2", "base_defines_path").strip('"')
            except (configparser.Error, OSError):
                continue
            if os.path.isdir(value):
                return value
    return None


def find_vic2(explicit):
    candidates = [explicit, os.environ.get("OPENVIC_VIC2_PATH"), vic2_from_cfg(), os.path.join(ROOT, "Victoria 2 Heart of Darkness")]
    for path in candidates:
        if path and os.path.isdir(path):
            return path
    return None


def run(command):
    """Runs the executable and prints the lines of the tests; returns (exit code, number of failed lines)."""
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace")
    failed = 0
    for line in process.stdout:
        if line.startswith(("TEST ", "SELFTEST")):
            print(line.rstrip())
            failed += line.startswith("TEST FAIL")
    return process.wait(), failed


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--vic2", help="folder of Victoria 2 Heart of Darkness")
    parser.add_argument("--exe", help="the headless executable (default: the one of the build folders)")
    parser.add_argument("--build", action="store_true", help="build the headless executable first (out/build/sim-selftest)")
    parser.add_argument("--pure-only", action="store_true", help="only the tests that need no game files")
    args = parser.parse_args()

    if args.build and not build():
        print("The build failed")
        return 2
    exe = find_exe(args.exe)
    if exe is None:
        print("The headless executable is not found: build it (python tools/run_tests.py --build) or give --exe")
        return 2
    print(f"Executable: {exe}")

    vic2 = None if args.pure_only else find_vic2(args.vic2)
    if vic2 is None:
        if not args.pure_only:
            print("The folder of Victoria 2 is not found (--vic2 or OPENVIC_VIC2_PATH): only the tests without game files run")
        code, failed = run([exe, "--selftest-pure"])
    else:
        print(f"Victoria 2: {vic2}")
        code, failed = run([exe, "-b", vic2, "--selftest"])  # the tests without game files run first
    result = 0 if code == 0 and failed == 0 else 1

    print("ALL TESTS PASSED" if result == 0 else "TESTS FAILED")
    return result


if __name__ == "__main__":
    sys.exit(main())
