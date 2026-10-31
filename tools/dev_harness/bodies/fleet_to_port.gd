	# A fleet of the player is ordered into a port: the order, the route and the place after a few days
	PlayerSingleton.toggle_paused()
	var fleets: Array = []
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and stack.get(&"is_navy", false):
			fleets.append(stack)
	print("DEVCHECK player fleets=", fleets.size())
	if fleets.is_empty():
		return
	var fleet: Dictionary = fleets[0]
	var fleet_id: int = int(fleet[&"army_ids"][0])
	var details: Dictionary = PlayerSingleton.get_army_details(fleet_id)
	print("DEVCHECK fleet=", details.get(&"name"), " province=", details.get(&"province_name"), " docked=", details.get(&"docked"))
	# Orders into the province of the fleet and its neighbours: the port provinces of the country are those the game lets a fleet dock in
	var accepted: Array = []
	for number: int in range(1, 400):
		if PlayerSingleton.move_army(fleet_id, number):
			accepted.append(number)
			if accepted.size() >= 5:
				break
	print("DEVCHECK accepted province numbers=", accepted)
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(4.0).timeout
	PlayerSingleton.toggle_paused()
	details = PlayerSingleton.get_army_details(fleet_id)
	print("DEVCHECK after: province=", details.get(&"province_name"), " moving=", details.get(&"is_moving"), " docked=", details.get(&"docked"))
	await get_tree().create_timer(2.0).timeout
	await _devshot("plain_start")
