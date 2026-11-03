extends Node
## The tools of the plate of a field marshal (docs/WAR_ASSUMPTIONS.md, section 6): the lines of his plan are drawn on the map.
## - The front: the borders of the land of the player with every neighbour are dashed pale yellow, the one under the mouse turns green (our
##   provinces next to it get green stripes); a click makes the front along the whole border with that neighbour. The coast: the same with the
##   seas next to our land.
## - The offensive, the defence, the naval invasion: the provinces a line may hold get dim yellow stripes; the left button held down paints the
##   provinces of the line (bright stripes, the arrow of an offensive shows where it goes); when the button is let go the line is made. A naval
##   invasion starts with a click on a port of the player.
## - The edit mode: a click on a province of a line of the marshal takes it away (a piece of the border of a front, a target, a province of the
##   defence), a click next to a line adds it.
## The right button or Escape leaves the tool.

signal tool_changed(tool: int)

enum Tool { NONE, FRONT, OFFENSIVE, DEFENCE, COAST, NAVAL, EDIT }

const _COLOUR_BORDER: Color = Color(0.93, 0.88, 0.55, 0.8)
const _COLOUR_HOVER: Color = Color(0.3, 0.95, 0.35, 1.0)
const _STRIPES_HOVER: Color = Color(0.25, 0.9, 0.3, 0.55)
const _STRIPES_CANDIDATE: Color = Color(0.95, 0.85, 0.2, 0.22)
const _STRIPES_PAINTED: Color = Color(1.0, 0.9, 0.15, 0.75)
const _STRIPES_LINE: Color = Color(1.0, 0.75, 0.2, 0.45)
## The texture of the stripes holds the province numbers below 256 times this (Victoria 2 has about 3300 provinces)
const _OVERLAY_ROWS: int = 32
const _PLAN_TYPE: Dictionary = { Tool.OFFENSIVE: 0, Tool.DEFENCE: 1, Tool.NAVAL: 2 }

var tool: int = Tool.NONE
var group_id: int = 0
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


## Starts a tool for the field marshal (the same tool again leaves it)
func start(new_tool: int, new_group_id: int) -> void:
	if new_tool == tool and new_group_id == group_id:
		stop()
		return
	stop()
	tool = new_tool
	group_id = new_group_id
	_map_view.input_tool = _on_map_input
	match tool:
		Tool.FRONT, Tool.COAST:
			_highlights = PlayerSingleton.get_border_highlights()
			_entries = _highlights.get(&"neighbours" if tool == Tool.FRONT else &"seas", [])
		Tool.OFFENSIVE, Tool.DEFENCE, Tool.NAVAL:
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
	_hovered_entry = -1
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
		get_viewport().set_input_as_handled()


## The buttons of the mouse over the map while a tool is active (MapView.input_tool)
func _on_map_input(event: InputEvent, province_number: int) -> bool:
	var button := event as InputEventMouseButton
	if button == null:
		return false
	if button.button_index == MOUSE_BUTTON_RIGHT:
		if button.pressed:
			stop()
		return true
	if button.button_index != MOUSE_BUTTON_LEFT:
		return false
	match tool:
		Tool.FRONT, Tool.COAST:
			if button.pressed and _hovered_entry >= 0:
				var entry: Dictionary = _entries[_hovered_entry]
				if tool == Tool.FRONT:
					PlayerSingleton.create_border_front(group_id, int(entry[&"country_index"]))
				else:
					PlayerSingleton.create_coastal_front(group_id, int(entry[&"sea_number"]))
				if not button.shift_pressed:
					stop()
		Tool.OFFENSIVE, Tool.DEFENCE:
			if button.pressed:
				_painting = true
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
					_painted.clear()
					_paint(province_number)
			elif _painting:
				_painting = false
				_finish_line()
		Tool.EDIT:
			if button.pressed:
				_edit_at(province_number)
	return true


func _on_province_hovered(province_number: int) -> void:
	match tool:
		Tool.FRONT, Tool.COAST:
			var found: int = _entry_at(province_number)
			if found != _hovered_entry:
				_hovered_entry = found
				_update_highlight()
		Tool.OFFENSIVE, Tool.DEFENCE, Tool.NAVAL:
			if _painting and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
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
				entries.append({ &"polylines": entry[&"polylines"], &"colour": _COLOUR_HOVER if hovered else _COLOUR_BORDER, &"dashed": true })
				if hovered:
					for number: int in entry[&"own_numbers"]:
						stripes[number] = _STRIPES_HOVER
		Tool.OFFENSIVE, Tool.DEFENCE, Tool.NAVAL:
			for number: int in _candidates:
				stripes[number] = _STRIPES_CANDIDATE
			for number: int in _painted:
				stripes[number] = _STRIPES_PAINTED
			if _port != 0:
				stripes[_port] = _STRIPES_HOVER
			if tool == Tool.OFFENSIVE and not _painted.is_empty():
				entries.append(_preview_arrow())
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
