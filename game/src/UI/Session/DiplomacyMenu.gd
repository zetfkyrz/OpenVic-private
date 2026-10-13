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

var _active: bool = false

var _main_window: Panel
var _country_listbox: GUIListBox
var _facts_name: GUILabel
var _facts_relation: GUILabel
var _facts_status: GUILabel

var _action_identifiers: PackedStringArray
var _action_buttons: Dictionary[String, GUIIconButton]

var _selected_country_index: int = -1
var _countries_generated: bool = false


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

	var facts: Node = _main_window.get_node_or_null(^"./diplomacy_country_facts")
	if facts:
		_facts_name = GUINode.get_gui_label_from_node(facts.get_node_or_null(^"./country_name"))
		_facts_relation = GUINode.get_gui_label_from_node(facts.get_node_or_null(^"./our_relation"))
		_facts_status = GUINode.get_gui_label_from_node(facts.get_node_or_null(^"./country_status"))

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

	_generate_country_list()
	_generate_action_buttons()
	_update_selected_country()


func _generate_country_list() -> void:
	if not _country_listbox:
		return

	var countries: Array = PlayerSingleton.get_diplomacy_country_list()

	# The list of countries only changes when the player country does, which requires a new game session,
	# but the player country is not known yet when the menu is created so we regenerate it on first show.
	if _countries_generated and _country_listbox.get_child_count() == countries.size():
		return
	_countries_generated = true

	_country_listbox.clear_children(countries.size())
	while _country_listbox.get_child_count() < countries.size():
		var entry: Panel = GUINode.generate_gui_element(_gui_file, "diplomacy_country_info")
		if not entry:
			break
		_country_listbox.add_child(entry)

	for i: int in mini(_country_listbox.get_child_count(), countries.size()):
		var entry: Panel = _country_listbox.get_child(i)
		var country: Dictionary = countries[i]
		var country_index: int = country[&"index"]

		var name_label: GUILabel = GUINode.get_gui_label_from_node_and_path(entry, ^"./country_name")
		if name_label:
			name_label.set_auto_translate(false)
			name_label.set_text(country[&"name"])

		var flag: GUIMaskedFlag = GUINode.get_gui_masked_flag_from_node_and_path(entry, ^"./country_flag")
		if flag:
			flag.set_flag_country_name(country[&"identifier"])

		var select_button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(entry, ^"./country_select")
		if select_button:
			select_button.pressed.connect(_select_country.bind(country_index))

		# These columns need data the simulation does not provide yet
		for column: NodePath in [
			^"./country_prestige", ^"./country_economic", ^"./country_military", ^"./country_total",
			^"./country_opinion", ^"./country_relation",
		]:
			var label: GUILabel = GUINode.get_gui_label_from_node_and_path(entry, column)
			if label:
				label.set_text("")


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

	# Place the visible buttons in _update_selected_country
	_update_selected_country()


func _select_country(country_index: int) -> void:
	_selected_country_index = country_index
	_update_selected_country()


func _on_action_pressed(action_index: int) -> void:
	if _selected_country_index < 0:
		return

	var identifier: String = _action_identifiers[action_index]
	var sent: bool = PlayerSingleton.send_diplomatic_action(_selected_country_index, action_index)
	if not sent:
		push_warning("Diplomatic action \"%s\" was not accepted" % identifier)

	_update_selected_country()


func _update_selected_country() -> void:
	var has_selection: bool = _selected_country_index >= 0
	var relation: Dictionary = {}
	if has_selection:
		relation = PlayerSingleton.get_diplomatic_relation(_selected_country_index)
		has_selection = not relation.is_empty()

	_update_facts(relation)

	# Collect the visible actions, then lay them out in rows of _ACTIONS_PER_ROW
	var slot: int = 0
	for identifier: String in _action_identifiers:
		var button: GUIIconButton = _action_buttons.get(identifier)
		if not button:
			continue

		var visible_for_relation: bool = has_selection and _is_action_available(identifier, relation)
		var option: Control = button.get_parent()
		option.visible = visible_for_relation
		if not visible_for_relation:
			continue

		option.position = _ACTIONS_POSITION + Vector2(
			(slot % _ACTIONS_PER_ROW) * _ACTION_SIZE.x,
			(slot / _ACTIONS_PER_ROW) * _ACTION_SIZE.y,
		)
		slot += 1


func _update_facts(relation: Dictionary) -> void:
	if _facts_name:
		_facts_name.set_auto_translate(false)
		_facts_name.set_text(_get_selected_country_name())

	if _facts_relation:
		_facts_relation.set_auto_translate(false)
		_facts_relation.set_text(str(relation.get(&"relation", "")))

	if _facts_status:
		_facts_status.set_auto_translate(false)
		_facts_status.set_text(_describe_relation(relation))


func _get_selected_country_name() -> String:
	if _selected_country_index < 0:
		return ""

	for country: Dictionary in PlayerSingleton.get_diplomacy_country_list():
		if country[&"index"] == _selected_country_index:
			return country[&"name"]

	return ""


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
