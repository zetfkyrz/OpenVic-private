extends CanvasLayer
## Performance debugger, F12 opens and closes it. It shows where the time and the memory of the game go:
##  - "Обзор": frames per second, frame time, the speed of the game, the time of the ticks of the simulation with the
##    graphs against the budget of the speed, memory, objects;
##  - "Симуляция": every part of the tick and of the update of the gamestate with its time (last, average, maximum, share)
##    and the heaviest parts by their own time;
##  - "Интерфейс": what every handler of the update of the gamestate takes (the windows of the interface), the map colours;
##  - "Скрипты": stopwatches of the heavy scripts (PerfProbe);
##  - "Память": the memory of the process and of Godot, objects, nodes, orphan nodes, resources, video memory, with the growth
##    per minute and a verdict about possible leaks;
##  - "Рендер": draw calls, primitives, render time of the CPU and the GPU;
##  - "Журнал": slow frames and slow ticks with the parts that were the heaviest at that moment;
##  - "Тест": a benchmark that runs the game for a time at a speed and sums up the frames and ticks.
## The report (all tabs and the samples) is saved to user://perf/ with the button.

const PerfProbe := preload("res://src/Utilities/PerfProbe.gd")

# F12: the only function key the game and its interface do not use (F1-F8 are the hotkeys of the top bar, F4, F6-F11 of the windows)
const _TOGGLE_KEY: Key = KEY_F12
const _LAYOUT_FILE: String = "user://perf_debugger.cfg"
const _MIN_PANEL_SIZE := Vector2(560, 300)
const _MIN_SCALE: float = 0.6
const _MAX_SCALE: float = 2.5
const _TABS: PackedStringArray = ["Обзор", "Симуляция", "Интерфейс", "Скрипты", "Память", "Рендер", "Журнал", "Тест"]
const _FRAME_HISTORY: int = 300
const _SAMPLE_INTERVAL: float = 0.5
const _MAX_SAMPLES: int = 2400
const _MAX_SPIKES: int = 200
const _TEXT_REFRESH: float = 0.25
# A frame longer than this (or three times the average) is a spike
const _SPIKE_FRAME_MS: float = 50.0
const _GRAPH_COLOUR := Color(0.4, 0.85, 0.5)
const _BUDGET_COLOUR := Color(0.95, 0.35, 0.3)

var _panel: PanelContainer
var _text: RichTextLabel
var _graph_box: VBoxContainer
var _frame_graph: Graph
var _tick_graph: Graph
var _update_graph: Graph
var _memory_graph: Graph
var _nodes_graph: Graph
var _tab_buttons: Array[Button] = []
var _status: Label
var _tab: int = 0

# The window can be moved by its title, resized by the corner and scaled (the buttons A- / A+ or Ctrl + mouse wheel)
var _ui_scale: float = 1.0
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _resizing: bool = false
var _resize_start_mouse: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO

# Frames
var _frame_ms: PackedFloat32Array = PackedFloat32Array()
var _frame_count: int = 0
var _frame_max_ms: float = 0.0
var _frame_sum_ms: float = 0.0

# Samples of the memory and the counters every half second
var _samples: Array[Dictionary] = []
var _sample_timer: float = 0.0
var _text_timer: float = 0.0
var _start_msec: int = 0

# Slow frames and ticks
var _spikes: Array[Dictionary] = []
var _last_tick_calls: int = -1

# Benchmark
var _bench_running: bool = false
var _bench_speed: int = 4
var _bench_seconds: float = 60.0
var _bench_time: float = 0.0
var _bench_frames: PackedFloat32Array = PackedFloat32Array()
var _bench_tick_calls_start: int = 0
var _bench_start_sample: Dictionary = {}
var _bench_result: String = ""
var _bench_buttons: Array[Button] = []


## A line chart of the last values with optional horizontal lines (budgets)
class Graph extends Control:
	var values: PackedFloat32Array = PackedFloat32Array()
	var colour: Color = Color(0.4, 0.85, 0.5)
	var lines: Array[float] = []
	var line_colour: Color = Color(0.95, 0.35, 0.3)
	var caption: String = ""
	var unit: String = "мс"
	var fixed_max: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 70)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		var font: Font = ThemeDB.fallback_font
		if values.size() < 2:
			draw_string(font, Vector2(6, 14), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))
			return
		var maximum: float = fixed_max
		for value: float in values:
			maximum = maxf(maximum, value)
		for line: float in lines:
			maximum = maxf(maximum, line * 1.1)
		maximum = maxf(maximum, 0.001)
		var top: float = 16.0
		var height: float = size.y - top - 2.0
		var step: float = size.x / float(values.size() - 1)
		var previous := Vector2(0, size.y - 2.0 - values[0] / maximum * height)
		for i: int in range(1, values.size()):
			var point := Vector2(step * i, size.y - 2.0 - values[i] / maximum * height)
			draw_line(previous, point, colour, 1.5)
			previous = point
		for line: float in lines:
			var y: float = size.y - 2.0 - line / maximum * height
			draw_line(Vector2(0, y), Vector2(size.x, y), line_colour, 1.0)
		var last: float = values[values.size() - 1]
		draw_string(
			font, Vector2(6, 12),
			"%s   последнее %.1f %s, максимум %.1f %s" % [caption, last, unit, maximum, unit],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.9)
		)


func _ready() -> void:
	layer = 100
	visible = false
	_frame_ms.resize(_FRAME_HISTORY)
	_start_msec = Time.get_ticks_msec()
	_build_ui()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == _TOGGLE_KEY:
		_set_open(not visible)
		get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	visible = open
	GameSingleton.set_profiling(open)
	PerfProbe.enabled = open
	var viewport_rid: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, open)
	if open:
		_reset_all()
	elif _bench_running:
		_bench_running = false


# ---- Interface ----


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 70)
	_panel.custom_minimum_size = Vector2(900, 660)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.92)
	style.border_color = Color(0.5, 0.7, 0.9, 0.8)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override(&"panel", style)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 4)
	_panel.add_child(root)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(_on_header_input)
	root.add_child(header)
	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	title.text = "Отладчик производительности (F12) — тяните за заголовок"
	title.add_theme_color_override(&"font_color", Color(0.6, 0.85, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	for def: Array in [
		["A−", func() -> void: _set_ui_scale(_ui_scale - 0.1)], ["A+", func() -> void: _set_ui_scale(_ui_scale + 0.1)],
		["Сбросить", _reset_all], ["Сохранить отчёт", _save_report], ["Закрыть", func() -> void: _set_open(false)],
	]:
		var button := Button.new()
		button.text = def[0]
		button.pressed.connect(def[1])
		header.add_child(button)

	var tabs := HBoxContainer.new()
	root.add_child(tabs)
	for i: int in _TABS.size():
		var tab_button := Button.new()
		tab_button.text = _TABS[i]
		tab_button.toggle_mode = true
		tab_button.pressed.connect(_set_tab.bind(i))
		tabs.add_child(tab_button)
		_tab_buttons.append(tab_button)

	_graph_box = VBoxContainer.new()
	_graph_box.add_theme_constant_override(&"separation", 3)
	root.add_child(_graph_box)
	_frame_graph = _make_graph("Кадр", [16.7, 33.3])
	_tick_graph = _make_graph("Тик симуляции", [])
	_update_graph = _make_graph("Обновление состояния", [])
	_memory_graph = _make_graph("Память процесса", [])
	_memory_graph.unit = "МБ"
	_nodes_graph = _make_graph("Узлы сцены", [])
	_nodes_graph.unit = ""
	_nodes_graph.colour = Color(0.9, 0.75, 0.3)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = true
	_text.fit_content = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(0, 60)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
	_text.add_theme_font_override(&"normal_font", font)
	_text.add_theme_font_override(&"bold_font", font)
	_text.add_theme_font_size_override(&"normal_font_size", 12)
	_text.add_theme_font_size_override(&"bold_font_size", 12)
	root.add_child(_text)

	var bench := HBoxContainer.new()
	bench.name = "Bench"
	root.add_child(bench)
	var bench_label := Label.new()
	bench_label.text = "Тест: скорость"
	bench.add_child(bench_label)
	for speed: int in 5:
		var speed_button := Button.new()
		speed_button.text = str(speed + 1)
		speed_button.toggle_mode = true
		speed_button.pressed.connect(func() -> void: _bench_speed = speed; _update_bench_buttons())
		bench.add_child(speed_button)
		_bench_buttons.append(speed_button)
	var start := Button.new()
	start.text = "Запустить (60 с)"
	start.pressed.connect(_start_benchmark)
	bench.add_child(start)
	bench.visible = false
	_update_bench_buttons()

	var footer := HBoxContainer.new()
	root.add_child(footer)
	_status = Label.new()
	_status.add_theme_font_size_override(&"font_size", 11)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	footer.add_child(_status)
	var handle := Label.new()
	handle.text = " ◢ "
	handle.tooltip_text = "Потяните, чтобы изменить размер"
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	handle.gui_input.connect(_on_resize_input)
	footer.add_child(handle)

	_load_layout()

	_set_tab(0)


func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (event as InputEventMouseButton).pressed
		_drag_offset = _panel.position - get_viewport().get_mouse_position()
		if not _dragging:
			_save_layout()
	elif event is InputEventMouseMotion and _dragging:
		_panel.position = _clamp_position(get_viewport().get_mouse_position() + _drag_offset)


func _on_resize_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_resizing = (event as InputEventMouseButton).pressed
		_resize_start_mouse = get_viewport().get_mouse_position()
		_resize_start_size = _panel.size
		if not _resizing:
			_save_layout()
	elif event is InputEventMouseMotion and _resizing:
		var delta: Vector2 = (get_viewport().get_mouse_position() - _resize_start_mouse) / _ui_scale
		_apply_size((_resize_start_size + delta).max(_MIN_PANEL_SIZE))


func _apply_size(new_size: Vector2) -> void:
	_panel.custom_minimum_size = new_size
	_panel.size = new_size


func _clamp_position(pos: Vector2) -> Vector2:
	# At least the title stays on the screen so that the window can always be taken back
	var screen: Vector2 = get_viewport().get_visible_rect().size
	return Vector2(clampf(pos.x, 40.0 - _panel.size.x * _ui_scale, screen.x - 40.0), clampf(pos.y, 0.0, screen.y - 30.0))


func _set_ui_scale(value: float) -> void:
	_ui_scale = clampf(snappedf(value, 0.05), _MIN_SCALE, _MAX_SCALE)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	_panel.position = _clamp_position(_panel.position)
	_save_layout()


func _unhandled_input(event: InputEvent) -> void:
	# Ctrl + mouse wheel over the window changes its scale
	if visible and event is InputEventMouseButton and (event as InputEventMouseButton).pressed and Input.is_key_pressed(KEY_CTRL):
		var rect := Rect2(_panel.position, _panel.size * _ui_scale)
		if rect.has_point(get_viewport().get_mouse_position()):
			var button: int = (event as InputEventMouseButton).button_index
			if button == MOUSE_BUTTON_WHEEL_UP:
				_set_ui_scale(_ui_scale + 0.1)
				get_viewport().set_input_as_handled()
			elif button == MOUSE_BUTTON_WHEEL_DOWN:
				_set_ui_scale(_ui_scale - 0.1)
				get_viewport().set_input_as_handled()


func _save_layout() -> void:
	var config := ConfigFile.new()
	config.set_value("window", "position", _panel.position)
	config.set_value("window", "size", _panel.size)
	config.set_value("window", "scale", _ui_scale)
	config.save(_LAYOUT_FILE)


func _load_layout() -> void:
	var config := ConfigFile.new()
	if config.load(_LAYOUT_FILE) != OK:
		return
	_apply_size((config.get_value("window", "size", _panel.custom_minimum_size) as Vector2).max(_MIN_PANEL_SIZE))
	_ui_scale = clampf(float(config.get_value("window", "scale", 1.0)), _MIN_SCALE, _MAX_SCALE)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	_panel.position = _clamp_position(config.get_value("window", "position", _panel.position) as Vector2)


func _make_graph(caption: String, lines: Array[float]) -> Graph:
	var graph := Graph.new()
	graph.caption = caption
	graph.lines = lines
	_graph_box.add_child(graph)
	return graph


func _update_bench_buttons() -> void:
	for i: int in _bench_buttons.size():
		_bench_buttons[i].set_pressed_no_signal(i == _bench_speed)


func _set_tab(tab: int) -> void:
	_tab = tab
	for i: int in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == tab)
	_frame_graph.visible = tab == 0
	_tick_graph.visible = tab == 0 or tab == 1
	_update_graph.visible = tab == 0 or tab == 1
	_memory_graph.visible = tab == 4
	_nodes_graph.visible = tab == 4
	var bench: Node = _panel.find_child("Bench", true, false)
	if bench is CanvasItem:
		(bench as CanvasItem).visible = tab == 7
	_text_timer = 0.0


func _reset_all() -> void:
	GameSingleton.reset_profiling()
	PerfProbe.reset()
	_frame_ms.fill(0.0)
	_frame_count = 0
	_frame_max_ms = 0.0
	_frame_sum_ms = 0.0
	_samples.clear()
	_spikes.clear()
	_last_tick_calls = -1
	_start_msec = Time.get_ticks_msec()


# ---- Data every frame ----


func _process(delta: float) -> void:
	if not visible:
		return

	var frame_ms: float = delta * 1000.0
	_frame_ms[_frame_count % _FRAME_HISTORY] = frame_ms
	_frame_count += 1
	_frame_max_ms = maxf(_frame_max_ms, frame_ms)
	_frame_sum_ms += frame_ms
	if _bench_running:
		_bench_frames.append(frame_ms)

	var average: float = _average_frame_ms()
	if _frame_count > 30 and frame_ms > maxf(_SPIKE_FRAME_MS, average * 3.0):
		_add_spike("кадр", frame_ms)

	_sample_timer += delta
	if _sample_timer >= _SAMPLE_INTERVAL:
		_sample_timer = 0.0
		_take_sample()
		_check_ticks()

	if _bench_running:
		_bench_time += delta
		if _bench_time >= _bench_seconds:
			_finish_benchmark()

	_text_timer += delta
	if _text_timer >= _TEXT_REFRESH:
		_text_timer = 0.0
		_refresh()


func _average_frame_ms() -> float:
	var count: int = mini(_frame_count, _FRAME_HISTORY)
	if count == 0:
		return 0.0
	var sum: float = 0.0
	for i: int in count:
		sum += _frame_ms[i]
	return sum / float(count)


## The last frames in time order
func _ordered_frames() -> PackedFloat32Array:
	var count: int = mini(_frame_count, _FRAME_HISTORY)
	var result := PackedFloat32Array()
	result.resize(count)
	var first: int = _frame_count - count
	for i: int in count:
		result[i] = _frame_ms[(first + i) % _FRAME_HISTORY]
	return result


func _take_sample() -> void:
	var process_memory: Dictionary = GameSingleton.get_process_memory()
	var sample: Dictionary = {
		&"t": float(Time.get_ticks_msec() - _start_msec) / 1000.0,
		&"fps": Engine.get_frames_per_second(),
		&"frame_ms": _average_frame_ms(),
		&"rss": float(process_memory.get("working_set", 0)),
		&"private": float(process_memory.get("private_bytes", 0)),
		&"static": Performance.get_monitor(Performance.MEMORY_STATIC),
		&"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		&"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		&"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		&"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		&"vram": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		&"texture": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		&"buffer": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),
		&"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	}
	_samples.append(sample)
	if _samples.size() > _MAX_SAMPLES:
		_samples.pop_front()


## A tick that took longer than the interval of the speed (or 100 ms) is a spike of the simulation
func _check_ticks() -> void:
	var tick_entry: Dictionary = _find_entry(GameSingleton.get_sim_profile(), "tick")
	if tick_entry.is_empty():
		return
	var calls: int = int(tick_entry[&"calls"])
	if _last_tick_calls >= 0 and calls > _last_tick_calls:
		var info: Dictionary = GameSingleton.get_clock_info()
		var limit: float = minf(float(info.get("interval_ms", 100.0)), 100.0)
		var last_ms: float = float(tick_entry[&"last_ms"])
		if last_ms > limit:
			_add_spike("тик", last_ms)
	_last_tick_calls = calls


func _find_entry(entries: Array, path: String) -> Dictionary:
	for entry: Dictionary in entries:
		if entry[&"path"] == path:
			return entry
	return {}


func _add_spike(kind: String, ms: float) -> void:
	# What was the heaviest at the moment: the three largest scopes of the simulation by the last run
	var entries: Array = GameSingleton.get_sim_profile()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a[&"last_ms"]) > float(b[&"last_ms"]))
	var parts: PackedStringArray = []
	for entry: Dictionary in entries.slice(0, 4):
		parts.append("%s %.1f" % [entry[&"path"], float(entry[&"last_ms"])])
	var spike: Dictionary = {
		&"t": float(Time.get_ticks_msec() - _start_msec) / 1000.0,
		&"kind": kind,
		&"ms": ms,
		&"context": "; ".join(parts),
		&"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	}
	_spikes.append(spike)
	if _spikes.size() > _MAX_SPIKES:
		_spikes.pop_front()


# ---- Text of the tabs ----


func _refresh() -> void:
	var average: float = _average_frame_ms()
	var info: Dictionary = GameSingleton.get_clock_info()
	var tick_history: PackedFloat32Array = GameSingleton.get_tick_history()
	var update_history: PackedFloat32Array = GameSingleton.get_update_history()

	_frame_graph.values = _ordered_frames()
	_tick_graph.values = tick_history
	var budget: Array[float] = []
	if info.has("interval_ms"):
		budget.append(float(info["interval_ms"]))
	_tick_graph.lines = budget
	_update_graph.values = update_history
	for graph: Graph in [_frame_graph, _tick_graph, _update_graph]:
		graph.queue_redraw()
	if _tab == 4:
		var megabytes := PackedFloat32Array()
		var nodes := PackedFloat32Array()
		for sample: Dictionary in _samples:
			megabytes.append(float(sample[&"rss"]) / 1048576.0)
			nodes.append(float(sample[&"nodes"]))
		_memory_graph.values = megabytes
		_nodes_graph.values = nodes
		_memory_graph.queue_redraw()
		_nodes_graph.queue_redraw()

	_text.text = _build_text(_tab)
	_status.text = "Кадров: %d   среднее %.1f мс   максимум %.1f мс   замеров памяти: %d   долгих событий: %d" % [
		_frame_count, average, _frame_max_ms, _samples.size(), _spikes.size(),
	]


func _build_text(tab: int) -> String:
	match tab:
		0:
			return _text_overview()
		1:
			return _text_simulation()
		2:
			return _text_interface()
		3:
			return _text_scripts()
		4:
			return _text_memory()
		5:
			return _text_render()
		6:
			return _text_spikes()
		7:
			return _text_benchmark()
	return ""


func _colour_ms(ms: float, warn: float, bad: float) -> String:
	if ms >= bad:
		return "#ff6b5e"
	if ms >= warn:
		return "#ffc24a"
	return "#c8f0c8"


func _ms(ms: float, warn: float = 2.0, bad: float = 16.0) -> String:
	return "[color=%s]%s[/color]" % [_colour_ms(ms, warn, bad), ("%7.2f" % ms)]


func _mb(bytes: float) -> String:
	return "%.1f МБ" % (bytes / 1048576.0)


func _percentile(values: PackedFloat32Array, fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = Array(values)
	sorted.sort()
	return float(sorted[clampi(int(float(sorted.size() - 1) * fraction), 0, sorted.size() - 1)])


func _average(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var sum: float = 0.0
	for value: float in values:
		sum += value
	return sum / float(values.size())


func _text_overview() -> String:
	var lines: PackedStringArray = []
	var info: Dictionary = GameSingleton.get_clock_info()
	var frames: PackedFloat32Array = _ordered_frames()
	var tick_history: PackedFloat32Array = GameSingleton.get_tick_history()
	var update_history: PackedFloat32Array = GameSingleton.get_update_history()
	var frame_profile: Dictionary = GameSingleton.get_frame_profile()
	var interval: float = float(info.get("interval_ms", 0.0))
	var speeds: Array = info.get("speeds", [])

	lines.append("[b]Кадры[/b]")
	lines.append("  FPS %d   кадр: среднее %s мс, 95%% %s мс, 99%% %s мс, максимум %s мс" % [
		Engine.get_frames_per_second(), _ms(_average(frames), 17.0, 34.0), _ms(_percentile(frames, 0.95), 17.0, 34.0),
		_ms(_percentile(frames, 0.99), 17.0, 34.0), _ms(_frame_max_ms, 34.0, 100.0),
	])
	lines.append("  процесс (скрипты, UI) %s мс   физика %s мс" % [
		_ms(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 8.0, 16.0),
		_ms(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 4.0, 8.0),
	])
	lines.append("")
	lines.append("[b]Скорость игры[/b]")
	var speed_texts: PackedStringArray = []
	for i: int in speeds.size():
		speed_texts.append("%d: %d мс" % [i + 1, int(float(speeds[i]))])
	lines.append("  выбрана %s%s   интервалы дня: %s" % [
		str(int(info.get("speed", 0)) + 1), " (пауза)" if info.get("paused", true) else "", ", ".join(speed_texts),
	])
	var tick_average: float = _average(tick_history)
	var load: float = tick_average / interval * 100.0 if interval > 0.0 else 0.0
	lines.append("  тик симуляции: последний %s мс, среднее %s мс, 95%% %s мс, максимум %s мс" % [
		_ms(tick_history[tick_history.size() - 1] if not tick_history.is_empty() else 0.0, 30.0, interval),
		_ms(tick_average, 30.0, interval), _ms(_percentile(tick_history, 0.95), 30.0, interval),
		_ms(_percentile(tick_history, 1.0), 60.0, interval * 1.5),
	])
	lines.append("  загрузка бюджета скорости: [color=%s]%.0f %%[/color] (среднее время тика / интервал дня)" % [
		_colour_ms(load, 50.0, 90.0), load,
	])
	lines.append("  обновление состояния: среднее %s мс, максимум %s мс" % [
		_ms(_average(update_history), 20.0, 60.0), _ms(_percentile(update_history, 1.0), 40.0, 120.0),
	])
	lines.append("  вызов update_clock за кадр: %s мс (ср. %s, макс. %s)" % [
		_ms(float(frame_profile.get("clock_ms", 0.0)), 20.0, 80.0), _ms(float(frame_profile.get("clock_average_ms", 0.0)), 20.0, 80.0),
		_ms(float(frame_profile.get("clock_max_ms", 0.0)), 40.0, 150.0),
	])
	lines.append("  сигнал gamestate_updated (интерфейс): %s мс (ср. %s, макс. %s), цвета карты %s мс" % [
		_ms(float(frame_profile.get("signal_ms", 0.0)), 5.0, 20.0), _ms(float(frame_profile.get("signal_average_ms", 0.0)), 5.0, 20.0),
		_ms(float(frame_profile.get("signal_max_ms", 0.0)), 10.0, 40.0), _ms(float(frame_profile.get("colours_ms", 0.0)), 3.0, 10.0),
	])
	lines.append("")
	lines.append("[b]Память и объекты[/b]")
	var process_memory: Dictionary = GameSingleton.get_process_memory()
	lines.append("  процесс: в ОЗУ %s (пик %s), выделено %s" % [
		_mb(float(process_memory.get("working_set", 0))), _mb(float(process_memory.get("peak_working_set", 0))),
		_mb(float(process_memory.get("private_bytes", 0))),
	])
	lines.append("  Godot: статическая %s, видеопамять %s   узлов %d, объектов %d, ресурсов %d, сирот %d" % [
		_mb(Performance.get_monitor(Performance.MEMORY_STATIC)), _mb(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
	])
	var sizes: Dictionary = GameSingleton.get_sim_sizes()
	if not sizes.is_empty():
		lines.append("  симуляция: действий в истории %d, войн %d, кредитов %d" % [
			int(sizes.get("action_history", 0)), int(sizes.get("wars", 0)), int(sizes.get("loans", 0)),
		])
	lines.append("")
	lines.append(_leak_verdict_short())
	lines.append("")
	lines.append("[color=#8899aa]Подсказка: вкладка «Симуляция» показывает самые тяжёлые части тика, «Интерфейс» — какие окна тормозят при обновлении, «Тест» — замер на скорости.[/color]")
	return "\n".join(lines)


func _text_simulation() -> String:
	var entries: Array = GameSingleton.get_sim_profile()
	var lines: PackedStringArray = []
	if entries.is_empty():
		return "Пока нет данных: запустите игру (снимите паузу), замеры собираются при открытом отладчике."

	var tick_average: float = 0.0
	var update_average: float = 0.0
	for entry: Dictionary in entries:
		if entry[&"path"] == "tick":
			tick_average = float(entry[&"average_ms"])
		elif entry[&"path"] == "update_gamestate":
			update_average = float(entry[&"average_ms"])

	lines.append("[b]Части тика и обновления[/b] (время в мс; доля — от среднего времени родителя верхнего уровня)")
	lines.append("[color=#8899aa]%s %s %s %s %s %s[/color]" % [
		"часть".rpad(44), "послед.".lpad(8), "среднее".lpad(8), "макс.".lpad(8), "вызовов".lpad(8), "доля".lpad(6),
	])
	for entry: Dictionary in entries:
		var depth: int = int(entry[&"depth"])
		var root_average: float = tick_average if String(entry[&"path"]).begins_with("tick") else update_average
		var share: float = float(entry[&"average_ms"]) / root_average * 100.0 if root_average > 0.0 else 0.0
		var label: String = ("  ".repeat(depth) + String(entry[&"name"])).rpad(44)
		lines.append("%s %s %s %s %s %5.0f%%" % [
			label, _ms(float(entry[&"last_ms"]), 5.0, 30.0), _ms(float(entry[&"average_ms"]), 5.0, 30.0),
			_ms(float(entry[&"max_ms"]), 10.0, 60.0), str(entry[&"calls"]).lpad(8), share,
		])

	lines.append("")
	lines.append("[b]Самое тяжёлое по собственному времени[/b] (без вложенных частей, по среднему)")
	var own: Array = []
	for entry: Dictionary in entries:
		var children_sum: float = 0.0
		for other: Dictionary in entries:
			if String(other[&"path"]).begins_with(String(entry[&"path"]) + "/") and int(other[&"depth"]) == int(entry[&"depth"]) + 1:
				children_sum += float(other[&"average_ms"])
		own.append({ &"path": entry[&"path"], &"own": maxf(float(entry[&"average_ms"]) - children_sum, 0.0) })
	own.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a[&"own"]) > float(b[&"own"]))
	for i: int in mini(10, own.size()):
		lines.append("  %2d. %s  %s мс" % [i + 1, String(own[i][&"path"]).rpad(52), _ms(float(own[i][&"own"]), 5.0, 30.0)])
	return "\n".join(lines)


func _text_interface() -> String:
	var lines: PackedStringArray = []
	var frame_profile: Dictionary = GameSingleton.get_frame_profile()
	lines.append("[b]Обновление интерфейса при каждом обновлении состояния[/b]")
	lines.append("  цвета карты %s мс, все обработчики сигнала %s мс (среднее %s, максимум %s), обновлений: %d" % [
		_ms(float(frame_profile.get("colours_ms", 0.0)), 3.0, 10.0), _ms(float(frame_profile.get("signal_ms", 0.0)), 5.0, 20.0),
		_ms(float(frame_profile.get("signal_average_ms", 0.0)), 5.0, 20.0), _ms(float(frame_profile.get("signal_max_ms", 0.0)), 10.0, 40.0),
		int(frame_profile.get("updates", 0)),
	])
	lines.append("")
	var handlers: Array = GameSingleton.get_ui_profile()
	if handlers.is_empty():
		lines.append("Пока нет данных: обработчики замеряются при обновлении состояния (идёт игра).")
		return "\n".join(lines)
	handlers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a[&"average_ms"]) > float(b[&"average_ms"]))
	lines.append("[color=#8899aa]%s %s %s %s %s[/color]" % ["обработчик".rpad(62), "среднее".lpad(8), "послед.".lpad(8), "макс.".lpad(8), "вызовов".lpad(8)])
	for handler: Dictionary in handlers:
		lines.append("%s %s %s %s %s" % [
			String(handler[&"name"]).rpad(62).substr(0, 62), _ms(float(handler[&"average_ms"]), 1.0, 5.0),
			_ms(float(handler[&"last_ms"]), 1.0, 5.0), _ms(float(handler[&"max_ms"]), 3.0, 15.0), str(handler[&"calls"]).lpad(8),
		])
	return "\n".join(lines)


func _text_scripts() -> String:
	var lines: PackedStringArray = []
	lines.append("[b]Секундомеры скриптов[/b] (PerfProbe.begin / end в тяжёлых местах)")
	if PerfProbe.stats.is_empty():
		lines.append("Пока нет данных.")
		return "\n".join(lines)
	var names: Array = PerfProbe.stats.keys()
	names.sort_custom(func(a: String, b: String) -> bool:
		return float(PerfProbe.stats[a][&"average_ms"]) > float(PerfProbe.stats[b][&"average_ms"])
	)
	lines.append("[color=#8899aa]%s %s %s %s %s %s[/color]" % ["место".rpad(40), "среднее".lpad(8), "послед.".lpad(8), "макс.".lpad(8), "вызовов".lpad(9), "всего, с".lpad(9)])
	for probe_name: String in names:
		var stat: Dictionary = PerfProbe.stats[probe_name]
		lines.append("%s %s %s %s %s %9.2f" % [
			probe_name.rpad(40), _ms(float(stat[&"average_ms"]), 1.0, 4.0), _ms(float(stat[&"last_ms"]), 1.0, 4.0),
			_ms(float(stat[&"max_ms"]), 4.0, 16.0), str(stat[&"calls"]).lpad(9), float(stat[&"total_ms"]) / 1000.0,
		])
	return "\n".join(lines)


# Growth of a value per minute by a straight line through the last samples
func _slope_per_minute(key: StringName, seconds: float = 120.0) -> float:
	if _samples.size() < 20:
		return 0.0
	var last_time: float = float(_samples[_samples.size() - 1][&"t"])
	var points: Array[Vector2] = []
	for i: int in range(_samples.size() - 1, -1, -1):
		var sample: Dictionary = _samples[i]
		if last_time - float(sample[&"t"]) > seconds:
			break
		points.append(Vector2(float(sample[&"t"]), float(sample[key])))
	if points.size() < 10:
		return 0.0
	var mean_x: float = 0.0
	var mean_y: float = 0.0
	for point: Vector2 in points:
		mean_x += point.x
		mean_y += point.y
	mean_x /= points.size()
	mean_y /= points.size()
	var numerator: float = 0.0
	var denominator: float = 0.0
	for point: Vector2 in points:
		numerator += (point.x - mean_x) * (point.y - mean_y)
		denominator += (point.x - mean_x) * (point.x - mean_x)
	return numerator / denominator * 60.0 if denominator > 0.0 else 0.0


func _monitored_seconds() -> float:
	if _samples.is_empty():
		return 0.0
	return float(_samples[_samples.size() - 1][&"t"]) - float(_samples[0][&"t"])


func _leak_verdict_short() -> String:
	if _monitored_seconds() < 60.0:
		return "[b]Утечки:[/b] нужно минимум минута наблюдения (прошло %.0f с)" % _monitored_seconds()
	var suspects: PackedStringArray = []
	if _slope_per_minute(&"rss") > 20.0 * 1048576.0:
		suspects.append("память процесса растёт на %s/мин" % _mb(_slope_per_minute(&"rss")))
	if _slope_per_minute(&"nodes") > 30.0:
		suspects.append("узлы +%.0f/мин" % _slope_per_minute(&"nodes"))
	if _slope_per_minute(&"orphans") > 0.5:
		suspects.append("сироты +%.1f/мин" % _slope_per_minute(&"orphans"))
	if _slope_per_minute(&"resources") > 30.0:
		suspects.append("ресурсы +%.0f/мин" % _slope_per_minute(&"resources"))
	if suspects.is_empty():
		return "[b]Утечки:[/b] [color=#c8f0c8]роста памяти и объектов не видно[/color]"
	return "[b]Утечки:[/b] [color=#ff6b5e]возможны: %s[/color] (подробности на вкладке «Память»)" % ", ".join(suspects)


func _text_memory() -> String:
	var lines: PackedStringArray = []
	lines.append("[b]Память и объекты[/b] (замер каждые %.1f с, наблюдение %.0f с)" % [_SAMPLE_INTERVAL, _monitored_seconds()])
	if _samples.is_empty():
		return "\n".join(lines) + "\nЗамеры ещё не начались."
	var first: Dictionary = _samples[0]
	var last: Dictionary = _samples[_samples.size() - 1]
	lines.append("[color=#8899aa]%s %s %s %s %s[/color]" % ["показатель".rpad(28), "сейчас".lpad(12), "в начале".lpad(12), "рост".lpad(12), "в минуту".lpad(12)])
	var rows: Array = [
		["Память процесса (ОЗУ)", &"rss", true], ["Выделено процессом", &"private", true], ["Память Godot (статич.)", &"static", true],
		["Видеопамять всего", &"vram", true], ["  текстуры", &"texture", true], ["  буферы", &"buffer", true],
		["Узлы сцены", &"nodes", false], ["Объекты", &"objects", false], ["Ресурсы", &"resources", false], ["Узлы-сироты", &"orphans", false],
	]
	for row: Array in rows:
		var key: StringName = row[1]
		var bytes: bool = row[2]
		var now: float = float(last[key])
		var start: float = float(first[key])
		var slope: float = _slope_per_minute(key)
		var fmt_now: String = _mb(now) if bytes else str(int(now))
		var fmt_start: String = _mb(start) if bytes else str(int(start))
		var fmt_delta: String = _mb(now - start) if bytes else "%+d" % int(now - start)
		var fmt_slope: String = _mb(slope) if bytes else "%+.1f" % slope
		lines.append("%s %s %s %s %s" % [String(row[0]).rpad(28), fmt_now.lpad(12), fmt_start.lpad(12), fmt_delta.lpad(12), fmt_slope.lpad(12)])
	lines.append("")
	lines.append(_leak_verdict_short())
	lines.append("")
	lines.append("[b]Как искать утечку[/b]")
	lines.append("  Растут узлы и сироты — окна создают элементы и не удаляют (смотрите, что вы делали в эти минуты).")
	lines.append("  Растёт память процесса при стабильных узлах — данные симуляции или текстуры (ищите по списку «Симуляция» и размерам ниже).")
	lines.append("  Растёт видеопамять — текстуры карты или окна запекания пересоздаются.")
	var sizes: Dictionary = GameSingleton.get_sim_sizes()
	if not sizes.is_empty():
		lines.append("")
		lines.append("[b]Размеры данных симуляции[/b]")
		for key: Variant in sizes:
			lines.append("  %s %d" % [String(key).rpad(20), int(sizes[key])])
	return "\n".join(lines)


func _text_render() -> String:
	var lines: PackedStringArray = []
	var rid: RID = get_viewport().get_viewport_rid()
	lines.append("[b]Рендер[/b]")
	lines.append("  вызовов отрисовки %d   объектов в кадре %d   примитивов %d" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
	])
	lines.append("  время кадра: CPU %s мс, GPU %s мс (замер Godot)" % [
		_ms(RenderingServer.viewport_get_measured_render_time_cpu(rid), 6.0, 14.0),
		_ms(RenderingServer.viewport_get_measured_render_time_gpu(rid), 6.0, 14.0),
	])
	lines.append("  видеопамять: всего %s, текстуры %s, буферы %s" % [
		_mb(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)), _mb(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		_mb(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
	])
	lines.append("")
	lines.append("[b]Окно и карта[/b]")
	var window_size: Vector2i = get_window().size
	lines.append("  окно %dx%d   масштаб содержимого %s   режим окна %d" % [
		window_size.x, window_size.y, str(get_window().content_scale_size), int(get_window().mode),
	])
	lines.append("  качество карты %s, тени: %s, размер %s, тёмность %s" % [
		str(GameSettings.get_setting(GameSettings.VIDEO_MAP_QUALITY).value()),
		"вкл" if GameSettings.get_setting(GameSettings.VIDEO_MAP_SHADOWS).value() else "выкл",
		str(GameSettings.get_setting(GameSettings.VIDEO_SHADOW_DISTANCE).value()),
		str(GameSettings.get_setting(GameSettings.VIDEO_SHADOW_DARKNESS).value()),
	])
	lines.append("")
	lines.append("[color=#8899aa]Если GPU долго (≥ кадра), снизьте «Качество карты» или тени в настройках; если CPU — смотрите «Скрипты» и «Интерфейс».[/color]")
	return "\n".join(lines)


func _text_spikes() -> String:
	var lines: PackedStringArray = []
	lines.append("[b]Долгие кадры (> %d мс или втрое дольше среднего) и долгие тики (дольше интервала дня или 100 мс)[/b]" % int(_SPIKE_FRAME_MS))
	if _spikes.is_empty():
		lines.append("Пока ничего не было.")
		return "\n".join(lines)
	lines.append("[color=#8899aa]%s %s %s  %s[/color]" % ["время, с".lpad(9), "что".rpad(6), "мс".lpad(8), "самые тяжёлые части симуляции в этот момент"])
	for i: int in range(_spikes.size() - 1, maxi(_spikes.size() - 60, -1), -1):
		var spike: Dictionary = _spikes[i]
		lines.append("%9.1f %s %s  %s" % [float(spike[&"t"]), String(spike[&"kind"]).rpad(6), _ms(float(spike[&"ms"]), 50.0, 150.0), spike[&"context"]])
	return "\n".join(lines)


# ---- Benchmark ----


func _start_benchmark() -> void:
	if _bench_running:
		return
	# The game goes to the chosen speed and runs
	var info: Dictionary = GameSingleton.get_clock_info()
	if info.get("paused", true):
		PlayerSingleton.toggle_paused()
	var guard: int = 0
	while int(GameSingleton.get_clock_info().get("speed", 0)) != _bench_speed and guard < 10:
		if int(GameSingleton.get_clock_info().get("speed", 0)) < _bench_speed:
			PlayerSingleton.increase_speed()
		else:
			PlayerSingleton.decrease_speed()
		guard += 1
	_reset_all()
	_bench_frames = PackedFloat32Array()
	_bench_time = 0.0
	_bench_running = true
	_bench_result = ""
	_take_sample()
	_bench_start_sample = _samples[_samples.size() - 1] if not _samples.is_empty() else {}
	var tick_entry: Dictionary = _find_entry(GameSingleton.get_sim_profile(), "tick")
	_bench_tick_calls_start = int(tick_entry.get("calls", 0))


func _finish_benchmark() -> void:
	_bench_running = false
	_take_sample()
	var info: Dictionary = GameSingleton.get_clock_info()
	var tick_history: PackedFloat32Array = GameSingleton.get_tick_history()
	var tick_entry: Dictionary = _find_entry(GameSingleton.get_sim_profile(), "tick")
	var ticks: int = int(tick_entry.get("calls", 0)) - _bench_tick_calls_start
	var interval: float = float(info.get("interval_ms", 0.0))
	var over_budget: int = 0
	for value: float in tick_history:
		if value > interval:
			over_budget += 1
	var last: Dictionary = _samples[_samples.size() - 1] if not _samples.is_empty() else {}
	var lines: PackedStringArray = []
	lines.append("[b]Результат теста[/b]: скорость %d (день каждые %d мс), %.0f с" % [_bench_speed + 1, int(interval), _bench_time])
	lines.append("  игровых дней: %d (%.2f дня/с, при пределе %.2f)" % [ticks, ticks / maxf(_bench_time, 0.001), 1000.0 / maxf(interval, 1.0)])
	lines.append("  кадры: среднее %.1f мс, 95%% %.1f мс, 99%% %.1f мс, максимум %.1f мс, FPS среднее %.0f" % [
		_average(_bench_frames), _percentile(_bench_frames, 0.95), _percentile(_bench_frames, 0.99), _percentile(_bench_frames, 1.0),
		1000.0 / maxf(_average(_bench_frames), 0.001),
	])
	lines.append("  тики: среднее %.1f мс, 95%% %.1f мс, 99%% %.1f мс, максимум %.1f мс, дольше интервала: %d из %d" % [
		_average(tick_history), _percentile(tick_history, 0.95), _percentile(tick_history, 0.99), _percentile(tick_history, 1.0),
		over_budget, tick_history.size(),
	])
	if not _bench_start_sample.is_empty() and not last.is_empty():
		lines.append("  память процесса: %s → %s, узлов %d → %d, объектов %d → %d, сирот %d → %d" % [
			_mb(float(_bench_start_sample[&"rss"])), _mb(float(last[&"rss"])), int(_bench_start_sample[&"nodes"]), int(last[&"nodes"]),
			int(_bench_start_sample[&"objects"]), int(last[&"objects"]), int(_bench_start_sample[&"orphans"]), int(last[&"orphans"]),
		])
	var verdict: String = "[color=#c8f0c8]скорость держится[/color]"
	if over_budget > tick_history.size() / 10:
		verdict = "[color=#ff6b5e]тики не укладываются в интервал дня: на этой скорости игра тормозит (нужны более медленный интервал или оптимизация самых тяжёлых частей)[/color]"
	lines.append("  вывод: " + verdict)
	var entries: Array = GameSingleton.get_sim_profile()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a[&"average_ms"]) > float(b[&"average_ms"]))
	lines.append("  самые тяжёлые части тика (среднее, мс):")
	var shown: int = 0
	for entry: Dictionary in entries:
		if entry[&"path"] == "tick" or entry[&"path"] == "update_gamestate":
			continue
		lines.append("    %s %.2f" % [String(entry[&"path"]).rpad(46), float(entry[&"average_ms"])])
		shown += 1
		if shown >= 6:
			break
	_bench_result = "\n".join(lines)
	_save_report()


func _text_benchmark() -> String:
	var lines: PackedStringArray = []
	lines.append("[b]Тест производительности[/b]")
	lines.append("  Выберите скорость и нажмите «Запустить»: игра идёт 60 секунд на этой скорости, отладчик пишет кадры, тики и память,")
	lines.append("  потом показывает итог и сохраняет отчёт в user://perf/.")
	lines.append("")
	if _bench_running:
		lines.append("[color=#ffc24a]Идёт тест: %.0f из %.0f с[/color]" % [_bench_time, _bench_seconds])
	elif not _bench_result.is_empty():
		lines.append(_bench_result)
	else:
		lines.append("Теста ещё не было.")
	return "\n".join(lines)


# ---- Report ----


func _strip_bbcode(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\[/?[a-z]+(=[^\\]]*)?\\]")
	return regex.sub(text, "", true)


func _save_report() -> void:
	DirAccess.make_dir_recursive_absolute("user://perf")
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path: String = "user://perf/perf_" + stamp + ".txt"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_status.text = "Не удалось записать отчёт"
		return
	file.store_line("Отчёт отладчика производительности OpenVic, " + Time.get_datetime_string_from_system())
	file.store_line("Версия движка: " + Engine.get_version_info()["string"])
	file.store_line("")
	for i: int in _TABS.size():
		file.store_line("=== " + _TABS[i] + " ===")
		file.store_line(_strip_bbcode(_build_text(i)))
		file.store_line("")
	file.close()

	var csv_path: String = "user://perf/perf_" + stamp + ".csv"
	var csv: FileAccess = FileAccess.open(csv_path, FileAccess.WRITE)
	if csv != null:
		csv.store_line("t_s,fps,frame_ms,rss_bytes,private_bytes,godot_static,nodes,objects,resources,orphans,vram,texture,buffer,draw_calls")
		for sample: Dictionary in _samples:
			csv.store_line("%.1f,%d,%.2f,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d" % [
				float(sample[&"t"]), int(sample[&"fps"]), float(sample[&"frame_ms"]), int(sample[&"rss"]), int(sample[&"private"]),
				int(sample[&"static"]), int(sample[&"nodes"]), int(sample[&"objects"]), int(sample[&"resources"]), int(sample[&"orphans"]),
				int(sample[&"vram"]), int(sample[&"texture"]), int(sample[&"buffer"]), int(sample[&"draw_calls"]),
			])
		csv.close()
	_status.text = "Отчёт сохранён: " + ProjectSettings.globalize_path(path)
	print("Performance report: ", ProjectSettings.globalize_path(path))
