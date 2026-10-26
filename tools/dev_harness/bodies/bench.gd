	var debugger: Node = null
	for child: Node in get_children():
		if child is CanvasLayer and child.has_method("_start_benchmark"):
			debugger = child
	print("DEVCHECK debugger=", debugger)
	debugger._set_open(true)
	debugger._set_tab(8)
	await get_tree().create_timer(2.0).timeout
	debugger._bench_speed = 2
	debugger._start_benchmark()
	await get_tree().create_timer(30.0).timeout
	await _devshot("bench_cpu_tab")
	await get_tree().create_timer(36.0).timeout
	print("DEVCHECK bench result:\n", debugger._strip_bbcode(debugger._bench_result))
	print("DEVCHECK ", debugger._status.text)
