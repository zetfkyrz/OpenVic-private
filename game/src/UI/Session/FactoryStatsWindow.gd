extends "res://src/UI/Session/Vic2Window.gd"
## Statistics of a factory: the figures of the tooltip of the original game (output per day, maximum and base output, the
## efficiency, the goods the factory needs), the finances of the day, and the productivity of the last ten years: a graph of the
## revenue, the costs and the number of employees by months and a table by years. A Victoria 2 style window that is opened by a click
## on the factory in the production window.

const _LineChart: GDScript = preload("res://src/UI/Session/Vic2LineChart.gd")

const REVENUE_COLOUR: Color = Color(0.08, 0.5, 0.12)
const COSTS_COLOUR: Color = Color(0.78, 0.13, 0.1)
const EMPLOYEES_COLOUR: Color = Color(0.1, 0.2, 0.72)
const _WINDOW_SIZE: Vector2 = Vector2(790, 660)
const _TABLE_YEARS: int = 10

var _province_index: int = -1
var _building_type_index: int = -1

var _subtitle: Label
var _figures: Label
var _finances: Label
var _chart: Control
var _table: Tree


func _ready() -> void:
	setup(_WINDOW_SIZE, "")

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 6)
	content.add_child(root)

	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override(&"font_size", 15)
	_subtitle.add_theme_color_override(&"font_color", MUTED_TEXT_COLOUR)
	root.add_child(_subtitle)

	# The figures of the day on the left, the finances on the right
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 18)
	root.add_child(columns)
	_figures = _create_column(columns)
	_finances = _create_column(columns)

	var chart_title := Label.new()
	chart_title.text = "Продуктивность за последние 10 лет (по месяцам)"
	chart_title.add_theme_font_size_override(&"font_size", 15)
	chart_title.add_theme_color_override(&"font_color", HEADER_COLOUR)
	root.add_child(chart_title)

	_chart = Control.new()
	_chart.set_script(_LineChart)
	_chart.custom_minimum_size = Vector2(0, 200)
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_chart)

	var legend := HBoxContainer.new()
	legend.add_theme_constant_override(&"separation", 18)
	root.add_child(legend)
	_add_legend_item(legend, REVENUE_COLOUR, "Выручка")
	_add_legend_item(legend, COSTS_COLOUR, "Затраты (сырьё и зарплаты)")
	_add_legend_item(legend, EMPLOYEES_COLOUR, "Сотрудники (правая шкала)")

	_table = Tree.new()
	_table.columns = 6
	_table.column_titles_visible = true
	_table.hide_root = true
	_table.select_mode = Tree.SELECT_ROW
	_table.custom_minimum_size = Vector2(0, 150)
	_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for column: int in _table.columns:
		_table.set_column_title(column, ["Год", "Выручка", "Затраты", "Прибыль", "Сотрудники", "Выпуск"][column])
		_table.set_column_expand(column, true)
		_table.set_column_custom_minimum_width(column, 60 if column > 0 else 50)
	root.add_child(_table)

	GameSingleton.gamestate_updated.connect(_on_gamestate_updated)


func _create_column(parent: Control) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(340, 150)
	label.add_theme_font_size_override(&"font_size", 14)
	parent.add_child(label)
	return label


func _add_legend_item(parent: Control, colour: Color, text: String) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	parent.add_child(box)
	var swatch := ColorRect.new()
	swatch.color = colour
	swatch.custom_minimum_size = Vector2(22, 4)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(swatch)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 13)
	box.add_child(label)


## Opens the statistics of the factory of the given type in the state of the province
func open(province_index: int, building_type_index: int) -> void:
	_province_index = province_index
	_building_type_index = building_type_index
	_refresh()
	open_window()


func is_showing(province_index: int, building_type_index: int) -> bool:
	return visible and _province_index == province_index and _building_type_index == building_type_index


func _on_gamestate_updated() -> void:
	if visible:
		_refresh()


func _money(value: float, decimals: int = 0) -> String:
	return "%s ¤" % GUINode.float_to_string_dp(value, decimals)


func _percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)


func _refresh() -> void:
	if _province_index < 0 or _building_type_index < 0:
		return
	var details: Dictionary = PlayerSingleton.get_factory_details(_province_index, _building_type_index)
	if not details.get("found", false):
		close()
		return

	set_title("%s: статистика" % details["name"])
	# The maximum level of the factories of the original game is a formality (99), it is not worth showing
	var max_level: int = int(details["max_level"])
	_subtitle.text = "%s, уровень %d%s%s" % [
		details["state_name"], int(details["level"]),
		" из %d" % max_level if max_level < 50 else "",
		"" if details["open"] else " — завод закрыт",
	]

	var figure_lines: PackedStringArray = [
		"Производство в день: %s (%s)" % [GUINode.float_to_string_dp(float(details["output_per_day"]), 2), details["output_good"]],
		"Максимальное производство: %s" % GUINode.float_to_string_dp(float(details["max_output"]), 2),
		"Базовое производство: %s" % GUINode.float_to_string_dp(float(details["base_output"]), 2),
		"Эффективность выпуска: %s" % _percent(float(details["efficiency"])),
		"Загрузка мощностей: %s" % _percent(float(details["throttle"])),
		"Занятость: %d из %d (%s)" % [int(details["employees"]), int(details["max_employees"]), _percent(float(details["employment_ratio"]))],
	]
	var inputs: Array = details["inputs"]
	if not inputs.is_empty():
		figure_lines.append("Нужные товары в день:")
		for input: Dictionary in inputs:
			figure_lines.append("   %s: %s (запас %s)" % [
				input["name"], GUINode.float_to_string_dp(float(input["quantity"]), 2), GUINode.float_to_string_dp(float(input["stockpile"]), 1),
			])
	_figures.text = "\n".join(figure_lines)

	var state_share: float = float(details["state_share"])
	var owner_name: String = details.get("owner_pop_type", "Капиталисты")
	var finance_lines: PackedStringArray = [
		"Выручка вчера: %s" % _money(float(details["revenue"]), 1),
		"Сырьё вчера: %s" % _money(float(details["input_cost"]), 1),
		"Зарплаты вчера: %s" % _money(float(details["wages"]), 1),
		"Прибыль вчера: %s" % _money(float(details["profit"]), 1),
		"Средняя прибыль в день: %s" % _money(float(details["average_profit"]), 1),
		"Цена продукции: %s" % _money(float(details["output_price"]), 2),
		"Стоимость завода: %s" % _money(float(details["value"]), 0),
		"Казна завода: %s" % _money(float(details["budget"]), 0),
		"Владельцы: государство %s, %s %s" % [_percent(state_share), owner_name.to_lower(), _percent(1.0 - state_share)],
	]
	_finances.text = "\n".join(finance_lines)

	var months: Dictionary = details["months"]
	var labels: PackedStringArray = months["labels"]
	_chart.set_data(labels, [
		{ &"name": "Выручка", &"colour": REVENUE_COLOUR, &"values": months["revenue"], &"group": 0 },
		{ &"name": "Затраты", &"colour": COSTS_COLOUR, &"values": months["costs"], &"group": 0 },
		{ &"name": "Сотрудники", &"colour": EMPLOYEES_COLOUR, &"values": months["employees"], &"group": 1, &"format": "count" },
	])
	_fill_table(labels, months)


# The table by years: the sums of the months of a year (the average of the employees), the newest year first
func _fill_table(labels: PackedStringArray, months: Dictionary) -> void:
	_table.clear()
	var root: TreeItem = _table.create_item()

	var years: Array[String] = []
	var totals: Dictionary[String, Array] = {}
	var revenue: PackedFloat32Array = months["revenue"]
	var costs: PackedFloat32Array = months["costs"]
	var employees: PackedFloat32Array = months["employees"]
	var output: PackedFloat32Array = months["output"]
	for i: int in labels.size():
		var year: String = labels[i].substr(0, 4)
		if not totals.has(year):
			years.append(year)
			totals[year] = [0.0, 0.0, 0.0, 0.0, 0]
		var row: Array = totals[year]
		row[0] += revenue[i]
		row[1] += costs[i]
		row[2] += employees[i]
		row[3] += output[i]
		row[4] += 1

	years.reverse()
	for year: String in years.slice(0, _TABLE_YEARS):
		var row: Array = totals[year]
		var item: TreeItem = _table.create_item(root)
		var profit: float = float(row[0]) - float(row[1])
		var values: PackedStringArray = [
			year,
			GUINode.float_to_string_dp(float(row[0]), 0),
			GUINode.float_to_string_dp(float(row[1]), 0),
			GUINode.float_to_string_dp(profit, 0),
			GUINode.float_to_string_dp(float(row[2]) / maxf(float(row[4]), 1.0), 0),
			GUINode.float_to_string_dp(float(row[3]), 0),
		]
		for column: int in values.size():
			item.set_text(column, values[column])
			if column > 0:
				item.set_text_alignment(column, HORIZONTAL_ALIGNMENT_RIGHT)
		item.set_custom_color(3, REVENUE_COLOUR if profit >= 0.0 else COSTS_COLOUR)
		if int(row[4]) < 12:
			item.set_tooltip_text(0, "Месяцев в статистике: %d" % int(row[4]))
