extends "res://src/UI/Session/Vic2Window.gd"
## Templates of the divisions (docs/PLAN_ARMY_SUPPLY_FRONTS.md, section 4): how many regiments of every kind a division needs. A template can be
## made, changed (all the divisions of the template change with it) and deleted (its divisions stay, out of the template). Only the countries with
## the technology of the organisation of the army have templates. A sketch of the constructor of the divisions: the sums of the attack, the
## defence and the cost will come later.

const _SIZE: Vector2 = Vector2(640, 420)

var _templates: Array = []
var _selected_id: int = 0
var _signature: String = ""

var _info_label: Label
var _tree: Tree
var _spins: Array[SpinBox] = []
var _create_button: Button
var _update_button: Button
var _delete_button: Button


func _ready() -> void:
	setup(_SIZE, "Шаблоны дивизий")

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 6)
	content.add_child(root)

	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_info_label)

	_tree = Tree.new()
	_tree.columns = 5
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var titles: PackedStringArray = ["Шаблон", "Пехота", "Кавалерия", "Поддержка", "Особые"]
	for column: int in titles.size():
		_tree.set_column_title(column, titles[column])
	_tree.set_column_expand(0, true)
	_tree.item_selected.connect(_on_item_selected)
	_tree.nothing_selected.connect(_on_nothing_selected)
	root.add_child(_tree)

	var spin_row := HBoxContainer.new()
	spin_row.add_theme_constant_override(&"separation", 6)
	root.add_child(spin_row)
	var captions: PackedStringArray = ["Пехота", "Кавалерия", "Поддержка", "Особые"]
	for caption: String in captions:
		var label := Label.new()
		label.text = caption + ":"
		spin_row.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 40
		spin.step = 1
		spin.value = 0
		spin_row.add_child(spin)
		_spins.append(spin)
	_spins[0].value = 3
	_spins[1].value = 1

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override(&"separation", 6)
	root.add_child(button_row)
	_create_button = Button.new()
	_create_button.text = "Создать шаблон"
	_create_button.pressed.connect(_on_create_pressed)
	button_row.add_child(_create_button)
	_update_button = Button.new()
	_update_button.text = "Изменить выбранный"
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


func _values() -> Array[int]:
	var values: Array[int] = []
	for spin: SpinBox in _spins:
		values.append(int(spin.value))
	return values


func _refresh() -> void:
	if not visible:
		return
	if not PlayerSingleton.has_army_organisation():
		_info_label.text = "Шаблоны дивизий открываются технологией «Организация армии» (цивилизованным странам)."
	else:
		_info_label.text = "Шаблон задаёт, сколько полков каждого вида нужно дивизии. Полки, которые есть со старта игры, остаются вне шаблона, пока вы не нажмёте «Переформировать по шаблону» в панели армии."
	_templates = PlayerSingleton.get_division_templates()
	var signature: String = str(_templates) + str(_selected_id)
	if signature == _signature:
		return
	_signature = signature
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var to_select: TreeItem = null
	for entry: Dictionary in _templates:
		var item: TreeItem = _tree.create_item(root)
		item.set_text(0, entry[&"name"])
		item.set_text(1, str(entry[&"infantry"]))
		item.set_text(2, str(entry[&"cavalry"]))
		item.set_text(3, str(entry[&"support"]))
		item.set_text(4, str(entry[&"special"]))
		item.set_metadata(0, entry[&"id"])
		if entry[&"id"] == _selected_id:
			to_select = item
	if to_select != null:
		to_select.select(0)
	else:
		_selected_id = 0
	_update_buttons()


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
			_spins[0].value = entry[&"infantry"]
			_spins[1].value = entry[&"cavalry"]
			_spins[2].value = entry[&"support"]
			_spins[3].value = entry[&"special"]
	_update_buttons()


func _on_nothing_selected() -> void:
	_selected_id = 0
	_tree.deselect_all()
	_update_buttons()


func _on_create_pressed() -> void:
	var v: Array[int] = _values()
	PlayerSingleton.create_division_template(v[0], v[1], v[2], v[3])


func _on_update_pressed() -> void:
	var v: Array[int] = _values()
	PlayerSingleton.update_division_template(_selected_id, v[0], v[1], v[2], v[3])


func _on_delete_pressed() -> void:
	PlayerSingleton.delete_division_template(_selected_id)
	_selected_id = 0
