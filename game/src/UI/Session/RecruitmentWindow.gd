extends "res://src/UI/Session/Vic2Window.gd"
## Recruitment of regiments (tasks A4/A7): the type of the regiment, the pops of the province that can provide the
## soldiers (type, culture, regiments they support), the cost in goods from the national stockpile, the reason why a
## recruitment is not possible and the queue of the recruitments in progress with cancelling. The mode "Дивизии" recruits
## a whole division by a template (docs/RECRUITMENT.md): the soldiers from the pops of the whole country, a regiment is
## 3000 men; the manpower of the country (available of the maximum) is shown on top.
## A Victoria 2 style window, opened from the panel of the selected army or from the war panel.

const _SIZE: Vector2 = Vector2(640, 600)

var _province_number: int = 0
var _info: Dictionary = {}
var _selected_pop_id: int = -1
var _ships_mode: bool = false
var _division_mode: bool = false
var _ship_types: Array = []
var _templates: Array = []
var _manpower_label: Label

var _province_label: Label
var _mode_option: OptionButton
var _type_option: OptionButton
var _pops_caption: Label
var _cost_label: Label
var _pops_tree: Tree
var _reason_label: Label
var _recruit_button: Button
var _queue_tree: Tree
var _cancel_button: Button
var _priority_option: OptionButton
var _selected_order_id: int = 0
# The order selected in the queue is a regiment of the mobilisation (it cannot be cancelled alone)
var _selected_mobilisation: bool = false
const _PRIORITY_NAMES: PackedStringArray = ["обычный", "высокий", "срочный"]
var _type_signature: String = ""


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
	selected_button.tooltip_text = "Набор в провинции, выбранной на карте"
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
	_mode_option.add_item("Полки")
	_mode_option.add_item("Корабли")
	_mode_option.add_item("Дивизии")
	_mode_option.item_selected.connect(_on_mode_selected)
	type_row.add_child(_mode_option)
	var type_caption := Label.new()
	type_caption.text = "Тип:"
	type_row.add_child(type_caption)
	_type_option = OptionButton.new()
	_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_option.item_selected.connect(_on_type_selected)
	type_row.add_child(_type_option)

	_cost_label = Label.new()
	_cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_cost_label)

	_pops_caption = Label.new()
	_pops_caption.text = "Население провинции:"
	root.add_child(_pops_caption)

	_pops_tree = Tree.new()
	_pops_tree.columns = 5
	_pops_tree.column_titles_visible = true
	_pops_tree.hide_root = true
	_pops_tree.select_mode = Tree.SELECT_ROW
	_pops_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pops_tree.custom_minimum_size = Vector2(0, 150)
	var titles: PackedStringArray = ["Тип", "Культура", "Размер", "Полков", "Можно набрать"]
	for column: int in titles.size():
		_pops_tree.set_column_title(column, titles[column])
	_pops_tree.item_selected.connect(_on_pop_selected)
	_pops_tree.nothing_selected.connect(_on_pop_deselected)
	root.add_child(_pops_tree)

	_reason_label = Label.new()
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_reason_label)

	_recruit_button = Button.new()
	_recruit_button.text = "Набрать полк"
	_recruit_button.pressed.connect(_on_recruit_pressed)
	root.add_child(_recruit_button)

	var queue_caption := Label.new()
	queue_caption.text = "Очередь набора:"
	root.add_child(queue_caption)

	_queue_tree = Tree.new()
	_queue_tree.columns = 5
	_queue_tree.column_titles_visible = true
	_queue_tree.hide_root = true
	_queue_tree.select_mode = Tree.SELECT_ROW
	_queue_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_queue_tree.custom_minimum_size = Vector2(0, 100)
	var queue_titles: PackedStringArray = ["Полк", "Провинция", "Осталось", "Приоритет", "Состояние"]
	for column: int in queue_titles.size():
		_queue_tree.set_column_title(column, queue_titles[column])
	_queue_tree.item_selected.connect(_on_order_selected)
	_queue_tree.nothing_selected.connect(_on_order_deselected)
	root.add_child(_queue_tree)

	# The priority of the selected order: the orders that wait for the monthly limit start by it (docs/RECRUITMENT.md)
	var order_row := HBoxContainer.new()
	order_row.add_theme_constant_override(&"separation", 6)
	root.add_child(order_row)
	var priority_caption := Label.new()
	priority_caption.text = "Приоритет:"
	order_row.add_child(priority_caption)
	_priority_option = OptionButton.new()
	for priority_name: String in _PRIORITY_NAMES:
		_priority_option.add_item(priority_name)
	_priority_option.tooltip_text = ("Заказы сверх лимита набора в месяц ждут в очереди и начинаются в следующих месяцах:\n" +
		"сначала с более высоким приоритетом, при равном — более старые. Для дивизии — сразу для всех её полков.")
	_priority_option.disabled = true
	_priority_option.item_selected.connect(_on_priority_selected)
	order_row.add_child(_priority_option)
	_cancel_button = Button.new()
	_cancel_button.text = "Отменить набор (товары возвращаются)"
	_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_button.pressed.connect(_on_cancel_pressed)
	order_row.add_child(_cancel_button)

	GameSingleton.gamestate_updated.connect(_refresh)


## Opens the window for the province, 0 or a negative number means the province selected on the map.
## With ships = true the window builds ships in the port of the province instead of recruiting regiments.
func open_for_province(province_number: int, ships: bool = false) -> void:
	_province_number = province_number if province_number > 0 else PlayerSingleton.get_selected_province_number()
	_selected_pop_id = -1
	_type_signature = ""
	_ships_mode = ships
	_division_mode = false
	_mode_option.select(1 if ships else 0)
	_refresh()
	open_window()


func _on_mode_selected(index: int) -> void:
	_ships_mode = index == 1
	_division_mode = index == 2
	_selected_pop_id = -1
	_type_signature = ""
	_refresh()


func _refresh() -> void:
	if not visible:
		return

	_update_queue()
	_update_manpower()

	if _province_number <= 0:
		_province_label.text = "Выберите провинцию на карте"
		_pops_tree.clear()
		_recruit_button.disabled = true
		_reason_label.text = ""
		return

	_info = PlayerSingleton.get_recruitment_info(_province_number)
	if _info.is_empty():
		return

	_province_label.text = "Провинция: %s" % _info[&"province_name"]
	_ship_types = PlayerSingleton.get_ship_types(_province_number) if _ships_mode else []
	_templates = []
	if _division_mode:
		for template: Dictionary in PlayerSingleton.get_division_recruitment_info(_province_number):
			var entry: Dictionary = template.duplicate()
			entry[&"index"] = int(template[&"id"])
			entry[&"unlocked"] = true
			entry[&"name"] = "%s: %d полков, %s чел." % [template[&"name"], template[&"regiments"], _thousands(int(template[&"men"]))]
			_templates.append(entry)
	var pops_mode: bool = not _ships_mode and not _division_mode
	_pops_caption.visible = pops_mode
	_pops_tree.visible = pops_mode
	_recruit_button.text = "Построить корабль" if _ships_mode else ("Набрать дивизию" if _division_mode else "Набрать полк")
	_update_types()
	if pops_mode:
		_update_pops()
	_update_cost_and_reason()


func _get_types() -> Array:
	if _division_mode:
		return _templates
	return _ship_types if _ships_mode else _info.get(&"regiment_types", [])


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
		"Набор и пополнение берут людей из свободных; потери в боях и от истощения убивают солдат-попов.\n" +
		"Армия больше максимума воюет слабее: атака и защита падают на процент превышения.") % int(manpower[&"men_per_regiment"])
	if float(manpower[&"over_pct"]) > 0.0:
		_manpower_label.text += " · превышение %d %%" % int(manpower[&"over_pct"])
	# The monthly limit of the recruitment (ov_war.RECRUIT_MAX_REGIMENTS_PER_MONTH, 0: none)
	var month_limit: int = int(manpower.get(&"month_limit", 0))
	if month_limit > 0:
		_manpower_label.text += " · в этом месяце можно начать ещё %d из %d полков" % [maxi(0, int(manpower.get(&"month_left", 0))), month_limit]
		var waiting: int = int(manpower.get(&"waiting_orders", 0))
		if waiting > 0:
			_manpower_label.text += ", ждут лимита: %d" % waiting
		_manpower_label.tooltip_text += ("\nЛимит набора: %d полков в месяц. Заказы сверх него ждут в очереди (людей и товаров не берут) " +
			"и начинаются в следующих месяцах по приоритету.") % month_limit


func _thousands(value: int) -> String:
	var text: String = str(absi(value))
	var grouped: String = ""
	while text.length() > 3:
		grouped = " " + text.substr(text.length() - 3) + grouped
		text = text.substr(0, text.length() - 3)
	return ("-" if value < 0 else "") + text + grouped


func _update_types() -> void:
	var types: Array = _get_types()
	var signature: String = "divisions;" if _division_mode else ("ships;" if _ships_mode else "regiments;")
	for entry: Dictionary in types:
		signature += "%d:%s;" % [entry[&"index"], entry[&"unlocked"]]
	if signature == _type_signature:
		return
	_type_signature = signature

	var previous_index: int = _get_selected_type_index()
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


func _update_pops() -> void:
	_pops_tree.clear()
	var root: TreeItem = _pops_tree.create_item()
	var to_select: TreeItem = null
	var has_free_men: bool = int(PlayerSingleton.get_manpower().get(&"available_regiments", 0)) > 0
	for pop: Dictionary in _info[&"pops"]:
		# Pops that can never give soldiers only clutter the list
		if not pop[&"recruitable"]:
			continue
		var item: TreeItem = _pops_tree.create_item(root)
		item.set_text(0, pop[&"type_name"])
		item.set_text(1, pop[&"culture_name"])
		item.set_text(2, str(pop[&"size"]))
		item.set_text(3, "%d / %d" % [pop[&"regiments"], pop[&"max_regiments"]])
		var status: String = "да"
		if not pop[&"recruitable"]:
			status = "не призывается"
		elif not pop[&"culture_ok"]:
			status = "культура не допускается"
		elif not has_free_men:
			status = "нет свободных людей"
		item.set_text(4, status)
		item.set_metadata(0, pop[&"id"])
		if pop[&"id"] == _selected_pop_id:
			to_select = item
	if to_select != null:
		to_select.select(0)
	else:
		_selected_pop_id = -1


func _update_cost_and_reason() -> void:
	var type_entry: Dictionary = _get_selected_type()
	if type_entry.is_empty():
		_cost_label.text = ""
		_recruit_button.disabled = true
		return

	var parts: PackedStringArray = []
	for cost: Dictionary in type_entry[&"cost"]:
		parts.append("%s: %.1f (на складе %.1f)" % [cost[&"good_name"], cost[&"amount"], cost[&"have"]])
	_cost_label.text = "Стоимость из национального склада: " + (", ".join(parts) if not parts.is_empty() else "нет") \
		+ ". Срок: %d дн." % type_entry[&"days"]

	if _ships_mode or _division_mode:
		# The reason is worked out by the simulation (port, level of the naval base, goods; the manpower of a division, ...)
		_reason_label.text = type_entry[&"reason"]
		_recruit_button.disabled = type_entry[&"reason"] != ""
		return

	if not _info[&"owned"]:
		_reason_label.text = "Набор возможен только в своей провинции, не занятой врагом."
		_recruit_button.disabled = true
		return
	if _selected_pop_id < 0:
		_reason_label.text = "Выберите население, из которого набирать."
		_recruit_button.disabled = true
		return

	var reason: String = PlayerSingleton.get_recruitment_block_reason(
		_get_selected_type_index(), _province_number, _selected_pop_id
	)
	_reason_label.text = reason
	_recruit_button.disabled = reason != ""


func _update_queue() -> void:
	var queue: Array = PlayerSingleton.get_recruitment_queue()
	_queue_tree.clear()
	var root: TreeItem = _queue_tree.create_item()
	var to_select: TreeItem = null
	# The regiments of a division are one line (cancelling it cancels the division)
	var division_counts: Dictionary = {}
	for order: Dictionary in queue:
		var division_id: int = int(order.get(&"division_id", 0))
		if division_id != 0:
			division_counts[division_id] = int(division_counts.get(division_id, 0)) + 1
	var shown_divisions: Dictionary = {}
	for order: Dictionary in queue:
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
		item.set_text(3, "—" if mobilisation or bool(order.get(&"is_ship", false)) else _PRIORITY_NAMES[clampi(int(order.get(&"priority", 0)), 0, 2)])
		item.set_text(4, "мобилизация" if mobilisation else ("ждёт лимита месяца" if waiting else "набирается"))
		if waiting:
			item.set_custom_color(4, Color(0.95, 0.75, 0.35))
		elif mobilisation:
			item.set_custom_color(4, Color(0.9, 0.85, 0.5))
		item.set_metadata(0, order[&"id"])
		item.set_metadata(1, mobilisation)
		item.set_metadata(2, int(order.get(&"priority", 0)))
		item.set_metadata(3, bool(order.get(&"is_ship", false)))
		if order[&"id"] == _selected_order_id:
			to_select = item
	if to_select != null:
		to_select.select(0)
		_update_order_controls(to_select)
	else:
		_selected_order_id = 0
		_update_order_controls(null)


## The cancel and the priority of the selected order: a regiment of the mobilisation is cancelled only by the demobilisation, a ship has no priority
func _update_order_controls(item: TreeItem) -> void:
	_selected_mobilisation = item != null and bool(item.get_metadata(1))
	var is_ship: bool = item != null and bool(item.get_metadata(3))
	_cancel_button.disabled = _selected_order_id == 0 or _selected_mobilisation
	_cancel_button.tooltip_text = "Мобилизованные полки отменяет только демобилизация" if _selected_mobilisation else ""
	_priority_option.disabled = _selected_order_id == 0 or _selected_mobilisation or is_ship
	if item != null:
		_priority_option.select(clampi(int(item.get_metadata(2)), 0, 2))


func _on_selected_province_pressed() -> void:
	open_for_province(0)


func _on_type_selected(_index: int) -> void:
	_update_cost_and_reason()


func _on_pop_selected() -> void:
	var item: TreeItem = _pops_tree.get_selected()
	_selected_pop_id = item.get_metadata(0) if item != null else -1
	_update_cost_and_reason()


func _on_pop_deselected() -> void:
	_pops_tree.deselect_all()
	_selected_pop_id = -1
	_update_cost_and_reason()


func _on_recruit_pressed() -> void:
	if _ships_mode:
		PlayerSingleton.start_ship_building(_get_selected_type_index(), _province_number)
		return
	if _division_mode:
		PlayerSingleton.start_division_recruitment(_get_selected_type_index(), _province_number)
		return
	if _selected_pop_id < 0:
		return
	PlayerSingleton.start_recruitment(_get_selected_type_index(), _province_number, _selected_pop_id)


func _on_order_selected() -> void:
	var item: TreeItem = _queue_tree.get_selected()
	_selected_order_id = item.get_metadata(0) if item != null else 0
	_update_order_controls(item)


func _on_order_deselected() -> void:
	_queue_tree.deselect_all()
	_selected_order_id = 0
	_update_order_controls(null)


func _on_priority_selected(index: int) -> void:
	if _selected_order_id != 0 and not _selected_mobilisation:
		PlayerSingleton.set_recruitment_priority(_selected_order_id, index)


func _on_cancel_pressed() -> void:
	if _selected_order_id != 0 and not _selected_mobilisation:
		PlayerSingleton.cancel_recruitment(_selected_order_id)
		_selected_order_id = 0
