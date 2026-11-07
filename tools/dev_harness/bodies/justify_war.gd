	# The justification of a war and the casus belli (docs/WAR_ASSUMPTIONS.md, "Обоснование войны"): Prussia, the diplomacy screen on Austria (no
	# casus belli: the penalties of a war without it), the justification started, a few days later the days left
	PlayerSingleton.toggle_paused()
	PlayerSingleton.set_player_country_by_identifier("PRU")
	await get_tree().create_timer(1.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	var austria: int = -1
	for entry: Dictionary in PlayerSingleton.get_border_highlights()[&"neighbours"]:
		if str(entry[&"name"]).begins_with("Австри"):
			austria = int(entry[&"country_index"])
	print("DEVCHECK austria ", austria, " relation ", PlayerSingleton.get_diplomatic_relation(austria))
	Events.NationManagementScreens.open_nation_management_screen(NationManagement.Screen.DIPLOMACY)
	await get_tree().create_timer(1.0).timeout
	var menu: Node = null
	for node: Node in get_tree().root.find_children("*", "", true, false):
		if node.get_script() != null and node.get_script().resource_path.ends_with("DiplomacyMenu.gd"):
			menu = node
	if menu != null:
		menu.call(&"_select_country", austria)
	await get_tree().create_timer(0.5).timeout
	await _devshot("justify_before")
	var identifiers: PackedStringArray = PlayerSingleton.get_diplomatic_action_identifiers()
	print("DEVCHECK justify sent=", PlayerSingleton.send_diplomatic_action(austria, identifiers.find("justify_war")))
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(2.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	await get_tree().create_timer(0.5).timeout
	print("DEVCHECK relation after ", PlayerSingleton.get_diplomatic_relation(austria))
	if menu != null:
		menu.call(&"_select_country", austria)
	await get_tree().create_timer(0.5).timeout
	await _devshot("justify_running")
