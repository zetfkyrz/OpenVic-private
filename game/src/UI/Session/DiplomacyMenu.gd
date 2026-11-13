extends GUINode

const _screen: NationManagement.Screen = NationManagement.Screen.DIPLOMACY
const _gui_file: String = "country_diplomacy"

# Position and layout of the action buttons, from the diplomacy_actions_pos and diplomacy_actions_wrap_count
# positionTypes of country_diplomacy.gui
const _ACTIONS_POSITION: Vector2 = Vector2(677, 395)
const _ACTIONS_PER_ROW: int = 2
const _ACTION_SIZE: Vector2 = Vector2(160, 24)

# Actions that cannot be used yet (they depend on systems which do not exist, e.g. wars with allies)
# The influence and the sphere wait for their own system (docs/PLAN_DIPLOMACY_VIC2.md, "Сфера влияния"): their buttons are hidden for now
const _UNAVAILABLE_ACTIONS: PackedStringArray = [
	"call_ally", "command_units", "justify_war", "expel_advisors", "discredit", "ban_embassy", "increase_opinion", "decrease_opinion",
	"add_to_sphere", "remove_from_foreign_sphere", "remove_from_own_sphere",
]
## The names of the diplomatic actions (the identifiers of the simulation are English)
const _ACTION_NAMES: Dictionary[String, String] = {
	"form_alliance": "Предложить союз",
	"end_alliance": "Расторгнуть союз",
	"call_ally": "Призвать союзника",
	"request_military_access": "Запросить проход войск",
	"give_military_access": "Дать проход войск",
	"increase_relations": "Улучшать отношения",
	"decrease_relations": "Ухудшать отношения",
	"war_subsidies": "Платить субсидии",
	"end_war_subsidies": "Прекратить субсидии",
	"declare_war": "Объявить войну",
	"offer_peace": "Мирные переговоры",
	"command_units": "Командовать войсками",
	"justify_war": "Обосновать войну",
	"give_vision": "Дать обзор",
	"remove_vision": "Отозвать обзор",
}

# Labels of the country list entries (diplomacy_country_info), filled from the country data
const _LIST_COLUMNS: Dictionary[NodePath, StringName] = {
	^"./country_prestige": &"prestige_rank",
	^"./country_economic": &"industrial_rank",
	^"./country_military": &"military_rank",
	^"./country_total": &"total_rank",
	^"./country_opinion": &"opinion",
	^"./country_relation": &"relation",
}

# Labels of the country facts window, filled from the selected country data
const _FACT_LABELS: Dictionary[StringName, StringName] = {
	&"country_gov": &"government",
	&"country_prestige": &"prestige",
	&"selected_prestige_rank": &"prestige_rank",
	&"country_economic": &"industrial_power",
	&"selected_industry_rank": &"industrial_rank",
	&"country_military": &"military_power",
	&"selected_military_rank": &"military_rank",
	&"selected_total_rank": &"total_rank",
	&"country_population": &"population",
}
# Facts that have no data in the simulation yet, cleared so that the raw GUI element names are not displayed
const _EMPTY_FACT_LABELS: PackedStringArray = [
	"country_party", "country_tech", "country_primary_cultures", "country_accepted_cultures", "country_total",
]

var _active: bool = false

var _main_window: Panel
var _country_listbox: GUIListBox
var _facts_window: Node
var _facts_name: GUILabel
var _facts_relation: GUILabel
var _facts_status: GUILabel
var _facts_labels: Dictionary[StringName, GUILabel]
var _empty_facts_labels: Array[GUILabel]

var _action_identifiers: PackedStringArray
var _action_buttons: Dictionary[String, GUIIconButton]

var _countries: Array = []
var _countries_by_index: Dictionary[int, Dictionary]
var _selected_country_index: int = -1


# Tabs of the window: great powers, wars, casus belli, crisis (country_diplomacy.gui)
const _TAB_NAMES: PackedStringArray = ["gp_info", "war_info", "cb_info", "crisis_info"]
const _GP_ORIGIN := Vector2(30, 52)
const _GP_STEP := Vector2(335, 62)
var _tab: int = 0
var _war_listbox: GUIListBox
var _cb_window: Control
var _crisis_window: Control
var _gp_entries: Array[Panel] = []


func _ready() -> void:
	GameSingleton.gamestate_updated.connect(_update_info)

	Events.NationManagementScreens.update_active_nation_management_screen.connect(_on_update_active_nation_management_screen)

	add_gui_element(_gui_file, "country_diplomacy")

	set_click_mask_from_nodepaths([^"./country_diplomacy/main_bg"])

	var close_button: GUIIconButton = get_gui_icon_button_from_nodepath(^"./country_diplomacy/close_button")
	if close_button:
		close_button.pressed.connect(Events.NationManagementScreens.close_nation_management_screen.bind(_screen))

	_main_window = get_panel_from_nodepath(^"./country_diplomacy")
	if not _main_window:
		return

	_country_listbox = GUINode.get_gui_listbox_from_node(_main_window.get_node(^"./country_listbox"))

	_facts_window = _main_window.get_node_or_null(^"./diplomacy_country_facts")
	if _facts_window:
		_facts_name = GUINode.get_gui_label_from_node(_facts_window.get_node_or_null(^"./country_name"))
		_facts_relation = GUINode.get_gui_label_from_node(_facts_window.get_node_or_null(^"./our_relation"))
		_facts_status = GUINode.get_gui_label_from_node(_facts_window.get_node_or_null(^"./country_status"))

		for label_name: StringName in _FACT_LABELS:
			var label: GUILabel = _find_facts_label(label_name)
			if label:
				_facts_labels[label_name] = label

		for label_name: String in _EMPTY_FACT_LABELS:
			var label: GUILabel = _find_facts_label(label_name)
			# country_total is both a label with a value and the total rank, it is filled below if it exists
			if label and not _FACT_LABELS.has(StringName(label_name)):
				_empty_facts_labels.append(label)

	_setup_tabs()
	_update_info()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED:
			_update_info()


func _on_update_active_nation_management_screen(active_screen: NationManagement.Screen) -> void:
	_active = active_screen == _screen
	_update_info()


func _update_info() -> void:
	if not _active:
		hide()
		return

	show()

	if not _main_window:
		return

	_countries = PlayerSingleton.get_diplomacy_country_list()
	_countries_by_index.clear()
	for country: Dictionary in _countries:
		_countries_by_index[country[&"index"]] = country

	_update_country_list()
	_generate_action_buttons()
	_update_selected_country()
	_update_tabs()


func _find_facts_label(label_name: String) -> GUILabel:
	var node: Node = _facts_window.find_child(label_name, true, false)
	if not node:
		return null
	return GUINode.get_gui_label_from_node(node)


func _set_label_text(label: GUILabel, text: String) -> void:
	label.set_auto_translate(false)
	label.set_text(text)


func _update_country_list() -> void:
	if not _country_listbox:
		return

	# Entries are only regenerated when the amount of countries changes, e.g. in a new game session
	if _country_listbox.get_child_count() != _countries.size():
		_country_listbox.clear_children(_countries.size())
		while _country_listbox.get_child_count() < _countries.size():
			var new_entry: Panel = GUINode.generate_gui_element(_gui_file, "diplomacy_country_info")
			if not new_entry:
				break
			_country_listbox.add_child(new_entry)

		for i: int in mini(_country_listbox.get_child_count(), _countries.size()):
			_setup_list_entry(_country_listbox.get_child(i), _countries[i])

	for i: int in mini(_country_listbox.get_child_count(), _countries.size()):
		_update_list_entry(_country_listbox.get_child(i), _countries[i])


# Static parts of an entry: name, flag and the selection button
func _setup_list_entry(entry: Panel, country: Dictionary) -> void:
	var country_index: int = country[&"index"]

	var name_label: GUILabel = GUINode.get_gui_label_from_node_and_path(entry, ^"./country_name")
	if name_label:
		_set_label_text(name_label, country[&"name"])

	var flag: GUIMaskedFlag = GUINode.get_gui_masked_flag_from_node_and_path(entry, ^"./country_flag")
	if flag:
		flag.set_flag_country_name(country[&"identifier"])

	var select_button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(entry, ^"./country_select")
	if select_button:
		select_button.pressed.connect(_select_country.bind(country_index))


# Values that change during the game: ranks, opinion and relations
func _update_list_entry(entry: Panel, country: Dictionary) -> void:
	for column: NodePath in _LIST_COLUMNS:
		var label: GUILabel = GUINode.get_gui_label_from_node_and_path(entry, column)
		if label:
			_set_label_text(label, str(country.get(_LIST_COLUMNS[column], "")))


func _generate_action_buttons() -> void:
	if not _action_buttons.is_empty():
		return

	_action_identifiers = PlayerSingleton.get_diplomatic_action_identifiers()

	for action_index: int in _action_identifiers.size():
		var identifier: String = _action_identifiers[action_index]
		if identifier in _UNAVAILABLE_ACTIONS:
			continue

		var option: Panel = GUINode.generate_gui_element(_gui_file, "diplomacy_option")
		if not option:
			break

		var button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(option, ^"./action_option")
		if not button:
			option.queue_free()
			continue

		button.set_text(_ACTION_NAMES.get(identifier, identifier.capitalize()))
		button.pressed.connect(_on_action_pressed.bind(action_index))

		_main_window.add_child(option)
		_action_buttons[identifier] = button


func _select_country(country_index: int) -> void:
	_selected_country_index = country_index
	_update_selected_country()


func _on_action_pressed(action_index: int) -> void:
	if _selected_country_index < 0:
		return

	var identifier: String = _action_identifiers[action_index]
	# Peace is negotiated in the window of the peace (the demands, the answer of the enemy)
	if identifier == "offer_peace" and _open_peace_window(_selected_country_index):
		return
	if not PlayerSingleton.send_diplomatic_action(_selected_country_index, action_index):
		push_warning("Diplomatic action \"%s\" was not accepted" % identifier)

	# The simulation applies the action immediately, refresh the relation and the available actions
	_update_info()


## Opens the window of the peace for the war of the player with the country; false if there is no such war or no window
func _open_peace_window(country_index: int) -> bool:
	var peace_window: Node = get_tree().get_first_node_in_group(&"peace_window")
	if peace_window == null:
		return false
	for war: Dictionary in PlayerSingleton.get_war_overview().get("wars", []):
		for enemy: Dictionary in (war["defenders"] if war["we_attack"] else war["attackers"]):
			if int(enemy["index"]) == country_index:
				peace_window.open_for_war(int(war["id"]))
				return true
	return false


func _update_selected_country() -> void:
	var country: Dictionary = _countries_by_index.get(_selected_country_index, {})
	var has_selection: bool = not country.is_empty()
	var relation: Dictionary = {}
	if has_selection:
		relation = PlayerSingleton.get_diplomatic_relation(_selected_country_index)
		has_selection = not relation.is_empty()

	_update_facts(country, relation)

	# Lay the visible actions out in rows of _ACTIONS_PER_ROW
	var slot: int = 0
	for identifier: String in _action_identifiers:
		var button: GUIIconButton = _action_buttons.get(identifier)
		if not button:
			continue

		var visible_for_relation: bool = has_selection and _is_action_available(identifier, relation)
		var option: Control = button.get_parent() as Control
		option.visible = visible_for_relation
		if not visible_for_relation:
			continue

		_update_action_text(identifier, button, relation)
		option.position = _ACTIONS_POSITION + Vector2(
			(slot % _ACTIONS_PER_ROW) * _ACTION_SIZE.x,
			(slot / _ACTIONS_PER_ROW) * _ACTION_SIZE.y,
		)
		slot += 1


## The buttons of the relations start and stop a monthly process (version 90, docs/DIPLOMACY.md): the text says which, the tooltip what it costs
func _update_action_text(identifier: String, button: GUIIconButton, relation: Dictionary) -> void:
	if identifier != "increase_relations" and identifier != "decrease_relations":
		return
	var improve: bool = identifier == "increase_relations"
	var process: int = int(relation.get(&"relation_process", 0))
	var active: bool = (process > 0) if improve else (process < 0)
	button.set_text(("Прекратить улучшение" if improve else "Прекратить ухудшение") if active else _ACTION_NAMES[identifier])
	var step: int = int(relation.get(&"relation_improve" if improve else &"relation_worsen", 0))
	var limit: int = int(relation.get(&"relation_limit", 100)) if improve else int(relation.get(&"relation_min", -100))
	button.set_tooltip_string(
		"Каждый месяц %s%d к отношениям за %s очко дипломатии, пока отношения не дойдут до %d.\nОчки: %s из %s, +%s в месяц." % [
			"+" if improve else "-", step, GUINode.float_to_string_dp(float(relation.get(&"relation_process_cost", 1.0)), 1), limit,
			GUINode.float_to_string_dp(float(relation.get(&"diplomatic_points", 0.0)), 1),
			GUINode.float_to_string_dp(float(relation.get(&"diplomatic_points_max", 10.0)), 0),
			GUINode.float_to_string_dp(float(relation.get(&"diplomatic_points_gain", 1.0)), 1),
		]
	)


func _update_facts(country: Dictionary, relation: Dictionary) -> void:
	if _facts_name:
		_set_label_text(_facts_name, country.get(&"name", ""))

	if _facts_relation:
		_set_label_text(_facts_relation, str(relation.get(&"relation", "")))
		# What the relation is made of (version 90): its own part, the scar of a war, the process of the buttons, the diplomatic points
		if not relation.is_empty():
			var lines: PackedStringArray = ["Отношения: %d" % int(relation[&"relation"])]
			var scar: int = int(relation.get(&"war_scar", 0))
			if scar < 0:
				lines.append("Без войны: %d, след войны: %d (заживает за %d лет после мира)" % [
					int(relation[&"relation_base"]), scar, int(relation.get(&"war_relation_years", 20))])
			lines.append("Обычно от %d до 100; выше — только в союзе (до %d)" % [int(relation.get(&"relation_min", -100)), int(relation.get(&"relation_limit", 100))])
			var process: int = int(relation.get(&"relation_process", 0))
			if process != 0:
				lines.append("Идёт %s: %s%d в месяц" % ["улучшение" if process > 0 else "ухудшение", "+" if process > 0 else "-",
					int(relation.get(&"relation_improve" if process > 0 else &"relation_worsen", 0))])
			lines.append("Очки дипломатии: %s из %s, +%s в месяц" % [
				GUINode.float_to_string_dp(float(relation.get(&"diplomatic_points", 0.0)), 1),
				GUINode.float_to_string_dp(float(relation.get(&"diplomatic_points_max", 10.0)), 0),
				GUINode.float_to_string_dp(float(relation.get(&"diplomatic_points_gain", 1.0)), 1)])
			_facts_relation.set_tooltip_string("\n".join(lines))

	if _facts_status:
		_set_label_text(_facts_status, _describe_relation(relation))

	for label_name: StringName in _facts_labels:
		var value: Variant = country.get(_FACT_LABELS[label_name], "")
		var text: String
		if value is float:
			text = GUINode.float_to_string_dp(value, 1)
		elif value is int and _FACT_LABELS[label_name] == &"population":
			text = GUINode.int_to_string_suffixed(value)
		else:
			text = str(value)
		_set_label_text(_facts_labels[label_name], text)

	for label: GUILabel in _empty_facts_labels:
		_set_label_text(label, "")


func _describe_relation(relation: Dictionary) -> String:
	if relation.is_empty():
		return ""

	var parts: PackedStringArray
	if relation[&"at_war"]:
		parts.append("Война")
	if relation[&"allied"]:
		parts.append("Союз")
	if relation[&"we_have_military_access"]:
		parts.append("у нас проход войск")
	if relation[&"they_have_military_access"]:
		parts.append("у них проход войск")
	if relation[&"we_subsidise"]:
		parts.append("мы платим субсидии")
	if parts.is_empty():
		parts.append("Мир")
	var process: int = int(relation.get(&"relation_process", 0))
	if process != 0:
		parts.append("улучшаем отношения" if process > 0 else "ухудшаем отношения")
	if int(relation.get(&"war_scar", 0)) < 0:
		parts.append("след войны %d" % int(relation[&"war_scar"]))
	# The casus belli and the justification of a war (docs/WAR_ASSUMPTIONS.md, "Обоснование войны")
	if relation.get(&"has_casus_belli", false):
		parts.append("повод для войны: ещё %d дн." % int(relation[&"casus_belli_days"]))
	elif relation.get(&"justifying", false):
		parts.append("обоснование: %d дн." % int(relation[&"justify_days_left"]))
	elif not relation[&"at_war"] and not relation[&"allied"]:
		# A war without it costs no_cb_infamy of infamy and no_cb_exhaustion of war exhaustion (the label is short)
		parts.append("повода нет")

	return ", ".join(parts)


# Only shows actions that make sense for the current relation, so that the player is not offered
# "end alliance" with a country they are not allied with, etc.
func _is_action_available(identifier: String, relation: Dictionary) -> bool:
	var at_war: bool = relation[&"at_war"]
	var allied: bool = relation[&"allied"]

	match identifier:
		"form_alliance":
			return not allied and not at_war
		"end_alliance":
			return allied
		"justify_war":
			# One justification at a time, not against a country we already have a casus belli against
			return not at_war and not allied and not relation.get(&"has_casus_belli", false) \
				and not relation.get(&"justifying", false) and not relation.get(&"justifying_other", false)
		"call_ally":
			# Into our war (docs/WAR_ASSUMPTIONS.md, "Союзники и отдельный мир"); the simulation checks the rest
			return allied and not at_war
		"declare_war":
			return not at_war and not allied
		"offer_peace":
			return at_war
		"war_subsidies":
			return not relation[&"we_subsidise"] and not at_war
		"end_war_subsidies":
			return relation[&"we_subsidise"]
		"request_military_access":
			return not relation[&"we_have_military_access"]
		"give_military_access":
			return not relation[&"they_have_military_access"]
		"give_vision":
			return not relation[&"we_have_vision"]
		"remove_vision":
			return relation[&"we_have_vision"]

	return true


# ---- Tabs: great powers, wars, casus belli, crisis ----


func _setup_tabs() -> void:
	for i: int in _TAB_NAMES.size():
		var button: GUIIconButton = get_gui_icon_button_from_nodepath(NodePath("./country_diplomacy/" + _TAB_NAMES[i]))
		if button:
			button.pressed.connect(_set_tab.bind(i))
	_war_listbox = GUINode.get_gui_listbox_from_node(_main_window.get_node_or_null(^"./war_listbox"))
	_cb_window = _main_window.get_node_or_null(^"./cb_info_win")
	_crisis_window = _main_window.get_node_or_null(^"./crisis_info_win")

	# Casus belli do not exist in the simulation: the war goal is chosen when the war is declared
	if _cb_window:
		var note := Label.new()
		note.text = "Поводов к войне пока нет.
Цель войны выбирается при её объявлении."
		note.position = Vector2(20, 60)
		note.add_theme_color_override(&"font_color", Color(0.15, 0.1, 0.05))
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cb_window.add_child(note)


func _set_tab(tab: int) -> void:
	_tab = tab
	_update_tabs()


func _update_tabs() -> void:
	if _war_listbox:
		_war_listbox.visible = _tab == 1
	if _cb_window:
		_cb_window.visible = _tab == 2
	if _crisis_window:
		_crisis_window.visible = _tab == 3
	for entry: Panel in _gp_entries:
		entry.visible = _tab == 0

	match _tab:
		0:
			_fill_great_powers()
		1:
			_fill_wars()
		3:
			_update_crisis()


func _fill_great_powers() -> void:
	var powers: Array = PlayerSingleton.get_great_powers_info()
	# Entries are made again only when the amount changes, their numbers are refreshed every time
	if _gp_entries.size() != powers.size():
		for entry: Panel in _gp_entries:
			entry.queue_free()
		_gp_entries.clear()
		for i: int in powers.size():
			var entry: Panel = GUINode.generate_gui_element(_gui_file, "diplomacy_greatpower_info")
			if entry == null:
				break
			entry.position = _GP_ORIGIN + Vector2(_GP_STEP.x * (i % 2), _GP_STEP.y * (i / 2))
			_main_window.add_child(entry)
			_gp_entries.append(entry)

	for i: int in mini(_gp_entries.size(), powers.size()):
		var entry: Panel = _gp_entries[i]
		var power: Dictionary = powers[i]
		var name_label: GUILabel = GUINode.get_gui_label_from_node_and_path(entry, ^"./country_name")
		if name_label:
			name_label.set_text(str(power[&"name"]))
		var flag_button: GUIMaskedFlagButton = GUINode.get_gui_masked_flag_button_from_node_and_path(entry, ^"./country_flag")
		if flag_button:
			flag_button.set_flag_country_name(str(power[&"tag"]))
		for pair: Array in [
			[^"./gp_prestige", &"prestige"], [^"./gp_economic", &"industrial_power"], [^"./gp_military", &"military_power"],
		]:
			var label: GUILabel = GUINode.get_gui_label_from_node_and_path(entry, pair[0])
			if label:
				label.set_text(GUINode.float_to_string_dp(float(power[pair[1]]), 0))
		var total: GUILabel = GUINode.get_gui_label_from_node_and_path(entry, ^"./gp_total")
		if total:
			total.set_text(str(power[&"total_rank"]))
		entry.tooltip_text = "%s\n%s: %s" % [power[&"name"], "Ваше влияние", GUINode.float_to_string_dp(float(power[&"influence"]), 0)]


func _fill_wars() -> void:
	if _war_listbox == null:
		return
	var wars: Array = PlayerSingleton.get_world_wars_info()
	_war_listbox.clear_children(wars.size())
	for war: Dictionary in wars:
		var entry: Panel = GUINode.generate_gui_element(_gui_file, "diplomacy_war_info")
		if entry == null:
			break
		_war_listbox.add_child(entry)
		var attackers: PackedStringArray = []
		for side: Dictionary in war[&"attackers"]:
			attackers.append(str(side[&"name"]))
		var defenders: PackedStringArray = []
		for side: Dictionary in war[&"defenders"]:
			defenders.append(str(side[&"name"]))
		var title: GUILabel = GUINode.get_gui_label_from_node_and_path(entry, ^"./war_name")
		if title:
			title.set_text("%s — %s" % [", ".join(attackers), ", ".join(defenders)])
		var score: GUILabel = GUINode.get_gui_label_from_node_and_path(entry, ^"./warscore_text")
		if score:
			score.set_text("%s : %s" % [
				GUINode.float_to_string_dp(float(war[&"attacker_score"]), 0), GUINode.float_to_string_dp(float(war[&"defender_score"]), 0),
			])
		entry.tooltip_text = "%s: %d" % ["Дней войны", int(war[&"days"])]
		# There is no joining of wars and no military strength per side in the simulation yet
		for part: StringName in [&"join_attackers", &"join_defenders"]:
			var button: Node = entry.find_child(String(part), true, false)
			if button is CanvasItem:
				(button as CanvasItem).visible = false
		for label_name: NodePath in [^"./attackers_mil_strength", ^"./defenders_mil_strength"]:
			var strength: GUILabel = GUINode.get_gui_label_from_node_and_path(entry, label_name)
			if strength:
				strength.set_text("")


func _update_crisis() -> void:
	if _crisis_window == null:
		return
	var crisis: Dictionary = PlayerSingleton.get_crisis_info()
	var active: bool = crisis.get(&"active", false)
	# There is no crisis system yet: the window only says so, the parts of a crisis are hidden
	for part: StringName in [&"attacker_win", &"defender_win", &"fence_sitters_win", &"fence_sitters_label", &"crisis_temperature",
			&"crisis_temperature_overlay"]:
		var node: Node = _crisis_window.find_child(String(part), true, false)
		if node is CanvasItem:
			(node as CanvasItem).visible = active
	var title: GUILabel = GUINode.get_gui_label_from_node_and_path(_crisis_window, ^"./crisis_title")
	if title:
		title.set_text("Кризис")
	var sub_title: GUILabel = GUINode.get_gui_label_from_node_and_path(_crisis_window, ^"./crisis_sub_title")
	if sub_title:
		sub_title.set_text("" if active else "В мире нет кризиса")
	var status: GUILabel = GUINode.get_gui_label_from_node_and_path(_crisis_window, ^"./crisis_status_label")
	if status:
		status.set_text("")
