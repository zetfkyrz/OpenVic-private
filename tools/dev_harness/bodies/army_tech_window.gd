	# The window of the army technologies: the data the bridge gives, screenshots of the tree, a click that starts a research
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	var branches: Array = PlayerSingleton.get_army_tech_branches()
	var technologies: Array = PlayerSingleton.get_army_technologies()
	print("DEVCHECK branches=", branches)
	print("DEVCHECK technologies=", technologies.size())
	var states: Array = [0, 0, 0, 0]
	for technology: Dictionary in technologies:
		states[int(technology[&"state"])] += 1
	print("DEVCHECK states (not available, available, researching, researched)=", states)
	if not technologies.is_empty():
		print("DEVCHECK first=", technologies[0])
	var window: Node = null
	for child: Node in get_tree().root.find_children("*", "Control", true, false):
		var script: Script = child.get_script()
		if script != null and script.resource_path.ends_with("ArmyTechWindow.gd"):
			window = child
	print("DEVCHECK window=", window)
	if window != null:
		window.open_technologies()
		await get_tree().create_timer(1.0).timeout
		await _devshot("army_tech_tree")
		# Start the first available technology and let two days pass
		var started: int = -1
		for technology: Dictionary in technologies:
			if bool(technology[&"can_start"]):
				started = int(technology[&"index"])
				print("DEVCHECK starting ", technology[&"id"], " -> ", PlayerSingleton.start_army_research(started))
				break
		PlayerSingleton.toggle_paused()
		await get_tree().create_timer(3.0).timeout
		PlayerSingleton.toggle_paused()
		window._refresh()
		await get_tree().create_timer(0.5).timeout
		for technology: Dictionary in PlayerSingleton.get_army_technologies():
			if int(technology[&"index"]) == started:
				print("DEVCHECK after: state=", technology[&"state"], " days_left=", technology[&"days_left"], " progress=", technology[&"progress"])
		await _devshot("army_tech_tree_researching")
