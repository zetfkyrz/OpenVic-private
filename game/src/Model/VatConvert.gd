## Turns a model that is animated by a skeleton and an animation player (the processor evaluates both every frame) into one whose animation
## is played by the video card (vertex animation textures, see VatBake.gd and the shaders unit_vat.gdshader, unit_vat_attach.gdshader,
## flag_vat.gdshader). Only the models that it can do exactly are converted (the materials are the ones of units and flags, the parts that
## are carried by bones do not animate by themselves); the others stay as they are.

const _Bake := preload("res://src/Model/VatBake.gd")
const _BODY_SHADER: Shader = preload("res://src/Model/unit_vat.gdshader")
const _ATTACH_SHADER: Shader = preload("res://src/Model/unit_vat_attach.gdshader")
const _FLAG_SHADER: Shader = preload("res://src/Model/flag_vat.gdshader")
const _PLAIN_SHADER: Shader = preload("res://src/Model/plain_vat.gdshader")
const _PLAIN_ATTACH_SHADER: Shader = preload("res://src/Model/plain_vat_attach.gdshader")
const _MAX_FRAMES_PER_CLIP: int = 24
# Waving cloth needs more frames than the walk of a soldier (its cycle is long and every part of it moves)
const _MAX_FRAMES_PER_CLIP_FLAG: int = 80
const _FRAMES_PER_SECOND: float = 12.0
const _MIN_FRAMES_PER_CLIP: int = 4

## Switch: the models are made as before when off
static var enabled: bool = true
# key of the model -> {asset} or false when the model cannot be converted
static var _assets: Dictionary = {}
# instance id of a mesh that has bones -> the same mesh in its rest pose without bones
static var _rest_meshes: Dictionary = {}
static var converted_models: int = 0
static var skipped_models: int = 0
static var bake_milliseconds: float = 0.0


## What the baked models take: the number of baked models and the memory of their textures (positions and normals, 8 bytes a texel)
static func get_stats() -> Dictionary:
	var bytes: int = 0
	var count: int = 0
	for asset: Variant in _assets.values():
		if asset is Dictionary:
			count += 1
			var width: int = asset[&"width"]
			var texels: int = asset[&"vertex_count"] * int((asset[&"clips"] as Array).back().x + (asset[&"clips"] as Array).back().y)
			bytes += texels * 16
	return { &"assets": count, &"bytes": bytes, &"converted": converted_models, &"skipped": skipped_models, &"bake_ms": bake_milliseconds }


static func _is_unit_material(material: Material) -> bool:
	return material == XACLoader.unit_shader


static func _is_flag_material(material: Material) -> bool:
	return material == XACLoader.flag_shader


## The ordinary material of the loader (a texture with alpha, a normal map): ships and the blobs of shadows
static func _is_plain_material(material: Material) -> bool:
	return material is StandardMaterial3D


static func _is_known_material(material: Material) -> bool:
	return _is_unit_material(material) or _is_flag_material(material) or _is_plain_material(material)


## All the mesh instances below a node
static func _mesh_instances(node: Node, result: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	if node is MeshInstance3D:
		result.append(node)
	for child: Node in node.get_children():
		_mesh_instances(child, result)
	return result


## The models whose parts are only carried by bones (a helmet, a rifle) and the meshes that are skinned by the skeleton of the model.
## Returns {} when something does not fit
static func _inspect(unit: UnitModel) -> Dictionary:
	var skeleton: Skeleton3D = unit.skeleton
	var bodies: Array[MeshInstance3D] = _Bake.get_skinned_meshes(skeleton)
	if bodies.is_empty():
		return {}
	for body: MeshInstance3D in bodies:
		for surface: int in body.mesh.get_surface_count():
			if not _is_known_material(body.mesh.surface_get_material(surface)):
				return {}
	var attachments: Array = []
	for child: Node in skeleton.get_children():
		var bone_attachment: BoneAttachment3D = child as BoneAttachment3D
		if bone_attachment == null:
			continue
		for carried: Node in bone_attachment.get_children():
			var carried_unit: UnitModel = carried as UnitModel
			if carried_unit != null and carried_unit.anim_player != null:
				return {} # it moves by itself (a rider on a horse): not done yet
			for mesh_instance: MeshInstance3D in _mesh_instances(carried):
				if mesh_instance.mesh == null:
					continue
				for surface: int in mesh_instance.mesh.get_surface_count():
					var material: Material = mesh_instance.mesh.surface_get_material(surface)
					if not (_is_unit_material(material) or _is_plain_material(material)):
						return {}
			attachments.append([bone_attachment.bone_idx, bone_attachment, carried])
	return { &"bodies": bodies, &"attachments": attachments }


static func try_convert(model: Node3D, key: String) -> bool:
	if not enabled:
		return false
	var unit: UnitModel = model as UnitModel
	if unit == null or unit.skeleton == null or unit.anim_player == null:
		return false
	var inspected: Dictionary = _inspect(unit)
	if inspected.is_empty():
		skipped_models += 1
		return false
	var asset: Variant = _assets.get(key)
	if asset == null:
		var start: int = Time.get_ticks_usec()
		asset = _bake_asset(unit, inspected)
		bake_milliseconds += float(Time.get_ticks_usec() - start) / 1000.0
		_assets[key] = asset
	if asset is bool:
		skipped_models += 1
		return false
	_apply(unit, inspected, asset)
	converted_models += 1
	return true


static func _bake_asset(unit: UnitModel, inspected: Dictionary) -> Variant:
	var skeleton: Skeleton3D = unit.skeleton
	var bodies: Array[MeshInstance3D] = inspected[&"bodies"]
	var paths: Array[StringName] = [unit._idle_anim_path, unit._move_anim_path, unit._attack_anim_path]
	var fallback: StringName = &""
	for path: StringName in paths:
		if not path.is_empty() and unit.anim_player.has_animation(path):
			fallback = path
			break
	if fallback.is_empty():
		return false

	var max_frames: int = _MAX_FRAMES_PER_CLIP
	for body: MeshInstance3D in bodies:
		if _is_flag_material(body.mesh.surface_get_material(0)):
			max_frames = _MAX_FRAMES_PER_CLIP_FLAG
	var bone_count: int = skeleton.get_bone_count()
	var skin_all: PackedFloat32Array = PackedFloat32Array()
	var poses_all: PackedFloat32Array = PackedFloat32Array()
	var clips: Array[Vector4] = []
	var total_frames: int = 0
	for i: int in 3:
		var path: StringName = paths[i] if (not paths[i].is_empty() and unit.anim_player.has_animation(paths[i])) else fallback
		var length: float = unit.anim_player.get_animation(path).length
		var frames: int = clampi(ceili(length * _FRAMES_PER_SECOND), _MIN_FRAMES_PER_CLIP, max_frames)
		var sampled: Dictionary = _Bake.sample_clip(skeleton, unit.anim_player, path, frames)
		skin_all.append_array(sampled[&"skin"])
		poses_all.append_array(sampled[&"poses"])
		clips.append(Vector4(total_frames, frames, length, 0.0))
		total_frames += frames
	# The model goes back to the pose it had
	unit.anim_player.stop()
	skeleton.reset_bone_poses()

	var vertices: Dictionary = _Bake.collect_vertices(bodies)
	var baked: Dictionary = VATBaker.bake_skinned(
		vertices[&"positions"], vertices[&"normals"], vertices[&"bone_ids"], vertices[&"weights"], 4,
		skin_all, bone_count, total_frames, _Bake.TEXTURE_WIDTH
	)
	if baked.is_empty():
		return false
	var asset: Dictionary = {
		&"positions": ImageTexture.create_from_image(baked["positions"]),
		&"normals": ImageTexture.create_from_image(baked["normals"]),
		&"width": baked["width"],
		&"vertex_count": (vertices[&"positions"] as PackedVector3Array).size(),
		&"clips": clips,
		&"bones": ImageTexture.create_from_image(VATBaker.bake_matrices(poses_all, bone_count, total_frames)),
		&"attach_materials": {},
		&"plain_materials": {},
	}
	asset[&"unit_material"] = _make_material(_BODY_SHADER, asset, XACLoader.unit_shader)
	asset[&"flag_material"] = _make_flag_material(asset)

	# the meshes of the body with the number of the vertex (the shaders find the vertex in the textures by it)
	var meshes: Dictionary = {}
	for entry: Array in vertices[&"ranges"]:
		var source: MeshInstance3D = entry[0]
		var mesh: ArrayMesh = ArrayMesh.new()
		for surface: int in source.mesh.get_surface_count():
			var arrays: Array = source.mesh.surface_get_arrays(surface)
			var start: int = entry[1][surface][0]
			var count: int = entry[1][surface][1]
			var ids: PackedVector2Array = PackedVector2Array()
			ids.resize(count)
			for i: int in count:
				ids[i] = Vector2(float(start + i), 0.0)
			arrays[Mesh.ARRAY_TEX_UV2] = ids
			arrays[Mesh.ARRAY_BONES] = null
			arrays[Mesh.ARRAY_WEIGHTS] = null
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var original: Material = source.mesh.surface_get_material(surface)
			var replacement: Material = asset[&"unit_material"]
			if _is_flag_material(original):
				replacement = asset[&"flag_material"]
			elif _is_plain_material(original):
				replacement = _plain_material(asset, original, false, -1)
			mesh.surface_set_material(surface, replacement)
		meshes[source.name] = mesh
	asset[&"meshes"] = meshes
	return asset


static func _copy_parameters(material: ShaderMaterial, from: ShaderMaterial, names: Array[StringName]) -> void:
	for parameter_name: StringName in names:
		var value: Variant = from.get_shader_parameter(parameter_name)
		if value != null:
			material.set_shader_parameter(parameter_name, value)


static func _make_material(shader: Shader, asset: Dictionary, colours: ShaderMaterial) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"vat_positions", asset[&"positions"])
	material.set_shader_parameter(&"vat_normals", asset[&"normals"])
	material.set_shader_parameter(&"vat_width", asset[&"width"])
	material.set_shader_parameter(&"vat_vertex_count", asset[&"vertex_count"])
	material.set_shader_parameter(&"vat_clips", asset[&"clips"])
	_copy_parameters(material, colours, [&"texture_diffuse", &"texture_nation_colors_mask"])
	return material


static func _make_flag_material(asset: Dictionary) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _FLAG_SHADER
	material.set_shader_parameter(&"vat_positions", asset[&"positions"])
	material.set_shader_parameter(&"vat_normals", asset[&"normals"])
	material.set_shader_parameter(&"vat_width", asset[&"width"])
	material.set_shader_parameter(&"vat_vertex_count", asset[&"vertex_count"])
	material.set_shader_parameter(&"vat_clips", asset[&"clips"])
	_copy_parameters(material, XACLoader.flag_shader, [&"flag_dims", &"texture_flag_sheet_diffuse", &"texture_normal"])
	return material


## The ShaderMaterial that does what a StandardMaterial3D of the loader does and plays the animation (of the body, or of the bone that carries a part)
static func _plain_material(asset: Dictionary, source: Material, attached: bool, bone: int) -> ShaderMaterial:
	var materials: Dictionary = asset[&"plain_materials"]
	var key: String = "%d|%s|%d" % [source.get_instance_id(), attached, bone]
	var material: ShaderMaterial = materials.get(key)
	if material != null:
		return material
	material = ShaderMaterial.new()
	var standard: StandardMaterial3D = source
	if attached:
		material.shader = _PLAIN_ATTACH_SHADER
		material.set_shader_parameter(&"vat_bones", asset[&"bones"])
		material.set_shader_parameter(&"vat_bone", bone)
		material.set_shader_parameter(&"vat_clips", asset[&"clips"])
	else:
		material.shader = _PLAIN_SHADER
		material.set_shader_parameter(&"vat_positions", asset[&"positions"])
		material.set_shader_parameter(&"vat_normals", asset[&"normals"])
		material.set_shader_parameter(&"vat_width", asset[&"width"])
		material.set_shader_parameter(&"vat_vertex_count", asset[&"vertex_count"])
		material.set_shader_parameter(&"vat_clips", asset[&"clips"])
	var albedo: Texture2D = standard.get_texture(BaseMaterial3D.TEXTURE_ALBEDO)
	if albedo != null:
		material.set_shader_parameter(&"albedo_texture", albedo)
		material.set_shader_parameter(&"use_albedo_texture", true)
	if standard.normal_enabled:
		var normal: Texture2D = standard.get_texture(BaseMaterial3D.TEXTURE_NORMAL)
		if normal != null:
			material.set_shader_parameter(&"normal_texture", normal)
			material.set_shader_parameter(&"use_normal_texture", true)
	materials[key] = material
	return material


static func _attach_material(asset: Dictionary, bone: int) -> ShaderMaterial:
	var materials: Dictionary = asset[&"attach_materials"]
	var material: ShaderMaterial = materials.get(bone)
	if material == null:
		material = ShaderMaterial.new()
		material.shader = _ATTACH_SHADER
		material.set_shader_parameter(&"vat_bones", asset[&"bones"])
		material.set_shader_parameter(&"vat_bone", bone)
		material.set_shader_parameter(&"vat_clips", asset[&"clips"])
		_copy_parameters(material, XACLoader.unit_shader, [&"texture_diffuse", &"texture_nation_colors_mask"])
		materials[bone] = material
	return material


## A mesh that was skinned by a skeleton that never moves: the same mesh without bones (its rest pose is what the skinning gives)
static func _rest_mesh(source: Mesh) -> ArrayMesh:
	var id: int = source.get_instance_id()
	var cached: ArrayMesh = _rest_meshes.get(id)
	if cached != null:
		return cached
	var mesh: ArrayMesh = ArrayMesh.new()
	for surface: int in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface)
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_rest_meshes[id] = mesh
	return mesh


static func _apply(unit: UnitModel, inspected: Dictionary, asset: Dictionary) -> void:
	var meshes: Dictionary = asset[&"meshes"]
	var skeleton: Skeleton3D = unit.skeleton
	var instances: Array[MeshInstance3D] = []
	for body: MeshInstance3D in inspected[&"bodies"]:
		body.mesh = meshes[body.name]
		body.skeleton = NodePath()
		instances.append(body)
	# What is carried by bones goes where the bone goes (the shader does it), the model is no longer under the bone
	for entry: Array in inspected[&"attachments"]:
		var bone: int = entry[0]
		var bone_attachment: BoneAttachment3D = entry[1]
		var carried: Node3D = entry[2]
		var material: ShaderMaterial = _attach_material(asset, bone)
		for mesh_instance: MeshInstance3D in _mesh_instances(carried):
			if mesh_instance.mesh == null:
				continue
			var source_mesh: Mesh = mesh_instance.mesh
			mesh_instance.mesh = _rest_mesh(source_mesh)
			mesh_instance.skeleton = NodePath()
			for surface: int in source_mesh.get_surface_count():
				var original: Material = source_mesh.surface_get_material(surface)
				mesh_instance.set_surface_override_material(
					surface, material if _is_unit_material(original) else _plain_material(asset, original, true, bone)
				)
			instances.append(mesh_instance)
		var carried_unit: UnitModel = carried as UnitModel
		if carried_unit != null and carried_unit.skeleton != null:
			carried_unit.skeleton.free()
			carried_unit.skeleton = null
		bone_attachment.remove_child(carried)
		unit.add_child(carried)
		bone_attachment.free()
	unit.anim_player.free()
	unit.anim_player = null
	skeleton.free()
	unit.skeleton = null
	unit.vat_instances = instances
	unit.vat_phase = randf() * 10.0
	unit.vat_apply()
