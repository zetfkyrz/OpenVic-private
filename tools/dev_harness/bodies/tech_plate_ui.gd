	# The plate "Technology" of the top bar: the research of OpenVic on it, the click opens our tree, the button of the tree opens the screen of Victoria 2
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	var info: Dictionary = MenuSingleton.get_topbar_info()
	print("DEVCHECK plate before: research=", info.get(&"research"), " progress=", info.get(&"research_progress"))
	print("DEVCHECK tooltip before=", info.get(&"research_tooltip"))
	await _devshot("tech_plate_none")
	var started: int = -1
	for technology: Dictionary in PlayerSingleton.get_army_technologies():
		if bool(technology[&"can_start"]):
			started = int(technology[&"index"])
			print("DEVCHECK starting ", technology[&"id"], " -> ", PlayerSingleton.start_army_research(started))
			break
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(3.0).timeout
	PlayerSingleton.toggle_paused()
	info = MenuSingleton.get_topbar_info()
	print("DEVCHECK plate after: research=", info.get(&"research"), " progress=", info.get(&"research_progress"))
	print("DEVCHECK tooltip after=", info.get(&"research_tooltip"))
	await _devshot("tech_plate_researching")
	# The click on the plate (the signal the button emits)
	Events.NationManagementScreens.army_tech_window_toggle_requested.emit()
	await get_tree().create_timer(1.0).timeout
	await _devshot("tech_plate_opened_tree")
	for button: Node in get_tree().root.find_children("*", "Button", true, false):
		if button is Button and (button as Button).text == "Технологии Vic2":
			print("DEVCHECK pressing the Vic2 button")
			(button as Button).pressed.emit()
	await get_tree().create_timer(1.0).timeout
	await _devshot("tech_plate_vic2_screen")
