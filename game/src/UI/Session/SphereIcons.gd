extends RefCounted
## (loaded by preload as SphereIcons in the scripts that use it, no class_name: the game also runs without the editor scanning the classes)
## The icons of the spheres (version 95, docs/PLAN_SPHERES.md, stage S5). The simulation keeps two numbers of an icon (Sphere::icon, icon_extra);
## this script makes the picture of 256x256 from them and keeps it in a cache.
## icon: bits 0-1 the kind: 0 none (the default: an emblem of the own set chosen by the leader), 1 the own set, 2 the pieces of Victoria 3,
##   3 an own file; the own set: bits 2-9 the emblem; Victoria 3: bits 2-4 the pattern of the shield, 5-12 the centre, 13-15 the frame,
##   16-18 the top, 19-21 the sides (these three: 0 none, else the index + 1)
## icon_extra: bits 0-4 the 2nd colour of the shield, 5-9 the 3rd, 10-14 the colour of the emblem (indices of PALETTE); the 1st colour of the
##   shield is the colour of the sphere
## The own set: ov_data/gfx/spheres (shield.png, shield_inner.png, emblems/*.png: white on transparent, tinted here). Victoria 3 is read from
## its own folder when it is installed (user://vic3.cfg or the Steam libraries), nothing of it is copied: gfx/coat_of_arms/colored_emblems and
## textured_emblems, the list of the pieces common/power_bloc_coa_pieces. An own file: user://sphere_icons/<tag of the leader>.png (this
## computer only).

const SIZE: int = 256
const KIND_DEFAULT: int = 0
const KIND_SET: int = 1
const KIND_VIC3: int = 2
const KIND_FILE: int = 3

const PALETTE: PackedColorArray = [
	Color8(240, 200, 60), Color8(250, 250, 245), Color8(25, 25, 30), Color8(200, 30, 30), Color8(120, 20, 25), Color8(235, 120, 30),
	Color8(30, 60, 160), Color8(20, 30, 90), Color8(90, 160, 230), Color8(30, 120, 60), Color8(20, 70, 40), Color8(120, 190, 90),
	Color8(110, 40, 140), Color8(200, 90, 160), Color8(120, 80, 40), Color8(190, 160, 110), Color8(130, 130, 135), Color8(70, 70, 75),
	Color8(30, 150, 150), Color8(170, 40, 70), Color8(250, 220, 120), Color8(60, 100, 200), Color8(160, 110, 30), Color8(240, 240, 120),
]
const PIECE_PATTERN: String = "shield_pattern"
const PIECE_CENTER: String = "center"
const PIECE_FRAME: String = "shield_frame"
const PIECE_TOP: String = "top"
const PIECE_SIDE: String = "side"
# The places of the pieces of Victoria 3 on the canvas: the size and the centre
const _LAYOUT: Dictionary = {
	PIECE_PATTERN: [150, Vector2i(128, 132)],
	PIECE_CENTER: [96, Vector2i(128, 128)],
	PIECE_FRAME: [188, Vector2i(128, 134)],
	PIECE_TOP: [150, Vector2i(128, 40)],
	PIECE_SIDE: [120, Vector2i(40, 140)],
}
const _VIC3_CONFIG: String = "user://vic3.cfg"
const _FILE_FOLDER: String = "user://sphere_icons"

static var _cache: Dictionary = {}
static var _set_loaded: bool = false
static var _set_emblems: Array[Image] = []
static var _set_names: PackedStringArray = []
static var _shield: Image
static var _shield_inner: Image
static var _vic3_checked: bool = false
static var _vic3_path: String = ""
static var _vic3_pieces: Dictionary = {} # piece -> PackedStringArray of the file names, in the order of the list of Victoria 3
static var _piece_cache: Dictionary = {} # "<file>/<size>" -> Image (raw, the colours not applied)


# ---- the numbers

static func encode_set(emblem: int, emblem_colour: int) -> PackedInt64Array:
	return PackedInt64Array([KIND_SET | (clampi(emblem, 0, 255) << 2), (clampi(emblem_colour, 0, 31) << 10)])


## frame, top and side: -1 none
static func encode_vic3(pattern: int, center: int, frame: int, top: int, side: int, colour2: int, colour3: int, emblem_colour: int) -> PackedInt64Array:
	var icon: int = KIND_VIC3 | (clampi(pattern, 0, 7) << 2) | (clampi(center, 0, 255) << 5) | (clampi(frame + 1, 0, 7) << 13) \
		| (clampi(top + 1, 0, 7) << 16) | (clampi(side + 1, 0, 7) << 19)
	var extra: int = clampi(colour2, 0, 31) | (clampi(colour3, 0, 31) << 5) | (clampi(emblem_colour, 0, 31) << 10)
	return PackedInt64Array([icon, extra])


static func encode_file() -> PackedInt64Array:
	return PackedInt64Array([KIND_FILE, 0])


## { kind, emblem, pattern, center, frame, top, side (-1: none), colour2, colour3, emblem_colour }
static func decode(icon: int, extra: int) -> Dictionary:
	return {
		&"kind": icon & 3,
		&"emblem": (icon >> 2) & 255,
		&"pattern": (icon >> 2) & 7,
		&"center": (icon >> 5) & 255,
		&"frame": ((icon >> 13) & 7) - 1,
		&"top": ((icon >> 16) & 7) - 1,
		&"side": ((icon >> 19) & 7) - 1,
		&"colour2": extra & 31,
		&"colour3": (extra >> 5) & 31,
		&"emblem_colour": (extra >> 10) & 31,
	}


static func palette_colour(index: int) -> Color:
	return PALETTE[clampi(index, 0, PALETTE.size() - 1)]


# ---- the pictures

## The icon of a sphere (a dictionary of PlayerSingleton.get_sphere_info / get_world_spheres)
static func get_texture(sphere: Dictionary) -> Texture2D:
	var colour: Color = sphere.get(&"colour", Color.GRAY)
	return get_texture_for(int(sphere.get(&"icon", 0)), int(sphere.get(&"icon_extra", 0)), colour, String(sphere.get(&"leader_tag", "")))


static func get_texture_for(icon: int, extra: int, colour: Color, tag: String) -> Texture2D:
	var key: String = "%d/%d/%s/%s" % [icon, extra, colour.to_html(false), tag]
	if _cache.has(key):
		return _cache[key]
	var image: Image = make_image(icon, extra, colour, tag)
	var texture: Texture2D = ImageTexture.create_from_image(image) if image != null else null
	_cache[key] = texture
	return texture


static func clear_cache() -> void:
	_cache.clear()


static func make_image(icon: int, extra: int, colour: Color, tag: String) -> Image:
	var parts: Dictionary = decode(icon, extra)
	var image: Image = null
	match int(parts[&"kind"]):
		KIND_SET:
			image = _make_set_image(int(parts[&"emblem"]), colour, palette_colour(int(parts[&"emblem_colour"])))
		KIND_VIC3:
			image = _make_vic3_image(parts, colour)
		KIND_FILE:
			image = load_file_image(tag)
	if image == null:
		image = _make_default_image(colour, tag)
	return image


## The default icon (a sphere whose leader chose none, or whose pieces are not on this computer): an emblem of the own set by the leader
static func _make_default_image(colour: Color, tag: String) -> Image:
	_load_set()
	if _set_emblems.is_empty():
		var empty: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		empty.fill(colour)
		return empty
	var emblem: int = absi(hash(tag)) % _set_emblems.size()
	var emblem_colour: Color = Color8(250, 250, 245) if colour.get_luminance() < 0.6 else Color8(25, 25, 30)
	return _make_set_image(emblem, colour, emblem_colour)


# ---- the own set

static func set_folder() -> String:
	var root: String = GameSingleton.get_builtin_data_path()
	return root.path_join("gfx/spheres") if root != "" else ""


static func _load_set() -> void:
	if _set_loaded:
		return
	_set_loaded = true
	var folder: String = set_folder()
	if folder == "":
		return
	_shield = Image.load_from_file(folder.path_join("shield.png")) if FileAccess.file_exists(folder.path_join("shield.png")) else null
	_shield_inner = Image.load_from_file(folder.path_join("shield_inner.png")) if FileAccess.file_exists(folder.path_join("shield_inner.png")) else null
	var names: PackedStringArray = DirAccess.get_files_at(folder.path_join("emblems"))
	names.sort()
	for file_name: String in names:
		if not file_name.to_lower().ends_with(".png"):
			continue
		var emblem: Image = Image.load_from_file(folder.path_join("emblems").path_join(file_name))
		if emblem == null:
			continue
		emblem.convert(Image.FORMAT_RGBA8)
		_set_emblems.append(emblem)
		_set_names.append(file_name.get_basename())
	for image: Image in [_shield, _shield_inner]:
		if image != null:
			image.convert(Image.FORMAT_RGBA8)
			if image.get_size() != Vector2i(SIZE, SIZE):
				image.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)


static func get_set_count() -> int:
	_load_set()
	return _set_emblems.size()


## The emblems of the own set, white (for the lists of the constructor)
static func get_set_emblem(index: int) -> Image:
	_load_set()
	return _set_emblems[index] if index >= 0 and index < _set_emblems.size() else null


static func _make_set_image(emblem: int, colour: Color, emblem_colour: Color) -> Image:
	_load_set()
	var canvas: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	if _shield != null:
		_blend(canvas, tint(_shield, colour.darkened(0.65)), Vector2i.ZERO)
	if _shield_inner != null:
		_blend(canvas, tint(_shield_inner, colour), Vector2i.ZERO)
	if emblem >= 0 and emblem < _set_emblems.size():
		var picture: Image = _set_emblems[emblem].duplicate()
		picture.resize(150, 150, Image.INTERPOLATE_LANCZOS)
		_blend(canvas, tint(picture, emblem_colour), Vector2i(53, 58))
	return canvas


## A copy of a white picture in the colour (the alpha stays)
static func tint(image: Image, colour: Color) -> Image:
	var copy: Image = image.duplicate()
	copy.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = copy.get_data()
	var r: int = colour.r8
	var g: int = colour.g8
	var b: int = colour.b8
	for i: int in range(0, data.size(), 4):
		data[i] = data[i] * r / 255
		data[i + 1] = data[i + 1] * g / 255
		data[i + 2] = data[i + 2] * b / 255
	return Image.create_from_data(copy.get_width(), copy.get_height(), false, Image.FORMAT_RGBA8, data)


static func _blend(canvas: Image, picture: Image, at: Vector2i) -> void:
	canvas.blend_rect(picture, Rect2i(Vector2i.ZERO, picture.get_size()), at)


# ---- Victoria 3

## The folder "game" of Victoria 3 ("" when it is not installed or not found)
static func vic3_path() -> String:
	if _vic3_checked:
		return _vic3_path
	_vic3_checked = true
	var candidates: PackedStringArray = []
	var config := ConfigFile.new()
	if config.load(_VIC3_CONFIG) == OK:
		candidates.append(String(config.get_value("victoria_3", "base_path", "")))
	for steam: String in ["C:/Program Files (x86)/Steam", "C:/Program Files/Steam"]:
		candidates.append(steam.path_join("steamapps/common/Victoria 3"))
		var vdf: String = steam.path_join("steamapps/libraryfolders.vdf")
		if FileAccess.file_exists(vdf):
			var regex := RegEx.create_from_string("\"path\"\\s+\"([^\"]+)\"")
			for found: RegExMatch in regex.search_all(FileAccess.get_file_as_string(vdf)):
				candidates.append(found.get_string(1).replace("\\\\", "/").path_join("steamapps/common/Victoria 3"))
	for candidate: String in candidates:
		var game: String = _vic3_game_folder(candidate)
		if game != "":
			_vic3_path = game
			break
	return _vic3_path


## The folder "game" in the folder given (the folder of Victoria 3 or its "game"), "" if it has no emblems
static func _vic3_game_folder(folder: String) -> String:
	if folder == "":
		return ""
	for game: String in [folder, folder.path_join("game")]:
		if DirAccess.dir_exists_absolute(game.path_join("gfx/coat_of_arms/colored_emblems")):
			return game
	return ""


## Sets the folder of Victoria 3 (the player gives it): false if there are no emblems there
static func set_vic3_path(folder: String) -> bool:
	var game: String = _vic3_game_folder(folder.strip_edges().replace("\\", "/"))
	if game == "":
		return false
	var config := ConfigFile.new()
	config.load(_VIC3_CONFIG)
	config.set_value("victoria_3", "base_path", game)
	config.save(_VIC3_CONFIG)
	_vic3_path = game
	_vic3_checked = true
	_vic3_pieces.clear()
	_piece_cache.clear()
	clear_cache()
	return true


## The file names of a kind of the pieces of the power blocs (in the order of Victoria 3)
static func vic3_pieces(piece: String) -> PackedStringArray:
	if _vic3_pieces.is_empty() and vic3_path() != "":
		for key: String in [PIECE_PATTERN, PIECE_CENTER, PIECE_FRAME, PIECE_TOP, PIECE_SIDE]:
			_vic3_pieces[key] = PackedStringArray()
		var folder: String = vic3_path().path_join("common/power_bloc_coa_pieces")
		var files: PackedStringArray = DirAccess.get_files_at(folder)
		files.sort()
		var entry := RegEx.create_from_string("([\\w\\.-]+\\.dds)\\s*=\\s*\\{([^}]*)\\}")
		var piece_regex := RegEx.create_from_string("piece\\s*=\\s*(\\w+)")
		for file_name: String in files:
			if not file_name.ends_with(".txt"):
				continue
			for found: RegExMatch in entry.search_all(FileAccess.get_file_as_string(folder.path_join(file_name))):
				var kind: RegExMatch = piece_regex.search(found.get_string(2))
				if kind != null and _vic3_pieces.has(kind.get_string(1)):
					var names: PackedStringArray = _vic3_pieces[kind.get_string(1)]
					if not names.has(found.get_string(1)):
						names.append(found.get_string(1))
						_vic3_pieces[kind.get_string(1)] = names
	return _vic3_pieces.get(piece, PackedStringArray())


## A piece of Victoria 3 at the size (the raw picture: the masks of the colours of a coloured piece are not applied); null if missing
static func vic3_piece(file_name: String, size: int) -> Image:
	var key: String = "%s/%d" % [file_name, size]
	if _piece_cache.has(key):
		return _piece_cache[key]
	var image: Image = null
	for folder: String in ["gfx/coat_of_arms/colored_emblems", "gfx/coat_of_arms/textured_emblems"]:
		var path: String = vic3_path().path_join(folder).path_join(file_name)
		if FileAccess.file_exists(path):
			image = _load_dds(path)
			break
	if image != null:
		image.resize(size, size, Image.INTERPOLATE_LANCZOS)
	_piece_cache[key] = image
	return image


## A DDS of Victoria 3: by Godot, else (an uncompressed BGRA one it does not take) read here
static func _load_dds(path: String) -> Image:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() < 128:
		return null
	var loaded := Image.new()
	if loaded.load_dds_from_buffer(bytes) == OK and not loaded.is_empty():
		if loaded.is_compressed():
			loaded.decompress()
		loaded.clear_mipmaps()
		loaded.convert(Image.FORMAT_RGBA8)
		return loaded
	var height: int = bytes.decode_u32(12)
	var width: int = bytes.decode_u32(16)
	var fourcc: int = bytes.decode_u32(84)
	var bits: int = bytes.decode_u32(88)
	if fourcc == 0 and bits == 32 and bytes.size() >= 128 + width * height * 4:
		var data: PackedByteArray = bytes.slice(128, 128 + width * height * 4)
		for i: int in range(0, data.size(), 4):
			var blue: int = data[i]
			data[i] = data[i + 2]
			data[i + 2] = blue
		return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)
	return null


## The colours of a coloured piece: the 1st colour, the green channel blends the 2nd, the red one the 3rd, the blue one shades (0.5: none)
static func recolour(image: Image, colour1: Color, colour2: Color, colour3: Color) -> Image:
	var data: PackedByteArray = image.get_data()
	var out := PackedByteArray()
	out.resize(data.size())
	for i: int in range(0, data.size(), 4):
		var alpha: int = data[i + 3]
		if alpha == 0:
			continue
		var red: float = data[i] / 255.0
		var green: float = data[i + 1] / 255.0
		var shade: float = data[i + 2] / 127.5
		var colour: Color = colour1.lerp(colour2, green).lerp(colour3, red)
		colour = colour * shade if shade <= 1.0 else colour.lerp(Color.WHITE, shade - 1.0)
		out[i] = clampi(int(colour.r * 255.0), 0, 255)
		out[i + 1] = clampi(int(colour.g * 255.0), 0, 255)
		out[i + 2] = clampi(int(colour.b * 255.0), 0, 255)
		out[i + 3] = alpha
	return Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, out)


static func _place_piece(canvas: Image, picture: Image, piece: String, mirrored: bool = false) -> void:
	var layout: Array = _LAYOUT[piece]
	var size: int = layout[0]
	var centre: Vector2i = layout[1]
	if mirrored:
		picture = picture.duplicate()
		picture.flip_x()
		centre.x = SIZE - centre.x
	_blend(canvas, picture, centre - Vector2i(size / 2, size / 2))


static func _make_vic3_image(parts: Dictionary, colour: Color) -> Image:
	if vic3_path() == "":
		return null
	var patterns: PackedStringArray = vic3_pieces(PIECE_PATTERN)
	var centers: PackedStringArray = vic3_pieces(PIECE_CENTER)
	if patterns.is_empty() or centers.is_empty():
		return null
	var colour2: Color = palette_colour(int(parts[&"colour2"]))
	var colour3: Color = palette_colour(int(parts[&"colour3"]))
	var canvas: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var sides: PackedStringArray = vic3_pieces(PIECE_SIDE)
	var side: int = int(parts[&"side"])
	if side >= 0 and side < sides.size():
		var side_image: Image = vic3_piece(sides[side], _LAYOUT[PIECE_SIDE][0])
		if side_image != null:
			_place_piece(canvas, side_image, PIECE_SIDE)
			_place_piece(canvas, side_image, PIECE_SIDE, true)
	var pattern: Image = vic3_piece(patterns[clampi(int(parts[&"pattern"]), 0, patterns.size() - 1)], _LAYOUT[PIECE_PATTERN][0])
	if pattern != null:
		_place_piece(canvas, recolour(pattern, colour, colour2, colour3), PIECE_PATTERN)
	var center: Image = vic3_piece(centers[clampi(int(parts[&"center"]), 0, centers.size() - 1)], _LAYOUT[PIECE_CENTER][0])
	if center != null:
		var emblem_colour: Color = palette_colour(int(parts[&"emblem_colour"]))
		_place_piece(canvas, recolour(center, emblem_colour, emblem_colour.lightened(0.4), emblem_colour.darkened(0.5)), PIECE_CENTER)
	for piece: String in [PIECE_FRAME, PIECE_TOP]:
		var names: PackedStringArray = vic3_pieces(piece)
		var index: int = int(parts[&"frame" if piece == PIECE_FRAME else &"top"])
		if index >= 0 and index < names.size():
			var picture: Image = vic3_piece(names[index], _LAYOUT[piece][0])
			if picture != null:
				_place_piece(canvas, picture, piece)
	return canvas


## A small picture of a piece for the lists of the constructor (the coloured ones in light colours)
static func vic3_thumbnail(piece: String, index: int, size: int = 48) -> Texture2D:
	var names: PackedStringArray = vic3_pieces(piece)
	if index < 0 or index >= names.size():
		return null
	var key: String = "thumb/%s/%d" % [names[index], size]
	if _cache.has(key):
		return _cache[key]
	var image: Image = vic3_piece(names[index], size)
	if image != null and piece in [PIECE_PATTERN, PIECE_CENTER]:
		image = recolour(image, Color8(235, 225, 200), Color8(150, 60, 50), Color8(60, 80, 140))
	var texture: Texture2D = ImageTexture.create_from_image(image) if image != null else null
	_cache[key] = texture
	return texture


# ---- an own file

static func file_path(tag: String) -> String:
	return _FILE_FOLDER.path_join("%s.png" % tag)


static func load_file_image(tag: String) -> Image:
	var path: String = file_path(tag)
	if tag == "" or not FileAccess.file_exists(path):
		return null
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		return null
	image.convert(Image.FORMAT_RGBA8)
	if image.get_size() != Vector2i(SIZE, SIZE):
		image.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	return image


## Keeps the picture (already cut to a square) as the icon of the sphere of the leader on this computer
static func save_file_image(tag: String, image: Image) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_FILE_FOLDER))
	var copy: Image = image.duplicate()
	copy.convert(Image.FORMAT_RGBA8)
	copy.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	var ok: bool = copy.save_png(ProjectSettings.globalize_path(file_path(tag))) == OK
	clear_cache()
	return ok
