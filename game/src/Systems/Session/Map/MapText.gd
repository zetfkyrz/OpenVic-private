class_name MapText
extends Node3D

const _province_name_scale: float = 1.0 / 48.0

@export var _map_view: MapView

var _province_name_font: Font
# The setting "Map Text Size" (0.5..2) scales every name, a new value is applied within half a second
var _text_size: float = 1.0
var _size_timer: Timer


func _ready() -> void:
	_province_name_font = AssetManager.get_font(&"mapfont_56")
	_text_size = _get_text_size_setting()
	_size_timer = Timer.new()
	_size_timer.wait_time = 0.5
	_size_timer.autostart = true
	_size_timer.timeout.connect(_check_text_size)
	add_child(_size_timer)


func _get_text_size_setting() -> float:
	return clampf(float(GameSettings.get_setting(GameSettings.VIDEO_MAP_TEXT_SIZE).value()), 0.5, 2.0)


func _check_text_size() -> void:
	var wanted: float = _get_text_size_setting()
	if is_equal_approx(wanted, _text_size):
		return
	_text_size = wanted
	for child: Node in get_children():
		if child is Label3D and child.has_meta(&"base_scale"):
			(child as Label3D).scale = (child.get_meta(&"base_scale") as Vector3) * _text_size


func _clear_children() -> void:
	var child_count: int = get_child_count()
	while child_count > 0:
		child_count -= 1
		var child: Node = get_child(child_count)
		remove_child(child)
		child.queue_free()


func _on_ground_changed() -> void:
	# Names stand on the ground: placed again when the relief is baked
	generate_map_names()


func generate_map_names() -> void:
	if _map_view and not _map_view.ground_changed.is_connected(_on_ground_changed):
		_map_view.ground_changed.connect(_on_ground_changed)
	_clear_children()

	for dict: Dictionary in GameSingleton.get_province_names():
		_add_province_name(dict)


func _add_province_name(dict: Dictionary) -> void:
	const identifier_key: StringName = &"identifier"
	const position_key: StringName = &"position"
	const rotation_key: StringName = &"rotation"
	const scale_key: StringName = &"scale"

	var label: Label3D = Label3D.new()

	label.set_draw_flag(Label3D.FLAG_DOUBLE_SIDED, false)
	label.set_modulate(Color.BLACK)
	label.set_outline_size(0)
	label.set_font(_province_name_font)
	label.set_vertical_alignment(VERTICAL_ALIGNMENT_BOTTOM)

	var identifier: String = dict[identifier_key]
	label.set_name(identifier)
	label.set_text(GUINode.format_province_name(identifier))

	label.set_position(_map_view._map_to_ground_coords(dict[position_key]) + Vector3(0, 0.001, 0))

	label.rotate_x(-PI / 2)
	label.rotate_y(dict.get(rotation_key, 0.0))

	label.scale *= dict.get(scale_key, 1.0) * _province_name_scale
	label.set_meta(&"base_scale", label.scale)
	label.scale *= _text_size

	add_child(label)
