extends "res://src/UI/Session/Vic2Window.gd"
## Peace negotiations (task B): the war score of both sides, the terms the player builds (states of the enemy that the
## side holds, reparations, humiliation; or the states the player gives up when losing), the price of the terms in war
## score, the forecast of the answer of the other side, the last answer, and the offers made by the AI that the player
## answers. Opened from the war panel (F6 -> Wars -> "Peace negotiations") and automatically when an AI offers peace.

const _SIZE: Vector2 = Vector2(660, 640)
const _GOOD_COLOUR: Color = Color(0.1, 0.45, 0.15)
const _BAD_COLOUR: Color = Color(0.65, 0.1, 0.1)

var _war_id: int = 0
var _info: Dictionary = {}
var _updating: bool = false
var _known_offers: Dictionary[int, bool] = {}

var _header_label: Label
var _concede_check: CheckBox
var _states_tree: Tree
var _reparations_check: CheckBox
var _humiliate_check: CheckBox
var _cost_label: Label
var _forecast_label: Label
var _send_button: Button
var _white_button: Button
var _clear_button: Button
var _response_label: Label
var _offers_tree: Tree
var _accept_button: Button
var _decline_button: Button
var _selected_offer_war: int = 0


func _ready() -> void:
	setup(_SIZE, "Мирные переговоры")

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 6)
	content.add_child(root)

	_header_label = Label.new()
	_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_header_label)

	_concede_check = CheckBox.new()
	_concede_check.text = "Мы проигрываем и уступаем области (вместо требований)"
	_concede_check.toggled.connect(_on_concede_toggled)
	root.add_child(_concede_check)

	_states_tree = Tree.new()
	_states_tree.columns = 4
	_states_tree.column_titles_visible = true
	_states_tree.hide_root = true
	_states_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_states_tree.custom_minimum_size = Vector2(0, 170)
	var titles: PackedStringArray = ["Область", "Владелец", "Очки", "Цель войны"]
	for column: int in titles.size():
		_states_tree.set_column_title(column, titles[column])
	_states_tree.set_column_expand(0, true)
	_states_tree.set_column_custom_minimum_width(0, 160)
	_states_tree.item_edited.connect(_on_state_edited)
	root.add_child(_states_tree)

	var extras := HBoxContainer.new()
	extras.add_theme_constant_override(&"separation", 14)
	root.add_child(extras)
	_reparations_check = CheckBox.new()
	_reparations_check.toggled.connect(_on_reparations_toggled)
	extras.add_child(_reparations_check)
	_humiliate_check = CheckBox.new()
	_humiliate_check.toggled.connect(_on_humiliate_toggled)
	extras.add_child(_humiliate_check)

	_cost_label = Label.new()
	_cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_cost_label)

	_forecast_label = Label.new()
	_forecast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_forecast_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 6)
	root.add_child(buttons)
	_send_button = Button.new()
	_send_button.text = "Предложить мир"
	_send_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_send_button.pressed.connect(_on_send_pressed)
	buttons.add_child(_send_button)
	_white_button = Button.new()
	_white_button.text = "Белый мир"
	_white_button.pressed.connect(_on_white_pressed)
	buttons.add_child(_white_button)
	_clear_button = Button.new()
	_clear_button.text = "Очистить условия"
	_clear_button.pressed.connect(_on_clear_pressed)
	buttons.add_child(_clear_button)

	_response_label = Label.new()
	_response_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_response_label)

	var offers_caption := Label.new()
	offers_caption.text = "Предложения мира от противника:"
	root.add_child(offers_caption)

	_offers_tree = Tree.new()
	_offers_tree.columns = 2
	_offers_tree.column_titles_visible = true
	_offers_tree.hide_root = true
	_offers_tree.select_mode = Tree.SELECT_ROW
	_offers_tree.custom_minimum_size = Vector2(0, 90)
	_offers_tree.set_column_title(0, "От кого / условия")
	_offers_tree.set_column_title(1, "Осталось дней")
	_offers_tree.set_column_expand(0, true)
	_offers_tree.item_selected.connect(_on_offer_selected)
	_offers_tree.nothing_selected.connect(_on_offer_deselected)
	root.add_child(_offers_tree)

	var offer_buttons := HBoxContainer.new()
	offer_buttons.add_theme_constant_override(&"separation", 6)
	root.add_child(offer_buttons)
	_accept_button = Button.new()
	_accept_button.text = "Принять предложение"
	_accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_accept_button.pressed.connect(_on_answer_pressed.bind(true))
	offer_buttons.add_child(_accept_button)
	_decline_button = Button.new()
	_decline_button.text = "Отклонить"
	_decline_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decline_button.pressed.connect(_on_answer_pressed.bind(false))
	offer_buttons.add_child(_decline_button)

	GameSingleton.gamestate_updated.connect(_refresh)


## Opens the negotiations of the war
func open_for_war(war_id: int) -> void:
	_war_id = war_id
	_refresh_inner()
	open_window()


func _refresh() -> void:
	# New offers of the AI open the window by themselves
	var offers: Array = PlayerSingleton.get_peace_offers()
	for offer: Dictionary in offers:
		var war_id: int = offer[&"war_id"]
		if not _known_offers.has(war_id):
			_known_offers[war_id] = true
			_war_id = war_id
			_refresh_inner()
			open_window()
			return
	var current: Dictionary[int, bool] = {}
	for offer: Dictionary in offers:
		current[offer[&"war_id"]] = true
	for war_id: int in _known_offers.keys():
		if not current.has(war_id):
			_known_offers.erase(war_id)

	if visible:
		_refresh_inner()


func _refresh_inner() -> void:
	_info = PlayerSingleton.get_peace_info(_war_id) if _war_id > 0 else {}
	if _info.is_empty():
		# The war is over
		_header_label.text = "Война окончена или не выбрана."
		_states_tree.clear()
		_offers_tree.clear()
		_send_button.disabled = true
		_white_button.disabled = true
		_accept_button.disabled = true
		_decline_button.disabled = true
		return

	_updating = true

	var goal: String = ""
	if _info[&"goal_type"] == 1:
		goal = " Цель войны: %s." % _info[&"goal_name"]
	elif _info[&"goal_type"] == 2:
		goal = " Цель войны: унижение."
	elif _info[&"goal_type"] == 3:
		goal = " Цель войны: репарации."
	_header_label.text = "Война №%d, дней: %d. Мы: %s. Очки войны: у нас %.0f, у врага %.0f.%s\nАтакующие: %s. Защитники: %s." % [
		_war_id, _info[&"days"], "атакуем" if _info[&"we_attack"] else "обороняемся",
		_info[&"our_score"], _info[&"their_score"], goal,
		", ".join(PackedStringArray(_info[&"attackers"])), ", ".join(PackedStringArray(_info[&"defenders"])),
	]

	_concede_check.button_pressed = _info[&"concede"]
	_reparations_check.text = "Репарации: четверть казны (%d очков)" % _info[&"reparations_cost"]
	_humiliate_check.text = "Унижение: престиж (%d очков)" % _info[&"humiliate_cost"]
	_reparations_check.button_pressed = _info[&"reparations"]
	_humiliate_check.button_pressed = _info[&"humiliate"]

	_update_states()

	var cost: float = _info[&"cost"]
	var available: float = _info[&"available"]
	_cost_label.text = "Стоимость условий: %.1f из %.1f очков войны %s" % [
		cost, available, "(у врага)" if _info[&"concede"] else "(у нас)",
	]
	_cost_label.add_theme_color_override(&"font_color", _BAD_COLOUR if cost > available else TEXT_COLOUR)

	var accepts: bool = _info[&"accepts"]
	_forecast_label.text = "Прогноз: %s" % _info[&"reason"]
	_forecast_label.add_theme_color_override(&"font_color", _GOOD_COLOUR if accepts else _BAD_COLOUR)

	_send_button.disabled = cost > available
	_white_button.disabled = false

	if _info.has(&"last_response"):
		var response: Dictionary = _info[&"last_response"]
		_response_label.text = "Последний ответ (%d дн. назад): %s" % [response[&"days_ago"], response[&"text"]]
	else:
		_response_label.text = ""

	_update_offers()
	_updating = false


func _update_states() -> void:
	_states_tree.clear()
	var root: TreeItem = _states_tree.create_item()
	for state: Dictionary in _info[&"states"]:
		var item: TreeItem = _states_tree.create_item(root)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_editable(0, true)
		item.set_text(0, state[&"name"])
		item.set_checked(0, state[&"selected"])
		item.set_text(1, state[&"owner_name"])
		item.set_text(2, "%.1f" % state[&"cost"])
		item.set_text(3, "да" if state[&"is_goal"] else "")
		item.set_metadata(0, state[&"province_number"])


func _update_offers() -> void:
	_offers_tree.clear()
	var root: TreeItem = _offers_tree.create_item()
	var offers: Array = PlayerSingleton.get_peace_offers()
	var to_select: TreeItem = null
	for offer: Dictionary in offers:
		var item: TreeItem = _offers_tree.create_item(root)
		var terms: PackedStringArray = []
		for state_name: String in offer[&"states"]:
			terms.append(state_name)
		if offer[&"reparations"]:
			terms.append("репарации")
		if offer[&"humiliate"]:
			terms.append("унижение")
		var what: String
		if offer[&"concede"]:
			what = "уступает: " + (", ".join(terms) if not terms.is_empty() else "белый мир")
		else:
			what = "требует: " + (", ".join(terms) if not terms.is_empty() else "белый мир")
		item.set_text(0, "%s %s" % [offer[&"from_name"], what])
		item.set_text(1, str(offer[&"days_left"]))
		item.set_metadata(0, offer[&"war_id"])
		if offer[&"war_id"] == _selected_offer_war:
			to_select = item
	if to_select != null:
		to_select.select(0)
	else:
		_selected_offer_war = 0
	_accept_button.disabled = _selected_offer_war == 0
	_decline_button.disabled = _selected_offer_war == 0


func _on_concede_toggled(pressed: bool) -> void:
	if not _updating:
		PlayerSingleton.set_peace_demand(_war_id, 3, 0, pressed)


func _on_reparations_toggled(pressed: bool) -> void:
	if not _updating:
		PlayerSingleton.set_peace_demand(_war_id, 1, 0, pressed)


func _on_humiliate_toggled(pressed: bool) -> void:
	if not _updating:
		PlayerSingleton.set_peace_demand(_war_id, 2, 0, pressed)


func _on_state_edited() -> void:
	if _updating:
		return
	var item: TreeItem = _states_tree.get_edited()
	if item == null:
		return
	PlayerSingleton.set_peace_demand(_war_id, 0, item.get_metadata(0), item.is_checked(0))


func _on_send_pressed() -> void:
	PlayerSingleton.send_peace_offer(_war_id)


func _on_white_pressed() -> void:
	# White peace: no terms
	PlayerSingleton.set_peace_demand(_war_id, 4, 0, true)
	PlayerSingleton.send_peace_offer(_war_id)


func _on_clear_pressed() -> void:
	PlayerSingleton.set_peace_demand(_war_id, 4, 0, true)


func _on_offer_selected() -> void:
	var item: TreeItem = _offers_tree.get_selected()
	_selected_offer_war = item.get_metadata(0) if item != null else 0
	_accept_button.disabled = _selected_offer_war == 0
	_decline_button.disabled = _selected_offer_war == 0


func _on_offer_deselected() -> void:
	_offers_tree.deselect_all()
	_selected_offer_war = 0
	_accept_button.disabled = true
	_decline_button.disabled = true


func _on_answer_pressed(accept: bool) -> void:
	if _selected_offer_war == 0:
		return
	PlayerSingleton.answer_peace_offer(_selected_offer_war, accept)
	_selected_offer_war = 0
