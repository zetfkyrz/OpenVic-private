extends Control

# Banners over the armies on the map: country, regiments, strength and organisation, battle icon and the progress of
# a siege. The banners of the player's armies can be selected by clicking on them, a right click on a province of the
# map then orders the selected armies to go there.

const _BANNER_SIZE: Vector2 = Vector2(78, 40)
const _BANNER_OFFSET: float = 22.0
# Height above the map the banner is anchored to, in world units
const _WORLD_HEIGHT: float = 0.35

const _COLOUR_PLAYER: Color = Color(0.2, 0.5, 0.9)
const _COLOUR_OTHER: Color = Color(0.55, 0.55, 0.55)
const _COLOUR_ENEMY: Color = Color(0.85, 0.25, 0.2)
const _COLOUR_SELECTED: Color = Color(1.0, 0.9, 0.2)
const _COLOUR_BATTLE: Color = Color(1.0, 0.25, 0.2)
const _COLOUR_STRENGTH: Color = Color(0.35, 0.8, 0.35)
const _COLOUR_ORGANISATION: Color = Color(0.4, 0.65, 1.0)
const _COLOUR_SIEGE: Color = Color(0.95, 0.65, 0.15)

class Banner:
	extends PanelContainer

	var key: String
	var style: StyleBoxFlat
	var title: Label
	var battle: Label
	var strength: ProgressBar
	var organisation: ProgressBar
	var siege: ProgressBar
	var data: Dictionary
	var slot: int = 0
	var slot_count: int = 1


var _map_view: MapView
var _banners: Dictionary[String, Banner] = {}
var _selected_key: String = ""


func setup(map_view: MapView) -> void:
	_map_view = map_view


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	GameSingleton.gamestate_updated.connect(_refresh)
	_refresh()


func has_selection() -> bool:
	return _banners.has(_selected_key) and _banners[_selected_key].data.get(&"is_player", false)


func clear_selection() -> void:
	if _selected_key.is_empty():
		return
	var previous: Banner = _banners.get(_selected_key)
	_selected_key = ""
	if previous:
		_update_style(previous)


# Orders every army of the selected banner to go to the province
func order_move(province_number: int) -> void:
	if not has_selection():
		return

	var ordered: int = 0
	for army_id: int in _banners[_selected_key].data[&"army_ids"]:
		if PlayerSingleton.move_army(army_id, province_number):
			ordered += 1

	if ordered == 0:
		push_warning("The armies cannot move to province %d" % province_number)


func _process(_delta: float) -> void:
	if not _map_view or _banners.is_empty():
		return

	var camera: Camera3D = _map_view._camera
	for banner: Banner in _banners.values():
		var world_position: Vector3 = _map_view._map_to_world_coords(banner.data[&"position"])
		world_position.y += _WORLD_HEIGHT

		if camera.is_position_behind(world_position):
			banner.hide()
			continue

		var screen_position: Vector2 = camera.unproject_position(world_position)
		var slot_shift: float = (banner.slot - (banner.slot_count - 1) / 2.0) * (_BANNER_SIZE.x + 2.0)
		banner.position = screen_position + Vector2(slot_shift - _BANNER_SIZE.x / 2.0, -_BANNER_SIZE.y - _BANNER_OFFSET)
		banner.show()


func _refresh() -> void:
	var units: Array = PlayerSingleton.get_map_units()

	# Slots of the banners in the same province, so that they do not overlap
	var counts: Dictionary[int, int] = {}
	for unit: Dictionary in units:
		counts[unit[&"province_number"]] = counts.get(unit[&"province_number"], 0) + 1
	var used: Dictionary[int, int] = {}

	var present: Dictionary[String, bool] = {}
	for unit: Dictionary in units:
		var province_number: int = unit[&"province_number"]
		var key: String = "%d_%d" % [province_number, unit[&"country_index"]]
		present[key] = true

		var banner: Banner = _banners.get(key)
		if not banner:
			banner = _create_banner(key)
			_banners[key] = banner
			add_child(banner)

		banner.data = unit
		banner.slot = used.get(province_number, 0)
		banner.slot_count = counts[province_number]
		used[province_number] = banner.slot + 1
		_update_banner(banner)

	for key: String in _banners.keys():
		if not present.has(key):
			var stale: Banner = _banners[key]
			_banners.erase(key)
			if key == _selected_key:
				_selected_key = ""
			remove_child(stale)
			stale.free()


func _create_banner(key: String) -> Banner:
	var banner := Banner.new()
	banner.key = key
	banner.custom_minimum_size = _BANNER_SIZE
	banner.size = _BANNER_SIZE
	banner.mouse_filter = Control.MOUSE_FILTER_STOP

	banner.style = StyleBoxFlat.new()
	banner.style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	banner.style.set_border_width_all(2)
	banner.style.set_corner_radius_all(3)
	banner.style.content_margin_left = 4
	banner.style.content_margin_right = 4
	banner.style.content_margin_top = 2
	banner.style.content_margin_bottom = 2
	banner.add_theme_stylebox_override(&"panel", banner.style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	banner.add_child(box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	box.add_child(row)

	banner.title = Label.new()
	banner.title.add_theme_font_size_override(&"font_size", 11)
	banner.title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(banner.title)

	banner.battle = Label.new()
	banner.battle.text = "БОЙ"
	banner.battle.add_theme_font_size_override(&"font_size", 11)
	banner.battle.add_theme_color_override(&"font_color", _COLOUR_BATTLE)
	row.add_child(banner.battle)

	banner.strength = _create_bar(_COLOUR_STRENGTH)
	box.add_child(banner.strength)
	banner.organisation = _create_bar(_COLOUR_ORGANISATION)
	box.add_child(banner.organisation)
	banner.siege = _create_bar(_COLOUR_SIEGE)
	banner.siege.custom_minimum_size.y = 6
	box.add_child(banner.siege)

	banner.gui_input.connect(_on_banner_input.bind(banner))
	return banner


func _create_bar(colour: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.01
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	bar.add_theme_stylebox_override(&"fill", fill)
	bar.add_theme_stylebox_override(&"background", background)
	return bar


func _update_banner(banner: Banner) -> void:
	var unit: Dictionary = banner.data

	banner.title.text = "%s  %d" % [str(unit[&"country_identifier"]), int(unit[&"regiments"])]
	banner.battle.visible = unit[&"in_combat"]
	banner.strength.value = unit[&"strength"]
	banner.organisation.value = unit[&"organisation"]

	var siege_progress: float = unit[&"siege_progress"]
	banner.siege.visible = siege_progress >= 0.0
	banner.siege.value = maxf(siege_progress, 0.0)

	var lines: PackedStringArray = [
		"%s: %d, %s: %d" % [tr("Armies"), unit[&"army_count"], tr("Regiments"), unit[&"regiments"]],
		"%s: %d%%" % [tr("Strength"), roundi(float(unit[&"strength"]) * 100.0)],
		"%s: %d%%" % [tr("Organisation"), roundi(float(unit[&"organisation"]) * 100.0)],
	]
	if unit[&"in_combat"]:
		lines.append(tr("In battle"))
	elif unit[&"moving"]:
		lines.append(tr("Marching"))
	if siege_progress >= 0.0:
		lines.append("%s: %d%%" % [tr("Siege"), roundi(siege_progress * 100.0)])
	if unit[&"is_player"]:
		lines.append(tr("Click to select, then right click a province to move"))
	banner.tooltip_text = "\n".join(lines)

	_update_style(banner)


func _update_style(banner: Banner) -> void:
	var colour: Color = _COLOUR_PLAYER if banner.data.get(&"is_player", false) else _COLOUR_OTHER
	if banner.data.get(&"in_combat", false):
		colour = _COLOUR_BATTLE
	if banner.key == _selected_key:
		colour = _COLOUR_SELECTED
	banner.style.border_color = colour


func _on_banner_input(event: InputEvent, banner: Banner) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if banner.data.get(&"is_player", false):
			var previous: Banner = _banners.get(_selected_key)
			_selected_key = banner.key if _selected_key != banner.key else ""
			if previous:
				_update_style(previous)
			_update_style(banner)
		banner.accept_event()
