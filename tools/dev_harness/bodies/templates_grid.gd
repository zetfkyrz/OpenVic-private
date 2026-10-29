	# The window of the division templates (a grid) with the numbers of the template: screenshots and the values the bridge gives
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	print("DEVCHECK organised=", PlayerSingleton.has_army_organisation())
	print("DEVCHECK limits=", PlayerSingleton.get_division_template_limits())
	print("DEVCHECK types=", PlayerSingleton.get_division_cell_types())
	var templates: Array = PlayerSingleton.get_division_templates()
	print("DEVCHECK templates=", templates.size())
	if not templates.is_empty():
		print("DEVCHECK first text=", templates[0][&"text"])
		print("DEVCHECK first stats=", templates[0][&"stats"])
	var window: Node = null
	for child: Node in get_tree().root.find_children("*", "Control", true, false):
		var script: Script = child.get_script()
		if script != null and script.resource_path.ends_with("DivisionTemplatesWindow.gd"):
			window = child
	print("DEVCHECK window=", window)
	if window != null:
		window.open_templates()
		await get_tree().create_timer(1.0).timeout
		await _devshot("templates_grid")
		# Make a new template: the standard cells plus one more rank of infantry
		var cells: PackedInt32Array = templates[0][&"cells"]
		var max_depth: int = int(PlayerSingleton.get_division_template_limits()[&"max_depth"])
		cells[3 * max_depth] = cells[0]
		print("DEVCHECK too wide refused? ", PlayerSingleton.create_division_template(cells))
		cells[3 * max_depth] = 0
		cells[1] = 0
		print("DEVCHECK new template ", PlayerSingleton.create_division_template(cells))
		PlayerSingleton.toggle_paused()
		await get_tree().create_timer(2.0).timeout
		PlayerSingleton.toggle_paused()
		window._refresh()
		await get_tree().create_timer(0.5).timeout
		await _devshot("templates_grid_after")
