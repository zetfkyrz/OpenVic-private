	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var cam: Camera3D = _map_view._camera
	var mm: Node = _model_manager
	cam.position.y = _map_view.get_detailed_threshold() * 0.5
	_map_view._zoom_target = cam.position.y
	await get_tree().create_timer(1.5).timeout
	print("DEVCHECK threshold=", _map_view.get_detailed_threshold(), " camera height=", _map_view.get_camera_height(), " models visible=", mm.visible)
	var measure := func(label: String) -> void:
		await get_tree().create_timer(0.7).timeout
		var t0: int = Time.get_ticks_usec()
		var n: int = 0
		while Time.get_ticks_usec() - t0 < 3000000:
			await get_tree().process_frame
			n += 1
		var active: int = 0
		for node: Node in mm.get_children():
			if node.process_mode != Node.PROCESS_MODE_DISABLED:
				active += 1
		print("DEVCHECK ", label, ": ", snappedf(3000.0 / n, 0.1), " ms/frame, animated models ", active, " of ", mm.get_child_count())
	await measure.call("with culling (new)")
	await _devshot("anim_visible")
	mm.set_process(false)
	for node: Node in mm.get_children():
		node.process_mode = Node.PROCESS_MODE_INHERIT
	await measure.call("everything animated (old behaviour)")
