	var vb: GDScript = load("res://src/Model/VatBake.gd")
	var mm: Node = _model_manager
	mm.set_process(false)
	mm.visible = true
	var cam: Camera3D = _map_view._camera
	var unit: UnitModel = null
	for n: Node in mm.get_children():
		if n is UnitModel and String(n.name).find("Infantry") >= 0 and (n as UnitModel).skeleton != null:
			unit = n
			break
	print("DEVCHECK unit=", unit.name if unit else "none")
	unit.process_mode = Node.PROCESS_MODE_INHERIT
	var skeleton: Skeleton3D = unit.skeleton
	var meshes: Array[MeshInstance3D] = vb.get_skinned_meshes(skeleton)
	print("DEVCHECK skinned meshes=", meshes.size(), " bones=", skeleton.get_bone_count())
	var t0: int = Time.get_ticks_usec()
	var verts: Dictionary = vb.collect_vertices(meshes)
	var t1: int = Time.get_ticks_usec()
	var frames: int = 16
	var clip_path: StringName = unit._move_anim_path
	var clip: Dictionary = vb.sample_clip(skeleton, unit.anim_player, clip_path, frames)
	var t2: int = Time.get_ticks_usec()
	var baked: Dictionary = vb.bake_clip(verts, clip)
	var t3: int = Time.get_ticks_usec()
	print("DEVCHECK vertices=", baked["vertex_count"], " collect=", (t1 - t0) / 1000, "ms sample=", (t2 - t1) / 1000, "ms bake=", (t3 - t2) / 1000, "ms texture=", baked["width"], "x", baked["height"])
	var image: Image = baked["position_image"]
	var vertex_count: int = baked["vertex_count"]
	var world: Vector3 = unit.global_position
	cam.position = world + Vector3(0.0, 0.07, 0.05)
	cam.look_at(world + Vector3(0.0, 0.01, 0.0))
	_map_view._zoom_target = cam.position.y
	var overlay: Node3D = Node3D.new()
	unit.get_parent().add_child(overlay)
	for f: int in [0, 5, 11]:
		unit.anim_player.play(clip_path)
		unit.anim_player.pause()
		unit.anim_player.seek(float(clip["length"]) * float(f) / float(frames), true)
		for child: Node in overlay.get_children():
			child.free()
		for entry: Array in verts[&"ranges"]:
			var source: MeshInstance3D = entry[0]
			var copy: ArrayMesh = ArrayMesh.new()
			for s: int in source.mesh.get_surface_count():
				var arrays: Array = source.mesh.surface_get_arrays(s)
				var start: int = entry[1][s][0]
				var count: int = entry[1][s][1]
				var new_positions: PackedVector3Array = PackedVector3Array()
				new_positions.resize(count)
				for i: int in count:
					var texel: int = f * vertex_count + start + i
					var c: Color = image.get_pixel(texel % baked["width"], texel / baked["width"])
					new_positions[i] = Vector3(c.r, c.g, c.b)
				arrays[Mesh.ARRAY_VERTEX] = new_positions
				arrays[Mesh.ARRAY_BONES] = null
				arrays[Mesh.ARRAY_WEIGHTS] = null
				copy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				copy.surface_set_material(s, source.mesh.surface_get_material(s))
			var instance: MeshInstance3D = MeshInstance3D.new()
			instance.mesh = copy
			overlay.add_child(instance)
			for parameter: StringName in [&"colour_primary", &"colour_secondary", &"colour_tertiary", &"tex_index_diffuse", &"tex_index_specular"]:
				instance.set_instance_shader_parameter(parameter, source.get_instance_shader_parameter(parameter))
		overlay.global_transform = unit.global_transform * Transform3D(Basis(), Vector3(7.0, 0, 0))
		await get_tree().create_timer(0.3).timeout
		unit.anim_player.seek(float(clip["length"]) * float(f) / float(frames), true)
		unit.skeleton.force_update_all_bone_transforms()
		await get_tree().create_timer(0.3).timeout
		await _devshot("vat_overlay_frame%d" % f)
	# the rest pose: live skeleton reset, overlay from the rest pose
	unit.anim_player.stop()
	unit.skeleton.reset_bone_poses()
	unit.skeleton.force_update_all_bone_transforms()
	var rest_clip: Dictionary = vb.sample_clip(skeleton, null, &"none", 1)
	var rest_baked: Dictionary = vb.bake_clip(verts, rest_clip)
	var rest_image: Image = rest_baked["position_image"]
	for child: Node in overlay.get_children():
		child.free()
	for entry: Array in verts[&"ranges"]:
		var source: MeshInstance3D = entry[0]
		var copy: ArrayMesh = ArrayMesh.new()
		for s: int in source.mesh.get_surface_count():
			var arrays: Array = source.mesh.surface_get_arrays(s)
			var start: int = entry[1][s][0]
			var count: int = entry[1][s][1]
			var new_positions: PackedVector3Array = PackedVector3Array()
			new_positions.resize(count)
			for i: int in count:
				var texel: int = start + i
				var c: Color = rest_image.get_pixel(texel % rest_baked["width"], texel / rest_baked["width"])
				new_positions[i] = Vector3(c.r, c.g, c.b)
			arrays[Mesh.ARRAY_VERTEX] = new_positions
			arrays[Mesh.ARRAY_BONES] = null
			arrays[Mesh.ARRAY_WEIGHTS] = null
			copy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			copy.surface_set_material(s, source.mesh.surface_get_material(s))
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.mesh = copy
		overlay.add_child(instance)
		for parameter: StringName in [&"colour_primary", &"colour_secondary", &"colour_tertiary", &"tex_index_diffuse", &"tex_index_specular"]:
			instance.set_instance_shader_parameter(parameter, source.get_instance_shader_parameter(parameter))
	await get_tree().create_timer(0.6).timeout
	await _devshot("vat_overlay_rest")
