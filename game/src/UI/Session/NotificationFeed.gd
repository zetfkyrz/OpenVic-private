extends VBoxContainer
## Messages about the events that concern the player (task E1 and others): an invention or a technology was discovered,
## an election was held, a rising began, a war started or ended. The messages appear in the top right corner under the
## top bar, stay for a while and fade away. Click a message to remove it.

const _SHOW_SECONDS: float = 12.0
const _MAX_MESSAGES: int = 6

var _last_id: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -380.0
	offset_right = -20.0
	offset_top = 150.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 4)
	# The messages of the beginning of the game (history) are not shown
	for entry: Dictionary in PlayerSingleton.get_notifications(0):
		_last_id = maxi(_last_id, entry[&"id"])
	GameSingleton.gamestate_updated.connect(_poll)


func _poll() -> void:
	for entry: Dictionary in PlayerSingleton.get_notifications(_last_id):
		_last_id = maxi(_last_id, entry[&"id"])
		var text: String = _make_text(entry)
		if text != "":
			_show(text)


func _make_text(entry: Dictionary) -> String:
	var kind: String = entry[&"kind"]
	var we_first: bool = entry[&"we_are_first"]
	match kind:
		"invention":
			return "Изобретение: %s" % entry[&"subject"]
		"technology":
			return "Исследована технология"
		"election":
			return "Выборы: к власти пришла партия %s" % entry[&"subject"]
		"colony":
			if we_first:
				return "Основана колония: %s" % entry[&"subject"]
			return ""
		"uprising":
			return "Восстание в провинции %s!" % entry[&"subject"]
		"war_declared":
			if we_first:
				return "Мы объявили войну: %s" % entry[&"other"]
			return "%s объявляет нам войну!" % entry[&"country"]
		"peace_signed":
			return "Заключён мир: %s и %s" % [entry[&"country"], entry[&"other"]]
	return ""


func _show(text: String) -> void:
	while get_child_count() >= _MAX_MESSAGES:
		get_child(0).queue_free()
		remove_child(get_child(0))

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(340, 0)
	panel.add_child(label)
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			panel.queue_free()
	)
	add_child(panel)

	var tween: Tween = create_tween()
	tween.tween_interval(_SHOW_SECONDS)
	tween.tween_property(panel, "modulate:a", 0.0, 1.5)
	tween.tween_callback(panel.queue_free)
