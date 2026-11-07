	# The preparation of a plan (docs/COMMAND.md): Prussia, a marshal with generals and a front against its biggest neighbour, not executed: the plate says
	# that the divisions hold the line and the planning grows
	PlayerSingleton.toggle_paused()
	PlayerSingleton.set_player_country_by_identifier("PRU")
	PlayerSingleton.create_army_group()
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	PlayerSingleton.toggle_paused()
	var group_id: int = int(PlayerSingleton.get_army_groups()[0][&"id"])
	for general: Dictionary in PlayerSingleton.get_generals():
		if not bool(general[&"is_marshal"]) and int(general[&"army_id"]) == 0:
			PlayerSingleton.set_army_group_marshal(group_id, int(general[&"leader_id"]))
			break
	var attached: int = 0
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and attached < 4:
			for army_id: int in stack[&"army_ids"]:
				PlayerSingleton.set_army_group(army_id, group_id)
				attached += 1
	var neighbour: Dictionary = {}
	for entry: Dictionary in PlayerSingleton.get_border_highlights()[&"neighbours"]:
		if neighbour.is_empty() or (entry[&"edges"] as PackedInt32Array).size() > (neighbour[&"edges"] as PackedInt32Array).size():
			neighbour = entry
	PlayerSingleton.create_border_front(group_id, int(neighbour[&"country_index"]))
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(3.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	await get_tree().create_timer(0.5).timeout
	_command_panel._select_group(group_id)
	await get_tree().create_timer(0.8).timeout
	print("DEVCHECK group ", PlayerSingleton.get_army_groups()[0].get(&"planning"), " active ", PlayerSingleton.get_army_groups()[0].get(&"plan_active"))
	await _devshot("plan_preparing")
