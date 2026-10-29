	# The fronts of the player drawn along the borders of the provinces; and the spread of divisions over the line
	PlayerSingleton.toggle_paused()
	var numbers: Array[int] = []
	var army_ids: Array[int] = []
	for stack: Dictionary in PlayerSingleton.get_map_units():
		if stack.get(&"is_player", false):
			if not numbers.has(int(stack[&"province_number"])):
				numbers.append(int(stack[&"province_number"]))
			for army_id: int in stack[&"army_ids"]:
				army_ids.append(army_id)
	print("DEVCHECK player stacks provinces=", numbers.size(), " armies=", army_ids.size())
	PlayerSingleton.create_front(-1)
	await get_tree().create_timer(0.4).timeout
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.2).timeout
	PlayerSingleton.toggle_paused()
	var summaries: Array = PlayerSingleton.get_front_summaries()
	print("DEVCHECK fronts=", summaries)
	var front_id: int = summaries[0][&"id"]
	for n: int in numbers.slice(0, 4):
		PlayerSingleton.toggle_front_province(front_id, n)
	for army_id: int in army_ids.slice(0, 2):
		PlayerSingleton.set_front_army(front_id, army_id, true)
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(2.0).timeout
	PlayerSingleton.toggle_paused()
	print("DEVCHECK fronts after=", PlayerSingleton.get_front_summaries())
	var lines: Array = PlayerSingleton.get_front_lines(front_id)
	var points: int = 0
	for line: PackedVector2Array in lines:
		points += line.size()
	print("DEVCHECK lines=", lines.size(), " points=", points)
	var first: Vector2 = Vector2(0.5, 0.5)
	if not lines.is_empty() and not lines[0].is_empty():
		first = lines[0][0]
	_map_view.look_at_map_position(first)
	_map_view._camera.position.y = _map_view._zoom_detailed_threshold * 1.5
	_map_view._zoom_target = _map_view._camera.position.y
	await get_tree().create_timer(2.5).timeout
	await _devshot("fronts_map_close")
	_map_view._camera.position.y = _map_view._zoom_parchment_threshold * 0.9
	_map_view._zoom_target = _map_view._camera.position.y
	await get_tree().create_timer(2.0).timeout
	await _devshot("fronts_map_far")
