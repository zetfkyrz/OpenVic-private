	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().create_timer(1.0).timeout
	var measure := func() -> float:
		await get_tree().create_timer(0.3).timeout
		var t0: int = Time.get_ticks_usec()
		var n: int = 0
		while Time.get_ticks_usec() - t0 < 1500000:
			await get_tree().process_frame
			n += 1
		return 1500.0 / n
	var base: float = await measure.call()
	print("DEVCHECK baseline ", snappedf(base, 0.1))
	var candidates: Array[Node] = []
	for child: Node in get_children():
		candidates.append(child)
	for child: Node in get_tree().root.get_children():
		if child != self and child != get_parent():
			candidates.append(child)
	candidates.append(get_parent())
	for node: Node in candidates:
		var old_mode: Node.ProcessMode = node.process_mode
		node.process_mode = Node.PROCESS_MODE_DISABLED
		var ms: float = await measure.call()
		node.process_mode = old_mode
		print("DEVCHECK disable ", node.name, " (", node.get_class(), " ", node.get_script().resource_path if node.get_script() else "", "): ", snappedf(ms, 0.1))
