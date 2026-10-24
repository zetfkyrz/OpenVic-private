extends "res://src/UI/Session/Vic2Window.gd"
## Save and load window (tasks G1/G3). A save game is a replay of the actions (see GameSingleton.save_game), the list
## shows the header of every file in user://saves. Opened with F4; Ctrl+S makes a quick save. A Victoria 2 style window.

signal load_requested(path: String)

var _save_dir: String = ProjectSettings.get_setting_with_override(&"openvic/data/saves_directory")
const EXTENSION: String = "ovsave"
const QUICKSAVE: String = "quicksave"
const AUTOSAVE: String = "autosave"
const _SIZE: Vector2 = Vector2(700, 520)
const _TOGGLE_KEY: Key = KEY_F4

var _tree: Tree
var _name_edit: LineEdit
var _status: Label


func _ready() -> void:
	setup(_SIZE, "Сохранение и загрузка")

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 6)
	content.add_child(root)

	_tree = Tree.new()
	_tree.columns = 4
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for column: int in 4:
		_tree.set_column_title(column, ["Файл", "Страна", "Дата игры", "Сохранено"][column])
	_tree.set_column_expand(0, true)
	_tree.item_activated.connect(_on_load_pressed)
	root.add_child(_tree)

	var row := HBoxContainer.new()
	root.add_child(row)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Имя сохранения"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name_edit)
	row.add_child(_make_button("Сохранить", _on_save_pressed))
	row.add_child(_make_button("Загрузить", _on_load_pressed))
	row.add_child(_make_button("Удалить", _on_delete_pressed))

	_status = Label.new()
	_status.add_theme_color_override(&"font_color", TEXT_COLOUR)
	root.add_child(_status)


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event and key_event.pressed and not key_event.echo:
		if key_event.keycode == _TOGGLE_KEY:
			if visible:
				close()
			else:
				refresh_list()
				open_window()
			get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_S and key_event.ctrl_pressed:
			var result: String = save_to(QUICKSAVE, "Быстрое сохранение")
			_status.text = result
			get_viewport().set_input_as_handled()
			return
	super._unhandled_key_input(event)


## Writes <saves directory>/<save_name>.ovsave, returns a message for the player.
func save_to(save_name: String, label: String) -> String:
	if SaveManager.save_replay(save_name) != OK:
		return "Не удалось сохранить игру"
	return "Игра сохранена: " + save_name.validate_filename() + "." + EXTENSION


func refresh_list() -> void:
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var entries: Array = []
	for file_name: String in DirAccess.get_files_at(_save_dir):
		if file_name.get_extension() != EXTENSION:
			continue
		var path: String = _save_dir + "/" + file_name
		var header: Dictionary = GameSingleton.read_save_header(path)
		if header.is_empty():
			continue
		entries.append({&"path": path, &"header": header, &"time": int(header.get("saved", "0"))})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a[&"time"] > b[&"time"])
	for entry: Dictionary in entries:
		var header: Dictionary = entry[&"header"]
		var item: TreeItem = _tree.create_item(root)
		item.set_text(0, (entry[&"path"] as String).get_file().get_basename())
		item.set_text(1, header.get("country", ""))
		item.set_text(2, header.get("date", ""))
		item.set_text(3, Time.get_datetime_string_from_unix_time(entry[&"time"], true))
		item.set_tooltip_text(0, header.get("label", ""))
		item.set_metadata(0, entry[&"path"])


func _selected_path() -> String:
	var item: TreeItem = _tree.get_selected()
	return item.get_metadata(0) if item else ""


func _on_save_pressed() -> void:
	var save_name: String = _name_edit.text.strip_edges()
	if save_name.is_empty():
		var item: TreeItem = _tree.get_selected()
		save_name = item.get_text(0) if item else "save_" + Time.get_datetime_string_from_system().replace(":", "-")
	_status.text = save_to(save_name, save_name)
	refresh_list()


func _on_load_pressed() -> void:
	var path: String = _selected_path()
	if path.is_empty():
		_status.text = "Выберите сохранение в списке"
		return
	close()
	# The game session checks the header (version, defines hash) and replays the save
	load_requested.emit(path)


func _on_delete_pressed() -> void:
	var path: String = _selected_path()
	if path.is_empty():
		return
	var found: SaveResource = null
	for save: SaveResource in SaveManager._save_dictionary.values():
		if save.file_path == path:
			found = save
	if found != null:
		found.delete()
	else:
		DirAccess.remove_absolute(path)
	refresh_list()
