extends Control

@export var _main_menu: Control
@export var _options_menu: Control
@export var _multiplayer_menu: Control
@export var _lobby_menu: Control
@export var _credits_menu: Control

const _ReplayLoader := preload("res://src/Systems/Startup/ReplayLoader.gd")

var _replay_loader: Node


func _ready() -> void:
	# "Continue" loads the newest save game (autosave, quick save, ...)
	_replay_loader = _ReplayLoader.new()
	add_child(_replay_loader)
	_replay_loader.load_confirmed.connect(func(path: String) -> void: _ReplayLoader.start_game(path, get_tree()))
	_main_menu.continue_button_pressed.connect(_on_main_menu_continue_button_pressed)


func _on_main_menu_continue_button_pressed() -> void:
	var path: String = _ReplayLoader.latest_save_path()
	if path.is_empty():
		push_warning("There is no save game to continue.")
		return
	_replay_loader.request_load(path)


# REQUIREMENTS
# * SS-10


func _on_main_menu_new_game_button_pressed() -> void:
	_lobby_menu.show()
	_main_menu.hide()

# REQUIREMENTS
# * SS-6
# * UIFUN-5


func _on_main_menu_options_button_pressed() -> void:
	_options_menu.show()
	_main_menu.hide()


func _on_options_menu_back_button_pressed() -> void:
	_main_menu.show()
	_options_menu.hide()


func _on_lobby_menu_back_button_pressed() -> void:
	_main_menu.show()
	_lobby_menu.hide()


func _on_credits_menu_close_requested() -> void:
	_credits_menu.hide()
	_main_menu.show()


func _on_main_menu_credits_button_pressed() -> void:
	_credits_menu.show()
	_main_menu.hide()


func _on_multiplayer_menu_back_button_pressed() -> void:
	_multiplayer_menu.hide()
	_main_menu.show()


func _on_main_menu_multiplayer_button_pressed() -> void:
	_multiplayer_menu.show()
	_main_menu.hide()
