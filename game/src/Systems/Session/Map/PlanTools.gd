extends Node
## The tools of the plate of a field marshal (docs/WAR_ASSUMPTIONS.md, section 6): the lines of his plan are drawn on the map.
## - The front: the borders of the land of the player with every neighbour are dashed pale yellow, the one under the mouse turns green (our
##   provinces next to it get green stripes); a right click (or a left one) makes the front along the whole border with that neighbour; the button held
##   down and moved along the border makes it only on the part between the two provinces (the part is green while the button is held). The coast:
##   the same with the seas next to our land. A selected field marshal without an order gets the front tool by himself (passive: only the right
##   click on a highlighted border is taken, the other clicks select and move as before).
## - The offensive, the defence, the naval invasion, the breakthrough (a chain of neighbouring provinces into the enemy land, like the defence): the provinces a line may hold get dim yellow stripes; a button (right or left) held down paints the
##   provinces of the line (bright stripes, the arrow of an offensive shows where it goes); when the button is let go the line is made. A naval
##   invasion starts with a click on a port of the player.
## - The edit mode: a click on a province of a line of the marshal takes it away (a piece of the border of a front, a target, a province of the
##   defence), a click next to a line adds it.
## - The handles: a selected marshal with an order shows the circles at the ends of his front or of his line of defence; a button held down on a circle
##   and let go over a province moves that end there (a front: the part of the border from the other end; a line of defence: its chain goes there,
##   a province of the line cuts it).
## Escape or the button of the tool again leaves the tool.

signal tool_changed(tool: int)
## Escape left the tool (the panel lets the marshal go: his passive front tool would start again)
signal cancelled

enum Tool { NONE, FRONT, OFFENSIVE, DEFENCE, COAST, NAVAL, EDIT, HANDLES, BREAKTHROUGH }

const _COLOUR_BORDER: Color = Color(0.93, 0.88, 0.55, 0.8)
const _COLOUR_HOVER: Color = Color(0.3, 0.95, 0.35, 1.0)
const _STRIPES_HOVER: Color = Color(0.25, 0.9, 0.3, 0.55)
const _STRIPES_CANDIDATE: Color = Color(0.95, 0.85, 0.2, 0.22)
const _STRIPES_PAINTED: Color = Color(1.0, 0.9, 0.15, 0.75)
const _STRIPES_LINE: Color = Color(1.0, 0.75, 0.2, 0.45)
## The texture of the stripes holds the province numbers below 256 times this (Victoria 2 has about 3300 provinces)
const _OVERLAY_ROWS: int = 32
const _PLAN_TYPE: Dictionary = { Tool.OFFENSIVE: 0, Tool.DEFENCE: 1, Tool.NAVAL: 2, Tool.BREAKTHROUGH: 3 }

var tool: int = Tool.NONE
var group_id: int = 0
## The tool started by itself for a selected marshal without an order: only the right click on a highlighted border is taken
var passive: bool = false
## The button that paints (left or right)
var _paint_button: int = MOUSE_BUTTON_LEFT
## A front drawn with the button held: the neighbour (index of _entries), the province the button went down on and the one it is over now
var _front_drag_entry: int = -1
var _front_from: int = 0
var _front_to: int = 0
var _front_part_lines: Array = []
## The handle (a circle at an end, FrontLines.get_handles) the button went down on, and the province under the mouse
const _HANDLE_PIXELS: float = 18.0
var _handle: Dictionary = {}
var _handle_to: int = 0
var _map_view: MapView
var _front_lines: Node
var _highlights: Dictionary = {}
var _entries: Array = [] # the neighbours (FRONT) or the seas (COAST)
var _hovered_entry: int = -1
var _candidates: Dictionary = {} # province number -> true
var _painted: Array[int] = []
var _painting: bool = false
var _port: int = 0
## A line asked for and not made yet: the provinces to add to it once it is there
var _pending_type: int = -1
var _pending_known: Dictionary = {}
var _pending_provinces: Array[int] = []
var _overlay_image: Image
var _overlay_texture: ImageTexture


func setup(map_view: MapView) -> void:
	_map_view = map_view
	_front_lines = map_view.get_front_lines()
	_map_view.province_hovered.connect(_on_province_hovered)
	GameSingleton.gamestate_updated.connect(_on_gamestate_updated)


func is_active() -> bool:
	return tool != Tool.NONE


## The button is held down by the tool (painting, a handle, a front along a part of the border)
func is_dragging() -> bool:
	return _painting or _front_drag_entry >= 0 or not _handle.is_empty()


## Starts a tool for the field marshal (the same tool again leaves it, unless it was started by itself: then it becomes the full tool)
func start(new_tool: int, new_group_id: int, new_passive: bool = false) -> void:
	if new_tool == tool and new_group_id == group_id:
		if passive and not new_passive:
			passive = false
			tool_changed.emit(tool)
		elif not new_passive:
			stop()
		return
	stop()
	tool = new_tool
	group_id = new_group_id
	passive = new_passive
	_map_view.input_tool = _on_map_input
	match tool:
		Tool.FRONT, Tool.COAST:
			_highlights = PlayerSingleton.get_border_highlights()
			_entries = _highlights.get(&"neighbours" if tool == Tool.FRONT else &"seas", [])
		Tool.OFFENSIVE, Tool.DEFENCE, Tool.NAVAL, Tool.BREAKTHROUGH:
			_candidates.clear()
			for number: int in PlayerSingleton.get_plan_candidates(_PLAN_TYPE[tool], group_id):
				_candidates[number] = true
		Tool.EDIT:
			_highlights = PlayerSingleton.get_border_highlights()
	_update_highlight()
	tool_changed.emit(tool)


func stop() -> void:
	if tool == Tool.NONE:
		return
	tool = Tool.NONE
	passive = false
	_hovered_entry = -1
	_front_drag_entry = -1
	_front_part_lines = []
	_handle = {}
	_handle_to = 0
	_painting = false
	_painted.clear()
	_port = 0
	_entries = []
	_candidates.clear()
	_map_view.input_tool = Callable()
	if _front_lines != null:
		_front_lines.set_tool_highlight([])
	_map_view.set_plan_overlay(null)
	tool_changed.emit(tool)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if tool != Tool.NONE and key != null and key.pressed and key.keycode == KEY_ESCAPE:
		stop()
		cancelled.emit()
		get_viewport().set_input_as_handled()


## The buttons of the mouse over the map while a tool is active (MapView.input_tool)
func _on_map_input(event: InputEvent, province_number: int) -> bool:
	var button := event as InputEventMouseButton
	if button == null:
		return false
	if button.button_index != MOUSE_BUTTON_RIGHT and button.button_index != MOUSE_BUTTON_LEFT:
		return false
	if tool == Tool.HANDLES:
		return _on_handle_input(button, province_number)
	# The passive front tool takes only the right click on a highlighted border (a click elsewhere selects or moves the armies as before)
	if passive and (button.button_index != MOUSE_BUTTON_RIGHT or _hovered_entry < 0):
		return false
	if not button.pressed and _painting and button.button_index != _paint_button:
		return true
	match tool:
		Tool.FRONT:
			if button.pressed:
				if _hovered_entry < 0:
					return not passive
				# The front is made when the button is let go: on the whole border, or on the part the mouse went along
				_front_drag_entry = _hovered_entry
				_front_from = province_number
				_front_to = province_number
				_paint_button = button.button_index
			elif _front_drag_entry >= 0 and button.button_index == _paint_button:
				var entry: Dictionary = _entries[_front_drag_entry]
				if _front_to != _front_from and _front_to > 0 and _front_from > 0:
					PlayerSingleton.create_border_front_part(group_id, int(entry[&"country_index"]), _front_from, _front_to)
				else:
					PlayerSingleton.create_border_front(group_id, int(entry[&"country_index"]))
				_front_drag_entry = -1
				_front_part_lines = []
				if not button.shift_pressed:
					stop()
				else:
					_update_highlight()
		Tool.COAST:
			if button.pressed and _hovered_entry >= 0:
				PlayerSingleton.create_coastal_front(group_id, int(_entries[_hovered_entry][&"sea_number"]))
				if not button.shift_pressed:
					stop()
		Tool.OFFENSIVE, Tool.DEFENCE, Tool.BREAKTHROUGH:
			if button.pressed:
				_painting = true
				_paint_button = button.button_index
				_painted.clear()
				_paint(province_number)
			elif _painting:
				_painting = false
				_finish_line()
		Tool.NAVAL:
			if button.pressed:
				if _port == 0:
					# First the port the divisions embark in
					if _candidates.has(province_number) and _is_own_port(province_number):
						_port = province_number
						_update_highlight()
				else:
					_painting = true
					_paint_button = button.button_index
					_painted.clear()
					_paint(province_number)
			elif _painting:
				_painting = false
				_finish_line()
		Tool.EDIT:
			if button.pressed:
				_edit_at(province_number)
	return true


## The handles: a press on a circle of the marshal starts the drag, the release over a province moves that end there; other clicks go on as before
func _on_handle_input(button: InputEventMouseButton, province_number: int) -> bool:
	if button.pressed:
		var mouse: Vector2 = get_viewport().get_mouse_position()
		var camera: Camera3D = _map_view.get_viewport().get_camera_3d()
		for handle: Dictionary in _front_lines.get_handles():
			if int(handle[&"group_id"]) != group_id:
				continue
			var at: Vector2 = camera.unproject_position(_map_view.get_ground_position(handle[&"point"]))
			if at.distance_to(mouse) <= _HANDLE_PIXELS:
				_handle = handle
				_handle_to = province_number
				_paint_button = button.button_index
				_update_highlight()
				return true
		return false
	if _handle.is_empty() or button.button_index != _paint_button:
		return false
	var handle: Dictionary = _handle
	_handle = {}
	_update_highlight()
	if province_number <= 0:
		return true
	if handle[&"kind"] == &"defence":
		PlayerSingleton.extend_plan_line(int(handle[&"id"]), bool(handle[&"at_end"]), province_number)
	elif int(handle[&"front_kind"]) == 0 and int(handle[&"enemy_index"]) >= 0:
		# The front from the province of the line at the other end to the province the end was dragged to
		var fixed: int = 0
		var best: float = INF
		var other_point: Vector2 = handle[&"other_point"]
		for number: int in handle[&"province_numbers"]:
			var distance: float = MapItemSingleton.get_unit_position_by_province_number(number).distance_squared_to(other_point)
			if distance < best:
				best = distance
				fixed = number
		if fixed != 0:
			PlayerSingleton.create_border_front_part(group_id, int(handle[&"enemy_index"]), fixed, province_number)
	return true


func _on_province_hovered(province_number: int) -> void:
	if tool == Tool.HANDLES:
		if not _handle.is_empty() and province_number != _handle_to:
			_handle_to = province_number
			_update_highlight()
		return
	match tool:
		Tool.FRONT, Tool.COAST:
			if _front_drag_entry >= 0:
				# The part of the border between the province the button went down on and the one under the mouse (of the same neighbour)
				var entry: Dictionary = _entries[_front_drag_entry]
				var of_entry: bool = (entry[&"own_numbers"] as PackedInt32Array).has(province_number) or (entry[&"other_numbers"] as PackedInt32Array).has(province_number)
				if of_entry and province_number != _front_to:
					_front_to = province_number
					_front_part_lines = PlayerSingleton.get_border_part_lines(int(entry[&"country_index"]), _front_from, _front_to) if _front_to != _front_from else []
					_update_highlight()
				return
			var found: int = _entry_at(province_number)
			if found != _hovered_entry:
				_hovered_entry = found
				_update_highlight()
		Tool.OFFENSIVE, Tool.DEFENCE, Tool.NAVAL, Tool.BREAKTHROUGH:
			if _painting and Input.is_mouse_button_pressed(_paint_button):
				_paint(province_number)


## The neighbour (or the sea) the province belongs to: his land next to ours first, then our land next to his
func _entry_at(province_number: int) -> int:
	if province_number <= 0:
		return -1
	var key: StringName = &"other_numbers" if tool == Tool.FRONT else &"sea_number"
	for index: int in _entries.size():
		var entry: Dictionary = _entries[index]
		if tool == Tool.FRONT and (entry[key] as PackedInt32Array).has(province_number):
			return index
		if tool == Tool.COAST and int(entry[key]) == province_number:
			return index
	for index: int in _entries.size():
		if (_entries[index][&"own_numbers"] as PackedInt32Array).has(province_number):
			return index
	return -1


func _paint(province_number: int) -> void:
	if province_number <= 0 or not _candidates.has(province_number) or _painted.has(province_number):
		return
	if tool == Tool.NAVAL and _is_own_port(province_number):
		return
	_painted.append(province_number)
	_update_highlight()


func _is_own_port(province_number: int) -> bool:
	# The candidates of a naval invasion are our ports and the coast of the others: ours are the ones the player controls
	return PlayerSingleton.get_plan_candidates(1, group_id).has(province_number)


## The painted provinces become a line: the first one makes it, the others are added when it is there (the next update of the state)
func _finish_line() -> void:
	if _painted.is_empty():
		return
	_pending_known.clear()
	for line: Dictionary in PlayerSingleton.get_plan_lines():
		_pending_known[int(line[&"id"])] = true
	_pending_type = _PLAN_TYPE[tool]
	if tool == Tool.NAVAL:
		PlayerSingleton.create_plan_line(group_id, _pending_type, _port)
		_pending_provinces = _painted.duplicate()
	else:
		PlayerSingleton.create_plan_line(group_id, _pending_type, _painted[0])
		_pending_provinces = _painted.slice(1)
	stop()


func _on_gamestate_updated() -> void:
	if _pending_type < 0:
		return
	for line: Dictionary in PlayerSingleton.get_plan_lines():
		if not _pending_known.has(int(line[&"id"])) and int(line[&"type"]) == _pending_type:
			for number: int in _pending_provinces:
				if _pending_type == 1 or _pending_type == 3:
					PlayerSingleton.extend_plan_line(int(line[&"id"]), true, number)
				else:
					PlayerSingleton.toggle_plan_line_province(int(line[&"id"]), number)
			_pending_type = -1
			_pending_provinces.clear()
			if _front_lines != null:
				_front_lines.refresh()
			return


## The edit mode: a province on a line of the marshal is taken away from it, a province next to it is added
func _edit_at(province_number: int) -> void:
	if province_number <= 0:
		return
	var lines: Array = PlayerSingleton.get_plan_lines()
	for line: Dictionary in lines:
		if int(line[&"group_id"]) == group_id and (line[&"province_numbers"] as PackedInt32Array).has(province_number):
			PlayerSingleton.toggle_plan_line_province(int(line[&"id"]), province_number)
			return
	var fronts: Array = []
	for front: Dictionary in PlayerSingleton.get_front_summaries():
		if int(front[&"group_id"]) == group_id:
			fronts.append(front)
	# A piece of the border of a front: all its pieces with the province are taken away
	for front: Dictionary in fronts:
		var edges: PackedInt32Array = front[&"edges"]
		var removed: bool = false
		for i: int in range(0, edges.size(), 2):
			if edges[i + 1] == province_number or (int(front[&"kind"]) == 1 and edges[i] == province_number):
				PlayerSingleton.toggle_front_edge(int(front[&"id"]), edges[i], edges[i + 1])
				removed = true
		if removed:
			return
	# A province of a neighbour of a front: its pieces of the border with our land are added
	for front: Dictionary in fronts:
		for entry: Dictionary in _highlights.get(&"neighbours", []):
			if int(entry[&"country_index"]) != int(front[&"enemy_index"]):
				continue
			var edges: PackedInt32Array = entry[&"edges"]
			var added: bool = false
			for i: int in range(0, edges.size(), 2):
				if edges[i + 1] == province_number:
					PlayerSingleton.toggle_front_edge(int(front[&"id"]), edges[i], edges[i + 1])
					added = true
			if added:
				return
	# Else a target next to an offensive, a province of ours to a line of defence
	var own: bool = PlayerSingleton.get_plan_candidates(1, group_id).has(province_number)
	for line: Dictionary in lines:
		if int(line[&"group_id"]) == group_id and int(line[&"type"]) == (1 if own else 0):
			PlayerSingleton.toggle_plan_line_province(int(line[&"id"]), province_number)
			return


func _update_highlight() -> void:
	var entries: Array = []
	var stripes: Dictionary = {} # province number -> colour
	match tool:
		Tool.FRONT, Tool.COAST:
			for index: int in _entries.size():
				var entry: Dictionary = _entries[index]
				var hovered: bool = index == _hovered_entry
				var dragged_part: bool = index == _front_drag_entry and not _front_part_lines.is_empty()
				entries.append({ &"polylines": entry[&"polylines"], &"colour": _COLOUR_HOVER if hovered and not dragged_part else _COLOUR_BORDER, &"dashed": true })
				if hovered and not dragged_part:
					for number: int in entry[&"own_numbers"]:
						stripes[number] = _STRIPES_HOVER
			if not _front_part_lines.is_empty():
				entries.append({ &"polylines": _front_part_lines, &"colour": _COLOUR_HOVER, &"dashed": false })
		Tool.OFFENSIVE, Tool.DEFENCE, Tool.NAVAL, Tool.BREAKTHROUGH:
			for number: int in _candidates:
				stripes[number] = _STRIPES_CANDIDATE
			for number: int in _painted:
				stripes[number] = _STRIPES_PAINTED
			if _port != 0:
				stripes[_port] = _STRIPES_HOVER
			if tool == Tool.OFFENSIVE and not _painted.is_empty():
				entries.append(_preview_arrow())
			if (tool == Tool.DEFENCE or tool == Tool.BREAKTHROUGH) and _painted.size() >= 2:
				var chain := PackedVector2Array()
				for number: int in _painted:
					chain.append(MapItemSingleton.get_unit_position_by_province_number(number))
				entries.append({ &"polylines": [chain], &"colour": _COLOUR_HOVER, &"dashed": true })
		Tool.HANDLES:
			if not _handle.is_empty() and _handle_to > 0:
				var to: Vector2 = MapItemSingleton.get_unit_position_by_province_number(_handle_to)
				entries.append({ &"polylines": [PackedVector2Array([_handle[&"point"], to])], &"colour": _COLOUR_HOVER, &"dashed": true })
				stripes[_handle_to] = _STRIPES_HOVER
		Tool.EDIT:
			for line: Dictionary in PlayerSingleton.get_plan_lines():
				if int(line[&"group_id"]) == group_id:
					for number: int in line[&"province_numbers"]:
						stripes[number] = _STRIPES_LINE
	if _front_lines != null:
		_front_lines.set_tool_highlight(entries)
	_set_stripes(stripes)


## The way of the offensive that is painted: from the nearest front of the marshal to the middle of the painted provinces
func _preview_arrow() -> Dictionary:
	var to := Vector2.ZERO
	for number: int in _painted:
		to += MapItemSingleton.get_unit_position_by_province_number(number)
	to /= float(_painted.size())
	var from := Vector2.ZERO
	var best: float = INF
	for front: Dictionary in PlayerSingleton.get_front_summaries():
		if int(front[&"group_id"]) != group_id or int(front[&"kind"]) != 0:
			continue
		var centre := Vector2.ZERO
		var numbers: PackedInt32Array = front[&"province_numbers"]
		for number: int in numbers:
			centre += MapItemSingleton.get_unit_position_by_province_number(number)
		if numbers.is_empty():
			continue
		centre /= float(numbers.size())
		if centre.distance_squared_to(to) < best:
			best = centre.distance_squared_to(to)
			from = centre
	if best == INF:
		return { &"polylines": [], &"colour": _COLOUR_HOVER }
	var head: Vector2 = (to - from).normalized() * from.distance_to(to) * 0.08
	var side := Vector2(-head.y, head.x) * 0.6
	return { &"polylines": [PackedVector2Array([from, to]), PackedVector2Array([to - head + side, to, to - head - side])], &"colour": Color(1.0, 0.8, 0.3, 0.9), &"dashed": true }


## The stripes over the provinces: a texture of one texel per province (number % 256, number / 256)
func _set_stripes(stripes: Dictionary) -> void:
	if stripes.is_empty():
		_map_view.set_plan_overlay(null)
		return
	if _overlay_image == null:
		_overlay_image = Image.create_empty(256, _OVERLAY_ROWS, false, Image.FORMAT_RGBA8)
	_overlay_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for number: int in stripes:
		if number / 256 < _OVERLAY_ROWS:
			_overlay_image.set_pixel(number % 256, number / 256, stripes[number])
	if _overlay_texture == null:
		_overlay_texture = ImageTexture.create_from_image(_overlay_image)
	else:
		_overlay_texture.update(_overlay_image)
	_map_view.set_plan_overlay(_overlay_texture)
