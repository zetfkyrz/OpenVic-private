	PlayerSingleton.toggle_paused()
	var mode_count: int = GameSingleton.get_mapmode_count()
	var supply_mode: int = -1
	for i in mode_count:
		if GameSingleton.get_mapmode_identifier(i) == "mapmode_supply":
			supply_mode = i
	print("DEVCHECK mapmode_supply index=", supply_mode)
	for n: int in [1, 50, 300, 600]:
		var info: Dictionary = MenuSingleton.get_province_info_from_number(n)
		print("DEVCHECK province ", n, " text=", info.get("supply_limit_text", "-"))
		print("DEVCHECK tooltip ", n, ": ", String(info.get("supply_limit_tooltip", "-")).replace("\n", " | "))
	GameSingleton.set_mapmode(supply_mode)
	_map_view._camera.position.y = _map_view._zoom_parchment_threshold * 0.9
	_map_view._zoom_target = _map_view._camera.position.y
	await get_tree().create_timer(2.0).timeout
	await _devshot("supply_map")
	PlayerSingleton.set_selected_province_by_number(300)
	await get_tree().create_timer(1.5).timeout
	await _devshot("supply_panel")
