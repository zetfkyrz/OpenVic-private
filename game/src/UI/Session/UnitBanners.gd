extends Control

# Icons over the armies on the map, built from the original mapicons.gui templates: unit_mapicon (flag, number of
# regiments, organisation), combat_mapicon (both sides of a battle) and siege_mapicon (progress of a siege).
# The icons of the player's armies can be selected by clicking on them, a right click on a province of the map then
# orders the selected armies to go there. The icons are hidden when the map is zoomed out.

const _GUI_FILE: String = "mapicons"

# Position of the middle of the icon's panel relative to the origin of the window, so that the panel is centred
# above the army (the panels of the original templates start at a negative offset)
const _UNIT_ANCHOR: Vector2 = Vector2(17, 40)
const _COMBAT_ANCHOR: Vector2 = Vector2(57, 36)
const _SIEGE_ANCHOR: Vector2 = Vector2(26, 38)
# Distance above the army in canvas units, and between the icons of a province
const _LIFT: float = 10.0
const _SLOT_SPACING: float = 54.0
const _SIEGE_DROP: float = 22.0

# The icons are hidden when the camera is higher than this many times the height of the parchment view
const _HIDE_ABOVE_PARCHMENT_FACTOR: float = 0.9
const _MIN_SCALE: float = 0.55
const _MAX_SCALE: float = 1.0

const _SELECTED_MODULATE: Color = Color(1.5, 1.35, 0.6)
const _ENEMY_FRAME: int = 3

var _map_view: MapView
# key -> { panel: Panel, anchor: Vector2, position: Vector2, slot: int, slot_count: int, drop: float, ids: Array, ... }
var _icons: Dictionary[String, Dictionary] = {}
# Selected icons of the player's armies
var _selected_keys: Dictionary[String, bool] = {}

# Selection box (left mouse button held and dragged over the map)
const _BOX_DRAG_THRESHOLD: float = 6.0
const _BOX_FILL: Color = Color(0.3, 0.7, 1.0, 0.18)
const _BOX_BORDER: Color = Color(0.5, 0.85, 1.0, 0.9)
var _box: Control
# Layer the paths of moving armies are drawn on, below the icons
var _paths_layer: Control

const _PATH_COLOUR: Color = Color(0.95, 0.95, 0.85, 0.8)
const _PATH_COLOUR_SELECTED: Color = Color(1.0, 0.9, 0.2, 0.95)
const _PATH_WIDTH: float = 2.5
const _PATH_DASH: float = 7.0
const _ARROW_SIZE: float = 9.0
var _mouse_pressed: bool = false
var _drag_active: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_current: Vector2 = Vector2.ZERO


func setup(map_view: MapView) -> void:
	_map_view = map_view


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_paths_layer = Control.new()
	_paths_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paths_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paths_layer.draw.connect(_draw_paths)
	add_child(_paths_layer)

	# Rectangle drawn while selecting with the mouse
	_box = Control.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.draw.connect(_draw_box)
	add_child(_box)

	GameSingleton.gamestate_updated.connect(_refresh)
	_refresh()


func has_selection() -> bool:
	for key: String in _selected_keys:
		if _icons.has(key) and _icons[key].get(&"is_player", false):
			return true
	return false


func clear_selection() -> void:
	if _selected_keys.is_empty():
		return
	var previous: Array = _selected_keys.keys()
	_selected_keys.clear()
	for key: String in previous:
		_update_selection_visual(key)


# Orders every army of the selected icons to go to the province
func order_move(province_number: int) -> void:
	var ordered: int = 0
	for key: String in _selected_keys:
		if not _icons.has(key) or not _icons[key].get(&"is_player", false):
			continue
		for army_id: int in _icons[key][&"army_ids"]:
			if PlayerSingleton.move_army(army_id, province_number):
				ordered += 1

	if ordered == 0:
		push_warning("The armies cannot move to province %d" % province_number)
	else:
		SoundManager.play_effect_compat("army_move")


func _process(_delta: float) -> void:
	if not _map_view or _icons.is_empty():
		return

	_paths_layer.queue_redraw()

	var camera: Camera3D = _map_view._camera
	var zoomed_out: bool = camera.position.y > _map_view._zoom_parchment_threshold * _HIDE_ABOVE_PARCHMENT_FACTOR

	# Icons shrink a bit when zooming out
	var icon_scale: float = clampf(
		_map_view._zoom_parchment_threshold * 1.2 / maxf(camera.position.y, 0.001), _MIN_SCALE, _MAX_SCALE
	)

	for icon: Dictionary in _icons.values():
		var panel: Panel = icon[&"panel"]

		if zoomed_out:
			panel.hide()
			continue

		# The same position as the unit's model, the icon is then lifted by a few pixels above it
		var world_position: Vector3 = _map_view._map_to_world_coords(icon[&"position"])
		if camera.is_position_behind(world_position):
			panel.hide()
			continue

		# The projected position is already in the coordinates of the (scaled) viewport that the controls use
		var canvas_position: Vector2 = camera.unproject_position(world_position)
		var anchor: Vector2 = icon[&"anchor"]
		var slot_shift: float = (icon[&"slot"] - (icon[&"slot_count"] - 1) / 2.0) * _SLOT_SPACING * icon_scale

		panel.pivot_offset = anchor
		panel.scale = Vector2(icon_scale, icon_scale)
		panel.position = canvas_position + Vector2(slot_shift, -_LIFT * icon_scale + icon[&"drop"] * icon_scale) - anchor
		panel.show()


func _refresh() -> void:
	var units: Array = PlayerSingleton.get_map_units()

	# Group by province
	var by_province: Dictionary[int, Array] = {}
	for unit: Dictionary in units:
		var province_number: int = unit[&"province_number"]
		if not by_province.has(province_number):
			by_province[province_number] = []
		by_province[province_number].append(unit)

	var present: Dictionary[String, bool] = {}

	for province_number: int in by_province:
		var group: Array = by_province[province_number]

		var in_combat: bool = false
		for unit: Dictionary in group:
			in_combat = in_combat or unit[&"in_combat"]

		# A battle is one icon with both sides
		if in_combat and group.size() >= 2:
			var key: String = "p%d_combat" % province_number
			present[key] = true
			_update_combat_icon(key, group[0], group[1])
			continue

		for slot: int in group.size():
			var unit: Dictionary = group[slot]
			var key: String = "p%d_c%d" % [province_number, unit[&"country_index"]]
			present[key] = true
			_update_unit_icon(key, unit, slot, group.size())

			if unit[&"siege_progress"] >= 0.0:
				var siege_key: String = key + "_siege"
				present[siege_key] = true
				_update_siege_icon(siege_key, unit, slot, group.size())

	for key: String in _icons.keys():
		if not present.has(key):
			_remove_icon(key)


func _remove_icon(key: String) -> void:
	var icon: Dictionary = _icons[key]
	_icons.erase(key)
	_selected_keys.erase(key)
	var panel: Panel = icon[&"panel"]
	if is_instance_valid(panel):
		remove_child(panel)
		panel.free()


func _get_or_create(key: String, template: String, anchor: Vector2) -> Dictionary:
	var icon: Dictionary = _icons.get(key, {})
	if not icon.is_empty():
		return icon

	var panel: Panel = GUINode.generate_gui_element(_GUI_FILE, template)
	if not panel:
		return {}

	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(panel)

	icon = { &"panel": panel, &"anchor": anchor, &"slot": 0, &"slot_count": 1, &"drop": 0.0, &"army_ids": [] }
	_icons[key] = icon
	return icon


func _set_text(panel: Node, path: NodePath, text: String) -> void:
	var label: GUILabel = GUINode.get_gui_label_from_node_and_path(panel, path)
	if label:
		label.set_auto_translate(false)
		label.set_text(text)


func _set_bar(panel: Node, path: NodePath, value: float) -> void:
	var bar: GUIProgressBar = GUINode.get_gui_progress_bar_from_node_and_path(panel, path)
	if bar:
		bar.max_value = 1.0
		bar.step = 0.01
		bar.value = value


func _set_flag(panel: Node, path: NodePath, country_identifier: String) -> void:
	var flag: GUIMaskedFlagButton = GUINode.get_gui_masked_flag_button_from_node_and_path(panel, path)
	if flag:
		flag.set_flag_country_name(country_identifier)
		flag.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _describe(unit: Dictionary) -> String:
	var lines: PackedStringArray = [
		"%s: %d, %s: %d" % [tr("Armies"), unit[&"army_count"], tr("Regiments"), unit[&"regiments"]],
		"%s: %d%%" % [tr("Strength"), roundi(float(unit[&"strength"]) * 100.0)],
		"%s: %d%%" % [tr("Organisation"), roundi(float(unit[&"organisation"]) * 100.0)],
	]
	if unit[&"in_combat"]:
		lines.append(tr("In battle"))
	elif unit[&"moving"]:
		lines.append(tr("Marching"))
	if unit[&"siege_progress"] >= 0.0:
		lines.append("%s: %d%%" % [tr("Siege"), roundi(float(unit[&"siege_progress"]) * 100.0)])
	if unit[&"is_player"]:
		lines.append(tr("Click to select, then right click a province to move"))
	return "\n".join(lines)


func _update_unit_icon(key: String, unit: Dictionary, slot: int, slot_count: int) -> void:
	var icon: Dictionary = _get_or_create(key, "unit_mapicon", _UNIT_ANCHOR)
	if icon.is_empty():
		return

	var panel: Panel = icon[&"panel"]
	icon[&"position"] = unit[&"position"]
	icon[&"slot"] = slot
	icon[&"slot_count"] = slot_count
	icon[&"drop"] = 0.0
	icon[&"army_ids"] = unit[&"army_ids"]
	icon[&"is_player"] = unit[&"is_player"]
	icon[&"paths"] = unit[&"paths"]

	_set_text(panel, ^"./unit_strength", str(unit[&"regiments"]))
	_set_bar(panel, ^"./unit_panel_org_bar", unit[&"organisation"])
	_set_flag(panel, ^"./unit_panel_country_flag", unit[&"country_identifier"])

	var colour: GUIIcon = GUINode.get_gui_icon_from_node_and_path(panel, ^"./unit_panel_color")
	if colour:
		colour.set_icon_index(1 if unit[&"is_player"] else _ENEMY_FRAME)

	var background: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(panel, ^"./unit_panel_bg")
	if background:
		background.tooltip_string = _describe(unit)
		if not panel.has_meta(&"connected"):
			panel.set_meta(&"connected", true)
			background.pressed.connect(_on_icon_pressed.bind(key))

	# Armies that are moving or fighting show the attrition icon slot only when needed
	var attr: Node = panel.get_node_or_null(^"./unit_panel_attr")
	if attr is CanvasItem:
		attr.visible = false

	_update_selection_visual(key)


func _update_combat_icon(key: String, left: Dictionary, right: Dictionary) -> void:
	var icon: Dictionary = _get_or_create(key, "combat_mapicon", _COMBAT_ANCHOR)
	if icon.is_empty():
		return

	var panel: Panel = icon[&"panel"]
	icon[&"position"] = left[&"position"]
	icon[&"slot"] = 0
	icon[&"slot_count"] = 1
	icon[&"drop"] = 0.0
	icon[&"army_ids"] = []
	icon[&"is_player"] = false
	icon[&"paths"] = []

	_set_text(panel, ^"./unit_strengthL", str(left[&"regiments"]))
	_set_text(panel, ^"./unit_strengthR", str(right[&"regiments"]))
	_set_bar(panel, ^"./unit_panel_org_barL", left[&"organisation"])
	_set_bar(panel, ^"./unit_panel_org_barR", right[&"organisation"])
	_set_flag(panel, ^"./combat_country_flagL", left[&"country_identifier"])
	_set_flag(panel, ^"./combat_country_flagR", right[&"country_identifier"])

	var background: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(panel, ^"./combat_panel_bg")
	if background:
		background.tooltip_string = "%s\n%s\n\n%s" % [
			left[&"country_identifier"], _describe(left), "%s\n%s" % [right[&"country_identifier"], _describe(right)],
		]


func _update_siege_icon(key: String, unit: Dictionary, slot: int, slot_count: int) -> void:
	var icon: Dictionary = _get_or_create(key, "siege_mapicon", _SIEGE_ANCHOR)
	if icon.is_empty():
		return

	var panel: Panel = icon[&"panel"]
	icon[&"position"] = unit[&"position"]
	icon[&"slot"] = slot
	icon[&"slot_count"] = slot_count
	icon[&"drop"] = _SIEGE_DROP
	icon[&"army_ids"] = []
	icon[&"is_player"] = false
	icon[&"paths"] = []

	_set_bar(panel, ^"./siege_progress_bar", unit[&"siege_progress"])


func _on_icon_pressed(key: String) -> void:
	var icon: Dictionary = _icons.get(key, {})
	if icon.is_empty() or not icon.get(&"is_player", false):
		return

	if Input.is_key_pressed(KEY_SHIFT):
		# Add to or remove from the selection
		if _selected_keys.has(key):
			_selected_keys.erase(key)
		else:
			_selected_keys[key] = true
		_update_selection_visual(key)
		return

	var was_only_selected: bool = _selected_keys.size() == 1 and _selected_keys.has(key)
	var previous: Array = _selected_keys.keys()
	_selected_keys.clear()
	if not was_only_selected:
		_selected_keys[key] = true
	for previous_key: String in previous:
		_update_selection_visual(previous_key)
	_update_selection_visual(key)
	if not was_only_selected:
		SoundManager.play_effect_compat("army_selected")


func _update_selection_visual(key: String) -> void:
	var icon: Dictionary = _icons.get(key, {})
	if icon.is_empty():
		return
	var panel: Panel = icon[&"panel"]
	panel.modulate = _SELECTED_MODULATE if _selected_keys.has(key) else Color.WHITE


# ---- Selection box ----


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var position: Vector2 = (make_input_local(event) as InputEventMouseButton).position
		if event.pressed:
			_mouse_pressed = true
			_drag_active = false
			_drag_start = position
			_drag_current = position
		else:
			_drag_current = position
			if _drag_active:
				_finish_box_selection()
				get_viewport().set_input_as_handled()
			_mouse_pressed = false
			_drag_active = false
			_box.queue_redraw()

	elif event is InputEventMouseMotion and _mouse_pressed:
		_drag_current = (make_input_local(event) as InputEventMouseMotion).position
		if not _drag_active and _drag_current.distance_to(_drag_start) >= _BOX_DRAG_THRESHOLD:
			_drag_active = true
		if _drag_active:
			_box.queue_redraw()


func _get_box() -> Rect2:
	return Rect2(_drag_start, _drag_current - _drag_start).abs()


func _draw_box() -> void:
	if not _drag_active:
		return
	var rect: Rect2 = _get_box()
	_box.draw_rect(rect, _BOX_FILL, true)
	_box.draw_rect(rect, _BOX_BORDER, false, 1.5)


func _finish_box_selection() -> void:
	var rect: Rect2 = _get_box()
	var additive: bool = Input.is_key_pressed(KEY_SHIFT)

	var previous: Array = _selected_keys.keys()
	if not additive:
		_selected_keys.clear()

	for key: String in _icons:
		var icon: Dictionary = _icons[key]
		if not icon.get(&"is_player", false):
			continue
		var panel: Panel = icon[&"panel"]
		if not panel.visible:
			continue
		# The icons are scaled around their anchor, which therefore stays at position + anchor
		var centre: Vector2 = panel.position + icon[&"anchor"]
		if rect.has_point(centre):
			_selected_keys[key] = true

	for key: String in previous:
		_update_selection_visual(key)
	for key: String in _selected_keys:
		_update_selection_visual(key)
	if not _selected_keys.is_empty():
		SoundManager.play_effect_compat("army_selected")


# ---- Movement paths ----


func _draw_paths() -> void:
	if not _map_view:
		return

	var camera: Camera3D = _map_view._camera
	if camera.position.y > _map_view._zoom_parchment_threshold * _HIDE_ABOVE_PARCHMENT_FACTOR:
		return

	for key: String in _icons:
		var icon: Dictionary = _icons[key]
		if not icon.get(&"is_player", false):
			continue

		var paths: Array = icon.get(&"paths", [])
		if paths.is_empty():
			continue

		var colour: Color = _PATH_COLOUR_SELECTED if _selected_keys.has(key) else _PATH_COLOUR
		for path: PackedVector2Array in paths:
			_draw_path(camera, path, colour)


func _draw_path(camera: Camera3D, path: PackedVector2Array, colour: Color) -> void:
	var points: PackedVector2Array
	for map_position: Vector2 in path:
		var world: Vector3 = _map_view._map_to_world_coords(map_position)
		if camera.is_position_behind(world):
			return
		points.append(camera.unproject_position(world))

	if points.size() < 2:
		return

	for i: int in range(points.size() - 1):
		_paths_layer.draw_dashed_line(points[i], points[i + 1], colour, _PATH_WIDTH, _PATH_DASH)
	for i: int in range(1, points.size() - 1):
		_paths_layer.draw_circle(points[i], 3.0, colour)

	# Arrow at the destination
	var end: Vector2 = points[points.size() - 1]
	var direction: Vector2 = (end - points[points.size() - 2])
	if direction.length() > 0.001:
		direction = direction.normalized()
		var side: Vector2 = direction.orthogonal()
		_paths_layer.draw_colored_polygon(
			PackedVector2Array([
				end + direction * _ARROW_SIZE,
				end - direction * _ARROW_SIZE * 0.4 + side * _ARROW_SIZE * 0.7,
				end - direction * _ARROW_SIZE * 0.4 - side * _ARROW_SIZE * 0.7,
			]),
			colour
		)
