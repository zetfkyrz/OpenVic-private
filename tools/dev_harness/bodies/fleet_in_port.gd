	# The fleets in the ports (owner 2026-11-06): a docked fleet stands at the port (only its plate, no model), a fleet ordered into another port shows its
	# route to the port itself and sails there; England, the first fleet goes to the port of another fleet
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	var docked: Array = []
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and stack.get(&"is_navy", false):
			var details: Dictionary = PlayerSingleton.get_army_details(int(stack[&"army_ids"][0]))
			print("DEVCHECK fleet ", details.get(&"name"), " at ", stack[&"province_number"], " docked=", details.get(&"docked"), " position=", stack[&"position"])
			if bool(details.get(&"docked", false)):
				docked.append(stack)
	var _look := func(at: Vector2, height: float) -> void:
		_map_view._camera.position.y = _map_view._zoom_detailed_threshold * height
		_map_view._zoom_target = _map_view._camera.position.y
		await get_tree().create_timer(1.5).timeout
	if docked.size() < 2:
		print("DEVCHECK not two docked fleets")
		return
	# Two ports near each other (the British ones), else the first and the last
	var fleet: Dictionary = docked[0]
	var target: int = int(docked[docked.size() - 1][&"province_number"])
	for stack: Dictionary in docked:
		if int(stack[&"province_number"]) == 299:
			fleet = stack
		if int(stack[&"province_number"]) == 303:
			target = 303
	var fleet_id: int = int(fleet[&"army_ids"][0])
	await _look.call(MapItemSingleton.get_unit_position_by_province_number(int(fleet[&"province_number"])), 1.0)
	await _devshot("port_docked")
	print("DEVCHECK order ", fleet_id, " to ", target, " accepted=", PlayerSingleton.move_army(fleet_id, target))
	_unit_banners.select_armies([fleet_id])
	await get_tree().create_timer(0.5).timeout
	if MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.5).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_navy", false) and (stack[&"army_ids"] as Array).has(fleet_id):
			print("DEVCHECK sailing at ", stack[&"province_number"], " paths=", stack[&"paths"])
			await _look.call(MapItemSingleton.get_unit_position_by_province_number(target), 1.6)
	await _devshot("port_sailing")
	if MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	for step: int in 4:
		PlayerSingleton.increase_speed()
	await get_tree().create_timer(12.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	var after: Dictionary = PlayerSingleton.get_army_details(fleet_id)
	print("DEVCHECK after ", MenuSingleton.get_longform_date(), " province=", after.get(&"province_number"), " docked=", after.get(&"docked"))
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_navy", false) and (stack[&"army_ids"] as Array).has(fleet_id):
			await _look.call(MapItemSingleton.get_unit_position_by_province_number(target), 1.0)
	await _devshot("port_arrived")
