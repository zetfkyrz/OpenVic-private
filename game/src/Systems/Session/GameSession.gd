extends Node

const _WarPanel: GDScript = preload("res://src/UI/Session/WarPanel.gd")
const _UnitBanners: GDScript = preload("res://src/UI/Session/UnitBanners.gd")

@export var _map_view: MapView
@export var _model_manager: ModelManager
@export var _game_session_menu: Control

var _unit_banners: Control


func _ready() -> void:
	if GameSingleton.start_game_session() != OK:
		push_error("Failed to setup game")

	# Wars, armies and fronts panel (F6)
	var war_panel: PanelContainer = PanelContainer.new()
	war_panel.set_script(_WarPanel)
	_game_session_menu.get_parent().add_child(war_panel)

	# Banners over the armies (selection, strength, battles, sieges), under the windows of the interface
	_unit_banners = Control.new()
	_unit_banners.set_script(_UnitBanners)
	_unit_banners.setup(_map_view)
	var ui: Node = _game_session_menu.get_parent()
	ui.add_child(_unit_banners)
	ui.move_child(_unit_banners, 0)

	_model_manager.generate_units()
	_model_manager.generate_buildings()
	MusicManager.generate_playlist()
	MusicManager.select_next_song()
	# In game, the province selector uses the normal glove cursor.
	CursorManager.set_compat_cursor(&"normal", Input.CURSOR_IBEAM)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PREDELETE:
			if GameSingleton.end_game_session() != OK:
				push_error("Failed to end game session")


func _process(_delta: float) -> void:
	GameSingleton.update_clock()

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
	PlayerSingleton.set_selected_province_by_number(province_number)


func _on_map_view_province_right_clicked(province_number: int) -> void:
	# With an army selected a right click is a movement order
	if _unit_banners.has_selection():
		# Shift adds the province to the route of the armies, so the armies stay selected and keep following it
		_unit_banners.order_move(province_number, Input.is_key_pressed(KEY_SHIFT))
		return

	# TODO - open diplomacy screen on province owner or viewed country if province has no owner
	#Events.NationManagementScreens.open_nation_management_screen(NationManagement.Screen.DIPLOMACY)
	PlayerSingleton.set_player_country_by_province_number(province_number)
