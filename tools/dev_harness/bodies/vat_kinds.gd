	var mm: Node = _model_manager
	var cam: Camera3D = _map_view._camera
	var kinds: Array[String] = ["Manowar", "frigate", "Cavalry", "Transport", "Infantry"]
	for pass_index: int in 2:
		mm.set_vat_enabled(pass_index == 0)
		await get_tree().create_timer(1.0).timeout
		for kind: String in kinds:
			var unit: Node3D = null
			for n: Node in mm.get_children():
				if String(n.name).findn(kind) >= 0 and n is Node3D:
					unit = n
					break
			if unit == null:
				print("DEVCHECK no unit of kind ", kind)
				continue
			var world: Vector3 = unit.global_position
			cam.position = world + Vector3(0.0, 0.09, 0.07)
			cam.look_at(world + Vector3(0.0, 0.01, 0.0))
			_map_view._zoom_target = cam.position.y
			await get_tree().create_timer(1.2).timeout
			var image: Image = get_viewport().get_texture().get_image()
			image.save_png("C:/Users/zetfk/Desktop/OpenVic/OpenVic/out/dev_shots/kind_%s_%s.png" % [kind, "vat" if pass_index == 0 else "old"])
