extends "res://src/UI/Session/Vic2Window.gd"
## Colonisation (task F2): the colonial points of the country (all and in use), the unowned provinces that can be
## reached by land or from the ports, the price of a project in points and the reason why a project cannot be started,
## the projects in progress with their progress and cancelling. A Victoria 2 style window, opened with F11.

const _SIZE: Vector2 = Vector2(700, 620)
const _TOGGLE_KEY: Key = KEY_F11

var _info: Dictionary = {}
var _selected_candidate: int = 0
var _selected_project: int = 0

var _header_label: Label
var _candidates_tree: Tree
var _reason_label: Label
var _start_button: Button
var _projects_tree: Tree
var _cancel_button: Button


func _ready() -> void:
	setup(_SIZE, "Колонизация")

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 6)
	content.add_child(root)

	_header_label = Label.new()
	_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_header_label)

	var candidates_caption := Label.new()
	candidates_caption.text = "Свободные земли, до которых можно добраться:"
	root.add_child(candidates_caption)

	_candidates_tree = Tree.new()
	_candidates_tree.columns = 4
	_candidates_tree.column_titles_visible = true
	_candidates_tree.hide_root = true
	_candidates_tree.select_mode = Tree.SELECT_ROW
	_candidates_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var titles: PackedStringArray = ["Провинция", "Население", "Очки", "Можно начать"]
	for column: int in titles.size():
		_candidates_tree.set_column_title(column, titles[column])
	_candidates_tree.set_column_expand(0, true)
	_candidates_tree.set_column_custom_minimum_width(3, 260)
	_candidates_tree.item_selected.connect(_on_candidate_selected)
	_candidates_tree.nothing_selected.connect(_on_candidate_deselected)
	root.add_child(_candidates_tree)

	_reason_label = Label.new()
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_reason_label)

	_start_button = Button.new()
	_start_button.text = "Начать колонизацию"
	_start_button.pressed.connect(_on_start_pressed)
	root.add_child(_start_button)

	var projects_caption := Label.new()
	projects_caption.text = "Идущие колонизации:"
	root.add_child(projects_caption)

	_projects_tree = Tree.new()
	_projects_tree.columns = 3
	_projects_tree.column_titles_visible = true
	_projects_tree.hide_root = true
	_projects_tree.select_mode = Tree.SELECT_ROW
	_projects_tree.custom_minimum_size = Vector2(0, 110)
	var project_titles: PackedStringArray = ["Провинция", "Прогресс", "Очки"]
	for column: int in project_titles.size():
		_projects_tree.set_column_title(column, project_titles[column])
	_projects_tree.set_column_expand(0, true)
	_projects_tree.item_selected.connect(_on_project_selected)
	_projects_tree.nothing_selected.connect(_on_project_deselected)
	root.add_child(_projects_tree)

	_cancel_button = Button.new()
	_cancel_button.text = "Отменить колонизацию"
	_cancel_button.pressed.connect(_on_cancel_pressed)
	root.add_child(_cancel_button)

	GameSingleton.gamestate_updated.connect(_refresh)


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event and key_event.pressed and not key_event.echo and key_event.keycode == _TOGGLE_KEY:
		if visible:
			close()
		else:
			_refresh_inner()
			open_window()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)


func _refresh() -> void:
	if visible:
		_refresh_inner()


func _refresh_inner() -> void:
	_info = PlayerSingleton.get_colonisation_info()
	if _info.is_empty():
		return

	var free_points: float = float(_info[&"total_points"]) - float(_info[&"used_points"])
	_header_label.text = "Колониальные очки: всего %.0f, занято %.0f, свободно %.0f.%s" % [
		_info[&"total_points"], _info[&"used_points"], free_points,
		"" if _info[&"rank_ok"] else " Ваша страна ниже 16-го места: колонизация недоступна.",
	]

	_candidates_tree.clear()
	var root: TreeItem = _candidates_tree.create_item()
	var to_select: TreeItem = null
	for candidate: Dictionary in _info[&"candidates"]:
		var item: TreeItem = _candidates_tree.create_item(root)
		item.set_text(0, candidate[&"name"])
		item.set_text(1, str(candidate[&"people"]))
		item.set_text(2, "%.0f" % candidate[&"cost"])
		var reason: String = candidate[&"reason"]
		item.set_text(3, "да" if reason == "" else reason)
		if reason == "":
			item.set_custom_color(3, Color(0.1, 0.45, 0.15))
		item.set_metadata(0, candidate[&"province_number"])
		if candidate[&"province_number"] == _selected_candidate:
			to_select = item
	if to_select != null:
		to_select.select(0)
	_update_candidate_buttons()

	_projects_tree.clear()
	var projects_root: TreeItem = _projects_tree.create_item()
	var project_to_select: TreeItem = null
	for project: Dictionary in _info[&"projects"]:
		var item: TreeItem = _projects_tree.create_item(projects_root)
		item.set_text(0, project[&"name"])
		item.set_text(1, "%d из %d дн." % [project[&"days_done"], project[&"days_total"]])
		item.set_text(2, "%.0f" % project[&"cost"])
		item.set_metadata(0, project[&"province_number"])
		if project[&"province_number"] == _selected_project:
			project_to_select = item
	if project_to_select != null:
		project_to_select.select(0)
	_cancel_button.disabled = _selected_project == 0 or project_to_select == null


func _find_candidate(province_number: int) -> Dictionary:
	for candidate: Dictionary in _info.get(&"candidates", []):
		if candidate[&"province_number"] == province_number:
			return candidate
	return {}


func _update_candidate_buttons() -> void:
	var candidate: Dictionary = _find_candidate(_selected_candidate)
	if candidate.is_empty():
		_reason_label.text = "Выберите провинцию."
		_start_button.disabled = true
		return
	_reason_label.text = "Проект займёт очки на время колонизации; готовая колония потом требует очков на содержание." \
		if candidate[&"reason"] == "" else candidate[&"reason"]
	_start_button.disabled = candidate[&"reason"] != ""


func _on_candidate_selected() -> void:
	var item: TreeItem = _candidates_tree.get_selected()
	_selected_candidate = item.get_metadata(0) if item != null else 0
	_update_candidate_buttons()


func _on_candidate_deselected() -> void:
	_candidates_tree.deselect_all()
	_selected_candidate = 0
	_update_candidate_buttons()


func _on_project_selected() -> void:
	var item: TreeItem = _projects_tree.get_selected()
	_selected_project = item.get_metadata(0) if item != null else 0
	_cancel_button.disabled = _selected_project == 0


func _on_project_deselected() -> void:
	_projects_tree.deselect_all()
	_selected_project = 0
	_cancel_button.disabled = true


func _on_start_pressed() -> void:
	if _selected_candidate != 0:
		PlayerSingleton.start_colonisation(_selected_candidate)


func _on_cancel_pressed() -> void:
	if _selected_project != 0:
		PlayerSingleton.cancel_colonisation(_selected_project)
		_selected_project = 0
