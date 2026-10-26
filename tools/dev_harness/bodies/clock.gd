	print("DEVCHECK before: ", GameSingleton.get_clock_info(), " thread=", GameSingleton.is_simulation_thread_enabled())
	PlayerSingleton.toggle_paused()
	for i in 6:
		await get_tree().create_timer(1.0).timeout
		print("DEVCHECK t=", i, " ", GameSingleton.get_clock_info(), " info=", GameSingleton.get_simulation_thread_info()["busy"], " today=", GameSingleton.get_clock_info())
	PlayerSingleton.increase_speed()
	PlayerSingleton.increase_speed()
	await get_tree().create_timer(3.0).timeout
	print("DEVCHECK after speed: ", GameSingleton.get_clock_info())
