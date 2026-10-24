extends HBoxContainer


# REQUIREMENTS:
# * 1.4 Game Lobby Menu
# * SS-12

signal back_button_pressed
signal save_game_selected(save: SaveResource)
signal start_date_selected(index: int)

@export var lobby_panel_button: PackedScene
@export var save_scene: PackedScene
@export_group("Nodes")
@export var game_select_start_date: BoxContainer
@export var game_select_save_tab: TabBar
@export var game_select_save_list: BoxContainer
@export var start_button: BaseButton
@export var session_tag_line_edit: LineEdit
@export var session_tag_dialog: ConfirmationDialog
@export var delete_dialog: ConfirmationDialog
@export var map_view: MapView

const _POLITICAL_MAPMODE_IDENTIFIER: String = "mapmode_political"
const _SELECTED_COUNTRY_LABEL_PATH: NodePath = ^"GameStartPanel/VBoxContainer/SelectedCountryNameLabel"

var _id_to_tag: Array[StringName] = []
var _requested_node_to_delete: Control
var _start_date_index: int = -1
# Start date the game is currently set up for, so that the game is not set up again for the same date
var _setup_start_date_index: int = -1

@onready var _selected_country_label: Label = get_node_or_null(_SELECTED_COUNTRY_LABEL_PATH)


var _flag_rect: TextureRect
var _info_label: Label


const _ReplayLoader := preload("res://src/Systems/Startup/ReplayLoader.gd")

var _replay_loader: Node


func _ready() -> void:
	# Save games of the simulation (*.ovsave) in the list of saves start the game by replaying the actions
	_replay_loader = _ReplayLoader.new()
	add_child(_replay_loader)
	_replay_loader.load_confirmed.connect(func(path: String) -> void: _ReplayLoader.start_game(path, get_tree()))
	_build_country_preview()
	_update_selected_country_label()


# TODO (multiplayer): there is no multiplayer lobby yet. When it appears, its handshake must carry
# GameSingleton.get_defines_hash() (hash of the openvic_defines values after the mods) and the game must refuse to start
# when the hashes of the players differ, so that everybody plays with the same parameters.

# Flag and key figures of the selected country, under its name (task G2)
func _build_country_preview() -> void:
	if not _selected_country_label:
		return
	var box: Node = _selected_country_label.get_parent()
	_flag_rect = TextureRect.new()
	_flag_rect.custom_minimum_size = Vector2(128, 64)
	_flag_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_flag_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_flag_rect)
	box.move_child(_flag_rect, _selected_country_label.get_index() + 1)
	box.add_child(_info_label)
	box.move_child(_info_label, _flag_rect.get_index() + 1)


func _update_country_preview() -> void:
	if not _info_label:
		return
	var info: Dictionary = PlayerSingleton.get_lobby_country_info() if _setup_start_date_index >= 0 else {}
	if info.is_empty():
		_flag_rect.texture = null
		_info_label.text = ""
		return
	if info.has("flag_rect"):
		var atlas := AtlasTexture.new()
		atlas.atlas = GameSingleton.get_flag_sheet_texture()
		atlas.region = Rect2(info["flag_rect"])
		_flag_rect.texture = atlas
	var lines: PackedStringArray = []
	lines.append(tr("Population: {0}").format([_format_number(info.get("population", 0))]))
	lines.append(tr("Provinces: {0}").format([info.get("provinces", 0)]))
	lines.append(tr("Rank: {0}{1}").format([info.get("rank", 0), " (" + tr("Great Power") + ")" if info.get("great_power", false) else ""]))
	lines.append(tr("Prestige {0} · Industry {1} · Military {2}").format(
		[info.get("prestige_rank", 0), info.get("industrial_rank", 0), info.get("military_rank", 0)]
	))
	if info.has("government"):
		lines.append(info["government"])
	_info_label.text = "\n".join(lines)


func _format_number(value: int) -> String:
	var text: String = str(value)
	var result: String = ""
	for i: int in text.length():
		if i > 0 and (text.length() - i) % 3 == 0:
			result += " "
		result += text[i]
	return result


# Sets the game up for the selected start date, so that the map can show the countries of that date
# and the player can pick which one to play by clicking on it.
func _setup_start_date(index: int) -> void:
	if index == _setup_start_date_index and GameSingleton.is_bookmark_loaded():
		return

	if GameSingleton.setup_game(index) != OK:
		push_error("Failed to setup game for start date %d" % index)
		_setup_start_date_index = -1
		return
	_setup_start_date_index = index

	_set_political_mapmode()
	_focus_map_on_player_country()
	_update_selected_country_label()


func _set_political_mapmode() -> void:
	for index: int in GameSingleton.get_mapmode_count():
		if GameSingleton.get_mapmode_identifier(index) == _POLITICAL_MAPMODE_IDENTIFIER:
			GameSingleton.set_mapmode(index)
			return
	push_warning("Political mapmode not found")


func _focus_map_on_player_country() -> void:
	if not map_view:
		return

	var capital_position: Vector2 = PlayerSingleton.get_player_country_capital_position()
	if capital_position != Vector2.ZERO:
		map_view._camera.position = map_view._map_to_world_coords(capital_position)


func _update_selected_country_label() -> void:
	if not _selected_country_label:
		return

	var country_name: String = PlayerSingleton.get_player_country_name() if _setup_start_date_index >= 0 else ""
	_selected_country_label.text = country_name if not country_name.is_empty() else tr("Click on a country to select it")
	_update_country_preview()


func filter_for_tag(tag: StringName) -> void:
	for child: Control in game_select_save_list.get_children():
		if tag.is_empty():
			child.show()
		else:
			if tag == child.resource.session_tag:
				child.show()
			else:
				child.hide()


func _build_date_list() -> void:
	const bookmark_info_name_key: StringName = &"bookmark_name"
	const bookmark_info_date_key: StringName = &"bookmark_date"

	for bookmark_dict: Dictionary in GameSingleton.get_bookmark_info():
		var start_date := lobby_panel_button.instantiate()
		start_date.set_name_text(bookmark_dict.get(bookmark_info_name_key, "MISSING BOOKMARK NAME"))
		start_date.set_date_text(bookmark_dict.get(bookmark_info_date_key, "MISSING BOOKMARK DATE"))
		start_date.pressed.connect(_on_start_date_panel_button_pressed.bind(start_date))
		game_select_start_date.add_child(start_date)


# Requirements
# * FS-8


func _build_save_list() -> void:
	game_select_save_tab.add_tab("All")
	for save_name: StringName in SaveManager._save_dictionary:
		var save: SaveResource = SaveManager._save_dictionary[save_name]
		var save_node := _create_save_node(save)
		game_select_save_list.add_child(save_node)
		if not _id_to_tag.has(save.session_tag):
			_id_to_tag.append(save.session_tag)
			game_select_save_tab.add_tab(save.session_tag)


func _create_save_node(resource: SaveResource) -> Control:
	var save_node := save_scene.instantiate()
	save_node.resource = resource
	save_node.pressed.connect(_on_save_node_pressed.bind(save_node))
	save_node.request_to_delete.connect(_on_save_node_delete_requested.bind(save_node))
	return save_node


func _queue_clear_lists() -> void:
	var full_list := game_select_start_date.get_children()
	full_list.append_array(game_select_save_list.get_children())
	for child: Node in full_list:
		child.queue_free()
	game_select_save_tab.clear_tabs()
	_id_to_tag.clear()


# REQUIREMENTS:
# * SS-16
# * UIFUN-40


func _on_back_button_pressed() -> void:
	print("Returning to Main Menu.")
	SaveManager.current_session_tag = ""
	SaveManager.current_save = null
	back_button_pressed.emit()


# REQUIREMENTS:
# * SS-21


func _on_start_button_pressed() -> void:
	if SaveManager.current_save != null and SaveManager.current_save.is_replay:
		_replay_loader.request_load(SaveManager.current_save.file_path)
		return
	print("Starting new game.")
	if SaveManager.current_session_tag == "":
		# TODO: Get country tag as well
		var datetime := Time.get_datetime_dict_from_system()
		SaveManager.current_session_tag = "%s/%s/%s-%s:%s:%s" % [
			datetime["day"],
			datetime["month"],
			datetime["year"],
			datetime["hour"],
			datetime["minute"],
			datetime["second"],
		]
	if SaveManager.current_save == null and SaveManager.current_session_tag in _id_to_tag:
		session_tag_dialog.dialog_text = tr("Are you sure you want to override {session_tag} as a previous session?").format({ "session_tag": SaveManager.current_session_tag })
		session_tag_dialog.title = tr("Override {session_tag}").format({ "session_tag": SaveManager.current_session_tag })
		session_tag_dialog.popup_centered()
	else:
		_on_session_tag_dialog_confirmed()


# REQUIREMENTS:
# * SS-19


func _on_game_select_list_item_selected(index) -> void:
	print("Selected save game: ", index)
	save_game_selected.emit(index)


# If the date is double-clicked, start the game!


func _on_game_select_list_item_activated(index) -> void:
	_on_game_select_list_item_selected(index)
	_on_start_button_pressed()


func _on_session_tag_edit_text_submitted(new_text: String) -> void:
	SaveManager.current_session_tag = new_text
	_on_start_button_pressed()


func _on_session_tag_dialog_confirmed() -> void:
	if _start_date_index < 0:
		push_error("Cannot setup game, no start date selected!")
		return

	# Game has to be setup (bookmark loaded) before opening the GameSession scene.
	# It is normally already set up when the start date was selected.
	if _setup_start_date_index != _start_date_index or not GameSingleton.is_bookmark_loaded():
		_setup_start_date(_start_date_index)
		if _setup_start_date_index != _start_date_index:
			return
	get_tree().change_scene_to_file("res://src/Systems/Session/GameSession.tscn")


func _on_save_node_delete_requested(node: Control) -> void:
	_requested_node_to_delete = node
	delete_dialog.dialog_text = tr("Are you sure you want to delete {file_name}?").format({ "file_name": _requested_node_to_delete.resource.save_name })
	delete_dialog.title = tr("Delete {file_name}").format({ "file_name": _requested_node_to_delete.resource.save_name })
	delete_dialog.popup_centered()


func _on_start_date_panel_button_pressed(node: Control) -> void:
	if node is LobbyPanelButton and node.get_index(true) == _start_date_index:
		_on_start_button_pressed()
		return
	_start_date_index = node.get_index(true)
	# A start date was chosen instead of a save game
	SaveManager.current_save = null
	SaveManager.current_session_tag = ""
	_setup_start_date(_start_date_index)
	start_button.disabled = false
	start_date_selected.emit(_start_date_index)


func _on_save_node_pressed(node: Control) -> void:
	if SaveManager.current_save != null and SaveManager.current_save == node.resource:
		SaveManager.current_session_tag = SaveManager.current_save.session_tag
		_on_start_button_pressed()
		return
	SaveManager.current_save = node.resource
	if SaveManager.current_save != null:
		session_tag_line_edit.text = SaveManager.current_save.session_tag
	else:
		session_tag_line_edit.text = ""
	start_button.disabled = false
	save_game_selected.emit(SaveManager.current_save)


func _on_game_select_save_tab_tab_changed(tab: int) -> void:
	if tab == 0:
		filter_for_tag(&"")
	else:
		filter_for_tag(_id_to_tag[tab - 1])


func _on_delete_dialog_confirmed() -> void:
	_requested_node_to_delete.resource.delete()
	_requested_node_to_delete.queue_free()


func _on_visibility_changed() -> void:
	if visible:
		_build_date_list()
		_build_save_list()
	else:
		_queue_clear_lists()


func _on_map_view_ready() -> void:
	# TODO: Start at the bookmark's start position (used when loading a bookmark in the lobby)
	# GameSingleton.get_bookmark_start_position()
	pass


func _on_map_view_province_clicked(province_number: int) -> void:
	# Countries can only be picked once a start date is selected
	if _setup_start_date_index < 0 or not GameSingleton.is_bookmark_loaded():
		return

	PlayerSingleton.set_player_country_by_province_number(province_number)
	_update_selected_country_label()
