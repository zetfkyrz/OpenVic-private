	PlayerSingleton.toggle_paused()
	var player_ids: Array[int] = []
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and int(stack.get(&"regiments", 0)) >= 4:
			for army_id: int in stack[&"army_ids"]:
				player_ids.append(army_id)
			break
	var details: Dictionary = PlayerSingleton.get_army_details(player_ids[0])
	print("DEVCHECK organisation=", details.get(&"has_organisation"), " divisions=", details.get(&"divisions"))
	print("DEVCHECK templates=", PlayerSingleton.get_division_templates())
	_army_panel.show_armies(player_ids)
	await get_tree().create_timer(1.0).timeout
	await _devshot("divisions_panel")
	PlayerSingleton.create_division_template(1, 1, 0, 0)
	await get_tree().create_timer(0.6).timeout
	PlayerSingleton.reform_army_to_template(player_ids[0], 0, 2)
	await get_tree().create_timer(0.6).timeout
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.5).timeout
	PlayerSingleton.toggle_paused()
	details = PlayerSingleton.get_army_details(player_ids[0])
	print("DEVCHECK after reform divisions=", details.get(&"divisions"))
	await _devshot("divisions_panel2")
	var nm: GDScript = load("res://src/Utilities/NationManagement.gd")
	Events.NationManagementScreens.open_nation_management_screen(nm.Screen.MILITARY)
	await get_tree().create_timer(1.0).timeout
	await _devshot("military_priority")
