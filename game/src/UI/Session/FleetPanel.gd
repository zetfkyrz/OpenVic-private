extends "res://src/UI/Session/Vic2Window.gd"
## Panel of the selected fleet (tasks A8-A10): ships with their state, the admiral, movement, the armies on board with
## loading in a port and landing from the sea, blockade, and the way to the shipyard. Built like the panel of the army
## (ArmyPanel.gd): a Victoria 2 style window that appears when fleets are selected on the map.

const _SIZE: Vector2 = Vector2(600, 600)

var _fleet_ids: Array[int] = []
var _index: int = 0
var _details: Dictionary = {}
var _selected_carried_id: int = 0

var _prev_button: Button
var _next_button: Button
var _nav_label: Label
var _info_label: Label
var _leader_label: Label
var _admiral_option: OptionButton
var _assign_button: Button
var _remove_leader_button: Button
var _ships_tree: Tree
var _load_option: OptionButton
var _load_button: Button
var _carried_tree: Tree
var _unload_button: Button
var _landing_option: OptionButton
var _landing_button: Button
var _stop_button: Button
var _shipyard_button: Button

var _admiral_signature: String = ""
var _load_signature: String = ""
var _landing_signature: String = ""

var _recruitment_window: Control


func _ready() -> void:
	setup(_SIZE, "")
	# Bottom left corner of the screen, above the panel of the army
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 110.0
	offset_right = 110.0 + _SIZE.x
	offset_top = -_SIZE.y - 90.0
	offset_bottom = -90.0
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 6)
	content.add_child(root)

	var nav := HBoxContainer.new()
	root.add_child(nav)
	_prev_button = Button.new()
	_prev_button.text = "<"
	_prev_button.pressed.connect(_on_nav_pressed.bind(-1))
	nav.add_child(_prev_button)
	_nav_label = Label.new()
	_nav_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nav_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(_nav_label)
	_next_button = Button.new()
	_next_button.text = ">"
	_next_button.pressed.connect(_on_nav_pressed.bind(1))
	nav.add_child(_next_button)

	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_info_label)

	var leader_row := HBoxContainer.new()
	leader_row.add_theme_constant_override(&"separation", 6)
	root.add_child(leader_row)
	_leader_label = Label.new()
	_leader_label.custom_minimum_size = Vector2(190, 0)
	_leader_label.clip_text = true
	leader_row.add_child(_leader_label)
	_admiral_option = OptionButton.new()
	_admiral_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_admiral_option.clip_text = true
	leader_row.add_child(_admiral_option)
	_assign_button = Button.new()
	_assign_button.text = "Назначить"
	_assign_button.pressed.connect(_on_assign_pressed)
	leader_row.add_child(_assign_button)
	_remove_leader_button = Button.new()
	_remove_leader_button.text = "Снять"
	_remove_leader_button.pressed.connect(_on_remove_leader_pressed)
	leader_row.add_child(_remove_leader_button)

	_ships_tree = Tree.new()
	_ships_tree.columns = 5
	_ships_tree.column_titles_visible = true
	_ships_tree.hide_root = true
	_ships_tree.select_mode = Tree.SELECT_ROW
	_ships_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ships_tree.custom_minimum_size = Vector2(0, 140)
	var titles: PackedStringArray = ["Корабль", "Тип", "Состав", "Организация", "Корпус / орудия"]
	for column: int in titles.size():
		_ships_tree.set_column_title(column, titles[column])
	_ships_tree.set_column_custom_minimum_width(0, 120)
	_ships_tree.set_column_custom_minimum_width(1, 100)
	_ships_tree.set_column_custom_minimum_width(2, 60)
	_ships_tree.set_column_custom_minimum_width(3, 80)
	_ships_tree.set_column_custom_minimum_width(4, 100)
	root.add_child(_ships_tree)

	# Loading in a port
	var load_row := HBoxContainer.new()
	load_row.add_theme_constant_override(&"separation", 6)
	root.add_child(load_row)
	var load_caption := Label.new()
	load_caption.text = "Погрузить армию из порта:"
	load_row.add_child(load_caption)
	_load_option = OptionButton.new()
	_load_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load_option.clip_text = true
	load_row.add_child(_load_option)
	_load_button = Button.new()
	_load_button.text = "Погрузить"
	_load_button.pressed.connect(_on_load_pressed)
	load_row.add_child(_load_button)

	# Armies on board
	var carried_caption := Label.new()
	carried_caption.text = "Армии на борту (выберите армию, чтобы выгрузить или высадить её):"
	root.add_child(carried_caption)
	_carried_tree = Tree.new()
	_carried_tree.columns = 2
	_carried_tree.column_titles_visible = true
	_carried_tree.hide_root = true
	_carried_tree.select_mode = Tree.SELECT_ROW
	_carried_tree.custom_minimum_size = Vector2(0, 70)
	_carried_tree.set_column_title(0, "Армия")
	_carried_tree.set_column_title(1, "Полков")
	_carried_tree.item_selected.connect(_on_carried_selected)
	_carried_tree.nothing_selected.connect(_on_carried_deselected)
	root.add_child(_carried_tree)

	var unload_row := HBoxContainer.new()
	unload_row.add_theme_constant_override(&"separation", 6)
	root.add_child(unload_row)
	_unload_button = Button.new()
	_unload_button.text = "Выгрузить в порту"
	_unload_button.pressed.connect(_on_unload_pressed)
	unload_row.add_child(_unload_button)
	_landing_option = OptionButton.new()
	_landing_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_landing_option.clip_text = true
	unload_row.add_child(_landing_option)
	_landing_button = Button.new()
	_landing_button.text = "Высадить"
	_landing_button.tooltip_text = "Армия высаживается в береговой провинции рядом с морем, теряя половину организации"
	_landing_button.pressed.connect(_on_landing_pressed)
	unload_row.add_child(_landing_button)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override(&"separation", 6)
	root.add_child(bottom_row)
	_stop_button = Button.new()
	_stop_button.text = "Остановить"
	_stop_button.pressed.connect(_on_stop_pressed)
	bottom_row.add_child(_stop_button)
	_shipyard_button = Button.new()
	_shipyard_button.text = "Построить корабли в порту"
	_shipyard_button.pressed.connect(_on_shipyard_pressed)
	bottom_row.add_child(_shipyard_button)

	GameSingleton.gamestate_updated.connect(_refresh)


func set_recruitment_window(window: Control) -> void:
	_recruitment_window = window


## Shows the selected fleets of the player, an empty list hides the panel
func show_fleets(fleet_ids: Array[int]) -> void:
	if fleet_ids.is_empty():
		_fleet_ids = []
		close()
		return

	var current_id: int = _fleet_ids[_index] if _index < _fleet_ids.size() else 0
	_fleet_ids = fleet_ids.duplicate()
	_index = maxi(0, _fleet_ids.find(current_id))
	_selected_carried_id = 0
	_refresh()
	open_window()


func _refresh() -> void:
	if not visible or _fleet_ids.is_empty():
		return

	_index = clampi(_index, 0, _fleet_ids.size() - 1)
	_details = PlayerSingleton.get_army_details(_fleet_ids[_index])
	if _details.is_empty() or not _details.get(&"is_navy", false):
		# The fleet is gone (sunk or merged)
		_fleet_ids.remove_at(_index)
		if _fleet_ids.is_empty():
			close()
		else:
			_refresh()
		return

	set_title(_details[&"name"])
	_prev_button.visible = _fleet_ids.size() > 1
	_next_button.visible = _fleet_ids.size() > 1
	_nav_label.text = "Флот" if _fleet_ids.size() <= 1 else "Флот %d из %d" % [_index + 1, _fleet_ids.size()]

	_info_label.text = _make_info_text()
	_update_leader()
	_update_ships()
	_update_load_list()
	_update_carried()
	_update_landing_list()

	var docked: bool = _details[&"docked"]
	_stop_button.disabled = not _details[&"moving"]
	_shipyard_button.disabled = not docked


func _make_info_text() -> String:
	var lines: PackedStringArray = []
	var strength: float = _details[&"strength"]
	var max_strength: float = _details[&"max_strength"]
	var strength_share: float = strength / max_strength if max_strength > 0.0 else 0.0
	var place: String = "в порту провинции %s" % _details[&"province_name"] if _details[&"docked"] \
		else "в море (%s)" % _details[&"province_name"]
	lines.append("Кораблей: %d, %s. Состав: %d%%. Организация: %d%%." % [
		_details[&"regiments"], place, roundi(strength_share * 100.0), roundi(float(_details[&"organisation"]) * 100.0),
	])
	lines.append("Вместимость транспортов: %d полков, на борту: %d." % [_details[&"capacity"], _details[&"carried_regiments"]])

	if _details[&"in_combat"]:
		lines.append("Флот сражается.")
	elif _details[&"moving"]:
		lines.append("В плавании к %s, прибытие через %d дн." % [_details[&"destination_name"], _details[&"eta_days"]])
	else:
		lines.append("Стоит на месте.")
	if _details[&"blockading"]:
		lines.append("Блокирует вражеский порт: торговля и снабжение врага страдают.")
	return "\n".join(lines)


func _update_leader() -> void:
	var leader_id: int = _details[&"leader_id"]
	if leader_id != 0:
		var leader: Dictionary = _details[&"leader"]
		_leader_label.text = "Адмирал: %s" % leader.get(&"leader_name", "?")
	else:
		_leader_label.text = "Адмирал не назначен"

	var admirals: Array = PlayerSingleton.get_admirals()
	var signature: String = ""
	for admiral: Dictionary in admirals:
		signature += "%d:%d;" % [admiral[&"leader_id"], admiral[&"army_id"]]
	if signature != _admiral_signature:
		_admiral_signature = signature
		_admiral_option.clear()
		for admiral: Dictionary in admirals:
			var text: String = "%s (престиж %.1f)" % [admiral.get(&"leader_name", "?"), admiral[&"prestige"]]
			if admiral[&"army_id"] != 0:
				text += " - " + str(admiral[&"army_name"])
			_admiral_option.add_item(text)
			_admiral_option.set_item_metadata(_admiral_option.item_count - 1, admiral[&"leader_id"])

	_admiral_option.disabled = _admiral_option.item_count == 0
	_assign_button.disabled = _admiral_option.item_count == 0
	_remove_leader_button.disabled = leader_id == 0


func _update_ships() -> void:
	_ships_tree.clear()
	var root: TreeItem = _ships_tree.create_item()
	for ship: Dictionary in _details[&"units"]:
		var item: TreeItem = _ships_tree.create_item(root)
		item.set_text(0, ship[&"name"])
		item.set_text(1, ship[&"type_name"] + (" (транспорт)" if ship[&"is_transport"] else ""))
		var max_strength: float = ship[&"max_strength"]
		var strength_share: float = float(ship[&"strength"]) / max_strength if max_strength > 0.0 else 0.0
		item.set_text(2, "%d%%" % roundi(strength_share * 100.0))
		var max_organisation: float = ship[&"max_organisation"]
		var organisation_share: float = float(ship[&"organisation"]) / max_organisation if max_organisation > 0.0 else 0.0
		item.set_text(3, "%d%%" % roundi(organisation_share * 100.0))
		item.set_text(4, "%.0f / %.0f" % [ship[&"hull"], ship[&"gun_power"]])


func _update_load_list() -> void:
	var armies: Array = _details[&"loadable"]
	var signature: String = ""
	for army: Dictionary in armies:
		signature += "%d:%d;" % [army[&"id"], army[&"regiments"]]
	if signature != _load_signature:
		_load_signature = signature
		_load_option.clear()
		for army: Dictionary in armies:
			_load_option.add_item("%s (%d полков)" % [army[&"name"], army[&"regiments"]])
			_load_option.set_item_metadata(_load_option.item_count - 1, army[&"id"])
	var free_capacity: int = int(_details[&"capacity"]) - int(_details[&"carried_regiments"])
	_load_option.disabled = _load_option.item_count == 0
	_load_button.disabled = _load_option.item_count == 0 or free_capacity <= 0 or _details[&"in_combat"]


func _update_carried() -> void:
	_carried_tree.clear()
	var root: TreeItem = _carried_tree.create_item()
	var to_select: TreeItem = null
	for army: Dictionary in _details[&"carried"]:
		var item: TreeItem = _carried_tree.create_item(root)
		item.set_text(0, army[&"name"])
		item.set_text(1, str(army[&"regiments"]))
		item.set_metadata(0, army[&"id"])
		if army[&"id"] == _selected_carried_id:
			to_select = item
	if to_select != null:
		to_select.select(0)
	else:
		_selected_carried_id = 0
	_update_carried_buttons()


func _update_landing_list() -> void:
	var targets: Array = _details[&"landing_targets"]
	var signature: String = ""
	for target: Dictionary in targets:
		signature += "%d;" % target[&"number"]
	if signature != _landing_signature:
		_landing_signature = signature
		_landing_option.clear()
		for target: Dictionary in targets:
			var text: String = target[&"name"] + (" (вражеская)" if target[&"hostile"] else "")
			_landing_option.add_item(text)
			_landing_option.set_item_metadata(_landing_option.item_count - 1, target[&"number"])
	_landing_option.disabled = _landing_option.item_count == 0
	_update_carried_buttons()


func _update_carried_buttons() -> void:
	if _details.is_empty():
		return
	var has_selection: bool = _selected_carried_id != 0
	_unload_button.disabled = not has_selection or not _details[&"docked"]
	_landing_button.disabled = not has_selection or _landing_option.item_count == 0 or _details[&"docked"] \
		or _details[&"in_combat"]


func _on_nav_pressed(step: int) -> void:
	if _fleet_ids.is_empty():
		return
	_index = posmod(_index + step, _fleet_ids.size())
	_selected_carried_id = 0
	_refresh()


func _on_carried_selected() -> void:
	var item: TreeItem = _carried_tree.get_selected()
	_selected_carried_id = item.get_metadata(0) if item != null else 0
	_update_carried_buttons()


func _on_carried_deselected() -> void:
	_carried_tree.deselect_all()
	_selected_carried_id = 0
	_update_carried_buttons()


func _on_assign_pressed() -> void:
	if _admiral_option.item_count == 0 or _admiral_option.selected < 0:
		return
	PlayerSingleton.set_army_leader(_fleet_ids[_index], _admiral_option.get_item_metadata(_admiral_option.selected))


func _on_remove_leader_pressed() -> void:
	PlayerSingleton.set_army_leader(_fleet_ids[_index], 0)


func _on_load_pressed() -> void:
	if _load_option.item_count == 0 or _load_option.selected < 0:
		return
	PlayerSingleton.load_army(_load_option.get_item_metadata(_load_option.selected), _fleet_ids[_index])


func _on_unload_pressed() -> void:
	if _selected_carried_id != 0:
		PlayerSingleton.unload_army(_selected_carried_id)
		_selected_carried_id = 0


func _on_landing_pressed() -> void:
	if _selected_carried_id == 0 or _landing_option.item_count == 0 or _landing_option.selected < 0:
		return
	PlayerSingleton.land_army(_selected_carried_id, _landing_option.get_item_metadata(_landing_option.selected))
	_selected_carried_id = 0


func _on_stop_pressed() -> void:
	PlayerSingleton.stop_army(_fleet_ids[_index])


func _on_shipyard_pressed() -> void:
	if _recruitment_window != null:
		_recruitment_window.open_for_province(_details[&"province_number"], true)
