extends "res://src/UI/Session/Vic2Window.gd"
## Dialog with the owners of a factory: a pie chart of the shares of the state and of the investors (capitalists),
## the finances of the factory and buttons to buy shares from the capitalists or sell shares to them.
## A Victoria 2 style window (frame, close button, dragging), opened from the ownership button of a factory.

const _PERCENTS: PackedInt32Array = [10, 25, 100]

var _province_index: int = -1
var _building_type_index: int = -1

var _pie: _Pie
var _info: Label
var _buy_buttons: Array[Button] = []
var _sell_buttons: Array[Button] = []
var _priority_buttons: Array[Button] = []
const _PRIORITY_NAMES: PackedStringArray = ["Низкий", "Обычный", "Высокий"]


class _Pie extends Control:
	const STATE_COLOUR: Color = Color(0.72, 0.34, 0.27)
	const INVESTOR_COLOUR: Color = Color(0.45, 0.72, 0.86)

	var state_share: float = 1.0

	func _init() -> void:
		custom_minimum_size = Vector2(160, 160)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var centre: Vector2 = size / 2.0
		var radius: float = minf(size.x, size.y) / 2.0 - 4.0
		draw_circle(centre + Vector2(2, 2), radius + 1.0, Color(0, 0, 0, 0.3))
		_draw_slice(centre, radius, 0.0, state_share, STATE_COLOUR)
		_draw_slice(centre, radius, state_share, 1.0, INVESTOR_COLOUR)
		draw_circle(centre + Vector2(-radius * 0.25, -radius * 0.3), radius * 0.55, Color(1, 1, 1, 0.12))
		draw_arc(centre, radius, 0.0, TAU, 64, Color(0.1, 0.17, 0.22), 2.0)

	func _draw_slice(centre: Vector2, radius: float, from_share: float, to_share: float, colour: Color) -> void:
		if to_share - from_share <= 0.0005:
			return
		# Slices start at the top and go clockwise
		var start_angle: float = -PI / 2.0 + from_share * TAU
		var end_angle: float = -PI / 2.0 + to_share * TAU
		var points: PackedVector2Array = [centre]
		var steps: int = maxi(2, int((to_share - from_share) * 64.0))
		for i: int in steps + 1:
			var angle: float = lerpf(start_angle, end_angle, float(i) / float(steps))
			points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, colour)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var offset: Vector2 = (event as InputEventMouseMotion).position - size / 2.0
			var share: float = fposmod(offset.angle() + PI / 2.0, TAU) / TAU
			if share < state_share:
				tooltip_text = "Государство: %d%%" % roundi(state_share * 100.0)
			else:
				tooltip_text = "Инвесторы (капиталисты): %d%%" % roundi((1.0 - state_share) * 100.0)


func _ready() -> void:
	setup(Vector2(520, 430), "")

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 8)
	content.add_child(root)

	var body := HBoxContainer.new()
	body.add_theme_constant_override(&"separation", 14)
	root.add_child(body)
	_pie = _Pie.new()
	body.add_child(_pie)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(300, 0)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_info)

	# Hiring priority: factories with a higher priority hire workers first
	var priority_row := HBoxContainer.new()
	priority_row.add_theme_constant_override(&"separation", 6)
	root.add_child(priority_row)
	var priority_label := Label.new()
	priority_label.text = "Приоритет найма:"
	priority_row.add_child(priority_label)
	for level: int in _PRIORITY_NAMES.size():
		var priority_button := Button.new()
		priority_button.text = _PRIORITY_NAMES[level]
		priority_button.toggle_mode = true
		priority_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		priority_button.pressed.connect(_on_priority_pressed.bind(level))
		priority_row.add_child(priority_button)
		_priority_buttons.append(priority_button)

	var buy_row := HBoxContainer.new()
	buy_row.add_theme_constant_override(&"separation", 6)
	root.add_child(buy_row)
	for percent: int in _PERCENTS:
		var button := Button.new()
		button.text = "Выкупить %d%%" % percent if percent < 100 else "Выкупить всё"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_trade_pressed.bind(percent, true))
		buy_row.add_child(button)
		_buy_buttons.append(button)

	var sell_row := HBoxContainer.new()
	sell_row.add_theme_constant_override(&"separation", 6)
	root.add_child(sell_row)
	for percent: int in _PERCENTS:
		var button := Button.new()
		button.text = "Продать %d%%" % percent if percent < 100 else "Продать всё"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_trade_pressed.bind(percent, false))
		sell_row.add_child(button)
		_sell_buttons.append(button)


## Opens the dialog for the factory (a dictionary of PlayerSingleton.get_production_info)
func open(province_index: int, factory: Dictionary) -> void:
	_province_index = province_index
	_building_type_index = factory[&"building_type_index"]
	update_factory(factory)
	open_window()


func is_showing(province_index: int, building_type_index: int) -> bool:
	return visible and _province_index == province_index and _building_type_index == building_type_index


func get_building_type_index() -> int:
	return _building_type_index


func update_factory(factory: Dictionary) -> void:
	var state_share: float = factory[&"state_share"]
	_pie.state_share = state_share
	_pie.queue_redraw()

	set_title("%s: владельцы" % factory[&"name"])
	var value: float = factory[&"value"]
	_info.text = "\n".join([
		"Государство: %d%%" % roundi(state_share * 100.0),
		"Инвесторы: %d%%" % roundi((1.0 - state_share) * 100.0),
		"Построено: %s" % ("государством" if factory[&"built_by_state"] else "частными инвесторами"),
		"",
		"Стоимость завода: %s" % GUINode.float_to_string_dp(value, 0),
		"Средняя прибыль в день: %s" % GUINode.float_to_string_dp(factory[&"average_profit"], 1),
		"Цена 10%%: %s" % GUINode.float_to_string_dp(value / 10.0, 0),
		"",
		"Казна завода: %s" % GUINode.float_to_string_dp(factory[&"budget"], 0),
		"Фонд расширения: %s / %s" % [
			GUINode.float_to_string_dp(factory[&"expansion_fund"], 0),
			GUINode.float_to_string_dp(factory[&"expansion_cost"], 0),
		],
		"Дивиденды вчера: государство %s, инвесторы %s" % [
			GUINode.float_to_string_dp(factory[&"state_dividends"], 1),
			GUINode.float_to_string_dp(factory[&"owner_dividends"], 1),
		],
		"Накопления капиталистов штата: %s" % GUINode.float_to_string_dp(factory[&"capitalist_fund"], 0),
	])

	var priority: int = int(factory.get(&"priority", 1))
	for i: int in _priority_buttons.size():
		_priority_buttons[i].set_pressed_no_signal(i == priority)

	for button in _buy_buttons:
		button.disabled = state_share >= 0.999
	for button in _sell_buttons:
		button.disabled = state_share <= 0.001


func _on_priority_pressed(level: int) -> void:
	if _province_index >= 0 and _building_type_index >= 0:
		PlayerSingleton.set_factory_priority(_province_index, _building_type_index, level)


func _on_trade_pressed(percent: int, buy: bool) -> void:
	if _province_index < 0 or _building_type_index < 0:
		return
	if buy:
		PlayerSingleton.buy_factory_share(_province_index, _building_type_index, percent)
	else:
		PlayerSingleton.sell_factory_share(_province_index, _building_type_index, percent)
