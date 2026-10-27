	var mm: Node = _model_manager
	var seen: Dictionary = {}
	var printed: int = 0
	var dump := func(node: Node, depth: int, dump_ref: Callable) -> void:
		var pad: String = "  ".repeat(depth)
		var info: String = pad + node.name + " <" + node.get_class() + ">"
		if node is Node3D:
			var t: Transform3D = (node as Node3D).transform
			info += " pos=" + str(t.origin) + " scale=" + str(t.basis.get_scale())
		if node is MeshInstance3D:
			var mi: MeshInstance3D = node
			var verts: int = 0
			var skinned: bool = false
			if mi.mesh:
				for s in mi.mesh.get_surface_count():
					var arrays: Array = mi.mesh.surface_get_arrays(s)
					verts += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
					var bones: Variant = arrays[Mesh.ARRAY_BONES]
					if bones != null and bones.size() > 0:
						skinned = true
			info += " surfaces=" + str(mi.mesh.get_surface_count() if mi.mesh else 0) + " verts=" + str(verts) + " skinned=" + str(skinned) + " skeleton=" + str(mi.skeleton) + " skin=" + str(mi.skin)
		if node is Skeleton3D:
			info += " bones=" + str((node as Skeleton3D).get_bone_count())
		if node is AnimationPlayer:
			var ap: AnimationPlayer = node
			var names: PackedStringArray = []
			for a in ap.get_animation_list():
				var anim: Animation = ap.get_animation(a)
				names.append("%s(%.2fs,%d tracks)" % [a, anim.length, anim.get_track_count()])
			info += " anims=" + ", ".join(names) + " root=" + str(ap.root_node)
		if node is BoneAttachment3D:
			info += " bone=" + str((node as BoneAttachment3D).bone_idx)
		print("TREE ", info)
		for c: Node in node.get_children():
			dump_ref.call(c, depth + 1, dump_ref)
	var dumped_kinds: int = 0
	for node: Node in mm.get_children():
		var key: String = String(node.name).split("@")[0]
		var kind: String = key + str(node.get_child_count())
		if seen.has(kind) or dumped_kinds >= 6:
			continue
		seen[kind] = true
		dumped_kinds += 1
		print("TREE ==== ", node.name, " children=", node.get_child_count())
		dump.call(node, 0, dump)
