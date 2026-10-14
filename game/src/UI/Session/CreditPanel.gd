extends "res://src/UI/Session/Vic2Window.gd"
## Central bank and credit: rates of the loans the country gives, tables of the loans it took and gave, the offers of the
## other countries, lending to groups of countries and loans to the capitalists of the states.
## A Victoria 2 style window (frame, close button, dragging), opened from the budget screen.

const _TERM_NAMES: PackedStringArray = ["Краткосрочный (5 лет)", "Среднесрочный (10 лет)", "Долгосрочный (20 лет)"]
const _TERM_TIPS: PackedStringArray = [
	"5 лет, платежи по телу долга не берутся первые 2 года. Капиталисты могут тратить только на стройки до 365 дней.",
	"10 лет, платежи по телу долга не берутся первые 4 года. Без ограничений на траты.",
	"20 лет, платежи по телу долга не берутся первые 8 лет. Без ограничений на траты.",
]
const _POLICY_NAMES: PackedStringArray = ["Простить долг", "Мягко: забрать деньги", "Жёстко: деньги, затем доли заводов"]
const _POLICY_TIPS: PackedStringArray = [
	"По окончании срока непогашенный долг списывается.",
	"По окончании срока берутся деньги капиталистов (накопления и наличные), заводы не трогаются. Остаток списывается.",
	"Сначала берутся деньги, затем доли капиталистов в заводах по стоимости завода. Остаток списывается.",
]
const _GROUP_ALL: int = 0
const _GROUP_ALLIES: int = 1
const _GROUP_FRIENDS: int = 2
const _GROUP_SELECTED: int = 3

var _overview: Dictionary = {}

var _tabs: TabContainer
var _summary: Label

# Central bank
var _internal_rate: SpinBox
var _external_rate: SpinBox

# Taken / given loans
var _taken_tree: Tree
var _repay_amount: SpinBox
var _given_tree: Tree
var _internal_tree: Tree

# Offers
var _offers_tree: Tree
var _offer_amount: SpinBox
var _offer_term: OptionButton

# Lending to countries
var _search: LineEdit
var _countries_tree: Tree
var _lend_amount: SpinBox
var _lend_rate: SpinBox
var _lend_term: OptionButton
var _lend_result: Label
var _requests_box: VBoxContainer
var _countries: Array = []
var _updating_selection: bool = false
var _last_selected: PackedInt32Array = []

# Loan to capitalists
var _state_option: OptionButton
var _internal_amount: SpinBox
var _internal_rate_field: SpinBox
var _internal_term: OptionButton
var _internal_policy: OptionButton
var _internal_info: Label
var _states: Array = []


func _ready() -> void:
	setup(Vector2(980, 600), "Центробанк и кредиты")

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(root)

	_summary = Label.new()
	root.add_child(_summary)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)

	_build_bank_tab()
	_build_taken_tab()
	_build_offers_tab()
	_build_given_tab()
	_build_lend_tab()
	_build_internal_tab()

	GameSingleton.gamestate_updated.connect(_refresh)


func open(tab: int = 0) -> void:
	_tabs.current_tab = clampi(tab, 0, _tabs.get_tab_count() - 1)
	open_window()
	_refresh(true)


func toggle() -> void:
	if visible:
		hide()
	else:
		open(_tabs.current_tab)


# ---- Helpers ----


func _tab(tab_name: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = tab_name
	_tabs.add_child(box)
	return box


func _make_tree(parent: Node, columns: PackedStringArray, widths: PackedInt32Array = []) -> Tree:
	var tree := Tree.new()
	tree.columns = columns.size()
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size = Vector2(0, 150)
	for i: int in columns.size():
		tree.set_column_title(i, columns[i])
		tree.set_column_expand(i, i == 0 or widths.is_empty())
		if i < widths.size() and widths[i] > 0:
			tree.set_column_custom_minimum_width(i, widths[i])
	parent.add_child(tree)
	return tree


func _spin(minimum: float, maximum: float, step: float, value: float, suffix: String = "") -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = value
	spin.suffix = suffix
	return spin


func _row(parent: Node, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(190, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)


func _term_option() -> OptionButton:
	var option := OptionButton.new()
	for i: int in _TERM_NAMES.size():
		option.add_item(_TERM_NAMES[i])
	option.tooltip_text = "\n".join(_TERM_TIPS)
	return option


func _money(value: float) -> String:
	return GUINode.float_to_string_dp(value, 0)


func _selected_id(tree: Tree) -> int:
	var item: TreeItem = tree.get_selected()
	return int(item.get_metadata(0)) if item else 0


# ---- Central bank ----


func _build_bank_tab() -> void:
	var tab := _tab("Центробанк")
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = (
		"Процент по кредитам, которые выдаёт государство. Ставка никогда не бывает ниже 1%.\n"
		+ "Внутренний кредит выдаётся капиталистам на стройку заводов и покрытие убытков, внешний — другим странам."
	)
	tab.add_child(info)

	_internal_rate = _spin(1.0, 50.0, 0.5, 5.0, " % в год")
	_external_rate = _spin(1.0, 50.0, 0.5, 4.0, " % в год")
	_row(tab, "Внутренний кредит (капиталистам):", _internal_rate)
	_row(tab, "Внешний кредит (странам):", _external_rate)

	var apply := Button.new()
	apply.text = "Применить ставки"
	apply.pressed.connect(
		func() -> void: PlayerSingleton.set_central_bank_rates(_internal_rate.value / 100.0, _external_rate.value / 100.0)
	)
	tab.add_child(apply)


# ---- Taken loans ----


func _build_taken_tab() -> void:
	var tab := _tab("Взятые кредиты")
	_taken_tree = _make_tree(tab, ["Кредитор", "Взято", "Осталось", "Ставка", "Срок", "Выплачено %"], [0, 90, 90, 70, 90, 100])
	var row := HBoxContainer.new()
	tab.add_child(row)
	_repay_amount = _spin(0.0, 100000000.0, 10.0, 0.0)
	row.add_child(_repay_amount)
	var repay := Button.new()
	repay.text = "Погасить выбранный кредит (сумма, 0 = весь)"
	repay.pressed.connect(
		func() -> void:
			var id: int = _selected_id(_taken_tree)
			if id > 0:
				var amount: float = _repay_amount.value
				if amount <= 0.0:
					amount = 100000000.0
				PlayerSingleton.repay_loan(id, amount)
	)
	row.add_child(repay)


# ---- Offers ----


func _build_offers_tab() -> void:
	var tab := _tab("Взять кредит")
	var info := Label.new()
	info.text = "Предложения стран, у которых есть свободные деньги. Ставка зависит от ваших долгов."
	tab.add_child(info)
	_offers_tree = _make_tree(tab, ["Кредитор", "Макс. сумма", "Ставка"], [0, 120, 90])
	var row := HBoxContainer.new()
	tab.add_child(row)
	_offer_amount = _spin(100.0, 100000.0, 100.0, 1000.0)
	row.add_child(_offer_amount)
	_offer_term = _term_option()
	row.add_child(_offer_term)
	var take := Button.new()
	take.text = "Взять кредит"
	take.pressed.connect(
		func() -> void:
			var lender: int = _selected_id(_offers_tree)
			if lender >= 0 and _offers_tree.get_selected():
				PlayerSingleton.take_external_loan(lender, _offer_amount.value, _offer_term.selected)
	)
	row.add_child(take)


# ---- Given loans ----


func _build_given_tab() -> void:
	var tab := _tab("Выданные кредиты")
	var label := Label.new()
	label.text = "Внешние кредиты, которые вы выдали другим странам"
	tab.add_child(label)
	_given_tree = _make_tree(tab, ["Должник", "Выдано", "Осталось", "Ставка", "Срок", "Получено процентов"], [0, 90, 90, 70, 90, 130])


# ---- Lending to countries ----


func _build_lend_tab() -> void:
	var tab := _tab("Выдать странам")

	_search = LineEdit.new()
	_search.placeholder_text = "Поиск страны..."
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_text: String) -> void: _fill_countries())
	tab.add_child(_search)

	_countries_tree = _make_tree(tab, ["Страна", "Отношения"], [0, 90])
	_countries_tree.select_mode = Tree.SELECT_MULTI
	_countries_tree.multi_selected.connect(_on_country_selected)

	var terms := HBoxContainer.new()
	tab.add_child(terms)
	_lend_amount = _spin(100.0, 100000.0, 100.0, 1000.0)
	_lend_amount.tooltip_text = "Сумма каждой стране"
	terms.add_child(_lend_amount)
	_lend_rate = _spin(1.0, 50.0, 0.5, 4.0, " %")
	_lend_rate.tooltip_text = "Годовая ставка, не меньше 1%"
	terms.add_child(_lend_rate)
	_lend_term = _term_option()
	terms.add_child(_lend_term)

	var groups := HBoxContainer.new()
	tab.add_child(groups)
	for entry: Array in [
		["Всем", _GROUP_ALL, "Предложить кредит всем странам"],
		["Союзникам", _GROUP_ALLIES, "Предложить кредит странам в альянсе с вами"],
		["Друзьям (>100)", _GROUP_FRIENDS, "Предложить кредит странам с отношениями выше 100"],
		["Выбранным", _GROUP_SELECTED, "Предложить кредит странам, выбранным в таблице"],
	]:
		var button := Button.new()
		button.text = entry[0]
		button.tooltip_text = entry[2]
		button.pressed.connect(_on_lend_pressed.bind(entry[1]))
		groups.add_child(button)

	_lend_result = Label.new()
	_lend_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lend_result.text = (
		"Страны решают сами: нуждающиеся принимают кредит, а те, кому вы не нравитесь, могут улучшить отношения "
		+ "или попроситься в альянс."
	)
	tab.add_child(_lend_result)

	var requests_label := Label.new()
	requests_label.text = "Просьбы об альянсе:"
	tab.add_child(requests_label)
	_requests_box = VBoxContainer.new()
	tab.add_child(_requests_box)


func _on_lend_pressed(group: int) -> void:
	PlayerSingleton.give_external_loans(group, _lend_amount.value, _lend_rate.value / 100.0, _lend_term.selected)
	_lend_result.text = "Предложение отправлено. Результат виден в таблице выданных кредитов через день."


func _on_country_selected(item: TreeItem, _column: int, selected: bool) -> void:
	if _updating_selection:
		return
	PlayerSingleton.stage_loan_target(int(item.get_metadata(0)), selected)


func _fill_countries() -> void:
	if _countries.is_empty():
		_countries = PlayerSingleton.get_diplomacy_country_list()

	var query: String = _search.text.strip_edges().to_lower() if _search else ""
	var selected: PackedInt32Array = _overview.get("selected_targets", PackedInt32Array())

	_updating_selection = true
	_countries_tree.clear()
	var root: TreeItem = _countries_tree.create_item()
	for country: Dictionary in _countries:
		var country_name: String = country[&"name"]
		if not query.is_empty() and not country_name.to_lower().contains(query):
			continue
		var item: TreeItem = _countries_tree.create_item(root)
		item.set_text(0, country_name)
		item.set_text(1, str(int(country.get(&"relation", 0))))
		item.set_metadata(0, int(country[&"index"]))
		if selected.has(int(country[&"index"])):
			item.select(0)
	_updating_selection = false


# ---- Internal loans ----


func _build_internal_tab() -> void:
	var tab := _tab("Капиталистам")

	_internal_tree = _make_tree(
		tab, ["Штат", "Выдано", "Осталось", "Не потрачено", "Ставка", "Без выплат до", "Срок"], [0, 80, 80, 100, 60, 110, 90]
	)

	var plate := PanelContainer.new()
	tab.add_child(plate)
	var form := VBoxContainer.new()
	plate.add_child(form)
	var title := Label.new()
	title.text = "Новый кредит капиталистам (не чаще раза в месяц)"
	form.add_child(title)

	_state_option = OptionButton.new()
	_state_option.item_selected.connect(func(_index: int) -> void: _update_internal_info())
	_row(form, "Штат:", _state_option)
	_internal_amount = _spin(100.0, 1000000.0, 100.0, 2000.0)
	_row(form, "Сумма:", _internal_amount)
	_internal_rate_field = _spin(1.0, 50.0, 0.5, 5.0, " % в год")
	_row(form, "Процент:", _internal_rate_field)
	_internal_term = _term_option()
	_row(form, "Срок:", _internal_term)
	_internal_policy = OptionButton.new()
	for policy_name in _POLICY_NAMES:
		_internal_policy.add_item(policy_name)
	_internal_policy.tooltip_text = "\n".join(_POLICY_TIPS)
	_row(form, "По окончании срока:", _internal_policy)

	_internal_info = Label.new()
	_internal_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(_internal_info)

	var give := Button.new()
	give.text = "Выдать кредит"
	give.pressed.connect(
		func() -> void:
			var selected: int = _state_option.selected
			if selected >= 0 and selected < _states.size():
				PlayerSingleton.give_internal_loan(
					int(_states[selected][&"province_index"]), _internal_amount.value, _internal_rate_field.value / 100.0,
					_internal_term.selected, _internal_policy.selected
				)
	)
	form.add_child(give)


func _update_internal_info() -> void:
	var selected: int = _state_option.selected
	if selected < 0 or selected >= _states.size():
		_internal_info.text = "Нет штатов с капиталистами."
		return
	var state: Dictionary = _states[selected]
	_internal_info.text = (
		"Капиталистов: %d. Свободные деньги капиталистов: %s.\n%s\n%s" % [
			state[&"capitalists"], _money(state[&"capitalist_money"]),
			_TERM_TIPS[_internal_term.selected], _POLICY_TIPS[_internal_policy.selected],
		]
	)


# ---- Refresh ----


func _refresh(force: bool = false) -> void:
	if not visible and not force:
		return

	_overview = PlayerSingleton.get_credit_overview()
	if _overview.is_empty():
		return

	var bank: Dictionary = _overview["central_bank"]
	_summary.text = "Казна: %s    Долг: %s (лимит %s)    Проценты в месяц: %s" % [
		_money(_overview["cash"]), _money(_overview["total_debt"]), _money(_overview["debt_limit"]),
		_money(_overview["monthly_interest"]),
	]

	# The rate fields show the real rates until the player edits them
	if not _internal_rate.get_line_edit().has_focus() and not _external_rate.get_line_edit().has_focus():
		_internal_rate.set_value_no_signal(snappedf(float(bank["internal_rate"]) * 100.0, 0.5))
		_external_rate.set_value_no_signal(snappedf(float(bank["external_rate"]) * 100.0, 0.5))

	_fill_loans(_taken_tree, _overview["external_taken"], false)
	_fill_loans(_given_tree, _overview["external_given"], false)
	_fill_loans(_internal_tree, _overview["internal_given"], true)

	# Offers
	var previous_offer: int = _selected_id(_offers_tree) if _offers_tree.get_selected() else -1
	_offers_tree.clear()
	var offers_root: TreeItem = _offers_tree.create_item()
	for offer: Dictionary in _overview["offers"]:
		var item: TreeItem = _offers_tree.create_item(offers_root)
		item.set_text(0, offer["lender_name"])
		item.set_text(1, _money(offer["max_amount"]))
		item.set_text(2, "%.1f %%" % (float(offer["rate"]) * 100.0))
		item.set_metadata(0, int(offer["lender_index"]))
		if int(offer["lender_index"]) == previous_offer:
			item.select(0)

	# The table of countries is only rebuilt when the chosen countries changed elsewhere
	var selected: PackedInt32Array = _overview["selected_targets"]
	if force or selected != _last_selected:
		_last_selected = selected
		_fill_countries()

	# Requests for an alliance
	for child: Node in _requests_box.get_children():
		_requests_box.remove_child(child)
		child.queue_free()
	for request: Dictionary in _overview["alliance_requests"]:
		var row := HBoxContainer.new()
		_requests_box.add_child(row)
		var label := Label.new()
		label.text = "%s просит союза (%s)" % [request["from_name"], request["date"]]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var accept := Button.new()
		accept.text = "Принять"
		accept.pressed.connect(func() -> void: PlayerSingleton.answer_alliance_request(int(request["from_index"]), true))
		row.add_child(accept)
		var decline := Button.new()
		decline.text = "Отказать"
		decline.pressed.connect(func() -> void: PlayerSingleton.answer_alliance_request(int(request["from_index"]), false))
		row.add_child(decline)

	# States for the loans to the capitalists
	var previous_state: int = -1
	if _state_option.selected >= 0 and _state_option.selected < _states.size():
		previous_state = int(_states[_state_option.selected][&"province_index"])
	_states = _overview["states"]
	_state_option.clear()
	var restore: int = 0
	for i: int in _states.size():
		var state: Dictionary = _states[i]
		_state_option.add_item("%s (капиталисты: %s)" % [
			GUINode.format_province_name(state[&"province_identifier"]), _money(state[&"capitalist_money"]),
		])
		if int(state[&"province_index"]) == previous_state:
			restore = i
	if not _states.is_empty():
		_state_option.select(restore)
	_update_internal_info()


func _fill_loans(tree: Tree, loans: Array, internal: bool) -> void:
	var previous: int = _selected_id(tree) if tree.get_selected() else 0
	tree.clear()
	var root: TreeItem = tree.create_item()
	for loan: Dictionary in loans:
		var item: TreeItem = tree.create_item(root)
		var principal: float = loan["principal"]
		var remaining: float = loan["remaining"]
		if internal:
			item.set_text(0, GUINode.format_province_name(loan["province_identifier"]))
			item.set_text(1, _money(principal))
			item.set_text(2, _money(remaining))
			item.set_text(3, _money(loan["unspent"]))
			item.set_text(4, "%.1f %%" % (float(loan["rate"]) * 100.0))
			item.set_text(5, loan["grace_end"])
			item.set_text(6, loan["due"])
		else:
			item.set_text(0, loan["other_name"])
			item.set_text(1, _money(principal))
			item.set_text(2, _money(remaining))
			item.set_text(3, "%.1f %%" % (float(loan["rate"]) * 100.0))
			item.set_text(4, loan["due"])
			item.set_text(5, "%d %%" % roundi((1.0 - remaining / maxf(principal, 0.01)) * 100.0) if tree == _taken_tree else _money(loan["interest_paid"]))
		item.set_metadata(0, int(loan["id"]))
		if int(loan["id"]) == previous:
			item.select(0)
