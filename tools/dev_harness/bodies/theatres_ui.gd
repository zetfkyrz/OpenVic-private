	# The theatres (B4): the main one is made by itself, a second one, a name, a focus, a marshal moved to it; what the bridge gives
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	print("DEVCHECK theatres at the start=", PlayerSingleton.get_theatres())
	print("DEVCHECK create group=", PlayerSingleton.create_army_group(), " create theatre=", PlayerSingleton.create_theatre())
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(2.0).timeout
	PlayerSingleton.toggle_paused()
	var theatres: Array = PlayerSingleton.get_theatres()
	print("DEVCHECK theatres=", theatres.size())
	if theatres.size() < 2:
		return
	var second_id: int = int(theatres[1][&"id"])
	var group_id: int = int(PlayerSingleton.get_army_groups()[0][&"id"])
	print("DEVCHECK rename=", PlayerSingleton.rename_theatre(second_id, "Северный театр"), " focus=", PlayerSingleton.set_theatre_focus(second_id, 13), " move=", PlayerSingleton.set_army_group_theatre(group_id, second_id))
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(2.0).timeout
	PlayerSingleton.toggle_paused()
	for theatre: Dictionary in PlayerSingleton.get_theatres():
		print("DEVCHECK theatre ", theatre)
	print("DEVCHECK group theatre_id=", PlayerSingleton.get_army_groups()[0][&"theatre_id"])
