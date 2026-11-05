	# The case of the owner (2026-11-05): Turkey, a field marshal with all the armies, the front against Russia at peace (the divisions must go to the
	# line, also over the Bosporus), a manual move from Europe to Asia (the army must go and stay where it was sent), the screenshots of the front
	PlayerSingleton.toggle_paused()
	PlayerSingleton.set_player_country_by_identifier("TUR")
	PlayerSingleton.create_army_group()
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	var group_id: int = int(PlayerSingleton.get_army_groups()[0][&"id"])
	for general: Dictionary in PlayerSingleton.get_generals():
		if not bool(general[&"is_marshal"]) and int(general[&"army_id"]) == 0:
			PlayerSingleton.set_army_group_marshal(group_id, int(general[&"leader_id"]))
			break
	var all_armies: Array = []
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and not stack.get(&"is_navy", false):
			for army_id: int in stack[&"army_ids"]:
				PlayerSingleton.set_army_group(army_id, group_id)
				all_armies.append(army_id)
	var russia: Dictionary = {}
	for entry: Dictionary in PlayerSingleton.get_border_highlights()[&"neighbours"]:
		print("DEVCHECK neighbour ", entry[&"name"], " pieces=", (entry[&"edges"] as PackedInt32Array).size() / 2)
		if str(entry[&"name"]).contains("Росс"):
			russia = entry
	PlayerSingleton.create_border_front(group_id, int(russia[&"country_index"]))
	await get_tree().create_timer(0.5).timeout
	if MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	for step: int in 5:
		PlayerSingleton.increase_speed()
	await get_tree().create_timer(40.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	await get_tree().create_timer(0.5).timeout
	print("DEVCHECK date ", MenuSingleton.get_longform_date(), " fronts=", PlayerSingleton.get_front_summaries())
	var europe_army: int = 0
	for army_id: int in PlayerSingleton.get_army_groups()[0][&"army_ids"]:
		var details: Dictionary = PlayerSingleton.get_army_details(army_id)
		print("DEVCHECK army ", army_id, " at=", details.get(&"province_identifier", "?"), " moving=", details.get(&"moving", false), " manual=", details.get(&"manual_order", false))
		if str(details.get(&"province_identifier", "")) in ["860", "858", "817", "814", "818", "810"] and europe_army == 0 and not bool(details.get(&"moving", false)):
			europe_army = army_id
	# The front on the map
	var look: PackedInt32Array = russia[&"own_numbers"]
	_map_view.look_at_map_position(MapItemSingleton.get_unit_position_by_province_number(look[look.size() / 2]))
	_map_view._camera.position.y = _map_view._zoom_detailed_threshold * 2.2
	_map_view._zoom_target = _map_view._camera.position.y
	await get_tree().create_timer(1.5).timeout
	await _devshot("turkey_front")
	# A manual move of an army in Europe (or the first one) to a province of Anatolia (Ankara region, 1096 when there)
	if europe_army == 0:
		europe_army = int(all_armies[0])
	print("DEVCHECK manual army ", europe_army, " accepted=", PlayerSingleton.move_army(europe_army, 880))
	await get_tree().create_timer(0.5).timeout
	if MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	await get_tree().create_timer(20.0).timeout
	if not MenuSingleton.is_paused():
		PlayerSingleton.toggle_paused()
	var moved: Dictionary = PlayerSingleton.get_army_details(europe_army)
	print("DEVCHECK manual after ", MenuSingleton.get_longform_date(), " at=", moved.get(&"province_identifier", "?"), " moving=", moved.get(&"moving", false), " manual=", moved.get(&"manual_order", false))
