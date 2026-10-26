	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vp: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	print("DEVCHECK vsync=", DisplayServer.window_get_vsync_mode(), " max_fps=", Engine.max_fps, " window=", get_window().size, " mode=", get_window().mode)
	for phase: String in ["paused", "speed3"]:
		if phase == "speed3":
			PlayerSingleton.toggle_paused()
			PlayerSingleton.increase_speed()
			PlayerSingleton.increase_speed()
		await get_tree().create_timer(2.0).timeout
		var frames: Array[float] = []
		var process_ms: float = 0.0
		var cpu_ms: float = 0.0
		var gpu_ms: float = 0.0
		var count: int = 0
		var end: int = Time.get_ticks_msec() + 8000
		while Time.get_ticks_msec() < end:
			var delta: float = get_process_delta_time()
			await get_tree().process_frame
			frames.append(delta * 1000.0)
			process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			count += 1
		frames.sort()
		var sum: float = 0.0
		for value: float in frames:
			sum += value
		print("DEVCHECK ", phase, ": frames=", count, " avg=", snappedf(sum / count, 0.1), " ms median=", snappedf(frames[count / 2], 0.1), " p95=", snappedf(frames[int(count * 0.95)], 0.1), " | script process=", snappedf(process_ms / count, 0.1), " ms, render cpu=", snappedf(cpu_ms / count, 0.1), " gpu=", snappedf(gpu_ms / count, 0.1))
