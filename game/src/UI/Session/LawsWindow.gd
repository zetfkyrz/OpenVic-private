extends "res://src/UI/Session/Vic2Window.gd"
## The window of the laws (docs/LAWS_DESIGN.md): three columns (power, economy, human rights) of law groups, as in the grid of the owner's picture.
## Every group shows the law in force; its list gives the other variants, the tooltip of a variant lists what it does (the effects of OpenVic and the
## modifiers of Vic2 it carries). Below: the kind of the mobilisation. The data are the ones of the simulation (PlayerSingleton.get_laws), nothing is
## counted here. Opened with F6.

const _SIZE: Vector2 = Vector2(1500, 820)
const _TOGGLE_KEY: Key = KEY_F6
const _COLUMNS: PackedStringArray = ["power", "economy", "human_rights"]
const _ROW_COLOUR: Color = Color(0.12, 0.17, 0.16)
const _ROW_BORDER: Color = Color(0.45, 0.36, 0.2)
const _ROW_TEXT: Color = Color(0.93, 0.88, 0.76)
const _ROW_MUTED: Color = Color(0.72, 0.68, 0.6)

## The effects of OpenVic (politics/Law.hpp; their names: LAW_EFFECT_<id> of ov_data/localisation/ov_laws.csv), shares unless listed here
const _FLAG_EFFECTS: PackedStringArray = ["no_foreign_trade"]

var _columns: Dictionary = {} # column id -> VBoxContainer
var _mobilisation: OptionButton
var _signature: String = ""
var _building: bool = false


## The text in Russian (the keys with the ending _RU of ov_data/localisation), the text of the locale if there is none
func _t(key: String) -> String:
	var russian: String = tr(key + "_RU")
	return russian if russian != key + "_RU" else tr(key)


func _ready() -> void:
	setup(_SIZE, _t("LAWS_WINDOW"))

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 8)
	content.add_child(root)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override(&"separation", 10)
	root.add_child(columns)
	for column: String in _COLUMNS:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override(&"separation", 4)
		var header := Label.new()
		header.text = _t("LAWS_COLUMN_" + column)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_font_size_override(&"font_size", 18)
		header.add_theme_color_override(&"font_color", HEADER_COLOUR)
		box.add_child(header)
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override(&"separation", 4)
		box.add_child(rows)
		_columns[column] = rows
		columns.add_child(box)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override(&"separation", 8)
	root.add_child(bottom)
	var mobilisation_label := Label.new()
	mobilisation_label.text = _t("LAWS_MOBILISATION_LEVEL")
	mobilisation_label.add_theme_color_override(&"font_color", TEXT_COLOUR)
	bottom.add_child(mobilisation_label)
	_mobilisation = OptionButton.new()
	for level: int in 3:
		_mobilisation.add_item(_t("LAWS_MOBILISATION_" + str(level)), level)
	_mobilisation.item_selected.connect(_on_mobilisation_selected)
	bottom.add_child(_mobilisation)

	GameSingleton.gamestate_updated.connect(_on_gamestate_updated)


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event and key_event.pressed and not key_event.echo and key_event.keycode == _TOGGLE_KEY:
		if visible:
			close()
		else:
			open_laws()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)


func open_laws() -> void:
	# The window is opened first (a hidden window does not refresh)
	_signature = ""
	open_window()
	_refresh()


func _on_gamestate_updated() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	var laws: Array = PlayerSingleton.get_laws()
	var level: int = PlayerSingleton.get_mobilisation_level()
	var signature: String = str(laws.hash()) + "|" + str(level)
	if signature == _signature:
		return
	_signature = signature
	_building = true
	for column: String in _COLUMNS:
		var rows: VBoxContainer = _columns[column]
		for child: Node in rows.get_children():
			child.queue_free()
	var sorted: Array = laws.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))
	for group: Dictionary in sorted:
		var rows: VBoxContainer = _columns.get(String(group["column"]), _columns["power"])
		rows.add_child(_make_row(group))
	_mobilisation.select(clampi(level, 0, 2))
	_building = false


func _make_row(group: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = _ROW_COLOUR
	style.border_color = _ROW_BORDER
	style.set_border_width_all(1)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override(&"panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	panel.add_child(box)
	var name_label := Label.new()
	name_label.text = _t(String(group["name"]))
	name_label.add_theme_color_override(&"font_color", _ROW_MUTED)
	name_label.add_theme_font_size_override(&"font_size", 13)
	box.add_child(name_label)
	var option := OptionButton.new()
	option.add_theme_font_size_override(&"font_size", 16)
	var current: int = int(group["current"])
	var variants: Array = group["variants"]
	for i: int in variants.size():
		var variant: Dictionary = variants[i]
		option.add_item(_t(String(variant["name"])), int(variant["index"]))
		option.get_popup().set_item_tooltip(i, _describe(variant))
		if int(variant["index"]) == current:
			option.select(i)
			option.tooltip_text = _describe(variant)
	option.item_selected.connect(func(item: int) -> void: _on_law_selected(option, item, current))
	box.add_child(option)
	# The law that is being passed: its name, the support of the voters, the months of the stall (a click on the law in force withdraws it)
	var proposal: int = int(group.get("proposal", -1))
	if proposal >= 0:
		var proposed_name: String = ""
		for variant: Dictionary in variants:
			if int(variant["index"]) == proposal:
				proposed_name = _t(String(variant["name"]))
		var status := Label.new()
		status.text = _t("LAWS_PROPOSAL") % [proposed_name, roundi(float(group["support"]) * 100.0), int(group["stall"])]
		status.add_theme_color_override(&"font_color", Color(0.95, 0.78, 0.35))
		status.add_theme_font_size_override(&"font_size", 13)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(status)
	return panel


## What a variant does: the effects of OpenVic, then the modifiers of Vic2 it carries
func _describe(variant: Dictionary) -> String:
	var lines: PackedStringArray = []
	var effects: Dictionary = variant["effects"]
	for key: String in effects:
		var value: float = float(effects[key])
		var label: String = _t("LAW_EFFECT_" + key)
		if key in _FLAG_EFFECTS:
			lines.append(label)
		else:
			lines.append("%s: %+d %%" % [label, roundi(value * 100.0)])
	var modifiers: Dictionary = variant["modifiers"]
	for key: String in modifiers:
		var amount: float = float(modifiers[key])
		if absf(amount) < 0.0001:
			continue
		var label: String = tr(key)
		if label == key:
			label = tr("modifier_" + key)
			if label == "modifier_" + key:
				label = key
		lines.append("%s: %s" % [label, ("%+.2f" % amount).rstrip("0").rstrip(".")])
	if lines.is_empty():
		lines.append(_t("LAWS_NO_EFFECTS"))
	return "\n".join(lines)


func _on_law_selected(option: OptionButton, item: int, current: int) -> void:
	if _building:
		return
	# Another variant is proposed; the law in force withdraws the proposal of the group
	PlayerSingleton.set_law(option.get_item_id(item))


func _on_mobilisation_selected(item: int) -> void:
	if _building:
		return
	PlayerSingleton.set_mobilisation_level(_mobilisation.get_item_id(item))
