	var mm: Node = _model_manager
	print("DEVCHECK stats ", mm.VatConvert.get_stats())
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(0.5).timeout
	for i in 3:
		PlayerSingleton.increase_speed()
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(15.0).timeout
	print("DEVCHECK after play: ", mm.VatConvert.get_stats(), " models=", mm.get_child_count())
