	await get_tree().create_timer(2.0).timeout
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(0.5).timeout
	for i in 4:
		PlayerSingleton.increase_speed()
		await get_tree().create_timer(0.4).timeout
	print("DEVCHECK clock ", GameSingleton.get_clock_info())
	await get_tree().create_timer(3.0).timeout
	var frames: Array[float] = []
	var end: int = Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
		frames.append(get_process_delta_time() * 1000.0)
	var over12: int = 0
	var over20: int = 0
	var over40: int = 0
	var worst: float = 0.0
	var sum: float = 0.0
	for value: float in frames:
		sum += value
		worst = maxf(worst, value)
		if value > 12.0:
			over12 += 1
		if value > 20.0:
			over20 += 1
		if value > 40.0:
			over40 += 1
	var days: int = int(GameSingleton.get_sim_profile().size())
	print("DEVCHECK frames=", frames.size(), " avg=", snappedf(sum / frames.size(), 0.01), " >12ms=", over12, " >20ms=", over20, " >40ms=", over40, " worst=", snappedf(worst, 0.1))
	print("DEVCHECK clock ", GameSingleton.get_clock_info(), " info=", GameSingleton.get_simulation_thread_info()["wait_calls"])
