	# The tooltip of a fleet (docs/WAR_ASSUMPTIONS.md, section 9): England, the roles of the ships of its first fleets
	await get_tree().create_timer(1.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	var shown: bool = false
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and stack.get(&"is_navy", false):
			var text: String = _unit_banners._describe(stack)
			print("DEVCHECK fleet tooltip:\n", text)
			if not shown:
				shown = true
				MenuSingleton.show_tooltip(text, {}, Vector2(1100, 420))
				await get_tree().create_timer(0.5).timeout
				await _devshot("fleet_tooltip")
				MenuSingleton.hide_tooltip()
