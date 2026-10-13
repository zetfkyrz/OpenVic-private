class_name ModelManager
extends Node3D

const MODEL_SCALE: float = 1.0 / 256.0

@export var _map_view: MapView

# Unit icons (the flags above units) are drawn 20% closer than the models and are 20% smaller.
const UNIT_ICON_RANGE_FACTOR: float = 0.8
const UNIT_ICON_SCALE_FACTOR: float = 0.8

# Flags of the units currently on the map, shown only when the camera is close enough
var _flag_nodes: Array[Node3D] = []
var _icons_visible: bool = false

# Unit models currently on the map and the signature of the units they were generated from,
# the models are regenerated when an army moves, appears or is destroyed
var _unit_nodes: Array[Node3D] = []
var _units_signature: int = 0


func _process(_delta: float) -> void:
	if not _map_view:
		return

	# The draw distance setting (-50..+50 %) scales the distance at which models and unit icons are drawn
	var factor: float = 1.0 + float(GameSettings.get_setting(GameSettings.VIDEO_DRAW_DISTANCE).value()) / 100.0
	var model_range: float = _map_view.get_detailed_threshold() * factor
	var height: float = _map_view.get_camera_height()

	var models_visible: bool = height <= model_range
	if visible != models_visible:
		visible = models_visible

	var icons_visible: bool = height <= model_range * UNIT_ICON_RANGE_FACTOR
	if icons_visible != _icons_visible:
		_icons_visible = icons_visible
		for flag: Node3D in _flag_nodes:
			if is_instance_valid(flag):
				flag.visible = _icons_visible


func generate_units() -> void:
	XACLoader.setup_flag_shader()

	var units: Array[Dictionary] = ModelSingleton.get_units()
	_units_signature = _get_units_signature(units)
	for unit: Dictionary in units:
		_generate_unit(unit)

	if not GameSingleton.gamestate_updated.is_connected(_refresh_units):
		GameSingleton.gamestate_updated.connect(_refresh_units)


func _get_units_signature(units: Array[Dictionary]) -> int:
	var signature: int = units.size()
	for unit: Dictionary in units:
		signature = hash([signature, unit.get(&"position"), unit.get(&"flag_index"), unit.get(&"model")])
	return signature


func _refresh_units() -> void:
	var units: Array[Dictionary] = ModelSingleton.get_units()
	var signature: int = _get_units_signature(units)
	if signature == _units_signature:
		return
	_units_signature = signature

	for node in _unit_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_unit_nodes.clear()
	_flag_nodes.clear()

	for unit: Dictionary in units:
		_generate_unit(unit)


func _generate_unit(unit_dict: Dictionary) -> void:
	const culture_key: StringName = &"culture"
	const model_key: StringName = &"model"
	const mount_model_key: StringName = &"mount_model"
	const mount_attach_node_key: StringName = &"mount_attach_node"
	const flag_index_key: StringName = &"flag_index"
	const flag_floating_key: StringName = &"flag_floating"
	const position_key: StringName = &"position"
	const rotation_key: StringName = &"rotation"
	const primary_colour_key: StringName = &"primary_colour"
	const secondary_colour_key: StringName = &"secondary_colour"
	const tertiary_colour_key: StringName = &"tertiary_colour"

	var model: Node3D = _generate_model(unit_dict[model_key], unit_dict[culture_key])
	if not model:
		return

	if mount_model_key in unit_dict and mount_attach_node_key in unit_dict:
		# This must be a UnitModel so we can attach the rider to it
		var mount_model: Node3D = _generate_model(
			unit_dict[mount_model_key],
			unit_dict[culture_key],
			true,
		)
		if mount_model:
			if mount_model.attach_model(unit_dict[mount_attach_node_key], model) == OK:
				model = mount_model
			else:
				mount_model.free()

	var rotation: float = unit_dict.get(rotation_key, 0.0)

	var flag_dict: Dictionary = ModelSingleton.get_flag_model(unit_dict.get(flag_floating_key, false))
	if flag_dict:
		var flag_model: UnitModel = _generate_model(flag_dict, "", true)
		if flag_model:
			flag_model.set_flag_index(unit_dict[flag_index_key])
			flag_model.current_anim = UnitModel.Anim.IDLE
			flag_model.scale /= model.scale
			flag_model.scale *= UNIT_ICON_SCALE_FACTOR
			flag_model.rotate_y(-rotation)
			flag_model.visible = _icons_visible
			_flag_nodes.append(flag_model)

			model.add_child(flag_model)

	model.scale *= MODEL_SCALE
	model.rotate_y(PI + rotation)
	model.set_position(_map_view._map_to_world_coords(unit_dict[position_key]) + Vector3(0, 0.1 * MODEL_SCALE, 0))

	if model is UnitModel:
		model.current_anim = UnitModel.Anim.IDLE

		model.primary_colour = unit_dict[primary_colour_key]
		model.secondary_colour = unit_dict[secondary_colour_key]
		model.tertiary_colour = unit_dict[tertiary_colour_key]

	add_child(model)
	_unit_nodes.append(model)


func generate_buildings() -> void:
	for building: Dictionary in ModelSingleton.get_buildings():
		_generate_building(building)


func _generate_building(building_dict: Dictionary) -> void:
	const model_key: StringName = &"model"
	const position_key: StringName = &"position"
	const rotation_key: StringName = &"rotation"

	var model: Node3D = _generate_model(building_dict[model_key])
	if not model:
		return

	model.scale *= MODEL_SCALE
	model.rotate_y(PI + building_dict.get(rotation_key, 0.0))
	model.set_position(_map_view._map_to_world_coords(building_dict[position_key]) + Vector3(0, 0.1 * MODEL_SCALE, 0))

	add_child(model)


func _generate_model(model_dict: Dictionary, culture: String = "", is_unit: bool = false) -> Node3D:
	const file_key: StringName = &"file"
	const scale_key: StringName = &"scale"
	const idle_key: StringName = &"idle"
	const move_key: StringName = &"move"
	const attack_key: StringName = &"attack"
	const attachments_key: StringName = &"attachments"

	const animation_file_key: StringName = &"file"
	const animation_time_key: StringName = &"time"

	const attachment_node_key: StringName = &"node"
	const attachment_model_key: StringName = &"model"

	# Model
	is_unit = is_unit or (
		# Needed for animations
		idle_key in model_dict or move_key in model_dict or attack_key in model_dict
		# Currently needs UnitModel's attach_model helper function
		or attachments_key in model_dict
	)

	var model: Node3D = XACLoader.get_xac_model(model_dict[file_key], is_unit)
	if not model:
		return null
	model.scale *= model_dict[scale_key]

	if model is UnitModel:
		# Animations
		var idle_dict: Dictionary = model_dict.get(idle_key, {})
		if idle_dict:
			model.set_idle_anim(XSMLoader.get_xsm_animation(idle_dict[animation_file_key]))
			model.scroll_speed_idle = idle_dict[animation_time_key]

		var move_dict: Dictionary = model_dict.get(move_key, {})
		if move_dict:
			model.set_move_anim(XSMLoader.get_xsm_animation(move_dict[animation_file_key]))
			model.scroll_speed_move = move_dict[animation_time_key]

		var attack_dict: Dictionary = model_dict.get(attack_key, {})
		if attack_dict:
			model.set_attack_anim(XSMLoader.get_xsm_animation(attack_dict[animation_file_key]))
			model.scroll_speed_attack = attack_dict[animation_time_key]

		# Attachments
		for attachment_dict: Dictionary in model_dict.get(attachments_key, []):
			var attachment_model: Node3D = _generate_model(
				attachment_dict[attachment_model_key],
				culture,
			)
			if attachment_model and model.attach_model(
				attachment_dict[attachment_node_key],
				attachment_model,
			) != OK:
				attachment_model.free()

		if culture:
			const gun_bone_name: String = "GunNode"
			if model.has_bone(gun_bone_name):
				var gun_dict: Dictionary = ModelSingleton.get_cultural_gun_model(culture)
				if gun_dict:
					var gun_model: Node3D = _generate_model(gun_dict, culture)
					if gun_model and model.attach_model(gun_bone_name, gun_model) != OK:
						gun_model.free()

			const helmet_bone_name: String = "HelmetNode"
			if model.has_bone(helmet_bone_name):
				var helmet_dict: Dictionary = ModelSingleton.get_cultural_helmet_model(culture)
				if helmet_dict:
					var helmet_model: Node3D = _generate_model(helmet_dict, culture)
					if helmet_model and model.attach_model(helmet_bone_name, helmet_model) != OK:
						helmet_model.free()

	return model
