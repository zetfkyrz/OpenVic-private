	# The manpower in the tooltip of the regiments of the top bar (docs/RECRUITMENT.md)
	await get_tree().create_timer(1.0).timeout
	for node: Node in get_tree().root.find_children("*", "", true, false):
		if node.get_script() != null and node.get_script().resource_path.ends_with("Topbar.gd"):
			var label: Variant = node.get(&"_military_army_size_label")
			if label != null:
				print("DEVCHECK topbar tooltip: ", label.get_tooltip_string())
	print("DEVCHECK manpower ", PlayerSingleton.get_manpower())
