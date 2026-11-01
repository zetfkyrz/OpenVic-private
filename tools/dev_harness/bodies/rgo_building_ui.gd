	# The building of the RGO in the province panel: find a province that has one, select it, look at the slot and press the button
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	var found: int = -1
	for number: int in range(1, 1500):
		var info: Dictionary = MenuSingleton.get_province_info_from_number(number)
		if info.has(&"rgo_building_state") and int(info[&"rgo_building_state"]) != 0 and String(info.get(&"rgo_building_tooltip", "")).find("своих") < 0:
			found = number
			print("DEVCHECK province ", number, " name=", info[&"rgo_building_name"], " level=", info[&"rgo_building_level"], "/", info[&"rgo_building_max_level"])
			print("DEVCHECK tooltip=", info[&"rgo_building_tooltip"])
			break
	if found > 0:
		PlayerSingleton.set_selected_province_by_number(found)
		await get_tree().create_timer(1.5).timeout
		await _devshot("rgo_building_slot")
		PlayerSingleton.build_selected_province_rgo_building()
		PlayerSingleton.toggle_paused()
		await get_tree().create_timer(3.0).timeout
		PlayerSingleton.toggle_paused()
		var after: Dictionary = MenuSingleton.get_province_info_from_number(found)
		print("DEVCHECK after state=", after.get(&"rgo_building_state"), " progress=", after.get(&"rgo_building_progress"))
		await get_tree().create_timer(0.5).timeout
		await _devshot("rgo_building_slot_building")
