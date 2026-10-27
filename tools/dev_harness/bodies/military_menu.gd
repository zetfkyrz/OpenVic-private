	var nm: GDScript = load("res://src/Utilities/NationManagement.gd")
	Events.NationManagementScreens.open_nation_management_screen(nm.Screen.MILITARY)
	await get_tree().create_timer(1.5).timeout
	await _devshot("military_menu")
	for node: Node in get_tree().root.find_children("*", "Panel", true, false):
		if node.name == "unit_window":
			for child: Node in node.get_children():
				if child is Control:
					print("DEVCHECK unit_window child ", child.name, " pos=", child.position, " size=", child.size)
			print("DEVCHECK unit_window size=", node.size, " pos=", node.position)
			break
