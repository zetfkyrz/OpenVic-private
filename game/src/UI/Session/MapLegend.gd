extends PanelContainer
## The legend of the map modes of the diplomacy (version 104, stage D9 of docs/PLAN_DIPLOMACY_VIC2.md): what the colours of the maps
## "Дипломатия", "Отношения" and "Кризис" mean. Shown at the left of the screen while one of them is on; the colours are the ones of
## openvic-simulation/map/Mapmode.cpp.

const _LEGENDS: Dictionary = {
	"mapmode_diplomatic": {
		&"title": "Дипломатия",
		&"hint": "Страна выбранной провинции (без выбора — наша). Полосы: кто занял землю; её ядра на чужой земле — зелёные.",
		&"rows": [
			[Color8(0x1E, 0x9E, 0x3A), "сама страна"],
			[Color8(0x8E, 0xD0, 0x81), "её субъекты"],
			[Color8(0x2E, 0x8C, 0x8C), "её сюзерен"],
			[Color8(0x2F, 0x6F, 0xD0), "союзники, военный союз"],
			[Color8(0xC8, 0x30, 0x2C), "враги (война)"],
			[Color8(0x9A, 0x6F, 0xC8), "её сфера"],
			[Color8(0x8F, 0xD3, 0xF0), "право прохода через них"],
			[Color8(0x9A, 0x9A, 0x9A), "остальные"],
		],
	},
	"mapmode_relations": {
		&"title": "Отношения",
		&"hint": "Отношения страны выбранной провинции (без выбора — нашей) с каждой страной, вместе со следом войн.",
		&"rows": [
			[Color8(0x2F, 0x6F, 0xD0), "сама страна"],
			[Color8(0x14, 0x6B, 0x2A), "+200"],
			[Color8(0x3A, 0xA8, 0x4E), "+100"],
			[Color8(0xD9, 0xD2, 0xA6), "0"],
			[Color8(0xC0, 0x30, 0x2C), "−100"],
			[Color8(0x5A, 0x0E, 0x0E), "−200"],
		],
	},
	"mapmode_crisis": {
		&"title": "Очаги кризисов",
		&"hint": "Где может начаться кризис: чужие ядра на земле владельца. Кризис начинается, когда напряжённость области дойдёт до 100 (вкладка «Кризис» окна «Дипломатия»).",
		&"rows": [
			[Color8(0xE6, 0xC8, 0x4A), "ядра нации без своей страны"],
			[Color8(0xE0, 0x70, 0x2A), "ядра другой страны (притязания)"],
			[Color8(0xC8, 0x14, 0x14), "кризис сейчас; красная полоса — напряжённость от 75"],
			[Color8(0xBD, 0xBD, 0xB0), "спокойно"],
		],
	},
}

var _title: Label
var _hint: Label
var _rows: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	# (under the button of the help of the AI)
	position = Vector2(8, 165)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.85)
	style.border_color = Color(0.75, 0.6, 0.3)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	add_theme_stylebox_override(&"panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	box.custom_minimum_size = Vector2(230, 0)
	add_child(box)
	_title = Label.new()
	_title.add_theme_color_override(&"font_color", Color(0.95, 0.85, 0.55))
	box.add_child(_title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 2)
	box.add_child(_rows)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(230, 0)
	_hint.add_theme_font_size_override(&"font_size", 12)
	_hint.add_theme_color_override(&"font_color", Color(0.8, 0.78, 0.7))
	box.add_child(_hint)
	visible = false
	GameSingleton.mapmode_changed.connect(_on_mapmode_changed)
	_on_mapmode_changed(GameSingleton.get_current_mapmode_index())


func _on_mapmode_changed(index: int) -> void:
	var legend: Dictionary = _LEGENDS.get(GameSingleton.get_mapmode_identifier(index), {})
	visible = not legend.is_empty()
	if legend.is_empty():
		return
	_title.text = legend[&"title"]
	_hint.text = legend[&"hint"]
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for row: Array in legend[&"rows"]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 6)
		var swatch := ColorRect.new()
		swatch.color = row[0]
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(swatch)
		var text := Label.new()
		text.text = row[1]
		text.add_theme_font_size_override(&"font_size", 13)
		line.add_child(text)
		_rows.add_child(line)
	reset_size()
