	# The colours of the command (B1): the palette, the colour of a new group, the recolouring, what the bridge gives for a general and an army
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	var palette: Array = PlayerSingleton.get_command_palette()
	print("DEVCHECK palette size=", palette.size(), " first=", palette[0] if palette.size() > 0 else null)
	print("DEVCHECK create=", PlayerSingleton.create_army_group(), " ", PlayerSingleton.create_army_group())
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(2.0).timeout
	PlayerSingleton.toggle_paused()
	var groups: Array = PlayerSingleton.get_army_groups()
	for group: Dictionary in groups:
		print("DEVCHECK group id=", group[&"id"], " colour_index=", group[&"colour_index"], " colour=", group[&"colour"], " max_attached=", group[&"max_attached"])
	if groups.size() >= 2:
		print("DEVCHECK recolour=", PlayerSingleton.set_army_group_colour(int(groups[0][&"id"]), 7))
		var generals: Array = PlayerSingleton.get_generals()
		if not generals.is_empty():
			var general: Dictionary = generals[0]
			print("DEVCHECK general=", general.get(&"name"), " is_marshal=", general.get(&"is_marshal"), " command_colour=", general.get(&"command_colour"), " group=", general.get(&"command_group_id"))
			print("DEVCHECK set marshal=", PlayerSingleton.set_army_group_marshal(int(groups[1][&"id"]), int(general[&"leader_id"])))
		PlayerSingleton.toggle_paused()
		await get_tree().create_timer(2.0).timeout
		PlayerSingleton.toggle_paused()
		for group: Dictionary in PlayerSingleton.get_army_groups():
			print("DEVCHECK after group id=", group[&"id"], " colour_index=", group[&"colour_index"], " marshal=", group[&"marshal_name"])
		for general: Dictionary in PlayerSingleton.get_generals().slice(0, 3):
			print("DEVCHECK general ", general.get(&"name"), " command_colour=", general.get(&"command_colour"), " group=", general.get(&"command_group_id"))
