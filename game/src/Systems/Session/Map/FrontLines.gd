class_name FrontLines
extends MeshInstance3D
## The fronts of the player drawn along the borders of the provinces (docs/PLAN_ARMY_SUPPLY_FRONTS.md, section 5): the line of a front is the
## border between the provinces of its line and the land next to them that we do not control. A red line is a front that attacks, a blue one
## defends. The lines are made by PlayerSingleton.get_front_lines (pixel edges of the province map, simplified) and drawn as ribbons on the ground.

const HEIGHT: float = 0.004
const WIDTH_PER_CAMERA_HEIGHT: float = 0.014
const MIN_WIDTH: float = 0.003
const COLOUR_ATTACK: Color = Color(0.95, 0.05, 0.03, 1.0)
const COLOUR_DEFEND: Color = Color(0.05, 0.3, 1.0, 1.0)
## The arrows of an attack plan: one every this many widths of the line (at most MAX_ARROWS per front), as long as ARROW_LENGTH widths
const ARROW_SPACING_WIDTHS: float = 40.0
const ARROW_LENGTH_WIDTHS: float = 12.0
const ARROW_HEAD_WIDTHS: float = 5.0
const MAX_ARROWS: int = 10

## The colours of the groups of armies (field marshals) by id, for the fronts they hold
var _group_colours: Dictionary = {}
## The borders change when provinces are taken: the lines are made again every this many updates of the game state
const REFRESH_EVERY_UPDATES: int = 30

var _map_view: MapView
var _signature: String = ""
var _lines: Dictionary = {} # front id -> { "mode": int, "polylines": Array }
var _width_bucket: int = -1
var _updates: int = 0
var _material: StandardMaterial3D


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
	GameSingleton.gamestate_updated.connect(_on_gamestate_updated)
	_map_view.ground_changed.connect(_rebuild_mesh)


func _process(_delta: float) -> void:
	if _map_view == null or _lines.is_empty():
		return
	var bucket: int = _get_width_bucket()
	if bucket != _width_bucket:
		_rebuild_mesh()


func _get_width_bucket() -> int:
	return int(round(log(maxf(_map_view.get_camera_height(), 0.01)) / log(1.25)))


func _get_width() -> float:
	return maxf(_map_view.get_camera_height() * WIDTH_PER_CAMERA_HEIGHT, MIN_WIDTH)


func _on_gamestate_updated() -> void:
	_updates += 1
	var summaries: Array = PlayerSingleton.get_front_summaries()
	var signature: String = str(summaries)
	for group: Dictionary in PlayerSingleton.get_army_groups():
		signature += "%d:%s:%d:%d;" % [int(group[&"id"]), str(group[&"colour"]), int(group[&"plan_front_id"]), int(group[&"plan_mode"])]
	if signature == _signature and _updates % REFRESH_EVERY_UPDATES != 0:
		return
	_signature = signature
	# The fronts that a field marshal holds are drawn in his colour (dimmer while his plan does not run)
	var group_colours: Dictionary = {}
	for group: Dictionary in PlayerSingleton.get_army_groups():
		group_colours[int(group[&"id"])] = group[&"colour"]
	_group_colours = group_colours
	# The fronts with an attack plan of a marshal get arrows (the plan mode 0 is the attack)
	var attack_fronts: Dictionary = {}
	for group: Dictionary in PlayerSingleton.get_army_groups():
		if int(group[&"plan_front_id"]) != 0 and int(group[&"plan_mode"]) == 0:
			attack_fronts[int(group[&"plan_front_id"])] = true
	var province_positions: PackedVector2Array = MapItemSingleton.get_province_positions()
	var lines: Dictionary = {}
	for summary: Dictionary in summaries:
		var front_id: int = summary[&"id"]
		lines[front_id] = {
			&"mode": summary[&"mode"],
			&"group_id": int(summary.get(&"group_id", 0)),
			&"commanded": bool(summary.get(&"commanded", true)),
			&"polylines": PlayerSingleton.get_front_lines(front_id),
			&"arrows": attack_fronts.has(front_id),
			&"centres": _province_centres(summary, province_positions),
		}
	_lines = lines
	_rebuild_mesh()


## The map positions of the provinces of the line of a front (an arrow starts on the side of them)
func _province_centres(summary: Dictionary, province_positions: PackedVector2Array) -> PackedVector2Array:
	var centres := PackedVector2Array()
	for number: Variant in summary.get(&"province_numbers", []):
		var index: int = int(number) - 1
		if index >= 0 and index < province_positions.size():
			centres.append(province_positions[index])
	return centres


func _rebuild_mesh() -> void:
	_width_bucket = _get_width_bucket()
	var half_width: float = _get_width() * 0.5
	var vertices := PackedVector3Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()

	for front_id: int in _lines:
		var entry: Dictionary = _lines[front_id]
		var colour: Color = COLOUR_ATTACK if int(entry[&"mode"]) == 1 else COLOUR_DEFEND
		if int(entry[&"group_id"]) != 0 and _group_colours.has(int(entry[&"group_id"])):
			colour = _group_colours[int(entry[&"group_id"])]
			if not bool(entry[&"commanded"]):
				colour.a = 0.45
		for polyline: PackedVector2Array in entry[&"polylines"]:
			_add_ribbon(polyline, half_width, colour, vertices, colours, indices)
		if bool(entry[&"arrows"]):
			_add_arrows(entry[&"polylines"], entry[&"centres"], half_width, colour, vertices, colours, indices)

	if vertices.is_empty():
		mesh = null
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = array_mesh


func _add_ribbon(
	polyline: PackedVector2Array, half_width: float, colour: Color,
	vertices: PackedVector3Array, colours: PackedColorArray, indices: PackedInt32Array
) -> void:
	var count: int = polyline.size()
	if count < 2:
		return
	var points := PackedVector3Array()
	for point: Vector2 in polyline:
		points.append(_map_view.get_ground_position(point) + Vector3(0.0, HEIGHT, 0.0))

	var first: int = vertices.size()
	for i: int in count:
		# The direction of the line at the point: the average of the two segments that meet there
		var direction := Vector3.ZERO
		if i > 0:
			direction += (points[i] - points[i - 1]).normalized()
		if i < count - 1:
			direction += (points[i + 1] - points[i]).normalized()
		direction.y = 0.0
		if direction.length_squared() < 0.000001:
			direction = Vector3.RIGHT
		direction = direction.normalized()
		var side := Vector3(-direction.z, 0.0, direction.x) * half_width
		vertices.append(points[i] + side)
		vertices.append(points[i] - side)
		colours.append(colour)
		colours.append(colour)
		if i > 0:
			var a: int = first + (i - 1) * 2
			indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])


## The arrows of an attack plan: along the line, every so often, from the side of our provinces to the other side of the border
func _add_arrows(
	polylines: Array, centres: PackedVector2Array, half_width: float, colour: Color,
	vertices: PackedVector3Array, colours: PackedColorArray, indices: PackedInt32Array
) -> void:
	if centres.is_empty():
		return
	var world_centres := PackedVector3Array()
	for centre: Vector2 in centres:
		world_centres.append(_map_view.get_ground_position(centre))
	var total: float = 0.0
	for polyline: PackedVector2Array in polylines:
		for i: int in range(1, polyline.size()):
			total += _map_view.get_ground_position(polyline[i]).distance_to(_map_view.get_ground_position(polyline[i - 1]))
	var spacing: float = maxf(half_width * 2.0 * ARROW_SPACING_WIDTHS, total / float(MAX_ARROWS))
	var carried: float = spacing * 0.5
	for polyline: PackedVector2Array in polylines:
		for i: int in range(1, polyline.size()):
			var from: Vector3 = _map_view.get_ground_position(polyline[i - 1])
			var to: Vector3 = _map_view.get_ground_position(polyline[i])
			var length: float = from.distance_to(to)
			carried += length
			if carried < spacing or length < 0.00001:
				continue
			carried = 0.0
			var middle: Vector3 = (from + to) * 0.5
			# Outward: away from the nearest province of the line
			var nearest: Vector3 = world_centres[0]
			for centre: Vector3 in world_centres:
				if centre.distance_squared_to(middle) < nearest.distance_squared_to(middle):
					nearest = centre
			var direction: Vector3 = middle - nearest
			direction.y = 0.0
			if direction.length_squared() < 0.000001:
				continue
			_add_arrow(middle, direction.normalized(), half_width, colour, vertices, colours, indices)


func _add_arrow(
	base: Vector3, direction: Vector3, half_width: float, colour: Color,
	vertices: PackedVector3Array, colours: PackedColorArray, indices: PackedInt32Array
) -> void:
	var lift := Vector3(0.0, HEIGHT, 0.0)
	var side := Vector3(-direction.z, 0.0, direction.x)
	var shaft_end: Vector3 = base + direction * half_width * 2.0 * (ARROW_LENGTH_WIDTHS - ARROW_HEAD_WIDTHS)
	var tip: Vector3 = base + direction * half_width * 2.0 * ARROW_LENGTH_WIDTHS
	var first: int = vertices.size()
	# The shaft (a quad) and the head (a triangle)
	vertices.append(base + side * half_width + lift)
	vertices.append(base - side * half_width + lift)
	vertices.append(shaft_end + side * half_width + lift)
	vertices.append(shaft_end - side * half_width + lift)
	vertices.append(shaft_end + side * half_width * ARROW_HEAD_WIDTHS * 0.5 + lift)
	vertices.append(shaft_end - side * half_width * ARROW_HEAD_WIDTHS * 0.5 + lift)
	vertices.append(tip + lift)
	for _i: int in 7:
		colours.append(colour)
	indices.append_array([first, first + 1, first + 2, first + 1, first + 3, first + 2, first + 4, first + 5, first + 6])
