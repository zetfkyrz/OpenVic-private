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
		"ally_joined_war":
			return "В войну на стороне %s вступил союзник: %s" % [entry[&"country"], entry[&"other"]]
		"joined_war":
			return "Союзник позвал нас в войну: мы воюем на стороне %s (выйти — отдельным миром в окне мира)" % entry[&"other"]
		"casus_belli_ready":
			return "Война обоснована: есть повод для войны против %s (на год)" % entry[&"other"]
		"separate_peace":
			return "Отдельный мир: %s вышла из войны с %s" % [entry[&"country"], entry[&"other"]]
		"army_no_supply":
			if not _supply_messages_enabled():
				return ""
			return "Армия без снабжения: %s" % entry[&"subject"]
		"army_supply_restored":
			if not _supply_messages_enabled():
				return ""
			return "Снабжение армии восстановлено: %s" % entry[&"subject"]
		"army_surrendered":
			return "Окружённая армия сдалась: %s" % entry[&"subject"]
		"over_manpower":
			# The share over the maximum in percent (docs/RECRUITMENT.md)
			return "Армия больше людских ресурсов на %s %%: атака и защита всех войск ниже на столько же. Расформируйте лишние полки" % entry[&"subject"]
		"leader_skill_up":
			# name|skill|level (docs/WAR_ASSUMPTIONS.md, section 7)
			var parts: PackedStringArray = str(entry[&"subject"]).split("|")
			if parts.size() < 3:
				return ""
			return "%s: %s — уровень %s" % [parts[0], _skill_name(parts[1]), parts[2]]
	return ""


# The name of a skill of a leader (a terrain: "Местность: <name>")
func _skill_name(id: String) -> String:
	var key: String = "LEADER_SKILL_" + id
	if tr(key + "_RU") == key + "_RU" and tr(key) == key:
		var terrain: String = tr("LEADER_TERRAIN_" + id + "_RU")
		return "Местность: %s" % (terrain if terrain != "LEADER_TERRAIN_" + id + "_RU" else id)
	var russian: String = tr(key + "_RU")
	return russian if russian != key + "_RU" else tr(key)


# The setting "Supply Messages" of the options (General)
func _supply_messages_enabled() -> bool:
	return GameSettings.get_setting(GameSettings.GENERAL_SUPPLY_MESSAGES).value()


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
