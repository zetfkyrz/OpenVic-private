extends GUINode

const _screen: NationManagement.Screen = NationManagement.Screen.TECHNOLOGY
const _gui_file: String = "country_technology"

# From the folder_offset, tech_group_offset and tech_offset positionTypes of country_technology.gui
const _FOLDER_POSITION: Vector2 = Vector2(32, 55)
const _FOLDER_WIDTH: float = 192.0
const _GROUP_POSITION: Vector2 = Vector2(28, 109)
const _GROUP_WIDTH: float = 194.0
const _TECH_OFFSET: float = 16.0
# Space left for the group name above the first technology of a group
const _GROUP_NAME_HEIGHT: float = 14.0

# Technology status, as returned by PlayerSingleton.get_technology_info()
enum Status { LOCKED, AVAILABLE, RESEARCHED, RESEARCHING }

# Colour codes for the label text of each status (Victoria 2 style text colour markers)
const _STATUS_COLOURS: Dictionary[Status, String] = {
	Status.LOCKED: "R",
	Status.AVAILABLE: "W",
	Status.RESEARCHED: "G",
	Status.RESEARCHING: "Y",
}

var _active: bool = false

var _main_window: Panel
var _administration_type: GUILabel
var _research_progress_name: GUILabel
var _research_progress_category: GUILabel

var _selected_window: Node
var _selected_title: GUILabel
var _selected_desc: GUILabel
var _selected_cost: GUILabel
var _selected_year: GUILabel
var _start_button: GUIIconButton

var _folder_buttons: Array[GUIIconButton]
var _folder_labels: Array[GUILabel]
var _folder_counts: Array[GUILabel]
# Nodes of the currently displayed technology groups, regenerated when the shown folder or the data changes
var _group_nodes: Array[Node]

var _info: Dictionary = {}
var _selected_folder: int = 0
var _selected_technology: int = -1
var _folders_generated: bool = false


func _ready() -> void:
	GameSingleton.gamestate_updated.connect(_update_info)

	Events.NationManagementScreens.update_active_nation_management_screen.connect(_on_update_active_nation_management_screen)

	add_gui_element(_gui_file, "country_technology")

	set_click_mask_from_nodepaths([^"./country_technology/main_bg"])

	var close_button: GUIIconButton = get_gui_icon_button_from_nodepath(^"./country_technology/close_button")
	if close_button:
		close_button.pressed.connect(Events.NationManagementScreens.close_nation_management_screen.bind(_screen))

	_main_window = get_panel_from_nodepath(^"./country_technology")
	if not _main_window:
		return

	_administration_type = GUINode.get_gui_label_from_node(_main_window.get_node_or_null(^"./administration_type"))
	_research_progress_name = GUINode.get_gui_label_from_node(
		_main_window.get_node_or_null(^"./research_progress_name")
	)
	_research_progress_category = GUINode.get_gui_label_from_node(
		_main_window.get_node_or_null(^"./research_progress_category")
	)

	_selected_window = _main_window.get_node_or_null(^"./selected_tech_window")
	if _selected_window:
		_selected_title = GUINode.get_gui_label_from_node(_selected_window.get_node_or_null(^"./title"))
		_selected_desc = GUINode.get_gui_label_from_node(_selected_window.get_node_or_null(^"./desc"))
		_selected_cost = GUINode.get_gui_label_from_node(_selected_window.get_node_or_null(^"./diff"))
		_selected_year = GUINode.get_gui_label_from_node(_selected_window.get_node_or_null(^"./year"))
		_start_button = GUINode.get_gui_icon_button_from_node(_selected_window.get_node_or_null(^"./start"))
		if _start_button:
			_start_button.pressed.connect(_on_start_research_pressed)

		# Nothing in the simulation provides the list of inventions of a technology yet
		var inventions: GUIListBox = GUINode.get_gui_listbox_from_node(_selected_window.get_node_or_null(^"./inventions"))
		if inventions:
			inventions.clear_children()

	var possible_inventions: GUIListBox = GUINode.get_gui_listbox_from_node(_main_window.get_node_or_null(^"./inventions"))
	if possible_inventions:
		possible_inventions.clear_children()

	_update_info()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED:
			_update_info()


func _on_update_active_nation_management_screen(active_screen: NationManagement.Screen) -> void:
	_active = active_screen == _screen
	_update_info()


func _set_label_text(label: GUILabel, text: String) -> void:
	if label:
		label.set_auto_translate(false)
		label.set_text(text)


func _update_info() -> void:
	if not _active:
		hide()
		return

	show()

	if not _main_window:
		return

	_info = PlayerSingleton.get_technology_info()
	if _info.is_empty():
		return

	var folders: Array = _info[&"folders"]
	if not _folders_generated:
		_generate_folder_buttons(folders)
		_folders_generated = true

	_update_header()
	_update_folder_buttons(folders)
	_update_groups(folders)
	_update_selected_technology()


func _generate_folder_buttons(folders: Array) -> void:
	for i: int in folders.size():
		var folder_window: Panel = GUINode.generate_gui_element(_gui_file, "folder_window")
		if not folder_window:
			break

		folder_window.position = _FOLDER_POSITION + Vector2(i * _FOLDER_WIDTH, 0)
		_main_window.add_child(folder_window)

		var button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(folder_window, ^"./folder_button")
		if button:
			button.pressed.connect(_select_folder.bind(i))
		_folder_buttons.append(button)
		_folder_labels.append(GUINode.get_gui_label_from_node_and_path(folder_window, ^"./folder_category"))
		_folder_counts.append(GUINode.get_gui_label_from_node_and_path(folder_window, ^"./folder_number_discovered"))


func _update_header() -> void:
	_set_label_text(_administration_type, _info.get(&"school", ""))

	var current: Dictionary = _info.get(&"current", {})
	if current.is_empty():
		_set_label_text(_research_progress_name, tr("No research"))
		_set_label_text(_research_progress_category, "")
	else:
		_set_label_text(_research_progress_name, current[&"name"])
		_set_label_text(
			_research_progress_category,
			"%s (%d%%)" % [current[&"category"], roundi(current[&"progress"] * 100.0)]
		)


func _update_folder_buttons(folders: Array) -> void:
	for i: int in mini(folders.size(), _folder_labels.size()):
		var folder: Dictionary = folders[i]
		_set_label_text(_folder_labels[i], folder[&"name"])
		_set_label_text(
			_folder_counts[i], "%d / %d" % [folder[&"researched_count"], folder[&"total_count"]]
		)


func _select_folder(index: int) -> void:
	_selected_folder = index
	_selected_technology = -1
	_update_info()


func _update_groups(folders: Array) -> void:
	for node: Node in _group_nodes:
		node.queue_free()
	_group_nodes.clear()

	if _selected_folder >= folders.size():
		return

	var areas: Array = folders[_selected_folder][&"areas"]
	for area_index: int in areas.size():
		var area: Dictionary = areas[area_index]

		var group: Panel = GUINode.generate_gui_element(_gui_file, "tech_group")
		if not group:
			break

		group.position = _GROUP_POSITION + Vector2(area_index * _GROUP_WIDTH, 0)
		_main_window.add_child(group)
		_group_nodes.append(group)

		_set_label_text(GUINode.get_gui_label_from_node_and_path(group, ^"./group_name"), area[&"name"])

		for technology: Dictionary in area[&"technologies"]:
			_add_technology_entry(group, technology)


func _add_technology_entry(group: Panel, technology: Dictionary) -> void:
	var entry: Panel = GUINode.generate_gui_element(_gui_file, "tech_window")
	if not entry:
		return

	entry.position = Vector2(0, _GROUP_NAME_HEIGHT + int(technology[&"position"]) * _TECH_OFFSET)
	group.add_child(entry)

	var status: Status = technology[&"status"]
	var name_label: GUILabel = GUINode.get_gui_label_from_node_and_path(entry, ^"./tech_name")
	if name_label:
		_set_label_text(name_label, "§%s%s§!" % [_STATUS_COLOURS[status], technology[&"name"]])
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(entry, ^"./start_research")
	if button:
		button.pressed.connect(_select_technology.bind(technology[&"index"]))


func _select_technology(technology_index: int) -> void:
	_selected_technology = technology_index
	_update_selected_technology()


func _find_technology(technology_index: int) -> Dictionary:
	for folder: Dictionary in _info.get(&"folders", []):
		for area: Dictionary in folder[&"areas"]:
			for technology: Dictionary in area[&"technologies"]:
				if technology[&"index"] == technology_index:
					return technology
	return {}


func _update_selected_technology() -> void:
	var technology: Dictionary = _find_technology(_selected_technology) if _selected_technology >= 0 else {}

	if technology.is_empty():
		_set_label_text(_selected_title, tr("No technology selected"))
		_set_label_text(_selected_desc, "")
		_set_label_text(_selected_cost, "")
		_set_label_text(_selected_year, "")
		if _start_button:
			_start_button.disabled = true
		return

	_set_label_text(_selected_title, technology[&"name"])
	var description: String = technology[&"description"]
	_set_label_text(_selected_desc, "" if description == technology[&"identifier"] + "_desc" else description)
	_set_label_text(_selected_cost, GUINode.float_to_string_dp(technology[&"cost"], 0))
	_set_label_text(_selected_year, str(technology[&"year"]))
	if _start_button:
		_start_button.disabled = technology[&"status"] != Status.AVAILABLE


func _on_start_research_pressed() -> void:
	if _selected_technology < 0:
		return

	if PlayerSingleton.start_research(_selected_technology):
		_update_info()
