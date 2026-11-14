extends Node

const _UnitBanners: GDScript = preload("res://src/UI/Session/UnitBanners.gd")
const _ArmyPanel: GDScript = preload("res://src/UI/Session/ArmyPanel.gd")
const _DivisionTemplatesWindow: GDScript = preload("res://src/UI/Session/DivisionTemplatesWindow.gd")
const _ArmyTechWindow: GDScript = preload("res://src/UI/Session/ArmyTechWindow.gd")
const _CommandPanel: GDScript = preload("res://src/UI/Session/CommandPanel.gd")
const _PlanTools: GDScript = preload("res://src/Systems/Session/Map/PlanTools.gd")
const _TheatrePanel: GDScript = preload("res://src/UI/Session/TheatrePanel.gd")
const _NotificationFeed: GDScript = preload("res://src/UI/Session/NotificationFeed.gd")
const _FlagLinks: GDScript = preload("res://src/UI/Session/FlagLinks.gd")
const _RankingWindow: GDScript = preload("res://src/UI/Session/RankingWindow.gd")
const _SphereWindow: GDScript = preload("res://src/UI/Session/SphereWindow.gd")
const _ColonisationWindow: GDScript = preload("res://src/UI/Session/ColonisationWindow.gd")
const _PoliticsWindow: GDScript = preload("res://src/UI/Session/PoliticsWindow.gd")
const _MarketWindow: GDScript = preload("res://src/UI/Session/MarketWindow.gd")
const _PeaceWindow: GDScript = preload("res://src/UI/Session/PeaceWindow.gd")
const _FleetPanel: GDScript = preload("res://src/UI/Session/FleetPanel.gd")
const _RecruitmentWindow: GDScript = preload("res://src/UI/Session/RecruitmentWindow.gd")
const PerfProbe := preload("res://src/Utilities/PerfProbe.gd")
const _PerfDebugger := preload("res://src/UI/Session/PerfDebugger.gd")
const _EconomyDebugger := preload("res://src/UI/Session/EconomyDebugger.gd")
const _RECRUITMENT_KEY: Key = KEY_F7
const _SaveGameWindow := preload("res://src/UI/Session/SaveGameWindow.gd")
const _ReplayLoader := preload("res://src/Systems/Startup/ReplayLoader.gd")
# Autosave interval in real seconds
const _AUTOSAVE_SECONDS: float = 300.0

@export var _map_view: MapView
@export var _model_manager: ModelManager
@export var _game_session_menu: Control

var _unit_banners: Control
var _army_panel: Control
var _fleet_panel: Control
var _command_panel: Control
var _theatre_panel: Control
## The windows over the map that hide the panels of the command and of the theatres while they are open
var _blocking_windows: Array[Control] = []
var _screen_open: bool = false
var _panels_suppressed: bool = false
var _recruitment_window: Control
var _save_window: Control
var _replaying: bool = false
var _reloading: bool = false
var _replay_bar: ProgressBar


func _ready() -> void:
	if GameSingleton.start_game_session() != OK:
		push_error("Failed to setup game")

	# The negotiations of peace: open by themselves on an offer of the AI and from "offer peace" of the diplomacy (the group peace_window)
	var peace_window := Control.new()
	peace_window.set_script(_PeaceWindow)
	_game_session_menu.get_parent().add_child(peace_window)
	peace_window.add_to_group(&"peace_window")
	_blocking_windows.append(peace_window)
	var market_window := Control.new()
	market_window.set_script(_MarketWindow)
	_game_session_menu.get_parent().add_child(market_window)
	_blocking_windows.append(market_window)
	var politics_window := Control.new()
	politics_window.set_script(_PoliticsWindow)
	_game_session_menu.get_parent().add_child(politics_window)
	_blocking_windows.append(politics_window)
	var colonisation_window := Control.new()
	colonisation_window.set_script(_ColonisationWindow)
	_game_session_menu.get_parent().add_child(colonisation_window)
	_blocking_windows.append(colonisation_window)
	var sphere_window := Control.new()
	sphere_window.set_script(_SphereWindow)
	_game_session_menu.get_parent().add_child(sphere_window)
	_blocking_windows.append(sphere_window)
	var ranking_window := Control.new()
	ranking_window.set_script(_RankingWindow)
	_game_session_menu.get_parent().add_child(ranking_window)
	_blocking_windows.append(ranking_window)
	_save_window = Control.new()
	_save_window.set_script(_SaveGameWindow)
	_game_session_menu.get_parent().add_child(_save_window)
	_blocking_windows.append(_save_window)
	var replay_loader := Node.new()
	replay_loader.set_script(_ReplayLoader)
	add_child(replay_loader)
	replay_loader.load_confirmed.connect(_load_game)
	_save_window.load_requested.connect(replay_loader.request_load)
	var save_load_menu: Node = _game_session_menu.get_parent().get_node_or_null(^"SaveLoadMenu")
	if save_load_menu:
		save_load_menu.replay_load_requested.connect(replay_loader.request_load)
	var autosave_timer := Timer.new()
	autosave_timer.wait_time = _AUTOSAVE_SECONDS
	autosave_timer.autostart = true
	autosave_timer.timeout.connect(func() -> void:
		if not _replaying:
			_save_window.save_to(_SaveGameWindow.AUTOSAVE, "Автосохранение"))
	add_child(autosave_timer)
	var feed := VBoxContainer.new()
	feed.set_script(_NotificationFeed)
	_game_session_menu.get_parent().add_child(feed)

	# Banners over the armies (selection, strength, battles, sieges), under the windows of the interface
	_unit_banners = Control.new()
	_unit_banners.set_script(_UnitBanners)
	_unit_banners.setup(_map_view)
	var ui: Node = _game_session_menu.get_parent()
	ui.add_child(_unit_banners)
	ui.move_child(_unit_banners, 0)

	# Panel of the selected armies and the window of the recruitment of regiments (F7)
	_recruitment_window = Control.new()
	_recruitment_window.set_script(_RecruitmentWindow)
	ui.add_child(_recruitment_window)
	_blocking_windows.append(_recruitment_window)
	_army_panel = Control.new()
	_army_panel.set_script(_ArmyPanel)
	ui.add_child(_army_panel)
	_blocking_windows.append(_army_panel)
	_army_panel.set_recruitment_window(_recruitment_window)
	# Every flag of a country opens the diplomacy window with it (FlagLinks.gd)
	var flag_links := Node.new()
	flag_links.set_script(_FlagLinks)
	add_child(flag_links)
	var templates_window := Control.new()
	templates_window.set_script(_DivisionTemplatesWindow)
	ui.add_child(templates_window)
	_blocking_windows.append(templates_window)
	_army_panel.set_templates_window(templates_window)
	var tech_window := Control.new()
	tech_window.set_script(_ArmyTechWindow)
	ui.add_child(tech_window)
	_blocking_windows.append(tech_window)
	_army_panel.set_tech_window(tech_window)
	# The panel of the command (bottom, middle) and the panel of the theatres (right, above the middle)
	_theatre_panel = PanelContainer.new()
	_theatre_panel.set_script(_TheatrePanel)
	ui.add_child(_theatre_panel)
	_theatre_panel.setup(_map_view)
	# The tools of the plate of a field marshal draw the lines of his plan on the map
	var plan_tools := Node.new()
	plan_tools.set_script(_PlanTools)
	add_child(plan_tools)
	plan_tools.setup(_map_view)
	_command_panel = PanelContainer.new()
	_command_panel.set_script(_CommandPanel)
	ui.add_child(_command_panel)
	_command_panel.setup(_unit_banners, _theatre_panel, plan_tools)
	Events.NationManagementScreens.update_active_nation_management_screen.connect(
		func(screen: NationManagement.Screen) -> void: _screen_open = screen != NationManagement.Screen.NONE
	)
	_fleet_panel = Control.new()
	_fleet_panel.set_script(_FleetPanel)
	ui.add_child(_fleet_panel)
	_blocking_windows.append(_fleet_panel)
	_fleet_panel.set_recruitment_window(_recruitment_window)
	# A single click only selects, the panel of the army opens on a double click (and follows the selection while it is open)
	_unit_banners.selection_changed.connect(_on_units_selected.bind(false))
	_unit_banners.open_requested.connect(_on_units_selected.bind(true))

	# Performance debugger (F12)
	var perf_debugger := CanvasLayer.new()
	perf_debugger.set_script(_PerfDebugger)
	add_child(perf_debugger)

	# Economy debugger (X + Ъ): writes the economy of the game to files
	var economy_debugger := CanvasLayer.new()
	economy_debugger.set_script(_EconomyDebugger)
	add_child(economy_debugger)

	_model_manager.generate_units()
	_model_manager.generate_buildings()
	MusicManager.generate_playlist()
	MusicManager.select_next_song()
	# In game, the province selector uses the normal glove cursor.
	CursorManager.set_compat_cursor(&"normal", Input.CURSOR_IBEAM)

	if GameSingleton.has_pending_replay():
		_run_pending_replay.call_deferred()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PREDELETE:
			if not _reloading and GameSingleton.end_game_session() != OK:
				push_error("Failed to end game session")


func _process(_delta: float) -> void:
	if not _replaying:
		PerfProbe.begin("GameSession.update_clock")
		GameSingleton.update_clock()
		PerfProbe.end("GameSession.update_clock")
	_update_command_panels()


## The panels of the command and of the theatres give way to any other window or screen of the interface that is open
func _update_command_panels() -> void:
	var blocked: bool = _screen_open or (_game_session_menu != null and _game_session_menu.visible)
	if not blocked:
		for window: Control in _blocking_windows:
			if is_instance_valid(window) and window.visible:
				blocked = true
				break
	if blocked == _panels_suppressed:
		return
	_panels_suppressed = blocked
	if _command_panel != null:
		_command_panel.set_suppressed(blocked)
	if _theatre_panel != null:
		_theatre_panel.set_suppressed(blocked)


## Loads a save game: the game is set up again from the bookmark and the player country of the save, then the scene is
## reloaded and replays the saved actions (the simulation is deterministic, so the state is the same).
func _load_game(path: String) -> void:
	var header: Dictionary = GameSingleton.prepare_load_game(path)
	if not header.has("valid"):
		push_error("Failed to read the save game " + path)
		return
	if GameSingleton.end_game_session() != OK:
		push_error("Failed to end game session")
		return
	if GameSingleton.setup_game(int(header["bookmark"])) != OK \
			or not PlayerSingleton.set_player_country_by_identifier(header["country"]):
		push_error("Failed to set up the game from the save")
		return
	_reloading = true
	get_tree().reload_current_scene()


func _run_pending_replay() -> void:
	_replaying = true
	var layer := PanelContainer.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layer.custom_minimum_size = Vector2(420, 60)
	var box := VBoxContainer.new()
	layer.add_child(box)
	var label := Label.new()
	label.text = "Загрузка сохранения: восстановление хода игры…"
	box.add_child(label)
	_replay_bar = ProgressBar.new()
	_replay_bar.max_value = 1000
	box.add_child(_replay_bar)
	_game_session_menu.get_parent().add_child(layer)
	while true:
		var progress: int = GameSingleton.step_pending_replay(15)
		_replay_bar.value = progress
		if progress >= 1000:
			break
		await get_tree().process_frame
	layer.queue_free()
	_replaying = false


# Armies go to the panel of the army, fleets to the panel of the fleet
func _on_units_selected(group_ids: Array[int], open: bool) -> void:
	var army_ids: Array[int] = []
	var fleet_ids: Array[int] = []
	for group_id: int in group_ids:
		var details: Dictionary = PlayerSingleton.get_army_details(group_id)
		if details.is_empty():
			continue
		if details.get(&"is_navy", false):
			fleet_ids.append(group_id)
		else:
			army_ids.append(group_id)
	if open or _army_panel.visible:
		_army_panel.show_armies(army_ids)
	if open or _fleet_panel.visible:
		_fleet_panel.show_fleets(fleet_ids)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == _RECRUITMENT_KEY:
		if _recruitment_window.visible:
			_recruitment_window.close()
		else:
			_recruitment_window.open_for_province(0)
		get_viewport().set_input_as_handled()

# REQUIREMENTS:
# * SS-42


func _on_game_session_menu_button_pressed() -> void:
	_game_session_menu.visible = not _game_session_menu.visible


func _on_map_view_ready() -> void:
	# Set the camera's starting position
	_map_view._camera.position = _map_view._map_to_world_coords(
		# Start at the player country's capital position (when loading a save game in the lobby or
		# entering the actual game)
		PlayerSingleton.get_player_country_capital_position()
	)


func _on_map_view_province_hovered(province_number: int) -> void:
	_map_view.set_hovered_province_number(province_number)


func _on_map_view_province_unhovered() -> void:
	_map_view.unset_hovered_province()


func _on_map_view_province_clicked(province_number: int) -> void:
	_unit_banners.clear_selection()
	SoundManager.play_effect_compat("click")
	PlayerSingleton.set_selected_province_by_number(province_number)


func _on_map_view_province_right_clicked(province_number: int) -> void:
	# With an army selected a right click is a movement order
	if _unit_banners.has_selection():
		# Shift adds the province to the route of the armies, so the armies stay selected and keep following it
		_unit_banners.order_move(province_number, Input.is_key_pressed(KEY_SHIFT))
		return

	# TODO - open diplomacy screen on province owner or viewed country if province has no owner
	#Events.NationManagementScreens.open_nation_management_screen(NationManagement.Screen.DIPLOMACY)
	# (without a selection the right click does nothing: it used to make the player the owner of the province, a slip of the mouse while drawing a
	# front took his country away)
