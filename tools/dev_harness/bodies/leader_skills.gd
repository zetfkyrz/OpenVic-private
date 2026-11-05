	# The skills of the generals and of the field marshal on the cards of the command (docs/WAR_ASSUMPTIONS.md, section 7): Prussia, a marshal with four
	# generals holds a front against the neighbour with the longest border, a war of some weeks at full speed, then the cards, the tooltips, the menu
	PlayerSingleton.toggle_paused()
	PlayerSingleton.set_player_country_by_identifier("PRU")
	PlayerSingleton.create_army_group()
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	PlayerSingleton.toggle_paused()
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
	var highlights: Dictionary = PlayerSingleton.get_border_highlights()
	var enemy: Dictionary = {}
	for entry: Dictionary in highlights[&"neighbours"]:
		if enemy.is_empty() or (entry[&"edges"] as PackedInt32Array).size() > (enemy[&"edges"] as PackedInt32Array).size():
			enemy = entry
	print("DEVCHECK war=", PlayerSingleton.declare_war_with_goal(int(enemy[&"country_index"]), 2, 0), " on ", enemy[&"name"])
	PlayerSingleton.create_border_front(group_id, int(enemy[&"country_index"]))
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	PlayerSingleton.set_army_group_modes(group_id, 3, 1)
	PlayerSingleton.set_army_group_plan_active(group_id, true)
	if MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	for step: int in 5:
		PlayerSingleton.increase_speed()
	var started: String = str(MenuSingleton.get_longform_date()) if MenuSingleton.has_method(&"get_longform_date") else ""
	await get_tree().create_timer(110.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	await get_tree().create_timer(0.5).timeout
	print("DEVCHECK dates ", started, " -> ", str(MenuSingleton.get_longform_date()) if MenuSingleton.has_method(&"get_longform_date") else "")
	for general: Dictionary in PlayerSingleton.get_generals():
		if int(general[&"skill_levels"]) > 0 or bool(general[&"is_marshal"]):
			print("DEVCHECK leader ", general[&"leader_name"], " marshal=", general[&"is_marshal"], " levels=", general[&"skill_levels"], " skills=", general[&"skills"])
	# The windows that opened by themselves (the peace offered by the enemy) cover the panel
	for window: Node in get_tree().get_nodes_in_group(&"peace_window"):
		(window as CanvasItem).hide()
	_command_panel._select_group(group_id)
	await get_tree().create_timer(0.8).timeout
	await _devshot("skills_cards")
	# The tooltip of the marshal: a real mouse motion over his card
	var marshal_card: Control = null
	var general_card: Control = null
	for node: Node in _command_panel.find_children("*", "Panel", true, false):
		if node.get_script() != null and (node as Control).custom_minimum_size.x > 60.0 and marshal_card == null:
			marshal_card = node as Control
		elif node.get_script() != null and general_card == null and marshal_card != null:
			general_card = node as Control
	for card: Control in [marshal_card, general_card]:
		if card == null:
			continue
		var motion := InputEventMouseMotion.new()
		motion.position = card.get_global_rect().get_center()
		motion.global_position = motion.position
		Input.parse_input_event(motion)
		Input.warp_mouse(motion.position)
		await get_tree().create_timer(1.6).timeout
		await _devshot("skills_tooltip_%d" % (0 if card == marshal_card else 1))
	print("DEVCHECK notifications ", PlayerSingleton.get_notifications(0).filter(func(entry: Dictionary) -> bool: return str(entry[&"kind"]) == "leader_skill_up").size())
