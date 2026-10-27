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
	unit.process_mode = Node.PROCESS_MODE_INHERIT
	var skeleton: Skeleton3D = unit.skeleton
	var player: AnimationPlayer = unit.anim_player
	var clip_path: StringName = unit._move_anim_path
	var meshes: Array[MeshInstance3D] = vb.get_skinned_meshes(skeleton)
	var verts: Dictionary = vb.collect_vertices(meshes)
	var frames: int = 26
	var clip: Dictionary = vb.sample_clip(skeleton, player, clip_path, frames)
	var baked: Dictionary = vb.bake_clip(verts, clip)
	var length: float = clip["length"]
	var image: Image = baked["position_image"]
	var vertex_count: int = baked["vertex_count"]
	var world: Vector3 = unit.global_position
	cam.position = world + Vector3(0.0, 0.07, 0.05)
	cam.look_at(world + Vector3(0.0, 0.01, 0.0))
	_map_view._zoom_target = cam.position.y
	var overlay: Node3D = Node3D.new()
	unit.get_parent().add_child(overlay)
	# the live unit is advanced the way the game does it (no seek)
	player.play(clip_path)
	for step: int in 3:
		player.advance(0.1)
		await get_tree().process_frame
		var t: float = player.current_animation_position
		var f: int = int(round(t / length * float(frames))) % frames
		print("DEVCHECK step ", step, " animation position=", t, " of ", length, " -> frame ", f)
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
			var ghost: StandardMaterial3D = StandardMaterial3D.new()
			ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ghost.albedo_color = Color(1.0, 0.0, 1.0, 0.55)
			ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ghost.cull_mode = BaseMaterial3D.CULL_DISABLED
			instance.material_override = ghost
			overlay.add_child(instance)
			for parameter: StringName in [&"colour_primary", &"colour_secondary", &"colour_tertiary", &"tex_index_diffuse", &"tex_index_specular"]:
				instance.set_instance_shader_parameter(parameter, source.get_instance_shader_parameter(parameter))
		overlay.global_transform = unit.global_transform * Transform3D(Basis(), Vector3(0.0, 0, 0))
		await get_tree().create_timer(0.1).timeout
		await _devshot("vat_overlay2_step%d" % step)
		player.advance(0.0)
