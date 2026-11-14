extends Control
## The icons of the spheres on the map "Сферы" (version 95, docs/PLAN_SPHERES.md, stage S5): the icon of every sphere over the capital of its
## leader while that map mode is on. Under the windows of the interface, like the banners of the armies.

const SphereIcons := preload("res://src/UI/Session/SphereIcons.gd")

const _MAPMODE: String = "mapmode_sphere"
const _ICON_SIZE: float = 64.0
const _MIN_SCALE: float = 0.45
const _MAX_SCALE: float = 1.6
## The spheres are read again at most this often (seconds) while the game state changes
const _REFRESH_SECONDS: float = 1.0

var _map_view: MapView
var _icons: Dictionary = {} # leader tag -> { rect: TextureRect, position: Vector2 (the map) }
var _active: bool = false
var _dirty: bool = true
var _since_refresh: float = 0.0


func setup(map_view: MapView) -> void:
	_map_view = map_view


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameSingleton.mapmode_changed.connect(_on_mapmode_changed)
	GameSingleton.gamestate_updated.connect(func() -> void: _dirty = true)
	_on_mapmode_changed(GameSingleton.get_current_mapmode_index())


func _on_mapmode_changed(index: int) -> void:
	_active = GameSingleton.get_mapmode_identifier(index) == _MAPMODE
	visible = _active
	if _active:
		_refresh()


func _refresh() -> void:
	_dirty = false
	_since_refresh = 0.0
	var seen: Dictionary = {}
	for sphere: Dictionary in PlayerSingleton.get_world_spheres():
		if not sphere.get(&"has_capital", false):
			continue
		var tag: String = sphere[&"leader_tag"]
		seen[tag] = true
		if not _icons.has(tag):
			var rect := TextureRect.new()
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(rect)
			_icons[tag] = { &"rect": rect, &"position": Vector2.ZERO }
		var icon: Dictionary = _icons[tag]
		(icon[&"rect"] as TextureRect).texture = SphereIcons.get_texture(sphere)
		icon[&"position"] = sphere[&"leader_capital"]
	for tag: String in _icons.keys():
		if not seen.has(tag):
			(_icons[tag][&"rect"] as TextureRect).queue_free()
			_icons.erase(tag)


func _process(delta: float) -> void:
	if not _active or _map_view == null:
		return
	_since_refresh += delta
	if _dirty and _since_refresh >= _REFRESH_SECONDS:
		_refresh()
	var camera: Camera3D = _map_view._camera
	var icon_scale: float = clampf(_map_view._zoom_parchment_threshold * 1.2 / maxf(camera.position.y, 0.001), _MIN_SCALE, _MAX_SCALE)
	var side: float = _ICON_SIZE * icon_scale
	for icon: Dictionary in _icons.values():
		var rect: TextureRect = icon[&"rect"]
		var world_position: Vector3 = _map_view._map_to_ground_coords(icon[&"position"])
		if camera.is_position_behind(world_position):
			rect.hide()
			continue
		var screen: Vector2 = camera.unproject_position(world_position)
		rect.size = Vector2(side, side)
		rect.position = screen - Vector2(side / 2.0, side + 4.0)
		rect.show()
