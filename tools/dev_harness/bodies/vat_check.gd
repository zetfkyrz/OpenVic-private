	var mm: Node = _model_manager
	print("DEVCHECK vat enabled=", mm.VatConvert.enabled, " converted=", mm.VatConvert.converted_models, " skipped=", mm.VatConvert.skipped_models, " bake ms=", snappedf(mm.VatConvert.bake_milliseconds, 0.1))
	var with_players: int = 0
	var total: int = 0
	for n: Node in mm.get_children():
		total += 1
		with_players += n.find_children("*", "AnimationPlayer", true, false).size()
	print("DEVCHECK models=", total, " animation players left=", with_players, " skeletons left=", mm.find_children("*", "Skeleton3D", true, false).size())
	var cam: Camera3D = _map_view._camera
	var unit: Node3D = null
	for n: Node in mm.get_children():
		if n is UnitModel and String(n.name).find("Infantry") >= 0:
			unit = n
			break
	var world: Vector3 = unit.global_position
	cam.position = world + Vector3(0.0, 0.07, 0.05)
	cam.look_at(world + Vector3(0.0, 0.01, 0.0))
	_map_view._zoom_target = cam.position.y
	await get_tree().create_timer(1.0).timeout
	await _devshot("vat_check_a")
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(0.3).timeout
	await _devshot("vat_check_b")
