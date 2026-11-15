extends PanelContainer
## The proposals of other countries that wait for the answer of the player (version 96, stage D1 of docs/PLAN_DIPLOMACY_VIC2.md): an alliance,
## military access, war subsidies. A row with the country, the proposal, the days left and the buttons "Принять" / "Отказать"; the panel is
## shown at the top of the screen while there is a proposal. Without an answer the proposal is declined after DIPLOMATIC_PROPOSAL_DAYS.

const _ACTION_TEXT: Dictionary = {
	"form_alliance": "предлагает союз",
	"request_military_access": "просит права прохода войск через нашу землю",
	"give_military_access": "предлагает нам право прохода войск",
	"war_subsidies": "предлагает нам военные субсидии",
}

const _MAX_ROWS: int = 5
var _rows: VBoxContainer
# The proposals answered here that the simulation has not taken off yet (the answer is a game action of the next update)
var _answered: Dictionary[int, bool] = {}


func _ready() -> void:
	# (placed in the middle of the screen by _place: the parent is not as wide as the screen)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.92)
	style.border_color = Color(0.75, 0.6, 0.3)
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	add_theme_stylebox_override(&"panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	add_child(box)
	var title := Label.new()
	title.text = "Дипломатические предложения"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_color", Color(0.95, 0.85, 0.55))
	box.add_child(title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 4)
	box.add_child(_rows)
	visible = false
	GameSingleton.gamestate_updated.connect(_refresh)
	_refresh()


func _refresh() -> void:
	# (taken out at once: the size of the panel must not count the old rows)
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var shown: int = 0
	var waiting: Dictionary[int, bool] = {}
	for proposal: Dictionary in PlayerSingleton.get_diplomatic_proposals():
		var id: int = int(proposal[&"id"])
		waiting[id] = true
		if _answered.has(id):
			continue
		shown += 1
		if shown <= _MAX_ROWS:
			_rows.add_child(_make_row(proposal))
	if shown > _MAX_ROWS:
		var more := Label.new()
		more.text = "…и ещё %d (ответьте на эти — покажутся следующие)" % (shown - _MAX_ROWS)
		_rows.add_child(more)
	# the answers the simulation has taken off are forgotten
	for id: int in _answered.keys():
		if not waiting.has(id):
			_answered.erase(id)
	visible = shown > 0
	if visible:
		_place.call_deferred()


func _place() -> void:
	reset_size()
	var screen: Vector2 = get_viewport_rect().size
	global_position = Vector2(roundf((screen.x - size.x) / 2.0), 120.0)


func _make_row(proposal: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var text := Label.new()
	var action: String = proposal[&"action"]
	text.text = "%s %s (осталось %d дн.)" % [proposal[&"sender_name"], _ACTION_TEXT.get(action, action), int(proposal[&"days_left"])]
	row.add_child(text)
	var accept := Button.new()
	accept.text = "Принять"
	accept.pressed.connect(_answer.bind(int(proposal[&"id"]), true))
	row.add_child(accept)
	var decline := Button.new()
	decline.text = "Отказать"
	decline.pressed.connect(_answer.bind(int(proposal[&"id"]), false))
	row.add_child(decline)
	return row


func _answer(id: int, accept: bool) -> void:
	PlayerSingleton.answer_diplomatic_proposal(id, accept)
	_answered[id] = true
	_refresh()
