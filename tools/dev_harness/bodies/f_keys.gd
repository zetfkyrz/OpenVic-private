	# F1-F8 do not open the screens of the top bar; F6 opens the war window only
	for keycode: Key in [KEY_F1, KEY_F2, KEY_F3, KEY_F5, KEY_F6, KEY_F7, KEY_F8]:
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = keycode
			event.physical_keycode = keycode
			event.pressed = pressed
			Input.parse_input_event(event)
			await get_tree().process_frame
		await get_tree().create_timer(0.5).timeout
		print("DEVCHECK key ", OS.get_keycode_string(keycode), " screen_open=", _screen_open, " war=", _blocking_windows[0].visible, " recruitment=", _recruitment_window.visible)
		_screen_open = false
		_blocking_windows[0].visible = false
		_recruitment_window.close()
		Events.NationManagementScreens.open_nation_management_screen(NationManagement.Screen.NONE)
	await _devshot("f_keys")
