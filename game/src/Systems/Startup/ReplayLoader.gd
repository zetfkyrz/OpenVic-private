extends Node
## Loading of a save game (a replay of the actions, see GameSingleton.save_game) from the menus: it checks the header
## (version of the format and of the rules, hash of the defines), asks the player when the save may not match this
## version ("open anyway") or refuses it with a reason, and then sets the game up and opens the game session.
## Add one to a menu, call request_load(path), the menu gets load_confirmed(path) and calls start_game(path).

signal load_confirmed(path: String)

var _warning_dialog: ConfirmationDialog
var _blocked_dialog: AcceptDialog
var _pending_path: String = ""


func _ready() -> void:
	_warning_dialog = ConfirmationDialog.new()
	_warning_dialog.title = "Сохранение может не совпасть"
	_warning_dialog.ok_button_text = "Открыть всё равно"
	_warning_dialog.cancel_button_text = "Отмена"
	_warning_dialog.confirmed.connect(func() -> void: load_confirmed.emit(_pending_path))
	add_child(_warning_dialog)
	_blocked_dialog = AcceptDialog.new()
	_blocked_dialog.title = "Сохранение нельзя открыть"
	add_child(_blocked_dialog)


## Checks the save: refuses it with a message, asks about the warnings, or emits load_confirmed at once.
func request_load(path: String) -> void:
	var header: Dictionary = GameSingleton.read_save_header(path)
	if header.is_empty():
		_show_blocked("Файл не похож на сохранение игры или повреждён.")
		return
	if not header.get("loadable", false):
		_show_blocked(header.get("blocked_reason", "Неизвестная причина."))
		return
	var warnings: PackedStringArray = header.get("warnings", PackedStringArray())
	if warnings.is_empty():
		load_confirmed.emit(path)
		return
	_pending_path = path
	_warning_dialog.dialog_text = "\n\n".join(warnings) + "\n\nОткрыть сохранение всё равно?"
	_warning_dialog.popup_centered(Vector2i(560, 0))


func _show_blocked(text: String) -> void:
	_blocked_dialog.dialog_text = text
	_blocked_dialog.popup_centered()


## Sets the game up from the save (bookmark and country) and opens the game session, which replays the actions.
## For the menus: no game session is running. Returns false (with an error message) if something is wrong.
static func start_game(path: String, tree: SceneTree) -> bool:
	var header: Dictionary = GameSingleton.prepare_load_game(path)
	if not header.get("valid", false) or not header.get("loadable", false):
		push_error("Failed to read the save game " + path)
		return false
	if GameSingleton.setup_game(int(header["bookmark"])) != OK \
			or not PlayerSingleton.set_player_country_by_identifier(header["country"]):
		push_error("Failed to set up the game from the save " + path)
		return false
	tree.change_scene_to_file("res://src/Systems/Session/GameSession.tscn")
	return true


## The newest save game file (autosave, quick save or any other) or "" if there is none.
static func latest_save_path() -> String:
	var dir_path: String = ProjectSettings.get_setting_with_override(&"openvic/data/saves_directory")
	var best_path: String = ""
	var best_time: int = -1
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.get_extension() != "ovsave":
			continue
		var path: String = dir_path.path_join(file_name)
		var time: int = FileAccess.get_modified_time(path)
		if time > best_time and not GameSingleton.read_save_header(path).is_empty():
			best_time = time
			best_path = path
	return best_path
