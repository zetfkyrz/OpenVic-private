	PlayerSingleton.toggle_paused()
	var player_ids: Array[int] = []
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and int(stack.get(&"regiments", 0)) >= 4:
			for army_id: int in stack[&"army_ids"]:
				player_ids.append(army_id)
			break
	var generals: Array = PlayerSingleton.get_generals()
	print("DEVCHECK generals=", generals.size(), " free=", generals.filter(func(g: Dictionary) -> bool: return g[&"army_id"] == 0).size())
	PlayerSingleton.create_army_group()
	await get_tree().create_timer(0.6).timeout
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	PlayerSingleton.toggle_paused()
	var groups: Array = PlayerSingleton.get_army_groups()
	print("DEVCHECK groups=", groups)
	PlayerSingleton.set_army_group(player_ids[0], groups[0][&"id"])
	var free_id: int = 0
	for g: Dictionary in PlayerSingleton.get_generals():
		if not g[&"is_marshal"]:
			free_id = g[&"leader_id"]
			break
	print("DEVCHECK free general=", free_id)
	if free_id != 0:
		PlayerSingleton.set_army_group_marshal(groups[0][&"id"], free_id)
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.5).timeout
	PlayerSingleton.toggle_paused()
	print("DEVCHECK groups after=", PlayerSingleton.get_army_groups())
	var details: Dictionary = PlayerSingleton.get_army_details(player_ids[0])
	print("DEVCHECK army group=", details.get(&"army_group_id"), " bonus=", details.get(&"supply_leader_bonus"))
	_army_panel.show_armies(player_ids)
	await get_tree().create_timer(1.0).timeout
	await _devshot("army_groups_panel")
	var groups_window: Control = null
	for child: Node in _army_panel.get_parent().get_children():
		if child.has_method("open_groups"):
			groups_window = child
	if groups_window != null:
		groups_window.open_groups()
		await get_tree().create_timer(1.0).timeout
		await _devshot("army_groups_window")
