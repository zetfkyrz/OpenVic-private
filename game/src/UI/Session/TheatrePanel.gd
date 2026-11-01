extends PanelContainer
## The panel of the theatres (B4 and B2 of the command system, docs/COMMAND.md): at the right edge of the screen, a little above the middle. The list of the
## theatres of the player, for every one the number of his field marshals and divisions, a frame of its colour; a click shows the theatre (the panel of
## the command shows only its marshals) and turns the camera to its region (if it is tied to one). The buttons of a row: rename, tie the region to the
## present position of the camera, delete (not the main one). "New theatre" at the bottom. A field marshal is dragged from his card onto a row to move him
## to that theatre. The main theatre ("Основной") is made by the simulation and takes the marshals without a theatre. Only the countries with the
## organisation of the army have theatres.

## The theatre that is shown was chosen (the panel of the command shows only its field marshals)
signal theatre_selected(theatre_id: int)

const _WIDTH: float = 250.0

var _map_view: Node
var _active_theatre: int = 0
var _signature: String = ""
var _rows: VBoxContainer
var _dialog: ConfirmationDialog
var _name_edit: LineEdit
var _renaming_id: int = 0


## One row of the list: takes a field marshal dropped on it
class _Row extends PanelContainer:
	var theatre_id: int = 0
	var on_drop: Callable
	var on_click: Callable

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and (data as Dictionary).get(&"type", "") == "ov_marshal"

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if on_drop.is_valid():
			on_drop.call(data)

	func _gui_input(event: InputEvent) -> void:
		var mouse_event := event as InputEventMouseButton
		if mouse_event and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and on_click.is_valid():
			on_click.call()


func setup(map_view: Node) -> void:
	_map_view = map_view


## The text in Russian (the keys with the ending _RU of ov_data/localisation), the text of the locale if there is none
func _t(key: String) -> String:
	var russian: String = tr(key + "_RU")
	return russian if russian != key + "_RU" else tr(key)


func _ready() -> void:
	# At the right edge, a little above the middle
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.3
	anchor_bottom = 0.3
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_END
	offset_right = -6.0
	custom_minimum_size = Vector2(_WIDTH, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.08, 0.85)
	style.set_border_width_all(2)
	style.border_color = Color(0.55, 0.42, 0.2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override(&"panel", style)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 4)
	add_child(root)
	var title := Label.new()
	title.text = _t("THEATRE_TITLE")
	title.add_theme_font_size_override(&"font_size", 16)
	title.add_theme_color_override(&"font_color", Color(0.95, 0.85, 0.55))
	root.add_child(title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 3)
	root.add_child(_rows)
	var new_button := Button.new()
	new_button.text = _t("THEATRE_NEW")
	new_button.tooltip_text = _t("THEATRE_NEW_TOOLTIP")
	new_button.pressed.connect(func() -> void: PlayerSingleton.create_theatre())
	root.add_child(new_button)
	# The dialog of the name
	_dialog = ConfirmationDialog.new()
	_dialog.title = _t("THEATRE_NAME_PROMPT")
	_dialog.ok_button_text = "OK"
	_name_edit = LineEdit.new()
	_name_edit.max_length = 30
	_name_edit.custom_minimum_size = Vector2(260.0, 0.0)
	_name_edit.text_submitted.connect(_on_name_submitted)
	_dialog.add_child(_name_edit)
	_dialog.confirmed.connect(_on_name_confirmed)
	add_child(_dialog)
	GameSingleton.gamestate_updated.connect(_refresh)
	_refresh()


func get_active_theatre() -> int:
	return _active_theatre


func _theatre_name(theatre: Dictionary, index: int) -> String:
	var theatre_name: String = str(theatre[&"name"])
	if not theatre_name.is_empty():
		return theatre_name
	if bool(theatre[&"is_main"]):
		return _t("THEATRE_MAIN")
	return _t("THEATRE_DEFAULT_NAME").replace("$N$", str(index))


func _refresh() -> void:
	if not PlayerSingleton.has_army_organisation():
		visible = false
		return
	var theatres: Array = PlayerSingleton.get_theatres()
	var main_id: int = 0
	var known: bool = false
	for theatre: Dictionary in theatres:
		if bool(theatre[&"is_main"]):
			main_id = int(theatre[&"id"])
		if int(theatre[&"id"]) == _active_theatre:
			known = true
	if not known:
		_active_theatre = main_id
		theatre_selected.emit(_active_theatre)
	var signature: String = str(_active_theatre) + str(theatres)
	if signature == _signature:
		return
	_signature = signature
	visible = not theatres.is_empty()
	for child: Node in _rows.get_children():
		child.queue_free()
	var index: int = 0
	for theatre: Dictionary in theatres:
		index += 1
		_rows.add_child(_make_row(theatre, index))


func _make_row(theatre: Dictionary, index: int) -> Control:
	var theatre_id: int = int(theatre[&"id"])
	var colour: Color = theatre[&"colour"]
	var is_active: bool = theatre_id == _active_theatre
	var row := _Row.new()
	row.theatre_id = theatre_id
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.16, 0.95) if is_active else Color(0.12, 0.13, 0.15, 0.95)
	style.set_border_width_all(3 if is_active else 2)
	style.border_color = colour
	style.set_corner_radius_all(4)
	style.content_margin_left = 6.0
	style.content_margin_right = 4.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	row.add_theme_stylebox_override(&"panel", style)
	row.tooltip_text = _t("THEATRE_ROW_TOOLTIP").replace("$M$", str(int(theatre[&"marshal_count"]))).replace("$D$", str(int(theatre[&"division_count"])))
	row.on_click = _on_row_clicked.bind(theatre_id, int(theatre[&"focus_province"]))
	row.on_drop = func(data: Dictionary) -> void:
		PlayerSingleton.set_army_group_theatre(int(data[&"group_id"]), theatre_id)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 1)
	row.add_child(box)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override(&"separation", 2)
	box.add_child(top)
	var name_label := Label.new()
	name_label.text = _theatre_name(theatre, index)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.add_theme_font_size_override(&"font_size", 15)
	name_label.add_theme_color_override(&"font_color", Color.WHITE)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(name_label)
	top.add_child(_tool_button("✎", _t("THEATRE_RENAME"), func() -> void: _open_rename(theatre_id, str(theatre[&"name"]))))
	var focus_tooltip: String = _t("THEATRE_FOCUS")
	if int(theatre[&"focus_province"]) != 0:
		focus_tooltip += "\n" + _t("THEATRE_FOCUS_SET").replace("$N$", str(int(theatre[&"focus_province"])))
	top.add_child(_tool_button("⌖", focus_tooltip, func() -> void: _tie_region(theatre_id)))
	if not bool(theatre[&"is_main"]):
		top.add_child(_tool_button("×", _t("THEATRE_DELETE"), func() -> void: PlayerSingleton.delete_theatre(theatre_id)))
	var counts := Label.new()
	counts.text = _t("THEATRE_COUNTS").replace("$M$", str(int(theatre[&"marshal_count"]))).replace("$D$", str(int(theatre[&"division_count"])))
	counts.add_theme_font_size_override(&"font_size", 12)
	counts.add_theme_color_override(&"font_color", Color(0.78, 0.78, 0.8))
	counts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(counts)
	return row


func _tool_button(text: String, tooltip: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.custom_minimum_size = Vector2(24.0, 22.0)
	button.add_theme_font_size_override(&"font_size", 15)
	button.tooltip_text = tooltip
	button.pressed.connect(action)
	return button


## A click on a row shows the theatre and turns the camera to its region
func _on_row_clicked(theatre_id: int, focus_province: int) -> void:
	_active_theatre = theatre_id
	_signature = ""
	theatre_selected.emit(theatre_id)
	if focus_province != 0 and _map_view != null:
		_map_view.look_at_province_number(focus_province)
	_refresh()


## The region of a theatre is the province in the middle of the view now
func _tie_region(theatre_id: int) -> void:
	if _map_view == null:
		return
	var province_number: int = _map_view.get_view_centre_province_number()
	if province_number != 0:
		PlayerSingleton.set_theatre_focus(theatre_id, province_number)


func _open_rename(theatre_id: int, current_name: String) -> void:
	_renaming_id = theatre_id
	_name_edit.text = current_name
	_dialog.popup_centered()
	_name_edit.grab_focus()
	_name_edit.select_all()


func _on_name_submitted(_text: String) -> void:
	_dialog.hide()
	_on_name_confirmed()


func _on_name_confirmed() -> void:
	if _renaming_id != 0:
		PlayerSingleton.rename_theatre(_renaming_id, _name_edit.text)
		_renaming_id = 0
