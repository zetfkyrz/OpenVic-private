	# The window of the market (F8): the weapons are goods of their own, with the names from the data
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	var goods: Array = PlayerSingleton.get_market_overview()
	for good: Dictionary in goods:
		var good_name: String = good[&"name"]
		if good_name.contains("rifle") or good_name.contains("field_gun") or good_name.contains("уж") or good_name.contains("оруд") or good_name.contains("винтов"):
			print("DEVCHECK good ", good_name, " price=", good[&"price"], " base=", good[&"base_price"], " history=", (good[&"price_history"] as PackedFloat32Array).size())
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F8
	key.keycode = KEY_F8
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(1.5).timeout
	await _devshot("market_goods")
