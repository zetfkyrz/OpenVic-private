## Bakes the animation of a model into textures (vertex animation textures, see VATBaker in the extension), so that the video card plays it:
## the processor does not evaluate skeletons and animation players any more.

const TEXTURE_WIDTH: int = 2048


## The meshes that are skinned by a skeleton (direct children of its parent that point to it)
static func get_skinned_meshes(skeleton: Skeleton3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	var parent: Node = skeleton.get_parent()
	if parent == null:
		return meshes
	for child: Node in parent.get_children():
		var mesh_instance: MeshInstance3D = child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		if mesh_instance.get_node_or_null(mesh_instance.skeleton) == skeleton:
			meshes.append(mesh_instance)
	return meshes


## The matrices that move the rest pose to the pose of every bone: the global pose times the inverse of the global rest pose
## (the bind pose that Godot makes for a mesh without a skin), 12 floats per bone: the columns of the basis and the origin
static func _append_skin_matrices(skeleton: Skeleton3D, matrices: PackedFloat32Array, offset: int) -> void:
	var bone_count: int = skeleton.get_bone_count()
	for bone: int in bone_count:
		var skin: Transform3D = skeleton.get_bone_global_pose(bone) * skeleton.get_bone_global_rest(bone).affine_inverse()
		var base: int = offset + bone * 12
		matrices[base + 0] = skin.basis.x.x
		matrices[base + 1] = skin.basis.x.y
		matrices[base + 2] = skin.basis.x.z
		matrices[base + 3] = skin.basis.y.x
		matrices[base + 4] = skin.basis.y.y
		matrices[base + 5] = skin.basis.y.z
		matrices[base + 6] = skin.basis.z.x
		matrices[base + 7] = skin.basis.z.y
		matrices[base + 8] = skin.basis.z.z
		matrices[base + 9] = skin.origin.x
		matrices[base + 10] = skin.origin.y
		matrices[base + 11] = skin.origin.z


## The poses of the skeleton in the frames of an animation: for every frame the skin matrices of all bones (frame_count * bone_count * 12 floats)
## and the global poses of the bones (the same layout, for the things that are attached to a bone)
static func sample_clip(
	skeleton: Skeleton3D, player: AnimationPlayer, animation_path: StringName, frame_count: int
) -> Dictionary:
	var bone_count: int = skeleton.get_bone_count()
	var skin: PackedFloat32Array = PackedFloat32Array()
	skin.resize(frame_count * bone_count * 12)
	var poses: PackedFloat32Array = PackedFloat32Array()
	poses.resize(frame_count * bone_count * 12)
	var length: float = 1.0
	if player != null and player.has_animation(animation_path):
		length = player.get_animation(animation_path).length
		player.play(animation_path)
		player.pause()
	for frame: int in frame_count:
		if player != null and player.has_animation(animation_path):
			player.seek(length * float(frame) / float(frame_count), true)
		skeleton.force_update_all_bone_transforms()
		_append_skin_matrices(skeleton, skin, frame * bone_count * 12)
		for bone: int in bone_count:
			var pose: Transform3D = skeleton.get_bone_global_pose(bone)
			var base: int = (frame * bone_count + bone) * 12
			poses[base + 0] = pose.basis.x.x
			poses[base + 1] = pose.basis.x.y
			poses[base + 2] = pose.basis.x.z
			poses[base + 3] = pose.basis.y.x
			poses[base + 4] = pose.basis.y.y
			poses[base + 5] = pose.basis.y.z
			poses[base + 6] = pose.basis.z.x
			poses[base + 7] = pose.basis.z.y
			poses[base + 8] = pose.basis.z.z
			poses[base + 9] = pose.origin.x
			poses[base + 10] = pose.origin.y
			poses[base + 11] = pose.origin.z
	return { &"skin": skin, &"poses": poses, &"length": length, &"frames": frame_count, &"bones": bone_count }


## The vertices of all surfaces of the meshes one after another (the rest pose) with the influences of the bones.
## Returns {positions, normals, bone_ids, weights, ranges: Array of [mesh_instance, first_vertex, vertex_count per surface...]}
static func collect_vertices(meshes: Array[MeshInstance3D]) -> Dictionary:
	var positions: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var bone_ids: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	var ranges: Array = []
	for mesh_instance: MeshInstance3D in meshes:
		var mesh: Mesh = mesh_instance.mesh
		var surfaces: Array = []
		for surface: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			var surface_positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var count: int = surface_positions.size()
			surfaces.append([positions.size(), count])
			positions.append_array(surface_positions)
			var surface_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			if surface_normals.size() != count:
				surface_normals = PackedVector3Array()
				surface_normals.resize(count)
				surface_normals.fill(Vector3.UP)
			normals.append_array(surface_normals)
			var bones: Variant = arrays[Mesh.ARRAY_BONES]
			var weight_array: Variant = arrays[Mesh.ARRAY_WEIGHTS]
			var per_vertex: int = 4
			for i: int in count * 4:
				if bones != null and weight_array != null and bones.size() >= count * per_vertex:
					bone_ids.append(int(bones[i]))
					weights.append(float(weight_array[i]))
				else:
					bone_ids.append(0)
					weights.append(0.0)
		ranges.append([mesh_instance, surfaces])
	return {
		&"positions": positions, &"normals": normals, &"bone_ids": bone_ids, &"weights": weights, &"ranges": ranges,
	}


## Bakes one clip of a group of skinned meshes (the skeleton of a model and its meshes): {positions: ImageTexture, normals: ImageTexture,
## width, height, vertex_count, frames, length} and the sampled poses
static func bake_clip(vertices: Dictionary, clip: Dictionary) -> Dictionary:
	var positions: PackedVector3Array = vertices[&"positions"]
	var result: Dictionary = VATBaker.bake_skinned(
		positions, vertices[&"normals"], vertices[&"bone_ids"], vertices[&"weights"], 4,
		clip[&"skin"], clip[&"bones"], clip[&"frames"], TEXTURE_WIDTH
	)
	if result.is_empty():
		return {}
	return {
		&"positions": ImageTexture.create_from_image(result["positions"]),
		&"normals": ImageTexture.create_from_image(result["normals"]),
		&"position_image": result["positions"],
		&"width": result["width"],
		&"height": result["height"],
		&"vertex_count": positions.size(),
		&"frames": clip[&"frames"],
		&"length": clip[&"length"],
	}
