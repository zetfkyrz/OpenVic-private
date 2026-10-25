extends RefCounted
## Stopwatches for the performance debugger (PerfDebugger, F3). Scripts put `PerfProbe.begin("name")` and
## `PerfProbe.end("name")` around a heavy piece of code; while the debugger is closed they do nothing (one `if`).
## Use it through a preload: `const PerfProbe := preload("res://src/Utilities/PerfProbe.gd")`.

static var enabled: bool = false
# name -> { calls, last_ms, average_ms, max_ms, total_ms, start_us, frame_ms }
static var stats: Dictionary = {}


static func begin(probe_name: String) -> void:
	if not enabled:
		return
	var stat: Dictionary = stats.get(probe_name, {})
	if stat.is_empty():
		stat = { &"calls": 0, &"last_ms": 0.0, &"average_ms": 0.0, &"max_ms": 0.0, &"total_ms": 0.0, &"start_us": 0, &"frame_ms": 0.0 }
		stats[probe_name] = stat
	stat[&"start_us"] = Time.get_ticks_usec()


static func end(probe_name: String) -> void:
	if not enabled:
		return
	var stat: Dictionary = stats.get(probe_name, {})
	if stat.is_empty() or int(stat[&"start_us"]) == 0:
		return
	var ms: float = float(Time.get_ticks_usec() - int(stat[&"start_us"])) / 1000.0
	stat[&"start_us"] = 0
	stat[&"last_ms"] = ms
	stat[&"max_ms"] = maxf(float(stat[&"max_ms"]), ms)
	stat[&"total_ms"] = float(stat[&"total_ms"]) + ms
	stat[&"average_ms"] = ms if int(stat[&"calls"]) == 0 else float(stat[&"average_ms"]) * 0.95 + ms * 0.05
	stat[&"calls"] = int(stat[&"calls"]) + 1


static func reset() -> void:
	stats.clear()
