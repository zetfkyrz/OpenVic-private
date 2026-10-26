	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var cam: Camera3D = _map_view._camera
	var mm: Node = _model_manager
	var units: Array = ModelSingleton.get_units()
	print("DEVCHECK units=", units.size())
	# densest place: the unit with most others within 0.6 map-units
	var best: Vector2 = Vector2.ZERO
	var best_n: int = 0
	for u: Dictionary in units:
		var p: Vector2 = u[&"position"]
		var n: int = 0
		for v: Dictionary in units:
			if p.distance_to(v[&"position"]) < 0.012:
				n += 1
		if n > best_n:
			best_n = n
			best = p
	print("DEVCHECK densest ", best, " n=", best_n)
	var world: Vector3 = _map_view._map_to_world_coords(best)
	var thr: float = _map_view.get_detailed_threshold()
	var measure := func(label: String) -> void:
		await get_tree().create_timer(0.8).timeout
		var t0: int = Time.get_ticks_usec()
		var n: int = 0
		while Time.get_ticks_usec() - t0 < 3000000:
			await get_tree().process_frame
			n += 1
		var active: int = 0
		var players: int = 0
		for node: Node in mm.get_children():
			if node.process_mode != Node.PROCESS_MODE_DISABLED:
				active += 1
		print("DEVCHECK ", label, ": ", snappedf(3000.0 / n, 0.01), " ms/frame, animated models ", active, " of ", mm.get_child_count())
	for factor: float in [0.7, 0.45]:
		cam.position = Vector3(world.x, thr * factor, world.z + thr * factor * 0.6)
		_map_view._zoom_target = cam.position.y
		await measure.call("height %.1f x threshold, culling on" % factor)
		await _devshot("dense_%d" % int(factor * 10))
	# every animated model at 15 Hz instead of every frame (manual advance)
	var players_list: Array[Node] = mm.find_children("*", "AnimationPlayer", true, false)
	print("DEVCHECK animation players: ", players_list.size())
	cam.position = Vector3(world.x, thr * 0.5, world.z + thr * 0.5 * 0.6)
	_map_view._zoom_target = cam.position.y
	mm.set_process(false)
	await measure.call("animation stopped (no advance at all)")
	var meshes: int = 0
	var skinned: int = 0
	for n: Node in mm.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
		if (n as MeshInstance3D).skin != null or (n as MeshInstance3D).skeleton != NodePath():
			skinned += 1
	print("DEVCHECK mesh instances=", meshes, " skinned=", skinned, " skeletons=", mm.find_children("*", "Skeleton3D", true, false).size())
	mm.visible = false
	await measure.call("models hidden")
