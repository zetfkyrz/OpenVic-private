extends Control
## The "Investments" and "Goods production" tabs of the production window (Victoria 2 style tables on the parchment of the
## window). Investments: what the capitalists and the state are building and the money of the capitalists by region.
## Goods production: what the factories of the country make, grouped by the good.

const _Vic2Window: GDScript = preload("res://src/UI/Session/Vic2Window.gd")
const _AREA := Rect2(33, 64, 942, 545)

var _pages: Array[Control] = []
var _capital_label: Label
var _projects_tree: Tree
var _states_tree: Tree
var _goods_tree: Tree


func _ready() -> void:
	# The look of the credit and ownership windows: parchment tables with a maroon header
	var themer := Control.new()
	themer.set_script(_Vic2Window)
	theme = themer.create_theme()
	themer.free()

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(1024, 632)

	_build_investments_page()
	_build_goods_page()
	show_page(0)


func _make_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.position = _AREA.position
	page.size = _AREA.size
	page.add_theme_constant_override(&"separation", 6)
	add_child(page)
	_pages.append(page)
	return page


func _make_tree(parent: Node, columns: PackedStringArray, widths: PackedInt32Array) -> Tree:
	var tree := Tree.new()
	tree.columns = columns.size()
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i: int in columns.size():
		tree.set_column_title(i, columns[i])
		tree.set_column_expand(i, i == 0)
		tree.set_column_custom_minimum_width(i, widths[i])
	parent.add_child(tree)
	return tree


func _caption(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", Color(0.42, 0.1, 0.17))
	parent.add_child(label)
	return label


func _build_investments_page() -> void:
	var page: VBoxContainer = _make_page()
	_capital_label = _caption(page, "")
	_caption(page, "Проекты: что строят капиталисты и государство")
	_projects_tree = _make_tree(
		page, ["Регион", "Постройка", "Уровень", "Готовность", "Платит"], [260, 150, 90, 100, 130]
	)
	_caption(page, "Регионы: деньги капиталистов")
	_states_tree = _make_tree(
		page, ["Регион", "Капиталисты", "Их деньги", "Свободных мест", "Заводов", "Остаток кредитов"], [260, 110, 110, 120, 80, 140]
	)


func _build_goods_page() -> void:
	var page: VBoxContainer = _make_page()
	_caption(page, "Что производят заводы страны (за вчерашний день), по товарам")
	_goods_tree = _make_tree(page, ["Завод", "Заводов", "Выпуск", "Выручка", "Прибыль"], [300, 90, 110, 120, 120])


## 0 is the factories tab (the pages are hidden), 1 the investments, 2 the goods production
func show_page(index: int) -> void:
	for i: int in _pages.size():
		_pages[i].visible = i == index - 1
	visible = index > 0
	if index > 0:
		refresh(index)


func refresh(page_index: int) -> void:
	if page_index == 1:
		_refresh_investments()
	elif page_index == 2:
		_refresh_goods()


func _money(value: float) -> String:
	return GUINode.float_to_string_dp(value, 1)


func _refresh_investments() -> void:
	var overview: Dictionary = PlayerSingleton.get_investment_overview()
	if overview.is_empty():
		return
	_capital_label.text = "Деньги капиталистов: %s ¤" % _money(overview.get("total_capitalist_money", 0.0))

	_projects_tree.clear()
	var root: TreeItem = _projects_tree.create_item()
	for project: Dictionary in overview.get("projects", []):
		var item: TreeItem = _projects_tree.create_item(root)
		item.set_text(0, GUINode.format_province_name(project[&"province_identifier"]))
		item.set_text(1, str(project[&"name"]))
		item.set_text(2, "%d / %d" % [project[&"level"], project[&"max_level"]])
		item.set_text(3, "%d %%" % roundi(float(project[&"progress"]) * 100.0))
		item.set_text(4, "Капиталисты" if project[&"capitalist_funded"] else "Государство")
		if project[&"built_by_state"]:
			item.set_custom_color(4, Color(0.2, 0.3, 0.6))

	_states_tree.clear()
	var states_root: TreeItem = _states_tree.create_item()
	for state: Dictionary in overview.get("states", []):
		var item: TreeItem = _states_tree.create_item(states_root)
		item.set_text(0, GUINode.format_province_name(state[&"province_identifier"]))
		item.set_text(1, str(state[&"capitalists"]))
		item.set_text(2, _money(state[&"capitalist_money"]))
		var free: Variant = state[&"free_slots"]
		item.set_text(3, ("да" if free else "нет") if typeof(free) == TYPE_BOOL else str(free))
		item.set_text(4, str(state[&"factories"]))
		item.set_text(5, _money(state[&"credit_unspent"]))


func _refresh_goods() -> void:
	# Grouped by the good the factory makes
	var groups: Dictionary = {}
	for state: Dictionary in PlayerSingleton.get_production_info():
		for factory: Dictionary in state[&"factories"]:
			if int(factory[&"level"]) <= 0:
				continue
			var key: int = int(factory[&"output_good_index"])
			var group: Dictionary = groups.get(key, {&"name": str(factory[&"name"]), &"count": 0, &"output": 0.0, &"revenue": 0.0, &"profit": 0.0})
			group[&"count"] = int(group[&"count"]) + 1
			group[&"output"] = float(group[&"output"]) + float(factory[&"output_quantity"])
			group[&"revenue"] = float(group[&"revenue"]) + float(factory[&"revenue"])
			group[&"profit"] = float(group[&"profit"]) + float(factory[&"profit"])
			groups[key] = group

	var rows: Array = groups.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a[&"revenue"]) > float(b[&"revenue"]))
	_goods_tree.clear()
	var root: TreeItem = _goods_tree.create_item()
	for row: Dictionary in rows:
		var item: TreeItem = _goods_tree.create_item(root)
		item.set_text(0, row[&"name"])
		item.set_text(1, str(row[&"count"]))
		item.set_text(2, _money(row[&"output"]))
		item.set_text(3, _money(row[&"revenue"]))
		item.set_text(4, _money(row[&"profit"]))
		if float(row[&"profit"]) < 0.0:
			item.set_custom_color(4, Color(0.7, 0.1, 0.1))
