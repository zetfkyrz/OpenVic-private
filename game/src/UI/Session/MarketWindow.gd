extends "res://src/UI/Session/Vic2Window.gd"
## World market (task C): price of every trading good, change since yesterday, supply, demand, the balance between them,
## the quantity traded and the stockpile of the country. A click on a column title sorts by it; the price history of the
## selected good is drawn under the table. A Victoria 2 style window, opened with F8.

const _SIZE: Vector2 = Vector2(760, 640)
const _TOGGLE_KEY: Key = KEY_F8
const _COLUMNS: PackedStringArray = [
	"Товар", "Категория", "Цена", "Изм.", "Предложение", "Спрос", "Спрос/предл.", "Торговля", "Склад страны",
]
const _KEYS: Array[StringName] = [
	&"name", &"category", &"price", &"price_change", &"supply", &"demand", &"balance", &"traded", &"stockpile",
]

var _tree: Tree
var _graph: _PriceGraph
var _graph_title: Label
var _goods: Array = []
var _sort_key: StringName = &"name"
var _sort_ascending: bool = true
var _selected_name: String = ""


class _PriceGraph extends Control:
	var history: PackedFloat32Array = PackedFloat32Array()
	var base_price: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 120)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.97, 0.94, 0.86, 0.9))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.25, 0.12), false, 1.0)
		if history.size() < 2:
			return
		var low: float = history[0]
		var high: float = history[0]
		for value: float in history:
			low = minf(low, value)
			high = maxf(high, value)
		if base_price > 0.0:
			low = minf(low, base_price)
			high = maxf(high, base_price)
		var span: float = maxf(high - low, 0.001)
		var points := PackedVector2Array()
		for i: int in history.size():
			var x: float = size.x * float(i) / float(history.size() - 1)
			var y: float = size.y - 6.0 - (size.y - 12.0) * (history[i] - low) / span
			points.append(Vector2(x, y))
		if base_price > 0.0:
			var base_y: float = size.y - 6.0 - (size.y - 12.0) * (base_price - low) / span
			draw_line(Vector2(0, base_y), Vector2(size.x, base_y), Color(0.4, 0.4, 0.4, 0.7), 1.0)
		draw_polyline(points, Color(0.6, 0.15, 0.2), 2.0)


func _ready() -> void:
	setup(_SIZE, "Мировой рынок")

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 6)
	content.add_child(root)

	_tree = Tree.new()
	_tree.columns = _COLUMNS.size()
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for column: int in _COLUMNS.size():
		_tree.set_column_title(column, _COLUMNS[column])
		_tree.set_column_custom_minimum_width(column, 70)
	_tree.set_column_expand(0, true)
	_tree.set_column_custom_minimum_width(0, 120)
	_tree.column_title_clicked.connect(_on_column_clicked)
	_tree.item_selected.connect(_on_item_selected)
	root.add_child(_tree)

	_graph_title = Label.new()
	root.add_child(_graph_title)
	_graph = _PriceGraph.new()
	root.add_child(_graph)

	GameSingleton.gamestate_updated.connect(_refresh)


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event and key_event.pressed and not key_event.echo and key_event.keycode == _TOGGLE_KEY:
		if visible:
			close()
		else:
			_refresh_inner()
			open_window()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)


func _refresh() -> void:
	if visible:
		_refresh_inner()


func _refresh_inner() -> void:
	_goods = PlayerSingleton.get_market_overview()
	for good: Dictionary in _goods:
		var supply: float = good[&"supply"]
		good[&"balance"] = float(good[&"demand"]) / supply if supply > 0.0 else 0.0
	_rebuild()


func _rebuild() -> void:
	var key: StringName = _sort_key
	var ascending: bool = _sort_ascending
	_goods.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left: Variant = a[key]
		var right: Variant = b[key]
		return left < right if ascending else left > right
	)

	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var to_select: TreeItem = null
	for good: Dictionary in _goods:
		var item: TreeItem = _tree.create_item(root)
		item.set_text(0, good[&"name"])
		item.set_text(1, good[&"category"])
		item.set_text(2, "%.2f" % good[&"price"])
		var change: float = good[&"price_change"]
		item.set_text(3, "%+.2f" % change)
		item.set_custom_color(3, Color(0.1, 0.45, 0.15) if change > 0.0 else (Color(0.65, 0.1, 0.1) if change < 0.0 else TEXT_COLOUR))
		item.set_text(4, "%.1f" % good[&"supply"])
		item.set_text(5, "%.1f" % good[&"demand"])
		var balance: float = good[&"balance"]
		item.set_text(6, "%.2f" % balance)
		# Demand above supply pushes the price up
		item.set_custom_color(6, Color(0.1, 0.45, 0.15) if balance > 1.05 else (Color(0.65, 0.1, 0.1) if balance < 0.95 and balance > 0.0 else TEXT_COLOUR))
		item.set_text(7, "%.1f" % good[&"traded"])
		item.set_text(8, "%.1f" % good[&"stockpile"])
		item.set_metadata(0, good[&"name"])
		if good[&"name"] == _selected_name:
			to_select = item
	if to_select != null:
		to_select.select(0)
	_update_graph()


func _update_graph() -> void:
	for good: Dictionary in _goods:
		if good[&"name"] == _selected_name:
			_graph.history = good[&"price_history"]
			_graph.base_price = good[&"base_price"]
			_graph.queue_redraw()
			_graph_title.text = "%s: цена за последние дни (серая линия - базовая цена %.2f)" % [good[&"name"], good[&"base_price"]]
			return
	_graph.history = PackedFloat32Array()
	_graph.queue_redraw()
	_graph_title.text = "Выберите товар, чтобы увидеть историю цены"


func _on_column_clicked(column: int, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	var key: StringName = _KEYS[column]
	if key == _sort_key:
		_sort_ascending = not _sort_ascending
	else:
		_sort_key = key
		_sort_ascending = key == &"name" or key == &"category"
	_rebuild()


func _on_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	_selected_name = item.get_metadata(0) if item != null else ""
	_update_graph()
