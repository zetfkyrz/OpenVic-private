	PlayerSingleton.toggle_paused()
	var player_ids: Array[int] = []
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and int(stack.get(&"regiments", 0)) >= 4:
			for army_id: int in stack[&"army_ids"]:
				player_ids.append(army_id)
			break
	for i in 2:
		PlayerSingleton.increase_speed()
	for step in 12:
		await get_tree().create_timer(2.0).timeout
		var d: Dictionary = PlayerSingleton.get_army_details(player_ids[0])
		print("DEVCHECK ", step, " supply=", d.get(&"supply"), " ratio=", d.get(&"supply_ratio"), " reserve=", d.get(&"supply_reserve"), " delivery=", d.get(&"supply_delivery"))
