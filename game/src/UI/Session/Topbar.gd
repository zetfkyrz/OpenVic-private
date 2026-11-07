extends GUINode

enum CountryStatus {
	GREAT_POWER,
	SECONDARY_POWER,
	CIVILISED,
	PARTIALLY_CIVILISED,
	UNCIVILISED,
	PRIMITIVE,
}

# Country info
var _country_flag_button: GUIMaskedFlagButton
#
# Time controls
var _speed_up_button: GUIIconButton
var _speed_down_button: GUIIconButton
var _pause_bg_button: GUIButton
var _speed_indicator_button: GUIIconButton
var _date_label: GUILabel
#
# NationManagement.Screen-GUIIconButton
var _nation_management_buttons: Dictionary
#
# Production
var _production_top_goods_icons: Array[GUIIcon]
var _production_alert_building_icon: GUIIcon
var _production_alert_closed_icon: GUIIcon
var _production_alert_unemployment_icon: GUIIcon
#
# Technology
var _technology_progress_bar: GUIProgressBar
var _technology_current_research_label: GUILabel
var _technology_literacy_label: GUILabel
var _technology_research_points_label: GUILabel
#
# Politics
var _politics_party_icon: GUIIcon
var _politics_party_label: GUILabel
var _politics_suppression_points_label: GUILabel
var _politics_infamy_label: GUILabel
var _politics_reforms_button: GUIButton
var _politics_decisions_button: GUIIconButton
var _politics_election_icon: GUIIcon
var _politics_rebels_button: GUIIconButton
#
# Population
var _population_total_size_label: GUILabel
var _population_national_foci_label: GUILabel
var _population_militancy_label: GUILabel
var _population_consciousness_label: GUILabel
#
# Trade
var _trade_imported_icons: Array[GUIIcon]
var _trade_exported_icons: Array[GUIIcon]
#
# Diplomacy
var _diplomacy_peace_label: GUILabel
var _diplomacy_war_enemies_overlapping_elements_box: GUIOverlappingElementsBox
var _diplomacy_diplomatic_points_label: GUILabel
var _diplomacy_alert_colony_button: GUIIconButton
var _diplomacy_alert_crisis_icon: GUIIcon
var _diplomacy_alert_sphere_icon: GUIIcon
var _diplomacy_alert_great_power_icon: GUIIcon
#
# Military
var _military_army_size_label: GUILabel
var _military_navy_size_label: GUILabel
var _military_mobilisation_size_label: GUILabel
const _MobilisationText = preload("res://src/UI/Session/MobilisationText.gd")
var _mobilisation_info: Dictionary = {}
var _mobilisation_dialog: ConfirmationDialog
var _military_leadership_points_label: GUILabel


func _ready() -> void:
	GameSingleton.gamestate_updated.connect(_update_info)

	add_gui_element("topbar", "topbar")
	MenuSingleton.link_top_bar_to_cpp(self)

	hide_nodes([
		^"./topbar/topbar_outlinerbutton_bg",
		^"./topbar/topbar_outlinerbutton",
	])

	set_click_mask_from_nodepaths([^"./topbar/topbar_bg", ^"./topbar/topbar_paper"])

	# Country info
	_country_flag_button = get_gui_masked_flag_button_from_nodepath(^"./topbar/player_flag")
	if _country_flag_button:
		_country_flag_button.pressed.connect(
			func() -> void:
				# TODO - open the diplomacy menu on the Wars tab
				Events.NationManagementScreens.open_nation_management_screen(NationManagement.Screen.DIPLOMACY)
		)

	# Time controls
	_speed_up_button = get_gui_icon_button_from_nodepath(^"./topbar/button_speedup")
	if _speed_up_button:
		_speed_up_button.pressed.connect(PlayerSingleton.increase_speed)
		_speed_up_button.set_tooltip_string("TOPBAR_INC_SPEED")
		var speed_up_action := InputEventAction.new()
		speed_up_action.action = "time_speed_increase"
		_speed_up_button.shortcut = Shortcut.new()
		_speed_up_button.shortcut.events.append(speed_up_action)
	_speed_down_button = get_gui_icon_button_from_nodepath(^"./topbar/button_speeddown")
	if _speed_down_button:
		_speed_down_button.pressed.connect(PlayerSingleton.decrease_speed)
		_speed_down_button.set_tooltip_string("TOPBAR_DEC_SPEED")
		var speed_down_action := InputEventAction.new()
		speed_down_action.action = "time_speed_decrease"
		_speed_down_button.shortcut = Shortcut.new()
		_speed_down_button.shortcut.events.append(speed_down_action)
	_pause_bg_button = get_gui_icon_button_from_nodepath(^"./topbar/pause_bg")
	if _pause_bg_button:
		_pause_bg_button.pressed.connect(PlayerSingleton.toggle_paused)
		var time_pause_action := InputEventAction.new()
		time_pause_action.action = "time_pause"
		_pause_bg_button.shortcut = Shortcut.new()
		_pause_bg_button.shortcut.events.append(time_pause_action)
	_speed_indicator_button = get_gui_icon_button_from_nodepath(^"./topbar/speed_indicator")
	if _speed_indicator_button:
		_speed_indicator_button.pressed.connect(PlayerSingleton.toggle_paused)
	_date_label = get_gui_label_from_nodepath(^"./topbar/DateText")

	# Nation management screens
	const screen_nodepaths: Dictionary = {
		NationManagement.Screen.PRODUCTION: ^"./topbar/topbarbutton_production",
		NationManagement.Screen.BUDGET: ^"./topbar/topbarbutton_budget",
		NationManagement.Screen.TECHNOLOGY: ^"./topbar/topbarbutton_tech",
		NationManagement.Screen.POLITICS: ^"./topbar/topbarbutton_politics",
		NationManagement.Screen.POPULATION: ^"./topbar/topbarbutton_pops",
		NationManagement.Screen.TRADE: ^"./topbar/topbarbutton_trade",
		NationManagement.Screen.DIPLOMACY: ^"./topbar/topbarbutton_diplomacy",
		NationManagement.Screen.MILITARY: ^"./topbar/topbarbutton_military",
	}
	for screen: NationManagement.Screen in screen_nodepaths:
		var button: GUIIconButton = get_gui_icon_button_from_nodepath(screen_nodepaths[screen])
		if button:
			if screen == NationManagement.Screen.TECHNOLOGY:
				# Our tree of the technologies (F5); the screen of Victoria 2 is opened with a button of that window
				button.pressed.connect(Events.NationManagementScreens.army_tech_window_toggle_requested.emit)
			else:
				button.pressed.connect(
					Events.NationManagementScreens.toggle_nation_management_screen.bind(screen)
				)
			# The keys F1-F8 of Victoria 2 are not bound to the screens: F5-F7 belong to our windows (technologies, wars, recruitment)
			button.shortcut = null
			_nation_management_buttons[screen] = button
	Events.NationManagementScreens.update_active_nation_management_screen.connect(
		_on_update_active_nation_management_screen
	)

	# Production
	const PRODUCED_GOOD_COUNT: int = 5
	for idx: int in PRODUCED_GOOD_COUNT:
		_production_top_goods_icons.push_back(get_gui_icon_from_nodepath("./topbar/topbar_produced%d" % idx))
	_production_alert_building_icon = get_gui_icon_from_nodepath(^"./topbar/alert_building_factories")
	_production_alert_closed_icon = get_gui_icon_from_nodepath(^"./topbar/alert_closed_factories")
	_production_alert_unemployment_icon = get_gui_icon_from_nodepath(^"./topbar/alert_unemployed_workers")

	# Technology
	var tech_button: GUIIconButton = _nation_management_buttons[NationManagement.Screen.TECHNOLOGY]
	_technology_progress_bar = get_gui_progress_bar_from_nodepath(^"./topbar/topbar_tech_progress")
	if _technology_progress_bar and tech_button:
		_technology_progress_bar.reparent(tech_button)
	_technology_current_research_label = get_gui_label_from_nodepath(^"./topbar/tech_current_research")
	if _technology_current_research_label:
		_technology_current_research_label.set_auto_translate(false)
		if tech_button:
			_technology_current_research_label.reparent(tech_button)
	_technology_literacy_label = get_gui_label_from_nodepath(^"./topbar/tech_literacy_value")
	if _technology_literacy_label:
		_technology_literacy_label.set_auto_translate(false)
		if tech_button:
			_technology_literacy_label.reparent(tech_button)
	_technology_research_points_label = get_gui_label_from_nodepath(^"./topbar/topbar_researchpoints_value")
	if _technology_research_points_label:
		_technology_research_points_label.set_auto_translate(false)
		if tech_button:
			_technology_research_points_label.reparent(tech_button)

	# Politics
	_politics_party_icon = get_gui_icon_from_nodepath(^"./topbar/politics_party_icon")
	_politics_party_label = get_gui_label_from_nodepath(^"./topbar/politics_ruling_party")
	var politics_suppression_button: GUIIconButton = get_gui_icon_button_from_nodepath(^"./topbar/topbar_supression_icon")
	if politics_suppression_button:
		politics_suppression_button.pressed.connect(
			func() -> void:
				# TODO - open the politics menu on the Movements tab
				Events.NationManagementScreens.toggle_nation_management_screen(NationManagement.Screen.POLITICS)
		)
	_politics_suppression_points_label = get_gui_label_from_nodepath(^"./topbar/politics_supressionpoints_value")
	_politics_infamy_label = get_gui_label_from_nodepath(^"./topbar/politics_infamy_value")
	_politics_reforms_button = get_gui_icon_button_from_nodepath(^"./topbar/alert_can_do_reforms")
	if _politics_reforms_button:
		_politics_reforms_button.pressed.connect(
			func() -> void:
				# TODO - open the politics menu on the Reforms tab
				Events.NationManagementScreens.toggle_nation_management_screen(NationManagement.Screen.POLITICS)
		)
	_politics_decisions_button = get_gui_icon_button_from_nodepath(^"./topbar/alert_can_do_decisions")
	if _politics_decisions_button:
		_politics_decisions_button.pressed.connect(
			func() -> void:
				# TODO - open the politics menu on the Decisions tab
				Events.NationManagementScreens.toggle_nation_management_screen(NationManagement.Screen.POLITICS)
		)
	_politics_election_icon = get_gui_icon_from_nodepath(^"./topbar/alert_is_in_election")
	_politics_rebels_button = get_gui_icon_button_from_nodepath(^"./topbar/alert_have_rebels")
	if _politics_rebels_button:
		_politics_rebels_button.pressed.connect(
			func() -> void:
				# TODO - open the politics menu on the Movements tab
				Events.NationManagementScreens.toggle_nation_management_screen(NationManagement.Screen.POLITICS)
		)

	# Population
	_population_total_size_label = get_gui_label_from_nodepath(^"./topbar/population_total_value")
	_population_national_foci_label = get_gui_label_from_nodepath(^"./topbar/topbar_focus_value")
	_population_militancy_label = get_gui_label_from_nodepath(^"./topbar/population_avg_mil_value")
	_population_consciousness_label = get_gui_label_from_nodepath(^"./topbar/population_avg_con_value")

	# Trade
	const TRADE_GOOD_COUNT: int = 3
	for idx in TRADE_GOOD_COUNT:
		_trade_imported_icons.push_back(get_gui_icon_from_nodepath("./topbar/topbar_import%d" % idx))
		_trade_exported_icons.push_back(get_gui_icon_from_nodepath("./topbar/topbar_export%d" % idx))

	# Diplomacy
	_diplomacy_peace_label = get_gui_label_from_nodepath(^"./topbar/diplomacy_status")
	_diplomacy_war_enemies_overlapping_elements_box = get_gui_overlapping_elements_box_from_nodepath(^"./topbar/diplomacy_at_war")
	_diplomacy_diplomatic_points_label = get_gui_label_from_nodepath(^"./topbar/diplomacy_diplopoints_value")
	_diplomacy_alert_colony_button = get_gui_icon_button_from_nodepath(^"./topbar/alert_colony")
	if _diplomacy_alert_colony_button:
		_diplomacy_alert_colony_button.pressed.connect(
			func() -> void:
				# TODO - move to and select province in upgradable colony if any exist
				Events.NationManagementScreens.open_nation_management_screen(NationManagement.Screen.DIPLOMACY)
		)
	_diplomacy_alert_crisis_icon = get_gui_icon_from_nodepath(^"./topbar/alert_crisis")
	_diplomacy_alert_sphere_icon = get_gui_icon_from_nodepath(^"./topbar/alert_can_increase_opinion")
	_diplomacy_alert_great_power_icon = get_gui_icon_from_nodepath(^"./topbar/alert_loosing_gp")

	# Military
	_military_army_size_label = get_gui_label_from_nodepath(^"./topbar/military_army_value")
	if _military_army_size_label:
		_military_army_size_label.set_auto_translate(false)
		_military_army_size_label.set_text("§Y$CURR$/$MAX$")
		_military_army_size_label.set_tooltip_string("TOPBAR_ARMY_TOOLTIP")
	_military_navy_size_label = get_gui_label_from_nodepath(^"./topbar/military_navy_value")
	if _military_navy_size_label:
		_military_navy_size_label.set_auto_translate(false)
	_military_mobilisation_size_label = get_gui_label_from_nodepath(^"./topbar/military_manpower_value")
	if _military_mobilisation_size_label:
		_military_mobilisation_size_label.set_auto_translate(false)
		# A click on the mobilisation of the top bar mobilises or demobilises the country (after a confirmation)
		_military_mobilisation_size_label.mouse_filter = Control.MOUSE_FILTER_STOP
		_military_mobilisation_size_label.gui_input.connect(_on_mobilisation_label_input)
	_mobilisation_dialog = ConfirmationDialog.new()
	_mobilisation_dialog.title = "Мобилизация"
	_mobilisation_dialog.ok_button_text = "Да"
	_mobilisation_dialog.cancel_button_text = "Отмена"
	_mobilisation_dialog.confirmed.connect(_on_mobilisation_confirmed)
	add_child(_mobilisation_dialog)
	_military_leadership_points_label = get_gui_label_from_nodepath(^"./topbar/military_leadership_value")
	if _military_leadership_points_label:
		_military_leadership_points_label.set_auto_translate(false)

	_update_info()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED:
			_update_info()
		NOTIFICATION_PREDELETE:
			# If the C++ TopBar isn't freed before the destruction of this GUINode, then its update
			# method, triggered by
			# gamestate updates, could be called after all the child UI nodes they refer to have
			# been freed,
			# meaning the C++ TopBar would be dereferencing invalid pointers.
			MenuSingleton.unlink_top_bar_from_cpp()


func _update_info() -> void:
	_update_speed_controls()

	var topbar_info: Dictionary = MenuSingleton.get_topbar_info()

	## Time control
	if _date_label:
		_date_label.text = MenuSingleton.get_longform_date()

	## Production
	for idx: int in _production_top_goods_icons.size():
		if _production_top_goods_icons[idx]:
			_production_top_goods_icons[idx].set_icon_index(idx + 2)

	if _production_alert_building_icon:
		_production_alert_building_icon.set_icon_index(2)

	if _production_alert_closed_icon:
		_production_alert_closed_icon.set_icon_index(2)

	if _production_alert_unemployment_icon:
		_production_alert_unemployment_icon.set_icon_index(2)

	## Technology
	const research_key: StringName = &"research"
	const research_tooltip_key: StringName = &"research_tooltip"
	const research_progress_key: StringName = &"research_progress"
	const literacy_key: StringName = &"literacy"
	const literacy_change_key: StringName = &"literacy_change"
	const research_points_key: StringName = &"research_points"
	const research_points_tooltip_key: StringName = &"research_points_tooltip"

	if _technology_progress_bar:
		_technology_progress_bar.set_value(topbar_info.get(research_progress_key, 0))

	if _technology_current_research_label:
		_technology_current_research_label.set_text(topbar_info.get(research_key, ""))
		_technology_current_research_label.set_tooltip_string(topbar_info.get(research_tooltip_key, ""))

	if _technology_literacy_label:
		var literacy_float: float = topbar_info.get(literacy_key, 0.0) * 100
		var literacy_string: String = GUINode.float_to_string_dp(literacy_float, 1)
		_technology_literacy_label.set_text("§Y%s§W%%" % literacy_string)
		_technology_literacy_label.set_tooltip_string(
			tr(&"TOPBAR_AVG_LITERACY").replace("$AVG$", literacy_string) + "\n" + tr(&"TOPBAR_AVG_CHANGE").replace(
				"$VAL$", GUINode.float_to_string_dp(topbar_info.get(literacy_change_key, 0.0), 4))
		)

	if _technology_research_points_label:
		_technology_research_points_label.set_text("§Y%s" % GUINode.float_to_string_dp(topbar_info.get(research_points_key, 0), 2))
		_technology_research_points_label.set_tooltip_string(topbar_info.get(research_points_tooltip_key, ""))

	## Politics
	if _politics_party_icon:
		_politics_party_icon.set_modulate(Color(1.0, 1.0, 0.0))

	if _politics_party_label:
		_politics_party_label.set_text("ENG_liberal")

	if _politics_suppression_points_label:
		_politics_suppression_points_label.set_text("§Y%s" % GUINode.float_to_string_dp(2.5, 1))

	if _politics_infamy_label:
		_politics_infamy_label.set_text("§Y%s" % GUINode.float_to_string_dp(0.0, 2))

	if _politics_reforms_button:
		_politics_reforms_button.set_icon_index(2)

	if _politics_decisions_button:
		_politics_decisions_button.set_icon_index(2)

	if _politics_election_icon:
		_politics_election_icon.set_icon_index(2)

	if _politics_rebels_button:
		_politics_rebels_button.set_icon_index(2)

	## Population
	if _population_total_size_label:
		# TODO - suffixes on both numbers should be white!
		var total_population: int = int(topbar_info.get(&"population", 0))
		var growth: int = int(topbar_info.get(&"population_change", 0))
		_population_total_size_label.set_text("§Y%s§!(§%s%s§!)" % [
			GUINode.int_to_string_suffixed(total_population),
			"G" if growth >= 0 else "R",
			GUINode.int_to_string_suffixed(absi(growth)),
		])
		_population_total_size_label.set_tooltip_string(str(topbar_info.get(&"population_tooltip", "")))

	if _population_national_foci_label:
		# The national foci are not in the project yet (docs/QUESTIONS.md)
		var foci_used: int = int(topbar_info.get(&"national_foci_used", 0))
		var max_foci: int = int(topbar_info.get(&"national_foci_max", 0))
		_population_national_foci_label.set_text("§%s%d/%d" % ["R" if foci_used < max_foci else "G", foci_used, max_foci])

	if _population_militancy_label:
		_population_militancy_label.set_text("§Y%s" % GUINode.float_to_string_dp(float(topbar_info.get(&"population_militancy", 0.0)), 2))

	if _population_consciousness_label:
		_population_consciousness_label.set_text("§Y%s" % GUINode.float_to_string_dp(float(topbar_info.get(&"population_consciousness", 0.0)), 2))

	## Trade
	for idx: int in _trade_imported_icons.size():
		if _trade_imported_icons[idx]:
			_trade_imported_icons[idx].set_icon_index(idx + 2 + _production_top_goods_icons.size())

	for idx: int in _trade_exported_icons.size():
		if _trade_exported_icons[idx]:
			_trade_exported_icons[idx].set_icon_index(idx + 2 + _production_top_goods_icons.size() + _trade_imported_icons.size())

	## Diplomacy
	if _diplomacy_peace_label:
		_diplomacy_peace_label.set_text("TOPBAR_AT_PEACE")

	# TODO - add war enemy flags to _diplomacy_war_enemies_overlapping_elements_box

	if _diplomacy_diplomatic_points_label:
		_diplomacy_diplomatic_points_label.set_text("§Y%s" % GUINode.float_to_string_dp(7.4, 0))

	if _diplomacy_alert_colony_button:
		_diplomacy_alert_colony_button.set_icon_index(3)

	if _diplomacy_alert_crisis_icon:
		_diplomacy_alert_crisis_icon.set_icon_index(3)

	if _diplomacy_alert_sphere_icon:
		_diplomacy_alert_sphere_icon.set_icon_index(2)

	if _diplomacy_alert_great_power_icon:
		_diplomacy_alert_great_power_icon.set_icon_index(2)

	## Military
	const regiment_count_key: StringName = &"regiment_count"

	const max_supported_regiments_key: StringName = &"max_supported_regiments"


	var regiment_count: String = str(topbar_info.get(regiment_count_key, 0))

	if _military_army_size_label:
		# The regiments of the army of the maximum the manpower gives (docs/RECRUITMENT.md: the pops of soldiers, 3000 men a regiment)
		var manpower: Dictionary = PlayerSingleton.get_manpower()
		var army_size_dict: Dictionary = {
			"CURR": regiment_count, "MAX": str(topbar_info.get(max_supported_regiments_key, 0)),
		}
		if not manpower.is_empty():
			army_size_dict["CURR"] = ("§R" if float(manpower[&"combat_multiplier"]) < 1.0 else "") + str(int(manpower[&"regiments"]))
			# The regiments there are and could be: these plus the ones the free men give
			army_size_dict["MAX"] = str(int(manpower[&"regiments"]) + int(manpower[&"available_regiments"]))
		_military_army_size_label.set_substitution_dict(army_size_dict)
		var army_tooltip: String = _manpower_tooltip(manpower) if not manpower.is_empty() \
			else tr(&"TOPBAR_ARMY_TOOLTIP").replace("$CURR$", army_size_dict["CURR"]).replace("$MAX$", army_size_dict["MAX"])
		_military_army_size_label.set_tooltip_substitution_dict({})
		_military_army_size_label.set_tooltip_string(army_tooltip)

	if _military_navy_size_label:
		_military_navy_size_label.set_text("§Y%d/%d" % [0, 0])
		# TODO - navy size tooltip

	const is_mobilised_key: StringName = &"is_mobilised"
	const mobilisation_regiments_key: StringName = &"mobilisation_regiments"
	const mobilisation_impact_tooltip_key: StringName = &"mobilisation_impact_tooltip"

	# The mobilisation (docs/RECRUITMENT.md): the regiments of the pool, or the mobilised ones (red); the tooltip has the pool, the days and the
	# penalty of the economy; a click mobilises or demobilises
	_mobilisation_info = topbar_info.get(&"mobilisation", {})
	if _military_mobilisation_size_label:
		var mobilised: bool = topbar_info.get(is_mobilised_key, false)
		# The click is offered only when it can work (the reason why not is in the tooltip)
		var blocked: String = str(_mobilisation_info.get(&"demobilise_reason" if mobilised else &"mobilise_reason", ""))
		var hint: String = "" if not blocked.is_empty() else "\n\nЩёлкните, чтобы %s." % ("демобилизоваться" if mobilised else "мобилизоваться")
		if mobilised:
			var standing: int = int(_mobilisation_info.get(&"regiments", 0))
			var pending: int = int(_mobilisation_info.get(&"pending_regiments", 0))
			_military_mobilisation_size_label.set_text("§R%d" % standing if pending == 0 else "§R%d+%d" % [standing, pending])
			_military_mobilisation_size_label.set_tooltip_string(_MobilisationText.tooltip(_mobilisation_info) + hint)
		else:
			var tooltip_text: String = _MobilisationText.tooltip(_mobilisation_info)
			if tooltip_text.is_empty():
				# No data of OpenVic: the numbers and the tooltip of Vic2
				var mobilisation_regiments: String = str(topbar_info.get(mobilisation_regiments_key, 0))
				_military_mobilisation_size_label.set_text("§Y%s" % mobilisation_regiments)
				var impact_tooltip: String = topbar_info.get(mobilisation_impact_tooltip_key, "")
				tooltip_text = tr(&"TOPBAR_MOBILIZE_TOOLTIP").replace("$CURR$", mobilisation_regiments) \
					+ ("\n\n" + impact_tooltip if not impact_tooltip.is_empty() else "")
			else:
				# The regiments of the pool of the poor pops (the count of Vic2 is not used by the mobilisation of OpenVic)
				_military_mobilisation_size_label.set_text("§Y%d" % int(_mobilisation_info.get(&"pool_regiments", 0)))
			_military_mobilisation_size_label.set_tooltip_string(tooltip_text + hint)

	const leadership_key: StringName = &"leadership"
	const leadership_tooltip_key: StringName = &"leadership_tooltip"

	if _military_leadership_points_label:
		_military_leadership_points_label.set_text("§Y%d" % topbar_info.get(leadership_key, 0))
		_military_leadership_points_label.set_tooltip_string(topbar_info.get(leadership_tooltip_key, ""))


func _update_speed_controls() -> void:
	var paused: bool = MenuSingleton.is_paused()
	var speed: int = MenuSingleton.get_speed()

	# TODO - decide whether to disable these or not
	# (they don't appear to get disabled in the base game)
	#if _speed_up_button:
	#	_speed_up_button.disabled = not MenuSingleton.can_increase_speed()

	#if _speed_down_button:
	#	_speed_down_button.disabled = not MenuSingleton.can_decrease_speed()

	if _pause_bg_button:
		_pause_bg_button.set_tooltip_string("TOPBAR_DATE_IS_PAUSED" if paused else "TOPBAR_DATE")

	if _speed_indicator_button:
		var index: int = 1
		if paused:
			_speed_indicator_button.set_tooltip_string("TOPBAR_PAUSE_INDICATOR")
		else:
			index += speed + 1
			const SPEED_NAMES: PackedStringArray = [
				"SLOWEST_SPEED",
				"SLOW_SPEED",
				"NORMAL_SPEED",
				"FAST_SPEED",
				"FASTEST_SPEED",
			]
			_speed_indicator_button.set_tooltip_string_and_substitution_dict(
				"TOPBAR_SPEED_INDICATOR", { "SPEED": SPEED_NAMES[speed] if speed < SPEED_NAMES.size() else str(speed) }
			)
		_speed_indicator_button.set_icon_index(index)


func _on_update_active_nation_management_screen(active_screen: NationManagement.Screen) -> void:
	for screen: NationManagement.Screen in _nation_management_buttons:
		_nation_management_buttons[screen].set_icon_index(1 + int(screen == active_screen))


# A number with spaces between the thousands (180 000)
## The manpower of the player (docs/RECRUITMENT.md): the army against the maximum, where the maximum comes from, what is free, the new men of
## yesterday and the penalty of an army over the maximum
func _manpower_tooltip(manpower: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("Армия: %d полков, %s чел. (по штату %s)" % [int(manpower[&"regiments"]),
		_group_thousands(int(manpower[&"army_men"])), _group_thousands(int(manpower[&"army_full_men"]))])
	lines.append("Можно набрать ещё %d полков (полк — %d чел.)" % [int(manpower[&"available_regiments"]), int(manpower[&"men_per_regiment"])])
	lines.append("Людские ресурсы: максимум %s чел." % _group_thousands(int(manpower[&"max_men"])))
	lines.append("  солдаты-попы своих провинций: %s" % _group_thousands(int(manpower[&"pop_men"])))
	if int(manpower[&"war_bonus_men"]) > 0:
		lines.append("  война: +%s" % _group_thousands(int(manpower[&"war_bonus_men"])))
	lines.append("  реформы: +0")
	var queued: int = int(manpower[&"queued_men"])
	lines.append("В армии %s%s, свободно %s чел. (%d полков)" % [_group_thousands(int(manpower[&"army_men"])),
		(", в наборе %s" % _group_thousands(queued)) if queued > 0 else "",
		_group_thousands(maxi(0, int(manpower[&"free_men"]))), int(manpower[&"available_regiments"])])
	var wanted: int = int(manpower[&"reinforce_wanted_men"])
	if wanted > 0:
		var limit: int = int(manpower[&"reinforce_limit"])
		lines.append("Пополнение вчера: %s из %s чел.%s" % [_group_thousands(int(manpower[&"reinforce_given_men"])), _group_thousands(wanted),
			" — не хватает свободных людей и товаров на складе" if limit == 3 else " — не хватает свободных людей" if limit == 1
			else " — не хватает товаров на складе" if limit == 2 else ""])
	lines.append("Потери в боях и от истощения — это погибшие: солдаты-попы уменьшаются, с ними и максимум.")
	var exhaustion: float = float(manpower.get(&"war_exhaustion", 0.0))
	if exhaustion > 0.0 or bool(manpower[&"at_war"]):
		lines.append("Усталость от войны: %.1f из %d (выпуск заводов и РГО −%d %%; растёт от потерь, оккупации и блокады, в мире −1 в месяц)" % [
			exhaustion, int(manpower.get(&"war_exhaustion_max", 0.0)), int(exhaustion)])
	var over: float = float(manpower[&"over_pct"])
	if float(manpower[&"combat_multiplier"]) < 1.0:
		lines.append("§RАрмия больше максимума на %d %%: атака и защита всех войск ×%.2f§W" % [int(over), float(manpower[&"combat_multiplier"])])
	elif over > 0.0:
		lines.append("Армия чуть больше максимума (на %.1f %%): до 2 %% штрафа нет" % over)
	return "\n".join(lines)


func _on_mobilisation_label_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT or _mobilisation_info.is_empty():
		return
	var mobilised: bool = bool(_mobilisation_info.get(&"is_mobilised", false))
	var reason: String = _mobilisation_info.get(&"demobilise_reason" if mobilised else &"mobilise_reason", "")
	if not reason.is_empty():
		_mobilisation_dialog.dialog_text = ("Демобилизоваться нельзя: " if mobilised else "Мобилизоваться нельзя: ") + reason
		_mobilisation_dialog.get_ok_button().visible = false
	else:
		_mobilisation_dialog.get_ok_button().visible = true
		if mobilised:
			_mobilisation_dialog.dialog_text = "Демобилизовать страну?\nМобилизованные полки (%d) будут распущены, люди вернутся домой." % int(
				_mobilisation_info.get(&"regiments", 0)) + "\nЭкономика снова заработает в полную силу."
		else:
			_mobilisation_dialog.dialog_text = ("Мобилизовать страну?\n%d полков из бедного населения соберутся за %d–%d дн.\n" +
				"Пока они в армии, выпуск РГО и заводов будет на %s %% меньше.") % [int(_mobilisation_info.get(&"pool_regiments", 0)),
				int(_mobilisation_info.get(&"days_min", 0)), int(_mobilisation_info.get(&"days_max", 0)),
				_MobilisationText.penalty_pct(float(_mobilisation_info.get(&"planned_output_multiplier", 1.0)))]
	_mobilisation_dialog.popup_centered()
	accept_event()


func _on_mobilisation_confirmed() -> void:
	PlayerSingleton.set_mobilise(not bool(_mobilisation_info.get(&"is_mobilised", false)))


func _group_thousands(value: int) -> String:
	var text: String = str(absi(value))
	var grouped: String = ""
	while text.length() > 3:
		grouped = " " + text.substr(text.length() - 3) + grouped
		text = text.substr(0, text.length() - 3)
	return ("-" if value < 0 else "") + text + grouped
