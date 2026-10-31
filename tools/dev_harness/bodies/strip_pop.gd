	# The strip of the commanders on the main screen and the number of rows of the population list of the player
	PlayerSingleton.toggle_paused()
	PlayerSingleton.create_army_group()
	await get_tree().create_timer(0.6).timeout
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.5).timeout
	print("DEVCHECK groups=", PlayerSingleton.get_army_groups().size())
	print("DEVCHECK population rows=", MenuSingleton.get_population_menu_province_list_row_count())
	await _devshot("commanders_strip")
