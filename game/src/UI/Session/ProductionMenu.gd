extends GUINode

const _screen: NationManagement.Screen = NationManagement.Screen.PRODUCTION
const _gui_file: String = "country_production"

# Elements of the original window that are used, the rest belong to features that do not exist yet
const _KEPT_ELEMENTS: PackedStringArray = [
	"main_bg", "prod_bg", "headline_production", "close_button", "tab_factories", "tab_factories_text",
	"tab_invest", "tab_invest_text", "tab_goodsproduction", "tab_goodsproduction_text",
	"state_listbox", "factory_buttons",
]

const _ProductionTabs: GDScript = preload("res://src/UI/Session/ProductionTabs.gd")
const _TAB_BUTTONS: PackedStringArray = ["tab_factories", "tab_invest", "tab_goodsproduction"]
var _tab: int = 0
var _tabs_view: Control
const _OwnershipDialog: GDScript = preload("res://src/UI/Session/FactoryOwnershipDialog.gd")
const _StatsWindow: GDScript = preload("res://src/UI/Session/FactoryStatsWindow.gd")
# Elements of the "factory_buttons" window that belong to features that do not exist yet
const _HIDDEN_BUTTONS: PackedStringArray = [
	"select_all", "deselect_all", "show_empty_states", "sort_by_name", "sort_by_factories", "sort_by_infra", "filter_bounds",
]

# Size of the "factory_info" window of the original interface
const _FACTORY_WIDTH: float = 112.0
const _STATE_ENTRY_HEIGHT: float = 140.0
# Vertical offset of the factory windows, which are not centred vertically in their bounds window
const _FACTORY_Y_OFFSET: float = -36.0
# Width of the "factory_info_bounds" window of the original interface
const _DEFAULT_BOUNDS_WIDTH: float = 940.0
const _MAX_INPUT_ICONS: int = 4
const _PRIORITY_NAMES: PackedStringArray = ["низкий", "обычный", "высокий"]
# Seconds in which the second click of the delete button confirms the deletion
const _DELETE_CONFIRM_SECONDS: float = 3.0
# GFX_resources frames: the first frames are not goods
const _GOODS_ICON_OFFSET: int = 2
# GFX_employment_ratio has 11 frames, from 0% to 100%
const _EMPLOYMENT_FRAMES: int = 10

var _active: bool = false

var _main_window: Panel
var _state_listbox: GUIListBox

# Build dialog
var _build_dialog: Panel
var _build_option_list: GUIListBox
var _build_state_name: GUILabel
var _build_output_icon: GUIIcon
var _build_building_name: GUILabel
var _build_output_amount: GUILabel
var _build_input_icons: Array[GUIIcon]
var _build_input_amounts: Array[GUILabel]
var _build_description: GUILabel
var _build_workers: GUILabel
var _build_cost: GUILabel
var _build_button: GUIIconButton
var _build_province_index: int = -1
var _build_options: Array = []
var _build_selected: int = -1

var _states_by_province: Dictionary[int, Dictionary] = {}
var _ownership_dialog: Control
var _stats_window: Control


# Small pie chart of the owners of a factory that works as a button
class _OwnerPie extends Control:
	signal pressed

	const STATE_COLOUR: Color = Color(0.72, 0.34, 0.27)
	const INVESTOR_COLOUR: Color = Color(0.45, 0.72, 0.86)

	var state_share: float = 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		# Victoria 2 style pie: light blue private owners, terracotta state wedge, dark rim and a soft gloss
		var centre: Vector2 = size / 2.0
		var radius: float = minf(size.x, size.y) / 2.0 - 1.5
		draw_circle(centre + Vector2(1, 1), radius + 0.5, Color(0, 0, 0, 0.35))
		_slice(centre, radius, 0.0, state_share, STATE_COLOUR)
		_slice(centre, radius, state_share, 1.0, INVESTOR_COLOUR)
		draw_circle(centre + Vector2(-radius * 0.25, -radius * 0.3), radius * 0.55, Color(1, 1, 1, 0.12))
		draw_arc(centre, radius, 0.0, TAU, 40, Color(0.1, 0.17, 0.22), 1.2)
		# The edges of the wedge
		if state_share > 0.01 and state_share < 0.99:
			var angle: float = -PI / 2.0 + state_share * TAU
			draw_line(centre, centre + Vector2(cos(angle), sin(angle)) * radius, Color(0.1, 0.17, 0.22), 1.0)
			draw_line(centre, centre + Vector2(0, -radius), Color(0.1, 0.17, 0.22), 1.0)

	func _slice(centre: Vector2, radius: float, from_share: float, to_share: float, colour: Color) -> void:
		if to_share - from_share <= 0.002:
			return
		var start_angle: float = -PI / 2.0 + from_share * TAU
		var end_angle: float = -PI / 2.0 + to_share * TAU
		var points: PackedVector2Array = [centre]
		var steps: int = maxi(2, int((to_share - from_share) * 32.0))
		for i: int in steps + 1:
			var angle: float = lerpf(start_angle, end_angle, float(i) / float(steps))
			points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, colour)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			pressed.emit()
			accept_event()


func _ready() -> void:
	GameSingleton.gamestate_updated.connect(_update_info)

	Events.NationManagementScreens.update_active_nation_management_screen.connect(_on_update_active_nation_management_screen)

	add_gui_element(_gui_file, "country_production")

	set_click_mask_from_nodepaths([^"./country_production/main_bg"])

	var close_button: GUIIconButton = get_gui_icon_button_from_nodepath(^"./country_production/close_button")
	if close_button:
		close_button.pressed.connect(Events.NationManagementScreens.close_nation_management_screen.bind(_screen))

	_main_window = get_panel_from_nodepath(^"./country_production")
	if not _main_window:
		return

	for child: Node in _main_window.get_children():
		if child is CanvasItem and not (child.name in _KEPT_ELEMENTS):
			child.hide()

	_state_listbox = GUINode.get_gui_listbox_from_node(_main_window.get_node_or_null(^"./state_listbox"))

	_setup_build_dialog()
	_setup_mass_buttons()

	# Tabs: factories (the list of the states), investments and goods production (tables)
	_tabs_view = Control.new()
	_tabs_view.set_script(_ProductionTabs)
	_main_window.add_child(_tabs_view)
	for i: int in _TAB_BUTTONS.size():
		var tab_button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(
			_main_window, NodePath("./" + _TAB_BUTTONS[i])
		)
		if tab_button:
			tab_button.pressed.connect(_set_tab.bind(i))

	_ownership_dialog = Control.new()
	_ownership_dialog.set_script(_OwnershipDialog)
	add_child(_ownership_dialog)

	_stats_window = Control.new()
	_stats_window.set_script(_StatsWindow)
	add_child(_stats_window)

	_update_info()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED:
			_update_info()


func _on_update_active_nation_management_screen(active_screen: NationManagement.Screen) -> void:
	_active = active_screen == _screen
	if not _active and _build_dialog:
		_build_dialog.hide()
	_update_info()


func _set_tab(tab: int) -> void:
	_tab = tab
	if _build_dialog:
		_build_dialog.hide()
	_update_tab_visibility()
	_tabs_view.show_page(_tab)
	if _tab == 0:
		_update_info()


func _update_tab_visibility() -> void:
	var factories: bool = _tab == 0
	if _state_listbox:
		_state_listbox.visible = factories
	var buttons: Node = _main_window.get_node_or_null(^"./factory_buttons")
	if buttons is CanvasItem:
		(buttons as CanvasItem).visible = factories


func _set_label_text(label: GUILabel, text: String) -> void:
	if label:
		label.set_auto_translate(false)
		label.set_text(text)


func _set_goods_icon(icon: GUIIcon, good_index: int) -> void:
	if icon:
		icon.set_icon_index(good_index + _GOODS_ICON_OFFSET)


func _update_info() -> void:
	if not _active:
		hide()
		return

	show()

	if not _state_listbox:
		return

	if _tab > 0 and _tabs_view:
		_update_tab_visibility()
		_tabs_view.refresh(_tab)
		return

	var states: Array = PlayerSingleton.get_production_info()

	_states_by_province.clear()
	var shown_states: Array = []
	for state: Dictionary in states:
		_states_by_province[state[&"province_index"]] = state
		# States with nothing to show and nothing that can be built are not listed
		if not state[&"factories"].is_empty() or not state[&"buildable"].is_empty():
			shown_states.append(state)

	# States with the most factories first
	shown_states.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a[&"factories"].size() > b[&"factories"].size()
	)

	if _state_listbox.get_child_count() != shown_states.size():
		_state_listbox.clear_children(shown_states.size())
		while _state_listbox.get_child_count() < shown_states.size():
			var entry: Panel = GUINode.generate_gui_element(_gui_file, "state_info")
			if not entry:
				break
			_setup_state_entry(entry)
			_state_listbox.add_child(entry)

	for i: int in mini(_state_listbox.get_child_count(), shown_states.size()):
		_update_state_entry(_state_listbox.get_child(i), shown_states[i])

	if _build_dialog and _build_dialog.visible:
		_refresh_build_dialog()


# ---- State entries ----


func _setup_state_entry(entry: Panel) -> void:
	# The factory windows are taller than the state window of the original interface, leave room for them
	entry.custom_minimum_size.y = _STATE_ENTRY_HEIGHT
	entry.size.y = _STATE_ENTRY_HEIGHT

	for hidden_name: NodePath in [^"./state_focus", ^"./pop_info_bounds"]:
		var node: Node = entry.get_node_or_null(hidden_name)
		if node is CanvasItem:
			node.hide()

	var build_button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(entry, ^"./build_new_factory")
	if build_button:
		build_button.pressed.connect(func() -> void: _open_build_dialog(int(entry.get_meta(&"province_index", -1))))


func _update_state_entry(entry: Panel, state: Dictionary) -> void:
	var factories: Array = state[&"factories"]
	entry.set_meta(&"province_index", state[&"province_index"])

	_set_label_text(GUINode.get_gui_label_from_node_and_path(entry, ^"./state_name"), state[&"name"])
	_set_label_text(
		GUINode.get_gui_label_from_node_and_path(entry, ^"./factory_count"),
		"%d / %d" % [factories.size(), factories.size() + int(state[&"free_slots"])]
	)

	var build_button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(entry, ^"./build_new_factory")
	if build_button:
		# Nothing can be built when there is no free slot or no type left to build
		build_button.visible = int(state[&"free_slots"]) > 0 and not state[&"buildable"].is_empty()

	var bounds: Node = entry.get_node_or_null(^"./factory_info_bounds")
	if not bounds:
		return

	while bounds.get_child_count() > factories.size():
		var extra: Node = bounds.get_child(bounds.get_child_count() - 1)
		bounds.remove_child(extra)
		extra.queue_free()

	while bounds.get_child_count() < factories.size():
		var factory_panel: Panel = GUINode.generate_gui_element(_gui_file, "factory_info")
		if not factory_panel:
			break
		_setup_factory_panel(factory_panel)
		# The factory windows are centred in the bounds window, so slots are laid out from its left edge
		var bounds_width: float = bounds.size.x if bounds is Control and bounds.size.x > 0 else _DEFAULT_BOUNDS_WIDTH
		factory_panel.position = Vector2(
			-bounds_width / 2.0 + _FACTORY_WIDTH / 2.0 + bounds.get_child_count() * _FACTORY_WIDTH,
			_FACTORY_Y_OFFSET,
		)
		bounds.add_child(factory_panel)

	for i: int in mini(bounds.get_child_count(), factories.size()):
		_update_factory_panel(bounds.get_child(i), state[&"province_index"], factories[i])


# ---- Buttons for all factories ----


func _setup_mass_buttons() -> void:
	var buttons: Node = _main_window.get_node_or_null(^"./factory_buttons")
	if not buttons:
		return

	for hidden_name: String in _HIDDEN_BUTTONS:
		var node: Node = buttons.get_node_or_null(NodePath("./" + hidden_name))
		if node is CanvasItem:
			node.hide()

	var actions: Dictionary[String, Callable] = {
		"prod_subsidize_all": func() -> void: PlayerSingleton.set_all_factories_subsidised(true),
		"prod_unsubsidize_all": func() -> void: PlayerSingleton.set_all_factories_subsidised(false),
		"prod_open_all_factories": func() -> void: PlayerSingleton.set_all_factories_open(true),
		"prod_close_all_factories": func() -> void: PlayerSingleton.set_all_factories_open(false),
	}
	var tips: Dictionary[String, String] = {
		"prod_subsidize_all": "Субсидировать все заводы",
		"prod_unsubsidize_all": "Снять субсидии со всех заводов",
		"prod_open_all_factories": "Открыть все заводы",
		"prod_close_all_factories": "Закрыть все заводы",
	}
	for button_name: String in actions:
		var button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(buttons, NodePath("./" + button_name))
		if button:
			button.pressed.connect(actions[button_name])
			button.tooltip_string = tips[button_name]

	# The original window has no button for expanding all factories
	var expand_all := Button.new()
	expand_all.text = "+ все"
	expand_all.tooltip_text = "Расширить все заводы страны на один уровень (дешёвые первыми, пока хватает денег)"
	expand_all.position = Vector2(946, 116)
	expand_all.size = Vector2(44, 22)
	expand_all.pressed.connect(func() -> void: PlayerSingleton.expand_all_factories())
	buttons.add_child(expand_all)


# ---- Factories ----


func _setup_factory_panel(panel: Panel) -> void:
	# Features that do not exist yet
	# The hiring priority is chosen in the window of the owners (the pie chart), not with a button on the plate
	var priority_node: Node = panel.get_node_or_null(^"./priority")
	if priority_node is CanvasItem:
		priority_node.hide()

	# Deleting a factory (or cancelling its construction) asks for a second click
	for delete_name: NodePath in [^"./delete_factory", ^"./prod_cancel_progress"]:
		var delete_button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(panel, delete_name)
		if delete_button:
			delete_button.pressed.connect(_on_delete_pressed.bind(panel, delete_button))

	# The open/close button opens or closes the factory
	var open_close_button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(panel, ^"./open_close")
	if open_close_button:
		open_close_button.pressed.connect(
			func() -> void:
				if not panel.has_meta(&"building_type_index"):
					return
				PlayerSingleton.set_factory_open(
					panel.get_meta(&"province_index"),
					panel.get_meta(&"building_type_index"),
					not panel.get_meta(&"open", true)
				)
		)
		open_close_button.tooltip_string = "Открыть или закрыть завод"

	# A click on the factory shows its statistics: the productivity of the last ten years
	var output_click_button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(panel, ^"./output")
	if output_click_button:
		output_click_button.pressed.connect(
			func() -> void:
				if panel.has_meta(&"building_type_index"):
					_stats_window.open(panel.get_meta(&"province_index"), panel.get_meta(&"building_type_index"))
		)

	var subsidise_button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(panel, ^"./subsidise")
	if subsidise_button:
		subsidise_button.pressed.connect(
			func() -> void:
				if not panel.has_meta(&"building_type_index"):
					return
				PlayerSingleton.set_factory_subsidised(
					panel.get_meta(&"province_index"),
					panel.get_meta(&"building_type_index"),
					not panel.get_meta(&"subsidised", false)
				)
		)

	# Owners of the factory: a small pie chart (state / investors), a click opens the window with the shares
	var owner_button := _OwnerPie.new()
	owner_button.name = "owner_button"
	# Between the number of the level and the icon of the type of the factory
	owner_button.position = Vector2(53, 13)
	owner_button.size = Vector2(22, 22)
	owner_button.pressed.connect(
		func() -> void:
			if panel.has_meta(&"factory"):
				_ownership_dialog.open(panel.get_meta(&"province_index"), panel.get_meta(&"factory"))
	)
	panel.add_child(owner_button)

	var upgrade_button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(panel, ^"./upgrade")
	if upgrade_button:
		upgrade_button.pressed.connect(
			func() -> void:
				if not panel.has_meta(&"building_type_index"):
					return
				PlayerSingleton.build_factory(panel.get_meta(&"province_index"), panel.get_meta(&"building_type_index"))
		)

	for progress_name: NodePath in [^"./build_factory_progress", ^"./upgrade_factory_progress"]:
		var bar: GUIProgressBar = GUINode.get_gui_progress_bar_from_node_and_path(panel, progress_name)
		if bar:
			bar.max_value = 1.0
			bar.step = 0.01


func _update_factory_panel(panel: Panel, province_index: int, factory: Dictionary) -> void:
	panel.set_meta(&"province_index", province_index)
	panel.set_meta(&"building_type_index", factory[&"building_type_index"])
	panel.set_meta(&"open", factory[&"open"])
	panel.set_meta(&"subsidised", factory[&"subsidised"])
	panel.set_meta(&"factory", factory)

	# Subsidy: a subsidised factory is highlighted, the tooltip shows what the state and the capitalists paid yesterday
	var subsidise_button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(panel, ^"./subsidise")
	if subsidise_button:
		subsidise_button.visible = factory[&"level"] > 0
		# A tick over the button instead of a highlight: the checkbox shows whether the factory is subsidised
		var check: Label = subsidise_button.get_node_or_null(^"./subsidy_check")
		if check == null:
			check = Label.new()
			check.name = "subsidy_check"
			check.text = "✔"
			check.add_theme_color_override(&"font_color", Color(0.1, 0.55, 0.15))
			check.add_theme_color_override(&"font_outline_color", Color.BLACK)
			check.add_theme_constant_override(&"outline_size", 3)
			check.add_theme_font_size_override(&"font_size", 18)
			check.mouse_filter = Control.MOUSE_FILTER_IGNORE
			check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			check.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			subsidise_button.add_child(check)
		check.visible = factory[&"subsidised"]
		var active: bool = factory.get(&"subsidy_active", factory[&"subsidised"])
		# Grey when the factory is marked but the state does not pay for it in the chosen subsidy mode (a private factory)
		check.modulate = Color.WHITE if active else Color(0.6, 0.6, 0.6, 0.7)
		subsidise_button.modulate = Color.WHITE
		subsidise_button.tooltip_string = "%s\n%s: %s, %s: %s" % [
			tr("Subsidise") if not factory[&"subsidised"] else (
				tr("Remove the subsidy") if factory.get(&"subsidy_active", true) else "Снять отметку (государство не платит за частный завод в этом режиме)"
			),
			tr("State paid"), GUINode.float_to_string_dp(factory[&"subsidy"], 1),
			tr("Capitalists paid"), GUINode.float_to_string_dp(factory[&"private_cover"], 1),
		]

	var owner_button: _OwnerPie = panel.get_node_or_null(^"./owner_button")
	if owner_button:
		var state_share: float = factory[&"state_share"]
		var state_percent: int = roundi(state_share * 100.0)
		owner_button.visible = factory[&"level"] > 0
		owner_button.state_share = state_share
		owner_button.queue_redraw()
		owner_button.tooltip_text = "%s\n%s %d%%, %s %d%%\n%s: %s" % [
			tr("Owners of the factory (click for details)"),
			tr("State"), state_percent, tr("investors"), 100 - state_percent,
			tr("Factory funds"), GUINode.float_to_string_dp(factory[&"budget"], 0),
		]

	if _ownership_dialog and _ownership_dialog.is_showing(province_index, factory[&"building_type_index"]):
		_ownership_dialog.update_factory(factory)

	var level: int = factory[&"level"]
	var constructing: bool = factory[&"constructing"]
	var is_new: bool = constructing and level == 0
	var is_upgrading: bool = constructing and level > 0

	_set_label_text(GUINode.get_gui_label_from_node_and_path(panel, ^"./level"), str(level) if level > 0 else "")

	var output_button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(panel, ^"./output")
	if output_button:
		output_button.set_icon_index(int(factory[&"output_good_index"]) + _GOODS_ICON_OFFSET)
		output_button.tooltip_string = "%s\n%s" % [factory[&"name"], "Нажмите, чтобы открыть статистику завода"]

	# Inputs of the factory and which of them are running out
	var inputs: Array = factory[&"inputs"]
	for i: int in _MAX_INPUT_ICONS:
		var icon: GUIIcon = GUINode.get_gui_icon_from_node_and_path(panel, NodePath("./input_%d" % i))
		var lack_icon: GUIIcon = GUINode.get_gui_icon_from_node_and_path(panel, NodePath("./input_%d_lack2" % i))
		var has_input: bool = i < inputs.size() and not is_new
		if icon:
			icon.visible = has_input
			if has_input:
				_set_goods_icon(icon, inputs[i][&"good_index"])
		if lack_icon:
			lack_icon.visible = has_input and inputs[i][&"lacking"] and factory[&"open"] and level > 0

	# Employment
	var employment_icon: GUIIcon = GUINode.get_gui_icon_from_node_and_path(panel, ^"./employment_ratio")
	if employment_icon:
		employment_icon.visible = level > 0
		employment_icon.set_icon_index(
			clampi(roundi(factory[&"employment_ratio"] * _EMPLOYMENT_FRAMES), 0, _EMPLOYMENT_FRAMES) + 1
		)

	# Income of yesterday
	var profit: float = factory[&"profit"]
	var income_label: GUILabel = GUINode.get_gui_label_from_node_and_path(panel, ^"./income")
	if income_label:
		income_label.visible = level > 0
		_set_label_text(income_label, "§%s%s%s§!" % [
			"G" if profit >= 0 else "R", "+" if profit >= 0 else "", GUINode.float_to_string_dp(profit, 1),
		])
	var income_icon: Node = panel.get_node_or_null(^"./income_icon")
	if income_icon is CanvasItem:
		income_icon.visible = level > 0

	# Construction and expansion
	var in_progress_bg: Node = panel.get_node_or_null(^"./prod_factory_inprogress_bg")
	if in_progress_bg is CanvasItem:
		in_progress_bg.visible = is_new

	var build_bar: GUIProgressBar = GUINode.get_gui_progress_bar_from_node_and_path(panel, ^"./build_factory_progress")
	if build_bar:
		build_bar.visible = is_new
		build_bar.value = factory[&"construction_progress"]

	var upgrade_bar: GUIProgressBar = GUINode.get_gui_progress_bar_from_node_and_path(
		panel, ^"./upgrade_factory_progress"
	)
	if upgrade_bar:
		upgrade_bar.visible = is_upgrading
		upgrade_bar.value = factory[&"construction_progress"]
	var overlay: Node = panel.get_node_or_null(^"./progress_overlay_16_64")
	if overlay is CanvasItem:
		overlay.visible = is_upgrading

	var upgrade_button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(panel, ^"./upgrade")
	if upgrade_button:
		upgrade_button.visible = factory[&"can_expand"] and not constructing and level > 0
		upgrade_button.tooltip_string = "%s (%s)" % [tr("Expand"), GUINode.float_to_string_dp(factory[&"upgrade_cost"], 0)]

	panel.set_meta(&"priority", int(factory.get(&"priority", 1)))
	panel.set_meta(&"constructing", constructing)
	var delete_button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(panel, ^"./delete_factory")
	if delete_button:
		delete_button.visible = level > 0 and not constructing
		delete_button.tooltip_string = "Снести завод (бюджет вернётся владельцам)"
	var cancel_button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(panel, ^"./prod_cancel_progress")
	if cancel_button:
		cancel_button.visible = constructing
		cancel_button.tooltip_string = "Отменить строительство"

	var is_closed: bool = not factory[&"open"] and level > 0
	for closed_name: NodePath in [^"./closed_overlay", ^"./factory_closed_text"]:
		var closed_node: Node = panel.get_node_or_null(closed_name)
		if closed_node is CanvasItem:
			closed_node.visible = is_closed

	# The open/close button is only useful for finished factories
	var open_close: Node = panel.get_node_or_null(^"./open_close")
	if open_close is CanvasItem:
		open_close.visible = level > 0


# A click on the delete button arms it, the second one within a few seconds deletes the factory
func _on_delete_pressed(panel: Panel, button: GUIIconButton) -> void:
	if not panel.has_meta(&"building_type_index"):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(panel.get_meta(&"delete_armed_at", -100.0)) < _DELETE_CONFIRM_SECONDS:
		panel.set_meta(&"delete_armed_at", -100.0)
		button.modulate = Color.WHITE
		PlayerSingleton.delete_factory(panel.get_meta(&"province_index"), panel.get_meta(&"building_type_index"))
		return
	panel.set_meta(&"delete_armed_at", now)
	button.modulate = Color(1.6, 0.5, 0.5)
	get_tree().create_timer(_DELETE_CONFIRM_SECONDS).timeout.connect(
		func() -> void:
			if is_instance_valid(button):
				button.modulate = Color.WHITE
	)


# ---- Build dialog ----


func _setup_build_dialog() -> void:
	add_gui_element(_gui_file, "build_factory")
	_build_dialog = get_panel_from_nodepath(^"./build_factory")
	if not _build_dialog:
		return

	_build_dialog.hide()

	for hidden_name: NodePath in [^"./employment_info", ^"./goods_cost_info"]:
		var node: Node = _build_dialog.get_node_or_null(hidden_name)
		if node is CanvasItem:
			node.hide()

	_build_state_name = GUINode.get_gui_label_from_node_and_path(_build_dialog, ^"./state_name")
	_build_option_list = GUINode.get_gui_listbox_from_node(_build_dialog.get_node_or_null(^"./factory_type"))
	_build_output_icon = GUINode.get_gui_icon_from_node_and_path(_build_dialog, ^"./output")
	_build_building_name = GUINode.get_gui_label_from_node_and_path(_build_dialog, ^"./building_name")
	_build_output_amount = GUINode.get_gui_label_from_node_and_path(_build_dialog, ^"./output_amount")
	_build_description = GUINode.get_gui_label_from_node_and_path(_build_dialog, ^"./description_text")
	_build_workers = GUINode.get_gui_label_from_node_and_path(_build_dialog, ^"./needed_workers_count")
	_build_cost = GUINode.get_gui_label_from_node_and_path(_build_dialog, ^"./prod_cost")

	for i: int in _MAX_INPUT_ICONS:
		_build_input_icons.append(GUINode.get_gui_icon_from_node_and_path(_build_dialog, NodePath("./input_%d" % i)))
		_build_input_amounts.append(
			GUINode.get_gui_label_from_node_and_path(_build_dialog, NodePath("./input_%d_amount" % i))
		)

	var cancel_button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(_build_dialog, ^"./Cancel")
	if cancel_button:
		cancel_button.pressed.connect(_build_dialog.hide)

	_build_button = GUINode.get_gui_icon_button_from_node_and_path(_build_dialog, ^"./Build")
	if _build_button:
		_build_button.pressed.connect(_on_build_confirmed)


func _open_build_dialog(province_index: int) -> void:
	if not _build_dialog or not _states_by_province.has(province_index):
		return

	_build_province_index = province_index
	_build_selected = -1
	_refresh_build_dialog()
	_build_dialog.show()
	_build_dialog.move_to_front()


func _refresh_build_dialog() -> void:
	var state: Dictionary = _states_by_province.get(_build_province_index, {})
	if state.is_empty():
		_build_dialog.hide()
		return

	_build_options = state[&"buildable"]
	_set_label_text(_build_state_name, state[&"name"])

	if _build_selected >= _build_options.size():
		_build_selected = -1

	if _build_option_list:
		_build_option_list.clear_children(_build_options.size())
		while _build_option_list.get_child_count() < _build_options.size():
			var option_panel: Panel = GUINode.generate_gui_element(_gui_file, "new_factory_option")
			if not option_panel:
				break
			_build_option_list.add_child(option_panel)

		for i: int in mini(_build_option_list.get_child_count(), _build_options.size()):
			_setup_build_option(_build_option_list.get_child(i), i, _build_options[i])

	_update_build_details()


func _setup_build_option(option_panel: Panel, index: int, option: Dictionary) -> void:
	_set_label_text(GUINode.get_gui_label_from_node_and_path(option_panel, ^"./name"), option[&"name"])
	_set_label_text(
		GUINode.get_gui_label_from_node_and_path(option_panel, ^"./total_build_cost"),
		GUINode.float_to_string_dp(option[&"cost"], 0)
	)
	_set_label_text(
		GUINode.get_gui_label_from_node_and_path(option_panel, ^"./buildtime"),
		tr("{days} days").format({ "days": option[&"build_time_days"] })
	)
	_set_goods_icon(GUINode.get_gui_icon_from_node_and_path(option_panel, ^"./output"), option[&"output_good_index"])

	var select_button: GUIIconButton = GUINode.get_gui_icon_button_from_node_and_path(option_panel, ^"./bg")
	if select_button:
		# The panel is reused between refreshes, so only connect once
		if not option_panel.has_meta(&"connected"):
			option_panel.set_meta(&"connected", true)
			select_button.pressed.connect(
				func() -> void:
					_build_selected = int(option_panel.get_meta(&"option_index"))
					_update_build_details()
			)
	option_panel.set_meta(&"option_index", index)


func _update_build_details() -> void:
	var has_selection: bool = _build_selected >= 0 and _build_selected < _build_options.size()
	var option: Dictionary = _build_options[_build_selected] if has_selection else {}

	if _build_output_icon:
		_build_output_icon.visible = has_selection
		if has_selection:
			_set_goods_icon(_build_output_icon, option[&"output_good_index"])

	_set_label_text(_build_building_name, option.get(&"name", ""))
	_set_label_text(
		_build_output_amount,
		GUINode.float_to_string_dp(option[&"output_quantity"], 2) if has_selection else ""
	)

	var description: String = option.get(&"description", "")
	_set_label_text(_build_description, "" if description.ends_with("_desc") else description)
	_set_label_text(
		_build_workers,
		GUINode.int_to_string_suffixed(option[&"workforce"]) if has_selection else ""
	)
	_set_label_text(
		_build_cost,
		GUINode.float_to_string_dp(option[&"cost"], 0) if has_selection else ""
	)

	var inputs: Array = option.get(&"inputs", [])
	for i: int in _MAX_INPUT_ICONS:
		var has_input: bool = i < inputs.size()
		if _build_input_icons[i]:
			_build_input_icons[i].visible = has_input
			if has_input:
				_set_goods_icon(_build_input_icons[i], inputs[i][&"good_index"])
		if _build_input_amounts[i]:
			_build_input_amounts[i].visible = has_input
			if has_input:
				_set_label_text(_build_input_amounts[i], GUINode.float_to_string_dp(inputs[i][&"quantity"], 2))

	if _build_button:
		_build_button.disabled = not has_selection or not option[&"can_build"]


func _on_build_confirmed() -> void:
	if _build_selected < 0 or _build_selected >= _build_options.size():
		return

	var option: Dictionary = _build_options[_build_selected]
	if not option[&"can_build"]:
		return

	if PlayerSingleton.build_factory(_build_province_index, option[&"building_type_index"]):
		_build_dialog.hide()
