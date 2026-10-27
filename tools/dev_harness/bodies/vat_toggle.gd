	var debugger: Node = null
	for child: Node in get_children():
		if child is CanvasLayer and child.has_method("_toggle_vat"):
			debugger = child
	print("DEVCHECK debugger=", debugger != null, " button=", debugger._vat_button.text if debugger and debugger._vat_button else "none")
	debugger._toggle_vat()
	await get_tree().create_timer(1.0).timeout
	print("DEVCHECK after toggle: ", debugger._vat_button.text, " players=", _model_manager.find_children("*", "AnimationPlayer", true, false).size())
	debugger._toggle_vat()
	await get_tree().create_timer(1.0).timeout
	print("DEVCHECK after second toggle: ", debugger._vat_button.text, " players=", _model_manager.find_children("*", "AnimationPlayer", true, false).size(), " models=", _model_manager.get_child_count())
