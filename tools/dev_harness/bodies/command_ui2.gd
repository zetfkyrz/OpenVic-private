	# The panel of the army stays within its width after pressing buttons; the panels of the command give way to other windows; attach selected armies; new front from the plan menu
	PlayerSingleton.toggle_paused()
	PlayerSingleton.create_army_group()
	await get_tree().create_timer(1.0).timeout
	var player_ids: Array[int] = []
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and int(stack.get(&"regiments", 0)) >= 4:
			for army_id: int in stack[&"army_ids"]:
				player_ids.append(army_id)
			break
	# A single click only selects: the panel of the army stays closed
	_unit_banners.select_armies(player_ids)
	await get_tree().create_timer(0.5).timeout
	print("DEVCHECK army panel after select visible=", _army_panel.visible, " command panel visible=", _command_panel.visible)
	# The right click on a marshal attaches the selected armies
	var groups: Array = PlayerSingleton.get_army_groups()
	print("DEVCHECK groups=", groups.size())
	_command_panel._attach_selected_to_group(int(groups[0][&"id"]))
	await get_tree().create_timer(1.0).timeout
	print("DEVCHECK attached armies=", PlayerSingleton.get_army_groups()[0][&"army_ids"], " selected=", player_ids)
	# Double click: the panel opens, the command panel gives way
	_on_units_selected(player_ids, true)
	await get_tree().create_timer(1.0).timeout
	print("DEVCHECK army panel visible=", _army_panel.visible, " command panel visible=", _command_panel.visible, " theatre visible=", _theatre_panel.visible)
	for index: int in 3:
		_army_panel._on_priority_selected(index + 1)
		await get_tree().create_timer(0.5).timeout
	print("DEVCHECK army panel size=", _army_panel.size, " root=", _army_panel.content.get_child(0).size)
	await _devshot("army_panel_width")
	_army_panel.close()
	await get_tree().create_timer(0.6).timeout
	print("DEVCHECK after close command panel visible=", _command_panel.visible)
	# A new front from the menu of the plan
	var fronts_before: int = PlayerSingleton.get_front_summaries().size()
	_command_panel._known_front_ids.clear()
	_command_panel._front_for_group = int(groups[0][&"id"])
	PlayerSingleton.create_front(-1)
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.5).timeout
	PlayerSingleton.toggle_paused()
	var group: Dictionary = PlayerSingleton.get_army_groups()[0]
	print("DEVCHECK fronts ", fronts_before, " -> ", PlayerSingleton.get_front_summaries().size(), " plan_front=", group[&"plan_front_id"], " front_ids=", group[&"front_ids"])
	await _devshot("command_ui2")
