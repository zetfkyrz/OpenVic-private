extends PanelContainer
## The panel of the command (B2 of the command system, docs/COMMAND.md): at the bottom in the middle of the screen. For every field marshal of the shown
## theatre: his big card on the left (the glow of his colour, under it "attached / maximum"), the smaller cards of his generals (the armies of his group) to
## the right in the same glow, a "+" slot for one more, the buttons of the plan, of the colour and the check mark of the plan (grey: no plan or it does not
## run, green: it runs). A general is dragged onto the card of a marshal to attach him, the cross on his card detaches him. A click on a marshal selects all
## his divisions on the map; a right click opens the menu (move to a theatre, take the marshal off). The colours come from the simulation (the palette of
## ov_data/common/ov_command/palette.txt); the armies and the generals without a marshal are grey. Only the countries with the organisation of the army
## have field marshals.

const _BIG: Vector2 = Vector2(66.0, 82.0)
const _SMALL: Vector2 = Vector2(46.0, 58.0)
const _GREY: Color = Color(0.55, 0.55, 0.55)
const _GENERALS_PER_ROW: int = 6
const _GREEN: Color = Color(0.25, 0.8, 0.3)
## Ids of the items of the menus that are not an index or a theatre
const _MENU_REMOVE: int = 100000
const _MENU_DELETE: int = 100001
## A new front: this id minus one is an empty front, this id plus the index of the enemy country a front against him
const _MENU_NEW_FRONT_BASE: int = 200000

var _unit_banners: Node
var _theatre_panel: Node
var _active_theatre: int = 0
var _signature: String = ""
var _row: HBoxContainer
## Groups that already existed when the player pressed "new field marshal": the new one goes to the shown theatre
var _known_group_ids: Dictionary = {}
var _waiting_for_group: bool = false
## Fronts that existed when the player asked for a new one; the new front goes to the group in _front_for_group (0: none is awaited)
var _known_front_ids: Dictionary = {}
var _front_for_group: int = 0
var _suppressed: bool = false
## The panel has something to show (the country has the organisation of the army)
var _wanted: bool = false


## One card (a field marshal or a general): a glow of the colour of the command behind a frame with the portrait. A general can be dragged, a card of a
## field marshal takes a general dropped on it and can be dragged to a theatre.
class _Card extends Panel:
	var drag_data: Dictionary = {}
	var accepts_generals: bool = false
	var on_drop: Callable
	var on_click: Callable
	var on_context: Callable

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if drag_data.is_empty():
			return null
		var preview := Label.new()
		preview.text = str(drag_data.get(&"caption", ""))
		preview.add_theme_color_override(&"font_color", Color.WHITE)
		preview.add_theme_color_override(&"font_outline_color", Color.BLACK)
		preview.add_theme_constant_override(&"outline_size", 4)
		set_drag_preview(preview)
		return drag_data

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return accepts_generals and data is Dictionary and (data as Dictionary).get(&"type", "") == "ov_general"

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if on_drop.is_valid():
			on_drop.call(data)

	func _gui_input(event: InputEvent) -> void:
		var mouse_event := event as InputEventMouseButton
		if mouse_event == null or not mouse_event.pressed:
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and on_click.is_valid():
			on_click.call()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and on_context.is_valid():
			on_context.call()


func setup(unit_banners: Node, theatre_panel: Node) -> void:
	_unit_banners = unit_banners
	_theatre_panel = theatre_panel
	if _theatre_panel != null:
		_theatre_panel.theatre_selected.connect(_on_theatre_selected)


## The text in Russian (the keys with the ending _RU of ov_data/localisation), the text of the locale if there is none
func _t(key: String) -> String:
	var russian: String = tr(key + "_RU")
	return russian if russian != key + "_RU" else tr(key)


func _ready() -> void:
	# At the bottom in the middle, grows upwards and to both sides; the minimap is at the bottom right, the panels of the armies at the bottom left
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -8.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.08, 0.82)
	style.set_border_width_all(2)
	style.border_color = Color(0.55, 0.42, 0.2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override(&"panel", style)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", 18)
	add_child(_row)
	GameSingleton.gamestate_updated.connect(_refresh)
	_refresh()


func get_active_theatre() -> int:
	return _active_theatre


func _on_theatre_selected(theatre_id: int) -> void:
	_active_theatre = theatre_id
	_signature = ""
	_refresh()


func _general_by_id(generals: Array, leader_id: int) -> Dictionary:
	for general: Dictionary in generals:
		if int(general[&"leader_id"]) == leader_id:
			return general
	return {}


func _general_of_army(generals: Array, army_id: int) -> Dictionary:
	for general: Dictionary in generals:
		if int(general[&"army_id"]) == army_id and not bool(general[&"is_marshal"]):
			return general
	return {}


## Another window of the interface is open: the panel is hidden until it is closed
func set_suppressed(suppressed: bool) -> void:
	_suppressed = suppressed
	visible = _wanted and not _suppressed


func _refresh() -> void:
	if not PlayerSingleton.has_army_organisation():
		_wanted = false
		visible = false
		return
	var groups: Array = PlayerSingleton.get_army_groups()
	var generals: Array = PlayerSingleton.get_generals()
	var theatres: Array = PlayerSingleton.get_theatres()
	# The shown theatre: the one chosen in the panel of the theatres, else the main one
	var main_id: int = 0
	var known_theatre: bool = false
	for theatre: Dictionary in theatres:
		if bool(theatre[&"is_main"]):
			main_id = int(theatre[&"id"])
		if int(theatre[&"id"]) == _active_theatre:
			known_theatre = true
	if not known_theatre:
		_active_theatre = main_id
	# A group that the player just made goes to the shown theatre
	if _waiting_for_group:
		for group: Dictionary in groups:
			if not _known_group_ids.has(int(group[&"id"])):
				_waiting_for_group = false
				if int(group[&"theatre_id"]) != _active_theatre and _active_theatre != 0:
					PlayerSingleton.set_army_group_theatre(int(group[&"id"]), _active_theatre)
	# A front that the player just made goes to the marshal whose menu he used
	if _front_for_group != 0:
		for front: Dictionary in PlayerSingleton.get_front_summaries():
			if not _known_front_ids.has(int(front[&"id"])):
				var front_group: int = _front_for_group
				_front_for_group = 0
				PlayerSingleton.set_army_group_front(front_group, int(front[&"id"]), true)
				PlayerSingleton.set_army_group_plan(front_group, int(front[&"id"]), 0)
				break
	var signature: String = str(_active_theatre) + str(groups) + str(theatres.size())
	for general: Dictionary in generals:
		signature += "%d:%d:%d;" % [int(general[&"leader_id"]), int(general[&"army_id"]), int(general[&"command_group_id"])]
	if signature == _signature:
		return
	_signature = signature
	_wanted = true
	visible = not _suppressed
	for child: Node in _row.get_children():
		child.queue_free()
	for group: Dictionary in groups:
		if int(group[&"theatre_id"]) == _active_theatre or _active_theatre == 0:
			_row.add_child(_make_group(group, generals, theatres))
	_row.add_child(_make_new_marshal_slot(groups))


func _make_card(general: Dictionary, card_size: Vector2, colour: Color, fallback: String, show_silhouette: bool = true) -> _Card:
	var card := _Card.new()
	card.custom_minimum_size = card_size + Vector2(12.0, 12.0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(colour.r, colour.g, colour.b, 0.55)
	glow_style.set_corner_radius_all(8)
	glow_style.shadow_color = Color(colour.r, colour.g, colour.b, 0.55)
	glow_style.shadow_size = 7
	card.add_theme_stylebox_override(&"panel", glow_style)
	var frame := Panel.new()
	frame.position = Vector2(6.0, 6.0)
	frame.size = card_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.16, 0.17, 0.2)
	frame_style.set_border_width_all(2)
	frame_style.border_color = Color(0.8, 0.7, 0.4)
	frame.add_theme_stylebox_override(&"panel", frame_style)
	card.add_child(frame)
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
	elif show_silhouette:
		# No picture (no file, no general): a silhouette
		var silhouette := Label.new()
		silhouette.text = "?" if general.is_empty() else "◉"
		silhouette.add_theme_font_size_override(&"font_size", int(card_size.y * 0.5))
		silhouette.add_theme_color_override(&"font_color", Color(0.45, 0.47, 0.52))
		silhouette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		silhouette.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		silhouette.size = card_size
		silhouette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(silhouette)
	card.tooltip_text = str(general.get(&"leader_name", fallback))
	return card


func _small_label(text: String, tooltip: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 12)
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 4)
	label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS if not tooltip.is_empty() else Control.MOUSE_FILTER_IGNORE
	return label


func _make_group(group: Dictionary, generals: Array, theatres: Array) -> Control:
	var group_id: int = int(group[&"id"])
	var colour: Color = group[&"colour"]
	var marshal_id: int = int(group[&"marshal_id"])
	var army_ids: Array = group[&"army_ids"]
	var max_attached: int = int(group[&"max_attached"])
	var block := HBoxContainer.new()
	block.add_theme_constant_override(&"separation", 6)

	# The field marshal and under him how many generals are attached
	var marshal_box := VBoxContainer.new()
	marshal_box.add_theme_constant_override(&"separation", 0)
	block.add_child(marshal_box)
	var marshal: Dictionary = _general_by_id(generals, marshal_id)
	var marshal_card: _Card = _make_card(marshal, _BIG, colour, _t("CMD_NO_MARSHAL"))
	marshal_card.accepts_generals = true
	marshal_card.on_drop = func(data: Dictionary) -> void:
		if int(data.get(&"army_id", 0)) != 0 and int(data.get(&"group_id", 0)) != group_id:
			PlayerSingleton.set_army_group(int(data[&"army_id"]), group_id)
	if marshal_id != 0:
		marshal_card.drag_data = { &"type": "ov_marshal", &"group_id": group_id, &"caption": str(marshal.get(&"leader_name", "")) }
		marshal_card.on_click = func() -> void:
			if _unit_banners != null:
				_unit_banners.select_armies(army_ids)
		marshal_card.on_context = _on_card_context.bind(group_id, int(group[&"theatre_id"]), theatres)
		marshal_card.tooltip_text = "%s\n%s" % [str(marshal.get(&"leader_name", "")), _t("CMD_MARSHAL_TOOLTIP")]
	else:
		marshal_card.on_click = _show_free_generals_menu.bind(group_id, true)
		marshal_card.on_context = _on_card_context.bind(group_id, int(group[&"theatre_id"]), theatres)
		marshal_card.tooltip_text = _t("CMD_NO_MARSHAL")
	marshal_box.add_child(marshal_card)
	marshal_box.add_child(_small_label("%d/%d" % [army_ids.size(), max_attached], _t("CMD_ATTACHED_TOOLTIP")))

	# The generals of the armies of the group, to the right of him, in the same glow
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 2)
	flow.add_theme_constant_override(&"v_separation", 2)
	flow.custom_minimum_size = Vector2(minf(float(max_attached), float(_GENERALS_PER_ROW)) * (_SMALL.x + 14.0), 0.0)
	block.add_child(flow)
	for army_id_value: Variant in army_ids:
		var army_id: int = int(army_id_value)
		var details: Dictionary = PlayerSingleton.get_army_details(army_id)
		var general: Dictionary = _general_of_army(generals, army_id)
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override(&"separation", 0)
		var card: _Card = _make_card(general, _SMALL, colour, str(details.get(&"name", "?")))
		card.drag_data = { &"type": "ov_general", &"army_id": army_id, &"group_id": group_id, &"caption": str(general.get(&"leader_name", details.get(&"name", ""))) }
		card.tooltip_text = "%s\n%s" % [str(general.get(&"leader_name", _t("CMD_NO_GENERAL"))), str(details.get(&"name", ""))]
		card.on_context = _attach_selected_to_group.bind(group_id)
		slot.add_child(card)
		var detach := Button.new()
		detach.text = "×"
		detach.flat = true
		detach.custom_minimum_size = Vector2(0.0, 18.0)
		detach.add_theme_font_size_override(&"font_size", 14)
		detach.add_theme_color_override(&"font_color", Color(1.0, 0.7, 0.7))
		detach.tooltip_text = _t("CMD_DETACH").replace("$NAME$", str(details.get(&"name", "?")))
		detach.pressed.connect(func() -> void: PlayerSingleton.set_army_group(army_id, 0))
		slot.add_child(detach)
		var divisions: int = (details.get(&"divisions", []) as Array).size()
		slot.add_child(_small_label(str(divisions), _t("CMD_DIVISIONS_TOOLTIP")))
		flow.add_child(slot)
	if army_ids.size() < max_attached:
		var plus := _make_card({}, _SMALL, colour, _t("CMD_ADD_GENERAL"), false)
		plus.on_click = _show_free_generals_menu.bind(group_id, false)
		plus.tooltip_text = _t("CMD_ADD_GENERAL")
		var plus_label := Label.new()
		plus_label.text = "+"
		plus_label.add_theme_font_size_override(&"font_size", 28)
		plus_label.add_theme_color_override(&"font_color", Color.WHITE)
		plus_label.position = Vector2(12.0, 8.0)
		plus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plus.add_child(plus_label)
		flow.add_child(plus)

	# The buttons: the plan, the colour and the check mark
	var side := VBoxContainer.new()
	side.add_theme_constant_override(&"separation", 4)
	block.add_child(side)
	var plan_button := _styled_button(_t("CMD_PLAN"))
	plan_button.tooltip_text = _t("CMD_PLAN_TOOLTIP")
	plan_button.pressed.connect(_show_plan_menu.bind(group))
	side.add_child(plan_button)
	var colour_button := _styled_button(_t("CMD_COLOUR"))
	colour_button.tooltip_text = _t("CMD_COLOUR_TOOLTIP")
	colour_button.pressed.connect(_show_colour_popup.bind(group_id, int(group[&"colour_index"])))
	side.add_child(colour_button)
	side.add_child(_make_check(group, marshal_id != 0))
	return block


func _styled_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(70.0, 28.0)
	for style_name: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color(0.22, 0.2, 0.16) if style_name != &"hover" else Color(0.32, 0.28, 0.2)
		button_style.set_border_width_all(1)
		button_style.border_color = Color(0.7, 0.58, 0.3)
		button_style.set_corner_radius_all(4)
		button.add_theme_stylebox_override(style_name, button_style)
	button.add_theme_color_override(&"font_color", Color(0.95, 0.9, 0.75))
	button.add_theme_color_override(&"font_hover_color", Color.WHITE)
	return button


## The check mark of the plan: grey when there is no plan or it does not run, green while it runs; a click starts or stops it
func _make_check(group: Dictionary, has_marshal: bool) -> Button:
	var active: bool = bool(group[&"plan_active"])
	var has_plan: bool = int(group[&"plan_front_id"]) != 0
	var check := Button.new()
	check.text = "✔"
	check.custom_minimum_size = Vector2(0.0, 30.0)
	for style_name: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		var check_style := StyleBoxFlat.new()
		check_style.bg_color = Color(0.2, 0.62, 0.25) if active else Color(0.3, 0.3, 0.32)
		check_style.set_border_width_all(2)
		check_style.border_color = Color(0.5, 0.9, 0.5) if active else Color(0.5, 0.5, 0.52)
		check_style.set_corner_radius_all(4)
		check.add_theme_stylebox_override(style_name, check_style)
	var text_colour: Color = Color.WHITE if active else Color(0.6, 0.6, 0.62)
	for colour_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_disabled_color"]:
		check.add_theme_color_override(colour_name, text_colour)
	if active:
		check.tooltip_text = _t("CMD_CHECK_ACTIVE")
	elif not has_plan:
		check.tooltip_text = _t("CMD_CHECK_NO_PLAN")
	elif not has_marshal:
		check.tooltip_text = _t("CMD_CHECK_NO_MARSHAL")
	else:
		check.tooltip_text = _t("CMD_CHECK_IDLE")
	var group_id: int = int(group[&"id"])
	check.pressed.connect(func() -> void: PlayerSingleton.set_army_group_plan_active(group_id, not active))
	return check


## The empty slot of a new field marshal: a new group of armies in the shown theatre
func _make_new_marshal_slot(groups: Array) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	var card := _make_card({}, _BIG, _GREY, _t("CMD_NEW_MARSHAL"), false)
	card.tooltip_text = _t("CMD_NEW_MARSHAL")
	var plus_label := Label.new()
	plus_label.text = "+"
	plus_label.add_theme_font_size_override(&"font_size", 40)
	plus_label.add_theme_color_override(&"font_color", Color.WHITE)
	plus_label.position = Vector2(22.0, 16.0)
	plus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(plus_label)
	card.on_click = func() -> void:
		_known_group_ids.clear()
		for group: Dictionary in groups:
			_known_group_ids[int(group[&"id"])] = true
		_waiting_for_group = true
		PlayerSingleton.create_army_group()
	box.add_child(card)
	box.add_child(_small_label(_t("CMD_NEW_MARSHAL")))
	return box


## A right click on a card of a marshal: the divisions that are selected on the map are attached to him, with none selected the menu opens
func _on_card_context(group_id: int, current_theatre: int, theatres: Array) -> void:
	if _attach_selected_to_group(group_id):
		return
	_show_marshal_menu(group_id, current_theatre, theatres)


## Attaches the armies selected on the map (those not in the command yet) to it; false if there is none to attach
func _attach_selected_to_group(group_id: int) -> bool:
	if _unit_banners == null:
		return false
	var to_attach: Array[int] = []
	for army_id: int in _unit_banners.get_selected_armies():
		if int(PlayerSingleton.get_army_details(army_id).get(&"army_group_id", 0)) != group_id:
			to_attach.append(army_id)
	if to_attach.is_empty():
		return false # nothing selected, or only his own divisions: the menu of the marshal opens
	for army_id: int in to_attach:
		PlayerSingleton.set_army_group(army_id, group_id)
	return true


func _new_menu() -> PopupMenu:
	var menu := PopupMenu.new()
	add_child(menu)
	menu.popup_hide.connect(menu.queue_free)
	return menu


func _popup_at_mouse(menu: PopupMenu) -> void:
	menu.position = Vector2i(get_global_mouse_position()) - Vector2i(0, int(menu.get_contents_minimum_size().y) + 8)
	menu.popup()


## A free general to a group: as the marshal of the group (marshal_slot) or attached to him (the army he leads goes into the group)
func _show_free_generals_menu(group_id: int, marshal_slot: bool) -> void:
	var menu := _new_menu()
	var entries: Array = []
	for general: Dictionary in PlayerSingleton.get_generals():
		if bool(general[&"is_marshal"]) or int(general[&"command_group_id"]) != 0:
			continue
		if not marshal_slot and int(general[&"army_id"]) == 0:
			continue # an attached general leads an army
		entries.append(general)
	if entries.is_empty():
		menu.add_item(_t("CMD_NO_FREE_GENERALS"))
		menu.set_item_disabled(0, true)
	for index: int in entries.size():
		var general: Dictionary = entries[index]
		var caption: String = str(general[&"leader_name"])
		if int(general[&"army_id"]) != 0:
			caption += " (%s)" % str(general[&"army_name"])
		menu.add_item(caption, index)
	menu.id_pressed.connect(func(id: int) -> void:
		var chosen: Dictionary = entries[id]
		if marshal_slot:
			PlayerSingleton.set_army_group_marshal(group_id, int(chosen[&"leader_id"]))
		else:
			PlayerSingleton.set_army_group(int(chosen[&"army_id"]), group_id)
	)
	_popup_at_mouse(menu)


## The menu of a field marshal: to another theatre, take the marshal off
func _show_marshal_menu(group_id: int, current_theatre: int, theatres: Array) -> void:
	var menu := _new_menu()
	var index: int = 0
	for theatre: Dictionary in theatres:
		index += 1
		if int(theatre[&"id"]) == current_theatre:
			continue
		var caption: String = _theatre_name(theatre, index)
		menu.add_item(_t("CMD_MOVE_TO_THEATRE").replace("$NAME$", caption), int(theatre[&"id"]))
	menu.add_separator()
	menu.add_item(_t("CMD_REMOVE_MARSHAL"), _MENU_REMOVE)
	menu.add_item(_t("CMD_DELETE_COMMAND"), _MENU_DELETE)
	menu.id_pressed.connect(func(id: int) -> void:
		if id == _MENU_REMOVE:
			PlayerSingleton.set_army_group_marshal(group_id, 0)
		elif id == _MENU_DELETE:
			PlayerSingleton.delete_army_group(group_id)
		else:
			PlayerSingleton.set_army_group_theatre(group_id, id)
	)
	_popup_at_mouse(menu)


func _theatre_name(theatre: Dictionary, index: int) -> String:
	var theatre_name: String = str(theatre[&"name"])
	if not theatre_name.is_empty():
		return theatre_name
	if bool(theatre[&"is_main"]):
		return _t("THEATRE_MAIN")
	return _t("THEATRE_DEFAULT_NAME").replace("$N$", str(index))


## The plan: a front of the player and the order for it (attack, hold); a front that is not his yet becomes his
func _show_plan_menu(group: Dictionary) -> void:
	var group_id: int = int(group[&"id"])
	var menu := _new_menu()
	var fronts: Array = PlayerSingleton.get_front_summaries()
	var entries: Array = []
	for front: Dictionary in fronts:
		var holder: int = int(front[&"group_id"])
		if holder != 0 and holder != group_id:
			continue # another marshal's front
		for mode: int in [1, 0]: # 1: attack, 0: hold (the modes of the plan are 0 attack, 1 hold)
			var plan_mode: int = 0 if mode == 1 else 1
			var caption: String = _t("CMD_PLAN_ATTACK" if plan_mode == 0 else "CMD_PLAN_HOLD").replace("$F$", str(front[&"id"])).replace("$N$", str(int(front[&"province_numbers"].size())))
			menu.add_check_item(caption, entries.size())
			var is_current: bool = int(group[&"plan_front_id"]) == int(front[&"id"]) and int(group[&"plan_mode"]) == plan_mode
			menu.set_item_checked(entries.size(), is_current)
			entries.append({ &"front_id": int(front[&"id"]), &"mode": plan_mode, &"held": holder == group_id })
	if entries.is_empty():
		menu.add_item(_t("CMD_NO_FRONTS"))
		menu.set_item_disabled(0, true)
	# New fronts: against an enemy the player is at war with (the line is drawn by itself) or an empty one (its provinces are chosen in the war window, F6)
	menu.add_separator()
	var enemy_indices: Array[int] = []
	for war: Dictionary in PlayerSingleton.get_war_overview().get("wars", []):
		for enemy: Dictionary in (war["defenders"] if war["we_attack"] else war["attackers"]):
			if not enemy_indices.has(int(enemy["index"])):
				enemy_indices.append(int(enemy["index"]))
				menu.add_item(_t("CMD_NEW_FRONT_VS").replace("$NAME$", str(enemy["name"])), _MENU_NEW_FRONT_BASE + int(enemy["index"]))
	menu.add_item(_t("CMD_NEW_FRONT_EMPTY"), _MENU_NEW_FRONT_BASE - 1)
	if int(group[&"plan_front_id"]) != 0:
		menu.add_separator()
		menu.add_item(_t("CMD_PLAN_CLEAR"), _MENU_REMOVE)
	menu.id_pressed.connect(func(id: int) -> void:
		if id == _MENU_REMOVE:
			PlayerSingleton.set_army_group_front(group_id, int(group[&"plan_front_id"]), false)
			return
		if id >= _MENU_NEW_FRONT_BASE - 1:
			# The front appears on the next update of the state, then it goes to this marshal with the order to attack
			_known_front_ids.clear()
			for front: Dictionary in PlayerSingleton.get_front_summaries():
				_known_front_ids[int(front[&"id"])] = true
			_front_for_group = group_id
			PlayerSingleton.create_front(id - _MENU_NEW_FRONT_BASE if id >= _MENU_NEW_FRONT_BASE else -1)
			return
		var entry: Dictionary = entries[id]
		if not bool(entry[&"held"]):
			PlayerSingleton.set_army_group_front(group_id, int(entry[&"front_id"]), true)
		PlayerSingleton.set_army_group_plan(group_id, int(entry[&"front_id"]), int(entry[&"mode"]))
	)
	_popup_at_mouse(menu)


## The palette of the command: a click on a colour recolours the marshal (his generals and the lines of his fronts follow)
func _show_colour_popup(group_id: int, current_index: int) -> void:
	var popup := PopupPanel.new()
	add_child(popup)
	popup.popup_hide.connect(popup.queue_free)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 4)
	popup.add_child(grid)
	var palette: Array = PlayerSingleton.get_command_palette()
	for index: int in palette.size():
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(30.0, 30.0)
		for style_name: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
			var swatch_style := StyleBoxFlat.new()
			swatch_style.bg_color = palette[index]
			swatch_style.set_border_width_all(3 if index == current_index else 1)
			swatch_style.border_color = Color.WHITE if index == current_index else Color(0.1, 0.1, 0.1)
			swatch.add_theme_stylebox_override(style_name, swatch_style)
		swatch.pressed.connect(func() -> void:
			PlayerSingleton.set_army_group_colour(group_id, index)
			popup.hide()
		)
		grid.add_child(swatch)
	popup.position = Vector2i(get_global_mouse_position()) - Vector2i(0, int(grid.get_combined_minimum_size().y) + 24)
	popup.popup()
