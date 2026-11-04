	# The breakthrough with real events of the mouse (docs/WAR_ASSUMPTIONS.md, section 6, P7): Prussia, a marshal with armies and a front against Russia;
	# the button of the breakthrough, the way painted with the right button two provinces deep, the divisions of the breakthrough at its start
	PlayerSingleton.toggle_paused()
	PlayerSingleton.set_player_country_by_identifier("PRU")
	PlayerSingleton.create_army_group()
	await get_tree().create_timer(1.0).timeout
	var group_id: int = int(PlayerSingleton.get_army_groups()[0][&"id"])
	for general: Dictionary in PlayerSingleton.get_generals():
		if not bool(general[&"is_marshal"]) and int(general[&"army_id"]) == 0:
			PlayerSingleton.set_army_group_marshal(group_id, int(general[&"leader_id"]))
			break
	var attached: int = 0
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and attached < 3:
			for army_id: int in stack[&"army_ids"]:
				PlayerSingleton.set_army_group(army_id, group_id)
				attached += 1
	var russia: Dictionary = {}
	for entry: Dictionary in PlayerSingleton.get_border_highlights()[&"neighbours"]:
		if russia.is_empty() or (entry[&"edges"] as PackedInt32Array).size() > (russia[&"edges"] as PackedInt32Array).size():
			russia = entry
	PlayerSingleton.create_border_front(group_id, int(russia[&"country_index"]))
	await get_tree().create_timer(1.0).timeout
	_command_panel._select_group(group_id)
	await get_tree().create_timer(0.5).timeout
	var to_window: Transform2D = get_tree().root.get_final_transform()
	var send_motion := func(at: Vector2, mask: int) -> void:
		var window_at: Vector2 = to_window * at
		Input.warp_mouse(window_at)
		var motion := InputEventMouseMotion.new()
		motion.position = window_at
		motion.global_position = window_at
		motion.button_mask = mask
		Input.parse_input_event(motion)
		await get_tree().create_timer(0.25).timeout
	var send_button := func(at: Vector2, button: int, pressed: bool) -> void:
		var window_at: Vector2 = to_window * at
		var click := InputEventMouseButton.new()
		click.button_index = button
		click.pressed = pressed
		click.position = window_at
		click.global_position = window_at
		click.button_mask = (MOUSE_BUTTON_MASK_RIGHT if button == MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_LEFT) if pressed else 0
		Input.parse_input_event(click)
		await get_tree().create_timer(0.2).timeout
	var screen_of := func(number: int) -> Vector2:
		return _map_view._camera.unproject_position(_map_view._map_to_ground_coords(MapItemSingleton.get_unit_position_by_province_number(number)))
	var stack: Array[Node] = [_command_panel]
	var button_at: Vector2 = Vector2.ZERO
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button and node.get(&"kind") == &"breakthrough":
			button_at = (node as Control).get_global_rect().get_center()
			break
		stack.append_array(node.get_children())
	await send_motion.call(button_at, 0)
	await send_button.call(button_at, MOUSE_BUTTON_LEFT, true)
	await send_button.call(button_at, MOUSE_BUTTON_LEFT, false)
	await get_tree().create_timer(0.5).timeout
	var tools: Node = _command_panel._plan_tools
	print("DEVCHECK breakthrough tool=", tools.tool, " candidates=", tools._candidates.size())
	# The way: from a province across the border to one farther in (a gap: the simulation fills it)
	var others: PackedInt32Array = russia[&"other_numbers"]
	var start: int = others[others.size() / 2]
	var start_at: Vector2 = MapItemSingleton.get_unit_position_by_province_number(start)
	var own_at: Vector2 = MapItemSingleton.get_unit_position_by_province_number(int((russia[&"own_numbers"] as PackedInt32Array)[0]))
	var far: int = 0
	var best: float = 0.0
	for number: int in tools._candidates:
		var at: Vector2 = MapItemSingleton.get_unit_position_by_province_number(number)
		var depth: float = (at - start_at).dot((start_at - own_at).normalized())
		if at.distance_to(start_at) < 0.03 and depth > best:
			best = depth
			far = number
	_map_view.look_at_map_position((start_at + MapItemSingleton.get_unit_position_by_province_number(far)) * 0.5)
	_map_view._camera.position.y = _map_view._zoom_detailed_threshold * 1.8
	_map_view._zoom_target = _map_view._camera.position.y
	await get_tree().create_timer(1.5).timeout
	await send_motion.call(screen_of.call(start), 0)
	await send_button.call(screen_of.call(start), MOUSE_BUTTON_RIGHT, true)
	await send_motion.call(screen_of.call(start).lerp(screen_of.call(far), 0.5), MOUSE_BUTTON_MASK_RIGHT)
	await send_motion.call(screen_of.call(far), MOUSE_BUTTON_MASK_RIGHT)
	await _devshot("breakthrough_paint")
	await send_button.call(screen_of.call(far), MOUSE_BUTTON_RIGHT, false)
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(6.0).timeout
	PlayerSingleton.toggle_paused()
	for line: Dictionary in PlayerSingleton.get_plan_lines():
		print("DEVCHECK line type=", line[&"type"], " provinces=", line[&"province_numbers"], " divisions=", line[&"division_count"])
	await get_tree().create_timer(0.5).timeout
	await _devshot("breakthrough_built")
