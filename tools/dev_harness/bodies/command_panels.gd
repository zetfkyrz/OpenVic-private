	# The panel of the command (bottom) and the panel of the theatres (right): two marshals, generals attached, a second theatre, a plan; screenshots
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	PlayerSingleton.create_army_group()
	PlayerSingleton.create_army_group()
	PlayerSingleton.create_theatre()
	PlayerSingleton.create_front(-1)
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(2.0).timeout
	PlayerSingleton.toggle_paused()
	var groups: Array = PlayerSingleton.get_army_groups()
	var generals: Array = PlayerSingleton.get_generals()
	print("DEVCHECK groups=", groups.size(), " generals=", generals.size())
	var with_army: Array = []
	for general: Dictionary in generals:
		if int(general[&"army_id"]) != 0:
			with_army.append(general)
	if groups.size() >= 2 and with_army.size() >= 8:
		# the first group: the marshal is a general of an army, three armies attached; the second: two armies and no marshal
		PlayerSingleton.set_army_group_marshal(int(groups[0][&"id"]), int(with_army[0][&"leader_id"]))
		for index: int in range(1, 4):
			PlayerSingleton.set_army_group(int(with_army[index][&"army_id"]), int(groups[0][&"id"]))
		for index: int in range(4, 6):
			PlayerSingleton.set_army_group(int(with_army[index][&"army_id"]), int(groups[1][&"id"]))
		var theatres: Array = PlayerSingleton.get_theatres()
		if theatres.size() >= 2:
			PlayerSingleton.rename_theatre(int(theatres[1][&"id"]), "Северный театр")
			PlayerSingleton.set_theatre_focus(int(theatres[1][&"id"]), 13)
			PlayerSingleton.set_army_group_theatre(int(groups[1][&"id"]), int(theatres[1][&"id"]))
		var fronts: Array = PlayerSingleton.get_front_summaries()
		if not fronts.is_empty():
			PlayerSingleton.set_army_group_front(int(groups[0][&"id"]), int(fronts[0][&"id"]), true)
			PlayerSingleton.set_army_group_plan(int(groups[0][&"id"]), int(fronts[0][&"id"]), 0)
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(3.0).timeout
	PlayerSingleton.toggle_paused()
	for theatre: Dictionary in PlayerSingleton.get_theatres():
		print("DEVCHECK theatre ", theatre[&"id"], " name=", theatre[&"name"], " marshals=", theatre[&"marshal_count"], " divisions=", theatre[&"division_count"])
	for group: Dictionary in PlayerSingleton.get_army_groups():
		print("DEVCHECK group ", group[&"id"], " theatre=", group[&"theatre_id"], " marshal=", group[&"marshal_name"], " armies=", group[&"army_count"], " plan_front=", group[&"plan_front_id"])
	await get_tree().create_timer(1.0).timeout
	await _devshot("command_panels")
