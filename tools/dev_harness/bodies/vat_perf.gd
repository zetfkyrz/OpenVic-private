	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var cam: Camera3D = _map_view._camera
	var mm: Node = _model_manager
	var units: Array = ModelSingleton.get_units()
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
	var world: Vector3 = _map_view._map_to_world_coords(best)
	var thr: float = _map_view.get_detailed_threshold()
	var measure := func(label: String) -> void:
		await get_tree().create_timer(1.0).timeout
		var t0: int = Time.get_ticks_usec()
		var n: int = 0
		while Time.get_ticks_usec() - t0 < 3000000:
			await get_tree().process_frame
			n += 1
		var active: int = 0
		for node: Node in mm.get_children():
			if node.process_mode != Node.PROCESS_MODE_DISABLED:
				active += 1
		print("DEVCHECK ", label, ": ", snappedf(3000.0 / n, 0.01), " ms/frame, in view ", active, ", players ", mm.find_children("*", "AnimationPlayer", true, false).size(), ", skeletons ", mm.find_children("*", "Skeleton3D", true, false).size())
	for factor: float in [0.7, 0.45]:
		cam.position = Vector3(world.x, thr * factor, world.z + thr * factor * 0.6)
		_map_view._zoom_target = cam.position.y
		await measure.call("VAT on, height %.2f" % factor)
		await _devshot("perf_vat_on_%d" % int(factor * 100))
	mm.set_vat_enabled(false)
	for factor: float in [0.7, 0.45]:
		cam.position = Vector3(world.x, thr * factor, world.z + thr * factor * 0.6)
		_map_view._zoom_target = cam.position.y
		await measure.call("VAT off, height %.2f" % factor)
	print("DEVCHECK models=", mm.get_child_count())
