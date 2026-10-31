extends "res://src/UI/Session/Vic2Window.gd"
## The commanders (docs/PLAN_ARMY_SUPPLY_FRONTS.md, sections 1 and 4): a group of armies has a field marshal, the big card on the left; the generals of the
## armies of the group are the smaller cards to the right of him, attached to him (how many of them: n / the maximum, 8 for now, the technologies will raise it).
## Behind the cards of a group there is a glow of its colour (every marshal gets a colour at random, the button changes it). The check mark says whether the group
## follows the orders: grey when it does not, green when it does. Only the countries with the technology of the organisation of the army have groups.

const _SIZE: Vector2 = Vector2(980, 560)
const _BIG: Vector2 = Vector2(116.0, 150.0)
const _SMALL: Vector2 = Vector2(88.0, 112.0)
const _PALETTE: Array[Color] = [
	Color(0.85, 0.25, 0.25), Color(0.25, 0.55, 0.9), Color(0.3, 0.75, 0.35), Color(0.9, 0.7, 0.2), Color(0.65, 0.35, 0.85),
	Color(0.2, 0.75, 0.75), Color(0.95, 0.5, 0.2), Color(0.85, 0.4, 0.65),
]
const _COLOUR_FILE: String = "user://leader_colours.cfg"

var _groups: Array = []
var _generals: Array = []
var _selected_id: int = 0
var _signature: String = ""
var _colours: Dictionary = {} # key (marshal id, or -group id) -> palette index

var _info_label: Label
var _rows: VBoxContainer
var _marshal_option: OptionButton
var _assign_button: Button
var _remove_button: Button
var _create_button: Button
var _delete_button: Button


func _ready() -> void:
	setup(_SIZE, "Командование")
	_load_colours()

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 6)
	content.add_child(root)

	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_info_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var field := StyleBoxFlat.new()
	field.bg_color = Color(0.09, 0.1, 0.11)
	field.set_border_width_all(2)
	field.border_color = Color(0.35, 0.25, 0.12)
	scroll.add_theme_stylebox_override(&"panel", field)
	root.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 10)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)

	var marshal_row := HBoxContainer.new()
	marshal_row.add_theme_constant_override(&"separation", 6)
	root.add_child(marshal_row)
	var marshal_caption := Label.new()
	marshal_caption.text = "Фельдмаршал выбранной группы:"
	marshal_row.add_child(marshal_caption)
	_marshal_option = OptionButton.new()
	_marshal_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_marshal_option.clip_text = true
	marshal_row.add_child(_marshal_option)
	_assign_button = Button.new()
	_assign_button.text = "Назначить"
	_assign_button.tooltip_text = "Генерал, который командует армией, оставит её и станет фельдмаршалом"
	_assign_button.pressed.connect(_on_assign_pressed)
	marshal_row.add_child(_assign_button)
	_remove_button = Button.new()
	_remove_button.text = "Снять"
	_remove_button.pressed.connect(_on_remove_pressed)
	marshal_row.add_child(_remove_button)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override(&"separation", 6)
	root.add_child(button_row)
	_create_button = Button.new()
	_create_button.text = "Создать группу"
	_create_button.pressed.connect(_on_create_pressed)
	button_row.add_child(_create_button)
	_delete_button = Button.new()
	_delete_button.text = "Удалить выбранную"
	_delete_button.tooltip_text = "Армии группы остаются, фельдмаршал освобождается"
	_delete_button.pressed.connect(_on_delete_pressed)
	button_row.add_child(_delete_button)

	GameSingleton.gamestate_updated.connect(_refresh)


func open_groups() -> void:
	# The window is opened first (a hidden window does not refresh)
	_signature = ""
	open_window()
	_refresh()


func _load_colours() -> void:
	var config := ConfigFile.new()
	if config.load(_COLOUR_FILE) == OK:
		for key: String in config.get_section_keys("colours"):
			_colours[int(key)] = int(config.get_value("colours", key))


func _save_colours() -> void:
	var config := ConfigFile.new()
	for key: int in _colours:
		config.set_value("colours", str(key), _colours[key])
	config.save(_COLOUR_FILE)


## The colour of a group: the one the player chose, else one taken from the palette by the key (always the same for the same commander)
func _colour_index(key: int) -> int:
	if _colours.has(key):
		return int(_colours[key]) % _PALETTE.size()
	return int(hash(key)) % _PALETTE.size() if hash(key) >= 0 else int(-hash(key)) % _PALETTE.size()


func _group_key(group: Dictionary) -> int:
	return int(group[&"marshal_id"]) if int(group[&"marshal_id"]) != 0 else -int(group[&"id"])


func _general_by_id(leader_id: int) -> Dictionary:
	for general: Dictionary in _generals:
		if int(general[&"leader_id"]) == leader_id:
			return general
	return {}


func _refresh() -> void:
	if not visible:
		return
	if not PlayerSingleton.has_army_organisation():
		_info_label.text = "Группы армий и фельдмаршалы открываются технологией «Организация армии» (цивилизованным странам)."
	else:
		_info_label.text = "Слева фельдмаршал группы, правее и мельче — прикреплённые к нему генералы армий. Армия входит в группу в своей панели. Фельдмаршал даёт половину своего бонуса к снабжению всем армиям группы."
	_groups = PlayerSingleton.get_army_groups()
	_generals = PlayerSingleton.get_generals()
	var signature: String = str(_groups) + str(_selected_id) + str(_colours)
	for general: Dictionary in _generals:
		signature += "%d:%d:%s;" % [general[&"leader_id"], general[&"army_id"], general.get(&"is_marshal", false)]
	if signature == _signature:
		return
	_signature = signature
	_rebuild_rows()
	_marshal_option.clear()
	for general: Dictionary in _generals:
		# Every general that is not a marshal already can become one (a general that leads an army leaves it)
		if not general.get(&"is_marshal", false):
			var text: String = "%s (престиж %.1f)" % [general.get(&"leader_name", "?"), general[&"prestige"]]
			if general[&"army_id"] != 0:
				text += " - командует: %s" % general[&"army_name"]
			_marshal_option.add_item(text)
			_marshal_option.set_item_metadata(_marshal_option.item_count - 1, general[&"leader_id"])
	_update_buttons()


func _rebuild_rows() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	for group: Dictionary in _groups:
		_rows.add_child(_make_row(group))


func _glow(size: Vector2, colour: Color) -> Panel:
	var glow := Panel.new()
	glow.position = Vector2(-9.0, -9.0)
	glow.size = size + Vector2(18.0, 18.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(colour.r, colour.g, colour.b, 0.5)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(colour.r, colour.g, colour.b, 0.6)
	style.shadow_size = 10
	glow.add_theme_stylebox_override(&"panel", style)
	return glow


## A card: the portrait, the name under it; the glow of the colour of the group is behind it
func _make_card(general: Dictionary, fallback_name: String, card_size: Vector2, colour: Color) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = card_size + Vector2(18.0, 18.0)
	var card := Control.new()
	card.position = Vector2(9.0, 9.0)
	card.size = card_size
	slot.add_child(card)
	card.add_child(_glow(card_size, colour))
	var frame := Panel.new()
	frame.size = card_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.16, 0.17, 0.2)
	frame_style.set_border_width_all(2)
	frame_style.border_color = Color(0.75, 0.65, 0.35)
	frame.add_theme_stylebox_override(&"panel", frame_style)
	card.add_child(frame)
	var picture: Texture2D = general.get(&"leader_picture", null) as Texture2D
	if picture != null:
		var portrait := TextureRect.new()
		portrait.texture = picture
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.position = Vector2(4.0, 4.0)
		portrait.size = Vector2(card_size.x - 8.0, card_size.y - 30.0)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait)
	var name_label := Label.new()
	name_label.text = str(general.get(&"leader_name", fallback_name))
	name_label.position = Vector2(2.0, card_size.y - 26.0)
	name_label.size = Vector2(card_size.x - 4.0, 22.0)
	name_label.clip_text = true
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override(&"font_size", 12)
	name_label.add_theme_color_override(&"font_color", Color(0.95, 0.95, 0.95))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_label)
	if not general.is_empty():
		slot.tooltip_text = "%s\nПрестиж %.1f\n%s, %s" % [general.get(&"leader_name", ""), general[&"prestige"], general[&"personality"], general[&"background"]]
	return slot


func _make_row(group: Dictionary) -> Control:
	var group_id: int = int(group[&"id"])
	var colour: Color = _PALETTE[_colour_index(_group_key(group))]
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.16) if group_id != _selected_id else Color(0.2, 0.2, 0.17)
	style.set_border_width_all(2 if group_id == _selected_id else 1)
	style.border_color = Color(0.9, 0.75, 0.3) if group_id == _selected_id else Color(0.3, 0.3, 0.34)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override(&"panel", style)
	panel.gui_input.connect(_on_row_input.bind(group_id))

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	panel.add_child(row)

	# The field marshal: the big card, under it the number of the generals attached to him
	var marshal_box := VBoxContainer.new()
	var marshal: Dictionary = _general_by_id(int(group[&"marshal_id"]))
	row.add_child(marshal_box)
	marshal_box.add_child(_make_card(marshal, "Нет фельдмаршала", _BIG, colour))
	var counter := Label.new()
	counter.text = "%d/%d" % [int(group[&"army_count"]), int(group[&"max_attached"])]
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.add_theme_color_override(&"font_color", Color(0.95, 0.9, 0.75))
	counter.tooltip_text = "Прикреплено армий / максимум (растёт с технологиями)"
	marshal_box.add_child(counter)

	# The generals of the armies of the group, smaller, to the right of him
	var attached := HBoxContainer.new()
	attached.add_theme_constant_override(&"separation", 2)
	attached.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(attached)
	for army_id: int in group[&"army_ids"]:
		var details: Dictionary = PlayerSingleton.get_army_details(army_id)
		var leader_id: int = int(details.get(&"leader_id", 0))
		var general: Dictionary = _general_by_id(leader_id)
		var box := VBoxContainer.new()
		box.add_child(_make_card(general, str(details.get(&"name", "?")), _SMALL, colour))
		var detach := Button.new()
		detach.text = "×"
		detach.tooltip_text = "Открепить армию «%s» от группы" % str(details.get(&"name", "?"))
		detach.pressed.connect(func() -> void: PlayerSingleton.set_army_group(army_id, 0))
		box.add_child(detach)
		attached.add_child(box)

	# The check mark (follows the orders: green, does not: grey) and the colour
	var side := VBoxContainer.new()
	side.add_theme_constant_override(&"separation", 6)
	row.add_child(side)
	var orders := Button.new()
	var follows: bool = bool(group[&"execute_orders"])
	orders.text = "✔"
	orders.custom_minimum_size = Vector2(44, 36)
	orders.tooltip_text = "Выполняет приказы" if follows else "Приказы не выполняет"
	for style_name: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		var check_style := StyleBoxFlat.new()
		check_style.bg_color = Color(0.2, 0.62, 0.25) if follows else Color(0.3, 0.3, 0.32)
		check_style.set_border_width_all(2)
		check_style.border_color = Color(0.5, 0.9, 0.5) if follows else Color(0.5, 0.5, 0.52)
		check_style.set_corner_radius_all(4)
		orders.add_theme_stylebox_override(style_name, check_style)
	orders.add_theme_color_override(&"font_color", Color.WHITE if follows else Color(0.55, 0.55, 0.58))
	orders.add_theme_color_override(&"font_hover_color", Color.WHITE if follows else Color(0.55, 0.55, 0.58))
	orders.pressed.connect(func() -> void: PlayerSingleton.set_army_group_orders(group_id, not follows))
	side.add_child(orders)
	var colour_button := Button.new()
	colour_button.text = "Цвет"
	colour_button.tooltip_text = "Сменить цвет подсветки группы"
	colour_button.pressed.connect(_on_colour_pressed.bind(_group_key(group)))
	side.add_child(colour_button)
	return panel


func _on_row_input(event: InputEvent, group_id: int) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_selected_id = group_id
		_signature = ""
		_refresh()


func _on_colour_pressed(key: int) -> void:
	_colours[key] = (_colour_index(key) + 1) % _PALETTE.size()
	_save_colours()
	_signature = ""
	_refresh()


func _update_buttons() -> void:
	var allowed: bool = PlayerSingleton.has_army_organisation()
	var selected: bool = _selected_id != 0
	_create_button.disabled = not allowed
	_delete_button.disabled = not allowed or not selected
	_assign_button.disabled = not allowed or not selected or _marshal_option.item_count == 0
	_marshal_option.disabled = not allowed or not selected or _marshal_option.item_count == 0
	var has_marshal: bool = false
	for group: Dictionary in _groups:
		if group[&"id"] == _selected_id and group[&"marshal_id"] != 0:
			has_marshal = true
	_remove_button.disabled = not allowed or not selected or not has_marshal


func _on_create_pressed() -> void:
	PlayerSingleton.create_army_group()


func _on_delete_pressed() -> void:
	PlayerSingleton.delete_army_group(_selected_id)
	_selected_id = 0


func _on_assign_pressed() -> void:
	if _marshal_option.item_count == 0 or _marshal_option.selected < 0:
		return
	PlayerSingleton.set_army_group_marshal(_selected_id, _marshal_option.get_item_metadata(_marshal_option.selected))


func _on_remove_pressed() -> void:
	PlayerSingleton.set_army_group_marshal(_selected_id, 0)
