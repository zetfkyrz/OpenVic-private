extends Control
## A window in the style of Victoria 2: the frame and close button of the original interface, a title, dragging by
## the title bar and Escape/close button to close it. Windows that are not part of the original interface (credit,
## ownership of factories, ...) are built on top of it, their controls go to `content`.
##
## Use with `extends "res://src/UI/Session/Vic2Window.gd"` and call `setup(size, title)` first.

const _BACKGROUND_PATH: String = "gfx/interface/main_bg.dds"
const _CLOSE_BUTTON_PATH: String = "gfx/interface/main_close_button.dds"
const _BUTTON_PATH: String = "gfx/interface/button_standard_200.dds"

# The frame texture draws this far outside of the rectangle of the window
const FRAME_MARGIN: float = 70.0
const TITLE_HEIGHT: float = 34.0
const CONTENT_PADDING: float = 14.0

const TEXT_COLOUR: Color = Color(0.1, 0.06, 0.03)
const MUTED_TEXT_COLOUR: Color = Color(0.32, 0.25, 0.18)
const HEADER_COLOUR: Color = Color(0.42, 0.1, 0.17)

## Control the controls of the window are added to
var content: Control

var _title_label: Label
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


func setup(window_size: Vector2, title: String) -> void:
	visible = false
	custom_minimum_size = window_size
	size = window_size
	# Centered in the parent, can be moved by the player
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -window_size.x / 2.0
	offset_right = window_size.x / 2.0
	offset_top = -window_size.y / 2.0
	offset_bottom = window_size.y / 2.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_PASS
	background.add_theme_stylebox_override(&"panel", _create_frame_style())
	background.gui_input.connect(_on_background_input)
	add_child(background)

	_title_label = Label.new()
	_title_label.text = title
	_title_label.position = Vector2(CONTENT_PADDING, 6.0)
	_title_label.size = Vector2(window_size.x - CONTENT_PADDING * 2.0 - 36.0, TITLE_HEIGHT - 6.0)
	_title_label.add_theme_font_size_override(&"font_size", 20)
	_title_label.add_theme_color_override(&"font_color", HEADER_COLOUR)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)

	var close_texture: Texture2D = AssetManager.get_texture(_CLOSE_BUTTON_PATH)
	var close_button := TextureButton.new()
	if close_texture:
		close_button.texture_normal = close_texture
		close_button.size = close_texture.get_size()
	else:
		close_button.custom_minimum_size = Vector2(24, 24)
	close_button.position = Vector2(window_size.x - 34.0, 2.0)
	close_button.tooltip_text = tr("Close")
	close_button.pressed.connect(close)
	add_child(close_button)

	content = Control.new()
	content.position = Vector2(CONTENT_PADDING, TITLE_HEIGHT + 4.0)
	content.size = window_size - Vector2(CONTENT_PADDING * 2.0, TITLE_HEIGHT + 4.0 + CONTENT_PADDING)
	content.theme = create_theme()
	add_child(content)


func set_title(title: String) -> void:
	_title_label.text = title


func open_window() -> void:
	show()
	move_to_front()


func close() -> void:
	hide()
	_dragging = false


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Windows come to the front when they are clicked, dragging works from the whole background
		if event.pressed:
			move_to_front()
			_dragging = true
			_drag_offset = get_global_mouse_position() - global_position
		else:
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var new_position: Vector2 = get_global_mouse_position() - _drag_offset
		global_position = new_position
		accept_event()


func _create_frame_style() -> StyleBox:
	var texture: Texture2D = AssetManager.get_texture(_BACKGROUND_PATH)
	if not texture:
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = Color(0.86, 0.8, 0.65)
		fallback.set_border_width_all(3)
		fallback.border_color = Color(0.55, 0.4, 0.15)
		return fallback

	var style := StyleBoxTexture.new()
	style.texture = texture
	style.set_texture_margin_all(FRAME_MARGIN)
	style.set_expand_margin_all(FRAME_MARGIN)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return style


func _create_button_style(modulate_colour: Color) -> StyleBox:
	var texture: Texture2D = AssetManager.get_texture(_BUTTON_PATH)
	if not texture:
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = Color(0.45, 0.5, 0.55) * modulate_colour
		fallback.set_corner_radius_all(3)
		fallback.content_margin_left = 8
		fallback.content_margin_right = 8
		return fallback

	var style := StyleBoxTexture.new()
	style.texture = texture
	style.set_texture_margin_all(10.0)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	style.modulate_color = modulate_colour
	return style


func _flat(colour: Color, border: Color = Color(0, 0, 0, 0), border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = border
	style.set_border_width_all(border_width)
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style


## Theme of the controls inside the windows: dark text on the parchment, buttons of the original interface
func create_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 14

	var parchment: Color = Color(0.93, 0.88, 0.76, 0.55)
	var border: Color = Color(0.35, 0.25, 0.12, 0.9)

	for control_type: StringName in [&"Label", &"CheckBox", &"CheckButton"]:
		theme.set_color(&"font_color", control_type, TEXT_COLOUR)
		theme.set_color(&"font_hover_color", control_type, TEXT_COLOUR)
		theme.set_color(&"font_pressed_color", control_type, TEXT_COLOUR)
		theme.set_color(&"font_hover_pressed_color", control_type, TEXT_COLOUR)
		theme.set_color(&"font_focus_color", control_type, TEXT_COLOUR)
		theme.set_color(&"font_disabled_color", control_type, MUTED_TEXT_COLOUR)

	# Buttons, option buttons and the tab bar use the button texture of the original interface
	for control_type: StringName in [&"Button", &"OptionButton", &"MenuButton"]:
		theme.set_stylebox(&"normal", control_type, _create_button_style(Color.WHITE))
		theme.set_stylebox(&"hover", control_type, _create_button_style(Color(1.25, 1.25, 1.3)))
		theme.set_stylebox(&"pressed", control_type, _create_button_style(Color(0.7, 0.7, 0.75)))
		theme.set_stylebox(&"focus", control_type, _create_button_style(Color(1.1, 1.1, 1.15)))
		theme.set_stylebox(&"disabled", control_type, _create_button_style(Color(0.6, 0.6, 0.6, 0.8)))
		theme.set_color(&"font_color", control_type, Color.BLACK)
		theme.set_color(&"font_hover_color", control_type, Color.BLACK)
		theme.set_color(&"font_pressed_color", control_type, Color.BLACK)
		theme.set_color(&"font_focus_color", control_type, Color.BLACK)
		theme.set_color(&"font_disabled_color", control_type, Color(0.35, 0.35, 0.35))

	# Tabs
	theme.set_stylebox(&"tab_selected", &"TabContainer", _create_button_style(Color(1.3, 1.25, 1.1)))
	theme.set_stylebox(&"tab_unselected", &"TabContainer", _create_button_style(Color(0.8, 0.8, 0.85)))
	theme.set_stylebox(&"tab_hovered", &"TabContainer", _create_button_style(Color(1.1, 1.1, 1.15)))
	theme.set_stylebox(&"tab_focus", &"TabContainer", _create_button_style(Color(1.3, 1.25, 1.1)))
	theme.set_stylebox(&"panel", &"TabContainer", _flat(Color(0, 0, 0, 0)))
	for color_name: StringName in [&"font_selected_color", &"font_unselected_color", &"font_hovered_color"]:
		theme.set_color(color_name, &"TabContainer", Color.BLACK)

	# Tables
	theme.set_stylebox(&"panel", &"Tree", _flat(parchment, border, 1))
	theme.set_stylebox(&"focus", &"Tree", _flat(Color(0, 0, 0, 0)))
	theme.set_stylebox(&"selected", &"Tree", _flat(Color(0.6, 0.18, 0.2, 0.45)))
	theme.set_stylebox(&"selected_focus", &"Tree", _flat(Color(0.6, 0.18, 0.2, 0.55)))
	theme.set_stylebox(&"cursor", &"Tree", _flat(Color(0, 0, 0, 0)))
	theme.set_stylebox(&"cursor_unfocused", &"Tree", _flat(Color(0, 0, 0, 0)))
	theme.set_stylebox(&"title_button_normal", &"Tree", _flat(HEADER_COLOUR, border, 1))
	theme.set_stylebox(&"title_button_hover", &"Tree", _flat(HEADER_COLOUR.lightened(0.15), border, 1))
	theme.set_stylebox(&"title_button_pressed", &"Tree", _flat(HEADER_COLOUR.darkened(0.15), border, 1))
	theme.set_color(&"font_color", &"Tree", TEXT_COLOUR)
	theme.set_color(&"font_selected_color", &"Tree", Color.BLACK)
	theme.set_color(&"title_button_color", &"Tree", Color(0.96, 0.92, 0.8))
	theme.set_color(&"guide_color", &"Tree", Color(0, 0, 0, 0))
	theme.set_color(&"relationship_line_color", &"Tree", Color(0, 0, 0, 0))
	theme.set_color(&"font_disabled_color", &"Tree", MUTED_TEXT_COLOUR)

	# Fields
	for control_type: StringName in [&"LineEdit", &"SpinBox"]:
		theme.set_stylebox(&"normal", control_type, _flat(Color(0.97, 0.94, 0.86, 0.9), border, 1))
		theme.set_stylebox(&"focus", control_type, _flat(Color(1.0, 0.98, 0.9), Color(0.6, 0.18, 0.2), 1))
		theme.set_stylebox(&"read_only", control_type, _flat(Color(0.85, 0.82, 0.74, 0.8), border, 1))
	theme.set_color(&"font_color", &"LineEdit", Color.BLACK)
	theme.set_color(&"font_placeholder_color", &"LineEdit", MUTED_TEXT_COLOUR)
	theme.set_color(&"caret_color", &"LineEdit", Color.BLACK)
	theme.set_color(&"selection_color", &"LineEdit", Color(0.6, 0.18, 0.2, 0.5))

	# Drop-down lists
	theme.set_stylebox(&"panel", &"PopupMenu", _flat(Color(0.92, 0.87, 0.74), border, 1))
	theme.set_stylebox(&"hover", &"PopupMenu", _flat(Color(0.6, 0.18, 0.2, 0.5)))
	theme.set_color(&"font_color", &"PopupMenu", Color.BLACK)
	theme.set_color(&"font_hover_color", &"PopupMenu", Color.BLACK)
	theme.set_color(&"font_disabled_color", &"PopupMenu", MUTED_TEXT_COLOUR)

	theme.set_stylebox(&"panel", &"PanelContainer", _flat(parchment, border, 1))
	theme.set_stylebox(&"panel", &"Panel", _flat(parchment, border, 1))
	theme.set_stylebox(&"scroll", &"VScrollBar", _flat(Color(0, 0, 0, 0.12)))
	theme.set_stylebox(&"grabber", &"VScrollBar", _flat(Color(0.45, 0.12, 0.17, 0.9)))
	theme.set_stylebox(&"grabber_highlight", &"VScrollBar", _flat(Color(0.6, 0.2, 0.25, 0.95)))
	theme.set_stylebox(&"grabber_pressed", &"VScrollBar", _flat(Color(0.35, 0.1, 0.14, 0.95)))

	return theme
