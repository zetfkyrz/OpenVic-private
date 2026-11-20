extends "res://src/UI/Session/Vic2Window.gd"
## Recruitment (docs/RECRUITMENT.md, docs/PLAN_ARMY_TRAINING.md): the mode "Обучение" is the queue of the training of the
## divisions by the templates (stage A2): a line is a template, how many divisions and where they appear; the lines start
## their divisions from the top as the men of the country allow, a division pays the goods of its template from the national
## stockpile once a week and stands without them. The mode "Корабли" builds ships in a port. The manpower of the country
## (available of the maximum) is shown on top. Regiments of their own are not recruited any more.
## A Victoria 2 style window, opened from the panel of the selected army, from the war panel or from the templates window.

const _SIZE: Vector2 = Vector2(900, 640)
# The colours on the parchment: a warning, a stop
const _WARN_COLOR: Color = Color(0.62, 0.36, 0.02)
const _STOP_COLOR: Color = Color(0.7, 0.12, 0.08)

var _province_number: int = 0
var _info: Dictionary = {}
var _ships_mode: bool = false
var _ship_types: Array = []
var _templates: Array = []
var _manpower_label: Label

var _province_label: Label
var _mode_option: OptionButton
var _type_option: OptionButton
var _count_spin: SpinBox
var _cost_label: Label
var _reason_label: Label
var _recruit_button: Button
var _queue_tree: Tree
var _cancel_button: Button
var _up_button: Button
var _release_button: Button
# The selected division in training (stage A3): its id, its line and what a release now gives (metadata 4 of its row)
var _selected_division: Dictionary = {}
var _down_button: Button
var _priority_option: OptionButton
# The selected line of the queue: a line of the training (its id) or an order (a ship, a regiment of the mobilisation)
var _selected_line_id: int = 0
var _selected_order_id: int = 0
# The order selected in the queue is a regiment of the mobilisation (it cannot be cancelled alone)
var _selected_mobilisation: bool = false
const _PRIORITY_NAMES: PackedStringArray = ["обычный", "высокий", "срочный"]
var _type_signature: String = ""
# The template to select when the window opens from the templates window
var _wanted_template_id: int = 0


func _ready() -> void:
	setup(_SIZE, "Набор войск")

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 6)
	content.add_child(root)

	var province_row := HBoxContainer.new()
	province_row.add_theme_constant_override(&"separation", 6)
	root.add_child(province_row)
	_province_label = Label.new()
	_province_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	province_row.add_child(_province_label)
	var selected_button := Button.new()
	selected_button.text = "Выбранная провинция"
	selected_button.tooltip_text = "Развернуть дивизии (построить корабли) в провинции, выбранной на карте"
	selected_button.pressed.connect(_on_selected_province_pressed)
	province_row.add_child(selected_button)

	_manpower_label = Label.new()
	_manpower_label.add_theme_color_override(&"font_color", Color(0.95, 0.85, 0.55))
	_manpower_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_manpower_label.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(_manpower_label)

	var type_row := HBoxContainer.new()
	type_row.add_theme_constant_override(&"separation", 6)
	root.add_child(type_row)
	_mode_option = OptionButton.new()
	_mode_option.add_item("Обучение")
	_mode_option.add_item("Корабли")
	_mode_option.item_selected.connect(_on_mode_selected)
	type_row.add_child(_mode_option)
	var type_caption := Label.new()
	type_caption.text = "Тип:"
	type_row.add_child(type_caption)
	_type_option = OptionButton.new()
	_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_option.item_selected.connect(_on_type_selected)
	type_row.add_child(_type_option)
	_count_spin = SpinBox.new()
	_count_spin.min_value = 1
	_count_spin.max_value = 100
	_count_spin.value = 1
	_count_spin.suffix = "див."
	_count_spin.tooltip_text = "Сколько дивизий этого шаблона обучить"
	type_row.add_child(_count_spin)

	_cost_label = Label.new()
	_cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_cost_label)

	_reason_label = Label.new()
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_reason_label)

	_recruit_button = Button.new()
	_recruit_button.text = "Добавить в очередь обучения"
	_recruit_button.pressed.connect(_on_recruit_pressed)
	root.add_child(_recruit_button)

	var queue_caption := Label.new()
	queue_caption.text = "Очередь (строки обучения идут сверху вниз):"
	root.add_child(queue_caption)

	_queue_tree = Tree.new()
	_queue_tree.columns = 5
	_queue_tree.column_titles_visible = true
	_queue_tree.hide_root = true
	_queue_tree.select_mode = Tree.SELECT_ROW
	_queue_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_queue_tree.custom_minimum_size = Vector2(0, 220)
	var queue_titles: PackedStringArray = ["Что", "Провинция", "Срок", "Товары", "Состояние"]
	for column: int in queue_titles.size():
		_queue_tree.set_column_title(column, queue_titles[column])
	var ratios: PackedInt32Array = [4, 2, 2, 1, 5]
	for column: int in ratios.size():
		_queue_tree.set_column_expand_ratio(column, ratios[column])
		_queue_tree.set_column_clip_content(column, true)
	_queue_tree.item_selected.connect(_on_order_selected)
	_queue_tree.nothing_selected.connect(_on_order_deselected)
	root.add_child(_queue_tree)

	var order_row := HBoxContainer.new()
	order_row.add_theme_constant_override(&"separation", 6)
	root.add_child(order_row)
	_up_button = Button.new()
	_up_button.text = "Вверх"
	_up_button.tooltip_text = "Строка выше начинает свои дивизии раньше"
	_up_button.pressed.connect(_on_move_pressed.bind(true))
	order_row.add_child(_up_button)
	_down_button = Button.new()
	_down_button.text = "Вниз"
	_down_button.pressed.connect(_on_move_pressed.bind(false))
	order_row.add_child(_down_button)
	_release_button = Button.new()
	_release_button.text = "Выпустить досрочно"
	_release_button.pressed.connect(_on_release_pressed)
	order_row.add_child(_release_button)
	# The priority of the selected order (a ship, an order of the monthly limit)
	var priority_caption := Label.new()
	priority_caption.text = "Приоритет:"
	order_row.add_child(priority_caption)
	_priority_option = OptionButton.new()
	for priority_name: String in _PRIORITY_NAMES:
		_priority_option.add_item(priority_name)
	_priority_option.tooltip_text = ("Заказы сверх лимита набора в месяц ждут в очереди и начинаются в следующих месяцах:\n" +
		"сначала с более высоким приоритетом, при равном — более старые.")
	_priority_option.disabled = true
	_priority_option.item_selected.connect(_on_priority_selected)
	order_row.add_child(_priority_option)
	_cancel_button = Button.new()
	_cancel_button.text = "Отменить"
	_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_button.pressed.connect(_on_cancel_pressed)
	order_row.add_child(_cancel_button)

	GameSingleton.gamestate_updated.connect(_refresh)


## Opens the window for the province, 0 or a negative number means the province selected on the map.
## With ships = true the window builds ships in the port of the province instead of training divisions.
func open_for_province(province_number: int, ships: bool = false) -> void:
	_province_number = province_number if province_number > 0 else PlayerSingleton.get_selected_province_number()
	_type_signature = ""
	_ships_mode = ships
	_mode_option.select(1 if ships else 0)
	_refresh()
	open_window()


## Opens the training of the template (the button "Обучать" of the templates window): the capital if no province is selected
func open_for_template(template_id: int) -> void:
	_wanted_template_id = template_id
	var province_number: int = PlayerSingleton.get_selected_province_number()
	if province_number <= 0 or PlayerSingleton.get_training_block_reason(template_id, province_number) != "":
		province_number = PlayerSingleton.get_player_capital_number()
	open_for_province(province_number)


func _on_mode_selected(index: int) -> void:
	_ships_mode = index == 1
	_type_signature = ""
	_refresh()


func _refresh() -> void:
	if not visible:
		return

	_update_queue()
	_update_manpower()
	_count_spin.visible = not _ships_mode
	_recruit_button.text = "Построить корабль" if _ships_mode else "Добавить в очередь обучения"

	if _province_number <= 0:
		_province_label.text = "Выберите провинцию на карте"
		_recruit_button.disabled = true
		_reason_label.text = ""
		return

	_info = PlayerSingleton.get_recruitment_info(_province_number)
	if _info.is_empty():
		return

	_province_label.text = "Провинция: %s" % _info[&"province_name"]
	_ship_types = PlayerSingleton.get_ship_types(_province_number) if _ships_mode else []
	_templates = []
	if not _ships_mode:
		for template: Dictionary in PlayerSingleton.get_division_recruitment_info(_province_number):
			var entry: Dictionary = template.duplicate()
			entry[&"index"] = int(template[&"id"])
			entry[&"unlocked"] = true
			entry[&"name"] = "%s: %d полков, %s чел." % [template[&"name"], template[&"regiments"], _thousands(int(template[&"men"]))]
			_templates.append(entry)
	_update_types()
	_update_cost_and_reason()


func _get_types() -> Array:
	return _ship_types if _ships_mode else _templates


## The manpower of the country: the regiments the pops of soldiers support (a regiment is 3000 men), available of the maximum
func _update_manpower() -> void:
	var manpower: Dictionary = PlayerSingleton.get_manpower()
	if manpower.is_empty():
		_manpower_label.text = ""
		return
	_manpower_label.text = "Полков %d, можно набрать ещё %d · Люди в армии %s из %s · свободно %s чел." % [
		int(manpower[&"regiments"]), int(manpower[&"available_regiments"]),
		_thousands(int(manpower[&"army_men"])), _thousands(int(manpower[&"max_men"])),
		_thousands(int(manpower[&"available_men"]))]
	_manpower_label.tooltip_text = ("Максимум — солдаты-попы своих, не оккупированных провинций (на войне +10 %%), полк — %d чел.\n" +
		"Обучение и пополнение берут людей из свободных; потери в боях и от истощения убивают солдат-попов.\n" +
		"Армия больше максимума воюет слабее: атака и защита падают на процент превышения.") % int(manpower[&"men_per_regiment"])
	if float(manpower[&"combat_multiplier"]) < 1.0:
		_manpower_label.text += " · превышение %d %%" % int(manpower[&"over_pct"])


func _thousands(value: int) -> String:
	var text: String = str(absi(value))
	var grouped: String = ""
	while text.length() > 3:
		grouped = " " + text.substr(text.length() - 3) + grouped
		text = text.substr(0, text.length() - 3)
	return ("-" if value < 0 else "") + text + grouped


func _update_types() -> void:
	var types: Array = _get_types()
	var signature: String = "ships;" if _ships_mode else "templates;"
	for entry: Dictionary in types:
		signature += "%d:%s;" % [entry[&"index"], entry[&"unlocked"]]
	if signature == _type_signature:
		return
	_type_signature = signature

	var previous_index: int = _wanted_template_id if _wanted_template_id > 0 and not _ships_mode else _get_selected_type_index()
	_wanted_template_id = 0
	_type_option.clear()
	for entry: Dictionary in types:
		var text: String = "%s (%d дн.)" % [entry[&"name"], entry[&"days"]]
		if not entry[&"unlocked"]:
			text += " - не открыт"
		_type_option.add_item(text)
		_type_option.set_item_metadata(_type_option.item_count - 1, entry[&"index"])
		_type_option.set_item_disabled(_type_option.item_count - 1, not entry[&"unlocked"])

	var to_select: int = 0
	for i: int in _type_option.item_count:
		if _type_option.get_item_metadata(i) == previous_index:
			to_select = i
			break
	if _type_option.item_count > 0:
		_type_option.select(to_select)


func _get_selected_type_index() -> int:
	if _type_option.item_count == 0 or _type_option.selected < 0:
		return -1
	return _type_option.get_item_metadata(_type_option.selected)


func _get_selected_type() -> Dictionary:
	var index: int = _get_selected_type_index()
	for entry: Dictionary in _get_types():
		if entry[&"index"] == index:
			return entry
	return {}


func _update_cost_and_reason() -> void:
	var type_entry: Dictionary = _get_selected_type()
	if type_entry.is_empty():
		_cost_label.text = "Нет шаблонов дивизий: создайте шаблон в окне шаблонов." if not _ships_mode else ""
		_reason_label.text = ""
		_recruit_button.disabled = true
		return

	var parts: PackedStringArray = []
	for cost: Dictionary in type_entry[&"cost"]:
		parts.append("%s: %.1f (на складе %.1f)" % [cost[&"good_name"], cost[&"amount"], cost[&"have"]])
	var goods: String = ", ".join(parts) if not parts.is_empty() else "нет"
	if _ships_mode:
		_cost_label.text = "Стоимость из национального склада: %s. Срок: %d дн." % [goods, type_entry[&"days"]]
		# The reason is worked out by the simulation (port, level of the naval base, goods)
		_reason_label.text = type_entry[&"reason"]
		_reason_label.remove_theme_color_override(&"font_color")
		_recruit_button.disabled = type_entry[&"reason"] != ""
		return

	_cost_label.text = ("Дивизия: %s. Срок обучения: %d дн. Товары списываются со склада раз в неделю равными долями; " +
		"нет товара — обучение стоит. Люди берутся при начале обучения.") % [goods, type_entry[&"days"]]
	var reason: String = PlayerSingleton.get_training_block_reason(_get_selected_type_index(), _province_number)
	_recruit_button.disabled = reason != ""
	if reason != "":
		_reason_label.text = reason
		_reason_label.remove_theme_color_override(&"font_color")
	elif String(type_entry[&"reason"]) != "":
		# not a block: the line waits for the men, a division in training for the goods
		_reason_label.text = "Сейчас: %s. Строка подождёт людей, обучение — товаров." % type_entry[&"reason"]
		_reason_label.add_theme_color_override(&"font_color", _WARN_COLOR)
	else:
		_reason_label.text = ""


func _update_queue() -> void:
	_queue_tree.clear()
	var root: TreeItem = _queue_tree.create_item()
	var to_select: TreeItem = null

	# The lines of the training, from the top, and their divisions in training under them
	var lines: Array = PlayerSingleton.get_training_lines()
	for index: int in lines.size():
		var line: Dictionary = lines[index]
		var divisions: Array = line[&"divisions"]
		var item: TreeItem = _queue_tree.create_item(root)
		item.set_text(0, "%d. %s × %d" % [index + 1, line[&"template_name"], int(line[&"remaining"]) + divisions.size()])
		item.set_text(1, line[&"province_name"])
		item.set_text(2, "не начато: %d" % int(line[&"remaining"]) if int(line[&"remaining"]) > 0 else "")
		var stalled: int = 0
		for division: Dictionary in divisions:
			stalled += 1 if bool(division[&"stalled"]) else 0
		var state: String = "обучается"
		if bool(line[&"waiting_men"]):
			state = "ждёт людей (%s чел.)" % _thousands(int(line[&"needed_men"]))
			item.set_custom_color(4, _WARN_COLOR)
		elif divisions.is_empty():
			state = "ждёт начала"
		elif stalled == divisions.size():
			state = "стоит: не хватает товаров"
			item.set_custom_color(4, _STOP_COLOR)
		elif stalled > 0:
			state = "обучается, стоят %d из %d" % [stalled, divisions.size()]
			item.set_custom_color(4, _WARN_COLOR)
		item.set_text(4, state)
		item.set_tooltip_text(4, state)
		item.set_metadata(0, int(line[&"id"]))
		item.set_metadata(1, "line")
		item.set_metadata(2, index == 0)
		item.set_metadata(3, index == lines.size() - 1)
		if int(line[&"id"]) == _selected_line_id and _selected_division.is_empty():
			to_select = item
		for division: Dictionary in divisions:
			var child: TreeItem = _queue_tree.create_item(item)
			child.set_text(0, "Дивизия, %d полков" % int(division[&"regiments"]))
			child.set_text(2, "%d из %d дн." % [int(division[&"days_left"]), int(division[&"days_total"])])
			child.set_text(3, "%d %%" % roundi(float(division[&"goods_paid"]) * 100.0))
			if bool(division.get(&"released", false)):
				child.set_text(4, "выпускается досрочно")
				child.set_custom_color(4, _WARN_COLOR)
			elif bool(division[&"stalled"]):
				child.set_text(4, "стоит: нет %s" % division[&"missing"] if String(division[&"missing"]) != "" else "стоит: нет товаров")
				child.set_tooltip_text(4, "Не хватает на неделю обучения (на складе из нужного): %s" % division[&"missing"])
				child.set_custom_color(4, _STOP_COLOR)
			else:
				child.set_text(4, "обучается")
			child.set_metadata(0, int(line[&"id"]))
			child.set_metadata(1, "division")
			child.set_metadata(2, index == 0)
			child.set_metadata(3, index == lines.size() - 1)
			child.set_metadata(4, {
				&"division_id": int(division[&"division_id"]), &"order_id": int(division.get(&"order_id", 0)), &"line_id": int(line[&"id"]),
				&"strength": float(division.get(&"release_strength", 0.0)), &"organisation": float(division.get(&"release_organisation", 0.0)),
				&"released": bool(division.get(&"released", false)),
			})
			if not _selected_division.is_empty() and int(_selected_division[&"division_id"]) == int(division[&"division_id"]):
				to_select = child

	# The other orders: ships, the regiments of the mobilisation
	var queue: Array = PlayerSingleton.get_recruitment_queue()
	var division_counts: Dictionary = {}
	for order: Dictionary in queue:
		var division_id: int = int(order.get(&"division_id", 0))
		if division_id != 0:
			division_counts[division_id] = int(division_counts.get(division_id, 0)) + 1
	var shown_divisions: Dictionary = {}
	for order: Dictionary in queue:
		if int(order.get(&"training_line", 0)) != 0:
			continue
		var division_id: int = int(order.get(&"division_id", 0))
		if division_id != 0 and shown_divisions.has(division_id):
			continue
		shown_divisions[division_id] = true
		var item: TreeItem = _queue_tree.create_item(root)
		var mobilisation: bool = bool(order.get(&"mobilisation", false))
		var waiting: bool = bool(order.get(&"waiting", false))
		if division_id != 0:
			item.set_text(0, "Дивизия (%s, %d полков)" % [order[&"template_name"], int(division_counts[division_id])])
		else:
			item.set_text(0, order[&"type_name"])
		item.set_text(1, order[&"province_name"])
		item.set_text(2, ("%d дн. после начала" % int(order[&"days_total"])) if waiting else "%d из %d дн." % [order[&"days_left"], order[&"days_total"]])
		item.set_text(4, "мобилизация" if mobilisation else ("ждёт лимита месяца" if waiting else "строится" if bool(order.get(&"is_ship", false)) else "набирается"))
		if waiting:
			item.set_custom_color(4, _WARN_COLOR)
		elif mobilisation:
			item.set_custom_color(4, Color(0.9, 0.85, 0.5))
		item.set_metadata(0, order[&"id"])
		item.set_metadata(1, "mobilisation" if mobilisation else ("ship" if bool(order.get(&"is_ship", false)) else "order"))
		item.set_metadata(2, int(order.get(&"priority", 0)))
		if _selected_line_id == 0 and _selected_division.is_empty() and order[&"id"] == _selected_order_id:
			to_select = item
	if to_select != null:
		to_select.select(0)
		_update_order_controls(to_select)
	else:
		_selected_line_id = 0
		_selected_order_id = 0
		_selected_division = {}
		_update_order_controls(null)


## The buttons of the selected line: a line of the training moves up and down and is removed with its divisions in training (the goods paid
## come back); an order is cancelled (a regiment of the mobilisation only by the demobilisation), its priority changes (not of a ship)
func _update_order_controls(item: TreeItem) -> void:
	var kind: String = String(item.get_metadata(1)) if item != null else ""
	_selected_mobilisation = kind == "mobilisation"
	var is_line: bool = kind == "line"
	var is_division: bool = kind == "division"
	_up_button.disabled = not (is_line or is_division) or bool(item.get_metadata(2))
	_down_button.disabled = not (is_line or is_division) or bool(item.get_metadata(3))
	# the early release of a division in training: the equipment and the training it got, the reinforcement adds the rest
	var release: Dictionary = item.get_metadata(4) if is_division else {}
	_release_button.disabled = not is_division or bool(release.get(&"released", false))
	_release_button.tooltip_text = ("Дивизия выйдет завтра: сила %d %% (доля полученного снаряжения), организация %d %% (доля пройденного обучения).\n" +
		"Остальное доберёт пополнение — из свободных людей и товаров склада.") % [
		roundi(float(release.get(&"strength", 0.0)) * 100.0), roundi(float(release.get(&"organisation", 0.0)) * 100.0)] if is_division \
		else "Выберите дивизию в обучении (строку под строкой очереди)"
	_cancel_button.disabled = item == null or _selected_mobilisation
	_cancel_button.text = "Убрать строку" if is_line else ("Отменить дивизию" if is_division else "Отменить")
	_cancel_button.tooltip_text = "Мобилизованные полки отменяет только демобилизация" if _selected_mobilisation 		else ("Люди свободны, оплаченная доля товаров возвращается на склад" if is_line or is_division else "")
	_priority_option.disabled = kind != "order"
	if kind == "order":
		_priority_option.select(clampi(int(item.get_metadata(2)), 0, 2))


func _on_selected_province_pressed() -> void:
	open_for_province(0, _ships_mode)


func _on_type_selected(_index: int) -> void:
	_update_cost_and_reason()


func _on_recruit_pressed() -> void:
	if _ships_mode:
		PlayerSingleton.start_ship_building(_get_selected_type_index(), _province_number)
		return
	PlayerSingleton.add_training_line(_get_selected_type_index(), _province_number, int(_count_spin.value))


func _on_order_selected() -> void:
	var item: TreeItem = _queue_tree.get_selected()
	var kind: String = String(item.get_metadata(1)) if item != null else ""
	_selected_division = item.get_metadata(4) if kind == "division" else {}
	if kind == "line" or kind == "division":
		_selected_line_id = int(item.get_metadata(0))
		_selected_order_id = 0
	else:
		_selected_line_id = 0
		_selected_order_id = int(item.get_metadata(0)) if item != null else 0
	_update_order_controls(item)


func _on_order_deselected() -> void:
	_queue_tree.deselect_all()
	_selected_line_id = 0
	_selected_order_id = 0
	_selected_division = {}
	_update_order_controls(null)


func _on_move_pressed(up: bool) -> void:
	if _selected_line_id != 0:
		PlayerSingleton.move_training_line(_selected_line_id, up)


func _on_priority_selected(index: int) -> void:
	if _selected_order_id != 0 and not _selected_mobilisation:
		PlayerSingleton.set_recruitment_priority(_selected_order_id, index)


func _on_release_pressed() -> void:
	if not _selected_division.is_empty():
		PlayerSingleton.release_training_division(int(_selected_division[&"division_id"]))


func _on_cancel_pressed() -> void:
	if not _selected_division.is_empty():
		PlayerSingleton.cancel_recruitment(int(_selected_division[&"order_id"]))
		_selected_division = {}
		return
	if _selected_line_id != 0:
		PlayerSingleton.remove_training_line(_selected_line_id)
		_selected_line_id = 0
		return
	if _selected_order_id != 0 and not _selected_mobilisation:
		PlayerSingleton.cancel_recruitment(_selected_order_id)
		_selected_order_id = 0
