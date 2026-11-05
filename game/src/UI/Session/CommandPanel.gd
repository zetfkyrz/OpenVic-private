extends PanelContainer
## The panel of the command (docs/COMMAND.md, docs/WAR_ASSUMPTIONS.md section 6): at the bottom in the middle of the screen. On the left the slot of a new
## field marshal ("+"), then for every field marshal of the shown theatre his card (under it how many generals are attached), the cards of his generals
## (under them their divisions, a cross detaches one) and a "+" slot for one more general. A click on a marshal selects him: the plate of his plans
## appears above him and his generals (in the middle of them) and his divisions are selected on the map. The plate: the execution of the plan (the
## arrows: 1 careful, 2 balanced, 3 aggressive; a click starts or stops it, a right click changes the mode), the integrity of the front (a click
## changes it), the tools that draw on the map (the naval invasion, the front, the offensive, the line of defence, the coastal defence, the edit mode,
## PlanTools.gd) and the trash (deletes the fronts and the lines of the marshal). A general is dragged onto the card of a marshal to attach him; a right
## click on a marshal attaches the divisions selected on the map or opens his menu (the colour, the theatre, take him off). The colours come from the
## simulation (ov_data/common/ov_command/palette.txt). Only the countries with mechanic:command have field marshals.

const _BIG: Vector2 = Vector2(62.0, 78.0)
const _SMALL: Vector2 = Vector2(52.0, 66.0)
const _GREY: Color = Color(0.55, 0.55, 0.55)
const _GOLD: Color = Color(0.78, 0.64, 0.33)
const _DARK: Color = Color(0.09, 0.09, 0.1, 0.94)
const _GREEN: Color = Color(0.35, 0.85, 0.35)
const _GENERALS_PER_ROW: int = 8
const _BUTTON: Vector2 = Vector2(34.0, 34.0)
## Ids of the items of the menus that are not a theatre
const _MENU_REMOVE: int = 100000
const _MENU_DELETE: int = 100001
const _MENU_COLOUR: int = 100002

var _unit_banners: Node
var _theatre_panel: Node
var _plan_tools: Node
var _active_theatre: int = 0
var _signature: String = ""
var _box: VBoxContainer
var _plate_holder: Control
var _plate: PanelContainer
var _row_panel: PanelContainer
var _row: HBoxContainer
## The field marshal whose plate is shown (0: none) and the block of his cards (the plate stands over the middle of his cards)
var _selected_group: int = 0
var _selected_block: Control
## Groups that already existed when the player pressed "new field marshal": the new one goes to the shown theatre
var _known_group_ids: Dictionary = {}
var _waiting_for_group: bool = false
var _suppressed: bool = false
## The panel has something to show (the country has mechanic:command)
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


## A silhouette of an officer (no portrait): the head, the cap and the shoulders, drawn
class _Silhouette extends Control:
	var plus: bool = false

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var shade := Color(0.33, 0.34, 0.37)
		var dark := Color(0.2, 0.21, 0.23)
		# The shoulders and the collar
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.08, h), Vector2(w * 0.14, h * 0.78), Vector2(w * 0.36, h * 0.68), Vector2(w * 0.64, h * 0.68),
			Vector2(w * 0.86, h * 0.78), Vector2(w * 0.92, h),
		]), shade)
		# The head
		draw_circle(Vector2(w * 0.5, h * 0.47), w * 0.2, shade)
		# The cap: the crown and the peak
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.26, h * 0.34), Vector2(w * 0.3, h * 0.18), Vector2(w * 0.7, h * 0.16), Vector2(w * 0.76, h * 0.32),
		]), dark)
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.24, h * 0.36), Vector2(w * 0.78, h * 0.33), Vector2(w * 0.7, h * 0.4), Vector2(w * 0.3, h * 0.41),
		]), shade.darkened(0.25))
		if plus:
			var green := Color(0.3, 0.85, 0.3)
			var thickness: float = w * 0.14
			draw_rect(Rect2(w * 0.5 - thickness * 0.5, h * 0.3, thickness, h * 0.4), green)
			draw_rect(Rect2(w * 0.25, h * 0.5 - thickness * 0.5, w * 0.5, thickness), green)


## A button of the plate with an icon drawn in the style of the interface (brass lines on a dark plate)
class _ToolButton extends Button:
	var kind: StringName = &""
	var level: int = 0
	var active: bool = false
	var on_right_click: Callable

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE

	func _gui_input(event: InputEvent) -> void:
		var mouse_event := event as InputEventMouseButton
		if mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT and on_right_click.is_valid():
			on_right_click.call()
			accept_event()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var gold := Color(0.85, 0.72, 0.42) if not disabled else Color(0.45, 0.42, 0.38)
		var orange := Color(1.0, 0.55, 0.12) if not disabled else Color(0.5, 0.42, 0.35)
		var back := Color(0.16, 0.15, 0.14) if not is_hovered() else Color(0.24, 0.22, 0.19)
		draw_rect(Rect2(Vector2.ZERO, size), back)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.45, 0.4, 0.3) if not active else Color(0.4, 0.95, 0.4), false, 2.0 if active else 1.0)
		var c := Vector2(w, h) * 0.5
		match kind:
			&"execute":
				# One, two or three chevrons
				var count: int = clampi(level, 1, 3)
				var step: float = w * 0.18
				var start: float = c.x - step * float(count - 1) * 0.5
				for i: int in count:
					var x: float = start + step * float(i)
					draw_polyline(PackedVector2Array([Vector2(x - w * 0.1, h * 0.28), Vector2(x + w * 0.08, h * 0.5), Vector2(x - w * 0.1, h * 0.72)]), Color(0.4, 0.95, 0.4) if active else orange, 3.5)
			&"integrity":
				# Three soldiers in a line, the level as dots under them
				for i: int in 3:
					var x: float = w * (0.27 + 0.23 * float(i))
					draw_circle(Vector2(x, h * 0.3), w * 0.07, orange)
					draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.09, h * 0.62), Vector2(x - w * 0.06, h * 0.4), Vector2(x + w * 0.06, h * 0.4), Vector2(x + w * 0.09, h * 0.62)]), orange)
				for i: int in 3:
					draw_circle(Vector2(w * (0.3 + 0.2 * float(i)), h * 0.8), w * 0.045, gold if i <= level else Color(0.35, 0.33, 0.3))
			&"naval":
				_anchor(Vector2(w * 0.36, h * 0.56), w * 0.22, gold)
				_arrow(Vector2(w * 0.5, h * 0.62), Vector2(w * 0.86, h * 0.22), gold, w)
			&"front":
				_figure(Vector2(w * 0.34, h * 0.5), w, gold)
				_dashes(PackedVector2Array([Vector2(w * 0.12, h * 0.86), Vector2(w * 0.5, h * 0.72), Vector2(w * 0.9, h * 0.84)]), gold, w)
			&"offensive":
				_dashes(PackedVector2Array([Vector2(w * 0.12, h * 0.82), Vector2(w * 0.45, h * 0.6), Vector2(w * 0.78, h * 0.3)]), gold, w)
				for i: int in 2:
					var o := Vector2(w * (0.2 + 0.2 * float(i)), h * (0.42 - 0.12 * float(i)))
					draw_polyline(PackedVector2Array([o + Vector2(-w * 0.06, -h * 0.1), o, o + Vector2(w * 0.1, -h * 0.02)]), orange, 2.5)
				_arrow(Vector2(w * 0.6, h * 0.5), Vector2(w * 0.88, h * 0.18), gold, w)
			&"breakthrough":
				# Three narrow arrows one after another
				for i: int in 3:
					var x: float = w * (0.22 + 0.2 * float(i))
					var colour_i: Color = orange if i == 2 else gold
					draw_line(Vector2(x - w * 0.1, h * 0.78 - h * 0.1 * float(i)), Vector2(x + w * 0.12, h * 0.3 - h * 0.05 * float(i)), colour_i, 2.0)
					_arrow(Vector2(x, h * 0.62 - h * 0.1 * float(i)), Vector2(x + w * 0.14, h * 0.28 - h * 0.05 * float(i)), colour_i, w)
			&"defence":
				_shield(c, w, gold)
				_dashes(PackedVector2Array([Vector2(w * 0.32, h * 0.52), Vector2(w * 0.68, h * 0.52)]), gold, w)
			&"coast":
				_shield(c, w, gold)
				draw_line(Vector2(w * 0.44, h * 0.68), Vector2(w * 0.44, h * 0.3), gold, 2.0)
				draw_colored_polygon(PackedVector2Array([Vector2(w * 0.44, h * 0.3), Vector2(w * 0.66, h * 0.37), Vector2(w * 0.44, h * 0.45)]), orange)
			&"edit":
				_dashes(PackedVector2Array([Vector2(w * 0.15, h * 0.75), Vector2(w * 0.4, h * 0.35), Vector2(w * 0.65, h * 0.62), Vector2(w * 0.85, h * 0.3)]), gold, w)
				for point: Vector2 in [Vector2(w * 0.4, h * 0.35), Vector2(w * 0.65, h * 0.62)]:
					draw_rect(Rect2(point - Vector2(w, w) * 0.06, Vector2(w, w) * 0.12), orange)
			&"delete":
				draw_rect(Rect2(w * 0.3, h * 0.32, w * 0.4, h * 0.5), gold, false, 2.0)
				draw_line(Vector2(w * 0.24, h * 0.28), Vector2(w * 0.76, h * 0.28), gold, 2.5)
				draw_rect(Rect2(w * 0.42, h * 0.2, w * 0.16, h * 0.08), gold, false, 1.5)
				for i: int in 3:
					var x: float = w * (0.39 + 0.11 * float(i))
					draw_line(Vector2(x, h * 0.4), Vector2(x, h * 0.74), gold, 1.5)

	func _dashes(points: PackedVector2Array, colour: Color, w: float) -> void:
		for i: int in range(1, points.size()):
			draw_dashed_line(points[i - 1], points[i], colour, 2.0, w * 0.08)

	func _arrow(from: Vector2, to: Vector2, colour: Color, w: float) -> void:
		draw_line(from, to, colour, 2.0)
		var direction: Vector2 = (to - from).normalized()
		var side := Vector2(-direction.y, direction.x)
		draw_colored_polygon(PackedVector2Array([to, to - direction * w * 0.16 + side * w * 0.08, to - direction * w * 0.16 - side * w * 0.08]), colour)

	func _figure(at: Vector2, w: float, colour: Color) -> void:
		draw_circle(at + Vector2(0.0, -w * 0.2), w * 0.09, colour)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-w * 0.13, w * 0.12), at + Vector2(-w * 0.08, -w * 0.08), at + Vector2(w * 0.08, -w * 0.08), at + Vector2(w * 0.13, w * 0.12)]), colour)

	func _shield(c: Vector2, w: float, colour: Color) -> void:
		draw_polyline(PackedVector2Array([
			c + Vector2(-w * 0.26, -w * 0.28), c + Vector2(w * 0.26, -w * 0.28), c + Vector2(w * 0.24, w * 0.06),
			c + Vector2(0.0, w * 0.32), c + Vector2(-w * 0.24, w * 0.06), c + Vector2(-w * 0.26, -w * 0.28),
		]), colour, 2.0)

	func _anchor(c: Vector2, r: float, colour: Color) -> void:
		draw_line(c + Vector2(0.0, -r), c + Vector2(0.0, r), colour, 2.0)
		draw_line(c + Vector2(-r * 0.5, -r * 0.55), c + Vector2(r * 0.5, -r * 0.55), colour, 2.0)
		draw_arc(c + Vector2(0.0, r * 0.2), r * 0.8, 0.3, PI - 0.3, 12, colour, 2.0)
		draw_circle(c + Vector2(0.0, -r * 1.15), r * 0.2, colour)


func setup(unit_banners: Node, theatre_panel: Node, plan_tools: Node) -> void:
	_unit_banners = unit_banners
	_theatre_panel = theatre_panel
	_plan_tools = plan_tools
	if _theatre_panel != null:
		_theatre_panel.theatre_selected.connect(_on_theatre_selected)
	if _plan_tools != null:
		_plan_tools.tool_changed.connect(func(_tool: int) -> void:
			_rebuild_plate()
			_update_passive_tool.call_deferred()
		)
		_plan_tools.cancelled.connect(func() -> void: _select_group(0))


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
	add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 4)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	# The plate stands over the selected marshal: its holder is as high as it, the plate is moved over the middle of his cards
	_plate_holder = Control.new()
	_plate_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_plate_holder)
	_plate = PanelContainer.new()
	_plate.add_theme_stylebox_override(&"panel", _panel_style(Color(0.07, 0.07, 0.08, 0.95)))
	_plate_holder.add_child(_plate)
	_row_panel = PanelContainer.new()
	_row_panel.add_theme_stylebox_override(&"panel", _panel_style(Color(0.06, 0.07, 0.08, 0.82)))
	_row_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(_row_panel)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", 14)
	_row_panel.add_child(_row)
	_plate.visible = false
	GameSingleton.gamestate_updated.connect(_refresh)
	_refresh()


func _panel_style(colour: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_border_width_all(2)
	style.border_color = Color(0.55, 0.42, 0.2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _process(_delta: float) -> void:
	# The plate over the middle of the cards of the selected marshal (the marshal and his generals)
	if not _plate.visible or _selected_block == null or not is_instance_valid(_selected_block):
		return
	var centre_x: float = _selected_block.get_global_rect().get_center().x - _plate_holder.global_position.x
	var plate_width: float = _plate.get_combined_minimum_size().x
	_plate.size = _plate.get_combined_minimum_size()
	var x: float = centre_x - plate_width * 0.5
	var viewport_width: float = get_viewport_rect().size.x
	x = clampf(x, 8.0 - _plate_holder.global_position.x, viewport_width - 8.0 - plate_width - _plate_holder.global_position.x)
	_plate.position = Vector2(x, 0.0)


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


func _group_by_id(group_id: int) -> Dictionary:
	for group: Dictionary in PlayerSingleton.get_army_groups():
		if int(group[&"id"]) == group_id:
			return group
	return {}


## Another window of the interface is open: the panel is hidden until it is closed
func set_suppressed(suppressed: bool) -> void:
	_suppressed = suppressed
	visible = _wanted and not _suppressed
	if _suppressed and _plan_tools != null:
		_plan_tools.stop()
	elif not _suppressed:
		_update_passive_tool()


func _refresh() -> void:
	if not PlayerSingleton.has_army_command():
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
	var signature: String = str(_active_theatre) + str(groups) + str(theatres.size()) + str(_selected_group)
	for general: Dictionary in generals:
		signature += "%d:%d:%d;" % [int(general[&"leader_id"]), int(general[&"army_id"]), int(general[&"command_group_id"])]
	if signature == _signature:
		return
	_signature = signature
	_wanted = true
	visible = not _suppressed
	if _selected_group != 0 and _group_by_id(_selected_group).is_empty():
		_select_group(0)
	for child: Node in _row.get_children():
		child.queue_free()
	_selected_block = null
	_row.add_child(_make_new_marshal_slot(groups))
	for group: Dictionary in groups:
		if int(group[&"theatre_id"]) == _active_theatre or _active_theatre == 0:
			_row.add_child(_make_group(group, generals, theatres))
	_rebuild_plate()
	_update_passive_tool()


## A selected field marshal without an order shows where a front can be made: the borders of the neighbours, a right click on one makes it
func _update_passive_tool() -> void:
	if _plan_tools == null:
		return
	var group: Dictionary = _group_by_id(_selected_group) if _selected_group != 0 else {}
	var without_order: bool = not group.is_empty() and (group[&"front_ids"] as PackedInt32Array).is_empty()
	if without_order:
		for line: Dictionary in PlayerSingleton.get_plan_lines():
			if int(line[&"group_id"]) == _selected_group:
				without_order = false
				break
	# Without an order the borders of the neighbours (a right click makes the front), with one the circles at its ends (dragged to edit it)
	var wanted_tool: int = 0 if group.is_empty() else (1 if without_order else 7)
	if wanted_tool != 0 and visible and (not _plan_tools.is_active() or (_plan_tools.passive and int(_plan_tools.tool) != wanted_tool)):
		_plan_tools.start(wanted_tool, _selected_group, true)
	elif wanted_tool == 0 and _plan_tools.is_active() and _plan_tools.passive:
		_plan_tools.stop()


func _make_card(general: Dictionary, card_size: Vector2, colour: Color, fallback: String, glow: bool, plus: bool = false) -> _Card:
	var card := _Card.new()
	card.custom_minimum_size = card_size + Vector2(8.0, 8.0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(colour.r, colour.g, colour.b, 0.6 if glow else 0.0)
	glow_style.set_corner_radius_all(6)
	glow_style.shadow_color = Color(colour.r, colour.g, colour.b, 0.6 if glow else 0.0)
	glow_style.shadow_size = 6 if glow else 0
	card.add_theme_stylebox_override(&"panel", glow_style)
	var frame := Panel.new()
	frame.position = Vector2(4.0, 4.0)
	frame.size = card_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.14, 0.15, 0.17)
	frame_style.set_border_width_all(2)
	frame_style.border_color = _GOLD if glow else Color(0.42, 0.4, 0.36)
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
	else:
		var silhouette := _Silhouette.new()
		silhouette.plus = plus
		silhouette.position = Vector2(2.0, 2.0)
		silhouette.size = card_size - Vector2(4.0, 4.0)
		silhouette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(silhouette)
	card.tooltip_text = str(general.get(&"leader_name", fallback))
	# The levels of the skills of his role (docs/WAR_ASSUMPTIONS.md, section 7): a gold badge in the corner of the portrait
	var levels: int = int(general.get(&"skill_levels", 0))
	if levels > 0:
		var badge := PanelContainer.new()
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(0.16, 0.13, 0.07, 0.95)
		badge_style.set_border_width_all(1)
		badge_style.border_color = _GOLD
		badge_style.set_corner_radius_all(7)
		badge_style.content_margin_left = 4.0
		badge_style.content_margin_right = 4.0
		badge.add_theme_stylebox_override(&"panel", badge_style)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.position = Vector2(2.0, card_size.y - 14.0)
		var badge_label := Label.new()
		badge_label.text = str(levels)
		badge_label.add_theme_font_size_override(&"font_size", 10)
		badge_label.add_theme_color_override(&"font_color", Color(1.0, 0.86, 0.45))
		badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(badge_label)
		card.add_child(badge)
	return card


## The name of a skill (a terrain: its name)
func _skill_name(skill: Dictionary) -> String:
	var id: String = str(skill[&"id"])
	if bool(skill[&"terrain"]):
		return _t("LEADER_SKILL_TERRAIN").replace("$T$", _t("LEADER_TERRAIN_" + id))
	return _t("LEADER_SKILL_" + id)


## The skills of a leader in a tooltip: the ones of his role with the levels and the experience, the ones of the other role (they do not work now)
func _skills_text(general: Dictionary) -> String:
	var skills: Array = general.get(&"skills", [])
	if skills.is_empty():
		return ""
	var lines: PackedStringArray = []
	var marshal_now: bool = bool(general.get(&"is_marshal", false))
	for active: bool in [true, false]:
		var header_added: bool = false
		for skill: Dictionary in skills:
			if bool(skill[&"active"]) != active:
				continue
			if not header_added:
				header_added = true
				var marshal_skills: bool = bool(skill[&"marshal"])
				var header: String = _t("LEADER_SKILLS_MARSHAL" if marshal_skills else "LEADER_SKILLS_GENERAL")
				if not active:
					header += " " + _t("LEADER_SKILLS_INACTIVE")
				lines.append(header)
			var line: String
			if float(skill[&"next"]) > 0.0:
				line = _t("LEADER_SKILL_LINE").replace("$XP$", str(snappedf(float(skill[&"experience"]), 0.1))).replace("$NEXT$", str(int(skill[&"next"])))
			else:
				line = _t("LEADER_SKILL_LINE_TOP")
			lines.append("  " + line.replace("$NAME$", _skill_name(skill)).replace("$L$", str(int(skill[&"level"]))).replace("$MAX$", str(int(skill[&"max"]))))
	if marshal_now and lines.is_empty():
		return ""
	return "\n".join(lines)


## A short line of the levels for the menus: the skills of a role that have a level (none: empty)
func _skills_short(general: Dictionary, marshal_role: bool) -> String:
	var parts: PackedStringArray = []
	for skill: Dictionary in general.get(&"skills", []):
		if bool(skill[&"marshal"]) == marshal_role and int(skill[&"level"]) > 0:
			parts.append("%s %d" % [_skill_name(skill), int(skill[&"level"])])
	return ", ".join(parts)


## The number plate under a card (a laurel of dots on the sides of the marshal's)
func _number_plate(text: String, tooltip: String, laurel: bool) -> Control:
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.13)
	style.set_border_width_all(1)
	style.border_color = _GOLD if laurel else Color(0.45, 0.42, 0.36)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10.0 if laurel else 6.0
	style.content_margin_right = 10.0 if laurel else 6.0
	plate.add_theme_stylebox_override(&"panel", style)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.tooltip_text = tooltip
	var label := Label.new()
	label.text = ("❦ %s ❦" % text) if laurel else text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 12)
	label.add_theme_color_override(&"font_color", Color(0.95, 0.92, 0.85))
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(label)
	return plate


func _make_group(group: Dictionary, generals: Array, theatres: Array) -> Control:
	var group_id: int = int(group[&"id"])
	var colour: Color = group[&"colour"]
	var marshal_id: int = int(group[&"marshal_id"])
	var army_ids: Array = group[&"army_ids"]
	# The armies of the generals (the divisions split from them along the line are counted under them)
	var group_generals: Array = group[&"generals"]
	var max_attached: int = int(group[&"max_attached"])
	var selected: bool = group_id == _selected_group
	var block := HBoxContainer.new()
	block.add_theme_constant_override(&"separation", 4)
	# The marshal and his generals: the plate stands over the middle of them
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override(&"separation", 4)
	block.add_child(cards)
	if selected:
		_selected_block = cards

	var marshal_box := VBoxContainer.new()
	marshal_box.add_theme_constant_override(&"separation", 2)
	cards.add_child(marshal_box)
	var marshal: Dictionary = _general_by_id(generals, marshal_id)
	var marshal_card: _Card = _make_card(marshal, _BIG, colour, _t("CMD_NO_MARSHAL"), true)
	if selected:
		var selected_style: StyleBoxFlat = marshal_card.get_theme_stylebox(&"panel").duplicate()
		selected_style.bg_color = Color(1.0, 0.85, 0.4, 0.9)
		selected_style.shadow_color = Color(1.0, 0.85, 0.4, 0.7)
		marshal_card.add_theme_stylebox_override(&"panel", selected_style)
	marshal_card.accepts_generals = true
	marshal_card.on_drop = func(data: Dictionary) -> void:
		if int(data.get(&"army_id", 0)) != 0 and int(data.get(&"group_id", 0)) != group_id:
			PlayerSingleton.set_army_group(int(data[&"army_id"]), group_id)
	if marshal_id != 0:
		marshal_card.drag_data = { &"type": "ov_marshal", &"group_id": group_id, &"caption": str(marshal.get(&"leader_name", "")) }
		marshal_card.on_click = func() -> void:
			_select_group(group_id)
			if _unit_banners != null:
				_unit_banners.select_armies(army_ids)
		var marshal_skills: String = _skills_text(marshal)
		marshal_card.tooltip_text = "%s\n%s%s" % [str(marshal.get(&"leader_name", "")), (marshal_skills + "\n") if marshal_skills != "" else "", _t("CMD_MARSHAL_TOOLTIP")]
	else:
		marshal_card.on_click = func() -> void:
			_select_group(group_id)
			_show_free_generals_menu(group_id, true)
		marshal_card.tooltip_text = _t("CMD_NO_MARSHAL")
	marshal_card.on_context = _on_card_context.bind(group_id, int(group[&"theatre_id"]), theatres, int(group[&"colour_index"]))
	marshal_box.add_child(marshal_card)
	marshal_box.add_child(_number_plate(str(group_generals.size()), _t("CMD_ATTACHED_TOOLTIP").replace("$N$", str(group_generals.size())).replace("$MAX$", str(max_attached)), true))

	# The generals of the armies of the group, to the right of him
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 3)
	flow.add_theme_constant_override(&"v_separation", 3)
	flow.custom_minimum_size = Vector2(minf(float(group_generals.size()), float(_GENERALS_PER_ROW)) * (_SMALL.x + 11.0), 0.0)
	cards.add_child(flow)
	for general_entry: Dictionary in group_generals:
		var army_id: int = int(general_entry[&"army_id"])
		var details: Dictionary = PlayerSingleton.get_army_details(army_id)
		var general: Dictionary = _general_of_army(generals, army_id)
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override(&"separation", 2)
		var card: _Card = _make_card(general, _SMALL, colour, str(details.get(&"name", "?")), true)
		card.drag_data = { &"type": "ov_general", &"army_id": army_id, &"group_id": group_id, &"caption": str(general.get(&"leader_name", details.get(&"name", ""))) }
		card.tooltip_text = "%s\n%s" % [str(general.get(&"leader_name", _t("CMD_NO_GENERAL"))), str(details.get(&"name", ""))]
		var general_skills: String = _skills_text(general)
		if general_skills != "":
			card.tooltip_text += "\n" + general_skills
		var general_army_ids: Array = general_entry[&"army_ids"]
		card.on_click = func() -> void:
			if _unit_banners != null:
				_unit_banners.select_armies(general_army_ids)
		card.on_context = _attach_selected_to_group.bind(group_id)
		# The cross in the corner detaches the general
		var detach := Button.new()
		detach.text = "×"
		detach.flat = true
		detach.focus_mode = Control.FOCUS_NONE
		detach.position = Vector2(_SMALL.x - 12.0, 0.0)
		detach.size = Vector2(16.0, 16.0)
		detach.add_theme_font_size_override(&"font_size", 13)
		detach.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.75))
		detach.tooltip_text = _t("CMD_DETACH").replace("$NAME$", str(details.get(&"name", "?")))
		detach.pressed.connect(func() -> void: PlayerSingleton.set_army_group(army_id, 0))
		card.add_child(detach)
		slot.add_child(card)
		slot.add_child(_number_plate(str(int(general_entry[&"divisions"])), _t("CMD_DIVISIONS_TOOLTIP"), false))
		flow.add_child(slot)
	# One more general
	if group_generals.size() < max_attached:
		var plus_box := VBoxContainer.new()
		var plus := _make_card({}, _SMALL, _GREY, _t("CMD_ADD_GENERAL"), false, true)
		plus.on_click = _show_free_generals_menu.bind(group_id, false)
		plus.on_context = _attach_selected_to_group.bind(group_id)
		plus.tooltip_text = _t("CMD_ADD_GENERAL")
		plus_box.add_child(plus)
		block.add_child(plus_box)
	return block


## The empty slot of a new field marshal: a new group of armies in the shown theatre
func _make_new_marshal_slot(groups: Array) -> Control:
	var box := VBoxContainer.new()
	var card := _make_card({}, _BIG, _GREY, _t("CMD_NEW_MARSHAL"), false, true)
	card.tooltip_text = _t("CMD_NEW_MARSHAL")
	card.on_click = func() -> void:
		_known_group_ids.clear()
		for group: Dictionary in groups:
			_known_group_ids[int(group[&"id"])] = true
		_waiting_for_group = true
		PlayerSingleton.create_army_group()
	box.add_child(card)
	return box


func _select_group(group_id: int) -> void:
	if group_id == _selected_group:
		return
	_selected_group = group_id
	if _plan_tools != null:
		_plan_tools.stop()
	_signature = ""
	_refresh()


## The plate of the plans of the selected field marshal
func _rebuild_plate() -> void:
	for child: Node in _plate.get_children():
		child.queue_free()
	var group: Dictionary = _group_by_id(_selected_group) if _selected_group != 0 else {}
	_plate.visible = not group.is_empty()
	if group.is_empty():
		_plate_holder.custom_minimum_size = Vector2.ZERO
		return
	var group_id: int = int(group[&"id"])
	var tool: int = _plan_tools.tool if _plan_tools != null and int(_plan_tools.group_id) == group_id and not _plan_tools.passive else 0
	var has_front: bool = not (group[&"front_ids"] as PackedInt32Array).is_empty()
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	_plate.add_child(box)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override(&"separation", 12)
	box.add_child(title_row)
	var title := Label.new()
	title.text = _t("PLAN_PLATE_TITLE")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override(&"font_size", 14)
	title.add_theme_color_override(&"font_color", Color(0.95, 0.9, 0.75))
	title_row.add_child(title)
	# The bonus of the planning (it grows while the order waits)
	var planning := Label.new()
	planning.text = _t("PLAN_PLANNING").replace("$P$", str(roundi(float(group[&"planning"]) * 100.0)))
	planning.tooltip_text = _t("PLAN_PLANNING_TOOLTIP").replace("$MAX$", str(roundi(float(group[&"planning_max"]) * 100.0)))
	planning.mouse_filter = Control.MOUSE_FILTER_PASS
	planning.add_theme_font_size_override(&"font_size", 13)
	planning.add_theme_color_override(&"font_color", Color(0.55, 0.9, 0.5) if float(group[&"planning"]) > 0.0 else Color(0.6, 0.6, 0.6))
	title_row.add_child(planning)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 3)
	box.add_child(buttons)

	var aggression: int = int(group[&"aggression"])
	var integrity: int = int(group[&"integrity"])
	var running: bool = bool(group[&"plan_active"])
	var execute := _tool_button(&"execute", _t("PLAN_EXECUTE_TOOLTIP").replace("$MODE$", _t("PLAN_AGGRESSION_%d" % aggression)), running)
	execute.level = aggression
	# The execution needs a front (the offensive, the breakthrough) or a naval invasion, and the field marshal
	var has_landing: bool = false
	for line: Dictionary in PlayerSingleton.get_plan_lines():
		has_landing = has_landing or (int(line[&"group_id"]) == group_id and int(line[&"type"]) == 2)
	execute.disabled = not (has_front or has_landing) or int(group[&"marshal_id"]) == 0
	execute.pressed.connect(func() -> void: PlayerSingleton.set_army_group_plan_active(group_id, not running))
	execute.on_right_click = func() -> void: PlayerSingleton.set_army_group_modes(group_id, aggression % 3 + 1, integrity)
	buttons.add_child(execute)
	var integrity_button := _tool_button(&"integrity", _t("PLAN_INTEGRITY_TOOLTIP").replace("$MODE$", _t("PLAN_INTEGRITY_%d" % integrity)), false)
	integrity_button.level = integrity
	integrity_button.pressed.connect(func() -> void: PlayerSingleton.set_army_group_modes(group_id, aggression, (integrity + 1) % 3))
	buttons.add_child(integrity_button)
	buttons.add_child(_gap())
	var naval := _tool_button(&"naval", _t("PLAN_TOOL_NAVAL"), tool == 5)
	naval.pressed.connect(_start_tool.bind(5, group_id))
	buttons.add_child(naval)
	buttons.add_child(_gap())
	var front := _tool_button(&"front", _t("PLAN_TOOL_FRONT"), tool == 1)
	front.pressed.connect(_start_tool.bind(1, group_id))
	buttons.add_child(front)
	var offensive := _tool_button(&"offensive", _t("PLAN_TOOL_OFFENSIVE") if has_front else _t("PLAN_TOOL_OFFENSIVE_NO_FRONT"), tool == 2)
	offensive.disabled = not has_front
	offensive.pressed.connect(_start_tool.bind(2, group_id))
	buttons.add_child(offensive)
	var breakthrough := _tool_button(&"breakthrough", _t("PLAN_TOOL_BREAKTHROUGH") if has_front else _t("PLAN_TOOL_OFFENSIVE_NO_FRONT"), tool == 8)
	breakthrough.disabled = not has_front
	breakthrough.pressed.connect(_start_tool.bind(8, group_id))
	buttons.add_child(breakthrough)
	buttons.add_child(_gap())
	var defence := _tool_button(&"defence", _t("PLAN_TOOL_DEFENCE"), tool == 3)
	defence.pressed.connect(_start_tool.bind(3, group_id))
	buttons.add_child(defence)
	var coast := _tool_button(&"coast", _t("PLAN_TOOL_COAST"), tool == 4)
	coast.pressed.connect(_start_tool.bind(4, group_id))
	buttons.add_child(coast)
	buttons.add_child(_gap())
	var edit := _tool_button(&"edit", _t("PLAN_TOOL_EDIT"), tool == 6)
	edit.pressed.connect(_start_tool.bind(6, group_id))
	buttons.add_child(edit)
	var delete := _tool_button(&"delete", _t("PLAN_TOOL_DELETE"), false)
	delete.pressed.connect(func() -> void:
		if _plan_tools != null:
			_plan_tools.stop()
		PlayerSingleton.delete_group_lines(group_id)
	)
	buttons.add_child(delete)
	_plate_holder.custom_minimum_size = Vector2(0.0, _plate.get_combined_minimum_size().y + 2.0)


func _tool_button(kind: StringName, tooltip: String, active: bool) -> _ToolButton:
	var button := _ToolButton.new()
	button.kind = kind
	button.active = active
	button.custom_minimum_size = _BUTTON
	button.tooltip_text = tooltip
	button.flat = true
	button.mouse_entered.connect(button.queue_redraw)
	button.mouse_exited.connect(button.queue_redraw)
	return button


func _gap() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8.0, 0.0)
	return gap


func _start_tool(tool: int, group_id: int) -> void:
	if _plan_tools != null:
		_plan_tools.start(tool, group_id)


## A right click on a card of a marshal: the divisions that are selected on the map are attached to him, with none selected the menu opens
func _on_card_context(group_id: int, current_theatre: int, theatres: Array, colour_index: int) -> void:
	if _attach_selected_to_group(group_id):
		return
	_show_marshal_menu(group_id, current_theatre, theatres, colour_index)


## Attaches the armies selected on the map (those not in the command yet) to it; false if there is none to attach
func _attach_selected_to_group(group_id: int) -> bool:
	if _unit_banners == null:
		return false
	var to_attach: Array[int] = []
	for army_id: int in _unit_banners.get_selected_armies():
		var details: Dictionary = PlayerSingleton.get_army_details(army_id)
		if details.is_empty() or bool(details.get(&"is_navy", false)) or not bool(details.get(&"is_player", false)):
			continue # a fleet or an army of another country is not attached
		# Another group, none, or his own division sent by hand (it goes back to his orders)
		if int(details.get(&"army_group_id", 0)) != group_id or bool(details.get(&"manual_order", false)):
			to_attach.append(army_id)
	if to_attach.is_empty():
		return false # nothing selected, or only his own divisions on his orders: the menu of the marshal opens
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
		# The levels he would use in the slot: of a marshal for the marshal, of a general for an army
		var short: String = _skills_short(general, marshal_slot)
		if short != "":
			caption += " — " + short
		menu.add_item(caption, index)
	menu.id_pressed.connect(func(id: int) -> void:
		var chosen: Dictionary = entries[id]
		if marshal_slot:
			PlayerSingleton.set_army_group_marshal(group_id, int(chosen[&"leader_id"]))
		else:
			PlayerSingleton.set_army_group(int(chosen[&"army_id"]), group_id)
	)
	_popup_at_mouse(menu)


## The menu of a field marshal: the colour, to another theatre, take the marshal off, delete the command
func _show_marshal_menu(group_id: int, current_theatre: int, theatres: Array, colour_index: int) -> void:
	var menu := _new_menu()
	menu.add_item(_t("CMD_COLOUR"), _MENU_COLOUR)
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
		if id == _MENU_COLOUR:
			_show_colour_popup.call_deferred(group_id, colour_index)
		elif id == _MENU_REMOVE:
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
