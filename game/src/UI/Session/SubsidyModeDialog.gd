extends "res://src/UI/Session/Vic2Window.gd"
## Choice of the factories whose losses the state pays (all / only state owned / by the share of ownership).
## A Victoria 2 style popup opened from the button next to the industrial subsidies of the budget.

signal mode_chosen(mode: int)

const _NAMES: PackedStringArray = [
	"Субсидировать все", "По доле владения", "Антикризисные субсидии", "Жёсткий антикризисный",
]
const _TIPS: PackedStringArray = [
	"Государство полностью оплачивает убытки всех отмеченных предприятий, капиталисты не платят.",
	"Государство платит долю убытков, равную его доле владения, остальное покрывают капиталисты.",
	"Работает как «по доле владения», пока у капиталистов есть деньги. Когда их деньги заканчиваются, государство берёт на себя и их часть убытков, какой бы ни была его доля владения, чтобы поддержать экономику.",
	"Как антикризисные, но не бесплатно: за деньги, которые государство заплатило за капиталистов, оно в начале каждого месяца забирает долю завода по его стоимости (в целых процентах, округляя вверх, но не больше доли капиталистов; всего не больше 100%).",
]

var _buttons: Array[Button] = []
var _tip: Label
const _DEFAULT_TIP: String = "Наведите на режим, чтобы прочитать, как он работает. Выбранный режим подсвечен."


func _ready() -> void:
	setup(Vector2(500, 400), "Субсидии промышленности")

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
		# The description of the mode under the cursor is written below
		button.mouse_entered.connect(func() -> void: _tip.text = _TIPS[i])
		button.mouse_exited.connect(func() -> void: _tip.text = _DEFAULT_TIP)
		root.add_child(button)
		_buttons.append(button)

	_tip = Label.new()
	_tip.text = _DEFAULT_TIP
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(0, 90)
	_tip.add_theme_color_override(&"font_color", MUTED_TEXT_COLOUR)
	root.add_child(_tip)

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
