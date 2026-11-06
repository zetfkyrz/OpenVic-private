	# The manpower in men (docs/RECRUITMENT.md): Prussia (its armies of the start fitted to the manpower), the tooltip of the regiments of the top bar,
	# the recruitment window in the mode of the divisions, the tooltip of an army (the new men, the overload); the real tooltip of the game
	PlayerSingleton.toggle_paused()
	PlayerSingleton.set_player_country_by_identifier("PRU")
	await get_tree().create_timer(1.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	# A few days, so that the new men of yesterday are known
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(2.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	await get_tree().create_timer(0.5).timeout
	print("DEVCHECK manpower ", PlayerSingleton.get_manpower())
	for node: Node in get_tree().root.find_children("*", "", true, false):
		if node.get_script() != null and node.get_script().resource_path.ends_with("Topbar.gd"):
			node.call(&"_update_info")
			var label: Variant = node.get(&"_military_army_size_label")
			if label != null:
				var tip: String = label.get_tooltip_string()
				print("DEVCHECK topbar tooltip:\n", tip)
				MenuSingleton.show_tooltip(tip, {}, (label as Control).get_global_position() + Vector2(0, 30))
	await get_tree().create_timer(0.5).timeout
	await _devshot("manpower_topbar")
	MenuSingleton.hide_tooltip()

	var capital: int = 0
	var damaged: Dictionary = {}
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and not stack.get(&"is_navy", false):
			if capital == 0:
				capital = int(stack[&"province_number"])
			if damaged.is_empty() and float(stack[&"strength"]) < 0.99:
				damaged = stack
	_recruitment_window.open_for_province(capital)
	await get_tree().create_timer(0.5).timeout
	_recruitment_window._mode_option.select(2)
	_recruitment_window._on_mode_selected(2)
	await get_tree().create_timer(0.8).timeout
	print("DEVCHECK recruitment manpower: ", _recruitment_window._manpower_label.text)
	await _devshot("manpower_recruit")
	_recruitment_window.close_window() if _recruitment_window.has_method(&"close_window") else _recruitment_window.hide()
	await get_tree().create_timer(0.3).timeout

	if not damaged.is_empty():
		var army_tip: String = _unit_banners._describe(damaged)
		print("DEVCHECK army tooltip:\n", army_tip)
		MenuSingleton.show_tooltip(army_tip, {}, Vector2(1100, 420))
		await get_tree().create_timer(0.5).timeout
		await _devshot("manpower_army")
		MenuSingleton.hide_tooltip()

	# At war the maximum is 10 % bigger: the free men reinforce the regiments
	var highlights: Dictionary = PlayerSingleton.get_border_highlights()
	var enemy: Dictionary = {}
	for entry: Dictionary in highlights[&"neighbours"]:
		if enemy.is_empty() or (entry[&"edges"] as PackedInt32Array).size() > (enemy[&"edges"] as PackedInt32Array).size():
			enemy = entry
	print("DEVCHECK war=", PlayerSingleton.declare_war_with_goal(int(enemy[&"country_index"]), 2, 0), " on ", enemy[&"name"])
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(3.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	await get_tree().create_timer(0.5).timeout
	print("DEVCHECK manpower at war ", PlayerSingleton.get_manpower())
	for node: Node in get_tree().root.find_children("*", "", true, false):
		if node.get_script() != null and node.get_script().resource_path.ends_with("Topbar.gd"):
			node.call(&"_update_info")
			var war_label: Variant = node.get(&"_military_army_size_label")
			if war_label != null:
				var war_tip: String = war_label.get_tooltip_string()
				print("DEVCHECK topbar tooltip at war:\n", war_tip)
				MenuSingleton.show_tooltip(war_tip, {}, (war_label as Control).get_global_position() + Vector2(0, 30))
	await get_tree().create_timer(0.5).timeout
	await _devshot("manpower_war")
	MenuSingleton.hide_tooltip()
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and not stack.get(&"is_navy", false) and float(stack[&"strength"]) < 0.99:
			print("DEVCHECK army tooltip at war:\n", _unit_banners._describe(stack))
			break
