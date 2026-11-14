extends "res://src/UI/Session/Vic2Window.gd"
## The constructor of the icon of a sphere (version 95, docs/PLAN_SPHERES.md, stage S5), opened by the leader from the window of the sphere:
## - "Набор": an emblem of the own set (ov_data/gfx/spheres) on a shield in the colour of the sphere, the colour of the emblem;
## - "Victoria 3": the pieces of the power blocs of an installed Victoria 3 (the pattern of the shield, the centre, the frame, the top, the
##   sides, two more colours of the shield and the colour of the centre), read from its folder (SphereIcons.gd);
## - "Свой файл": a picture of the computer; a square frame is moved over it (a drag) and made smaller or bigger (the wheel, the slider),
##   what is outside is cut off, the rest is kept as 256x256 (user://sphere_icons).
## The preview shows the icon as it will be; "Применить" sends it (PlayerSingleton.set_sphere_icon).

const SphereIcons := preload("res://src/UI/Session/SphereIcons.gd")

const _SIZE: Vector2 = Vector2(900, 650)
const _TAB_SET: int = 0
const _TAB_VIC3: int = 1
const _TAB_FILE: int = 2

var _sphere: Dictionary = {}
var _colour: Color = Color.GRAY
var _tag: String = ""

var _preview: TextureRect
var _status: Label
var _tabs: TabContainer
var _set_list: ItemList
var _set_colour: OptionButton
var _vic3_path_edit: LineEdit
var _vic3_status: Label
var _vic3_box: VBoxContainer
var _pattern_list: ItemList
var _center_list: ItemList
var _frame_option: OptionButton
var _top_option: OptionButton
var _side_option: OptionButton
var _colour2_option: OptionButton
var _colour3_option: OptionButton
var _vic3_colour_option: OptionButton
var _vic3_filled: bool = false
var _crop: CropView
var _zoom: HSlider
var _file_label: Label
var _file_dialog: FileDialog
var _built: bool = false


func _ready() -> void:
	setup(_SIZE, "Иконка сферы")
	add_to_group(&"sphere_icon_dialog")

	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 12)
	content.add_child(root)

	# the preview and the buttons
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(220, 0)
	root.add_child(left)
	var preview_caption := Label.new()
	preview_caption.text = "Так будет выглядеть:"
	left.add_child(preview_caption)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(200, 200)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left.add_child(_preview)
	var apply := Button.new()
	apply.text = "Применить"
	apply.pressed.connect(_on_apply)
	left.add_child(apply)
	var cancel := Button.new()
	cancel.text = "Отмена"
	cancel.pressed.connect(close)
	left.add_child(cancel)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(200, 0)
	left.add_child(_status)

	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.tab_changed.connect(func(_tab: int) -> void: _on_tab_changed())
	root.add_child(_tabs)

	# ---- the own set
	var set_box := VBoxContainer.new()
	set_box.name = "Набор"
	_tabs.add_child(set_box)
	_set_list = ItemList.new()
	_set_list.max_columns = 6
	_set_list.fixed_icon_size = Vector2i(72, 72)
	_set_list.icon_mode = ItemList.ICON_MODE_TOP
	_set_list.same_column_width = true
	_set_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_set_list.item_selected.connect(func(_index: int) -> void: _update_preview())
	set_box.add_child(_set_list)
	var set_row := HBoxContainer.new()
	set_box.add_child(set_row)
	var set_colour_label := Label.new()
	set_colour_label.text = "Цвет эмблемы:"
	set_row.add_child(set_colour_label)
	_set_colour = _make_palette_option()
	_set_colour.item_selected.connect(func(_index: int) -> void: _update_preview())
	set_row.add_child(_set_colour)
	var set_hint := Label.new()
	set_hint.text = "Щит — в цвете сферы (цвет меняется в окне сферы)."
	set_row.add_child(set_hint)

	# ---- Victoria 3
	var vic3_tab := VBoxContainer.new()
	vic3_tab.name = "Victoria 3"
	_tabs.add_child(vic3_tab)
	var path_row := HBoxContainer.new()
	vic3_tab.add_child(path_row)
	var path_label := Label.new()
	path_label.text = "Папка Victoria 3:"
	path_row.add_child(path_label)
	_vic3_path_edit = LineEdit.new()
	_vic3_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vic3_path_edit.placeholder_text = "C:/Program Files (x86)/Steam/steamapps/common/Victoria 3"
	path_row.add_child(_vic3_path_edit)
	var path_button := Button.new()
	path_button.text = "Указать"
	path_button.pressed.connect(_on_vic3_path)
	path_row.add_child(path_button)
	_vic3_status = Label.new()
	_vic3_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vic3_tab.add_child(_vic3_status)
	_vic3_box = VBoxContainer.new()
	_vic3_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vic3_tab.add_child(_vic3_box)
	var pattern_label := Label.new()
	pattern_label.text = "Узор щита (цвет 1 — цвет сферы):"
	_vic3_box.add_child(pattern_label)
	_pattern_list = ItemList.new()
	_pattern_list.max_columns = 8
	_pattern_list.fixed_icon_size = Vector2i(44, 44)
	_pattern_list.icon_mode = ItemList.ICON_MODE_TOP
	_pattern_list.custom_minimum_size = Vector2(0, 60)
	_pattern_list.item_selected.connect(func(_index: int) -> void: _update_preview())
	_vic3_box.add_child(_pattern_list)
	var center_label := Label.new()
	center_label.text = "Эмблема в центре:"
	_vic3_box.add_child(center_label)
	_center_list = ItemList.new()
	_center_list.max_columns = 11
	_center_list.fixed_icon_size = Vector2i(44, 44)
	_center_list.icon_mode = ItemList.ICON_MODE_TOP
	_center_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center_list.item_selected.connect(func(_index: int) -> void: _update_preview())
	_vic3_box.add_child(_center_list)
	var pieces_row := HBoxContainer.new()
	_vic3_box.add_child(pieces_row)
	_frame_option = _add_labelled_option(pieces_row, "Рамка:")
	_top_option = _add_labelled_option(pieces_row, "Верх:")
	_side_option = _add_labelled_option(pieces_row, "Бока:")
	var colours_row := HBoxContainer.new()
	_vic3_box.add_child(colours_row)
	for item: Array in [["Цвет 2:", &"_colour2_option"], ["Цвет 3:", &"_colour3_option"], ["Цвет эмблемы:", &"_vic3_colour_option"]]:
		var label := Label.new()
		label.text = item[0]
		colours_row.add_child(label)
		var option: OptionButton = _make_palette_option()
		option.item_selected.connect(func(_index: int) -> void: _update_preview())
		colours_row.add_child(option)
		set(item[1], option)

	# ---- an own file
	var file_tab := VBoxContainer.new()
	file_tab.name = "Свой файл"
	_tabs.add_child(file_tab)
	var file_row := HBoxContainer.new()
	file_tab.add_child(file_row)
	var choose := Button.new()
	choose.text = "Выбрать картинку…"
	choose.pressed.connect(_on_choose_file)
	file_row.add_child(choose)
	_file_label = Label.new()
	_file_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_file_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_label.text = "Картинка с компьютера (png, jpg, webp, bmp, svg). Иконка — квадрат 256×256."
	file_row.add_child(_file_label)
	_crop = CropView.new()
	_crop.custom_minimum_size = Vector2(380, 380)
	_crop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_crop.changed.connect(_update_preview)
	file_tab.add_child(_crop)
	var zoom_row := HBoxContainer.new()
	file_tab.add_child(zoom_row)
	var zoom_label := Label.new()
	zoom_label.text = "Увеличение:"
	zoom_row.add_child(zoom_label)
	_zoom = HSlider.new()
	_zoom.min_value = 1.0
	_zoom.max_value = 8.0
	_zoom.step = 0.05
	_zoom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zoom.value_changed.connect(func(value: float) -> void: _crop.set_zoom(value))
	zoom_row.add_child(_zoom)
	var crop_hint := Label.new()
	crop_hint.text = "Рамку двигайте мышью, колесо — увеличение. Что вне рамки — обрезается; в игре видна только эта иконка на этом компьютере."
	crop_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	file_tab.add_child(crop_hint)

	_file_dialog = FileDialog.new()
	_file_dialog.use_native_dialog = true
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp, *.bmp, *.svg ; Картинки"])
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)
	_built = true


## Opens the constructor for the sphere of the player (a dictionary of PlayerSingleton.get_sphere_info().own)
func open_for(sphere: Dictionary) -> void:
	_sphere = sphere
	_colour = sphere.get(&"colour", Color.GRAY)
	_tag = String(sphere.get(&"leader_tag", ""))
	var parts: Dictionary = SphereIcons.decode(int(sphere.get(&"icon", 0)), int(sphere.get(&"icon_extra", 0)))
	_fill_set(parts)
	_set_colour.select(int(parts[&"emblem_colour"]) if int(parts[&"kind"]) == SphereIcons.KIND_SET else 0)
	var kind: int = int(parts[&"kind"])
	_tabs.current_tab = _TAB_VIC3 if kind == SphereIcons.KIND_VIC3 else _TAB_FILE if kind == SphereIcons.KIND_FILE else _TAB_SET
	if kind == SphereIcons.KIND_VIC3:
		_fill_vic3(parts)
	_status.text = ""
	_update_preview()
	open_window()


func _make_palette_option() -> OptionButton:
	var option := OptionButton.new()
	for index: int in SphereIcons.PALETTE.size():
		var swatch: Image = Image.create_empty(18, 18, false, Image.FORMAT_RGBA8)
		swatch.fill(SphereIcons.PALETTE[index])
		option.add_icon_item(ImageTexture.create_from_image(swatch), "", index)
	return option


func _add_labelled_option(row: HBoxContainer, title: String) -> OptionButton:
	var label := Label.new()
	label.text = title
	row.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(150, 0)
	option.item_selected.connect(func(_index: int) -> void: _update_preview())
	row.add_child(option)
	return option


func _fill_set(parts: Dictionary) -> void:
	_set_list.clear()
	for index: int in SphereIcons.get_set_count():
		# (the emblems are white on a transparent ground: shown as they are)
		var picture: Image = SphereIcons.get_set_emblem(index).duplicate()
		picture.resize(72, 72, Image.INTERPOLATE_LANCZOS)
		_set_list.add_icon_item(ImageTexture.create_from_image(picture))
	if _set_list.item_count > 0:
		var emblem: int = int(parts[&"emblem"]) if int(parts[&"kind"]) == SphereIcons.KIND_SET else 0
		_set_list.select(clampi(emblem, 0, _set_list.item_count - 1))


## The lists of Victoria 3 (filled when the tab is first shown: reading the pieces takes a moment)
func _fill_vic3(parts: Dictionary = {}) -> void:
	var path: String = SphereIcons.vic3_path()
	_vic3_path_edit.text = path
	_vic3_box.visible = path != ""
	if path == "":
		_vic3_status.text = "Victoria 3 не найдена. Укажите её папку (в ней есть game/gfx/coat_of_arms). Файлы игры не копируются, а читаются из её папки."
		return
	_vic3_status.text = "Эмблемы читаются из установленной Victoria 3."
	if not _vic3_filled:
		_vic3_filled = true
		_pattern_list.clear()
		for index: int in SphereIcons.vic3_pieces(SphereIcons.PIECE_PATTERN).size():
			_pattern_list.add_icon_item(SphereIcons.vic3_thumbnail(SphereIcons.PIECE_PATTERN, index, 44))
		_center_list.clear()
		for index: int in SphereIcons.vic3_pieces(SphereIcons.PIECE_CENTER).size():
			_center_list.add_icon_item(SphereIcons.vic3_thumbnail(SphereIcons.PIECE_CENTER, index, 44))
		for item: Array in [[_frame_option, SphereIcons.PIECE_FRAME], [_top_option, SphereIcons.PIECE_TOP], [_side_option, SphereIcons.PIECE_SIDE]]:
			var option: OptionButton = item[0]
			option.clear()
			# (the ids: 0 none, else the index + 1)
			option.add_item("нет", 0)
			for index: int in SphereIcons.vic3_pieces(item[1]).size():
				option.add_icon_item(SphereIcons.vic3_thumbnail(item[1], index, 28), "%d" % (index + 1), index + 1)
		_colour2_option.select(3)
		_colour3_option.select(1)
		_vic3_colour_option.select(0)
		_pattern_list.select(0)
		_center_list.select(0)
		_frame_option.select(1 if _frame_option.item_count > 1 else 0)
		_top_option.select(0)
		_side_option.select(0)
	if not parts.is_empty() and int(parts[&"kind"]) == SphereIcons.KIND_VIC3:
		_pattern_list.select(clampi(int(parts[&"pattern"]), 0, maxi(0, _pattern_list.item_count - 1)))
		_center_list.select(clampi(int(parts[&"center"]), 0, maxi(0, _center_list.item_count - 1)))
		_center_list.ensure_current_is_visible()
		_frame_option.select(maxi(0, _frame_option.get_item_index(int(parts[&"frame"]) + 1)))
		_top_option.select(maxi(0, _top_option.get_item_index(int(parts[&"top"]) + 1)))
		_side_option.select(maxi(0, _side_option.get_item_index(int(parts[&"side"]) + 1)))
		_colour2_option.select(int(parts[&"colour2"]))
		_colour3_option.select(int(parts[&"colour3"]))
		_vic3_colour_option.select(int(parts[&"emblem_colour"]))


func _on_tab_changed() -> void:
	if not _built:
		return
	if _tabs.current_tab == _TAB_VIC3:
		_fill_vic3()
	_update_preview()


func _on_vic3_path() -> void:
	if SphereIcons.set_vic3_path(_vic3_path_edit.text):
		_vic3_filled = false
		_fill_vic3()
		_update_preview()
	else:
		_vic3_status.text = "В этой папке нет эмблем Victoria 3 (нужна папка игры, где есть game/gfx/coat_of_arms)."


func _selected(list: ItemList) -> int:
	var selected: PackedInt32Array = list.get_selected_items()
	return selected[0] if not selected.is_empty() else 0


## The two numbers of the icon of the open tab, [] when it cannot be made
func _current_numbers() -> PackedInt64Array:
	match _tabs.current_tab:
		_TAB_SET:
			return SphereIcons.encode_set(_selected(_set_list), _set_colour.get_selected_id())
		_TAB_VIC3:
			if SphereIcons.vic3_path() == "" or _center_list.item_count == 0:
				return PackedInt64Array()
			return SphereIcons.encode_vic3(_selected(_pattern_list), _selected(_center_list), _frame_option.get_selected_id() - 1,
				_top_option.get_selected_id() - 1, _side_option.get_selected_id() - 1, _colour2_option.get_selected_id(), _colour3_option.get_selected_id(),
				_vic3_colour_option.get_selected_id())
	return SphereIcons.encode_file()


func _update_preview() -> void:
	if not _built:
		return
	if _tabs.current_tab == _TAB_FILE:
		var cut: Image = _crop.get_cut()
		_preview.texture = ImageTexture.create_from_image(cut) if cut != null else SphereIcons.get_texture_for(
			SphereIcons.KIND_FILE, 0, _colour, _tag)
		return
	var numbers: PackedInt64Array = _current_numbers()
	if numbers.is_empty():
		_preview.texture = null
		return
	_preview.texture = ImageTexture.create_from_image(SphereIcons.make_image(numbers[0], numbers[1], _colour, _tag))


func _on_choose_file() -> void:
	_file_dialog.popup_centered_ratio(0.6)


func _on_file_selected(path: String) -> void:
	var image: Image = Image.load_from_file(path)
	if image == null or image.is_empty():
		_file_label.text = "Не удалось открыть: %s" % path
		return
	image.convert(Image.FORMAT_RGBA8)
	_file_label.text = path.get_file()
	_zoom.set_value_no_signal(1.0)
	_crop.set_image(image)


func _on_apply() -> void:
	var numbers: PackedInt64Array = _current_numbers()
	if _tabs.current_tab == _TAB_FILE:
		var cut: Image = _crop.get_cut()
		if cut == null:
			if SphereIcons.load_file_image(_tag) == null:
				_status.text = "Сначала выберите картинку."
				return
		elif not SphereIcons.save_file_image(_tag, cut):
			_status.text = "Не удалось сохранить картинку."
			return
	elif numbers.is_empty():
		_status.text = "Эмблемы Victoria 3 не найдены."
		return
	SphereIcons.clear_cache()
	PlayerSingleton.set_sphere_icon(numbers[0], numbers[1])
	close()


## A picture with a square frame over it: dragged by the mouse, made smaller or bigger by the wheel (set_zoom); get_cut gives the square
class CropView extends Control:
	signal changed

	var _image: Image
	var _texture: Texture2D
	var _centre: Vector2 = Vector2.ZERO # in the pixels of the picture
	var _side: float = 0.0
	var _dragging: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true

	func set_image(image: Image) -> void:
		_image = image
		_texture = ImageTexture.create_from_image(image)
		_side = float(mini(image.get_width(), image.get_height()))
		_centre = Vector2(image.get_size()) / 2.0
		queue_redraw()
		changed.emit()

	func set_zoom(zoom: float) -> void:
		if _image == null:
			return
		_side = float(mini(_image.get_width(), _image.get_height())) / maxf(zoom, 1.0)
		_clamp()
		queue_redraw()
		changed.emit()

	## The square cut out of the picture (null: no picture)
	func get_cut() -> Image:
		if _image == null:
			return null
		var region := Rect2i(Vector2i(_centre - Vector2(_side, _side) / 2.0), Vector2i(int(_side), int(_side)))
		region = region.intersection(Rect2i(Vector2i.ZERO, _image.get_size()))
		if region.size.x <= 0 or region.size.y <= 0:
			return null
		var cut: Image = _image.get_region(region)
		cut.resize(256, 256, Image.INTERPOLATE_LANCZOS)
		return cut

	func _fit() -> Array:
		var image_size := Vector2(_image.get_size())
		var scale_factor: float = minf(size.x / image_size.x, size.y / image_size.y)
		var offset: Vector2 = (size - image_size * scale_factor) / 2.0
		return [scale_factor, offset]

	func _clamp() -> void:
		var half: float = _side / 2.0
		_centre.x = clampf(_centre.x, half, maxf(half, _image.get_width() - half))
		_centre.y = clampf(_centre.y, half, maxf(half, _image.get_height() - half))

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.11, 0.1))
		if _image == null:
			return
		var fit: Array = _fit()
		var scale_factor: float = fit[0]
		var offset: Vector2 = fit[1]
		var picture := Rect2(offset, Vector2(_image.get_size()) * scale_factor)
		draw_texture_rect(_texture, picture, false)
		var frame := Rect2(offset + (_centre - Vector2(_side, _side) / 2.0) * scale_factor, Vector2(_side, _side) * scale_factor)
		var shadow := Color(0, 0, 0, 0.55)
		draw_rect(Rect2(picture.position, Vector2(picture.size.x, frame.position.y - picture.position.y)), shadow)
		draw_rect(Rect2(Vector2(picture.position.x, frame.end.y), Vector2(picture.size.x, picture.end.y - frame.end.y)), shadow)
		draw_rect(Rect2(Vector2(picture.position.x, frame.position.y), Vector2(frame.position.x - picture.position.x, frame.size.y)), shadow)
		draw_rect(Rect2(Vector2(frame.end.x, frame.position.y), Vector2(picture.end.x - frame.end.x, frame.size.y)), shadow)
		draw_rect(frame, Color(0.95, 0.8, 0.3), false, 2.0)

	func _gui_input(event: InputEvent) -> void:
		if _image == null:
			return
		if event is InputEventMouseButton:
			var button := event as InputEventMouseButton
			if button.button_index == MOUSE_BUTTON_LEFT:
				_dragging = button.pressed
				accept_event()
			elif button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				var smallest: float = 16.0
				var largest: float = float(mini(_image.get_width(), _image.get_height()))
				_side = clampf(_side * (0.9 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), minf(smallest, largest), largest)
				_clamp()
				queue_redraw()
				changed.emit()
				accept_event()
		elif event is InputEventMouseMotion and _dragging:
			var fit: Array = _fit()
			_centre += (event as InputEventMouseMotion).relative / float(fit[0])
			_clamp()
			queue_redraw()
			changed.emit()
			accept_event()
