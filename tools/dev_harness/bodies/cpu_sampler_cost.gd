	await get_tree().create_timer(2.0).timeout
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(3.0).timeout
	var worst: float = 0.0
	var total: float = 0.0
	for i in 10:
		await get_tree().create_timer(0.5).timeout
		var t0: int = Time.get_ticks_usec()
		var cpu: Dictionary = GameSingleton.get_cpu_usage()
		var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		worst = maxf(worst, ms)
		total += ms
	print("DEVCHECK get_cpu_usage avg=", snappedf(total / 10.0, 0.01), " ms worst=", snappedf(worst, 0.01), " threads listed=", GameSingleton.get_cpu_usage()["threads"].size())
