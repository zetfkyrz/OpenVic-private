extends Control
## The strip of the commanders on the main screen: for every group of armies the field marshal as a bigger card and to the right of him smaller cards of the
## generals attached to him, with a glow of the colour of the group behind them, the number n/8 under the marshal and a mark whether the group follows the
## orders (green) or not (grey). A click opens the window of the commanders. The colours are the ones of the window (user://leader_colours.cfg).

const _BIG: Vector2 = Vector2(58.0, 72.0)
const _SMALL: Vector2 = Vector2(42.0, 52.0)
const _PALETTE: Array[Color] = [
	Color(0.85, 0.25, 0.25), Color(0.25, 0.55, 0.9), Color(0.3, 0.75, 0.35), Color(0.9, 0.7, 0.2), Color(0.65, 0.35, 0.85),
	Color(0.2, 0.75, 0.75), Color(0.95, 0.5, 0.2), Color(0.85, 0.4, 0.65),
]
const _COLOUR_FILE: String = "user://leader_colours.cfg"

var _window: Control
var _signature: String = ""
var _row: HBoxContainer


func setup(window: Control) -> void:
	_window = window


func _ready() -> void:
	position = Vector2(440.0, 84.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", 16)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	GameSingleton.gamestate_updated.connect(_refresh)
	_refresh()


func _colour_index(key: int, chosen: Dictionary) -> int:
	if chosen.has(key):
		return int(chosen[key]) % _PALETTE.size()
	var h: int = hash(key)
	return (h if h >= 0 else -h) % _PALETTE.size()


func _chosen_colours() -> Dictionary:
	var result: Dictionary = {}
	var config := ConfigFile.new()
	if config.load(_COLOUR_FILE) == OK:
		for key: String in config.get_section_keys("colours"):
			result[int(key)] = int(config.get_value("colours", key))
	return result


func _refresh() -> void:
	if not PlayerSingleton.has_army_organisation():
		_row.visible = false
		return
	var groups: Array = PlayerSingleton.get_army_groups()
	var generals: Array = PlayerSingleton.get_generals()
	var signature: String = str(groups)
	for general: Dictionary in generals:
		signature += "%d:%d;" % [general[&"leader_id"], general[&"army_id"]]
	var chosen: Dictionary = _chosen_colours()
	signature += str(chosen)
	if signature == _signature:
		return
	_signature = signature
	for child: Node in _row.get_children():
		child.queue_free()
	_row.visible = not groups.is_empty()
	for group: Dictionary in groups:
		_row.add_child(_make_group(group, generals, chosen))


func _general_by_id(generals: Array, leader_id: int) -> Dictionary:
	for general: Dictionary in generals:
		if int(general[&"leader_id"]) == leader_id:
			return general
	return {}


func _card(general: Dictionary, card_size: Vector2, colour: Color, fallback: String) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = card_size + Vector2(12.0, 12.0)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := Panel.new()
	glow.position = Vector2(0.0, 0.0)
	glow.size = card_size + Vector2(12.0, 12.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(colour.r, colour.g, colour.b, 0.55)
	glow_style.set_corner_radius_all(8)
	glow_style.shadow_color = Color(colour.r, colour.g, colour.b, 0.5)
	glow_style.shadow_size = 6
	glow.add_theme_stylebox_override(&"panel", glow_style)
	slot.add_child(glow)
	var frame := Panel.new()
	frame.position = Vector2(6.0, 6.0)
	frame.size = card_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.16, 0.17, 0.2)
	frame_style.set_border_width_all(2)
	frame_style.border_color = Color(0.8, 0.7, 0.4)
	frame.add_theme_stylebox_override(&"panel", frame_style)
	slot.add_child(frame)
	var picture: Texture2D = general.get(&"leader_picture", null) as Texture2D
	if picture != null:
		var portrait := TextureRect.new()
		portrait.texture = picture
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.position = Vector2(2.0, 2.0)
		portrait.size = card_size - Vector2(4.0, 4.0)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(portrait)
	slot.tooltip_text = str(general.get(&"leader_name", fallback))
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.gui_input.connect(_on_card_input)
	return slot


func _make_group(group: Dictionary, generals: Array, chosen: Dictionary) -> Control:
	var key: int = int(group[&"marshal_id"]) if int(group[&"marshal_id"]) != 0 else -int(group[&"id"])
	var colour: Color = _PALETTE[_colour_index(key, chosen)]
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var marshal_box := VBoxContainer.new()
	marshal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marshal_box.add_theme_constant_override(&"separation", 0)
	box.add_child(marshal_box)
	marshal_box.add_child(_card(_general_by_id(generals, int(group[&"marshal_id"])), _BIG, colour, "Нет фельдмаршала"))
	var counter := Label.new()
	counter.text = "%d/%d" % [int(group[&"army_count"]), int(group[&"max_attached"])]
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.add_theme_font_size_override(&"font_size", 12)
	counter.add_theme_color_override(&"font_color", Color.WHITE)
	counter.add_theme_color_override(&"font_outline_color", Color.BLACK)
	counter.add_theme_constant_override(&"outline_size", 4)
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marshal_box.add_child(counter)
	for army_id: int in group[&"army_ids"]:
		var details: Dictionary = PlayerSingleton.get_army_details(army_id)
		var general: Dictionary = _general_by_id(generals, int(details.get(&"leader_id", 0)))
		var small := VBoxContainer.new()
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		small.add_child(_card(general, _SMALL, colour, str(details.get(&"name", "?"))))
		box.add_child(small)
	# The mark of the orders: green when the group follows them, grey when it does not
	var mark := ColorRect.new()
	mark.custom_minimum_size = Vector2(10.0, 10.0)
	mark.color = Color(0.25, 0.8, 0.3) if bool(group[&"execute_orders"]) else Color(0.45, 0.45, 0.48)
	mark.tooltip_text = "Выполняет приказы" if bool(group[&"execute_orders"]) else "Приказы не выполняет"
	box.add_child(mark)
	return box


func _on_card_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and _window != null:
		_window.open_groups()
