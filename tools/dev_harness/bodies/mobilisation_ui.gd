	# The mobilisation (docs/RECRUITMENT.md, "Мобилизация"): Prussia, the tooltip of the mobilisation of the top bar, mobilised (when the country has the
	# mechanic), a few days of the gathering, the tooltip again, the tooltip of a mobilised army, the recruitment window with the priorities
	PlayerSingleton.toggle_paused()
	PlayerSingleton.set_player_country_by_identifier("PRU")
	await get_tree().create_timer(1.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	await get_tree().create_timer(0.5).timeout
	var topbar: Node = null
	for node: Node in get_tree().root.find_children("*", "", true, false):
		if node.get_script() != null and node.get_script().resource_path.ends_with("Topbar.gd"):
			topbar = node
	print("DEVCHECK mobilisation ", PlayerSingleton.get_mobilisation())
	if topbar != null:
		topbar.call(&"_update_info")
		var label: Control = topbar.get(&"_military_mobilisation_size_label")
		if label != null:
			var tip: String = label.get_tooltip_string()
			print("DEVCHECK mobilisation tooltip:\n", tip)
			MenuSingleton.show_tooltip(tip, {}, label.get_global_position() + Vector2(0, 30))
	await get_tree().create_timer(0.5).timeout
	await _devshot("mobilisation_topbar")
	MenuSingleton.hide_tooltip()

	PlayerSingleton.set_mobilise(true)
	PlayerSingleton.toggle_paused()
	for step: int in 4:
		PlayerSingleton.increase_speed()
	await get_tree().create_timer(8.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	await get_tree().create_timer(0.5).timeout
	print("DEVCHECK mobilised ", MenuSingleton.get_longform_date(), " ", PlayerSingleton.get_mobilisation())
	if topbar != null:
		topbar.call(&"_update_info")
		var label_after: Control = topbar.get(&"_military_mobilisation_size_label")
		if label_after != null:
			var tip_after: String = label_after.get_tooltip_string()
			print("DEVCHECK mobilisation tooltip after:\n", tip_after)
			MenuSingleton.show_tooltip(tip_after, {}, label_after.get_global_position() + Vector2(0, 30))
	await get_tree().create_timer(0.5).timeout
	await _devshot("mobilisation_mobilised")
	MenuSingleton.hide_tooltip()

	var capital: int = 0
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and not stack.get(&"is_navy", false):
			if capital == 0:
				capital = int(stack[&"province_number"])
			var text: String = _unit_banners._describe(stack)
			if text.find("обилиз") >= 0:
				print("DEVCHECK mobilised army tooltip:\n", text)
				MenuSingleton.show_tooltip(text, {}, Vector2(1100, 420))
				await get_tree().create_timer(0.5).timeout
				await _devshot("mobilisation_army")
				MenuSingleton.hide_tooltip()
				break

	_recruitment_window.open_for_province(capital)
	await get_tree().create_timer(0.8).timeout
	print("DEVCHECK queue ", PlayerSingleton.get_recruitment_queue().size())
	await _devshot("mobilisation_recruit")
