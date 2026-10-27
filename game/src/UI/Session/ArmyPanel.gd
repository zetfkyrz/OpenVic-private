extends "res://src/UI/Session/Vic2Window.gd"
## Panel of the selected army (task A1): the regiments with their strength and organisation, the general, supply, dig
## in, movement and ETA, and the commands: split a regiment off, merge armies, assign or remove the general, stop,
## disband a regiment or the whole army. When several armies are selected a summary is shown and the arrows switch
## between the armies. A Victoria 2 style window, it appears when armies are selected on the map (see UnitBanners).

const _SIZE: Vector2 = Vector2(840, 620)
const _SELECTED_COLOUR: Color = Color(0.6, 0.18, 0.2, 0.45)

var _army_ids: Array[int] = []
var _index: int = 0
var _details: Dictionary = {}
var _selected_regiment_id: int = 0
var _selected_division_id: int = 0
var _disband_armed: bool = false

var _prev_button: Button
var _next_button: Button
var _nav_label: Label
var _info_label: Label
var _priority_option: OptionButton
var _global_priority_option: OptionButton
var _leader_label: Label
var _general_option: OptionButton
var _assign_button: Button
var _remove_leader_button: Button
var _tree: Tree
var _split_button: Button
var _disband_regiment_button: Button
var _merge_option: OptionButton
var _merge_button: Button
var _stop_button: Button
var _recruit_button: Button
var _disband_army_button: Button
var _template_option: OptionButton
var _reform_button: Button
var _templates_button: Button
var _division_row: HBoxContainer
var _templates_signature: String = ""
var _templates_window: Control

# Signatures of the lists in the drop-downs, they are rebuilt only when the content changes so that an opened list
# does not close every day
var _general_signature: String = ""
var _merge_signature: String = ""

var _recruitment_window: Control


func _ready() -> void:
	setup(_SIZE, "")
	# Bottom left corner of the screen instead of the centre
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 90.0
	offset_right = 90.0 + _SIZE.x
	offset_top = -_SIZE.y - 80.0
	offset_bottom = -80.0
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
	_info_label.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_info_label)

	# The priority of the supply of the army (an own one or the one of all the armies) - what the country sends to the army
	var priority_row := HBoxContainer.new()
	priority_row.add_theme_constant_override(&"separation", 6)
	root.add_child(priority_row)
	var priority_caption := Label.new()
	priority_caption.text = "Приоритет снабжения:"
	priority_caption.tooltip_text = "Стандартный: отправляется ровно то, что нужно армии.\nПовышенный: отправляется больше, чтобы покрыть потери (до 2.5 потребности).\nМаксимальный: до 5 потребностей. Сверх нормы тратятся товары из запаса."
	priority_row.add_child(priority_caption)
	_priority_option = OptionButton.new()
	_priority_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for text: String in ["Как у всех армий", "Стандартный", "Повышенный", "Максимальный"]:
		_priority_option.add_item(text)
	_priority_option.item_selected.connect(_on_priority_selected)
	priority_row.add_child(_priority_option)
	var global_caption := Label.new()
	global_caption.text = "Для всех армий:"
	global_caption.tooltip_text = "Приоритет армий, у которых нет своего. Свой приоритет армии этим не меняется."
	priority_row.add_child(global_caption)
	_global_priority_option = OptionButton.new()
	for text: String in ["Стандартный", "Повышенный", "Максимальный"]:
		_global_priority_option.add_item(text)
	_global_priority_option.item_selected.connect(_on_global_priority_selected)
	priority_row.add_child(_global_priority_option)

	var leader_row := HBoxContainer.new()
	leader_row.add_theme_constant_override(&"separation", 6)
	root.add_child(leader_row)
	_leader_label = Label.new()
	_leader_label.custom_minimum_size = Vector2(150, 0)
	_leader_label.clip_text = true
	leader_row.add_child(_leader_label)
	_general_option = OptionButton.new()
	_general_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_general_option.clip_text = true
	leader_row.add_child(_general_option)
	_assign_button = Button.new()
	_assign_button.text = "Назначить"
	_assign_button.pressed.connect(_on_assign_pressed)
	leader_row.add_child(_assign_button)
	_remove_leader_button = Button.new()
	_remove_leader_button.text = "Снять"
	_remove_leader_button.pressed.connect(_on_remove_leader_pressed)
	leader_row.add_child(_remove_leader_button)

	# Divisions (the countries with the technology of the organisation of the army): reforming the regiments by a template
	_division_row = HBoxContainer.new()
	_division_row.add_theme_constant_override(&"separation", 6)
	root.add_child(_division_row)
	var template_caption := Label.new()
	template_caption.text = "Шаблон:"
	_division_row.add_child(template_caption)
	_template_option = OptionButton.new()
	_template_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_template_option.clip_text = true
	_division_row.add_child(_template_option)
	_reform_button = Button.new()
	_reform_button.text = "Переформировать по шаблону"
	_reform_button.tooltip_text = "Полки выбранной дивизии вне шаблона (или всех дивизий вне шаблона, если ничего не выбрано) складываются в целые дивизии выбранного шаблона; остаток остаётся как был"
	_reform_button.pressed.connect(_on_reform_pressed)
	_division_row.add_child(_reform_button)
	_templates_button = Button.new()
	_templates_button.text = "Шаблоны…"
	_templates_button.pressed.connect(_on_templates_pressed)
	_division_row.add_child(_templates_button)

	_tree = Tree.new()
	_tree.columns = 5
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.custom_minimum_size = Vector2(0, 170)
	var titles: PackedStringArray = ["Полк", "Тип", "Состав", "Организация", "Набран из"]
	for column: int in titles.size():
		_tree.set_column_title(column, titles[column])
	_tree.set_column_expand(0, true)
	_tree.set_column_custom_minimum_width(0, 150)
	_tree.set_column_custom_minimum_width(1, 90)
	_tree.set_column_custom_minimum_width(2, 70)
	_tree.set_column_custom_minimum_width(3, 80)
	_tree.set_column_custom_minimum_width(4, 100)
	_tree.item_selected.connect(_on_regiment_selected)
	_tree.nothing_selected.connect(_on_regiment_deselected)
	root.add_child(_tree)

	var regiment_row := HBoxContainer.new()
	regiment_row.add_theme_constant_override(&"separation", 6)
	root.add_child(regiment_row)
	_split_button = Button.new()
	_split_button.text = "Выделить полк в отдельную армию"
	_split_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split_button.pressed.connect(_on_split_pressed)
	regiment_row.add_child(_split_button)
	_disband_regiment_button = Button.new()
	_disband_regiment_button.text = "Распустить полк"
	_disband_regiment_button.pressed.connect(_on_disband_regiment_pressed)
	regiment_row.add_child(_disband_regiment_button)

	var merge_row := HBoxContainer.new()
	merge_row.add_theme_constant_override(&"separation", 6)
	root.add_child(merge_row)
	var merge_caption := Label.new()
	merge_caption.text = "Объединить с армией:"
	merge_caption.tooltip_text = "Объединить с армией, которая стоит в этой же провинции"
	merge_row.add_child(merge_caption)
	_merge_option = OptionButton.new()
	_merge_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_merge_option.clip_text = true
	merge_row.add_child(_merge_option)
	_merge_button = Button.new()
	_merge_button.text = "Объединить"
	_merge_button.pressed.connect(_on_merge_pressed)
	merge_row.add_child(_merge_button)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override(&"separation", 6)
	root.add_child(bottom_row)
	_stop_button = Button.new()
	_stop_button.text = "Остановить"
	_stop_button.pressed.connect(_on_stop_pressed)
	bottom_row.add_child(_stop_button)
	_recruit_button = Button.new()
	_recruit_button.text = "Набор полков"
	_recruit_button.pressed.connect(_on_recruit_pressed)
	bottom_row.add_child(_recruit_button)
	_disband_army_button = Button.new()
	_disband_army_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_disband_army_button.pressed.connect(_on_disband_army_pressed)
	bottom_row.add_child(_disband_army_button)

	GameSingleton.gamestate_updated.connect(_refresh)


## The window of the recruitment of regiments opened by the button of the panel
func set_recruitment_window(window: Control) -> void:
	_recruitment_window = window


func set_templates_window(window: Control) -> void:
	_templates_window = window


## Shows the selected armies of the player, an empty list hides the panel
func show_armies(army_ids: Array[int]) -> void:
	if army_ids.is_empty():
		_army_ids = []
		close()
		return

	# Stay on the same army when the selection is only extended
	var current_id: int = _army_ids[_index] if _index < _army_ids.size() else 0
	_army_ids = army_ids.duplicate()
	_index = maxi(0, _army_ids.find(current_id))
	_disband_armed = false
	_selected_regiment_id = 0
	_refresh()
	open_window()


func _refresh() -> void:
	if not visible or _army_ids.is_empty():
		return

	_index = clampi(_index, 0, _army_ids.size() - 1)
	_details = PlayerSingleton.get_army_details(_army_ids[_index])
	if _details.is_empty():
		# The army is gone (merged, disbanded or destroyed in a battle)
		_army_ids.remove_at(_index)
		if _army_ids.is_empty():
			close()
		else:
			_refresh()
		return

	set_title(_details[&"name"])
	_prev_button.visible = _army_ids.size() > 1
	_next_button.visible = _army_ids.size() > 1
	_nav_label.text = _make_nav_text()

	_info_label.text = _make_info_text()
	_update_divisions_row()
	_info_label.tooltip_text = _details.get(&"supply_tooltip", "").replace("§Y", "").replace("§G", "").replace("§R", "").replace("§W", "").replace("§!", "")
	_update_priority()
	_update_leader()
	_update_units()
	_update_merge_list()

	var can_split: bool = _selected_regiment_id != 0 and _details[&"units"].size() > 1 and not _details[&"in_combat"]
	_split_button.disabled = not can_split
	_disband_regiment_button.disabled = _selected_regiment_id == 0 or _details[&"in_combat"]
	_stop_button.disabled = not _details[&"moving"]
	_disband_army_button.disabled = _details[&"in_combat"]
	_disband_army_button.text = "Подтвердить роспуск армии" if _disband_armed else "Распустить армию"


func _update_priority() -> void:
	var is_player: bool = _details[&"is_player"]
	_priority_option.disabled = not is_player
	_global_priority_option.disabled = not is_player
	_priority_option.select(_details[&"supply_priority_own"])
	_global_priority_option.select(_details[&"supply_global_priority"])


func _on_priority_selected(index: int) -> void:
	# 0 in the list is "as all the armies" (the own priority is taken off), 1..3 the own priorities 0..2
	var value: int = 3 if index == 0 else index - 1
	for army_id: int in _army_ids:
		PlayerSingleton.set_army_supply_priority(army_id, value)


func _on_global_priority_selected(index: int) -> void:
	PlayerSingleton.set_global_supply_priority(index)


func _make_nav_text() -> String:
	if _army_ids.size() <= 1:
		return "Армия"
	var regiments: int = 0
	for army_id: int in _army_ids:
		var other: Dictionary = PlayerSingleton.get_army_details(army_id)
		regiments += other.get(&"regiments", 0)
	return "Армия %d из %d. Выбрано: %d армий, %d полков" % [_index + 1, _army_ids.size(), _army_ids.size(), regiments]


func _make_info_text() -> String:
	var lines: PackedStringArray = []
	var strength: float = _details[&"strength"]
	var max_strength: float = _details[&"max_strength"]
	var strength_share: float = strength / max_strength if max_strength > 0.0 else 0.0
	lines.append("Провинция: %s. Полков: %d. Состав: %d%%. Организация: %d%%." % [
		_details[&"province_name"], _details[&"regiments"],
		roundi(strength_share * 100.0), roundi(float(_details[&"organisation"]) * 100.0),
	])

	var supply: float = _details[&"supply"]
	lines.append("Снабжение: %d%% (пришло %d%%, запас %.1f из %d дн.). Окопанность: %d из %d." % [
		roundi(supply * 100.0), roundi(float(_details[&"supply_ratio"]) * 100.0), _details[&"supply_reserve"],
		roundi(float(_details[&"supply_reserve_capacity"])), _details[&"dig_in"], _details[&"dig_in_cap"],
	])

	if _details[&"in_combat"]:
		lines.append("Армия сражается.")
	elif _details[&"moving"]:
		lines.append("Движется в провинцию %s, прибытие через %d дн." % [
			_details[&"destination_name"], _details[&"eta_days"],
		])
	else:
		lines.append("Стоит на месте.")

	if _details[&"front_id"] != 0:
		lines.append("Назначена на фронт №%d (приказ вручную снимает армию с фронта)." % _details[&"front_id"])
	return "\n".join(lines)


func _update_leader() -> void:
	var leader_id: int = _details[&"leader_id"]
	if leader_id != 0:
		var leader: Dictionary = _details[&"leader"]
		_leader_label.text = "Генерал: %s" % leader.get(&"leader_name", "?")
		_leader_label.tooltip_text = ""
	else:
		_leader_label.text = "Генерал не назначен"
		_leader_label.tooltip_text = ""

	var generals: Array = PlayerSingleton.get_generals()
	var signature: String = ""
	for general: Dictionary in generals:
		signature += "%d:%d;" % [general[&"leader_id"], general[&"army_id"]]
	if signature != _general_signature:
		_general_signature = signature
		_general_option.clear()
		for general: Dictionary in generals:
			var text: String = "%s (престиж %.1f)" % [general.get(&"leader_name", "?"), general[&"prestige"]]
			if general[&"army_id"] != 0:
				text += " - " + str(general[&"army_name"])
			_general_option.add_item(text)
			_general_option.set_item_metadata(_general_option.item_count - 1, general[&"leader_id"])
			if not general.get(&"leader_can_be_used", true):
				_general_option.set_item_disabled(_general_option.item_count - 1, true)

	var organised: bool = _details.get(&"has_organisation", false)
	if not organised:
		_leader_label.text = "Нет генерала"
		_leader_label.tooltip_text = "Генералы командуют армиями только у стран с технологией «Организация армии» (цивилизованных)"
	_general_option.disabled = _general_option.item_count == 0 or not organised
	_assign_button.disabled = _general_option.item_count == 0 or not _details[&"is_player"] or not organised
	_remove_leader_button.disabled = leader_id == 0 or not _details[&"is_player"]


func _update_divisions_row() -> void:
	var organised: bool = _details.get(&"has_organisation", false)
	_division_row.visible = organised
	if not organised:
		return
	var templates: Array = PlayerSingleton.get_division_templates()
	var signature: String = str(templates)
	if signature != _templates_signature:
		_templates_signature = signature
		_template_option.clear()
		for entry: Dictionary in templates:
			_template_option.add_item(entry[&"text"])
			_template_option.set_item_metadata(_template_option.item_count - 1, entry[&"id"])
	_template_option.disabled = _template_option.item_count == 0
	_reform_button.disabled = _template_option.item_count == 0 or not _details[&"is_player"] or _details[&"in_combat"]


func _on_reform_pressed() -> void:
	if _template_option.item_count == 0 or _template_option.selected < 0:
		return
	var template_id: int = _template_option.get_item_metadata(_template_option.selected)
	PlayerSingleton.reform_army_to_template(_army_ids[_index], _selected_division_id, template_id)


func _on_templates_pressed() -> void:
	if _templates_window != null:
		_templates_window.open_templates()


func _add_unit_item(parent: TreeItem, unit: Dictionary) -> TreeItem:
	var item: TreeItem = _tree.create_item(parent)
	item.set_text(0, unit[&"name"])
	item.set_text(1, unit[&"type_name"])
	var max_strength: float = unit[&"max_strength"]
	var strength_share: float = float(unit[&"strength"]) / max_strength if max_strength > 0.0 else 0.0
	item.set_text(2, "%d%%" % roundi(strength_share * 100.0))
	var max_organisation: float = unit[&"max_organisation"]
	var organisation_share: float = float(unit[&"organisation"]) / max_organisation if max_organisation > 0.0 else 0.0
	item.set_text(3, "%d%%" % roundi(organisation_share * 100.0))
	item.set_text(4, "%s (%s)" % [unit[&"pop_type"], unit[&"pop_culture"]] if unit[&"pop_type"] != "" else "-")
	item.set_metadata(0, unit[&"id"])
	item.set_metadata(1, 0)
	return item


func _update_units() -> void:
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var to_select: TreeItem = null
	if _details.get(&"has_organisation", false) and not _details.get(&"divisions", []).is_empty():
		# The divisions with their regiments
		var by_id: Dictionary = {}
		for unit: Dictionary in _details[&"units"]:
			by_id[unit[&"id"]] = unit
		for division: Dictionary in _details[&"divisions"]:
			var division_item: TreeItem = _tree.create_item(root)
			division_item.set_text(0, division[&"name"])
			division_item.set_text(1, "%d полков" % division[&"regiments"])
			division_item.set_metadata(0, 0)
			division_item.set_metadata(1, division[&"id"])
			division_item.set_custom_color(0, Color(0.55, 0.15, 0.15))
			for unit_id: int in division[&"unit_ids"]:
				var unit_item: TreeItem = _add_unit_item(division_item, by_id[unit_id])
				if unit_id == _selected_regiment_id:
					to_select = unit_item
			if division[&"id"] == _selected_division_id and _selected_regiment_id == 0:
				to_select = division_item
		if to_select != null:
			to_select.select(0)
		else:
			_selected_regiment_id = 0
			_selected_division_id = 0
		return
	for unit: Dictionary in _details[&"units"]:
		var item: TreeItem = _tree.create_item(root)
		item.set_text(0, unit[&"name"])
		item.set_text(1, unit[&"type_name"])
		var max_strength: float = unit[&"max_strength"]
		var strength_share: float = float(unit[&"strength"]) / max_strength if max_strength > 0.0 else 0.0
		item.set_text(2, "%d%%" % roundi(strength_share * 100.0))
		var max_organisation: float = unit[&"max_organisation"]
		var organisation_share: float = float(unit[&"organisation"]) / max_organisation if max_organisation > 0.0 else 0.0
		item.set_text(3, "%d%%" % roundi(organisation_share * 100.0))
		item.set_text(4, "%s (%s)" % [unit[&"pop_type"], unit[&"pop_culture"]] if unit[&"pop_type"] != "" else "-")
		item.set_metadata(0, unit[&"id"])
		if unit[&"id"] == _selected_regiment_id:
			to_select = item
	if to_select != null:
		to_select.select(0)
	else:
		_selected_regiment_id = 0


func _update_merge_list() -> void:
	var armies: Array = PlayerSingleton.get_mergeable_armies(_army_ids[_index]) if _details[&"is_player"] else []
	var signature: String = ""
	for army: Dictionary in armies:
		signature += "%d:%d;" % [army[&"id"], army[&"regiments"]]
	if signature != _merge_signature:
		_merge_signature = signature
		_merge_option.clear()
		for army: Dictionary in armies:
			_merge_option.add_item("%s (%d полков)" % [army[&"name"], army[&"regiments"]])
			_merge_option.set_item_metadata(_merge_option.item_count - 1, army[&"id"])
	_merge_option.disabled = _merge_option.item_count == 0
	_merge_button.disabled = _merge_option.item_count == 0 or _details[&"in_combat"]


func _on_nav_pressed(step: int) -> void:
	if _army_ids.is_empty():
		return
	_index = posmod(_index + step, _army_ids.size())
	_selected_regiment_id = 0
	_disband_armed = false
	_refresh()


func _on_regiment_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	_selected_regiment_id = item.get_metadata(0) if item != null else 0
	# A division is selected by its line, a regiment by its own (then the division of the regiment is meant)
	if item != null and item.get_metadata(1) != null and item.get_metadata(1) != 0:
		_selected_division_id = item.get_metadata(1)
	elif item != null and item.get_parent() != null and item.get_parent().get_metadata(1) != null:
		_selected_division_id = item.get_parent().get_metadata(1)
	else:
		_selected_division_id = 0
	_refresh_buttons_only()


func _on_regiment_deselected() -> void:
	_selected_regiment_id = 0
	_selected_division_id = 0
	_tree.deselect_all()
	_refresh_buttons_only()


func _refresh_buttons_only() -> void:
	if _details.is_empty():
		return
	var can_split: bool = _selected_regiment_id != 0 and _details[&"units"].size() > 1 and not _details[&"in_combat"]
	_split_button.disabled = not can_split
	_disband_regiment_button.disabled = _selected_regiment_id == 0 or _details[&"in_combat"]


func _on_split_pressed() -> void:
	if _selected_regiment_id != 0:
		PlayerSingleton.split_regiment(_selected_regiment_id)
		_selected_regiment_id = 0


func _on_disband_regiment_pressed() -> void:
	if _selected_regiment_id != 0:
		PlayerSingleton.disband_regiment(_selected_regiment_id)
		_selected_regiment_id = 0


func _on_merge_pressed() -> void:
	if _merge_option.item_count == 0 or _merge_option.selected < 0:
		return
	var source_id: int = _merge_option.get_item_metadata(_merge_option.selected)
	PlayerSingleton.merge_armies(_army_ids[_index], source_id)


func _on_assign_pressed() -> void:
	if _general_option.item_count == 0 or _general_option.selected < 0:
		return
	var leader_id: int = _general_option.get_item_metadata(_general_option.selected)
	PlayerSingleton.set_army_leader(_army_ids[_index], leader_id)


func _on_remove_leader_pressed() -> void:
	PlayerSingleton.set_army_leader(_army_ids[_index], 0)


func _on_stop_pressed() -> void:
	PlayerSingleton.stop_army(_army_ids[_index])


func _on_recruit_pressed() -> void:
	if _recruitment_window != null:
		_recruitment_window.open_for_province(_details[&"province_number"])


func _on_disband_army_pressed() -> void:
	# Two clicks, so that an army is not lost by accident
	if not _disband_armed:
		_disband_armed = true
		_disband_army_button.text = "Подтвердить роспуск армии"
		return
	_disband_armed = false
	PlayerSingleton.disband_army(_army_ids[_index])
