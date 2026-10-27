	PlayerSingleton.toggle_paused()
	var player_ids: Array[int] = []
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and int(stack.get(&"regiments", 0)) >= 4:
			for army_id: int in stack[&"army_ids"]:
				player_ids.append(army_id)
			break
	print("DEVCHECK army ids=", player_ids)
	if player_ids.is_empty():
		return
	var details: Dictionary = PlayerSingleton.get_army_details(player_ids[0])
	print("DEVCHECK details supply=", details.get(&"supply"), " delivery=", details.get(&"supply_delivery"), " send=", details.get(&"supply_send"), " reserve=", details.get(&"supply_reserve"), "/", details.get(&"supply_reserve_capacity"), " priority=", details.get(&"supply_priority"), " own=", details.get(&"supply_priority_own"))
	print("DEVCHECK tooltip: ", String(details.get(&"supply_tooltip", "")).replace("\n", " | "))
	_army_panel.show_armies(player_ids)
	await get_tree().create_timer(1.0).timeout
	await _devshot("supply_army_panel")
	PlayerSingleton.set_army_supply_priority(player_ids[0], 2)
	await get_tree().create_timer(0.5).timeout
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(3.0).timeout
	PlayerSingleton.toggle_paused()
	details = PlayerSingleton.get_army_details(player_ids[0])
	print("DEVCHECK after priority: own=", details.get(&"supply_priority_own"), " effective=", details.get(&"supply_priority"))
	await _devshot("supply_army_panel2")
