extends Control
## The laws of the country (docs/LAWS_DESIGN.md) on the tab "Reforms" of the politics screen (PoliticsMenu): three columns (power, economy, human
## rights) of law groups, as in the grid of the owner's picture. Every group shows the law in force; its list gives the other variants, the tooltip of
## a variant lists what it does (the effects of OpenVic and the modifiers of Vic2 it carries). A chosen variant is proposed (PlayerSingleton.set_law),
## the law in force withdraws the proposal. The data are the ones of the simulation (PlayerSingleton.get_laws), nothing is counted here.

const _COLUMNS: PackedStringArray = ["power", "economy", "human_rights"]
const _HEADER_COLOUR: Color = Color(0.45, 0.1, 0.1)
const _ROW_COLOUR: Color = Color(0.12, 0.17, 0.16)
const _ROW_BORDER: Color = Color(0.45, 0.36, 0.2)
const _ROW_MUTED: Color = Color(0.72, 0.68, 0.6)
const _PROPOSAL_COLOUR: Color = Color(0.95, 0.78, 0.35)
## The parchment under the laws: it covers the pictures of the tabs of Victoria 2 that stay in the window
const _BACKGROUND_COLOUR: Color = Color(0.86, 0.83, 0.76)

## The effects of OpenVic (politics/Law.hpp; their names: LAW_EFFECT_<id> of ov_data/localisation/ov_laws.csv), shares unless listed here
const _FLAG_EFFECTS: PackedStringArray = ["no_foreign_trade", "no_emigration", "no_immigration", "secular_schools"]

var _columns: Dictionary = {} # column id -> VBoxContainer
var _signature: String = ""
var _building: bool = false


## The text in Russian (the keys with the ending _RU of ov_data/localisation), the text of the locale if there is none
func _t(key: String) -> String:
	var russian: String = tr(key + "_RU")
	return russian if russian != key + "_RU" else tr(key)


func _ready() -> void:
	var background := Panel.new()
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = _BACKGROUND_COLOUR
	background.add_theme_stylebox_override(&"panel", background_style)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var columns := HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.offset_left = 4.0
	columns.offset_right = -4.0
	columns.offset_top = 4.0
	columns.add_theme_constant_override(&"separation", 4)
	add_child(columns)
	for column: String in _COLUMNS:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_stretch_ratio = 1.0
		box.add_theme_constant_override(&"separation", 3)
		var header := Label.new()
		header.text = _t("LAWS_COLUMN_" + column)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_font_size_override(&"font_size", 15)
		header.add_theme_color_override(&"font_color", _HEADER_COLOUR)
		box.add_child(header)
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override(&"separation", 3)
		box.add_child(rows)
		_columns[column] = rows
		columns.add_child(box)

	GameSingleton.gamestate_updated.connect(_on_gamestate_updated)
	visibility_changed.connect(refresh)


func _on_gamestate_updated() -> void:
	refresh()


## Rebuilds the rows if the laws changed (only while the tab is seen)
func refresh() -> void:
	if not is_visible_in_tree():
		return
	var laws: Array = PlayerSingleton.get_laws()
	var signature: String = str(laws.hash())
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
	_building = false


func _make_row(group: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = _ROW_COLOUR
	style.border_color = _ROW_BORDER
	style.set_border_width_all(1)
	style.content_margin_left = 3.0
	style.content_margin_right = 3.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 3.0
	panel.add_theme_stylebox_override(&"panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 1)
	panel.add_child(box)
	var name_label := Label.new()
	name_label.text = _t(String(group["name"]))
	name_label.add_theme_color_override(&"font_color", _ROW_MUTED)
	name_label.add_theme_font_size_override(&"font_size", 11)
	name_label.clip_text = true
	box.add_child(name_label)
	var option := OptionButton.new()
	option.add_theme_font_size_override(&"font_size", 12)
	# Narrow inner margins: the long names of the laws fit the column
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		var box_style: StyleBox = option.get_theme_stylebox(state)
		if box_style:
			box_style = box_style.duplicate()
			box_style.content_margin_left = 4.0
			box_style.content_margin_right = 2.0
			option.add_theme_stylebox_override(state, box_style)
	# As wide as the column, not as the longest variant
	option.fit_to_longest_item = false
	# A long name goes on two lines (the tab has room in height, not in width)
	option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	option.custom_minimum_size.x = 10.0
	var current: int = int(group["current"])
	var variants: Array = group["variants"]
	for i: int in variants.size():
		var variant: Dictionary = variants[i]
		option.add_item(_t(String(variant["name"])), int(variant["index"]))
		option.get_popup().set_item_tooltip(i, _describe(variant))
		if int(variant["index"]) == current:
			option.select(i)
			option.tooltip_text = _t(String(variant["name"])) + "\n" + _describe(variant)
	option.item_selected.connect(func(item: int) -> void: _on_law_selected(option, item))
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
		status.add_theme_color_override(&"font_color", _PROPOSAL_COLOUR)
		status.add_theme_font_size_override(&"font_size", 11)
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


func _on_law_selected(option: OptionButton, item: int) -> void:
	if _building:
		return
	# Another variant is proposed; the law in force withdraws the proposal of the group
	PlayerSingleton.set_law(option.get_item_id(item))
