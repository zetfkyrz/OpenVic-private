	# The way by sea of an army (docs/WAR_ASSUMPTIONS.md, P4d): Turkey, the army in Tripolitania is sent to Constantinople, it goes to the port, sails
	# (not drawn, its plate tells where it sails and how long), lands and goes on; the tooltip and the screenshots on the way
	PlayerSingleton.toggle_paused()
	PlayerSingleton.set_player_country_by_identifier("TUR")
	await get_tree().create_timer(1.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	var army_id: int = 0
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and not stack.get(&"is_navy", false) and int(stack[&"province_number"]) == 1733:
			army_id = int(stack[&"army_ids"][0])
	print("DEVCHECK army in Tripolitania ", army_id)
	# (no return in a body: the hook quits the game at its end)
	print("DEVCHECK order accepted=", PlayerSingleton.move_army(army_id, 860))
	_unit_banners.select_armies([army_id])
	await get_tree().create_timer(0.5).timeout
	if MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	for step: int in 4:
		PlayerSingleton.increase_speed()
	var shot: bool = false
	var arrived: bool = army_id == 0
	for second: int in 60:
		if arrived:
			break
		await get_tree().create_timer(1.0).timeout
		for stack: Dictionary in PlayerSingleton.get_map_units():
			if not stack.get(&"is_navy", false) and (stack[&"army_ids"] as Array).has(army_id):
				if int(stack.get(&"at_sea_days", 0)) > 0 and not shot:
					shot = true
					if not MenuSingleton.is_paused():
						PlayerSingleton.toggle_paused()
					print("DEVCHECK at sea ", MenuSingleton.get_longform_date(), " at ", stack[&"province_number"], " paths=", stack[&"paths"])
					print("DEVCHECK tooltip:\n", _unit_banners._describe(stack))
					_map_view._camera.position.y = _map_view._zoom_detailed_threshold * 6.0
					_map_view._zoom_target = _map_view._camera.position.y
					await get_tree().create_timer(0.5).timeout
					_map_view.look_at_map_position(MapItemSingleton.get_unit_position_by_province_number(int(stack[&"province_number"])))
					await get_tree().create_timer(1.5).timeout
					await _devshot("army_at_sea")
					PlayerSingleton.toggle_paused()
				if shot and int(stack[&"province_number"]) == 860 and not arrived:
					arrived = true
					print("DEVCHECK arrived ", MenuSingleton.get_longform_date())
	if not arrived:
		print("DEVCHECK not arrived ", MenuSingleton.get_longform_date())
