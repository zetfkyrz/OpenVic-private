extends "res://src/UI/Session/Vic2Window.gd"
## Politics of the country (task D3): government and ruling party, time to the election, parties with their votes,
## the ideologies of the people and of the upper house (pie charts), and the reforms by groups with the support of the
## people, the verdict of the simulation (why a reform cannot be passed) and a button to enact the selected reform.
## A Victoria 2 style window, opened with F9.

const _SIZE: Vector2 = Vector2(760, 680)
const _TOGGLE_KEY: Key = KEY_F9

var _info: Dictionary = {}
var _selected_reform: int = -1

var _header_label: Label
var _people_pie: _Pie
var _house_pie: _Pie
var _parties_tree: Tree
var _reforms_tree: Tree
var _reform_label: Label
var _unrest_label: Label
var _enact_button: Button


class _Pie extends Control:
	var slices: Array = []  # [{ name, share, colour }]

	func _init() -> void:
		custom_minimum_size = Vector2(130, 130)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var centre: Vector2 = size / 2.0
		var radius: float = minf(size.x, size.y) / 2.0 - 4.0
		var total: float = 0.0
		for slice: Dictionary in slices:
			total += float(slice[&"share"])
		if total <= 0.0:
			draw_arc(centre, radius, 0.0, TAU, 48, Color.BLACK, 2.0)
			return
		var start: float = -PI / 2.0
		for slice: Dictionary in slices:
			var portion: float = float(slice[&"share"]) / total
			if portion <= 0.001:
				continue
			var end: float = start + portion * TAU
			var points: PackedVector2Array = [centre]
			var steps: int = maxi(2, int(portion * 48.0))
			for i: int in steps + 1:
				var angle: float = lerpf(start, end, float(i) / float(steps))
				points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
			draw_colored_polygon(points, slice[&"colour"])
			start = end
		draw_arc(centre, radius, 0.0, TAU, 48, Color.BLACK, 2.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and not slices.is_empty():
			var offset: Vector2 = (event as InputEventMouseMotion).position - size / 2.0
			var share: float = fposmod(offset.angle() + PI / 2.0, TAU) / TAU
			var total: float = 0.0
			for slice: Dictionary in slices:
				total += float(slice[&"share"])
			var running: float = 0.0
			for slice: Dictionary in slices:
				running += float(slice[&"share"]) / maxf(total, 0.0001)
				if share <= running:
					tooltip_text = "%s: %d%%" % [slice[&"name"], roundi(float(slice[&"share"]) / maxf(total, 0.0001) * 100.0)]
					return


func _ready() -> void:
	setup(_SIZE, "Политика")

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 6)
	content.add_child(root)

	_header_label = Label.new()
	_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_header_label)

	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 10)
	root.add_child(top)

	var people_box := VBoxContainer.new()
	top.add_child(people_box)
	var people_caption := Label.new()
	people_caption.text = "Идеологии народа"
	people_box.add_child(people_caption)
	_people_pie = _Pie.new()
	people_box.add_child(_people_pie)

	var house_box := VBoxContainer.new()
	top.add_child(house_box)
	var house_caption := Label.new()
	house_caption.text = "Верхняя палата"
	house_box.add_child(house_caption)
	_house_pie = _Pie.new()
	house_box.add_child(_house_pie)

	_parties_tree = Tree.new()
	_parties_tree.columns = 3
	_parties_tree.column_titles_visible = true
	_parties_tree.hide_root = true
	_parties_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_parties_tree.custom_minimum_size = Vector2(0, 130)
	_parties_tree.set_column_title(0, "Партия")
	_parties_tree.set_column_title(1, "Идеология")
	_parties_tree.set_column_title(2, "Голоса")
	_parties_tree.set_column_expand(0, true)
	top.add_child(_parties_tree)

	_unrest_label = Label.new()
	_unrest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_unrest_label)

	var reforms_caption := Label.new()
	reforms_caption.text = "Реформы (поддержка внутри группы; выберите вариант и нажмите кнопку):"
	root.add_child(reforms_caption)

	_reforms_tree = Tree.new()
	_reforms_tree.columns = 3
	_reforms_tree.column_titles_visible = true
	_reforms_tree.hide_root = true
	_reforms_tree.select_mode = Tree.SELECT_ROW
	_reforms_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reforms_tree.set_column_title(0, "Реформа")
	_reforms_tree.set_column_title(1, "Поддержка")
	_reforms_tree.set_column_title(2, "Состояние")
	_reforms_tree.set_column_expand(0, true)
	_reforms_tree.set_column_custom_minimum_width(1, 80)
	_reforms_tree.set_column_custom_minimum_width(2, 260)
	_reforms_tree.item_selected.connect(_on_reform_selected)
	_reforms_tree.nothing_selected.connect(_on_reform_deselected)
	root.add_child(_reforms_tree)

	_reform_label = Label.new()
	_reform_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_reform_label)

	_enact_button = Button.new()
	_enact_button.text = "Принять реформу"
	_enact_button.pressed.connect(_on_enact_pressed)
	root.add_child(_enact_button)

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
	_info = PlayerSingleton.get_politics_info()
	if _info.is_empty():
		return

	var election: String = "выборов нет"
	if _info[&"holds_elections"]:
		election = "до выборов %d дн." % _info[&"days_to_election"] if _info[&"days_to_election"] >= 0 else "выборы скоро"
	_header_label.text = "%s. У власти: %s (%s), %s. Голосуют: %d%% населения." % [
		_info[&"government"], _info[&"ruling_party"], _info[&"ruling_ideology"], election,
		roundi(float(_info[&"voters_share"]) * 100.0),
	]

	_people_pie.slices = _info[&"ideologies"]
	_people_pie.queue_redraw()
	_house_pie.slices = _info[&"upper_house"]
	_house_pie.queue_redraw()

	_parties_tree.clear()
	var parties_root: TreeItem = _parties_tree.create_item()
	for party: Dictionary in _info[&"parties"]:
		var item: TreeItem = _parties_tree.create_item(parties_root)
		item.set_text(0, party[&"name"] + (" *" if party[&"ruling"] else ""))
		item.set_text(1, party[&"ideology"])
		item.set_text(2, "%d%%" % roundi(float(party[&"vote_share"]) * 100.0))

	var unrest: PackedStringArray = ["Средняя воинственность: %.1f из 10." % _info[&"average_militancy"]]
	var restless: PackedStringArray = []
	for entry: Dictionary in _info[&"restless"]:
		restless.append("%s (%.1f)" % [entry[&"name"], entry[&"militancy"]])
	if not restless.is_empty():
		unrest.append("Самые неспокойные провинции: " + ", ".join(restless) + ".")
	var risings: PackedStringArray = []
	for entry: Dictionary in _info[&"uprisings"]:
		risings.append("%s (полков %d, сила %d%%)" % [entry[&"name"], entry[&"regiments"], roundi(float(entry[&"strength"]) * 100.0)])
	unrest.append("Восстания: " + (", ".join(risings) if not risings.is_empty() else "нет") + ".")
	_unrest_label.text = " ".join(unrest)

	_update_reforms()


func _update_reforms() -> void:
	_reforms_tree.clear()
	var root: TreeItem = _reforms_tree.create_item()
	var to_select: TreeItem = null
	for group: Dictionary in _info[&"groups"]:
		if group[&"civilizing"]:
			continue
		var group_item: TreeItem = _reforms_tree.create_item(root)
		group_item.set_text(0, "%s (%s)" % [group[&"name"], group[&"type"]])
		group_item.set_selectable(0, false)
		group_item.set_selectable(1, false)
		group_item.set_selectable(2, false)
		group_item.set_custom_color(0, HEADER_COLOUR)
		for option: Dictionary in group[&"options"]:
			var item: TreeItem = _reforms_tree.create_item(group_item)
			item.set_text(0, ("> " if option[&"current"] else "   ") + option[&"name"])
			item.set_text(1, "%d%%" % roundi(float(option[&"support"]) * 100.0))
			var state: String = ""
			if option[&"current"]:
				state = "действует"
			elif option[&"can_enact"]:
				state = "можно принять"
			else:
				state = option[&"reason"]
			item.set_text(2, state)
			item.set_metadata(0, option[&"index"])
			if option[&"can_enact"]:
				item.set_custom_color(2, Color(0.1, 0.45, 0.15))
			if option[&"index"] == _selected_reform:
				to_select = item
	if to_select != null:
		to_select.select(0)
	_update_enact_button()


func _find_option(reform_index: int) -> Dictionary:
	for group: Dictionary in _info.get(&"groups", []):
		for option: Dictionary in group[&"options"]:
			if option[&"index"] == reform_index:
				return option
	return {}


func _update_enact_button() -> void:
	var option: Dictionary = _find_option(_selected_reform)
	if option.is_empty():
		_reform_label.text = "Выберите вариант реформы."
		_enact_button.disabled = true
		return
	if option[&"can_enact"]:
		_reform_label.text = "%s: поддержка %d%%, верхняя палата за: %d%%." % [
			option[&"name"], roundi(float(option[&"support"]) * 100.0), roundi(float(option[&"upper_house"]) * 100.0),
		]
	else:
		_reform_label.text = "%s: %s" % [option[&"name"], "уже действует" if option[&"current"] else option[&"reason"]]
	_enact_button.disabled = not option[&"can_enact"]


func _on_reform_selected() -> void:
	var item: TreeItem = _reforms_tree.get_selected()
	_selected_reform = item.get_metadata(0) if item != null and item.get_metadata(0) != null else -1
	_update_enact_button()


func _on_reform_deselected() -> void:
	_reforms_tree.deselect_all()
	_selected_reform = -1
	_update_enact_button()


func _on_enact_pressed() -> void:
	if _selected_reform >= 0:
		PlayerSingleton.enact_reform(_selected_reform)
