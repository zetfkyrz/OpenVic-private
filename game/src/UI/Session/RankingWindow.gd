extends "res://src/UI/Session/Vic2Window.gd"
## Ranking of the countries (task E3): total score, prestige, industrial and military power with the rank in each
## list; great powers are marked, the player country is highlighted. A click on a column title sorts the table by
## that column. A Victoria 2 style window, opened with F10.

const _SIZE: Vector2 = Vector2(760, 640)
const _TOGGLE_KEY: Key = KEY_F10
const _COLUMNS: PackedStringArray = ["№", "Страна", "Престиж", "Место", "Промышленность", "Место", "Армия", "Место", "Итого"]
const _KEYS: Array[StringName] = [
	&"rank", &"name", &"prestige", &"prestige_rank", &"industrial", &"industrial_rank", &"military", &"military_rank", &"total",
]

var _tree: Tree
var _countries: Array = []
var _sort_key: StringName = &"rank"
var _sort_ascending: bool = true
var _great_only: CheckBox


func _ready() -> void:
	setup(_SIZE, "Рейтинг стран")

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 6)
	content.add_child(root)

	_great_only = CheckBox.new()
	_great_only.text = "Только великие державы"
	_great_only.toggled.connect(func(_pressed: bool) -> void: _rebuild())
	root.add_child(_great_only)

	_tree = Tree.new()
	_tree.columns = _COLUMNS.size()
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for column: int in _COLUMNS.size():
		_tree.set_column_title(column, _COLUMNS[column])
		_tree.set_column_custom_minimum_width(column, 60)
	_tree.set_column_expand(1, true)
	_tree.set_column_custom_minimum_width(1, 150)
	_tree.column_title_clicked.connect(_on_column_clicked)
	root.add_child(_tree)

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
	_countries = PlayerSingleton.get_country_ranking()
	_rebuild()


func _rebuild() -> void:
	var key: StringName = _sort_key
	var ascending: bool = _sort_ascending
	_countries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a[key] < b[key] if ascending else a[key] > b[key]
	)
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	for country: Dictionary in _countries:
		if _great_only.button_pressed and not country[&"great_power"]:
			continue
		var item: TreeItem = _tree.create_item(root)
		item.set_text(0, str(country[&"rank"]))
		item.set_text(1, country[&"name"] + (" *" if country[&"great_power"] else ""))
		item.set_text(2, "%.0f" % country[&"prestige"])
		item.set_text(3, str(country[&"prestige_rank"]))
		item.set_text(4, "%.0f" % country[&"industrial"])
		item.set_text(5, str(country[&"industrial_rank"]))
		item.set_text(6, "%.0f" % country[&"military"])
		item.set_text(7, str(country[&"military_rank"]))
		item.set_text(8, "%.0f" % country[&"total"])
		if country[&"is_player"]:
			for column: int in _COLUMNS.size():
				item.set_custom_bg_color(column, Color(0.6, 0.18, 0.2, 0.35))


func _on_column_clicked(column: int, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	var key: StringName = _KEYS[column]
	if key == _sort_key:
		_sort_ascending = not _sort_ascending
	else:
		_sort_key = key
		# Ranks go up, the scores go down
		_sort_ascending = key in [&"rank", &"name", &"prestige_rank", &"industrial_rank", &"military_rank"]
	_rebuild()
