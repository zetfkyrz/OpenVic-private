extends CanvasLayer
## Economy debugger: the keys X + Ъ (the keys [ and ] of the keyboard, the same on the Russian and the English layout) start and stop
## the recording of the economy of the whole game to CSV files: every good in the world with its price, production and consumption
## and what is lacking, every country, every region and every class in it, every factory, the resource gathering and the movement
## of money. The files are written to user://economy_debug/<date and time>_<country>/ (README.txt there describes the columns).
## While it records, a red line at the top of the screen shows the date, the amount of data and the folder.

# Both keys have to be pressed together
const _KEY_A: Key = KEY_BRACKETLEFT
const _KEY_B: Key = KEY_BRACKETRIGHT
const _REFRESH_SECONDS: float = 0.5
const _TOAST_SECONDS: float = 7.0

var _status: Label
var _toast: Label
var _toast_left: float = 0.0
var _refresh_left: float = 0.0
var _latched: bool = false


func _ready() -> void:
	layer = 120

	_status = _make_label(Color(1.0, 0.45, 0.4), 15)
	_status.visible = false
	_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	# Under the top bar of the game
	_status.position.y = 88.0
	add_child(_status)

	_toast = _make_label(Color(0.95, 0.92, 0.7), 16)
	_toast.visible = false
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 114.0
	add_child(_toast)


func _make_label(colour: Color, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.add_theme_color_override(&"font_color", colour)
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override(&"outline_size", 5)
	label.add_theme_font_size_override(&"font_size", font_size)
	return label


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event
	if key_event.echo:
		return
	if not key_event.pressed:
		# The next combination can start when one of the keys is released
		if key_event.physical_keycode == _KEY_A or key_event.physical_keycode == _KEY_B:
			_latched = false
		return
	if key_event.physical_keycode != _KEY_A and key_event.physical_keycode != _KEY_B:
		return
	if Input.is_physical_key_pressed(_KEY_A) and Input.is_physical_key_pressed(_KEY_B) and not _latched:
		_latched = true
		get_viewport().set_input_as_handled()
		toggle()


## Starts the recording, or stops it if it is running
func toggle() -> void:
	if GameSingleton.is_economy_recording():
		var folder: String = GameSingleton.stop_economy_recording()
		_status.visible = false
		_show_toast("Запись экономики остановлена. Файлы: %s" % folder)
		print("Economy debugger stopped: ", folder)
		return

	var started_folder: String = GameSingleton.start_economy_recording()
	if started_folder.is_empty():
		_show_toast("Не удалось начать запись экономики (смотрите журнал)")
		return
	_show_toast("Запись экономики началась. Файлы: %s\nХ + Ъ ещё раз — остановить" % started_folder)
	print("Economy debugger started: ", started_folder)
	_refresh_status()


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_left = _TOAST_SECONDS


func _process(delta: float) -> void:
	if _toast.visible:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.visible = false

	if not GameSingleton.is_economy_recording():
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = _REFRESH_SECONDS
		_refresh_status()


func _refresh_status() -> void:
	var info: Dictionary = GameSingleton.get_economy_recording_info()
	if not info.get("running", false):
		_status.visible = false
		return
	_status.visible = true
	_status.text = "● ЗАПИСЬ ЭКОНОМИКИ  %s  ·  дней: %d  ·  строк: %d  ·  %.1f МБ  ·  Х + Ъ — остановить" % [
		info.get("date", ""), int(info.get("days", 0)), int(info.get("rows", 0)), float(info.get("megabytes", 0.0)),
	]
