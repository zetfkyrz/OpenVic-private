extends Node
## Every flag of a country in the interface opens the diplomacy window with that country (decision of the owner 2026-11-14): the flags of the
## great powers, the cores of a province, the movements of the pops and the others. The flags are hooked when they enter the tree. A flag
## button that has an action of its own keeps it (the player flag of the top bar); a flag that ignores the mouse stays so (the banners of the
## armies on the map).


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	# the flags made before this node
	_hook_tree.call_deferred(get_tree().root)


func _hook_tree(node: Node) -> void:
	_on_node_added(node)
	for child: Node in node.get_children():
		_hook_tree(child)


func _on_node_added(node: Node) -> void:
	if node.has_meta(&"flag_link"):
		return
	if node is GUIMaskedFlagButton:
		node.set_meta(&"flag_link", true)
		var button := node as GUIMaskedFlagButton
		button.pressed.connect(_on_flag_button_pressed.bind(button))
	elif node is GUIMaskedFlag:
		node.set_meta(&"flag_link", true)
		var flag := node as GUIMaskedFlag
		# the flag picture ignored the mouse: it takes the clicks now, with the hand of a link
		if flag.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			flag.mouse_filter = Control.MOUSE_FILTER_STOP
		flag.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		flag.gui_input.connect(_on_flag_input.bind(flag))


func _on_flag_button_pressed(button: GUIMaskedFlagButton) -> void:
	# a flag button with an action of its own (more than this one) keeps it
	if button.get_signal_connection_list(&"pressed").size() > 1:
		return
	_open(button.get_flag_country_name())


func _on_flag_input(event: InputEvent, flag: GUIMaskedFlag) -> void:
	var click := event as InputEventMouseButton
	if click and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		flag.accept_event()
		_open(flag.get_flag_country_name())


func _open(identifier: String) -> void:
	if identifier.is_empty():
		return
	Events.NationManagementScreens.open_diplomacy_with(identifier)
