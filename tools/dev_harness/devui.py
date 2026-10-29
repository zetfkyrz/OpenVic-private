import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
ROOT = os.path.join(os.environ.get('GAME_DIR', os.path.join(REPO, 'game')), 'src')
SHOTS = os.path.join(REPO, 'out', 'dev_shots').replace('\\', '/')
BODY = open(sys.argv[1], encoding='utf8').read()


def edit(rel, fn):
    p = ROOT + '\\' + rel
    s = open(p, encoding='utf8', newline='').read()
    nl = '\r\n' if '\r\n' in s else '\n'
    s = fn(s.replace('\r\n', '\n'))
    open(p, 'w', encoding='utf8', newline='').write(s.replace('\n', nl))


def start(t):
    a = '''	# change scene in a thread-safe way
	get_tree().change_scene_to_packed.call_deferred(GameMenuScene)
'''
    b = '''	# DEV CHECK (not committed)
	if FileAccess.file_exists("user://dev_check.txt"):
		await get_tree().process_frame
		GameSingleton.setup_game(0)
		get_tree().change_scene_to_file.call_deferred("res://src/Systems/Session/GameSession.tscn")
		return

	# change scene in a thread-safe way
	get_tree().change_scene_to_packed.call_deferred(GameMenuScene)
'''
    assert a in t
    return t.replace(a, b, 1)


def session(t):
    hook = '''# DEV CHECK (not committed) BEGIN
func _devshot(name: String) -> void:
	await get_tree().create_timer(1.0).timeout
	var image: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("__SHOTS__")
	image.save_png("__SHOTS__/" + name + ".png")
	print("DEVSHOT ", name)


func _dev_check() -> void:
	if not FileAccess.file_exists("user://dev_check.txt"):
		return
	await get_tree().create_timer(3.0).timeout
	print("DEVCHECK start country=", PlayerSingleton.get_player_country_identifier())
	_map_view._camera.position = _map_view._map_to_world_coords(PlayerSingleton.get_player_country_capital_position())
	_map_view._camera.position.y = _map_view._zoom_parchment_threshold * 0.6
	_map_view._zoom_target = _map_view._zoom_parchment_threshold * 0.6
__BODY__
	print("DEVCHECK done")
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()
# DEV CHECK END


'''.replace('__SHOTS__', SHOTS).replace('__BODY__', BODY)
    t = t.replace('func _process(_delta: float) -> void:', hook + 'func _process(_delta: float) -> void:', 1)
    t = t.replace('func _ready() -> void:\n', 'func _ready() -> void:\n\t_dev_check()\n', 1)
    return t


edit(r'Systems\Startup\GameStart.gd', start)
edit(r'Systems\Session\GameSession.gd', session)
print('hooks added')
