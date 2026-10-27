	var vb: GDScript = load("res://src/Model/VatBake.gd")
	var mm: Node = _model_manager
	mm.set_process(false)
	var unit: UnitModel = null
	for n: Node in mm.get_children():
		if n is UnitModel and String(n.name).find("Infantry") >= 0 and (n as UnitModel).skeleton != null:
			unit = n
			break
	unit.process_mode = Node.PROCESS_MODE_INHERIT
	var skeleton: Skeleton3D = unit.skeleton
	var player: AnimationPlayer = unit.anim_player
	var clip_path: StringName = unit._move_anim_path
	print("DEVCHECK clip=", clip_path, " idle=", unit._idle_anim_path, " attack=", unit._attack_anim_path, " current=", player.current_animation, " lib=", player.get_animation_library_list())
	var meshes: Array[MeshInstance3D] = vb.get_skinned_meshes(skeleton)
	var verts: Dictionary = vb.collect_vertices(meshes)
	var frames: int = 16
	var clip: Dictionary = vb.sample_clip(skeleton, player, clip_path, frames)
	var baked: Dictionary = vb.bake_clip(verts, clip)
	var length: float = clip["length"]
	print("DEVCHECK length=", length, " bones=", clip["bones"])
	# 1. the pose the live skeleton has after a seek vs the sampled one
	for f: int in [0, 5, 11]:
		player.play(clip_path)
		player.pause()
		player.seek(length * float(f) / float(frames), true)
		skeleton.force_update_all_bone_transforms()
		var worst: float = 0.0
		var worst_bone: int = -1
		var poses: PackedFloat32Array = clip["poses"]
		for b: int in skeleton.get_bone_count():
			var live: Transform3D = skeleton.get_bone_global_pose(b)
			var base: int = (f * skeleton.get_bone_count() + b) * 12
			var sampled_origin: Vector3 = Vector3(poses[base + 9], poses[base + 10], poses[base + 11])
			var d: float = live.origin.distance_to(sampled_origin)
			if d > worst:
				worst = d
				worst_bone = b
		print("DEVCHECK frame ", f, ": live pose vs sampled pose, worst distance=", worst, " bone ", worst_bone, " (", skeleton.get_bone_name(worst_bone) if worst_bone >= 0 else "", ")")
		# 2. CPU skinning in script of the vertex 0 and 2000, with the live skeleton vs the baked texel
		var image: Image = baked["position_image"]
		var vertex_count: int = baked["vertex_count"]
		for v: int in [0, 2000, 4000]:
			var p: Vector3 = (verts[&"positions"] as PackedVector3Array)[v]
			var acc: Vector3 = Vector3.ZERO
			var wsum: float = 0.0
			for i: int in 4:
				var w: float = (verts[&"weights"] as PackedFloat32Array)[v * 4 + i]
				if w <= 0.0:
					continue
				var bone: int = (verts[&"bone_ids"] as PackedInt32Array)[v * 4 + i]
				var skin: Transform3D = skeleton.get_bone_global_pose(bone) * skeleton.get_bone_global_rest(bone).affine_inverse()
				acc += w * (skin * p)
				wsum += w
			var texel: int = f * vertex_count + v
			var c: Color = image.get_pixel(texel % baked["width"], texel / baked["width"])
			print("DEVCHECK   vertex ", v, " weights=", wsum, " script=", acc, " baked=", Vector3(c.r, c.g, c.b), " rest=", p)
