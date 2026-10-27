	var mm: Node = _model_manager
	var counts: Dictionary = {}
	for n: Node in mm.get_children():
		if n is UnitModel and (n as UnitModel).skeleton != null:
			var u: UnitModel = n
			var mats: Dictionary = {}
			for mi: MeshInstance3D in mm.VatConvert._mesh_instances(u):
				if mi.mesh == null:
					continue
				for s in mi.mesh.get_surface_count():
					var m: Material = mi.mesh.surface_get_material(s)
					var kind: String = "null"
					if m == XACLoader.unit_shader:
						kind = "unit"
					elif m == XACLoader.flag_shader:
						kind = "flag"
					elif m == XACLoader.scrolling_shader:
						kind = "scroll"
					elif m != null:
						kind = m.get_class()
					mats[kind] = int(mats.get(kind, 0)) + 1
			var riders: int = 0
			for su: UnitModel in u.sub_units:
				if su.anim_player != null:
					riders += 1
			var key: String = String(u.name).split("@")[0] + " materials=" + str(mats) + " animated_subunits=" + str(riders)
			counts[key] = int(counts.get(key, 0)) + 1
	for key: String in counts:
		print("DEVCHECK skipped x", counts[key], ": ", key)
