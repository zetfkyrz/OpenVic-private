extends "res://src/UI/Session/Vic2Window.gd"
## Groups of armies and field marshals (docs/PLAN_ARMY_SUPPLY_FRONTS.md, sections 1 and 4): a group joins armies (an army is put into a group in
## its panel); a field marshal is a general that leads no army, he gives half of his bonus to the supply of all the armies of the group. Only
## the countries with the technology of the organisation of the army have groups.

const _SIZE: Vector2 = Vector2(640, 420)

var _groups: Array = []
var _selected_id: int = 0
var _signature: String = ""

var _info_label: Label
var _tree: Tree
var _armies_label: Label
var _marshal_option: OptionButton
var _assign_button: Button
var _remove_button: Button
var _create_button: Button
var _delete_button: Button


func _ready() -> void:
	setup(_SIZE, "Группы армий")

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 6)
	content.add_child(root)

	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_info_label)

	_tree = Tree.new()
	_tree.columns = 3
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var titles: PackedStringArray = ["Группа", "Фельдмаршал", "Армий"]
	for column: int in titles.size():
		_tree.set_column_title(column, titles[column])
	_tree.set_column_expand(0, true)
	_tree.item_selected.connect(_on_item_selected)
	_tree.nothing_selected.connect(_on_nothing_selected)
	root.add_child(_tree)

	_armies_label = Label.new()
	_armies_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_armies_label)

	var marshal_row := HBoxContainer.new()
	marshal_row.add_theme_constant_override(&"separation", 6)
	root.add_child(marshal_row)
	var marshal_caption := Label.new()
	marshal_caption.text = "Фельдмаршал:"
	marshal_row.add_child(marshal_caption)
	_marshal_option = OptionButton.new()
	_marshal_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_marshal_option.clip_text = true
	marshal_row.add_child(_marshal_option)
	_assign_button = Button.new()
	_assign_button.text = "Назначить"
	_assign_button.tooltip_text = "Генерал, который командует армией, оставит её и станет фельдмаршалом"
	_assign_button.pressed.connect(_on_assign_pressed)
	marshal_row.add_child(_assign_button)
	_remove_button = Button.new()
	_remove_button.text = "Снять"
	_remove_button.pressed.connect(_on_remove_pressed)
	marshal_row.add_child(_remove_button)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override(&"separation", 6)
	root.add_child(button_row)
	_create_button = Button.new()
	_create_button.text = "Создать группу"
	_create_button.pressed.connect(_on_create_pressed)
	button_row.add_child(_create_button)
	_delete_button = Button.new()
	_delete_button.text = "Удалить выбранную"
	_delete_button.tooltip_text = "Армии группы остаются, фельдмаршал освобождается"
	_delete_button.pressed.connect(_on_delete_pressed)
	button_row.add_child(_delete_button)

	GameSingleton.gamestate_updated.connect(_refresh)


func open_groups() -> void:
	# The window is opened first (a hidden window does not refresh)
	_signature = ""
	open_window()
	_refresh()


func _refresh() -> void:
	if not visible:
		return
	if not PlayerSingleton.has_army_organisation():
		_info_label.text = "Группы армий и фельдмаршалы открываются технологией «Организация армии» (цивилизованным странам)."
	else:
		_info_label.text = "Армия входит в группу в своей панели. Фельдмаршал даёт половину своего бонуса к снабжению всем армиям группы."
	_groups = PlayerSingleton.get_army_groups()
	var generals: Array = PlayerSingleton.get_generals()
	var signature: String = str(_groups) + str(_selected_id) + str(generals.size())
	for general: Dictionary in generals:
		signature += "%d:%d:%s;" % [general[&"leader_id"], general[&"army_id"], general.get(&"is_marshal", false)]
	if signature == _signature:
		return
	_signature = signature

	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var to_select: TreeItem = null
	for group: Dictionary in _groups:
		var item: TreeItem = _tree.create_item(root)
		item.set_text(0, group[&"name"])
		item.set_text(1, group[&"marshal_name"] if group[&"marshal_name"] != "" else "-")
		item.set_text(2, str(group[&"army_count"]))
		item.set_metadata(0, group[&"id"])
		if group[&"id"] == _selected_id:
			to_select = item
	if to_select != null:
		to_select.select(0)
	else:
		_selected_id = 0

	_marshal_option.clear()
	for general: Dictionary in generals:
		# Every general that is not a marshal already can become one (a general that leads an army leaves it)
		if not general.get(&"is_marshal", false):
			var text: String = "%s (престиж %.1f)" % [general.get(&"leader_name", "?"), general[&"prestige"]]
			if general[&"army_id"] != 0:
				text += " - командует: %s" % general[&"army_name"]
			_marshal_option.add_item(text)
			_marshal_option.set_item_metadata(_marshal_option.item_count - 1, general[&"leader_id"])
	_update_selected_info()
	_update_buttons()


func _update_selected_info() -> void:
	_armies_label.text = ""
	for group: Dictionary in _groups:
		if group[&"id"] == _selected_id:
			var names: PackedStringArray = []
			for army_id: int in group[&"army_ids"]:
				var details: Dictionary = PlayerSingleton.get_army_details(army_id)
				if not details.is_empty():
					names.append(details[&"name"])
			_armies_label.text = "Армии группы: %s" % (", ".join(names) if not names.is_empty() else "нет")


func _update_buttons() -> void:
	var allowed: bool = PlayerSingleton.has_army_organisation()
	var selected: bool = _selected_id != 0
	_create_button.disabled = not allowed
	_delete_button.disabled = not allowed or not selected
	_assign_button.disabled = not allowed or not selected or _marshal_option.item_count == 0
	_marshal_option.disabled = not allowed or not selected or _marshal_option.item_count == 0
	var has_marshal: bool = false
	for group: Dictionary in _groups:
		if group[&"id"] == _selected_id and group[&"marshal_id"] != 0:
			has_marshal = true
	_remove_button.disabled = not allowed or not selected or not has_marshal


func _on_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	_selected_id = item.get_metadata(0) if item != null else 0
	_update_selected_info()
	_update_buttons()


func _on_nothing_selected() -> void:
	_selected_id = 0
	_tree.deselect_all()
	_update_selected_info()
	_update_buttons()


func _on_create_pressed() -> void:
	PlayerSingleton.create_army_group()


func _on_delete_pressed() -> void:
	PlayerSingleton.delete_army_group(_selected_id)
	_selected_id = 0


func _on_assign_pressed() -> void:
	if _marshal_option.item_count == 0 or _marshal_option.selected < 0:
		return
	PlayerSingleton.set_army_group_marshal(_selected_id, _marshal_option.get_item_metadata(_marshal_option.selected))


func _on_remove_pressed() -> void:
	PlayerSingleton.set_army_group_marshal(_selected_id, 0)
