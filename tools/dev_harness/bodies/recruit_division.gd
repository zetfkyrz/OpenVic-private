	# The recruitment of a division by a template (docs/RECRUITMENT.md), the tooltip of an army (men, organisation, supply) and the state of the plan
	# on the plate (docs/WAR_ASSUMPTIONS.md, section 6, P5c): Prussia, the window in the mode of the divisions at the capital, a division recruited,
	# the queue; a marshal with a front against a neighbour at peace executed (no war)
	PlayerSingleton.toggle_paused()
	PlayerSingleton.set_player_country_by_identifier("PRU")
	await get_tree().create_timer(1.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	print("DEVCHECK manpower ", PlayerSingleton.get_manpower())
	var capital: int = 0
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and not stack.get(&"is_navy", false):
			if capital == 0:
				capital = int(stack[&"province_number"])
				print("DEVCHECK tooltip of an army:\n", _unit_banners._describe(stack))
	print("DEVCHECK templates ", PlayerSingleton.get_division_recruitment_info(capital))
	_recruitment_window.open_for_province(capital)
	await get_tree().create_timer(0.5).timeout
	_recruitment_window._mode_option.select(2)
	_recruitment_window._on_mode_selected(2)
	await get_tree().create_timer(0.8).timeout
	await _devshot("recruit_divisions")
	var templates: Array = PlayerSingleton.get_division_recruitment_info(capital)
	if not templates.is_empty():
		print("DEVCHECK recruit ", PlayerSingleton.start_division_recruitment(int(templates[0][&"id"]), capital))
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.5).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	await get_tree().create_timer(0.5).timeout
	print("DEVCHECK queue ", PlayerSingleton.get_recruitment_queue().size(), " manpower ", PlayerSingleton.get_manpower())
	_recruitment_window._refresh()
	await get_tree().create_timer(0.5).timeout
	await _devshot("recruit_queue")
	_recruitment_window.close_window() if _recruitment_window.has_method(&"close_window") else _recruitment_window.hide()

	# The plate: a marshal, a front against a neighbour at peace, executed
	PlayerSingleton.create_army_group()
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	var group_id: int = int(PlayerSingleton.get_army_groups()[0][&"id"])
	for general: Dictionary in PlayerSingleton.get_generals():
		if not bool(general[&"is_marshal"]) and int(general[&"army_id"]) == 0:
			PlayerSingleton.set_army_group_marshal(group_id, int(general[&"leader_id"]))
			break
	var attached: int = 0
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and not stack.get(&"is_navy", false) and attached < 4:
			for army_id: int in stack[&"army_ids"]:
				PlayerSingleton.set_army_group(army_id, group_id)
				attached += 1
	var neighbour: Dictionary = PlayerSingleton.get_border_highlights()[&"neighbours"][0]
	PlayerSingleton.create_border_front(group_id, int(neighbour[&"country_index"]))
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	await get_tree().create_timer(0.5).timeout
	PlayerSingleton.set_army_group_plan_active(group_id, true)
	await get_tree().create_timer(1.0).timeout
	var group: Dictionary = PlayerSingleton.get_army_groups()[0]
	print("DEVCHECK plan active=", group[&"plan_active"], " status=", group.get(&"plan_status", -1), " against ", neighbour[&"name"])
	_command_panel._select_group(group_id)
	await get_tree().create_timer(0.8).timeout
	await _devshot("plan_status_plate")
