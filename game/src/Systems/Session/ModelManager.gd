class_name ModelManager
extends Node3D

const PerfProbe := preload("res://src/Utilities/PerfProbe.gd")

const MODEL_SCALE: float = 1.0 / 256.0

@export var _map_view: MapView

# Unit models currently on the map by the unique id of the unit group they show, and a signature of what they were
# generated from (without their position). A model is only regenerated when what it looks like changes, otherwise
# recreating models whenever an army moves exhausts the renderer's buffer of shader instance variables and the models
# stop being drawn. Moving units glide to their new position and play their walking animation.
var _unit_nodes: Dictionary[int, Node3D] = {}
var _unit_signatures: Dictionary[int, int] = {}
var _building_nodes: Array[Node3D] = []

# Time the models take to move to the position of the next day
const _MOVE_TWEEN_TIME: float = 0.6


# The animations (skeletons and animation players of every unit and building) are what the models cost: Godot plays them on the
# processor for every model every frame (the skinning itself is done by the video card), also for hidden ones and for ones outside of
# the screen (≈17 ms of the main thread for the units of the start of the game). So:
#  - they only run while the models are shown, and only for the models that the camera sees (checked every few frames);
#  - the animation players are not left to Godot: this node advances them itself, and the further the camera is the less often
#    (a model on a far view is a few pixels, nobody sees that it moves at 6 steps a second); the models are advanced in groups, one
#    group per frame, so that the cost does not come in lumps.
const _CULL_INTERVAL: int = 3
# (height of the camera / the distance at which models are drawn up to, steps of animation per second)
const _ANIMATION_RATES: Array[Vector2] = [Vector2(0.25, 30.0), Vector2(0.5, 15.0), Vector2(0.75, 8.0), Vector2(1.01, 5.0)]
const _MAX_ANIMATION_GROUPS: int = 24
var _animating: bool = true
var _cull_frame: int = 0
var _frame_counter: int = 0
# Models that the camera sees (they are animated), and the time that every group of them has waited for its next step
var _in_view: Array[Node3D] = []
var _group_time: PackedFloat32Array = PackedFloat32Array()


func _process(delta: float) -> void:
	if not _map_view:
		return

	# The draw distance setting (-50..+50 %) scales the distance at which models are drawn
	var factor: float = 1.0 + float(GameSettings.get_setting(GameSettings.VIDEO_DRAW_DISTANCE).value()) / 100.0
	var model_range: float = _map_view.get_detailed_threshold() * factor
	var height: float = _map_view.get_camera_height()

	var models_visible: bool = height <= model_range
	if visible != models_visible:
		visible = models_visible

	if models_visible != _animating:
		_animating = models_visible
		for node: Node3D in _unit_nodes.values():
			_set_animated(node, models_visible)
		for node: Node3D in _building_nodes:
			_set_animated(node, models_visible)
		if not models_visible:
			_in_view.clear()
	if models_visible:
		_cull_frame += 1
		if _cull_frame % _CULL_INTERVAL == 0:
			_cull_animation()
		_advance_animations(delta, model_range if model_range > 0.0 else 1.0, height)


func _set_animated(node: Node3D, animated: bool) -> void:
	if not is_instance_valid(node):
		return
	var mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT if animated else Node.PROCESS_MODE_DISABLED
	if node.process_mode != mode:
		node.process_mode = mode


# The animation players of a model (with the ones of the models that are attached to it: the rider, the flag) do not play by themselves
func _take_over_animation(model: Node3D) -> void:
	var players: Array[AnimationPlayer] = []
	for player: Node in model.find_children("*", "AnimationPlayer", true, false):
		var animation_player: AnimationPlayer = player as AnimationPlayer
		animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		players.append(animation_player)
	model.set_meta(&"animation_players", players)


func _advance_animations(delta: float, model_range: float, height: float) -> void:
	var steps_per_second: float = _ANIMATION_RATES[_ANIMATION_RATES.size() - 1].y
	for rate: Vector2 in _ANIMATION_RATES:
		if height / model_range <= rate.x:
			steps_per_second = rate.y
			break
	# One group of the models steps in a frame: as many groups as the frames between two steps of a model
	var groups: int = clampi(roundi(1.0 / (maxf(delta, 0.0001) * steps_per_second)), 1, _MAX_ANIMATION_GROUPS)
	if _group_time.size() != _MAX_ANIMATION_GROUPS:
		_group_time.resize(_MAX_ANIMATION_GROUPS)
	for g: int in _MAX_ANIMATION_GROUPS:
		_group_time[g] += delta
	_frame_counter += 1
	var group: int = _frame_counter % groups
	var elapsed: float = _group_time[group]
	_group_time[group] = 0.0
	# The groups that are not in use wait from the start when they are needed again
	for g: int in range(groups, _MAX_ANIMATION_GROUPS):
		_group_time[g] = 0.0
	var index: int = group
	var count: int = _in_view.size()
	while index < count:
		var node: Node3D = _in_view[index]
		if is_instance_valid(node):
			for player: AnimationPlayer in node.get_meta(&"animation_players", []):
				player.advance(elapsed)
		index += groups


# Models in the view of the camera are animated, the others are stopped
func _cull_animation() -> void:
	var camera: Camera3D = _map_view._camera
	if camera == null:
		return
	_in_view.clear()
	for node: Node3D in _unit_nodes.values():
		if is_instance_valid(node):
			var in_view: bool = camera.is_position_in_frustum(node.global_position)
			_set_animated(node, in_view)
			if in_view:
				_in_view.append(node)
	for node: Node3D in _building_nodes:
		if is_instance_valid(node):
			var in_view: bool = camera.is_position_in_frustum(node.global_position)
			_set_animated(node, in_view)
			if in_view:
				_in_view.append(node)


func generate_units() -> void:
	XACLoader.setup_flag_shader()

	_sync_units()

	if not GameSingleton.gamestate_updated.is_connected(_sync_units):
		GameSingleton.gamestate_updated.connect(_sync_units)
	# The relief is baked a moment after the map is shown: models are placed on the ground again
	if _map_view and not _map_view.ground_changed.is_connected(_on_ground_changed):
		_map_view.ground_changed.connect(_on_ground_changed)


func _on_ground_changed() -> void:
	_sync_units()
	for building: Node3D in _building_nodes:
		var map_position: Vector2 = building.get_meta(&"map_position")
		building.position = _map_view._map_to_standing_coords(map_position) + Vector3(0, 0.1 * MODEL_SCALE, 0)


func _get_unit_signature(unit: Dictionary) -> int:
	return hash([
		unit.get(&"model"), unit.get(&"mount_model"), unit.get(&"flag_index"), unit.get(&"flag_floating"),
		unit.get(&"primary_colour"), unit.get(&"secondary_colour"), unit.get(&"tertiary_colour"),
	])


func _sync_units() -> void:
	PerfProbe.begin("ModelManager._sync_units")
	_sync_units_body()
	PerfProbe.end("ModelManager._sync_units")


func _sync_units_body() -> void:
	var present: Dictionary[int, bool] = {}

	for unit: Dictionary in ModelSingleton.get_units():
		var id: int = unit[&"id"]
		present[id] = true

		var signature: int = _get_unit_signature(unit)
		var node: Node3D = _unit_nodes.get(id)
		if is_instance_valid(node) and _unit_signatures.get(id, 0) == signature:
			_update_unit_node(node, unit)
			continue

		_remove_unit_node(id)

		node = _generate_unit(unit)
		if node:
			node.set_meta(&"moving", unit.get(&"moving", false))
			_unit_nodes[id] = node
			_unit_signatures[id] = signature

	for id: int in _unit_nodes.keys():
		if not present.has(id):
			_remove_unit_node(id)


# Moves an existing model to the position of its unit and plays the matching animation
func _update_unit_node(node: Node3D, unit: Dictionary) -> void:
	var target: Vector3 = _map_view._map_to_standing_coords(unit[&"position"]) + Vector3(0, 0.1 * MODEL_SCALE, 0)
	var moving: bool = unit.get(&"moving", false)

	if not node.position.is_equal_approx(target):
		if node.has_meta(&"tween"):
			var previous_tween: Tween = node.get_meta(&"tween")
			if previous_tween and previous_tween.is_valid():
				previous_tween.kill()
		var tween: Tween = create_tween()
		tween.tween_property(node, "position", target, _MOVE_TWEEN_TIME)
		node.set_meta(&"tween", tween)

	if moving:
		node.rotation.y = PI + unit.get(&"rotation", 0.0)

	if node.get_meta(&"moving", false) != moving:
		node.set_meta(&"moving", moving)
		if node is UnitModel:
			node.current_anim = UnitModel.Anim.MOVE if moving else UnitModel.Anim.IDLE


func _remove_unit_node(id: int) -> void:
	var node: Node3D = _unit_nodes.get(id)
	if is_instance_valid(node):
		remove_child(node)
		node.free()
	_unit_nodes.erase(id)
	_unit_signatures.erase(id)


func _generate_unit(unit_dict: Dictionary) -> Node3D:
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
		return null

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
			flag_model.rotate_y(-rotation)

			model.add_child(flag_model)

	model.scale *= MODEL_SCALE
	model.rotate_y(PI + rotation)
	model.set_position(_map_view._map_to_standing_coords(unit_dict[position_key]) + Vector3(0, 0.1 * MODEL_SCALE, 0))

	if model is UnitModel:
		model.current_anim = UnitModel.Anim.MOVE if unit_dict.get(&"moving", false) else UnitModel.Anim.IDLE

		model.primary_colour = unit_dict[primary_colour_key]
		model.secondary_colour = unit_dict[secondary_colour_key]
		model.tertiary_colour = unit_dict[tertiary_colour_key]

	add_child(model)
	_take_over_animation(model)
	if not _animating:
		_set_animated(model, false)
	return model


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
	model.set_position(_map_view._map_to_standing_coords(building_dict[position_key]) + Vector3(0, 0.1 * MODEL_SCALE, 0))
	model.set_meta(&"map_position", building_dict[position_key])
	_building_nodes.append(model)

	add_child(model)
	_take_over_animation(model)
	if not _animating:
		_set_animated(model, false)


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
