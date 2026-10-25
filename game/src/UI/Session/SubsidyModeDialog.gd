extends "res://src/UI/Session/Vic2Window.gd"
## Choice of the factories whose losses the state pays (all / only state owned / by the share of ownership).
## A Victoria 2 style popup opened from the button next to the industrial subsidies of the budget.

signal mode_chosen(mode: int)

const _NAMES: PackedStringArray = [
	"Субсидировать все предприятия", "Только государственные", "По доле владения",
]
const _TIPS: PackedStringArray = [
	"Государство покрывает убытки всех субсидируемых заводов полностью, капиталисты не платят.",
	"Государство полностью оплачивает убытки заводов, в которых ему принадлежит хоть какая-то доля. Частные заводы государство не субсидирует: их покрывают капиталисты.",
	"Государство платит долю убытков, равную его доле владения, остальное покрывают капиталисты.",
]

var _buttons: Array[Button] = []


func _ready() -> void:
	setup(Vector2(430, 250), "Субсидии промышленности")

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 6)
	content.add_child(root)

	for i: int in _NAMES.size():
		var button := Button.new()
		button.text = _NAMES[i]
		button.tooltip_text = _TIPS[i]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 30)
		button.pressed.connect(_choose.bind(i))
		root.add_child(button)
		_buttons.append(button)

	var tip := Label.new()
	tip.text = "Выберите, убытки каких предприятий оплачивает государство. Остальное покрывают капиталисты."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_color_override(&"font_color", MUTED_TEXT_COLOUR)
	root.add_child(tip)

	hide()


func open(current_mode: int) -> void:
	show_mode(current_mode)
	open_window()


func show_mode(mode: int) -> void:
	for i: int in _buttons.size():
		_buttons[i].set_pressed_no_signal(i == mode)


func _choose(mode: int) -> void:
	show_mode(mode)
	mode_chosen.emit(mode)
	close()
