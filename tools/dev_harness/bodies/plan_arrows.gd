	# The arrows of an attack plan along the line of a front held by a marshal
	PlayerSingleton.toggle_paused()
	var numbers: Array[int] = []
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false) and not numbers.has(int(stack[&"province_number"])):
			numbers.append(int(stack[&"province_number"]))
	PlayerSingleton.create_army_group()
	PlayerSingleton.create_front(-1)
	await get_tree().create_timer(0.4).timeout
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.2).timeout
	PlayerSingleton.toggle_paused()
	var front_id: int = PlayerSingleton.get_front_summaries()[0][&"id"]
	var group_id: int = int(PlayerSingleton.get_army_groups()[0][&"id"])
	for n: int in numbers.slice(0, 6):
		PlayerSingleton.toggle_front_province(front_id, n)
	PlayerSingleton.set_army_group_front(group_id, front_id, true)
	PlayerSingleton.set_army_group_plan(group_id, front_id, 0)
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(2.0).timeout
	PlayerSingleton.toggle_paused()
	var lines: Array = PlayerSingleton.get_front_lines(front_id)
	print("DEVCHECK lines=", lines.size(), " provinces=", PlayerSingleton.get_front_summaries()[0][&"province_numbers"])
	var first: Vector2 = Vector2(0.5, 0.5)
	if not lines.is_empty() and not lines[0].is_empty():
		first = lines[1][0] if lines.size() > 1 else lines[0][0]
	_map_view.look_at_map_position(first)
	_map_view._camera.position.y = _map_view._zoom_detailed_threshold * 1.0
	_map_view._zoom_target = _map_view._camera.position.y
	await get_tree().create_timer(2.5).timeout
	await _devshot("plan_arrows")
