extends Control

const PerfProbe := preload("res://src/Utilities/PerfProbe.gd")

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
# The icons are drawn 20% closer and 20% smaller than the original values above. The draw distance setting
# (-50..+50 %) then scales the distance (it also affects the unit and building models).
const _RANGE_FACTOR: float = 0.8
const _SIZE_FACTOR: float = 0.8

const _SELECTED_MODULATE: Color = Color(1.5, 1.35, 0.6)
const _ENEMY_FRAME: int = 3
const _NAVY_TINT: Color = Color(0.55, 0.8, 1.4)

## The armies that are selected changed (ids of the armies of the player)
signal selection_changed(army_ids: Array[int])
## A double click on an icon: the panel of the army (the division menu) is wanted, a single click only selects
signal open_requested(army_ids: Array[int])

const _DOUBLE_CLICK_MSEC: int = 400
var _last_press_key: String = ""
var _last_press_msec: int = 0

var _map_view: MapView
# The selection that was last announced with the signal
var _announced_selection: Array[int] = []
# key -> { panel: Panel, anchor: Vector2, position: Vector2, slot: int, slot_count: int, drop: float, ids: Array, ... }
var _icons: Dictionary[String, Dictionary] = {}
# Selected armies of the player by army id. Armies (not icons) are selected, because the icon of an army changes when it
# moves to another province, but the army stays selected until the player deselects it.
var _selected_armies: Dictionary[int, bool] = {}

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
# What the icons were last placed for (_process_body): they are placed again only when something of it changed
var _layout_dirty: bool = true
var _laid_out_camera: Transform3D = Transform3D()
var _laid_out_size: Vector2 = Vector2.ZERO
var _laid_out_scale: float = -1.0
var _laid_out_zoomed_out: bool = false

# The icons are drawn by the video card (unit_icons.gdshader): the panels of the icons are drawn into the cells of an atlas (a
# SubViewport that is only drawn again when an icon changed), and one MultiMesh shows a quad of every icon at the position of its
# army, the shader keeps it at its size on the screen. The processor does nothing for the icons when the camera moves; the mouse
# finds the icon under it with the rectangles of the icons on the screen (made again when the camera moved, only when asked).
const _ICON_SHADER: Shader = preload("res://src/UI/Session/unit_icons.gdshader")
const _CELL_SIZE: Vector2i = Vector2i(176, 48)
const _CELL_MARGIN: float = 2.0
const _ATLAS_COLUMNS: int = 11
var _atlas: SubViewport
var _atlas_dirty: bool = false
var _free_cells: Array[int] = []
var _cell_count: int = 0
# The part of a panel of a template that is drawn (its controls reach outside of the panel), relative to the panel
var _template_boxes: Dictionary[String, Rect2] = {}
var _icon_mesh: MultiMeshInstance3D
var _icon_material: ShaderMaterial
var _instances_dirty: bool = true
# The rectangles of the icons on the screen (canvas units) for the mouse: [key, Rect2, anchor on the screen], in the order of drawing
var _screen_rects: Array = []
var _screen_rects_camera: Transform3D = Transform3D()
var _screen_rects_scale: float = -1.0
var _screen_rects_dirty: bool = true
var _hovered_key: String = ""
var _pressed_key: String = ""
var _icon_scale: float = 1.0
var _mouse_pressed: bool = false
var _drag_active: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_current: Vector2 = Vector2.ZERO


func setup(map_view: MapView) -> void:
	_map_view = map_view


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Only the points over an icon belong to this control (_has_point): the clicks on the icons stop here, the others go to the map
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_exited.connect(_on_mouse_exited)

	_atlas = SubViewport.new()
	_atlas.transparent_bg = true
	_atlas.disable_3d = true
	_atlas.gui_disable_input = true
	_atlas.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_atlas.size = Vector2i(_CELL_SIZE.x * _ATLAS_COLUMNS, _CELL_SIZE.y)
	add_child(_atlas)

	_icon_material = ShaderMaterial.new()
	_icon_material.shader = _ICON_SHADER
	_icon_material.set_shader_parameter(&"atlas", _atlas.get_texture())
	# over the other transparent things of the map (its names, the markers)
	_icon_material.render_priority = Material.RENDER_PRIORITY_MAX
	var quad: QuadMesh = QuadMesh.new()
	quad.material = _icon_material
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	# the quads are placed by the shader: the box of the culling must cover everything
	multimesh.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	_icon_mesh = MultiMeshInstance3D.new()
	_icon_mesh.multimesh = multimesh
	_icon_mesh.top_level = true
	_icon_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_icon_mesh.visible = false
	if _map_view:
		_map_view.add_child.call_deferred(_icon_mesh)

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
	return not _get_selected_army_ids().is_empty()


## The armies of the player that are selected now
func get_selected_armies() -> Array[int]:
	return _get_selected_army_ids()


## Selects the given armies of the player (the divisions of a field marshal), the others are deselected
func select_armies(army_ids: Array) -> void:
	_selected_armies.clear()
	for army_id: Variant in army_ids:
		_selected_armies[int(army_id)] = true
	_update_all_selection_visuals()


func clear_selection() -> void:
	if _selected_armies.is_empty():
		return
	_selected_armies.clear()
	_update_all_selection_visuals()


# Ids of the selected armies that still exist
func _get_selected_army_ids() -> Array[int]:
	var result: Array[int] = []
	for icon: Dictionary in _icons.values():
		if not icon.get(&"is_player", false):
			continue
		for army_id: int in icon[&"army_ids"]:
			if _selected_armies.has(army_id):
				result.append(army_id)
	return result


func _is_icon_selected(icon: Dictionary) -> bool:
	if not icon.get(&"is_player", false):
		return false
	for army_id: int in icon[&"army_ids"]:
		if _selected_armies.has(army_id):
			return true
	return false


func _update_all_selection_visuals() -> void:
	_layout_dirty = true
	for key: String in _icons:
		_update_selection_visual(key)
	_sync_selection_markers()
	_announce_selection()


# Tells the panel of the army about the selection when it changed
func _announce_selection() -> void:
	var ids: Array[int] = _get_selected_army_ids()
	ids.sort()
	if ids == _announced_selection:
		return
	_announced_selection = ids
	selection_changed.emit(ids)


# Orders every selected army to go to the province, with queued = true (Shift) the province is added to the end of the
# route the armies are already following
func order_move(province_number: int, queued: bool = false) -> void:
	var ordered: int = 0
	for army_id: int in _get_selected_army_ids():
		var accepted: bool = (
			PlayerSingleton.queue_army_move(army_id, province_number) if queued
			else PlayerSingleton.move_army(army_id, province_number)
		)
		if accepted:
			ordered += 1

	if ordered == 0:
		push_warning("The armies cannot move to province %d" % province_number)
	else:
		SoundManager.play_effect_compat("army_move")


func _process(_delta: float) -> void:
	PerfProbe.begin("UnitBanners._process")
	_process_body(_delta)
	PerfProbe.end("UnitBanners._process")


func _process_body(_delta: float) -> void:
	if _icons_dirty and _map_view and not _is_zoomed_out():
		_refresh()

	if not _map_view or _icons.is_empty():
		return

	var camera: Camera3D = _map_view._camera
	var zoomed_out: bool = camera.position.y > _get_hide_height()

	# Icons shrink a bit when zooming out
	var size_setting: float = 1.0 + float(GameSettings.get_setting(GameSettings.VIDEO_UNIT_ICON_SIZE).value()) / 100.0
	_icon_scale = _SIZE_FACTOR * size_setting * clampf(
		_map_view._zoom_parchment_threshold * 1.2 / maxf(camera.position.y, 0.001), _MIN_SCALE, _MAX_SCALE
	)

	if _atlas_dirty:
		_atlas_dirty = false
		_atlas.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _instances_dirty:
		_instances_dirty = false
		_rebuild_instances()
	if _icon_mesh.visible == zoomed_out:
		_icon_mesh.visible = not zoomed_out
	# canvas units of the icon to pixels of the screen
	var pixel_scale: float = _icon_scale * get_viewport().get_final_transform().get_scale().x
	if pixel_scale != _laid_out_scale:
		_laid_out_scale = pixel_scale
		_icon_material.set_shader_parameter(&"pixel_scale", pixel_scale)

	# The paths of the player's armies are drawn on the canvas: again only when the camera, the window or the icons changed
	var view_size: Vector2 = size
	var camera_transform: Transform3D = camera.global_transform
	if not _layout_dirty and camera_transform == _laid_out_camera and view_size == _laid_out_size \
			and zoomed_out == _laid_out_zoomed_out:
		return
	_layout_dirty = false
	_laid_out_camera = camera_transform
	_laid_out_size = view_size
	_laid_out_zoomed_out = zoomed_out
	_paths_layer.queue_redraw()


# The anchor of an icon on the ground and its quad (canvas units of a full size icon, relative to the anchor)
func _icon_quad(icon: Dictionary) -> Rect2:
	var box: Rect2 = icon[&"box"]
	var shift: Vector2 = Vector2(
		(icon[&"slot"] - (icon[&"slot_count"] - 1) / 2.0) * _SLOT_SPACING, -_LIFT + float(icon[&"drop"])
	)
	return Rect2(shift + box.position - Vector2(_CELL_MARGIN, _CELL_MARGIN) - icon[&"anchor"], box.size + Vector2(_CELL_MARGIN, _CELL_MARGIN) * 2.0)


func _cell_origin(cell: int) -> Vector2:
	return Vector2((cell % _ATLAS_COLUMNS) * _CELL_SIZE.x, (cell / _ATLAS_COLUMNS) * _CELL_SIZE.y)


# The quads of all the icons (when the icons, their places or the selection changed: not when the camera moves)
func _rebuild_instances() -> void:
	var multimesh: MultiMesh = _icon_mesh.multimesh
	multimesh.instance_count = _icons.size()
	var atlas_size: Vector2 = Vector2(_atlas.size)
	var index: int = 0
	for icon: Dictionary in _icons.values():
		var quad: Rect2 = _icon_quad(icon)
		var world: Vector3 = _map_view._map_to_standing_coords(icon[&"position"])
		icon[&"world"] = world
		multimesh.set_instance_transform(index, Transform3D(
			Basis(Vector3(quad.position.x, quad.position.y, quad.size.x), Vector3(quad.size.y, 0.0, 0.0), Vector3(0.0, 0.0, 1.0)), world
		))
		var origin: Vector2 = _cell_origin(icon[&"cell"])
		multimesh.set_instance_custom_data(index, Color(
			origin.x / atlas_size.x, origin.y / atlas_size.y, quad.size.x / atlas_size.x, quad.size.y / atlas_size.y
		))
		multimesh.set_instance_color(index, _SELECTED_MODULATE if _is_icon_selected(icon) else Color.WHITE)
		index += 1
	_screen_rects_dirty = true


# The icon under a point of the canvas, "" if none (the last drawn is on top)
func _icon_at(point: Vector2) -> String:
	if _map_view == null or _icons.is_empty() or not _icon_mesh.visible:
		return ""
	var camera: Camera3D = _map_view._camera
	if _screen_rects_dirty or camera.global_transform != _screen_rects_camera or _icon_scale != _screen_rects_scale:
		_screen_rects_dirty = false
		_screen_rects_camera = camera.global_transform
		_screen_rects_scale = _icon_scale
		_screen_rects.clear()
		for key: String in _icons:
			var icon: Dictionary = _icons[key]
			var world: Vector3 = icon.get(&"world", _map_view._map_to_standing_coords(icon[&"position"]))
			if camera.is_position_behind(world):
				continue
			var anchor: Vector2 = camera.unproject_position(world)
			var quad: Rect2 = _icon_quad(icon)
			_screen_rects.append([key, Rect2(anchor + quad.position * _icon_scale, quad.size * _icon_scale), anchor])
	for i: int in range(_screen_rects.size() - 1, -1, -1):
		if (_screen_rects[i][1] as Rect2).has_point(point):
			return _screen_rects[i][0]
	return ""


func _has_point(point: Vector2) -> bool:
	return _icon_at(point) != ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hovered(_icon_at((event as InputEventMouseMotion).position), (event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button: InputEventMouseButton = event
		var key: String = _icon_at(button.position)
		if button.pressed:
			_pressed_key = key
			if key != "":
				accept_event()
		elif _pressed_key != "":
			accept_event()
			if key == _pressed_key:
				_on_icon_pressed(key)
			_pressed_key = ""


func _on_mouse_exited() -> void:
	_set_hovered("", Vector2.ZERO)


# The tooltip of the icon under the mouse (its text is made when the mouse comes over it)
func _set_hovered(key: String, point: Vector2) -> void:
	if key == _hovered_key:
		return
	_hovered_key = key
	_show_hovered_tooltip(point)


func _show_hovered_tooltip(point: Vector2) -> void:
	if _hovered_key == "":
		MenuSingleton.hide_tooltip()
		return
	var source: Callable = _icons.get(_hovered_key, {}).get(&"tooltip_source", Callable())
	if source.is_valid():
		MenuSingleton.show_tooltip(source.call(), {}, get_global_transform_with_canvas() * point + Vector2(0.0, 32.0))


# True while the icons are hidden because the camera is far away
func _is_zoomed_out() -> bool:
	return _map_view != null and _map_view._camera.position.y > _get_hide_height()


# Set while the icons are out of date because they were not rebuilt when the camera was far away
var _icons_dirty: bool = false


func _refresh() -> void:
	if _is_zoomed_out():
		_icons_dirty = true
		return
	_icons_dirty = false
	var units: Array = PlayerSingleton.get_map_units()

	# Group by province
	# (armies and fleets of a province are separate groups, a fleet in a port is drawn at sea)
	var by_province: Dictionary[String, Array] = {}
	for unit: Dictionary in units:
		var bucket: String = ("n%d" if unit.get(&"is_navy", false) else "p%d") % int(unit[&"province_number"])
		if not by_province.has(bucket):
			by_province[bucket] = []
		by_province[bucket].append(unit)

	var present: Dictionary[String, bool] = {}

	for bucket: String in by_province:
		var group: Array = by_province[bucket]

		var in_combat: bool = false
		for unit: Dictionary in group:
			in_combat = in_combat or unit[&"in_combat"]

		# A battle is one icon with both sides
		if in_combat and group.size() >= 2:
			var key: String = "%s_combat" % bucket
			present[key] = true
			# Icons whose data did not change are left alone (it is the interface that costs the time)
			var combat_signature: int = hash([group[0], group[1]])
			if not (_icons.has(key) and int(_icons[key].get(&"signature", -1)) == combat_signature):
				_update_combat_icon(key, group[0], group[1])
				if _icons.has(key):
					_icons[key][&"signature"] = combat_signature
			continue

		for slot: int in group.size():
			var unit: Dictionary = group[slot]
			var key: String = "%s_c%d" % [bucket, unit[&"country_index"]]
			present[key] = true
			var signature: int = hash([unit, slot, group.size()])
			if not (_icons.has(key) and int(_icons[key].get(&"signature", -1)) == signature):
				_update_unit_icon(key, unit, slot, group.size())
				if _icons.has(key):
					_icons[key][&"signature"] = signature

			if unit[&"siege_progress"] >= 0.0:
				var siege_key: String = key + "_siege"
				present[siege_key] = true
				if not (_icons.has(siege_key) and int(_icons[siege_key].get(&"signature", -1)) == signature):
					_update_siege_icon(siege_key, unit, slot, group.size())
					if _icons.has(siege_key):
						_icons[siege_key][&"signature"] = signature

	for key: String in _icons.keys():
		if not present.has(key):
			_remove_icon(key)

	# Armies that are gone (destroyed) are no longer selected
	if not _selected_armies.is_empty():
		var existing: Dictionary[int, bool] = {}
		for icon: Dictionary in _icons.values():
			for army_id: int in icon.get(&"army_ids", []):
				existing[army_id] = true
		for army_id: int in _selected_armies.keys():
			if not existing.has(army_id):
				_selected_armies.erase(army_id)
	_update_all_selection_visuals()


func _remove_icon(key: String) -> void:
	var icon: Dictionary = _icons[key]
	_icons.erase(key)
	_layout_dirty = true
	_instances_dirty = true
	_atlas_dirty = true
	_free_cells.append(int(icon[&"cell"]))
	if key == _hovered_key:
		_set_hovered("", Vector2.ZERO)
	var panel: Panel = icon[&"panel"]
	if is_instance_valid(panel):
		_atlas.remove_child(panel)
		panel.free()


func _get_or_create(key: String, template: String, anchor: Vector2) -> Dictionary:
	var icon: Dictionary = _icons.get(key, {})
	if not icon.is_empty():
		return icon

	var panel: Panel = GUINode.generate_gui_element(_GUI_FILE, template)
	if not panel:
		return {}

	# The panel goes into its cell of the atlas: the part of it that is drawn starts at the cell (plus a margin)
	_atlas.add_child(panel)
	if not _template_boxes.has(template):
		var box: Rect2 = Rect2()
		var origin: Vector2 = panel.get_global_rect().position
		for child: Node in panel.find_children("*", "Control", true, false):
			var rect: Rect2 = (child as Control).get_global_rect()
			rect.position -= origin
			box = rect if box.size == Vector2.ZERO else box.merge(rect)
		if box.size == Vector2.ZERO:
			box = Rect2(Vector2.ZERO, panel.size)
		_template_boxes[template] = box
	var box: Rect2 = _template_boxes[template]
	var cell: int = _free_cells.pop_back() if not _free_cells.is_empty() else _new_cell()
	# The panels of the templates are anchored to the centre of their parent: when the atlas grows they would move out of their cells
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position =_cell_origin(cell) + Vector2(_CELL_MARGIN, _CELL_MARGIN) - box.position

	_layout_dirty = true
	_instances_dirty = true
	_atlas_dirty = true
	icon = { &"panel": panel, &"anchor": anchor, &"slot": 0, &"slot_count": 1, &"drop": 0.0, &"army_ids": [], &"cell": cell, &"box": box }
	_icons[key] = icon
	return icon


# A new cell at the end of the atlas (it grows by a row when it is full)
func _new_cell() -> int:
	var cell: int = _cell_count
	_cell_count += 1
	var rows: int = (_cell_count + _ATLAS_COLUMNS - 1) / _ATLAS_COLUMNS
	if rows * _CELL_SIZE.y > _atlas.size.y:
		_atlas.size = Vector2i(_CELL_SIZE.x * _ATLAS_COLUMNS, rows * _CELL_SIZE.y)
		_instances_dirty = true
	return cell


# What the helpers below last put into the controls of a panel (by the path): a control is only changed when its value changed
func _unchanged(panel: Node, path: NodePath, value: Variant) -> bool:
	var cache: Dictionary = panel.get_meta(&"values", {})
	if cache.is_empty():
		panel.set_meta(&"values", cache)
	if cache.has(path) and cache[path] == value:
		return true
	cache[path] = value
	_atlas_dirty = true
	return false


func _set_text(panel: Node, path: NodePath, text: String) -> void:
	if _unchanged(panel, path, text):
		return
	var label: GUILabel = GUINode.get_gui_label_from_node_and_path(panel, path)
	if label:
		label.set_auto_translate(false)
		label.set_text(text)


func _set_bar(panel: Node, path: NodePath, value: float) -> void:
	# (the bar has steps of 0.01)
	if _unchanged(panel, path, roundi(value * 100.0)):
		return
	var bar: GUIProgressBar = GUINode.get_gui_progress_bar_from_node_and_path(panel, path)
	if bar:
		bar.max_value = 1.0
		bar.step = 0.01
		bar.value = value


func _set_flag(panel: Node, path: NodePath, country_identifier: String) -> void:
	if _unchanged(panel, path, country_identifier):
		return
	var flag: GUIMaskedFlagButton = GUINode.get_gui_masked_flag_button_from_node_and_path(panel, path)
	if flag:
		flag.set_flag_country_name(country_identifier)
		flag.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _describe(unit: Dictionary) -> String:
	if unit.get(&"is_navy", false):
		return _describe_fleet(unit)
	var lines: PackedStringArray = [
		"Армий: %d, полков: %d" % [unit[&"army_count"], unit[&"regiments"]],
		# The men now of the full strength (a regiment is 3000 men) and the organisation
		"Войска: %s из %s чел. (%d%%)" % [_men(int(unit.get(&"men", 0))), _men(int(unit.get(&"max_men", 0))), roundi(float(unit[&"strength"]) * 100.0)],
		"Организация: %d%%" % roundi(float(unit[&"organisation"]) * 100.0),
	]
	# The regiments raised by the mobilisation (docs/RECRUITMENT.md): out of the manpower of the soldiers, they go home with the demobilisation
	var mobilised: int = int(unit.get(&"mobilised_regiments", 0))
	if mobilised > 0:
		lines.insert(1, ("§YМобилизованные: все %d полков§W" % mobilised) if mobilised == int(unit[&"regiments"])
			else "§YМобилизованные: %d из %d полков§W" % [mobilised, int(unit[&"regiments"])])
	# The supply of the player's divisions: is it enough, the reserve, the level and how it changes a day
	if unit[&"is_player"] and unit.has(&"supply_arrived"):
		var arrived: float = float(unit[&"supply_arrived"])
		var change: float = float(unit[&"supply_change_per_day"])
		var step: int = roundi(float(unit[&"supply_step_per_day"]) * 100.0)
		var reserve_left: float = float(unit[&"supply_reserve_left_days"])
		if arrived >= 0.99:
			lines.append("Снабжение: хватает")
		else:
			lines.append("Снабжение: не хватает, доходит %d%% нужного" % roundi(arrived * 100.0))
		lines.append("Запас: %.1f дн." % float(unit[&"supply_reserve_days"]))
		var level_line: String = "Уровень снабжения: %d%%" % roundi(float(unit[&"supply_level"]) * 100.0)
		if change < 0.0:
			level_line += " (−%d%% в день)" % step
		elif change > 0.0:
			level_line += " (+%d%% в день)" % step
		elif reserve_left >= 0.0:
			level_line += " (запас кончится через %d дн., затем −%d%% в день)" % [ceili(reserve_left), step]
		lines.append(level_line)
		var from_grain: float = float(unit.get(&"canned_food_from_grain", 0.0))
		if from_grain > 0.0:
			lines.append("Консервов нет: страна кормит войска зерном (%.1f консервов в день заменено, зерна уходит вдвое больше)" % from_grain)
		# The overload of the province and the new men (docs/RECRUITMENT.md)
		var overload: float = float(unit.get(&"overload_attrition_pct", 0.0))
		if overload > 0.0:
			lines.append("Перегруз провинции: нагрузка %d%% лимита снабжения, истощение −%.1f%% в день" % [
				roundi(float(unit[&"supply_load_ratio"]) * 100.0), overload])
		var reinforce_men: int = int(unit.get(&"reinforce_men", 0))
		var reinforce_text: String = ("+%s чел. в день" % _men(reinforce_men)) if reinforce_men > 0 else "нет"
		match int(unit.get(&"reinforce_state", 0)):
			1:
				lines.append("Пополнение: " + reinforce_text)
			2:
				lines.append("Пополнение: нет — не своя и не союзная земля")
			3:
				lines.append("Пополнение: нет — армия отрезана")
			4:
				lines.append("Пополнение: нет — снабжения меньше половины")
			5:
				lines.append("Пополнение: %s — не хватает свободных людей" % reinforce_text)
			6:
				lines.append("Пополнение: %s — не хватает товаров на складе" % reinforce_text)
			7:
				lines.append("Пополнение: %s — не хватает свободных людей и товаров на складе" % reinforce_text)
	if int(unit.get(&"at_sea_days", 0)) > 0:
		lines.append("Плывёт морем в %s: осталось %d дн." % [unit.get(&"at_sea_to_name", "?"), int(unit[&"at_sea_days"])])
	if unit.get(&"attrition", false):
		lines.append("Армия несёт потери: чужая земля или нет снабжения")
	if unit[&"in_combat"]:
		lines.append("В бою")
	elif unit[&"moving"]:
		lines.append("На марше")
	if unit[&"siege_progress"] >= 0.0:
		lines.append("Осада: %d%%" % roundi(float(unit[&"siege_progress"]) * 100.0))
	if unit[&"is_player"]:
		lines.append("Нажмите, чтобы выбрать; правый клик по провинции — приказ идти")
	return "\n".join(lines)


## A number of men with spaces between the thousands
func _men(value: int) -> String:
	var text: String = str(absi(value))
	var grouped: String = ""
	while text.length() > 3:
		grouped = " " + text.substr(text.length() - 3) + grouped
		text = text.substr(0, text.length() - 3)
	return text + grouped


func _describe_fleet(unit: Dictionary) -> String:
	var lines: PackedStringArray = [
		"Флотов: %d, кораблей: %d" % [unit[&"army_count"], unit[&"regiments"]],
		"Сила: %d%%" % roundi(float(unit[&"strength"]) * 100.0),
		"Организация: %d%%" % roundi(float(unit[&"organisation"]) * 100.0),
	]
	# The roles of the ships (docs/WAR_ASSUMPTIONS.md, section 9): the light ships screen the capital ones in a battle, transports do not blockade
	lines.append("Линейных: %d, лёгких: %d, транспортов: %d" % [int(unit.get(&"capital_ships", 0)), int(unit.get(&"light_ships", 0)),
		int(unit.get(&"transports", 0))])
	if unit.get(&"carried", 0) > 0:
		lines.append("Перевозит полков: %d" % unit[&"carried"])
	if unit.get(&"blockade", false):
		lines.append("Порт заблокирован")
	if unit.get(&"out_of_range", false):
		lines.append("Вне дальности военно-морских баз: корабли теряют организацию и силу")
	if unit[&"in_combat"]:
		lines.append("Морской бой")
	elif unit[&"moving"]:
		lines.append("В плавании")
	if unit[&"is_player"]:
		lines.append("Нажмите, чтобы выбрать; правый клик по морю или порту - приказ плыть")
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
		# Fleets have a blue tint
		colour.modulate = _NAVY_TINT if unit.get(&"is_navy", false) else Color.WHITE

	_set_tooltip_source(key, _describe.bind(unit))
	_atlas_dirty = true
	_instances_dirty = true

	# The attrition icon is shown for armies that lose men: outside of friendly lands or without supplies
	var attr: Node = panel.get_node_or_null(^"./unit_panel_attr")
	if attr is CanvasItem:
		attr.visible = unit.get(&"attrition", false) or unit.get(&"blockade", false)

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

	_set_tooltip_source(key, func() -> String:
		return "%s\n%s\n\n%s" % [
			left[&"country_identifier"], _describe(left), "%s\n%s" % [right[&"country_identifier"], _describe(right)],
		])
	_instances_dirty = true


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
	_instances_dirty = true


# The text of the tooltip of an icon is made when the mouse comes over it (and again while it stays there and the army changes)
func _set_tooltip_source(key: String, source: Callable) -> void:
	var icon: Dictionary = _icons.get(key, {})
	if icon.is_empty():
		return
	icon[&"tooltip_source"] = source
	if key == _hovered_key:
		_show_hovered_tooltip(get_local_mouse_position())


func _on_icon_pressed(key: String) -> void:
	var icon: Dictionary = _icons.get(key, {})
	if icon.is_empty() or not icon.get(&"is_player", false):
		return

	var army_ids: Array = icon[&"army_ids"]
	var all_selected: bool = true
	for army_id: int in army_ids:
		all_selected = all_selected and _selected_armies.has(army_id)

	# A double click opens the panel of the armies of the icon (the first click has already selected them)
	var now: int = Time.get_ticks_msec()
	var is_double: bool = key == _last_press_key and now - _last_press_msec < _DOUBLE_CLICK_MSEC and not Input.is_key_pressed(KEY_SHIFT)
	_last_press_key = "" if is_double else key
	_last_press_msec = now
	if is_double:
		_selected_armies.clear()
		for army_id: int in army_ids:
			_selected_armies[army_id] = true
		_update_all_selection_visuals()
		open_requested.emit(_get_selected_army_ids())
		return

	if Input.is_key_pressed(KEY_SHIFT):
		# Add to or remove from the selection
		for army_id: int in army_ids:
			if all_selected:
				_selected_armies.erase(army_id)
			else:
				_selected_armies[army_id] = true
		_update_all_selection_visuals()
		return

	var was_only_selected: bool = all_selected and _selected_armies.size() == army_ids.size()
	_selected_armies.clear()
	if not was_only_selected:
		for army_id: int in army_ids:
			_selected_armies[army_id] = true
	_update_all_selection_visuals()
	if not was_only_selected:
		SoundManager.play_effect_compat("army_selected")


func _update_selection_visual(key: String) -> void:
	var icon: Dictionary = _icons.get(key, {})
	if icon.is_empty():
		return
	_layout_dirty = true
	# (the colour of the quad of the icon)
	_instances_dirty = true


# ---- Selection box ----


func _unhandled_input(event: InputEvent) -> void:
	# A tool of the plans holds the button (it paints a line, drags a handle): no box of the selection, the release is the tool's
	if _map_view != null and _map_view.is_tool_dragging():
		if _mouse_pressed or _drag_active:
			_mouse_pressed = false
			_drag_active = false
			_box.queue_redraw()
		return
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

	if not additive:
		_selected_armies.clear()

	for key: String in _icons:
		var icon: Dictionary = _icons[key]
		if not icon.get(&"is_player", false):
			continue
		if _is_zoomed_out():
			continue
		var world: Vector3 = icon.get(&"world", _map_view._map_to_standing_coords(icon[&"position"]))
		if _map_view._camera.is_position_behind(world):
			continue
		var centre: Vector2 = _map_view._camera.unproject_position(world)
		if rect.has_point(centre):
			for army_id: int in icon[&"army_ids"]:
				_selected_armies[army_id] = true

	_update_all_selection_visuals()
	if not _selected_armies.is_empty():
		SoundManager.play_effect_compat("army_selected")


# ---- Movement paths ----


# Camera height above which the icons are hidden
func _get_hide_height() -> float:
	var draw_distance: float = 1.0 + float(GameSettings.get_setting(GameSettings.VIDEO_DRAW_DISTANCE).value()) / 100.0
	return _map_view._zoom_parchment_threshold * _HIDE_ABOVE_PARCHMENT_FACTOR * _RANGE_FACTOR * draw_distance


func _draw_paths() -> void:
	if not _map_view:
		return

	var camera: Camera3D = _map_view._camera
	if camera.position.y > _get_hide_height():
		return

	for key: String in _icons:
		var icon: Dictionary = _icons[key]
		if not icon.get(&"is_player", false):
			continue

		var paths: Array = icon.get(&"paths", [])
		if paths.is_empty():
			continue

		var colour: Color = _PATH_COLOUR_SELECTED if _is_icon_selected(icon) else _PATH_COLOUR
		for path: PackedVector2Array in paths:
			_draw_path(camera, path, colour)


func _draw_path(camera: Camera3D, path: PackedVector2Array, colour: Color) -> void:
	var points: PackedVector2Array
	for map_position: Vector2 in path:
		var world: Vector3 = _map_view._map_to_ground_coords(map_position)
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


# Orange ring of the original game around every selected army (the map's selection markers)
func _sync_selection_markers() -> void:
	if not _map_view:
		return

	var markers: SelectionMarkers = _map_view.selectionMarkers
	if not markers:
		return

	markers.clear_selection_markers()
	for key: String in _icons:
		var icon: Dictionary = _icons[key]
		var army_ids: Array = icon.get(&"army_ids", [])
		var selected_id: int = -1
		for army_id: int in army_ids:
			if _selected_armies.has(army_id):
				selected_id = army_id
				break
		if selected_id < 0:
			continue

		markers.add_selection_marker(selected_id, _map_view._map_to_ground_coords(icon[&"position"]))


