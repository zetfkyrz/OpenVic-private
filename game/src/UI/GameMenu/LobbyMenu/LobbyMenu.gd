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


const _TEX_PATH: String = "gfx/interface/"
const _PANEL_SIZE := Vector2(240, 616)
const _TEXT_COLOUR := Color(0.1, 0.06, 0.03)

var _overlay: Control
var _countries_tree: Tree
var _countries: Array = []
var _sort_key: String = "rank"
var _play_button: TextureButton
var _filling: bool = false
var _saves_tree: Tree


func _ready() -> void:
	_build_original_layout()
	_build_country_preview()
	_update_selected_country_label()


func _process(_delta: float) -> void:
	if _play_button and start_button:
		_play_button.disabled = start_button.disabled


func _texture(file: String) -> Texture2D:
	return AssetManager.get_texture(_TEX_PATH + file)


# The lobby of the original game: a panel with the start dates and the playable countries on the left, the selected
# country on the right, the title on top and Back / Play in the bottom corners. The panels keep the size of their
# sprites, they are not stretched with the window.
func _build_original_layout() -> void:
	var old_panels: Array[Node] = [get_node_or_null(^"GameSelectPanel"), get_node_or_null(^"GameStartPanel")]
	var scroll: Node = get_node_or_null(^"GameSelectPanel/VBoxContainer/GameSelectScroll")
	var tag_edit: Node = session_tag_line_edit
	var name_label: Node = _selected_country_label

	_overlay = Control.new()
	_overlay.top_level = true
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# Left panel
	var left := TextureRect.new()
	left.texture = _texture("frontend_lobby_leftbg.dds")
	left.position = Vector2(0, 0)
	left.size = _PANEL_SIZE
	left.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(left)

	if scroll:
		scroll.get_parent().remove_child(scroll)
		left.add_child(scroll)
		scroll.position = Vector2(10, 12)
		scroll.size = Vector2(220, 150)
		scroll.size_flags_vertical = Control.SIZE_FILL
		# The old stub list of saves is replaced by the real save games (user://saves) below
		game_select_save_tab.hide()
		game_select_save_list.hide()

	var saves_label := Label.new()
	saves_label.text = "Сохранённые игры (двойной клик)"
	saves_label.position = Vector2(14, 168)
	saves_label.size = Vector2(212, 16)
	saves_label.add_theme_font_size_override(&"font_size", 12)
	saves_label.add_theme_color_override(&"font_color", _TEXT_COLOUR)
	left.add_child(saves_label)
	_saves_tree = Tree.new()
	_saves_tree.columns = 2
	_saves_tree.hide_root = true
	_saves_tree.position = Vector2(10, 186)
	_saves_tree.size = Vector2(220, 112)
	_saves_tree.set_column_expand(1, false)
	_saves_tree.set_column_custom_minimum_width(1, 70)
	_saves_tree.add_theme_color_override(&"font_color", _TEXT_COLOUR)
	_saves_tree.add_theme_font_size_override(&"font_size", 12)
	_saves_tree.item_activated.connect(_on_save_activated)
	left.add_child(_saves_tree)
	_refresh_saves()

	var sort_defs: Array = [
		["Страна", "name", 14, 92], ["Пре", "prestige_rank", 128, 32],
		["Инд", "industrial_rank", 160, 32], ["Арм", "military_rank", 192, 32],
	]
	for def: Array in sort_defs:
		var header := Button.new()
		header.text = def[0]
		header.flat = true
		header.focus_mode = Control.FOCUS_NONE
		header.position = Vector2(def[2], 313)
		header.size = Vector2(def[3], 20)
		header.add_theme_font_size_override(&"font_size", 12)
		header.add_theme_color_override(&"font_color", Color(0.95, 0.9, 0.8))
		header.add_theme_color_override(&"font_hover_color", Color.WHITE)
		header.pressed.connect(_on_sort_pressed.bind(def[1]))
		left.add_child(header)

	_countries_tree = Tree.new()
	_countries_tree.columns = 4
	_countries_tree.hide_root = true
	_countries_tree.column_titles_visible = false
	_countries_tree.set_column_expand(0, true)
	for column: int in range(1, 4):
		_countries_tree.set_column_expand(column, false)
		_countries_tree.set_column_custom_minimum_width(column, 32)
	_countries_tree.position = Vector2(8, 338)
	_countries_tree.size = Vector2(224, 262)
	_countries_tree.add_theme_color_override(&"font_color", _TEXT_COLOUR)
	_countries_tree.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	_countries_tree.add_theme_font_size_override(&"font_size", 13)
	_countries_tree.item_selected.connect(_on_country_row_selected)
	left.add_child(_countries_tree)

	# Right panel
	var right := TextureRect.new()
	right.texture = _texture("frontend_lobby_rightbg.dds")
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-_PANEL_SIZE.x, 0)
	right.size = _PANEL_SIZE
	right.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(right)

	if name_label:
		name_label.get_parent().remove_child(name_label)
		right.add_child(name_label)
	if tag_edit:
		tag_edit.get_parent().remove_child(tag_edit)
		right.add_child(tag_edit)
		tag_edit.position = Vector2(14, 340)
		tag_edit.size = Vector2(212, 30)

	# Title
	var title := TextureRect.new()
	title.texture = _texture("frontend_lobby_titlebg.dds")
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-262, 0)
	title.size = Vector2(524, 68)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(title)
	for def: Array in [["Выбранный сценарий", 6, 26], ["Выберите страну на карте или в списке", 38, 14]]:
		var label := Label.new()
		label.text = def[0]
		label.position = Vector2(0, def[1])
		label.size = Vector2(524, 30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", def[2])
		label.add_theme_color_override(&"font_color", _TEXT_COLOUR)
		title.add_child(label)

	# Corners with the buttons
	var corner_left := TextureRect.new()
	corner_left.texture = _texture("frontend_lobby_cornerleft.dds")
	corner_left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	corner_left.position = Vector2(0, -152)
	corner_left.size = Vector2(176, 152)
	corner_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(corner_left)
	var corner_right := TextureRect.new()
	corner_right.texture = _texture("frontend_lobby_cornerright.dds")
	corner_right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	corner_right.position = Vector2(-176, -152)
	corner_right.size = Vector2(176, 152)
	corner_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(corner_right)

	var back := _make_play_style_button("Назад", Control.PRESET_BOTTOM_LEFT, Vector2(17, -80))
	back.pressed.connect(_on_back_button_pressed)
	_play_button = _make_play_style_button("Играть", Control.PRESET_BOTTOM_RIGHT, Vector2(-184, -80))
	_play_button.pressed.connect(_on_start_button_pressed)

	for panel: Node in old_panels:
		if panel:
			panel.hide()
	var spacer: Node = get_node_or_null(^"Spacer")
	if spacer:
		spacer.hide()
	if start_button:
		start_button.hide()


func _make_play_style_button(text: String, preset: Control.LayoutPreset, offset: Vector2) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _texture("frontend_play_button.dds")
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	_overlay.add_child(button)
	button.set_anchors_preset(preset)
	button.offset_left = offset.x
	button.offset_top = offset.y
	button.offset_right = offset.x + 168.0
	button.offset_bottom = offset.y + 60.0
	var label := Label.new()
	label.text = text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 20)
	label.add_theme_color_override(&"font_color", _TEXT_COLOUR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	return button


func _refresh_saves() -> void:
	if not _saves_tree:
		return
	_saves_tree.clear()
	var root: TreeItem = _saves_tree.create_item()
	var entries: Array = []
	for file_name: String in DirAccess.get_files_at("user://saves"):
		if file_name.get_extension() != "ovsave":
			continue
		var path: String = "user://saves/" + file_name
		var header: Dictionary = GameSingleton.read_save_header(path)
		if header.is_empty():
			continue
		entries.append({&"path": path, &"header": header, &"time": int(header.get("saved", "0"))})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a[&"time"] > b[&"time"])
	for entry: Dictionary in entries:
		var item: TreeItem = _saves_tree.create_item(root)
		var header: Dictionary = entry[&"header"]
		item.set_text(0, "%s (%s)" % [(entry[&"path"] as String).get_file().get_basename(), header.get("country", "")])
		item.set_text(1, header.get("date", ""))
		item.set_tooltip_text(0, Time.get_datetime_string_from_unix_time(entry[&"time"], true))
		item.set_metadata(0, entry[&"path"])


# Loads a save game: the game is set up again from the bookmark and the country of the save, then the session scene
# replays the saved actions (see GameSession)
func _on_save_activated() -> void:
	var item: TreeItem = _saves_tree.get_selected()
	if item == null:
		return
	var header: Dictionary = GameSingleton.prepare_load_game(item.get_metadata(0))
	if not header.has("valid"):
		push_error("Failed to read the save game")
		return
	if GameSingleton.setup_game(int(header["bookmark"])) != OK 			or not PlayerSingleton.set_player_country_by_identifier(header["country"]):
		push_error("Failed to set up the game from the save")
		return
	get_tree().change_scene_to_file("res://src/Systems/Session/GameSession.tscn")


func _on_sort_pressed(key: String) -> void:
	_sort_key = key
	_fill_countries()


func _fill_countries() -> void:
	if not _countries_tree:
		return
	_countries_tree.clear()
	if _setup_start_date_index < 0:
		return
	_countries = PlayerSingleton.get_country_ranking()
	var field: String = _sort_key
	if field == "name":
		_countries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["name"]) < String(b["name"]))
	else:
		_countries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a[field]) < int(b[field]))
	_filling = true
	var root: TreeItem = _countries_tree.create_item()
	var player_name: String = PlayerSingleton.get_player_country_name()
	for entry: Dictionary in _countries:
		var item: TreeItem = _countries_tree.create_item(root)
		item.set_text(0, entry["name"])
		item.set_text(1, str(entry["prestige_rank"]))
		item.set_text(2, str(entry["industrial_rank"]))
		item.set_text(3, str(entry["military_rank"]))
		for column: int in range(1, 4):
			item.set_text_alignment(column, HORIZONTAL_ALIGNMENT_CENTER)
		item.set_metadata(0, String(entry["identifier"]))
		if bool(entry["great_power"]):
			item.set_custom_color(0, Color(0.42, 0.1, 0.17))
		if String(entry["name"]) == player_name:
			item.select(0)
			_countries_tree.scroll_to_item(item)
	_filling = false


func _on_country_row_selected() -> void:
	var item: TreeItem = _countries_tree.get_selected()
	if _filling or item == null or _setup_start_date_index < 0:
		return
	SoundManager.play_effect_compat("click")
	if PlayerSingleton.set_player_country_by_identifier(String(item.get_metadata(0))):
		_focus_map_on_player_country()
		_update_selected_country_label()


# Flag and key figures of the selected country, placed on the rows and bars of the sprite of the right panel
var _rows: Dictionary = {}


func _make_row_label(parent: Control, key: String, rect: Rect2, colour: Color, size: int = 13, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.clip_text = true
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	_rows[key] = label


func _build_country_preview() -> void:
	if not _selected_country_label:
		return
	var panel: Control = _selected_country_label.get_parent()
	var light := Color(0.96, 0.92, 0.82)
	var dark := Color(0.1, 0.06, 0.03)

	_flag_rect = TextureRect.new()
	_flag_rect.position = Vector2(14, 20)
	_flag_rect.size = Vector2(72, 56)
	_flag_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flag_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_flag_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_flag_rect)

	# Name on the maroon bar
	_selected_country_label.position = Vector2(92, 18)
	_selected_country_label.size = Vector2(134, 24)
	_selected_country_label.clip_text = true
	_selected_country_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selected_country_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_selected_country_label.add_theme_font_size_override(&"font_size", 14)
	_selected_country_label.add_theme_color_override(&"font_color", light)

	_make_row_label(panel, "government", Rect2(94, 43, 130, 15), dark, 12)
	_make_row_label(panel, "rank", Rect2(94, 59, 130, 15), dark, 12)
	_make_row_label(panel, "ranks_header", Rect2(24, 88, 200, 15), dark, 12, HORIZONTAL_ALIGNMENT_CENTER)
	_make_row_label(panel, "prestige", Rect2(24, 106, 200, 16), dark)
	_make_row_label(panel, "industry", Rect2(24, 124, 200, 16), dark)
	_make_row_label(panel, "military", Rect2(24, 142, 200, 16), dark)
	_make_row_label(panel, "population_header", Rect2(24, 170, 200, 15), dark, 12, HORIZONTAL_ALIGNMENT_CENTER)
	_make_row_label(panel, "population", Rect2(24, 192, 200, 18), dark, 14)
	_make_row_label(panel, "provinces", Rect2(24, 212, 200, 18), dark, 14)
	_make_row_label(panel, "lower_header", Rect2(24, 315, 200, 17), light, 12, HORIZONTAL_ALIGNMENT_CENTER)
	_rows["ranks_header"].text = "Рейтинг"
	_rows["population_header"].text = "Население"
	_rows["lower_header"].text = "Название сессии"


func _update_country_preview() -> void:
	if not _flag_rect:
		return
	var info: Dictionary = PlayerSingleton.get_lobby_country_info() if _setup_start_date_index >= 0 else {}
	if info.is_empty():
		_flag_rect.texture = null
		for key: String in ["government", "rank", "prestige", "industry", "military", "population", "provinces"]:
			_rows[key].text = ""
		return
	if info.has("flag_rect"):
		var atlas := AtlasTexture.new()
		atlas.atlas = GameSingleton.get_flag_sheet_texture()
		atlas.region = Rect2(info["flag_rect"])
		_flag_rect.texture = atlas
	_rows["government"].text = str(info.get("government", ""))
	_rows["rank"].text = "Ранг: %d%s" % [info.get("rank", 0), " (ВД)" if info.get("great_power", false) else ""]
	_rows["prestige"].text = "Престиж: %d-е место" % info.get("prestige_rank", 0)
	_rows["industry"].text = "Промышленность: %d-е место" % info.get("industrial_rank", 0)
	_rows["military"].text = "Армия: %d-е место" % info.get("military_rank", 0)
	_rows["population"].text = "Население: %s" % _format_number(info.get("population", 0))
	_rows["provinces"].text = "Провинций: %d" % info.get("provinces", 0)


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
	_fill_countries()


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
		_refresh_saves()
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

	SoundManager.play_effect_compat("click")
	PlayerSingleton.set_player_country_by_province_number(province_number)
	_update_selected_country_label()
	_fill_countries()
