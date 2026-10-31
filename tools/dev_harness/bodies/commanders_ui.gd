	# The window of the commanders (cards of the marshals and the generals attached) and the army panel with the boarding of a fleet
	PlayerSingleton.toggle_paused()
	var player_ids: Array[int] = []
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and int(stack.get(&"regiments", 0)) >= 4:
			for army_id: int in stack[&"army_ids"]:
				player_ids.append(army_id)
			break
	PlayerSingleton.create_army_group()
	await get_tree().create_timer(0.6).timeout
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	PlayerSingleton.toggle_paused()
	var groups: Array = PlayerSingleton.get_army_groups()
	print("DEVCHECK groups=", groups)
	if not groups.is_empty() and not player_ids.is_empty():
		PlayerSingleton.set_army_group(player_ids[0], groups[0][&"id"])
		var free_id: int = 0
		for g: Dictionary in PlayerSingleton.get_generals():
			if not g[&"is_marshal"] and g[&"army_id"] == 0:
				free_id = g[&"leader_id"]
				break
		if free_id != 0:
			PlayerSingleton.set_army_group_marshal(groups[0][&"id"], free_id)
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.5).timeout
	PlayerSingleton.toggle_paused()
	var window: Node = null
	for child: Node in get_tree().root.find_children("*", "Control", true, false):
		var script: Script = child.get_script()
		if script != null and script.resource_path.ends_with("ArmyGroupsWindow.gd"):
			window = child
	print("DEVCHECK window=", window)
	if window != null:
		window.open_groups()
		await get_tree().create_timer(1.0).timeout
		await _devshot("commanders")
	_army_panel.show_armies(player_ids)
	await get_tree().create_timer(1.0).timeout
	await _devshot("army_panel_board")
