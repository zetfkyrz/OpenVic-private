extends GUINode

const _screen: NationManagement.Screen = NationManagement.Screen.DIPLOMACY
const _gui_file: String = "country_diplomacy"

# Position and layout of the action buttons, from the diplomacy_actions_pos and diplomacy_actions_wrap_count
# positionTypes of country_diplomacy.gui
const _ACTIONS_POSITION: Vector2 = Vector2(677, 395)
const _ACTIONS_PER_ROW: int = 2
const _ACTION_SIZE: Vector2 = Vector2(160, 24)

# Actions that cannot be used yet (they depend on systems which do not exist, e.g. wars with allies)
const _UNAVAILABLE_ACTIONS: PackedStringArray = ["call_ally", "command_units", "justify_war", "expel_advisors"]

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

		button.set_text(identifier.capitalize())
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
	if not PlayerSingleton.send_diplomatic_action(_selected_country_index, action_index):
		push_warning("Diplomatic action \"%s\" was not accepted" % identifier)

	# The simulation applies the action immediately, refresh the relation and the available actions
	_update_info()


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

		option.position = _ACTIONS_POSITION + Vector2(
			(slot % _ACTIONS_PER_ROW) * _ACTION_SIZE.x,
			(slot / _ACTIONS_PER_ROW) * _ACTION_SIZE.y,
		)
		slot += 1


func _update_facts(country: Dictionary, relation: Dictionary) -> void:
	if _facts_name:
		_set_label_text(_facts_name, country.get(&"name", ""))

	if _facts_relation:
		_set_label_text(_facts_relation, str(relation.get(&"relation", "")))

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
		parts.append("At war")
	if relation[&"allied"]:
		parts.append("Allied")
	if relation[&"we_have_military_access"]:
		parts.append("We have military access")
	if relation[&"they_have_military_access"]:
		parts.append("They have military access")
	if relation[&"we_subsidise"]:
		parts.append("We send war subsidies")
	if parts.is_empty():
		parts.append("Peace")

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
