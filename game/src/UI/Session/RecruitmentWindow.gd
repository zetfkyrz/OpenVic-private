extends "res://src/UI/Session/Vic2Window.gd"
## Recruitment of regiments (tasks A4/A7): the type of the regiment, the pops of the province that can provide the
## soldiers (type, culture, regiments they support), the cost in goods from the national stockpile, the reason why a
## recruitment is not possible and the queue of the recruitments in progress with cancelling.
## A Victoria 2 style window, opened from the panel of the selected army or from the war panel.

const _SIZE: Vector2 = Vector2(640, 600)

var _province_number: int = 0
var _info: Dictionary = {}
var _selected_pop_id: int = -1
var _ships_mode: bool = false
var _ship_types: Array = []

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
var _selected_order_id: int = 0
var _type_signature: String = ""


func _ready() -> void:
	setup(_SIZE, "Набор полков")

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

	var type_row := HBoxContainer.new()
	type_row.add_theme_constant_override(&"separation", 6)
	root.add_child(type_row)
	_mode_option = OptionButton.new()
	_mode_option.add_item("Полки")
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
	_queue_tree.columns = 3
	_queue_tree.column_titles_visible = true
	_queue_tree.hide_root = true
	_queue_tree.select_mode = Tree.SELECT_ROW
	_queue_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_queue_tree.custom_minimum_size = Vector2(0, 100)
	var queue_titles: PackedStringArray = ["Полк", "Провинция", "Осталось"]
	for column: int in queue_titles.size():
		_queue_tree.set_column_title(column, queue_titles[column])
	_queue_tree.item_selected.connect(_on_order_selected)
	_queue_tree.nothing_selected.connect(_on_order_deselected)
	root.add_child(_queue_tree)

	_cancel_button = Button.new()
	_cancel_button.text = "Отменить набор (товары возвращаются)"
	_cancel_button.pressed.connect(_on_cancel_pressed)
	root.add_child(_cancel_button)

	GameSingleton.gamestate_updated.connect(_refresh)


## Opens the window for the province, 0 or a negative number means the province selected on the map.
## With ships = true the window builds ships in the port of the province instead of recruiting regiments.
func open_for_province(province_number: int, ships: bool = false) -> void:
	_province_number = province_number if province_number > 0 else PlayerSingleton.get_selected_province_number()
	_selected_pop_id = -1
	_type_signature = ""
	_ships_mode = ships
	_mode_option.select(1 if ships else 0)
	_refresh()
	open_window()


func _on_mode_selected(index: int) -> void:
	_ships_mode = index == 1
	_selected_pop_id = -1
	_type_signature = ""
	_refresh()


func _refresh() -> void:
	if not visible:
		return

	_update_queue()

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
	_pops_caption.visible = not _ships_mode
	_pops_tree.visible = not _ships_mode
	_recruit_button.text = "Построить корабль" if _ships_mode else "Набрать полк"
	_update_types()
	if not _ships_mode:
		_update_pops()
	_update_cost_and_reason()


func _get_types() -> Array:
	return _ship_types if _ships_mode else _info.get(&"regiment_types", [])


func _update_types() -> void:
	var types: Array = _get_types()
	var signature: String = "ships;" if _ships_mode else "regiments;"
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
		elif pop[&"regiments"] >= pop[&"max_regiments"]:
			status = "нет свободных мест"
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

	if _ships_mode:
		# The reason is worked out by the simulation (port, level of the naval base, goods, ...)
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
	for order: Dictionary in queue:
		var item: TreeItem = _queue_tree.create_item(root)
		item.set_text(0, order[&"type_name"])
		item.set_text(1, order[&"province_name"])
		item.set_text(2, "%d из %d дн." % [order[&"days_left"], order[&"days_total"]])
		item.set_metadata(0, order[&"id"])
		if order[&"id"] == _selected_order_id:
			to_select = item
	if to_select != null:
		to_select.select(0)
	else:
		_selected_order_id = 0
	_cancel_button.disabled = _selected_order_id == 0


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
	if _selected_pop_id < 0:
		return
	PlayerSingleton.start_recruitment(_get_selected_type_index(), _province_number, _selected_pop_id)


func _on_order_selected() -> void:
	var item: TreeItem = _queue_tree.get_selected()
	_selected_order_id = item.get_metadata(0) if item != null else 0
	_cancel_button.disabled = _selected_order_id == 0


func _on_order_deselected() -> void:
	_queue_tree.deselect_all()
	_selected_order_id = 0
	_cancel_button.disabled = true


func _on_cancel_pressed() -> void:
	if _selected_order_id != 0:
		PlayerSingleton.cancel_recruitment(_selected_order_id)
		_selected_order_id = 0
