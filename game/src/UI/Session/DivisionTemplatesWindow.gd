extends "res://src/UI/Session/Vic2Window.gd"
## Templates of the divisions (docs/PLAN_ARMY_SUPPLY_FRONTS.md, sections 4 and 4b): a grid of ranks (the width of the front) and rows (the depth),
## a cell holds a regiment type or is empty; every rank also has slots of support companies. What a country may use grows with its unlocks and
## modifiers (the closed cells are locked). On the right: what the template is worth (attack, defence, durability, cost, supplies...), worked out
## by the simulation (PlayerSingleton.get_division_grid_stats) for the grid that is on the screen, saved or not. A template can be made, changed
## (all the divisions of the template change with it) and deleted (its divisions stay, out of the template). Only the countries with the
## technology of the organisation of the army have templates. This is the working window; the constructor in the style of Victoria 2 is stage 8b.

const _SIZE: Vector2 = Vector2(1000, 620)
const _SHOWN_RANKS: int = 6
const _SHOWN_ROWS: int = 4

var _templates: Array = []
var _selected_id: int = 0
var _signature: String = ""
var _limits: Dictionary = {}
var _cell_types: Array = []

var _info_label: Label
var _tree: Tree
var _grid: GridContainer
var _cell_buttons: Array[OptionButton] = [] # [rank * _SHOWN_ROWS + row]
var _company_buttons: Array[Button] = [] # [rank * companies_shown + slot]
var _stats_label: Label
var _create_button: Button
var _update_button: Button
var _delete_button: Button
var _suspend_updates: bool = false


func _ready() -> void:
	setup(_SIZE, "Шаблоны дивизий")

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 6)
	content.add_child(root)

	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(1, 0)
	root.add_child(_info_label)

	var body := HBoxContainer.new()
	body.add_theme_constant_override(&"separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# The list of the templates
	_tree = Tree.new()
	_tree.columns = 1
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.custom_minimum_size = Vector2(150, 0)
	_tree.item_selected.connect(_on_item_selected)
	_tree.nothing_selected.connect(_on_nothing_selected)
	body.add_child(_tree)

	# The grid: a column for every rank, the rows of regiments and the slots of companies under them
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.custom_minimum_size = Vector2(1, 0)
	body.add_child(middle)
	var grid_caption := Label.new()
	grid_caption.text = "Шеренги (ширина фронта) → ряды (глубина) и роты поддержки"
	middle.add_child(grid_caption)
	_grid = GridContainer.new()
	_grid.columns = _SHOWN_RANKS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override(&"h_separation", 4)
	_grid.add_theme_constant_override(&"v_separation", 4)
	middle.add_child(_grid)

	# The numbers
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(290, 0)
	scroll.clip_contents = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.custom_minimum_size = Vector2(270, 0)
	_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_stats_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override(&"separation", 6)
	root.add_child(button_row)
	_create_button = Button.new()
	_create_button.text = "Создать шаблон"
	_create_button.pressed.connect(_on_create_pressed)
	button_row.add_child(_create_button)
	_update_button = Button.new()
	_update_button.text = "Сохранить выбранный"
	_update_button.tooltip_text = "Изменятся все дивизии этого шаблона: лишние полки уйдут в резерв армии, свободные места займут полки из резерва"
	_update_button.pressed.connect(_on_update_pressed)
	button_row.add_child(_update_button)
	_delete_button = Button.new()
	_delete_button.text = "Удалить выбранный"
	_delete_button.tooltip_text = "Дивизии шаблона остаются, но вне шаблона"
	_delete_button.pressed.connect(_on_delete_pressed)
	button_row.add_child(_delete_button)

	GameSingleton.gamestate_updated.connect(_refresh)


func open_templates() -> void:
	# The window is opened first (a hidden window does not refresh)
	_signature = ""
	open_window()
	_refresh()


func _build_grid() -> void:
	# The columns are the ranks, so the cells of a rank are under each other: the grid is filled by rows of the screen
	for child: Node in _grid.get_children():
		child.queue_free()
	_cell_buttons.clear()
	_company_buttons.clear()
	var companies_shown: int = maxi(1, int(_limits.get(&"max_company_slots", 4)))
	companies_shown = mini(companies_shown, 4)
	var ranks_open: int = int(_limits.get(&"ranks", 3))
	var rows_open: int = int(_limits.get(&"depth", 2))
	var company_open: int = int(_limits.get(&"company_slots", 1))

	_cell_buttons.resize(_SHOWN_RANKS * _SHOWN_ROWS)
	_company_buttons.resize(_SHOWN_RANKS * companies_shown)
	# The screen rows: the rows of regiments first, then the slots of the companies
	for row: int in _SHOWN_ROWS:
		for rank: int in _SHOWN_RANKS:
			var option := OptionButton.new()
			option.custom_minimum_size = Vector2(54, 0)
			option.fit_to_longest_item = false
			option.clip_text = true
			option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			option.add_item("—")
			option.set_item_metadata(0, 0)
			for entry: Dictionary in _cell_types:
				option.add_item(tr(entry[&"identifier"]))
				option.set_item_metadata(option.item_count - 1, int(entry[&"cell"]))
			var open: bool = rank < ranks_open and row < rows_open
			option.disabled = not open
			if not open:
				option.tooltip_text = "Закрыто: " + ("шеренга" if rank >= ranks_open else "ряд") + " открывается технологией"
			option.item_selected.connect(_on_cell_changed)
			_grid.add_child(option)
			_cell_buttons[rank * _SHOWN_ROWS + row] = option
	for slot: int in companies_shown:
		for rank: int in _SHOWN_RANKS:
			var company := Button.new()
			company.text = "рота"
			company.custom_minimum_size = Vector2(54, 0)
			company.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			company.clip_text = true
			var open_company: bool = rank < ranks_open and slot < company_open
			company.disabled = true
			if not open_company:
				company.text = "закрыто"
				company.tooltip_text = "Слот роты открывается технологией"
			else:
				company.tooltip_text = "Рота поддержки (артиллерия, инженеры, разведка): появятся с технологиями, стоят доп. ресурсов"
			_grid.add_child(company)
			_company_buttons[rank * companies_shown + slot] = company


func _cells_from_grid() -> PackedInt32Array:
	var max_ranks: int = int(_limits.get(&"max_ranks", 12))
	var max_depth: int = int(_limits.get(&"max_depth", 8))
	var cells := PackedInt32Array()
	cells.resize(max_ranks * max_depth)
	for rank: int in _SHOWN_RANKS:
		for row: int in _SHOWN_ROWS:
			var option: OptionButton = _cell_buttons[rank * _SHOWN_ROWS + row]
			var value: int = option.get_item_metadata(option.selected) if option.selected >= 0 else 0
			cells[rank * max_depth + row] = value
	return cells


func _show_cells(cells: PackedInt32Array) -> void:
	_suspend_updates = true
	var max_depth: int = int(_limits.get(&"max_depth", 8))
	for rank: int in _SHOWN_RANKS:
		for row: int in _SHOWN_ROWS:
			var option: OptionButton = _cell_buttons[rank * _SHOWN_ROWS + row]
			var wanted: int = cells[rank * max_depth + row] if rank * max_depth + row < cells.size() else 0
			option.select(0)
			for index: int in option.item_count:
				if option.get_item_metadata(index) == wanted:
					option.select(index)
					break
	_suspend_updates = false
	_update_stats()


func _good_text(goods: Array) -> String:
	var parts: PackedStringArray = []
	for entry: Dictionary in goods:
		parts.append("%s %.2f" % [tr(entry[&"good"]), entry[&"amount"]])
	return ", ".join(parts) if not parts.is_empty() else "—"


func _update_stats() -> void:
	if _cell_buttons.is_empty():
		return
	var stats: Dictionary = PlayerSingleton.get_division_grid_stats(_cells_from_grid())
	if stats.is_empty():
		_stats_label.text = ""
		return
	var occupation: String = "мгновенная" if stats[&"occupation_instant"] else "%.2f" % stats[&"occupation_speed"]
	var lines: PackedStringArray = [
		"ОСНОВНЫЕ",
		"Полков: %d, людей: %d" % [stats[&"regiments"], int(stats[&"men"])],
		"Скорость: %.2f" % stats[&"speed"],
		"Вес: %.1f т" % (stats[&"weight"] / 1000.0),
		"Прочность: %.1f" % stats[&"durability"],
		"Организация: %.1f" % stats[&"organisation"],
		"Разведка: %.1f" % stats[&"reconnaissance"],
		"Скорость оккупации: " + occupation,
		"",
		"БОЕВЫЕ (лучшее оружие)",
		"Атака: %.1f" % stats[&"attack"],
		"Защита: %.1f" % stats[&"defence"],
		"Ширина фронта: %d" % stats[&"width"],
		"Глубина: %.1f" % stats[&"depth"],
		"Плотность построения: %.1f" % stats[&"density"],
		"Укреплённость: %.1f" % stats[&"fortification"],
		"Надёжность: %d%%" % int(round(stats[&"reliability"] * 100.0)),
		"",
		"СТОИМОСТЬ",
		_good_text(stats[&"cost"]),
		"",
		"ПРИПАСЫ В ДЕНЬ (с артиллерией)",
		_good_text(stats[&"supply_per_day"]),
		"",
		"ПАТРОНЫ В БОЮ В ДЕНЬ",
		_good_text(stats[&"ammo_per_day"]),
	]
	_stats_label.text = "\n".join(lines)


func _on_cell_changed(_index: int) -> void:
	if not _suspend_updates:
		_update_stats()


func _refresh() -> void:
	if not visible:
		return
	if not PlayerSingleton.has_army_organisation():
		_info_label.text = "Шаблоны дивизий открываются технологией «Организация армии» (цивилизованным странам)."
	else:
		_info_label.text = "Шаблон — сетка: шеренги задают ширину фронта, ряды — глубину; в клетку ставится любой тип полка. Чем шире фронт, тем больше урон, чем глубже — тем дольше держится дивизия. Полки со старта игры остаются вне шаблона, пока вы не нажмёте «Переформировать по шаблону» в панели армии."
	_templates = PlayerSingleton.get_division_templates()
	var limits: Dictionary = PlayerSingleton.get_division_template_limits()
	var types: Array = PlayerSingleton.get_division_cell_types()
	var signature: String = str(_templates) + str(_selected_id) + str(limits) + str(types.size())
	if signature == _signature:
		return
	_signature = signature
	if str(limits) != str(_limits) or types.size() != _cell_types.size() or _cell_buttons.is_empty():
		_limits = limits
		_cell_types = types
		_build_grid()
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var to_select: TreeItem = null
	for entry: Dictionary in _templates:
		var item: TreeItem = _tree.create_item(root)
		item.set_text(0, entry[&"text"])
		item.set_tooltip_text(0, entry[&"text"])
		item.set_metadata(0, entry[&"id"])
		if entry[&"id"] == _selected_id:
			to_select = item
	if to_select == null and not _templates.is_empty():
		# The first template is shown when none is chosen yet
		_selected_id = _templates[0][&"id"]
		to_select = _tree.get_root().get_child(0)
	if to_select != null:
		to_select.select(0)
		for entry: Dictionary in _templates:
			if entry[&"id"] == _selected_id:
				_show_cells(entry[&"cells"])
	else:
		_selected_id = 0
	_update_buttons()
	_update_stats()


func _update_buttons() -> void:
	var allowed: bool = PlayerSingleton.has_army_organisation()
	_create_button.disabled = not allowed
	_update_button.disabled = not allowed or _selected_id == 0
	_delete_button.disabled = not allowed or _selected_id == 0


func _on_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	_selected_id = item.get_metadata(0) if item != null else 0
	for entry: Dictionary in _templates:
		if entry[&"id"] == _selected_id:
			_show_cells(entry[&"cells"])
	_update_buttons()


func _on_nothing_selected() -> void:
	_selected_id = 0
	_tree.deselect_all()
	_update_buttons()


func _on_create_pressed() -> void:
	PlayerSingleton.create_division_template(_cells_from_grid())


func _on_update_pressed() -> void:
	PlayerSingleton.update_division_template(_selected_id, _cells_from_grid())


func _on_delete_pressed() -> void:
	PlayerSingleton.delete_division_template(_selected_id)
	_selected_id = 0
