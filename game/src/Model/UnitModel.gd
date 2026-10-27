class_name UnitModel
extends Node3D

var skeleton: Skeleton3D = null
var anim_player: AnimationPlayer = null
var anim_lib: AnimationLibrary = null
var sub_units: Array[UnitModel]
var meshes: Array[MeshInstance3D]

# VAT: the animation is played by the video card (see VatConvert.gd): there is no skeleton and no animation player, the mesh instances
# that are animated (the body and what is carried by it) get the clip and the phase as instance shader parameters
var vat_instances: Array[MeshInstance3D] = []
var vat_phase: float = 0.0

# COLOUR VARIABLES

@export_group("Colors")
@export var primary_colour: Color:
	set(col_in):
		primary_colour = col_in
		_set_shader_parameter(&"colour_primary", primary_colour)
		for unit: UnitModel in sub_units:
			unit.primary_colour = col_in
@export var secondary_colour: Color:
	set(col_in):
		secondary_colour = col_in
		_set_shader_parameter(&"colour_secondary", secondary_colour)
		for unit: UnitModel in sub_units:
			unit.secondary_colour = col_in
@export var tertiary_colour: Color:
	set(col_in):
		tertiary_colour = col_in
		_set_shader_parameter(&"colour_tertiary", tertiary_colour)
		for unit: UnitModel in sub_units:
			unit.tertiary_colour = col_in

# ANIMATION VARIABLES

var _idle_anim_path: StringName
var _move_anim_path: StringName
var _attack_anim_path: StringName


func set_idle_anim(anim_in: Animation) -> void:
	_idle_anim_path = load_animation("idle", anim_in)


func set_move_anim(anim_in: Animation) -> void:
	_move_anim_path = load_animation("move", anim_in)


func set_attack_anim(anim_in: Animation) -> void:
	_attack_anim_path = load_animation("attack", anim_in)


enum Anim {
	NONE,
	IDLE,
	MOVE,
	ATTACK,
}

const ANIMATION_LIBRARY: StringName = &"default_lib"

@export var current_anim: Anim:
	set(anim_in):
		for unit: UnitModel in sub_units:
			unit.current_anim = anim_in

		if not vat_instances.is_empty():
			current_anim = anim_in
			_apply_vat_clip()
			match anim_in:
				Anim.IDLE:
					_set_tex_scroll(scroll_speed_idle)
				Anim.MOVE:
					_set_tex_scroll(scroll_speed_move)
				Anim.ATTACK:
					_set_tex_scroll(scroll_speed_attack)
				_:
					_set_tex_scroll(0.0)
			return

		if anim_player:
			match anim_in:
				Anim.IDLE:
					if _idle_anim_path:
						anim_player.set_current_animation(_idle_anim_path)
						_set_tex_scroll(scroll_speed_idle)
						current_anim = Anim.IDLE
						return
				Anim.MOVE:
					if _move_anim_path:
						anim_player.set_current_animation(_move_anim_path)
						_set_tex_scroll(scroll_speed_move)
						current_anim = Anim.MOVE
						return
				Anim.ATTACK:
					if _attack_anim_path:
						anim_player.set_current_animation(_attack_anim_path)
						_set_tex_scroll(scroll_speed_attack)
						current_anim = Anim.ATTACK
						return
				_: #None
					pass

			anim_player.stop()

		_set_tex_scroll(0.0)
		current_anim = Anim.NONE
#
# TEXTURE SCROLL SPEEDS (TANKS TRACKS AND SMOKE)
@export_subgroup("Texture_Scroll")
@export var scroll_speed_idle: float:
	set(speed_in):
		scroll_speed_idle = speed_in
		for unit: UnitModel in sub_units:
			unit.scroll_speed_idle = speed_in
@export var scroll_speed_move: float:
	set(speed_in):
		scroll_speed_move = speed_in
		for unit: UnitModel in sub_units:
			unit.scroll_speed_move = speed_in
@export var scroll_speed_attack: float:
	set(speed_in):
		scroll_speed_attack = speed_in
		for unit: UnitModel in sub_units:
			unit.scroll_speed_attack = speed_in


## The clip that plays now and the phase go to the shaders of the meshes that the video card animates
func vat_apply() -> void:
	_apply_vat_clip()
	for sub_unit: UnitModel in sub_units:
		sub_unit.current_anim = current_anim


func _apply_vat_clip() -> void:
	# idle 0, move 1, attack 2 (nothing plays: idle)
	var clip: float = 0.0
	match current_anim:
		Anim.MOVE:
			clip = 1.0
		Anim.ATTACK:
			clip = 2.0
	for mesh_instance: MeshInstance3D in vat_instances:
		if is_instance_valid(mesh_instance):
			mesh_instance.set_instance_shader_parameter(&"vat_clip", clip)
			mesh_instance.set_instance_shader_parameter(&"vat_phase", vat_phase)


func unit_init() -> void:
	for child: Node in get_children():
		if child is MeshInstance3D:
			meshes.append(child)
		elif child is Skeleton3D:
			skeleton = child


func add_anim_player() -> void:
	anim_player = AnimationPlayer.new()
	anim_player.name = "anim_player"

	anim_lib = AnimationLibrary.new()
	anim_lib.resource_name = ANIMATION_LIBRARY
	anim_player.add_animation_library(ANIMATION_LIBRARY, anim_lib)

	add_child(anim_player)


func has_bone(bone_name: String) -> bool:
	return skeleton and skeleton.find_bone(bone_name) > -1


func attach_model(bone_name: String, model: Node3D) -> Error:
	if not model:
		push_error("Cannot attach null model to bone \"", bone_name, "\" of UnitModel ", get_name())
		return FAILED

	if not skeleton:
		push_error(
			"Cannot attach model \"",
			model.get_name(),
			"\" to bone \"",
			bone_name,
			"\" of UnitModel ",
			get_name(),
			" - has no skeleton!",
		)
		return FAILED

	var bone_idx: int = skeleton.find_bone(bone_name)
	if bone_idx < 0 or bone_idx >= skeleton.get_bone_count():
		push_warning(
			"Invalid bone \"",
			bone_name,
			"\" (index ",
			bone_idx,
			") for attachment \"",
			model.get_name(),
			"\" to UnitModel \"",
			get_name(),
			"\"",
		)
		return FAILED

	var bone_attachment := BoneAttachment3D.new()
	bone_attachment.name = bone_name
	bone_attachment.bone_idx = bone_idx
	bone_attachment.add_child(model)
	skeleton.add_child(bone_attachment)

	if model is UnitModel:
		sub_units.push_back(model)
		model.current_anim = current_anim
		model.primary_colour = primary_colour
		model.secondary_colour = secondary_colour
		model.tertiary_colour = tertiary_colour

	return OK


func _set_shader_parameter(param_name: StringName, param_val: Variant) -> void:
	for mesh: MeshInstance3D in meshes:
		mesh.set_instance_shader_parameter(param_name, param_val)


func _set_tex_scroll(speed: float) -> void:
	_set_shader_parameter(&"scroll_speed", speed)


func set_flag_index(index: int) -> void:
	_set_shader_parameter(&"flag_index", index)


func load_animation(prop_name: String, animIn: Animation) -> StringName:
	if not animIn:
		return &""
	if not anim_player:
		add_anim_player()

	var anim_path: StringName = anim_player.find_animation(animIn)
	if anim_path.is_empty():
		anim_lib.add_animation(prop_name, animIn)
		anim_path = anim_player.find_animation(animIn)
	return anim_path
