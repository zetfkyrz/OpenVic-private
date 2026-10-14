extends PanelContainer
## Panel for wars, armies and fronts. Opened with F6 or the "Войны" button.
## Built from plain Godot controls (not from the Victoria 2 GUI files), so it does not depend on interface/*.gui.

const _TOGGLE_KEY: Key = KEY_F6
const _PEACE_WHITE: int = 0
const _PEACE_TAKE: int = 1
const _PEACE_GIVE: int = 2
const _MODE_NAMES: PackedStringArray = ["Оборона", "Наступление"]

var _auto_plan_check: CheckButton
var _tabs: TabContainer

var _wars_list: ItemList
var _war_info: Label
var _war_buttons: Array[Button]
## Window of the peace negotiations, set by the game session
var peace_window: Control
var _declare_country_option: OptionButton
var _declare_goal_option: OptionButton
var _declare_signature: String = ""
var _declare_goal_country: int = -2

var _armies_list: ItemList
var _army_info: Label

var _generals_list: ItemList
var _general_info: Label
var _auto_create_check: CheckButton
var _auto_assign_check: CheckButton
var _general_ids: Array[int] = []

var _blockade_info: Label

var _fronts_list: ItemList
var _front_info: Label
var _enemy_option: OptionButton
var _mode_option: OptionButton
var _draw_check: CheckButton

var _overview: Dictionary = {}
var _war_ids: Array[int] = []
var _army_ids: Array[int] = []
var _front_ids: Array[int] = []
var _enemy_indices: Array[int] = []
var _updating: bool = false


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(620, 440)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	position += Vector2(20, 0)

	var root := VBoxContainer.new()
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "Войны и армии (F6)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_auto_plan_check = CheckButton.new()
	_auto_plan_check.text = "Авто-план"
	_auto_plan_check.tooltip_text = "Армии сами строятся по фронтам против врагов и наступают"
	_auto_plan_check.toggled.connect(_on_auto_plan_toggled)
	header.add_child(_auto_plan_check)
	var close := Button.new()
	close.text = "X"
	close.pressed.connect(hide)
	header.add_child(close)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)

	_build_wars_tab()
	_build_armies_tab()
	_build_generals_tab()
	_build_blockade_tab()
	_build_fronts_tab()

	GameSingleton.gamestate_updated.connect(_refresh)
	PlayerSingleton.province_selected.connect(_on_province_selected)


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event and key_event.pressed and not key_event.echo and key_event.keycode == _TOGGLE_KEY:
		visible = not visible
		if visible:
			_refresh()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func _make_tab(tab_name: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = tab_name
	_tabs.add_child(box)
	return box


func _make_button(text: String, callback: Callable, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _make_list(parent: Node) -> ItemList:
	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(0, 120)
	list.item_selected.connect(func(_index: int) -> void: _update_details())
	parent.add_child(list)
	return list


func _make_info(parent: Node) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0, 90)
	parent.add_child(label)
	return label


# Wars

func _build_wars_tab() -> void:
	var tab := _make_tab("Войны")
	_wars_list = _make_list(tab)
	_war_info = _make_info(tab)
	var buttons := HBoxContainer.new()
	tab.add_child(buttons)
	_war_buttons.append(_make_button("Белый мир", _on_peace_pressed.bind(_PEACE_WHITE), buttons))
	_war_buttons.append(_make_button("Потребовать занятые нами земли", _on_peace_pressed.bind(_PEACE_TAKE), buttons))
	_war_buttons.append(_make_button("Уступить земли, занятые врагом", _on_peace_pressed.bind(_PEACE_GIVE), buttons))
	var negotiate := HBoxContainer.new()
	tab.add_child(negotiate)
	_make_button("Мирные переговоры (условия, области, прогноз)", _on_negotiate_pressed, negotiate)

	# Declaration of a war with a war goal
	var declare := HBoxContainer.new()
	tab.add_child(declare)
	var declare_caption := Label.new()
	declare_caption.text = "Объявить войну:"
	declare.add_child(declare_caption)
	_declare_country_option = OptionButton.new()
	_declare_country_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_declare_country_option.item_selected.connect(_on_declare_country_selected)
	declare.add_child(_declare_country_option)
	_declare_goal_option = OptionButton.new()
	_declare_goal_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	declare.add_child(_declare_goal_option)
	_make_button("Объявить", _on_declare_pressed, declare)


func _on_negotiate_pressed() -> void:
	var war_id: int = _get_selected_id(_wars_list, _war_ids)
	if war_id > 0 and peace_window != null:
		peace_window.open_for_war(war_id)


func _refresh_declare_options() -> void:
	var countries: Array = PlayerSingleton.get_declarable_countries()
	var signature: String = str(countries.size())
	for country: Dictionary in countries:
		signature += ",%d" % country[&"index"]
	if signature == _declare_signature:
		return
	_declare_signature = signature
	var previous: int = _get_declare_country()
	_declare_country_option.clear()
	for country: Dictionary in countries:
		_declare_country_option.add_item(country[&"name"])
		_declare_country_option.set_item_metadata(_declare_country_option.item_count - 1, country[&"index"])
	_declare_goal_country = -2
	for i: int in _declare_country_option.item_count:
		if _declare_country_option.get_item_metadata(i) == previous:
			_declare_country_option.select(i)
			break
	_on_declare_country_selected(_declare_country_option.selected)


func _get_declare_country() -> int:
	if _declare_country_option.item_count == 0 or _declare_country_option.selected < 0:
		return -1
	return _declare_country_option.get_item_metadata(_declare_country_option.selected)


func _on_declare_country_selected(_index: int) -> void:
	var country_index: int = _get_declare_country()
	if country_index == _declare_goal_country:
		return
	_declare_goal_country = country_index
	_declare_goal_option.clear()
	_declare_goal_option.add_item("Без цели (только оккупация)")
	_declare_goal_option.set_item_metadata(0, 0)
	if country_index < 0:
		return
	for state: Dictionary in PlayerSingleton.get_war_goal_states(country_index):
		_declare_goal_option.add_item("Захватить: %s" % state[&"name"])
		_declare_goal_option.set_item_metadata(_declare_goal_option.item_count - 1, state[&"province_number"])


func _on_declare_pressed() -> void:
	var country_index: int = _get_declare_country()
	if country_index < 0:
		return
	var province_number: int = 0
	if _declare_goal_option.selected > 0:
		province_number = _declare_goal_option.get_item_metadata(_declare_goal_option.selected)
	PlayerSingleton.declare_war_with_goal(country_index, 1 if province_number > 0 else 0, province_number)


func _on_peace_pressed(peace_type: int) -> void:
	var war_id: int = _get_selected_id(_wars_list, _war_ids)
	if war_id > 0:
		PlayerSingleton.propose_peace(war_id, peace_type)


# Armies

func _build_armies_tab() -> void:
	var tab := _make_tab("Армии")
	_armies_list = _make_list(tab)
	_army_info = _make_info(tab)
	var buttons := HBoxContainer.new()
	tab.add_child(buttons)
	_make_button("Идти в выбранную на карте провинцию", _on_move_army_pressed, buttons)
	_make_button("Стоп", _on_stop_army_pressed, buttons)


func _on_move_army_pressed() -> void:
	var army_id: int = _get_selected_id(_armies_list, _army_ids)
	var province_number: int = PlayerSingleton.get_selected_province_number()
	if army_id > 0 and province_number > 0:
		PlayerSingleton.move_army(army_id, province_number)


func _on_stop_army_pressed() -> void:
	var army_id: int = _get_selected_id(_armies_list, _army_ids)
	if army_id > 0:
		PlayerSingleton.stop_army(army_id)


# Generals

func _build_generals_tab() -> void:
	var tab := _make_tab("Генералы")
	_generals_list = _make_list(tab)
	_general_info = _make_info(tab)
	var options := HBoxContainer.new()
	tab.add_child(options)
	_auto_create_check = CheckButton.new()
	_auto_create_check.text = "Создавать генералов сами"
	_auto_create_check.tooltip_text = "Раз в месяц на очки лидерства создаётся генерал, пока армий больше, чем генералов"
	_auto_create_check.toggled.connect(_on_leader_auto_toggled)
	options.add_child(_auto_create_check)
	_auto_assign_check = CheckButton.new()
	_auto_assign_check.text = "Назначать в армии сами"
	_auto_assign_check.tooltip_text = "Свободные генералы (лучший по престижу первым) встают во главе армий без генерала"
	_auto_assign_check.toggled.connect(_on_leader_auto_toggled)
	options.add_child(_auto_assign_check)
	var buttons := HBoxContainer.new()
	tab.add_child(buttons)
	_make_button("Создать генерала (очки лидерства)", _on_create_general_pressed, buttons)
	_make_button("Снять с армии", _on_unassign_general_pressed, buttons)


func _on_leader_auto_toggled(_pressed: bool) -> void:
	if not _updating:
		PlayerSingleton.set_leader_auto(_auto_create_check.button_pressed, _auto_assign_check.button_pressed)


func _on_create_general_pressed() -> void:
	PlayerSingleton.create_general()


func _on_unassign_general_pressed() -> void:
	var leader_id: int = _get_selected_id(_generals_list, _general_ids)
	if leader_id <= 0:
		return
	for general: Dictionary in PlayerSingleton.get_generals() + PlayerSingleton.get_admirals():
		if general["leader_id"] == leader_id and general["army_id"] != 0:
			PlayerSingleton.set_army_leader(general["army_id"], 0)


func _refresh_generals() -> void:
	var settings: Dictionary = PlayerSingleton.get_leader_settings()
	if settings.is_empty():
		return
	_auto_create_check.button_pressed = settings["auto_create"]
	_auto_assign_check.button_pressed = settings["auto_assign"]
	var leaders: Array = PlayerSingleton.get_generals()
	for admiral: Dictionary in PlayerSingleton.get_admirals():
		admiral["is_admiral"] = true
		leaders.append(admiral)
	_fill_list(_generals_list, _general_ids, leaders, &"leader_id", func(general: Dictionary) -> String:
		var assignment: String = "свободен"
		if general["army_id"] != 0:
			assignment = "ведёт %s" % general["army_name"]
		return "%s%s, %s, %s, престиж %.2f - %s" % [
			"[адмирал] " if general.get("is_admiral", false) else "", general.get("leader_name", "?"),
			general["personality"], general["background"], general["prestige"], assignment,
		]
	)
	_general_info.text = "Очки лидерства: %.0f (+%.1f в месяц), генерал стоит %.0f.%s" % [
		settings["leadership_points"], settings["monthly_leadership_points"], settings["leader_cost"],
		"" if settings["can_create"] else " Не хватает очков для нового генерала.",
	]


# Blockade

func _build_blockade_tab() -> void:
	var tab := _make_tab("Блокада")
	_blockade_info = Label.new()
	_blockade_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blockade_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(_blockade_info)


func _refresh_blockade() -> void:
	var info: Dictionary = PlayerSingleton.get_blockade_info()
	if info.is_empty():
		return
	var lines: PackedStringArray = []
	lines.append("Доля ваших портов под блокадой: %d%%. Блокада режет снабжение армий (вдвое слабее, чем доля портов)." % \
		roundi(float(info["share"]) * 100.0))
	lines.append("")
	lines.append("Ваши блокированные порты:")
	for port: Dictionary in info["our_blockaded_ports"]:
		lines.append("  " + str(port["name"]))
	if info["our_blockaded_ports"].is_empty():
		lines.append("  нет")
	lines.append("")
	lines.append("Порты врага, которые блокируют ваши флоты:")
	for port: Dictionary in info["enemy_blockaded_ports"]:
		lines.append("  %s (%s)" % [port["name"], port["owner"]])
	if info["enemy_blockaded_ports"].is_empty():
		lines.append("  нет")
	lines.append("")
	lines.append("Блокада: флот воюющей страны стоит в море у порта и там нет флота владельца порта или его союзников.")
	_blockade_info.text = "\n".join(lines)


# Fronts

func _build_fronts_tab() -> void:
	var tab := _make_tab("Фронты")
	_fronts_list = _make_list(tab)
	_front_info = _make_info(tab)

	var create_row := HBoxContainer.new()
	tab.add_child(create_row)
	_enemy_option = OptionButton.new()
	_enemy_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_row.add_child(_enemy_option)
	_make_button("Авто-фронт против врага", _on_auto_front_pressed, create_row)
	_make_button("Пустой фронт", _on_empty_front_pressed, create_row)

	var edit_row := HBoxContainer.new()
	tab.add_child(edit_row)
	_mode_option = OptionButton.new()
	for mode_name in _MODE_NAMES:
		_mode_option.add_item(mode_name)
	_mode_option.item_selected.connect(_on_mode_selected)
	edit_row.add_child(_mode_option)
	_draw_check = CheckButton.new()
	_draw_check.text = "Рисовать"
	_draw_check.tooltip_text = "Каждый клик по вашей провинции на карте добавляет её в линию фронта или убирает из неё"
	edit_row.add_child(_draw_check)
	_make_button("Провинция в линию/из линии", _on_toggle_province_pressed, edit_row)

	var army_row := HBoxContainer.new()
	tab.add_child(army_row)
	_make_button("Назначить выбранную армию", _on_assign_army_pressed.bind(true), army_row)
	_make_button("Снять выбранную армию", _on_assign_army_pressed.bind(false), army_row)
	_make_button("Назначить все свободные армии", _on_assign_free_pressed, army_row)
	_make_button("Удалить фронт", _on_delete_front_pressed, army_row)


func _on_auto_front_pressed() -> void:
	var selected: int = _enemy_option.selected
	if selected >= 0 and selected < _enemy_indices.size():
		PlayerSingleton.create_front(_enemy_indices[selected])


func _on_empty_front_pressed() -> void:
	PlayerSingleton.create_front(-1)


func _on_mode_selected(index: int) -> void:
	if _updating:
		return
	var front_id: int = _get_selected_id(_fronts_list, _front_ids)
	if front_id > 0:
		PlayerSingleton.set_front_mode(front_id, index)


func _on_toggle_province_pressed() -> void:
	var front_id: int = _get_selected_id(_fronts_list, _front_ids)
	var province_number: int = PlayerSingleton.get_selected_province_number()
	if front_id > 0 and province_number > 0:
		PlayerSingleton.toggle_front_province(front_id, province_number)


func _on_assign_army_pressed(assigned: bool) -> void:
	var front_id: int = _get_selected_id(_fronts_list, _front_ids)
	var army_id: int = _get_selected_id(_armies_list, _army_ids)
	if front_id > 0 and army_id > 0:
		PlayerSingleton.set_front_army(front_id, army_id, assigned)


func _on_assign_free_pressed() -> void:
	var front_id: int = _get_selected_id(_fronts_list, _front_ids)
	if front_id > 0:
		PlayerSingleton.assign_free_armies(front_id)


func _on_delete_front_pressed() -> void:
	var front_id: int = _get_selected_id(_fronts_list, _front_ids)
	if front_id > 0:
		PlayerSingleton.delete_front(front_id)


func _on_province_selected(province_number: int) -> void:
	# Drawing mode: clicking provinces builds the front line
	if visible and _draw_check and _draw_check.button_pressed and province_number > 0:
		var front_id: int = _get_selected_id(_fronts_list, _front_ids)
		if front_id > 0:
			PlayerSingleton.toggle_front_province(front_id, province_number)


func _on_auto_plan_toggled(enabled: bool) -> void:
	if not _updating:
		PlayerSingleton.set_auto_plan(enabled)


# Shared

func _get_selected_id(list: ItemList, ids: Array[int]) -> int:
	var selected: PackedInt32Array = list.get_selected_items()
	if selected.is_empty() or selected[0] >= ids.size():
		return 0
	return ids[selected[0]]


func _province_name(identifier: String) -> String:
	return GUINode.format_province_name(identifier)


func _fill_list(list: ItemList, ids: Array[int], entries: Array, id_key: StringName, text_func: Callable) -> void:
	var previous_id: int = _get_selected_id(list, ids)
	list.clear()
	ids.clear()
	for entry: Dictionary in entries:
		ids.append(int(entry[id_key]))
		list.add_item(text_func.call(entry))
		if int(entry[id_key]) == previous_id:
			list.select(list.item_count - 1)


func _refresh() -> void:
	if not visible:
		return

	_overview = PlayerSingleton.get_war_overview()
	if _overview.is_empty():
		return

	_updating = true
	_auto_plan_check.button_pressed = _overview.get("auto_plan", false)

	_fill_list(_wars_list, _war_ids, _overview.get("wars", []), &"id", func(war: Dictionary) -> String:
		return "Война #%d: %s - %s (очки %.0f : %.0f, дней: %d)" % [
			war["id"], _side_names(war["attackers"]), _side_names(war["defenders"]),
			war["attacker_score"], war["defender_score"], war["days"],
		]
	)
	_fill_list(_armies_list, _army_ids, _overview.get("armies", []), &"id", func(army: Dictionary) -> String:
		var state: String = ""
		if army["in_combat"]:
			state = " - БОЙ"
		elif army["moving"]:
			state = " -> %s" % _province_name(army["destination_identifier"])
		return "%s [%s] полков: %d, сила %.0f%%, орг. %.0f%%%s%s" % [
			army["name"], _province_name(army["province_identifier"]), army["regiments"],
			_percent(army["strength"], army["max_strength"]), army["organisation"] * 100.0,
			" (фронт #%d)" % army["front_id"] if army["front_id"] > 0 else "", state,
		]
	)
	_fill_list(_fronts_list, _front_ids, _overview.get("fronts", []), &"id", func(front: Dictionary) -> String:
		return "Фронт #%d: %s, %s, провинций: %d, армий: %d" % [
			front["id"], front["enemy_name"] if front["enemy_name"] != "" else "ручной",
			_MODE_NAMES[front["mode"]], front["provinces"].size(), front["army_ids"].size(),
		]
	)

	# Enemies the player is at war with can get an auto front
	_enemy_option.clear()
	_enemy_indices.clear()
	for war: Dictionary in _overview.get("wars", []):
		var enemies: Array = war["defenders"] if war["we_attack"] else war["attackers"]
		for enemy: Dictionary in enemies:
			if not _enemy_indices.has(int(enemy["index"])):
				_enemy_indices.append(int(enemy["index"]))
				_enemy_option.add_item(enemy["name"])

	_refresh_generals()
	_refresh_blockade()
	_refresh_declare_options()

	_updating = false
	_update_details()


func _update_details() -> void:
	if _overview.is_empty():
		return

	var war_id: int = _get_selected_id(_wars_list, _war_ids)
	var has_war: bool = war_id > 0
	for button in _war_buttons:
		button.disabled = not has_war
	if has_war:
		for war: Dictionary in _overview["wars"]:
			if int(war["id"]) == war_id:
				_war_info.text = "Нападающие: %s\nОбороняющиеся: %s\nОчки войны: нападающие %.0f, обороняющиеся %.0f\nВы %s." % [
					_side_names(war["attackers"]), _side_names(war["defenders"]),
					war["attacker_score"], war["defender_score"],
					"нападающий" if war["we_attack"] else "обороняющийся",
				]
	else:
		_war_info.text = "Вы не воюете. Объявить войну можно на экране дипломатии."

	var army_id: int = _get_selected_id(_armies_list, _army_ids)
	_army_info.text = "Выберите армию в списке, затем провинцию на карте и нажмите «Идти»." if army_id <= 0 else (
		"Выбрана армия #%d. Выбранная на карте провинция: %d" % [army_id, _overview.get("selected_province_number", 0)]
	)

	var front_id: int = _get_selected_id(_fronts_list, _front_ids)
	if front_id <= 0:
		_front_info.text = "Авто-фронт строит линию по границе с врагом. Пустой фронт можно нарисовать вручную кликами по карте."
	else:
		for front: Dictionary in _overview["fronts"]:
			if int(front["id"]) == front_id:
				var names: PackedStringArray = []
				for province: Dictionary in front["provinces"]:
					names.append(_province_name(province["identifier"]))
				_front_info.text = "Линия фронта: %s\nАрмий на фронте: %d" % [
					", ".join(names) if not names.is_empty() else "пуста", front["army_ids"].size(),
				]
				_updating = true
				_mode_option.select(int(front["mode"]))
				_updating = false


func _side_names(side: Array) -> String:
	var names: PackedStringArray = []
	for country: Dictionary in side:
		names.append(country["name"])
	return ", ".join(names)


func _percent(value: float, maximum: float) -> float:
	return value / maximum * 100.0 if maximum > 0.0 else 0.0
