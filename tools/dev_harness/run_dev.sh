#!/bin/bash
# Runs the game from the project folder with a piece of GDScript added to the session (screenshots, benchmarks, measurements of the frame).
# usage: tools/dev_harness/run_dev.sh <bodies/name.gd> [log file]
# The hooks are put into GameStart.gd and GameSession.gd for the run and removed afterwards (git checkout); if the run is killed by a
# timeout the files stay changed: take the hook blocks (between DEV CHECK BEGIN and END) out by hand, or git checkout the two files if they have no work of yours.
# Environment: GODOT_EXE (the Godot 4.7.2 executable), VK_LOADER_LAYERS_DISABLE='~implicit~' (the FPS Monitor overlay of Vulkan crashes
# Godot), OV_SIM_THREAD=0/1 (the simulation thread), OV_SIM_TRACE=<file>.
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
GODOT_EXE="${GODOT_EXE:-C:/Users/zetfk/Desktop/Godot/Godot_v4.7.2-stable_win64.exe}"
BODY="$1"
LOG="${2:-$REPO/out/dev_harness.log}"
mkdir -p "$REPO/out/dev_shots" "$APPDATA/OpenVic"
# The two files are put back from copies made now (not by git checkout: uncommitted work in them stays)
BACKUP="$(mktemp -d)"
cp "$REPO/game/src/Systems/Startup/GameStart.gd" "$BACKUP/GameStart.gd"
cp "$REPO/game/src/Systems/Session/GameSession.gd" "$BACKUP/GameSession.gd"
cleanup() {
  cp "$BACKUP/GameStart.gd" "$REPO/game/src/Systems/Startup/GameStart.gd"
  cp "$BACKUP/GameSession.gd" "$REPO/game/src/Systems/Session/GameSession.gd"
  rm -rf "$BACKUP"
  rm -f "$APPDATA/OpenVic/dev_check.txt"
}
trap cleanup EXIT
echo 1 > "$APPDATA/OpenVic/dev_check.txt"
python "$HERE/devui.py" "$HERE/$BODY" || exit 1
"$GODOT_EXE" --path "$REPO/game" --resolution 1920x1080 --position 0,0 > "$LOG" 2>&1
echo "godot exit=$?  log: $LOG  screenshots: $REPO/out/dev_shots"
