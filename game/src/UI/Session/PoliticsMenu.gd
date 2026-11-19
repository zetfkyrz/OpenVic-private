extends GUINode

const _screen: NationManagement.Screen = NationManagement.Screen.POLITICS
const _gui_file: String = "country_politics"
const _LawsPanel: GDScript = preload("res://src/UI/Session/LawsPanel.gd")
## Where the laws stand in the window (the area of the tabs, under their buttons)
const _LAWS_RECT: Rect2 = Rect2(384, 44, 626, 574)

var _active: bool = false
#
# Main Window
var _country_modifiers_array: Array[GUIIconButton]
var _government_name: GUILabel
var _national_value: GUIIcon
var _government_desc: GUILabel
var _plurality_value: GUILabel
var _revanchism_value: GUILabel
var _hold_election_button: GUIIconButton
var _voters_ideology_chart: GUIPieChart
var _peoples_ideology_chart: GUIPieChart
#
#	Upper House
var _upperhouse_chart: GUIPieChart
var _upperhouse_listbox: GUIListBox
var _social_reform_allowed: GUILabel
var _political_reform_allowed: GUILabel
var _s_reform_allowed_icon: GUIIcon
var _p_reform_allowed_icon: GUIIcon
#
#	Issues
var _sort_issues: GUIIconButton
var _sort_voters: GUIIconButton
var _sort_people: GUIIconButton
var _issue_listbox: GUIListBox
#
#Tabs
var _reforms_tab: GUIIconButton
var _movements_tab: GUIIconButton
var _decisions_tab: GUIIconButton
var _release_nations_tab: GUIIconButton
#
# Decisions (version 103: the union of the nations of the culture of the player, docs/DIPLOMACY.md "Объединения наций")
var _decisions_listbox: GUIListBox
var _decisions_empty_label: Label
#
# Movements
var _suppression_value: GUILabel
var _sortby_size_button: GUIIconButton
var _sortby_radical_button: GUIIconButton
var _sortby_name_button: GUIIconButton
var _movements_listbox: GUIListBox
var _rebels_listbox: GUIListBox
#
# Reforms
# Unciv Reforms
var _research_points_value: GUILabel
var _unciv_progress: GUIProgressBar
var _westernize_button: GUIIconButton
#
# Release Nations (version 102, docs/DIPLOMACY.md "Освобождение наций"): the nations of the cores in our states, the kind is chosen
# after the button (free or one of the subjects)
var _release_nation_listbox: GUIListBox
var _release_empty_label: Label
var _release_menu: PopupMenu
var _releasable: Array = []
var _release_index: int = -1
const _RELEASE_KINDS: Array = [
	[0, "Независимой страной"], [1, "Марионеткой"], [2, "Протекторатом"], [3, "Колониальным субъектом"], [4, "Коронной землёй"],
	[5, "Доминионом"],
]
#
# The tab that is shown (0 reforms: the laws of OpenVic, 1 movements, 2 decisions, 3 release nations) and the windows of the tabs
var _tab: int = 0
var _laws_panel: Control
var _movements_window: Panel
var _decisions_window: Panel
var _release_nations_window: Panel
var _vic2_reform_windows: Array[Panel] = []


func _ready() -> void:
	GameSingleton.gamestate_updated.connect(_update_info)

	Events.NationManagementScreens.update_active_nation_management_screen.connect(_on_update_active_nation_management_screen)

	add_gui_element("country_politics", "country_politics")

	set_click_mask_from_nodepaths([^"./country_politics/main_bg"])

	var close_button: GUIIconButton = get_gui_icon_button_from_nodepath(^"./country_politics/close_button")
	if close_button:
		close_button.pressed.connect(Events.NationManagementScreens.close_nation_management_screen.bind(_screen))

	var politics_menu: Panel = get_panel_from_nodepath(^"./country_politics")
	if not politics_menu:
		return

	# Main Window
	_government_name = GUINode.get_gui_label_from_node(politics_menu.get_node(^"./government_name"))
	_national_value = GUINode.get_gui_icon_from_node(politics_menu.get_node(^"./national_value"))
	_government_desc = GUINode.get_gui_label_from_node(politics_menu.get_node(^"./government_desc"))
	_plurality_value = GUINode.get_gui_label_from_node(politics_menu.get_node(^"./plurality_value"))
	_revanchism_value = GUINode.get_gui_label_from_node(politics_menu.get_node(^"./revanchism_value"))
	_hold_election_button = GUINode.get_gui_icon_button_from_node(politics_menu.get_node(^"./hold_election"))
	if _hold_election_button:
		_hold_election_button.pressed.connect(func() -> void: print("ELECTION TO BE HELD"))
	_voters_ideology_chart = GUINode.get_gui_pie_chart_from_node(politics_menu.get_node(^"./chart_voters_ideologies"))
	_peoples_ideology_chart = GUINode.get_gui_pie_chart_from_node(politics_menu.get_node(^"./chart_people_ideologies"))

	# Upper House
	_upperhouse_chart = GUINode.get_gui_pie_chart_from_node(politics_menu.get_node(^"./chart_upper_house"))
	_upperhouse_listbox = GUINode.get_gui_listbox_from_node(politics_menu.get_node(^"./upperhouse_ideology_listbox"))
	_social_reform_allowed = GUINode.get_gui_label_from_node(politics_menu.get_node(^"./can_do_social_reforms"))
	_political_reform_allowed = GUINode.get_gui_label_from_node(politics_menu.get_node(^"./can_do_political_reforms"))
	_s_reform_allowed_icon = GUINode.get_gui_icon_from_node(politics_menu.get_node(^"./social_reforms_bock"))
	_p_reform_allowed_icon = GUINode.get_gui_icon_from_node(politics_menu.get_node(^"./political_reforms_bock"))

	#Issues
	_sort_issues = GUINode.get_gui_icon_button_from_node(politics_menu.get_node(^"./sort_by_issue_name"))
	if _sort_issues:
		_sort_issues.pressed.connect(func() -> void: print("ISSUES LIST SORTED BY ISSUE NAME"))
	_sort_voters = GUINode.get_gui_icon_button_from_node(politics_menu.get_node(^"./sort_by_voters"))
	if _sort_voters:
		_sort_voters.pressed.connect(func() -> void: print("ISSUES LIST SORTED BY VOTER PREFERENCE"))
	_sort_people = GUINode.get_gui_icon_button_from_node(politics_menu.get_node(^"./sort_by_people"))
	if _sort_people:
		_sort_people.pressed.connect(func() -> void: print("ISSUES LIST SORTED BY PEOPLES PREFERENCE"))
	_issue_listbox = GUINode.get_gui_listbox_from_node(politics_menu.get_node(^"./issue_listbox"))

	#Tabs
	_reforms_tab = GUINode.get_gui_icon_button_from_node(politics_menu.get_node(^"./reforms_tab"))
	_movements_tab = GUINode.get_gui_icon_button_from_node(politics_menu.get_node(^"./movements_tab"))
	_decisions_tab = GUINode.get_gui_icon_button_from_node(politics_menu.get_node(^"./decisions_tab"))
	_release_nations_tab = GUINode.get_gui_icon_button_from_node(politics_menu.get_node(^"./release_nations_tab"))
	var tab_index: int = 0
	for tab_button: GUIIconButton in [_reforms_tab, _movements_tab, _decisions_tab, _release_nations_tab]:
		if tab_button:
			tab_button.pressed.connect(_set_tab.bind(tab_index))
		tab_index += 1

	# Decisions
	var decisions_window: Panel = GUINode.get_panel_from_node(politics_menu.get_node(^"./decision_window"))
	_decisions_window = decisions_window
	if decisions_window:
		_decisions_listbox = GUINode.get_gui_listbox_from_node(decisions_window.get_node(^"./decision_listbox"))
		_decisions_empty_label = Label.new()
		_decisions_empty_label.position = Vector2(30, 56)
		_decisions_empty_label.size = Vector2(560, 120)
		_decisions_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_decisions_empty_label.add_theme_color_override(&"font_color", Color(0.1, 0.08, 0.05))
		_decisions_empty_label.text = "Решений пока нет. Здесь появляется объединение нации (Германия, Италия, Скандинавия…), если у нашей культурной группы есть союз и он ещё не образован."
		decisions_window.add_child(_decisions_empty_label)

	# Movements
	var movements_window: Panel = GUINode.get_panel_from_node(politics_menu.get_node(^"./movements_window"))
	_movements_window = movements_window
	if movements_window:
		_suppression_value = GUINode.get_gui_label_from_node(movements_window.get_node(^"./suppression_value"))
		_sortby_size_button = GUINode.get_gui_icon_button_from_node(movements_window.get_node(^"./sortby_size_button"))
		if _sortby_size_button:
			_sortby_size_button.pressed.connect(func() -> void: print("MOVEMENTS LIST SORTED BY MOVEMENT SIZE"))
		_sortby_radical_button = GUINode.get_gui_icon_button_from_node(movements_window.get_node(^"./sortby_radical_button"))
		if _sortby_radical_button:
			_sortby_radical_button.pressed.connect(func() -> void: print("MOVEMENTS LIST SORTED BY MOVEMENT RADICALISM"))
		_sortby_name_button = GUINode.get_gui_icon_button_from_node(movements_window.get_node(^"./sortby_name_button"))
		if _sortby_name_button:
			_sortby_name_button.pressed.connect(func() -> void: print("MOVEMENTS LIST SORTED BY MOVEMENT NAME"))
		_movements_listbox = GUINode.get_gui_listbox_from_node(movements_window.get_node(^"./movements_listbox"))
		_rebels_listbox = GUINode.get_gui_listbox_from_node(movements_window.get_node(^"./rebel_listbox"))


	# The reforms of Victoria 2 are replaced by the laws of OpenVic (docs/LAWS_DESIGN.md): their windows stay hidden, the laws take the tab
	var reforms_window: Panel  = GUINode.get_panel_from_node(politics_menu.get_node(^"./reforms_window"))
	if reforms_window:
		_vic2_reform_windows.append(reforms_window)
	_laws_panel = Control.new()
	_laws_panel.set_script(_LawsPanel)
	_laws_panel.position = _LAWS_RECT.position
	_laws_panel.size = _LAWS_RECT.size
	politics_menu.add_child(_laws_panel)

	# Unciv Reforms
	var unciv_reforms_window: Panel = GUINode.get_panel_from_node(politics_menu.get_node(^"./unciv_reforms_window"))
	if unciv_reforms_window:
		_vic2_reform_windows.append(unciv_reforms_window)
		_research_points_value = GUINode.get_gui_label_from_node(unciv_reforms_window.get_node(^"./research_points_val"))
		_unciv_progress = GUINode.get_gui_progress_bar_from_node(unciv_reforms_window.get_node(^"./civ_progress"))
		_westernize_button = GUINode.get_gui_icon_button_from_node(unciv_reforms_window.get_node(^"./westernize_button"))
		if _westernize_button:
			_westernize_button.pressed.connect(func() -> void: print("COUNTRY HAS WESTERNIZED"))

	# Release Nations
	var release_nations_window: Panel = GUINode.get_panel_from_node(politics_menu.get_node(^"./release_nation"))
	_release_nations_window = release_nations_window
	if release_nations_window:
		_release_nation_listbox = GUINode.get_gui_listbox_from_node(release_nations_window.get_node(^"./nations"))
		_release_empty_label = Label.new()
		_release_empty_label.position = Vector2(30, 56)
		_release_empty_label.size = Vector2(560, 120)
		_release_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_release_empty_label.add_theme_color_override(&"font_color", Color(0.1, 0.08, 0.05))
		_release_empty_label.text = "Освободить можно нацию, у которой нет своей страны, если её ядро — столица одной из наших областей (кроме области нашей столицы). Нация получает такие области целиком."
		release_nations_window.add_child(_release_empty_label)
		_release_menu = PopupMenu.new()
		_release_menu.id_pressed.connect(_on_release_kind_chosen)
		add_child(_release_menu)

	_update_tabs()
	_update_info()


func _set_tab(tab: int) -> void:
	_tab = tab
	_update_tabs()
	_update_release_nations()
	_update_decisions()


func _update_tabs() -> void:
	for window: Panel in _vic2_reform_windows:
		window.hide()
	if _laws_panel:
		_laws_panel.visible = _tab == 0
	if _movements_window:
		_movements_window.visible = _tab == 1
	if _decisions_window:
		_decisions_window.visible = _tab == 2
	if _release_nations_window:
		_release_nations_window.visible = _tab == 3


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED:
			_update_info()


func _on_update_active_nation_management_screen(active_screen: NationManagement.Screen) -> void:
	_active = active_screen == _screen
	_update_info()


func _update_info() -> void:
	if _active:
		# TODO - update UI state
		show()
		if _laws_panel:
			_laws_panel.refresh()
		_update_release_nations()
		_update_decisions()
	else:
		hide()


## The tab "decisions" (version 103): the union of the nations, as the decision form_germany... of Vic2 (an entry decision_entry)
func _update_decisions() -> void:
	if not _active or _tab != 2 or _decisions_listbox == null:
		return
	var decision: Dictionary = PlayerSingleton.get_union_decision()
	if _decisions_empty_label:
		_decisions_empty_label.visible = decision.is_empty()
	_decisions_listbox.clear_children(0 if decision.is_empty() else 1)
	if decision.is_empty():
		return
	if _decisions_listbox.get_child_count() == 0:
		var new_entry: Panel = GUINode.generate_gui_element(_gui_file, "decision_entry")
		if not new_entry:
			return
		_decisions_listbox.add_child(new_entry)
	var entry: Panel = _decisions_listbox.get_child(0)
	var name_label: GUILabel = GUINode.get_gui_label_from_node_and_path(entry, ^"./decision_name")
	if name_label:
		name_label.set_auto_translate(false)
		name_label.set_text("Образовать: %s" % decision[&"name"])
	var lines: PackedStringArray = []
	var unmet: PackedStringArray = []
	for requirement: Dictionary in decision[&"requirements"]:
		lines.append(("✓ " if requirement[&"met"] else "✗ ") + String(requirement[&"text"]))
		if not requirement[&"met"]:
			unmet.append("✗ " + String(requirement[&"text"]))
	var desc_label: GUILabel = GUINode.get_gui_label_from_node_and_path(entry, ^"./decision_desc")
	if desc_label:
		desc_label.set_auto_translate(false)
		# (the requirements not met yet under the description, all of them in the tooltip)
		desc_label.set_text("Наша страна станет %s: имя, флаг и ядра союза, культуры группы — принятые, +%d престижа; малым странам нашей культуры в сфере и субъектам предложат войти.\n%s" % [
			decision[&"name"], int(decision[&"prestige_gain"]), "\n".join(unmet) if not unmet.is_empty() else "Все условия выполнены!"])
	var tooltip: String = "Условия:\n" + "\n".join(lines)
	var requirements_icon: Control = entry.get_node_or_null(^"./requirements") as Control
	if requirements_icon:
		requirements_icon.tooltip_text = tooltip
	var button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(entry, ^"./make_decision")
	if button:
		button.disabled = not decision[&"can_form"]
		button.set_tooltip_string(tooltip)
		if not entry.has_meta(&"form_connected"):
			entry.set_meta(&"form_connected", true)
			button.pressed.connect(func() -> void:
				if not PlayerSingleton.form_union():
					push_warning("The union was not formed")
			)
	var ignore: Control = entry.get_node_or_null(^"./ignore_checkbox") as Control
	if ignore:
		ignore.visible = false


## The tab "release nations" (version 102): an entry of the GUI of Vic2 (vassal_nation) for every nation the player can release
func _update_release_nations() -> void:
	if not _active or _tab != 3 or _release_nation_listbox == null:
		return
	_releasable = PlayerSingleton.get_releasable_nations()
	if _release_empty_label:
		_release_empty_label.visible = _releasable.is_empty()
	_release_nation_listbox.clear_children(_releasable.size())
	while _release_nation_listbox.get_child_count() < _releasable.size():
		var new_entry: Panel = GUINode.generate_gui_element(_gui_file, "vassal_nation")
		if not new_entry:
			break
		_release_nation_listbox.add_child(new_entry)
	for i: int in mini(_release_nation_listbox.get_child_count(), _releasable.size()):
		_setup_release_entry(_release_nation_listbox.get_child(i), _releasable[i], i)


func _setup_release_entry(entry: Panel, nation: Dictionary, i: int) -> void:
	var name_label: GUILabel = GUINode.get_gui_label_from_node_and_path(entry, ^"./name")
	if name_label:
		name_label.set_auto_translate(false)
		name_label.set_text(nation[&"name"])
	var type_label: GUILabel = GUINode.get_gui_label_from_node_and_path(entry, ^"./type")
	if type_label:
		type_label.set_auto_translate(false)
		type_label.set_text("колония" if nation[&"colonial"] else "")
	var desc_label: GUILabel = GUINode.get_gui_label_from_node_and_path(entry, ^"./desc")
	if desc_label:
		desc_label.set_auto_translate(false)
		var desc: String = "Области: %s (%d пров., %s чел.)" % [", ".join(PackedStringArray(nation[&"state_names"])), int(nation[&"provinces"]),
			GUINode.int_to_string_suffixed(int(nation[&"population"]))]
		desc_label.set_text(desc)
		# (a long list is cut: the whole text in the tooltip)
		desc_label.set_tooltip_string(desc)
	var flag: Node = entry.get_node_or_null(^"./country_flag")
	if flag is GUIMaskedFlag:
		(flag as GUIMaskedFlag).set_flag_country_name(nation[&"tag"])
	var button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(entry, ^"./country_release_vassal")
	if button:
		button.set_text("Освободить")
		var reason: String = PackedStringArray(nation[&"reasons"])[0]
		button.disabled = reason != ""
		button.set_tooltip_string(reason if reason != "" else "Престиж %+d, дурная слава %+d. Нация получает свою долю казны (по населению); вид — после нажатия." % [
			int(nation[&"prestige"]), int(nation[&"infamy"])])
		if entry.has_meta(&"release_connected"):
			button.pressed.disconnect(entry.get_meta(&"release_connected"))
		var callable: Callable = _choose_release_kind.bind(i)
		button.pressed.connect(callable)
		entry.set_meta(&"release_connected", callable)


func _choose_release_kind(i: int) -> void:
	if i >= _releasable.size():
		return
	_release_index = i
	var reasons: PackedStringArray = _releasable[i][&"reasons"]
	_release_menu.clear()
	_release_menu.add_separator("Освободить %s как" % _releasable[i][&"name"])
	for kind: Array in _RELEASE_KINDS:
		var id: int = kind[0]
		_release_menu.add_item(kind[1], id)
		var item: int = _release_menu.get_item_index(id)
		if id < reasons.size() and reasons[id] != "":
			_release_menu.set_item_disabled(item, true)
			_release_menu.set_item_tooltip(item, reasons[id])
	_release_menu.reset_size()
	_release_menu.position = Vector2i(get_viewport().get_mouse_position())
	_release_menu.popup()


func _on_release_kind_chosen(kind: int) -> void:
	if _release_index < 0 or _release_index >= _releasable.size():
		return
	if not PlayerSingleton.release_nation(int(_releasable[_release_index][&"index"]), kind):
		push_warning("The release of a nation was not accepted")
	_release_index = -1
