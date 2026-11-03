	# The plate and the front tool with real events of the mouse (docs/WAR_ASSUMPTIONS.md, section 6): Prussia, a marshal; a click on his card shows the
	# borders by itself, the mouse over the border with Russia makes it green, a right click makes the front; then the front button and a left click
	# on another border take the place of the order
	PlayerSingleton.toggle_paused()
	PlayerSingleton.set_player_country_by_identifier("PRU")
	PlayerSingleton.create_army_group()
	await get_tree().create_timer(1.0).timeout
	var group_id: int = int(PlayerSingleton.get_army_groups()[0][&"id"])
	for general: Dictionary in PlayerSingleton.get_generals():
		if not bool(general[&"is_marshal"]) and int(general[&"army_id"]) == 0:
			PlayerSingleton.set_army_group_marshal(group_id, int(general[&"leader_id"]))
			break
	await get_tree().create_timer(1.0).timeout
	var to_window: Transform2D = get_tree().root.get_final_transform()
	var mouse := func(at: Vector2, button: int) -> void:
		var window_at: Vector2 = to_window * at
		Input.warp_mouse(window_at)
		var motion := InputEventMouseMotion.new()
		motion.position = window_at
		motion.global_position = window_at
		Input.parse_input_event(motion)
		await get_tree().create_timer(0.3).timeout
		if button != 0:
			for pressed: bool in [true, false]:
				var click := InputEventMouseButton.new()
				click.button_index = button
				click.pressed = pressed
				click.position = window_at
				click.global_position = window_at
				Input.parse_input_event(click)
				await get_tree().create_timer(0.15).timeout
	# The card of the marshal
	var card: Control = null
	var stack: Array[Node] = [_command_panel]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Panel and node.get(&"accepts_generals") == true:
			card = node
			break
		stack.append_array(node.get_children())
	print("DEVCHECK card=", card != null)
	await mouse.call(card.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await get_tree().create_timer(0.5).timeout
	var tools: Node = _command_panel._plan_tools
	print("DEVCHECK after card click: selected=", _command_panel._selected_group, " tool=", tools.tool, " passive=", tools.passive, " entries=", tools._entries.size())
	# Over the border with Russia
	var russia: Dictionary = {}
	for entry: Dictionary in tools._entries:
		if russia.is_empty() or (entry[&"edges"] as PackedInt32Array).size() > (russia[&"edges"] as PackedInt32Array).size():
			russia = entry
	var target: int = int((russia[&"other_numbers"] as PackedInt32Array)[0])
	var own: int = int((russia[&"own_numbers"] as PackedInt32Array)[0])
	_map_view.look_at_map_position(MapItemSingleton.get_unit_position_by_province_number(own))
	_map_view._camera.position.y = _map_view._zoom_detailed_threshold * 1.6
	_map_view._zoom_target = _map_view._camera.position.y
	await get_tree().create_timer(1.5).timeout
	var target_screen: Vector2 = _map_view._camera.unproject_position(_map_view._map_to_ground_coords(MapItemSingleton.get_unit_position_by_province_number(target)))
	await mouse.call(target_screen, 0)
	await get_tree().create_timer(0.5).timeout
	print("DEVCHECK hover: mouse province=", _map_view.get_mouse_province_number(), " target=", target, " hovered entry=", tools._hovered_entry, " russia=", russia[&"name"])
	await _devshot("input_hover")
	await mouse.call(target_screen, MOUSE_BUTTON_RIGHT)
	await get_tree().create_timer(1.0).timeout
	print("DEVCHECK after right click: fronts=", PlayerSingleton.get_front_summaries().size(), " tool=", tools.tool, " player=", PlayerSingleton.get_player_country_identifier())
	await get_tree().create_timer(0.5).timeout
	await _devshot("input_front")
	# The front button of the plate, then a left click on the border with Austria
	var front_button: Control = null
	stack = [_command_panel]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button and node.get(&"kind") == &"front":
			front_button = node
			break
		stack.append_array(node.get_children())
	await mouse.call(front_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await get_tree().create_timer(0.5).timeout
	print("DEVCHECK after front button: tool=", tools.tool, " passive=", tools.passive)
	var austria: Dictionary = {}
	for entry: Dictionary in tools._entries:
		if str(entry[&"name"]) == "Австрия":
			austria = entry
	if not austria.is_empty():
		var at: int = int((austria[&"other_numbers"] as PackedInt32Array)[0])
		_map_view.look_at_map_position(MapItemSingleton.get_unit_position_by_province_number(at))
		await get_tree().create_timer(1.5).timeout
		var at_screen: Vector2 = _map_view._camera.unproject_position(_map_view._map_to_ground_coords(MapItemSingleton.get_unit_position_by_province_number(at)))
		await mouse.call(at_screen, MOUSE_BUTTON_LEFT)
		await get_tree().create_timer(1.0).timeout
		var fronts: Array = PlayerSingleton.get_front_summaries()
		print("DEVCHECK after left click on Austria: fronts=", fronts.size(), " enemy=", fronts[0][&"enemy_index"] if not fronts.is_empty() else -1, " tool=", tools.tool)
		await _devshot("input_front_austria")
