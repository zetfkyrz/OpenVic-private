	# The tools with the right button and real events of the mouse (docs/WAR_ASSUMPTIONS.md, section 6): Prussia, a marshal with armies; the front
	# dragged along a part of the border with Russia, the divisions go to it at once; the offensive and the line of defence painted with the right button
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
	await get_tree().create_timer(1.0).timeout
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
	var find_control := func(test: Callable) -> Control:
		var stack: Array[Node] = [_command_panel]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			if node is Control and test.call(node):
				return node
			stack.append_array(node.get_children())
		return null
	var tools: Node = _command_panel._plan_tools
	var card: Control = find_control.call(func(node: Control) -> bool: return node is Panel and node.get(&"accepts_generals") == true)
	var card_at: Vector2 = card.get_global_rect().get_center()
	await send_motion.call(card_at, 0)
	await send_button.call(card_at, MOUSE_BUTTON_LEFT, true)
	await send_button.call(card_at, MOUSE_BUTTON_LEFT, false)
	await get_tree().create_timer(0.5).timeout
	print("DEVCHECK passive tool=", tools.tool, " passive=", tools.passive)

	# The front dragged with the right button from one end of the border with Russia to its middle
	var russia: Dictionary = {}
	for entry: Dictionary in tools._entries:
		if russia.is_empty() or (entry[&"edges"] as PackedInt32Array).size() > (russia[&"edges"] as PackedInt32Array).size():
			russia = entry
	var others: PackedInt32Array = russia[&"other_numbers"]
	var from_number: int = others[0]
	var to_number: int = others[others.size() / 2]
	_map_view.look_at_map_position((MapItemSingleton.get_unit_position_by_province_number(from_number) + MapItemSingleton.get_unit_position_by_province_number(to_number)) * 0.5)
	_map_view._camera.position.y = _map_view._zoom_detailed_threshold * 2.2
	_map_view._zoom_target = _map_view._camera.position.y
	await get_tree().create_timer(1.5).timeout
	await send_motion.call(screen_of.call(from_number), 0)
	await send_button.call(screen_of.call(from_number), MOUSE_BUTTON_RIGHT, true)
	var from_screen: Vector2 = screen_of.call(from_number)
	var to_screen: Vector2 = screen_of.call(to_number)
	for step: int in 6:
		await send_motion.call(from_screen.lerp(to_screen, float(step + 1) / 6.0), MOUSE_BUTTON_MASK_RIGHT)
	print("DEVCHECK drag: from=", tools._front_from, " to=", tools._front_to, " part lines=", tools._front_part_lines.size(), " mouse=", _map_view.get_mouse_province_number())
	await _devshot("rmb_front_drag")
	await send_button.call(to_screen, MOUSE_BUTTON_RIGHT, false)
	await get_tree().create_timer(1.0).timeout
	var fronts: Array = PlayerSingleton.get_front_summaries()
	print("DEVCHECK front part: fronts=", fronts.size(), " edges=", (fronts[0][&"edges"] as PackedInt32Array).size() / 2 if not fronts.is_empty() else 0, " whole=", (russia[&"edges"] as PackedInt32Array).size() / 2, " edited=", fronts[0][&"edited"] if not fronts.is_empty() else false)

	# The divisions go to the front at once (a few days)
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(4.0).timeout
	PlayerSingleton.toggle_paused()
	var moving: int = 0
	var armies: int = 0
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false):
			for army_id: int in stack[&"army_ids"]:
				var details: Dictionary = PlayerSingleton.get_army_details(army_id)
				if int(details.get(&"army_group_id", 0)) == group_id:
					armies += 1
					moving += 1 if bool(details.get(&"moving", false)) else 0
	print("DEVCHECK armies of the marshal=", armies, " moving=", moving, " generals=", PlayerSingleton.get_army_groups()[0][&"generals"])
	await _devshot("rmb_front_divisions")

	# The offensive painted with the right button
	var offensive_button: Control = find_control.call(func(node: Control) -> bool: return node is Button and node.get(&"kind") == &"offensive")
	var offensive_button_at: Vector2 = offensive_button.get_global_rect().get_center()
	await send_motion.call(offensive_button_at, 0)
	await send_button.call(offensive_button_at, MOUSE_BUTTON_LEFT, true)
	await send_button.call(offensive_button_at, MOUSE_BUTTON_LEFT, false)
	await get_tree().create_timer(0.5).timeout
	print("DEVCHECK offensive tool=", tools.tool, " candidates=", tools._candidates.size())
	var targets: Array[int] = [others[1], others[2], others[3]]
	await send_motion.call(screen_of.call(targets[0]), 0)
	await send_button.call(screen_of.call(targets[0]), MOUSE_BUTTON_RIGHT, true)
	for number: int in targets:
		await send_motion.call(screen_of.call(number), MOUSE_BUTTON_MASK_RIGHT)
	print("DEVCHECK painting=", tools._painting, " painted=", tools._painted)
	await _devshot("rmb_offensive_paint")
	await send_button.call(screen_of.call(targets[2]), MOUSE_BUTTON_RIGHT, false)
	await get_tree().create_timer(1.5).timeout
	print("DEVCHECK lines after offensive=", PlayerSingleton.get_plan_lines())

	# The line of defence painted with the right button
	var defence_button: Control = find_control.call(func(node: Control) -> bool: return node is Button and node.get(&"kind") == &"defence")
	var defence_button_at: Vector2 = defence_button.get_global_rect().get_center()
	await send_motion.call(defence_button_at, 0)
	await send_button.call(defence_button_at, MOUSE_BUTTON_LEFT, true)
	await send_button.call(defence_button_at, MOUSE_BUTTON_LEFT, false)
	await get_tree().create_timer(0.5).timeout
	var own: PackedInt32Array = russia[&"own_numbers"]
	await send_motion.call(screen_of.call(own[0]), 0)
	await send_button.call(screen_of.call(own[0]), MOUSE_BUTTON_RIGHT, true)
	for index: int in mini(own.size(), 3):
		await send_motion.call(screen_of.call(own[index]), MOUSE_BUTTON_MASK_RIGHT)
	print("DEVCHECK defence painting=", tools._painting, " painted=", tools._painted)
	await send_button.call(screen_of.call(own[mini(own.size(), 3) - 1]), MOUSE_BUTTON_RIGHT, false)
	await get_tree().create_timer(1.5).timeout
	print("DEVCHECK lines after defence=", PlayerSingleton.get_plan_lines(), " fronts=", PlayerSingleton.get_front_summaries().size())
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(3.0).timeout
	PlayerSingleton.toggle_paused()
	await _devshot("rmb_defence")
	print("DEVCHECK handles=", _map_view.get_front_lines().get_handles().size(), " tool=", tools.tool, " passive=", tools.passive)
	# The end of the line of defence dragged one province further along our border
	var end_handle: Dictionary = {}
	for handle: Dictionary in _map_view.get_front_lines().get_handles():
		if handle[&"kind"] == &"defence" and bool(handle[&"at_end"]):
			end_handle = handle
	if not end_handle.is_empty():
		var line_before: PackedInt32Array = PlayerSingleton.get_plan_lines()[0][&"province_numbers"]
		var further: int = 0
		for number: int in own:
			if not line_before.has(number):
				further = number
				break
		var handle_screen: Vector2 = _map_view._camera.unproject_position(_map_view._map_to_ground_coords(end_handle[&"point"]))
		await send_motion.call(handle_screen, 0)
		await send_button.call(handle_screen, MOUSE_BUTTON_LEFT, true)
		await send_motion.call(handle_screen.lerp(screen_of.call(further), 0.5), MOUSE_BUTTON_MASK_LEFT)
		await send_motion.call(screen_of.call(further), MOUSE_BUTTON_MASK_LEFT)
		await _devshot("rmb_handle_drag")
		await send_button.call(screen_of.call(further), MOUSE_BUTTON_LEFT, false)
		await get_tree().create_timer(1.5).timeout
		print("DEVCHECK defence before=", line_before, " further=", further, " after=", PlayerSingleton.get_plan_lines()[0][&"province_numbers"])
		await _devshot("rmb_handle_done")
