class_name FrontLines
extends MeshInstance3D
## The fronts and the lines of the plans of the player on the map (docs/WAR_ASSUMPTIONS.md, section 6), drawn as ribbons on the ground:
## - a front: the line of the colour of its field marshal along its pieces of the border, a circle at both ends (the handles: PlanTools.gd drags them);
##   with divisions on it the line gets teeth on the side of the enemy and a label "N div. - group";
## - an offensive: the line of its targets (the far border) with saw teeth and a wide arrow from the front to the targets with the label of the plan;
## - a line of defence: a line through the chain of its provinces with crosses and a circle at both ends; a naval invasion: a dashed arrow from the
##   port to the coast.
## The tools of the plate of a marshal (PlanTools.gd) draw their highlight over them (set_tool_highlight). The lines are made by PlayerSingleton
## (pixel edges of the province map, simplified).

const HEIGHT: float = 0.004
const WIDTH_PER_CAMERA_HEIGHT: float = 0.012
const MIN_WIDTH: float = 0.003
const COLOUR_ATTACK: Color = Color(0.95, 0.05, 0.03, 1.0)
const COLOUR_DEFEND: Color = Color(0.05, 0.3, 1.0, 1.0)
const CIRCLE_RADIUS_WIDTHS: float = 3.2
const CIRCLE_SEGMENTS: int = 24
const TOOTH_SPACING_WIDTHS: float = 2.2
const TOOTH_LENGTH_WIDTHS: float = 1.6
const SAW_SPACING_WIDTHS: float = 3.0
const SAW_LENGTH_WIDTHS: float = 2.2
const CROSS_SPACING_WIDTHS: float = 9.0
const CROSS_SIZE_WIDTHS: float = 2.4
const DASH_WIDTHS: float = 3.0
const GAP_WIDTHS: float = 2.0
const ARROW_WIDTH_WIDTHS: float = 9.0
const ARROW_HEAD_WIDTHS: float = 11.0
const ARROW_BEND: float = 0.18
## The height of the letters of a label in widths of the line
const LABEL_HEIGHT_WIDTHS: float = 2.6
## The borders change when provinces are taken: the lines are made again every this many updates of the game state
const REFRESH_EVERY_UPDATES: int = 30

var _map_view: MapView
var _signature: String = ""
var _fronts: Array = [] # { colour, polylines, ends, teeth, centres, label }
var _plans: Array = [] # { type, colour, polylines, centres (offensive: of the targets), from, to, label }
var _tool_entries: Array = [] # { polylines, colour, dashed }
## The circles at the ends of the fronts and of the lines of defence: { kind: &"front" or &"defence", id, group_id, enemy_index, at_end, point (map
## position), other_point (the other end), province_numbers }
var _handles: Array = []
var _width_bucket: int = -1
var _updates: int = 0
var _material: StandardMaterial3D
var _tool_mesh: MeshInstance3D
var _labels: Node3D


func setup(map_view: MapView) -> void:
	_map_view = map_view
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.render_priority = 5
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tool_mesh = MeshInstance3D.new()
	var tool_material: StandardMaterial3D = _material.duplicate()
	tool_material.render_priority = 6
	_tool_mesh.material_override = tool_material
	_tool_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tool_mesh)
	_labels = Node3D.new()
	add_child(_labels)
	GameSingleton.gamestate_updated.connect(_on_gamestate_updated)
	_map_view.ground_changed.connect(_rebuild_all)


## The text in Russian (the keys with the ending _RU of ov_data/localisation), the text of the locale if there is none
func _t(key: String) -> String:
	var russian: String = tr(key + "_RU")
	return russian if russian != key + "_RU" else tr(key)


func _process(_delta: float) -> void:
	if _map_view == null or (_fronts.is_empty() and _plans.is_empty() and _tool_entries.is_empty()):
		return
	var bucket: int = _get_width_bucket()
	if bucket != _width_bucket:
		_rebuild_all()


func _get_width_bucket() -> int:
	return int(round(log(maxf(_map_view.get_camera_height(), 0.01)) / log(1.25)))


func _get_width() -> float:
	return maxf(_map_view.get_camera_height() * WIDTH_PER_CAMERA_HEIGHT, MIN_WIDTH)


## The lines are read again at once (a tool changed them)
func refresh() -> void:
	_signature = ""
	_on_gamestate_updated()


## The highlight of a tool: [{ polylines: Array of PackedVector2Array (map coordinates), colour: Color, dashed: bool }]
func set_tool_highlight(entries: Array) -> void:
	_tool_entries = entries
	_rebuild_tool_mesh()


## The name of a group of armies for the labels: "N-я группа армий" by its place among the groups of the player
func group_label(group_id: int, groups: Array) -> String:
	for index: int in groups.size():
		if int(groups[index][&"id"]) == group_id:
			return _t("PLAN_GROUP_NAME").replace("$N$", str(index + 1))
	return ""


func _on_gamestate_updated() -> void:
	_updates += 1
	var summaries: Array = PlayerSingleton.get_front_summaries()
	var groups: Array = PlayerSingleton.get_army_groups()
	var plan_lines: Array = PlayerSingleton.get_plan_lines()
	var signature: String = str(summaries) + str(plan_lines)
	for group: Dictionary in groups:
		signature += "%d:%s:%d;" % [int(group[&"id"]), str(group[&"colour"]), roundi(float(group.get(&"planning", 0.0)) * 100.0)]
	if signature == _signature and _updates % REFRESH_EVERY_UPDATES != 0:
		return
	_signature = signature
	var group_colours: Dictionary = {}
	for group: Dictionary in groups:
		group_colours[int(group[&"id"])] = group[&"colour"]

	var fronts: Array = []
	var front_by_id: Dictionary = {}
	for summary: Dictionary in summaries:
		var group_id: int = int(summary.get(&"group_id", 0))
		var colour: Color = COLOUR_ATTACK if int(summary[&"mode"]) == 1 else COLOUR_DEFEND
		if group_colours.has(group_id):
			colour = group_colours[group_id]
		var divisions: int = int(summary.get(&"division_count", 0))
		var entry: Dictionary = {
			&"id": int(summary[&"id"]),
			&"group_id": group_id,
			&"enemy_index": int(summary.get(&"enemy_index", -1)),
			&"kind": int(summary.get(&"kind", 0)),
			&"province_numbers": summary.get(&"province_numbers", PackedInt32Array()),
			&"colour": colour,
			&"polylines": PlayerSingleton.get_front_lines(int(summary[&"id"])),
			&"teeth": divisions > 0,
			&"centres": _centres(summary.get(&"province_numbers", PackedInt32Array())),
			&"label": _t("PLAN_FRONT_LABEL").replace("$N$", str(divisions)).replace("$GROUP$", group_label(group_id, groups)) if divisions > 0 and group_id != 0 else "",
		}
		fronts.append(entry)
		front_by_id[int(summary[&"id"])] = summary
	_fronts = fronts

	var plans: Array = []
	var offensive_index: int = 0
	for line: Dictionary in plan_lines:
		var group_id: int = int(line[&"group_id"])
		var colour: Color = group_colours.get(group_id, COLOUR_ATTACK)
		var type: int = int(line[&"type"])
		var targets: PackedVector2Array = _centres(line[&"province_numbers"])
		var entry: Dictionary = {
			&"id": int(line[&"id"]), &"group_id": group_id, &"province_numbers": line[&"province_numbers"],
			&"type": type, &"colour": colour, &"polylines": [], &"centres": targets, &"label": "",
		}
		if type == 0:
			offensive_index += 1
			entry[&"polylines"] = PlayerSingleton.get_offensive_line(int(line[&"id"]))
			var front: Dictionary = front_by_id.get(int(line[&"front_id"]), {})
			entry[&"from"] = _centroid(_centres(front.get(&"province_numbers", PackedInt32Array())))
			entry[&"to"] = _centroid(targets)
			entry[&"label"] = _t("PLAN_OFFENSIVE_LABEL").replace("$N$", str(offensive_index)).replace("$D$", str(int(front.get(&"division_count", 0)))).replace("$GROUP$", group_label(group_id, groups))
			for group: Dictionary in groups:
				if int(group[&"id"]) == group_id and float(group.get(&"planning", 0.0)) > 0.0:
					entry[&"label"] += " (" + _t("PLAN_PLANNING").replace("$P$", str(roundi(float(group[&"planning"]) * 100.0))) + ")"
		elif type == 1:
			entry[&"label"] = group_label(group_id, groups)
		else:
			var port: int = int(line[&"port_number"])
			entry[&"from"] = MapItemSingleton.get_unit_position_by_province_number(port) if port >= 1 else Vector2.ZERO
			entry[&"to"] = _centroid(targets) if not targets.is_empty() else entry[&"from"]
		plans.append(entry)
	_plans = plans
	_make_handles()
	_rebuild_all()


## The circles at the ends: a front has them at the two ends of its line that are the farthest apart, a line of defence at its first and last province
func get_handles() -> Array:
	return _handles


func _make_handles() -> void:
	var handles: Array = []
	for entry: Dictionary in _fronts:
		var ends: Array[Vector2] = []
		for polyline: PackedVector2Array in entry[&"polylines"]:
			if polyline.size() >= 2 and polyline[0].distance_to(polyline[polyline.size() - 1]) > 0.0001:
				ends.append(polyline[0])
				ends.append(polyline[polyline.size() - 1])
		if ends.size() < 2:
			continue
		var first: Vector2 = ends[0]
		var second: Vector2 = ends[1]
		for a: Vector2 in ends:
			for b: Vector2 in ends:
				if a.distance_squared_to(b) > first.distance_squared_to(second):
					first = a
					second = b
		for at_end: bool in [false, true]:
			handles.append({
				&"kind": &"front", &"id": entry[&"id"], &"group_id": entry[&"group_id"], &"enemy_index": entry[&"enemy_index"], &"front_kind": entry[&"kind"],
				&"at_end": at_end, &"point": second if at_end else first, &"other_point": first if at_end else second, &"province_numbers": entry[&"province_numbers"],
			})
	for entry: Dictionary in _plans:
		var centres: PackedVector2Array = entry[&"centres"]
		if int(entry[&"type"]) != 1 or centres.is_empty():
			continue
		for at_end: bool in [false, true]:
			handles.append({
				&"kind": &"defence", &"id": entry[&"id"], &"group_id": entry[&"group_id"], &"at_end": at_end,
				&"point": centres[centres.size() - 1] if at_end else centres[0], &"other_point": centres[0] if at_end else centres[centres.size() - 1],
				&"province_numbers": entry[&"province_numbers"],
			})
	_handles = handles


## The map positions of the provinces (where their units stand)
func _centres(numbers: Variant) -> PackedVector2Array:
	var centres := PackedVector2Array()
	for number: Variant in numbers:
		if int(number) > 0:
			centres.append(MapItemSingleton.get_unit_position_by_province_number(int(number)))
	return centres


func _centroid(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for point: Vector2 in points:
		sum += point
	return sum / float(points.size())


func _ground(point: Vector2) -> Vector3:
	return _map_view.get_ground_position(point) + Vector3(0.0, HEIGHT, 0.0)


func _rebuild_all() -> void:
	_rebuild_mesh()
	_rebuild_tool_mesh()


func _rebuild_mesh() -> void:
	_width_bucket = _get_width_bucket()
	var width: float = _get_width()
	var half_width: float = width * 0.5
	var builder := _MeshBuilder.new()
	for child: Node in _labels.get_children():
		child.queue_free()

	for entry: Dictionary in _fronts:
		var colour: Color = entry[&"colour"]
		var polylines: Array = entry[&"polylines"]
		var world_centres: PackedVector3Array = _world_points(entry[&"centres"])
		for polyline: PackedVector2Array in polylines:
			var points: PackedVector3Array = _world_points(polyline)
			if bool(entry[&"teeth"]):
				_add_teeth(builder, points, world_centres, width, colour.lerp(Color(1.0, 0.45, 0.35), 0.35))
			builder.add_ribbon(points, half_width, colour)
		if not str(entry[&"label"]).is_empty():
			_add_label_along(polylines, str(entry[&"label"]), width, world_centres)

	for entry: Dictionary in _plans:
		var colour: Color = entry[&"colour"]
		match int(entry[&"type"]):
			0:
				var target_centres: PackedVector3Array = _world_points(entry[&"centres"])
				var from: Vector2 = entry[&"from"]
				var to: Vector2 = entry[&"to"]
				if from != Vector2.ZERO and to != Vector2.ZERO:
					_add_big_arrow(builder, _ground(from), _ground(to), width, colour)
				for polyline: PackedVector2Array in entry[&"polylines"]:
					_add_saw(builder, _world_points(polyline), target_centres, width, colour)
				if from != Vector2.ZERO and to != Vector2.ZERO:
					# Along the arrow, past its middle (the label of the front stands at its start)
					_add_label_on(_ground(from).lerp(_ground(to), 0.62), _ground(to) - _ground(from), str(entry[&"label"]), width)
			1:
				# The provinces in the order of the chain (neighbours one after another)
				var chain: PackedVector3Array = _world_points(entry[&"centres"])
				builder.add_ribbon(chain, half_width * 0.35, Color(colour.r, colour.g, colour.b, 0.6))
				_add_crosses(builder, chain, width, colour)
			2:
				var from: Vector2 = entry[&"from"]
				var to: Vector2 = entry[&"to"]
				if from != Vector2.ZERO and to != from:
					_add_dashed_arc(builder, _ground(from), _ground(to), width, colour)

	# The circles at the ends (the handles)
	for handle: Dictionary in _handles:
		builder.add_disc(_ground(handle[&"point"]), width * CIRCLE_RADIUS_WIDTHS, Color(0.95, 0.88, 0.7, 0.35))
		builder.add_ring(_ground(handle[&"point"]), width * CIRCLE_RADIUS_WIDTHS, width * 0.35, Color(0.95, 0.88, 0.7, 0.85))

	mesh = builder.make_mesh()


func _rebuild_tool_mesh() -> void:
	if _tool_mesh == null:
		return
	var width: float = _get_width()
	var builder := _MeshBuilder.new()
	for entry: Dictionary in _tool_entries:
		var colour: Color = entry[&"colour"]
		for polyline: PackedVector2Array in entry[&"polylines"]:
			var points: PackedVector3Array = _world_points(polyline)
			if bool(entry.get(&"dashed", false)):
				_add_dashes(builder, points, width * 0.5, colour, width)
			else:
				builder.add_ribbon(points, width * 0.5, colour)
	_tool_mesh.mesh = builder.make_mesh()


func _world_points(points: PackedVector2Array) -> PackedVector3Array:
	var world := PackedVector3Array()
	for point: Vector2 in points:
		world.append(_ground(point))
	return world


## The side away from the nearest of the centres (our provinces for a front, the targets for an offensive, reversed)
func _outward(middle: Vector3, centres: PackedVector3Array, direction: Vector3) -> Vector3:
	var side := Vector3(-direction.z, 0.0, direction.x)
	if centres.is_empty():
		return side
	var nearest: Vector3 = centres[0]
	for centre: Vector3 in centres:
		if centre.distance_squared_to(middle) < nearest.distance_squared_to(middle):
			nearest = centre
	return side if side.dot(middle - nearest) >= 0.0 else -side


## The teeth of a front with divisions: short bars across the line on the side of the enemy
func _add_teeth(builder: _MeshBuilder, points: PackedVector3Array, centres: PackedVector3Array, width: float, colour: Color) -> void:
	var spacing: float = width * TOOTH_SPACING_WIDTHS
	_walk(points, spacing, func(at: Vector3, direction: Vector3) -> void:
		var out: Vector3 = _outward(at, centres, direction)
		var half: Vector3 = direction * width * 0.5
		builder.add_quad(at - half, at + half, at + half + out * width * TOOTH_LENGTH_WIDTHS, at - half + out * width * TOOTH_LENGTH_WIDTHS, colour)
	)


## The saw of the line of an offensive: triangles pointing away from the targets
func _add_saw(builder: _MeshBuilder, points: PackedVector3Array, targets: PackedVector3Array, width: float, colour: Color) -> void:
	builder.add_ribbon(points, width * 0.3, colour)
	_walk(points, width * SAW_SPACING_WIDTHS, func(at: Vector3, direction: Vector3) -> void:
		var out: Vector3 = _outward(at, targets, direction)
		var half: Vector3 = direction * width * SAW_SPACING_WIDTHS * 0.5
		builder.add_triangle(at - half, at + half, at + out * width * SAW_LENGTH_WIDTHS, colour)
	)


func _add_crosses(builder: _MeshBuilder, points: PackedVector3Array, width: float, colour: Color) -> void:
	var size: float = width * CROSS_SIZE_WIDTHS
	_walk(points, width * CROSS_SPACING_WIDTHS, func(at: Vector3, direction: Vector3) -> void:
		var side := Vector3(-direction.z, 0.0, direction.x)
		for diagonal: Vector3 in [(direction + side).normalized(), (direction - side).normalized()]:
			var across := Vector3(-diagonal.z, 0.0, diagonal.x) * width * 0.35
			builder.add_quad(at - diagonal * size - across, at - diagonal * size + across, at + diagonal * size + across, at + diagonal * size - across, colour)
	)


## Calls the function every spacing along the polyline (the first one half a spacing from the start) with the point and the direction there
func _walk(points: PackedVector3Array, spacing: float, call: Callable) -> void:
	if points.size() < 2 or spacing <= 0.0:
		return
	var carried: float = spacing * 0.5
	for i: int in range(1, points.size()):
		var from: Vector3 = points[i - 1]
		var to: Vector3 = points[i]
		var length: float = from.distance_to(to)
		if length < 0.000001:
			continue
		var direction: Vector3 = (to - from) / length
		direction.y = 0.0
		direction = direction.normalized()
		var position: float = spacing - carried
		while position <= length:
			call.call(from + (to - from) * (position / length), direction)
			position += spacing
		carried = length - (position - spacing)


func _add_dashes(builder: _MeshBuilder, points: PackedVector3Array, half_width: float, colour: Color, width: float) -> void:
	var dash: float = width * DASH_WIDTHS
	var gap: float = width * GAP_WIDTHS
	var drawing: bool = true
	var left: float = dash
	var current := PackedVector3Array()
	if points.size() < 2:
		return
	current.append(points[0])
	for i: int in range(1, points.size()):
		var from: Vector3 = points[i - 1]
		var to: Vector3 = points[i]
		var length: float = from.distance_to(to)
		var done: float = 0.0
		while length - done > left:
			done += left
			var at: Vector3 = from.lerp(to, done / length)
			if drawing:
				current.append(at)
				builder.add_ribbon(current, half_width, colour)
				current = PackedVector3Array()
				left = gap
			else:
				current.append(at)
				left = dash
			drawing = not drawing
		left -= length - done
		if drawing:
			current.append(to)
		else:
			current = PackedVector3Array([to])
	if drawing and current.size() >= 2:
		builder.add_ribbon(current, half_width, colour)


## The wide arrow of an offensive from the front to its targets: a bent band and a head, pale with a darker edge
func _add_big_arrow(builder: _MeshBuilder, from: Vector3, to: Vector3, width: float, colour: Color) -> void:
	var length: float = from.distance_to(to)
	if length < width * ARROW_HEAD_WIDTHS:
		return
	var direction: Vector3 = (to - from) / length
	var side := Vector3(-direction.z, 0.0, direction.x)
	var control: Vector3 = (from + to) * 0.5 + side * length * ARROW_BEND
	var head_length: float = width * ARROW_HEAD_WIDTHS
	var curve := PackedVector3Array()
	const STEPS: int = 24
	for step: int in STEPS + 1:
		var t: float = float(step) / float(STEPS) * (1.0 - head_length / length)
		curve.append(from.lerp(control, t).lerp(control.lerp(to, t), t))
	var fill := Color(colour.r, colour.g, colour.b, 0.55)
	var edge := Color(colour.r * 0.35, colour.g * 0.35, colour.b * 0.35, 0.85)
	var half: float = width * ARROW_WIDTH_WIDTHS * 0.5
	builder.add_ribbon(curve, half, fill)
	builder.add_offset_ribbon(curve, half, width * 0.25, edge)
	builder.add_offset_ribbon(curve, -half, width * 0.25, edge)
	var base: Vector3 = curve[curve.size() - 1]
	var head_direction: Vector3 = (to - base).normalized()
	var head_side := Vector3(-head_direction.z, 0.0, head_direction.x) * half * 1.6
	builder.add_triangle(base + head_side, base - head_side, to, fill)
	builder.add_ribbon(PackedVector3Array([base + head_side, to, base - head_side]), width * 0.25, edge)


func _add_dashed_arc(builder: _MeshBuilder, from: Vector3, to: Vector3, width: float, colour: Color) -> void:
	var length: float = from.distance_to(to)
	var direction: Vector3 = (to - from) / maxf(length, 0.000001)
	var side := Vector3(-direction.z, 0.0, direction.x)
	var control: Vector3 = (from + to) * 0.5 + side * length * 0.3
	var curve := PackedVector3Array()
	for step: int in 25:
		var t: float = float(step) / 24.0
		curve.append(from.lerp(control, t).lerp(control.lerp(to, t), t))
	_add_dashes(builder, curve, width * 0.35, colour, width)
	var last: Vector3 = curve[curve.size() - 2]
	var tip_direction: Vector3 = (to - last).normalized()
	var tip_side := Vector3(-tip_direction.z, 0.0, tip_direction.x) * width * 2.0
	builder.add_triangle(to - tip_direction * width * 4.0 + tip_side, to - tip_direction * width * 4.0 - tip_side, to, colour)


## A label flat on the ground along the middle of the longest polyline, on the side of the centres
func _add_label_along(polylines: Array, text: String, width: float, centres: PackedVector3Array) -> void:
	var best: PackedVector2Array
	for polyline: PackedVector2Array in polylines:
		if polyline.size() > best.size():
			best = polyline
	if best.size() < 2:
		return
	var middle: int = best.size() / 2
	var from: Vector3 = _ground(best[max(middle - 1, 0)])
	var to: Vector3 = _ground(best[min(middle + 1, best.size() - 1)])
	var at: Vector3 = (from + to) * 0.5
	var direction: Vector3 = to - from
	direction.y = 0.0
	if direction.length_squared() < 0.0000001:
		return
	var inward: Vector3 = -_outward(at, centres, direction.normalized())
	_add_label_on(at + inward * width * 3.0, direction, text, width)


func _add_label_on(at: Vector3, direction: Vector3, text: String, width: float) -> void:
	if text.is_empty():
		return
	direction.y = 0.0
	if direction.length_squared() < 0.0000001:
		return
	# The text reads from the left to the right
	if direction.x < 0.0:
		direction = -direction
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = true
	label.render_priority = 7
	label.outline_render_priority = 6
	label.font_size = 32
	label.outline_size = 10
	label.modulate = Color.WHITE
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	label.pixel_size = width * LABEL_HEIGHT_WIDTHS / float(label.font_size)
	label.position = at + Vector3(0.0, HEIGHT, 0.0)
	label.rotation = Vector3(-PI * 0.5, -atan2(direction.z, direction.x), 0.0)
	label.rotation_order = EULER_ORDER_YXZ
	_labels.add_child(label)


## Triangles with vertex colours
class _MeshBuilder:
	var vertices := PackedVector3Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()

	func add_triangle(a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
		var first: int = vertices.size()
		vertices.append_array([a, b, c])
		colours.append_array([colour, colour, colour])
		indices.append_array([first, first + 1, first + 2])

	func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color) -> void:
		var first: int = vertices.size()
		vertices.append_array([a, b, c, d])
		colours.append_array([colour, colour, colour, colour])
		indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])

	func add_ribbon(points: PackedVector3Array, half_width: float, colour: Color) -> void:
		add_offset_ribbon(points, 0.0, half_width, colour)

	## A ribbon of the half width along the polyline moved sideways by the offset
	func add_offset_ribbon(points: PackedVector3Array, offset: float, half_width: float, colour: Color) -> void:
		var count: int = points.size()
		if count < 2:
			return
		var first: int = vertices.size()
		for i: int in count:
			var direction := Vector3.ZERO
			if i > 0:
				direction += (points[i] - points[i - 1]).normalized()
			if i < count - 1:
				direction += (points[i + 1] - points[i]).normalized()
			direction.y = 0.0
			if direction.length_squared() < 0.000001:
				direction = Vector3.RIGHT
			direction = direction.normalized()
			var side := Vector3(-direction.z, 0.0, direction.x)
			vertices.append(points[i] + side * (offset + half_width))
			vertices.append(points[i] + side * (offset - half_width))
			colours.append(colour)
			colours.append(colour)
			if i > 0:
				var a: int = first + (i - 1) * 2
				indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])

	func add_disc(centre: Vector3, radius: float, colour: Color) -> void:
		var first: int = vertices.size()
		vertices.append(centre)
		colours.append(colour)
		for step: int in CIRCLE_SEGMENTS:
			var angle: float = TAU * float(step) / float(CIRCLE_SEGMENTS)
			vertices.append(centre + Vector3(cos(angle), 0.0, sin(angle)) * radius)
			colours.append(colour)
			indices.append_array([first, first + 1 + step, first + 1 + (step + 1) % CIRCLE_SEGMENTS])

	func add_ring(centre: Vector3, radius: float, half_width: float, colour: Color) -> void:
		var points := PackedVector3Array()
		for step: int in CIRCLE_SEGMENTS + 1:
			var angle: float = TAU * float(step) / float(CIRCLE_SEGMENTS)
			points.append(centre + Vector3(cos(angle), 0.0, sin(angle)) * radius)
		add_ribbon(points, half_width, colour)

	func make_mesh() -> ArrayMesh:
		if vertices.is_empty():
			return null
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colours
		arrays[Mesh.ARRAY_INDEX] = indices
		var array_mesh := ArrayMesh.new()
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return array_mesh
