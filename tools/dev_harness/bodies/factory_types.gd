	# The factories of weapons: the drop-down list of the production type on the plate of the factory
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	var overview: Array = PlayerSingleton.get_production_info()
	var found: int = 0
	for state: Dictionary in overview:
		for factory: Dictionary in state.get(&"factories", []):
			var options: Array = factory.get(&"production_options", [])
			if options.size() > 1:
				found += 1
				if found <= 2:
					print("DEVCHECK factory ", factory[&"name"], " options=", options)
	print("DEVCHECK factories with a choice: ", found)
	Events.NationManagementScreens.open_nation_management_screen(NationManagement.Screen.PRODUCTION)
	await get_tree().create_timer(2.0).timeout
	await _devshot("factory_types")
