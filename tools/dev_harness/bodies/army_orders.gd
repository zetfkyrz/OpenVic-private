	# The orders of an army (docs/WAR_ASSUMPTIONS.md, section 10): Prussia, the army panel with the stance, follow and to the port; entrenched
	PlayerSingleton.toggle_paused()
	PlayerSingleton.set_player_country_by_identifier("PRU")
	await get_tree().create_timer(1.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	var ids: Array[int] = []
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and not stack.get(&"is_navy", false):
			for army_id: int in stack[&"army_ids"]:
				ids.append(army_id)
	if not ids.is_empty():
		print("DEVCHECK stance=", PlayerSingleton.set_army_stance(ids[0], 1))
		PlayerSingleton.toggle_paused()
		await get_tree().create_timer(1.0).timeout
		if not MenuSingleton.is_paused():
			PlayerSingleton.toggle_paused()
		var details: Dictionary = PlayerSingleton.get_army_details(ids[0])
		print("DEVCHECK details stance ", details.get(&"stance"), " follow ", details.get(&"follow_army_id"), " candidates ", (details.get(&"follow_candidates", []) as Array).size())
		var shown: Array[int] = [ids[0]]
		_army_panel.show_armies(shown)
		# The panel fills itself when the state of the game changes: a day passes
		PlayerSingleton.toggle_paused()
		await get_tree().create_timer(1.0).timeout
		if not MenuSingleton.is_paused():
			PlayerSingleton.toggle_paused()
		await get_tree().create_timer(1.0).timeout
		await _devshot("army_orders")
