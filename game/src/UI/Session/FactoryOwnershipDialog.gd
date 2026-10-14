extends PanelContainer
## Dialog with the owners of a factory: a pie chart of the shares of the state and of the investors (capitalists),
## the finances of the factory and buttons to buy shares from the capitalists or sell shares to them.
## Built from plain Godot controls, opened from the ownership button of a factory in ProductionMenu.

const _PERCENTS: PackedInt32Array = [10, 25, 100]

var _province_index: int = -1
var _building_type_index: int = -1

var _title: Label
var _pie: _Pie
var _info: Label
var _buy_buttons: Array[Button] = []
var _sell_buttons: Array[Button] = []


class _Pie extends Control:
	const STATE_COLOUR: Color = Color(0.25, 0.55, 0.95)
	const INVESTOR_COLOUR: Color = Color(0.95, 0.65, 0.2)

	var state_share: float = 1.0

	func _init() -> void:
		custom_minimum_size = Vector2(150, 150)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var centre: Vector2 = size / 2.0
		var radius: float = minf(size.x, size.y) / 2.0 - 4.0
		_draw_slice(centre, radius, 0.0, state_share, STATE_COLOUR)
		_draw_slice(centre, radius, state_share, 1.0, INVESTOR_COLOUR)
		draw_arc(centre, radius, 0.0, TAU, 64, Color.BLACK, 2.0)

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
	visible = false
	custom_minimum_size = Vector2(360, 0)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	var root := VBoxContainer.new()
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := Button.new()
	close.text = "X"
	close.pressed.connect(hide)
	header.add_child(close)

	var body := HBoxContainer.new()
	root.add_child(body)
	_pie = _Pie.new()
	body.add_child(_pie)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(190, 0)
	body.add_child(_info)

	var buy_row := HBoxContainer.new()
	root.add_child(buy_row)
	for percent: int in _PERCENTS:
		var button := Button.new()
		button.text = "Выкупить %d%%" % percent if percent < 100 else "Выкупить всё"
		button.pressed.connect(_on_trade_pressed.bind(percent, true))
		buy_row.add_child(button)
		_buy_buttons.append(button)

	var sell_row := HBoxContainer.new()
	root.add_child(sell_row)
	for percent: int in _PERCENTS:
		var button := Button.new()
		button.text = "Продать %d%%" % percent if percent < 100 else "Продать всё"
		button.pressed.connect(_on_trade_pressed.bind(percent, false))
		sell_row.add_child(button)
		_sell_buttons.append(button)


## Opens the dialog for the factory (a dictionary of PlayerSingleton.get_production_info)
func open(province_index: int, factory: Dictionary) -> void:
	_province_index = province_index
	_building_type_index = factory[&"building_type_index"]
	update_factory(factory)
	show()


func is_showing(province_index: int, building_type_index: int) -> bool:
	return visible and _province_index == province_index and _building_type_index == building_type_index


func get_building_type_index() -> int:
	return _building_type_index


func update_factory(factory: Dictionary) -> void:
	var state_share: float = factory[&"state_share"]
	_pie.state_share = state_share
	_pie.queue_redraw()

	_title.text = "%s: владельцы" % factory[&"name"]
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

	for button in _buy_buttons:
		button.disabled = state_share >= 0.999
	for button in _sell_buttons:
		button.disabled = state_share <= 0.001


func _on_trade_pressed(percent: int, buy: bool) -> void:
	if _province_index < 0 or _building_type_index < 0:
		return
	if buy:
		PlayerSingleton.buy_factory_share(_province_index, _building_type_index, percent)
	else:
		PlayerSingleton.sell_factory_share(_province_index, _building_type_index, percent)
