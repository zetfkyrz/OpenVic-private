extends "res://src/UI/Session/Vic2Window.gd"
## Credits window with four tabs (docs/CREDITS.md): tr("CREDIT_TAB_MAIN") (tables of internal and external credits), tr("CREDIT_TAB_ISSUE_INTERNAL"),
## tr("CREDIT_TAB_ISSUE_EXTERNAL"), tr("CREDIT_TAB_TAKE"). All the data come from PlayerSingleton.get_credit_overview() and
## PlayerSingleton.get_available_credit_offers(), all the commands are PlayerSingleton methods (see PlayerSingleton.hpp).
## A Victoria 2 style window (frame, close button, dragging), opened from the budget screen.

const _TERM_SHORT: int = 0
const _TERM_MEDIUM: int = 1
const _TERM_LONG: int = 2

var _overview: Dictionary = {}
var _terms: Array = []

var _tabs: TabContainer
var _summary: Label

# Tab 1: main
var _internal_tree: Tree
var _external_tree: Tree
var _repay_amount: SpinBox
var _main_buttons: HBoxContainer

# Tab 2: internal credit
var _regions_tree: Tree
var _all_regions: CheckBox
var _internal_amount: SpinBox
var _internal_rate: SpinBox
var _internal_term: OptionButton
var _internal_info: Label
var _updating_regions: bool = false

# Tab 3: external credit
var _search: LineEdit
var _countries_tree: Tree
var _all_countries: CheckBox
var _external_amount: SpinBox
var _external_rate: SpinBox
var _external_term: OptionButton
var _external_info: Label
var _countries: Array = []
var _updating_countries: bool = false
var _last_staged_countries: PackedInt32Array = []

# Tab 4: take a credit
var _offers_tree: Tree


func _ready() -> void:
	setup(Vector2(980, 600), tr("CREDIT_TITLE"))

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(root)

	_summary = Label.new()
	root.add_child(_summary)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)

	_build_main_tab()
	_build_internal_tab()
	_build_external_tab()
	_build_take_tab()

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


func _money(value: float) -> String:
	return GUINode.float_to_string_dp(value, 0)


func _percent(value: float) -> String:
	return "%.2f %%" % (value * 100.0)


func _years(days: int) -> String:
	return ("%.1f" % (float(days) / 365.0)).trim_suffix(".0")


func _term_text(term: int) -> String:
	for entry: Dictionary in _terms:
		if int(entry["term"]) == term:
			var text: String = tr("CREDIT_TERM_TEXT") % [_years(int(entry["term_days"])), _years(int(entry["delay_days"]))]
			if int(entry["short_max_construction_days"]) > 0:
				text += tr("CREDIT_TERM_SHORT_LIMIT") % int(entry["short_max_construction_days"])
			return text
	return ""


func _term_option() -> OptionButton:
	var option := OptionButton.new()
	option.add_item(tr("CREDIT_SHORT"))
	option.add_item(tr("CREDIT_MEDIUM"))
	option.add_item(tr("CREDIT_LONG"))
	return option


func _term_name(term: int) -> String:
	match term:
		_TERM_SHORT:
			return tr("CREDIT_SHORT")
		_TERM_MEDIUM:
			return tr("CREDIT_MEDIUM")
	return tr("CREDIT_LONG")


func _selected_id(tree: Tree) -> int:
	var item: TreeItem = tree.get_selected()
	return int(item.get_metadata(0)) if item else 0


func _delay_text(credit: Dictionary) -> String:
	var days: int = int(credit["delay_left_days"])
	if int(credit["status"]) == 0:
		return tr("CREDIT_NOT_TAKEN")
	if days <= 0:
		return tr("CREDIT_PAYING")
	return "%d %s" % [days, tr("CREDIT_DAYS_SUFFIX")]


# ---- Tab 1: main ----


func _build_main_tab() -> void:
	var tab := _tab(tr("CREDIT_TAB_MAIN"))

	var internal_label := Label.new()
	internal_label.text = tr("CREDIT_INTERNAL_HEADER")
	tab.add_child(internal_label)
	_internal_tree = _make_tree(
		tab, [tr("CREDIT_COL_AMOUNT"), tr("CREDIT_COL_ISSUED"), tr("CREDIT_COL_TAKEN"), tr("CREDIT_COL_RATE"), tr("CREDIT_COL_PAID"), tr("CREDIT_COL_DELAY"), tr("CREDIT_COL_REGIONS")],
		[90, 100, 100, 80, 90, 120, 0]
	)

	var external_label := Label.new()
	external_label.text = tr("CREDIT_EXTERNAL_HEADER")
	tab.add_child(external_label)
	_external_tree = _make_tree(
		tab, [tr("CREDIT_COL_TAG"), tr("CREDIT_COL_AMOUNT"), tr("CREDIT_COL_ISSUED"), tr("CREDIT_COL_TAKEN"), tr("CREDIT_COL_RATE"), tr("CREDIT_COL_PAID"), tr("CREDIT_COL_DELAY"), tr("CREDIT_COL_WHO")],
		[60, 90, 100, 100, 80, 90, 120, 0]
	)

	_main_buttons = HBoxContainer.new()
	tab.add_child(_main_buttons)
	_repay_amount = _spin(0.0, 100000000.0, 10.0, 0.0)
	_repay_amount.tooltip_text = tr("CREDIT_REPAY_TIP")
	_main_buttons.add_child(_repay_amount)
	var repay := Button.new()
	repay.text = tr("CREDIT_REPAY_BUTTON")
	repay.pressed.connect(
		func() -> void:
			var id: int = _selected_id(_external_tree)
			if id > 0:
				var amount: float = _repay_amount.value
				if amount <= 0.0:
					amount = 100000000.0
				PlayerSingleton.repay_loan(id, amount)
	)
	_main_buttons.add_child(repay)
	var withdraw := Button.new()
	withdraw.text = tr("CREDIT_WITHDRAW_BUTTON")
	withdraw.pressed.connect(
		func() -> void:
			var id: int = _selected_id(_external_tree)
			if id <= 0:
				id = _selected_id(_internal_tree)
			if id > 0:
				PlayerSingleton.withdraw_credit_offer(id)
	)
	_main_buttons.add_child(withdraw)


# ---- Tab 2: issue an internal credit ----


func _build_internal_tab() -> void:
	var tab := _tab(tr("CREDIT_TAB_ISSUE_INTERNAL"))

	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = tr("CREDIT_INTERNAL_INFO")
	tab.add_child(info)

	_all_regions = CheckBox.new()
	_all_regions.text = tr("CREDIT_ALL_REGIONS")
	_all_regions.button_pressed = true
	tab.add_child(_all_regions)

	_regions_tree = _make_tree(tab, [tr("CREDIT_COL_REGION"), tr("CREDIT_COL_CAPITALISTS"), tr("CREDIT_COL_CAPITALIST_MONEY")], [0, 110, 110])
	_regions_tree.select_mode = Tree.SELECT_MULTI
	_regions_tree.multi_selected.connect(_on_region_selected)

	_internal_amount = _spin(100.0, 100000000.0, 100.0, 2000.0)
	_row(tab, tr("CREDIT_AMOUNT"), _internal_amount)
	_internal_rate = _spin(0.1, 100.0, 0.1, 5.0, tr("CREDIT_PER_YEAR"))
	_row(tab, tr("CREDIT_RATE_ONCE"), _internal_rate)
	_internal_term = _term_option()
	_internal_term.item_selected.connect(func(_index: int) -> void: _update_info())
	_row(tab, tr("CREDIT_TYPE"), _internal_term)

	_internal_info = Label.new()
	_internal_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(_internal_info)

	var give := Button.new()
	give.text = tr("CREDIT_ISSUE_BUTTON")
	give.pressed.connect(
		func() -> void:
			PlayerSingleton.offer_internal_credit(
				_internal_amount.value, _internal_rate.value / 100.0, _internal_term.selected, _all_regions.button_pressed
			)
	)
	tab.add_child(give)


func _on_region_selected(item: TreeItem, _column: int, selected: bool) -> void:
	if _updating_regions:
		return
	PlayerSingleton.stage_credit_region(int(item.get_metadata(0)), selected)


# ---- Tab 3: issue an external credit ----


func _build_external_tab() -> void:
	var tab := _tab(tr("CREDIT_TAB_ISSUE_EXTERNAL"))

	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = tr("CREDIT_EXTERNAL_INFO")
	tab.add_child(info)

	_all_countries = CheckBox.new()
	_all_countries.text = tr("CREDIT_ALL_COUNTRIES")
	_all_countries.button_pressed = true
	tab.add_child(_all_countries)

	_search = LineEdit.new()
	_search.placeholder_text = tr("CREDIT_SEARCH")
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_text: String) -> void: _fill_countries())
	tab.add_child(_search)

	_countries_tree = _make_tree(tab, [tr("CREDIT_COL_COUNTRY"), tr("CREDIT_COL_RELATIONS")], [0, 90])
	_countries_tree.select_mode = Tree.SELECT_MULTI
	_countries_tree.multi_selected.connect(_on_country_selected)

	_external_amount = _spin(100.0, 100000000.0, 100.0, 1000.0)
	_row(tab, tr("CREDIT_AMOUNT"), _external_amount)
	_external_rate = _spin(0.1, 100.0, 0.1, 4.0, tr("CREDIT_PER_YEAR"))
	_row(tab, tr("CREDIT_RATE_ONCE"), _external_rate)
	_external_term = _term_option()
	_external_term.item_selected.connect(func(_index: int) -> void: _update_info())
	_row(tab, tr("CREDIT_TYPE"), _external_term)

	_external_info = Label.new()
	_external_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(_external_info)

	var give := Button.new()
	give.text = tr("CREDIT_ISSUE_BUTTON")
	give.pressed.connect(
		func() -> void:
			PlayerSingleton.offer_external_credit(
				_external_amount.value, _external_rate.value / 100.0, _external_term.selected, _all_countries.button_pressed
			)
	)
	tab.add_child(give)


func _on_country_selected(item: TreeItem, _column: int, selected: bool) -> void:
	if _updating_countries:
		return
	PlayerSingleton.stage_credit_country(int(item.get_metadata(0)), selected)


func _fill_countries() -> void:
	if _countries.is_empty():
		_countries = PlayerSingleton.get_diplomacy_country_list()

	var query: String = _search.text.strip_edges().to_lower() if _search else ""
	var staged: PackedInt32Array = _overview.get("staged_countries", PackedInt32Array())

	_updating_countries = true
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
		if staged.has(int(country[&"index"])):
			item.select(0)
	_updating_countries = false


# ---- Tab 4: take a credit ----


func _build_take_tab() -> void:
	var tab := _tab(tr("CREDIT_TAB_TAKE"))
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = tr("CREDIT_TAKE_INFO")
	tab.add_child(info)
	_offers_tree = _make_tree(tab, [tr("CREDIT_COL_AMOUNT"), tr("CREDIT_COL_TAG"), tr("CREDIT_COL_LENDER"), tr("CREDIT_COL_TYPE"), tr("CREDIT_COL_RATE")], [100, 70, 0, 130, 90])
	var take := Button.new()
	take.text = tr("CREDIT_TAKE_BUTTON")
	take.pressed.connect(
		func() -> void:
			var id: int = _selected_id(_offers_tree)
			if id > 0:
				PlayerSingleton.take_credit(id)
	)
	tab.add_child(take)


# ---- Refresh ----


func _update_info() -> void:
	_internal_info.text = _term_text(_internal_term.selected)
	_external_info.text = _term_text(_external_term.selected)


func _refresh(force: bool = false) -> void:
	if not visible and not force:
		return

	_overview = PlayerSingleton.get_credit_overview()
	if _overview.is_empty():
		return
	_terms = _overview["terms"]

	_summary.text = tr("CREDIT_SUMMARY") % [
		_money(_overview["cash"]), _money(_overview["total_debt"]), _money(_overview["debt_limit"]),
		_money(_overview["monthly_payments"]), _percent(_overview["rate_min"]), _percent(_overview["rate_max"]),
	]
	_update_info()

	_fill_internal_table()
	_fill_external_table()
	_fill_regions()

	var staged: PackedInt32Array = _overview["staged_countries"]
	if force or staged != _last_staged_countries:
		_last_staged_countries = staged
		_fill_countries()

	_fill_offers()


func _fill_internal_table() -> void:
	var previous: int = _selected_id(_internal_tree) if _internal_tree.get_selected() else 0
	_internal_tree.clear()
	var root: TreeItem = _internal_tree.create_item()
	for credit: Dictionary in _overview["internal"]:
		var item: TreeItem = _internal_tree.create_item(root)
		item.set_text(0, _money(credit["amount"]))
		item.set_text(1, credit["issue_date"])
		item.set_text(2, credit["taken_date"] if int(credit["status"]) == 1 else "—")
		item.set_text(3, _percent(credit["rate"]))
		item.set_text(4, _money(credit["paid"]))
		item.set_text(5, _delay_text(credit))
		var regions: PackedStringArray = credit["regions"]
		var names: PackedStringArray = []
		for identifier: String in regions:
			names.append(GUINode.format_province_name(identifier))
		item.set_text(6, tr("CREDIT_WHOLE_COUNTRY") if names.is_empty() else ", ".join(names))
		item.set_metadata(0, int(credit["id"]))
		if int(credit["id"]) == previous:
			item.select(0)


func _fill_external_table() -> void:
	var previous: int = _selected_id(_external_tree) if _external_tree.get_selected() else 0
	_external_tree.clear()
	var root: TreeItem = _external_tree.create_item()
	for credit: Dictionary in _overview["external"]:
		var item: TreeItem = _external_tree.create_item(root)
		var direction: String = credit["direction"]
		item.set_text(0, credit["country_tag"] if not String(credit["country_tag"]).is_empty() else "—")
		item.set_text(1, _money(credit["amount"]))
		item.set_text(2, credit["issue_date"])
		item.set_text(3, credit["taken_date"] if int(credit["status"]) == 1 else "—")
		item.set_text(4, _percent(credit["rate"]))
		item.set_text(5, _money(credit["paid"]))
		item.set_text(6, _delay_text(credit))
		var who: String = credit["country_name"]
		match direction:
			"given":
				who = tr("CREDIT_GIVEN_TO") + who
			"taken":
				who = tr("CREDIT_TAKEN_FROM") + who
			_:
				var targets: PackedStringArray = credit["targets"]
				who = tr("CREDIT_OFFERED_TO") + (tr("CREDIT_EVERYBODY") if targets.is_empty() else ", ".join(targets))
		item.set_text(7, who)
		item.set_metadata(0, int(credit["id"]))
		if int(credit["id"]) == previous:
			item.select(0)


func _fill_regions() -> void:
	var regions: Array = _overview["regions"]
	_updating_regions = true
	_regions_tree.clear()
	var root: TreeItem = _regions_tree.create_item()
	for region: Dictionary in regions:
		var item: TreeItem = _regions_tree.create_item(root)
		item.set_text(0, GUINode.format_province_name(region[&"province_identifier"]))
		item.set_text(1, str(int(region[&"capitalists"])))
		item.set_text(2, _money(region[&"capitalist_money"]))
		item.set_metadata(0, int(region[&"province_index"]))
		if bool(region[&"staged"]):
			item.select(0)
	_updating_regions = false


func _fill_offers() -> void:
	var previous: int = _selected_id(_offers_tree) if _offers_tree.get_selected() else 0
	_offers_tree.clear()
	var root: TreeItem = _offers_tree.create_item()
	for offer: Dictionary in PlayerSingleton.get_available_credit_offers():
		var item: TreeItem = _offers_tree.create_item(root)
		item.set_text(0, _money(offer["amount"]))
		item.set_text(1, offer["lender_tag"])
		item.set_text(2, offer["lender_name"])
		item.set_text(3, tr("CREDIT_TERM_TYPE_YEARS") % [_term_name(int(offer["term"])), _years(int(offer["term_days"]))])
		item.set_text(4, _percent(offer["rate"]))
		item.set_metadata(0, int(offer["id"]))
		if int(offer["id"]) == previous:
			item.select(0)
