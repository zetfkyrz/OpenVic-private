extends Node
## Prepares the relief and the water layers of the map and feeds the theme into the shader of the map.
##
## The heavy part is done once (and again when the map quality changes): two passes of a SubViewport bake the heights of
## the terrain (MapBakeHeight.gdshader) and the lighting of the relief (MapBakeLight.gdshader) into textures that the map
## shader only samples. The look comes from the MapTheme resource, the map quality setting picks the cost.

const _HeightShader: Shader = preload("res://src/Systems/Session/Map/MapBakeHeight.gdshader")
const _LightShader: Shader = preload("res://src/Systems/Session/Map/MapBakeLight.gdshader")
const _THEME_PATH: String = "res://src/Systems/Session/Map/map_theme.tres"
const _NOISE_PATH: StringName = &"map/terrain/noise-2d.dds"
const _SEA_NORMAL_PATH: StringName = &"map/terrain/sea_normal.dds"

# Cost of the quality levels: size of the baked textures relative to the map and the number of border samples
const _BAKE_SCALE: Array[float] = [0.0, 0.5, 1.0]
const _BORDER_TAPS: Array[int] = [6, 8, 16]

var _material: ShaderMaterial
var _theme: Resource
var _quality: int = -1
var _viewports: Array[SubViewport] = []
var _bake_serial: int = 0
var _watch_timer: Timer


func setup(material: ShaderMaterial) -> void:
	_material = material
	_theme = load(_THEME_PATH)
	_apply_theme()
	_apply_quality(_get_quality_setting())

	# The quality can be changed in the options at any time
	_watch_timer = Timer.new()
	_watch_timer.wait_time = 0.5
	_watch_timer.autostart = true
	_watch_timer.timeout.connect(
		func() -> void:
			var wanted: int = _get_quality_setting()
			if wanted != _quality:
				_apply_quality(wanted)
	)
	add_child(_watch_timer)


func _get_quality_setting() -> int:
	return clampi(int(GameSettings.get_setting(GameSettings.VIDEO_MAP_QUALITY).value()), 0, 2)


## Sets the uniforms of the shader that come from the theme
func _apply_theme() -> void:
	var t: Resource = _theme
	var m: ShaderMaterial = _material
	m.set_shader_parameter(&"border_colour", t.border_colour)
	m.set_shader_parameter(&"border_opacity", t.border_opacity)
	m.set_shader_parameter(&"border_width", t.border_width)
	m.set_shader_parameter(&"glow_width", t.glow_width)
	m.set_shader_parameter(&"glow_opacity", t.glow_opacity)
	m.set_shader_parameter(&"coast_colour", t.coast_colour)
	m.set_shader_parameter(&"coast_opacity", t.coast_opacity)
	m.set_shader_parameter(&"coast_width", t.coast_width)
	m.set_shader_parameter(&"relief_ambient", t.ambient)
	m.set_shader_parameter(&"relief_diffuse", t.diffuse)
	m.set_shader_parameter(&"sun_colour", Vector3(t.sun_colour.r, t.sun_colour.g, t.sun_colour.b))
	m.set_shader_parameter(&"shadow_strength", t.shadow_strength)
	m.set_shader_parameter(&"ao_strength", t.ao_strength)
	m.set_shader_parameter(&"shallow_colour", Vector3(t.shallow_colour.r, t.shallow_colour.g, t.shallow_colour.b))
	m.set_shader_parameter(&"deep_colour", Vector3(t.deep_colour.r, t.deep_colour.g, t.deep_colour.b))
	m.set_shader_parameter(&"depth_strength", t.depth_strength)
	m.set_shader_parameter(&"foam_colour", Vector3(t.foam_colour.r, t.foam_colour.g, t.foam_colour.b))
	m.set_shader_parameter(&"foam_opacity", t.foam_opacity)
	m.set_shader_parameter(&"wave_speed", t.wave_speed)
	m.set_shader_parameter(&"specular_strength", t.specular_strength)


func _apply_quality(quality: int) -> void:
	_quality = quality
	_bake_serial += 1
	_clear_viewports()

	_material.set_shader_parameter(&"quality", quality)
	_material.set_shader_parameter(&"border_taps", _BORDER_TAPS[quality])
	if quality == 0:
		# Plain map: no baked textures, only the smooth borders
		_material.set_shader_parameter(&"relief_amount", 0.0)
		return
	_bake(quality, _bake_serial)


func _clear_viewports() -> void:
	for viewport: SubViewport in _viewports:
		if is_instance_valid(viewport):
			viewport.queue_free()
	_viewports.clear()


func _make_pass(size: Vector2i, shader_material: ShaderMaterial, update_mode: int) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = update_mode
	var rect := ColorRect.new()
	rect.size = Vector2(size)
	rect.material = shader_material
	viewport.add_child(rect)
	add_child(viewport)
	_viewports.append(viewport)
	return viewport


func _bake(quality: int, serial: int) -> void:
	var map_size := Vector2(GameSingleton.get_map_width(), GameSingleton.get_map_height())
	var bake_size := Vector2i((map_size * _BAKE_SCALE[quality]).round())
	var t: Resource = _theme

	# The shader materials get the province shape texture the same way as the map shader
	var height_material := ShaderMaterial.new()
	height_material.shader = _HeightShader
	GameLoader.ShaderManager.set_up_shader(height_material, false)
	height_material.set_shader_parameter(&"terrain_heights", GameSingleton.get_terrain_height_table())
	height_material.set_shader_parameter(&"noise_tex", AssetManager.get_texture(_NOISE_PATH))
	# The baked texture is smaller than the map: the blur radii are given in map pixels
	height_material.set_shader_parameter(&"map_pixels", map_size)
	height_material.set_shader_parameter(&"terrain_blur", t.terrain_blur)
	height_material.set_shader_parameter(&"height_detail", t.height_detail)
	height_material.set_shader_parameter(&"shore_distance", t.shore_distance)
	var height_pass: SubViewport = _make_pass(bake_size, height_material, SubViewport.UPDATE_ONCE)

	await RenderingServer.frame_post_draw
	if serial != _bake_serial:
		return

	var light_material := ShaderMaterial.new()
	light_material.shader = _LightShader
	light_material.set_shader_parameter(&"height_tex", height_pass.get_texture())
	light_material.set_shader_parameter(&"map_pixels", map_size)
	light_material.set_shader_parameter(&"height_scale", t.height_scale)
	light_material.set_shader_parameter(&"normal_strength", t.normal_strength)
	light_material.set_shader_parameter(&"ao_radius", t.ao_radius)
	light_material.set_shader_parameter(&"shadow_length", t.shadow_length)
	light_material.set_shader_parameter(&"coast_cliff", t.coast_cliff)
	var azimuth: float = deg_to_rad(t.sun_azimuth)
	light_material.set_shader_parameter(&"sun_direction", Vector2(sin(azimuth), -cos(azimuth)))
	light_material.set_shader_parameter(&"sun_elevation", deg_to_rad(t.sun_elevation_far))
	var light_pass: SubViewport = _make_pass(bake_size, light_material, SubViewport.UPDATE_ONCE)

	await RenderingServer.frame_post_draw
	if serial != _bake_serial:
		return

	_material.set_shader_parameter(&"height_tex", height_pass.get_texture())
	_material.set_shader_parameter(&"relief_tex", light_pass.get_texture())
	_material.set_shader_parameter(&"sea_normal_tex", AssetManager.get_texture(_SEA_NORMAL_PATH))
	_material.set_shader_parameter(&"relief_amount", 1.0)


## Updates the lighting with the camera: the relief is strongest when zoomed in, fades out towards the parchment map
## and the sun moves a little with the camera. `zoom` is 0 far away and 1 close, `camera_uv` the map position (0..1).
func update_view(zoom: float, camera_uv: Vector2, border_scale: float) -> void:
	if _material == null or _theme == null:
		return
	var t: Resource = _theme
	_material.set_shader_parameter(&"relief_zoom", zoom * t.relief_strength)
	_material.set_shader_parameter(&"border_scale", border_scale)

	var azimuth: float = deg_to_rad(t.sun_azimuth + (camera_uv.x - 0.5) * 2.0 * t.light_sway)
	var elevation: float = deg_to_rad(lerpf(t.sun_elevation_far, t.sun_elevation_near, zoom) + (camera_uv.y - 0.5) * t.light_sway * 0.5)
	var horizontal := Vector2(sin(azimuth), -cos(azimuth)) * cos(elevation)
	_material.set_shader_parameter(&"sun_vector", Vector3(horizontal.x, horizontal.y, sin(elevation)))
