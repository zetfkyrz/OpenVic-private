	var mm: Node = _model_manager
	var cam: Camera3D = _map_view._camera
	var unit: UnitModel = null
	for n: Node in mm.get_children():
		if n is UnitModel and String(n.name).find("Infantry") >= 0:
			unit = n
			break
	var world: Vector3 = unit.global_position
	cam.position = world + Vector3(0.0, 0.07, 0.05)
	cam.look_at(world + Vector3(0.0, 0.01, 0.0))
	_map_view._zoom_target = cam.position.y
	unit.current_anim = UnitModel.Anim.MOVE
	await get_tree().create_timer(0.5).timeout
	for i in 4:
		await get_tree().create_timer(0.12).timeout
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png("%s/vat_motion_%d.png" % ["C:/Users/zetfk/Desktop/OpenVic/OpenVic/out/dev_shots", i])
