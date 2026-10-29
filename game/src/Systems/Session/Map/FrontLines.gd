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
	if signature == _signature and _updates % REFRESH_EVERY_UPDATES != 0:
		return
	_signature = signature
	var lines: Dictionary = {}
	for summary: Dictionary in summaries:
		var front_id: int = summary[&"id"]
		lines[front_id] = {
			&"mode": summary[&"mode"],
			&"polylines": PlayerSingleton.get_front_lines(front_id),
		}
	_lines = lines
	_rebuild_mesh()


func _rebuild_mesh() -> void:
	_width_bucket = _get_width_bucket()
	var half_width: float = _get_width() * 0.5
	var vertices := PackedVector3Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()

	for front_id: int in _lines:
		var entry: Dictionary = _lines[front_id]
		var colour: Color = COLOUR_ATTACK if int(entry[&"mode"]) == 1 else COLOUR_DEFEND
		for polyline: PackedVector2Array in entry[&"polylines"]:
			_add_ribbon(polyline, half_width, colour, vertices, colours, indices)

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
