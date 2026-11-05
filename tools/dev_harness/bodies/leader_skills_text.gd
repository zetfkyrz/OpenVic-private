	# The texts of the skills on the cards of the command (docs/WAR_ASSUMPTIONS.md, section 7): the tooltip and the short line of the menus for the
	# generals of Prussia (no war: the levels are 0, the lines show what the skills are)
	PlayerSingleton.toggle_paused()
	PlayerSingleton.set_player_country_by_identifier("PRU")
	await get_tree().create_timer(1.0).timeout
	var shown: int = 0
	for general: Dictionary in PlayerSingleton.get_generals():
		if shown < 2:
			print("DEVCHECK tooltip ", general[&"leader_name"], ":\n", _command_panel._skills_text(general))
			shown += 1
	var marshal: Dictionary = PlayerSingleton.get_generals()[0].duplicate(true)
	marshal[&"is_marshal"] = true
	for skill: Dictionary in marshal[&"skills"]:
		skill[&"active"] = bool(skill[&"marshal"])
	marshal[&"skills"].append({ &"id": "supply", &"terrain": false, &"marshal": true, &"level": 1, &"max": 3, &"experience": 73.0, &"next": 90.0, &"active": true })
	marshal[&"skills"].append({ &"id": "hills", &"terrain": true, &"marshal": false, &"level": 2, &"max": 5, &"experience": 33.5, &"next": 60.0, &"active": false })
	print("DEVCHECK tooltip of a marshal (made up):\n", _command_panel._skills_text(marshal))
	print("DEVCHECK short ", _command_panel._skills_short(marshal, true))
