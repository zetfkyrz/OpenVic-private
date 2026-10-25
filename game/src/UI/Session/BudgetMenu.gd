extends GUINode

const SCREEN := NationManagement.Screen.BUDGET

var _active: bool = false
var _incVal: int = 0 # incremental value to see the UI update, replace later by real values
#
# debt
var _national_bank_label: GUILabel
var _debt_val_label: GUILabel
var _interest_val_label: GUILabel
#
# costs
var _overseas_cost_val_label: GUILabel
var _ind_sub_val_label: GUILabel
# Which subsidised factories the state pays the losses of: all / state owned / by the share of ownership
var _subsidy_mode_button: Button
var _subsidy_dialog: Control
var _subsidy_mode: int = 0
const _Vic2WindowScript: GDScript = preload("res://src/UI/Session/Vic2Window.gd")
const _SubsidyDialog: GDScript = preload("res://src/UI/Session/SubsidyModeDialog.gd")
const _CreditPanel: GDScript = preload("res://src/UI/Session/CreditPanel.gd")
var _credit_panel: Control
# List of the credits of the original budget window: the credits the country took / gave, with the sorting buttons
var _debt_listbox: GUIListBox
var _showing_taken: bool = true
var _sort_loans_by_country: bool = false
var _selected_loan_id: int = 0
var _listed_loans: Array = []
const _TAB_MAIN: int = 0
const _TAB_TAKE: int = 3
const _SUBSIDY_MODE_NAMES: PackedStringArray = [
	"Субсидировать все", "По доле владения", "Антикризисные субсидии", "Жёсткий антикризисный",
]
const _SUBSIDY_MODE_TIPS: PackedStringArray = [
	"Государство полностью оплачивает убытки всех отмеченных предприятий, капиталисты не платят.",
	"Государство платит долю убытков, равную его доле владения, остальное покрывают капиталисты.",
	"Как «по доле владения», пока у капиталистов есть деньги; когда их деньги заканчиваются, государство платит и их часть.",
	"Как антикризисные, но государство каждый месяц забирает долю завода за деньги, заплаченные вместо капиталистов.",
]
var _lower_class_chart: GUIPieChart
var _middle_class_chart: GUIPieChart
var _upper_class_chart: GUIPieChart
var _debt_chart: GUIPieChart


# TODO - testing function, should be replaced with calls to SIM which trigger UI updates through
# gamestate_updated
#	slider.set_tooltip_string("%s: §Y%s%%" % [tr(tooltip), GUINode.float_to_string_dp(value, 1)])


func _ready() -> void:
	GameSingleton.gamestate_updated.connect(_update_info)

	Events.NationManagementScreens.update_active_nation_management_screen.connect(_on_update_active_nation_management_screen)

	add_gui_element("country_budget", "country_budget")
	MenuSingleton.link_budget_menu_to_cpp(self)

	set_click_mask_from_nodepaths([^"./country_budget/main_bg"])

	var close_button: GUIIconButton = get_gui_icon_button_from_nodepath(^"./country_budget/close_button")
	if close_button:
		close_button.pressed.connect(Events.NationManagementScreens.close_nation_management_screen.bind(SCREEN))

	# labels
	# debt
	_national_bank_label = get_gui_label_from_nodepath(^"./country_budget/national_bank_val")
	_debt_val_label = get_gui_label_from_nodepath(^"./country_budget/debt_val")
	_interest_val_label = get_gui_label_from_nodepath(^"./country_budget/interest_val")
	# costs
	_ind_sub_val_label = get_gui_label_from_nodepath(^"./country_budget/ind_sub_val")

	# Choice of the subsidised factories, below the industrial subsidies label
	var budget_window: Node = get_node_or_null(^"./country_budget")
	if budget_window:
		# Between the text and the value of the industrial subsidies, opens the Victoria 2 style choice
		_subsidy_mode_button = Button.new()
		_subsidy_mode_button.text = "Субсидии"
		# The look of the buttons of the other Victoria 2 style windows
		var themer := Control.new()
		themer.set_script(_Vic2WindowScript)
		_subsidy_mode_button.theme = themer.create_theme()
		themer.free()
		_subsidy_mode_button.add_theme_font_size_override(&"font_size", 13)
		_subsidy_mode_button.position = Vector2(784, 46)
		_subsidy_mode_button.size = Vector2(116, 21)
		_subsidy_mode_button.pressed.connect(
			func() -> void: _subsidy_dialog.open(_subsidy_mode)
		)
		budget_window.add_child(_subsidy_mode_button)

	_subsidy_dialog = Control.new()
	_subsidy_dialog.set_script(_SubsidyDialog)
	_subsidy_dialog.mode_chosen.connect(
		func(mode: int) -> void:
			_subsidy_mode = mode
			PlayerSingleton.set_subsidy_mode(mode)
	)
	add_child(_subsidy_dialog)

	_credit_panel = Control.new()
	_credit_panel.set_script(_CreditPanel)
	add_child(_credit_panel)

	_debt_listbox = GUINode.get_gui_listbox_from_node(get_node_or_null(^"./country_budget/debt_listbox"))

	# debt buttons
	var _tab_takenloans_button: GUIIconButton = get_gui_icon_button_from_nodepath(^"./country_budget/tab_takenloans")
	if _tab_takenloans_button:
		_tab_takenloans_button.pressed.connect(_switch_loans_tab.bind(true))
	var _tab_givenloans_button: GUIIconButton = get_gui_icon_button_from_nodepath(^"./country_budget/tab_givenloans")
	if _tab_givenloans_button:
		_tab_givenloans_button.pressed.connect(_switch_loans_tab.bind(false))
	var _debt_sort_country_button: GUIIconButton = get_gui_icon_button_from_nodepath(^"./country_budget/debt_sort_country")
	if _debt_sort_country_button:
		_debt_sort_country_button.pressed.connect(_sort_loans.bind(true))
	var _debt_sort_amount_button: GUIIconButton = get_gui_icon_button_from_nodepath(^"./country_budget/debt_sort_amount")
	if _debt_sort_amount_button:
		_debt_sort_amount_button.pressed.connect(_sort_loans.bind(false))
	var _take_loan_button: GUIIconButton = get_gui_icon_button_from_nodepath(^"./country_budget/take_loan")
	if _take_loan_button:
		_take_loan_button.pressed.connect(_take_loan)
	var _repay_loan_button: GUIIconButton = get_gui_icon_button_from_nodepath(^"./country_budget/repay_loan")
	if _repay_loan_button:
		_repay_loan_button.pressed.connect(_repay_loan)

	# charts
	_lower_class_chart = get_gui_pie_chart_from_nodepath(^"./country_budget/chart_0")
	_middle_class_chart = get_gui_pie_chart_from_nodepath(^"./country_budget/chart_1")
	_upper_class_chart = get_gui_pie_chart_from_nodepath(^"./country_budget/chart_2")
	_debt_chart = get_gui_pie_chart_from_nodepath(^"./country_budget/chart_debt")

	# TODO - generate strata pop type icons

	_update_info()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED:
			_update_info()
		NOTIFICATION_PREDELETE:
			# If the C++ BudgetMenu isn't freed before the destruction of this GUINode, then its
			# update method, triggered by
			# gamestate updates, could be called after all the child UI nodes they refer to have
			# been freed,
			# meaning the C++ BudgetMenu would be dereferencing invalid pointers.
			MenuSingleton.unlink_budget_menu_from_cpp()


func _on_update_active_nation_management_screen(active_screen: NationManagement.Screen) -> void:
	_active = active_screen == SCREEN
	_update_info()


func _update_info() -> void:
	# TODO - remove _incVal and link the true data with the UI
	_incVal += 1

	if _active:
		# Real data of the credit system (central bank, debts and interest of the country)
		var credit: Dictionary = PlayerSingleton.get_credit_overview()
		if _national_bank_label:
			_national_bank_label.text = "%s¤" % GUINode.float_to_string_suffixed(credit.get("cash", 0.0))

		if _debt_val_label:
			_debt_val_label.text = "%s¤" % GUINode.float_to_string_dp(credit.get("total_debt", 0.0), 1)

		if _interest_val_label:
			_interest_val_label.text = "%s¤" % GUINode.float_to_string_dp(credit.get("monthly_payments", 0.0), 2)

		_update_loans(credit)

		var subsidies: Dictionary = PlayerSingleton.get_subsidy_info()
		if _ind_sub_val_label:
			_ind_sub_val_label.text = "%s¤" % GUINode.float_to_string_dp(subsidies.get("state_paid", 0.0), 1)
		if _subsidy_mode_button and not subsidies.is_empty():
			_subsidy_mode = subsidies["mode"]
			_subsidy_mode_button.tooltip_text = "%s
%s

Государство заплатило вчера: %s
Капиталисты заплатили вчера: %s" % [
				_SUBSIDY_MODE_NAMES[_subsidy_mode], _SUBSIDY_MODE_TIPS[_subsidy_mode],
				GUINode.float_to_string_dp(subsidies["state_paid"], 1),
				GUINode.float_to_string_dp(subsidies["capitalists_paid"], 1),
			]

		# TODO - set strata tax and debt charts
		# TODO - update loans taken/given list and enable/disable take/give loan buttons

		show()
	else:
		hide()


func _open_credit_panel(tab: int) -> void:
	if _credit_panel:
		_credit_panel.open(tab)


func _switch_loans_tab(taken_loans: bool) -> void:
	_showing_taken = taken_loans
	_selected_loan_id = 0
	_update_info()


func _sort_loans(sort_by_country: bool) -> void:
	_sort_loans_by_country = sort_by_country
	_update_info()


# The take button opens the window with the credits that can be taken (and the ones to issue)
func _take_loan() -> void:
	_open_credit_panel(_TAB_TAKE)


# The repay button pays back the selected credit that the country took, without a selection it opens the credits
func _repay_loan() -> void:
	for loan: Dictionary in _listed_loans:
		if int(loan[&"id"]) == _selected_loan_id and loan[&"direction"] == "taken":
			PlayerSingleton.repay_loan(_selected_loan_id, float(loan[&"remaining"]))
			return
	_open_credit_panel(_TAB_MAIN)


# Fills the list of the credits taken / given by the country, one row (who, amount) per credit
func _update_loans(credit: Dictionary) -> void:
	if _debt_listbox == null:
		return

	_listed_loans.clear()
	var all: Array = []
	all.append_array(credit.get("internal", []))
	all.append_array(credit.get("external", []))
	for loan: Dictionary in all:
		# Only credits in force: offers nobody took yet are managed in the credits window
		if int(loan.get("status", 0)) != 1:
			continue
		var taken: bool = loan.get("direction", "") == "taken"
		if taken != _showing_taken:
			continue
		var who: String = loan.get("country_name", "")
		if who.is_empty():
			who = tr("Capitalists")
		_listed_loans.append({
			&"id": loan["id"], &"who": who, &"remaining": loan.get("remaining", 0.0), &"direction": loan.get("direction", ""),
		})

	if _sort_loans_by_country:
		_listed_loans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a[&"who"]) < String(b[&"who"]))
	else:
		_listed_loans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a[&"remaining"]) > float(b[&"remaining"]))

	_debt_listbox.clear_children(_listed_loans.size())
	for loan: Dictionary in _listed_loans:
		var entry: Panel = GUINode.generate_gui_element("country_budget", "debt_listitem")
		if entry == null:
			break
		_debt_listbox.add_child(entry)
		var who_label: GUILabel = GUINode.get_gui_label_from_node_and_path(entry, ^"./who")
		if who_label:
			who_label.set_text(loan[&"who"])
		var debt_label: GUILabel = GUINode.get_gui_label_from_node_and_path(entry, ^"./debt")
		if debt_label:
			debt_label.set_text("%s¤" % GUINode.float_to_string_dp(loan[&"remaining"], 1))
		# A click selects the credit (for the repay button), the selected one is highlighted
		var loan_id: int = int(loan[&"id"])
		entry.mouse_filter = Control.MOUSE_FILTER_STOP
		entry.modulate = Color(1.3, 1.15, 0.8) if loan_id == _selected_loan_id else Color.WHITE
		entry.gui_input.connect(
			func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_selected_loan_id = loan_id
					_update_info()
		)
