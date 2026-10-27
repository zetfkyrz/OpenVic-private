	var debugger: Node = null
	for child: Node in get_children():
		if child is CanvasLayer and child.has_method("_start_benchmark"):
			debugger = child
	debugger._set_open(true)
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(0.5).timeout
	for i in 2:
		PlayerSingleton.increase_speed()
		await get_tree().create_timer(0.4).timeout
	await get_tree().create_timer(12.0).timeout
	await _devshot("check_graphs")
	debugger._set_tab(1)
	await get_tree().create_timer(1.0).timeout
	await _devshot("check_sim_tab")
	debugger._set_open(false)
	var cam: Camera3D = _map_view._camera
	_map_view._camera.position.y = _map_view.get_detailed_threshold() * 0.4
	_map_view._zoom_target = cam.position.y
	await get_tree().create_timer(2.0).timeout
	await _devshot("check_units")
