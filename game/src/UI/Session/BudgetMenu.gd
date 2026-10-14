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
const _SubsidyDialog: GDScript = preload("res://src/UI/Session/SubsidyModeDialog.gd")
const _CreditPanel: GDScript = preload("res://src/UI/Session/CreditPanel.gd")
var _credit_panel: Control
const _SUBSIDY_MODE_NAMES: PackedStringArray = [
	"Субсидировать все предприятия", "Только государственные", "По доле владения",
]
const _SUBSIDY_MODE_TIPS: PackedStringArray = [
	"Государство покрывает убытки всех субсидируемых заводов полностью, капиталисты не платят.",
	"Заводы, целиком принадлежащие государству, государство субсидирует полностью, остальные считаются по доле владения.",
	"Государство платит долю убытков, равную его доле владения, остальное покрывают капиталисты.",
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
		_subsidy_mode_button.text = "▼"
		_subsidy_mode_button.position = Vector2(850, 52)
		_subsidy_mode_button.size = Vector2(42, 22)
		_subsidy_mode_button.pressed.connect(
			func() -> void: _subsidy_dialog.open(_subsidy_mode)
		)
		budget_window.add_child(_subsidy_mode_button)

		# Central bank and credit
		var bank_button := Button.new()
		bank_button.text = "Центробанк и кредиты"
		bank_button.position = Vector2(572, 112)
		bank_button.size = Vector2(250, 24)
		bank_button.pressed.connect(func() -> void: _open_credit_panel(0))
		budget_window.add_child(bank_button)

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
			_interest_val_label.text = "%s¤" % GUINode.float_to_string_dp(credit.get("monthly_interest", 0.0), 2)

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
	_open_credit_panel(1 if taken_loans else 3)
	# TODO - code the necessary logic
	#if taken_loans:
	#else: # given loans
	pass


func _sort_loans(sort_by_country: bool) -> void:
	# TODO - code the necessary logic
	#if sort_by_country:
	#else: # sort by amount
	pass


func _take_loan() -> void:
	_open_credit_panel(2)


func _repay_loan() -> void:
	_open_credit_panel(1)
