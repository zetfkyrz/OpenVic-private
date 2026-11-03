	# The plate of the plans of a field marshal and the lines drawn on the map (docs/WAR_ASSUMPTIONS.md, section 6): Prussia, a marshal with generals,
	# the front tool over the border with Russia, the front, the execution, an offensive, a line of defence, the coast
	PlayerSingleton.toggle_paused()
	PlayerSingleton.set_player_country_by_identifier("PRU")
	PlayerSingleton.create_army_group()
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	PlayerSingleton.toggle_paused()
	var tools: Node = _command_panel._plan_tools
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
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	PlayerSingleton.toggle_paused()
	print("DEVCHECK groups=", PlayerSingleton.get_army_groups())
	_command_panel._select_group(group_id)
	await get_tree().create_timer(0.5).timeout
	await _devshot("plan_plate_cards")

	# The front tool: the borders of the neighbours, the one of Russia under the mouse
	tools.start(1, group_id)
	var highlights: Dictionary = PlayerSingleton.get_border_highlights()
	var russia: Dictionary = {}
	for entry: Dictionary in highlights[&"neighbours"]:
		print("DEVCHECK neighbour ", entry[&"name"], " pieces=", (entry[&"edges"] as PackedInt32Array).size() / 2, " polylines=", (entry[&"polylines"] as Array).size())
		if russia.is_empty() or (entry[&"edges"] as PackedInt32Array).size() > (russia[&"edges"] as PackedInt32Array).size():
			russia = entry
	var look_number: int = int((russia[&"own_numbers"] as PackedInt32Array)[(russia[&"own_numbers"] as PackedInt32Array).size() / 2])
	_map_view.look_at_map_position(MapItemSingleton.get_unit_position_by_province_number(look_number))
	_map_view._camera.position.y = _map_view._zoom_detailed_threshold * 1.6
	_map_view._zoom_target = _map_view._camera.position.y
	await get_tree().create_timer(1.5).timeout
	await _devshot("plan_front_tool")
	tools._on_province_hovered(int((russia[&"other_numbers"] as PackedInt32Array)[0]))
	await get_tree().create_timer(0.5).timeout
	await _devshot("plan_front_hover")
	PlayerSingleton.create_border_front(group_id, int(russia[&"country_index"]))
	tools.stop()
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	PlayerSingleton.toggle_paused()
	print("DEVCHECK fronts=", PlayerSingleton.get_front_summaries())
	await get_tree().create_timer(1.0).timeout
	await _devshot("plan_front_built")

	# The execution: the divisions go on the front (the teeth and the label)
	PlayerSingleton.set_army_group_plan_active(group_id, true)
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(3.0).timeout
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	await _devshot("plan_front_divisions")

	# The offensive: the candidates, the painted targets with the arrow, the line
	tools.start(2, group_id)
	await get_tree().create_timer(0.5).timeout
	_map_view._camera.position.y = _map_view._zoom_detailed_threshold * 2.4
	_map_view._zoom_target = _map_view._camera.position.y
	await get_tree().create_timer(1.0).timeout
	await _devshot("plan_offensive_tool")
	# Targets two provinces deep behind the border
	var border: PackedInt32Array = russia[&"other_numbers"]
	var targets: Array[int] = []
	var candidates: PackedInt32Array = PlayerSingleton.get_plan_candidates(0, group_id)
	var centre: Vector2 = MapItemSingleton.get_unit_position_by_province_number(border[border.size() / 2])
	var direction: Vector2 = (centre - MapItemSingleton.get_unit_position_by_province_number(look_number)).normalized()
	for number: int in candidates:
		if border.has(number):
			continue
		var offset: Vector2 = MapItemSingleton.get_unit_position_by_province_number(number) - centre
		if offset.length() < 0.03 and targets.size() < 4:
			targets.append(number)
	print("DEVCHECK targets=", targets)
	tools._painting = true
	for number: int in targets:
		tools._paint(number)
	await get_tree().create_timer(0.5).timeout
	await _devshot("plan_offensive_paint")
	tools._painting = false
	tools._finish_line()
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(2.0).timeout
	PlayerSingleton.toggle_paused()
	print("DEVCHECK lines=", PlayerSingleton.get_plan_lines())
	await get_tree().create_timer(1.0).timeout
	await _devshot("plan_offensive_built")

	# A line of defence on our side of the front
	tools.start(3, group_id)
	tools._painting = true
	var own: PackedInt32Array = russia[&"own_numbers"]
	for index: int in mini(own.size(), 4):
		tools._paint(own[index])
	await get_tree().create_timer(0.5).timeout
	await _devshot("plan_defence_paint")
	tools._painting = false
	tools._finish_line()
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(2.0).timeout
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	await _devshot("plan_defence_built")

	# The coastal defence: the seas next to our land
	tools.start(4, group_id)
	var seas: Array = PlayerSingleton.get_border_highlights()[&"seas"]
	print("DEVCHECK seas=", seas.size())
	if not seas.is_empty():
		var sea: Dictionary = seas[0]
		_map_view.look_at_map_position(MapItemSingleton.get_unit_position_by_province_number(int(sea[&"sea_number"])))
		await get_tree().create_timer(1.0).timeout
		tools._on_province_hovered(int(sea[&"sea_number"]))
		await get_tree().create_timer(0.5).timeout
		await _devshot("plan_coast_hover")
	tools.stop()
