extends "res://src/UI/Session/Vic2Window.gd"
## The window of the army technologies (docs/WAR_ASSUMPTIONS.md, section 5): a tree on a grid in the manner of the focus trees: a node is a technology
## (x, y of its file), the lines go from the parent down, along a common horizontal to the node (solid for a needed technology, dashed for a block "any of").
## The style is the one of the focus trees of Hearts of Iron: a dark field, a round emblem over a dark plate with the name. Grey-blue: not researched; a node that is
## available has a light plate, one that is being researched has an orange rim and a bar of the progress, a researched one has a yellow rim and the line that leads to it is yellow. A click on an available node starts the research, a right click on the node that is being
## researched cancels it (the progress is lost). The data are the ones of the simulation (PlayerSingleton.get_army_technologies), nothing is counted here.
## Opened with F5 or with the button of the panel of the army.

const _SIZE: Vector2 = Vector2(1240, 760)
const _TOGGLE_KEY: Key = KEY_F5

const _CELL_WIDTH: float = 176.0
const _CELL_HEIGHT: float = 124.0
const _NODE_SIZE: Vector2 = Vector2(156.0, 104.0)
const _EMBLEM_SIZE: float = 58.0
const _PLATE_HEIGHT: float = 40.0
const _MARGIN: Vector2 = Vector2(30.0, 24.0)
const _FIELD_COLOUR: Color = Color(0.075, 0.08, 0.09)

const _STATE_NOT_AVAILABLE: int = 0
const _STATE_AVAILABLE: int = 1
const _STATE_RESEARCHING: int = 2
const _STATE_RESEARCHED: int = 3

const _LINE_COLOUR: Color = Color(0.45, 0.56, 0.68)
const _LINE_DONE_COLOUR: Color = Color(0.93, 0.72, 0.15)
const _RIM_COLOUR: Color = Color(0.95, 0.76, 0.12)
const _PROGRESS_COLOUR: Color = Color(0.85, 0.45, 0.1)

## The branches that are not made yet (a stub tab each)
const _STUB_BRANCHES: PackedStringArray = ["industry", "society", "navy"]

## How the values of the effects are shown: a share (+5 %), a number (+1) or a multiplier (x2)
const _SHARE_EFFECTS: PackedStringArray = [
	"attack_mult", "defense_mult", "breakthrough_mult", "mobilisation_speed_pct", "mobilisation_size_pct", "occupation_speed_pct", "supply_national_pct",
	"supply_army_pct", "railway_supply_per_level", "density_excess_reduction", "organisation_regain",
]
const _MULTIPLIER_EFFECTS: PackedStringArray = [
	"casualties_taken_mult", "mobilisation_speed_mult", "occupation_speed_mult", "density_coefficient_mult",
]

var _technologies: Array = []
var _branches: Array = []
var _selected_branch: int = 0
var _signature: String = ""

var _tab_row: HBoxContainer
var _scroll: ScrollContainer
var _canvas: Control
var _info_label: Label
var _nodes: Dictionary = {} # technology index -> Button
var _bars: Dictionary = {} # technology index -> ProgressBar


## The canvas draws the lines under the nodes (the children are drawn after it)
class _Lines extends Control:
	var window: Control

	func _draw() -> void:
		if window != null:
			window.call(&"draw_lines", self)


func _ready() -> void:
	setup(_SIZE, tr("ARMY_TECH_WINDOW"))

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 6)
	content.add_child(root)

	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override(&"separation", 4)
	root.add_child(_tab_row)

	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(1, 0)
	root.add_child(_info_label)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.clip_contents = true
	var field := StyleBoxFlat.new()
	field.bg_color = _FIELD_COLOUR
	field.set_border_width_all(2)
	field.border_color = Color(0.35, 0.25, 0.12)
	_scroll.add_theme_stylebox_override(&"panel", field)
	root.add_child(_scroll)

	var lines := _Lines.new()
	lines.window = self
	_canvas = lines
	_scroll.add_child(_canvas)

	GameSingleton.gamestate_updated.connect(_on_gamestate_updated)


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event and key_event.pressed and not key_event.echo and key_event.keycode == _TOGGLE_KEY:
		if visible:
			close()
		else:
			open_technologies()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)


func open_technologies() -> void:
	# The window is opened first (a hidden window does not refresh)
	_signature = ""
	open_window()
	_refresh()


func _on_gamestate_updated() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	_technologies = PlayerSingleton.get_army_technologies()
	_branches = PlayerSingleton.get_army_tech_branches()
	var signature: String = str(_selected_branch) + "|" + str(_technologies.hash())
	if signature == _signature:
		return
	_signature = signature
	_build_tabs()
	_build_nodes()
	_canvas.queue_redraw()


func _build_tabs() -> void:
	for child: Node in _tab_row.get_children():
		child.queue_free()
	for branch: Dictionary in _branches:
		var button := Button.new()
		button.text = str(branch[&"name"])
		button.toggle_mode = true
		button.button_pressed = int(branch[&"index"]) == _selected_branch
		button.pressed.connect(_on_branch_pressed.bind(int(branch[&"index"])))
		_tab_row.add_child(button)
	for stub: String in _STUB_BRANCHES:
		var stub_button := Button.new()
		stub_button.text = tr("ARMY_TECH_BRANCH_" + stub)
		stub_button.disabled = true
		stub_button.tooltip_text = tr("ARMY_TECH_STUB")
		_tab_row.add_child(stub_button)


func _on_branch_pressed(index: int) -> void:
	_selected_branch = index
	_signature = ""
	_refresh()


func _node_position(technology: Dictionary) -> Vector2:
	return _MARGIN + Vector2(float(int(technology[&"x"])) * _CELL_WIDTH, float(int(technology[&"y"])) * _CELL_HEIGHT)


func _build_nodes() -> void:
	for child: Node in _canvas.get_children():
		child.queue_free()
	_nodes.clear()
	_bars.clear()

	var max_x: int = 0
	var max_y: int = 0
	var researched: int = 0
	var total: int = 0
	for technology: Dictionary in _technologies:
		if int(technology[&"branch_index"]) != _selected_branch:
			continue
		max_x = maxi(max_x, int(technology[&"x"]))
		max_y = maxi(max_y, int(technology[&"y"]))
		total += 1
		if int(technology[&"state"]) == _STATE_RESEARCHED:
			researched += 1
	_canvas.custom_minimum_size = _MARGIN * 2.0 + Vector2(float(max_x) * _CELL_WIDTH + _NODE_SIZE.x, float(max_y) * _CELL_HEIGHT + _NODE_SIZE.y)
	_info_label.text = "%s: %d / %d" % [tr(_branch_name_key()), researched, total]

	for technology: Dictionary in _technologies:
		if int(technology[&"branch_index"]) != _selected_branch:
			continue
		_create_node(technology)


func _branch_name_key() -> String:
	for branch: Dictionary in _branches:
		if int(branch[&"index"]) == _selected_branch:
			return "ARMY_TECH_BRANCH_" + str(branch[&"id"])
	return "ARMY_TECH_BRANCH_army"


func _create_node(technology: Dictionary) -> void:
	var state: int = int(technology[&"state"])
	var index: int = int(technology[&"index"])
	# The button is the clickable place of the node (nothing is drawn by it), the emblem and the plate are drawn over it
	var button := Button.new()
	button.position = _node_position(technology)
	button.size = _NODE_SIZE
	button.custom_minimum_size = _NODE_SIZE
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	for style_name: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	button.tooltip_text = _tooltip(technology)
	button.pressed.connect(_on_node_pressed.bind(technology))
	button.gui_input.connect(_on_node_input.bind(technology))
	_canvas.add_child(button)
	_nodes[index] = button

	var dimmed: bool = state == _STATE_NOT_AVAILABLE
	var shown := Control.new()
	shown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shown.modulate = Color(0.68, 0.7, 0.74) if dimmed else Color.WHITE
	button.add_child(shown)
	button.mouse_entered.connect(func() -> void: shown.modulate = Color(1.15, 1.15, 1.15))
	button.mouse_exited.connect(func() -> void: shown.modulate = Color(0.68, 0.7, 0.74) if dimmed else Color.WHITE)

	var rim: Color = _rim_colour(state)
	# The emblem: a round disc with a rim; the picture (a temporary one for the whole branch, its path is in the file of the technology) or the era
	var emblem := Panel.new()
	emblem.position = Vector2((_NODE_SIZE.x - _EMBLEM_SIZE) / 2.0, 0.0)
	emblem.size = Vector2(_EMBLEM_SIZE, _EMBLEM_SIZE)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc := StyleBoxFlat.new()
	disc.bg_color = Color(0.2, 0.24, 0.3) if state != _STATE_RESEARCHED else Color(0.34, 0.27, 0.12)
	disc.set_corner_radius_all(int(_EMBLEM_SIZE / 2.0))
	disc.set_border_width_all(4 if state == _STATE_RESEARCHED else 3)
	disc.border_color = rim
	emblem.add_theme_stylebox_override(&"panel", disc)
	shown.add_child(emblem)
	var texture: Texture2D = _icon_texture(str(technology.get(&"icon", "")))
	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position = Vector2(10.0, 10.0)
		icon.size = Vector2(_EMBLEM_SIZE - 20.0, _EMBLEM_SIZE - 20.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		emblem.add_child(icon)
	var era := Label.new()
	era.text = _roman(int(technology[&"era"]))
	era.position = Vector2(0.0, _EMBLEM_SIZE - 20.0)
	era.size = Vector2(_EMBLEM_SIZE, 16.0)
	era.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	era.add_theme_font_size_override(&"font_size", 11)
	era.add_theme_color_override(&"font_color", rim.lightened(0.3))
	era.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.add_child(era)

	# The plate with the name under it: a dark capsule, the rim has the colour of the state
	var plate := Panel.new()
	plate.position = Vector2(0.0, _EMBLEM_SIZE - 8.0)
	plate.size = Vector2(_NODE_SIZE.x, _PLATE_HEIGHT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var capsule := StyleBoxFlat.new()
	capsule.bg_color = Color(0.13, 0.12, 0.1) if state == _STATE_RESEARCHED else Color(0.1, 0.11, 0.14)
	capsule.set_corner_radius_all(14)
	capsule.set_border_width_all(2)
	capsule.border_color = rim
	capsule.shadow_color = Color(0, 0, 0, 0.5)
	capsule.shadow_size = 3
	plate.add_theme_stylebox_override(&"panel", capsule)
	shown.add_child(plate)
	var label := Label.new()
	label.text = str(technology[&"name"])
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(8.0, 2.0)
	label.size = Vector2(_NODE_SIZE.x - 16.0, _PLATE_HEIGHT - 4.0)
	label.add_theme_font_size_override(&"font_size", 12)
	label.add_theme_color_override(&"font_color", Color(0.93, 0.93, 0.93))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(label)

	if state == _STATE_RESEARCHING:
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.value = float(technology[&"progress"])
		bar.show_percentage = false
		bar.position = Vector2(10.0, _EMBLEM_SIZE - 8.0 + _PLATE_HEIGHT + 4.0)
		bar.size = Vector2(_NODE_SIZE.x - 20.0, 6.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := StyleBoxFlat.new()
		fill.bg_color = _PROGRESS_COLOUR
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.25, 0.25, 0.28)
		bar.add_theme_stylebox_override(&"fill", fill)
		bar.add_theme_stylebox_override(&"background", back)
		shown.add_child(bar)
		_bars[index] = bar


func _rim_colour(state: int) -> Color:
	match state:
		_STATE_RESEARCHED:
			return _RIM_COLOUR
		_STATE_RESEARCHING:
			return _PROGRESS_COLOUR
		_STATE_AVAILABLE:
			return Color(0.72, 0.82, 0.92)
	return Color(0.4, 0.47, 0.56)


## The picture of the technology; a file with two or more frames side by side (the pictures of the interface are strips) gives its first frame
func _icon_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var texture: Texture2D = AssetManager.get_texture(path)
	if texture == null:
		return null
	var frame: float = float(texture.get_height())
	if frame > 0.0 and float(texture.get_width()) >= frame * 2.0:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(0.0, 0.0, frame, frame)
		return atlas
	return texture


func _roman(number: int) -> String:
	var numerals: PackedStringArray = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII"]
	return numerals[number] if number >= 0 and number < numerals.size() else str(number)


func _on_node_pressed(technology: Dictionary) -> void:
	if int(technology[&"state"]) == _STATE_AVAILABLE and bool(technology[&"can_start"]):
		PlayerSingleton.start_army_research(int(technology[&"index"]))


func _on_node_input(event: InputEvent, technology: Dictionary) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if int(technology[&"state"]) == _STATE_RESEARCHING:
			PlayerSingleton.cancel_army_research(int(technology[&"index"]))


func _tooltip(technology: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append(str(technology[&"name"]))
	lines.append("%s %d, %s: %d %s" % [tr("ARMY_TECH_ERA"), int(technology[&"era"]), tr("ARMY_TECH_TIME"), int(technology[&"days_total"]), tr("ARMY_TECH_DAYS")])
	var state: int = int(technology[&"state"])
	lines.append(tr("ARMY_TECH_STATE_%d" % state))
	if state == _STATE_RESEARCHING:
		lines.append("%d %s %s" % [int(technology[&"days_left"]), tr("ARMY_TECH_DAYS"), tr("ARMY_TECH_DAYS_LEFT")])
	if state == _STATE_NOT_AVAILABLE or (state == _STATE_AVAILABLE and not bool(technology[&"can_start"])):
		var reason: String = str(technology[&"block_reason"])
		if not reason.is_empty():
			lines.append(tr("ARMY_TECH_BLOCK_" + reason))
	var prerequisites: Array = technology[&"prerequisites"]
	if not prerequisites.is_empty():
		var parts: PackedStringArray = []
		for block: Array in prerequisites:
			var names: PackedStringArray = []
			for id: String in block:
				names.append(tr(id))
			if names.size() > 1:
				parts.append("%s (%s)" % [tr("ARMY_TECH_ANY_OF"), ", ".join(names)])
			else:
				parts.append(names[0] if not names.is_empty() else "")
		lines.append("%s: %s" % [tr("ARMY_TECH_PREREQUISITES"), "; ".join(parts)])
	var unlocks: Array = technology[&"unlocks"]
	if not unlocks.is_empty():
		lines.append(tr("ARMY_TECH_UNLOCKS") + ":")
		for unlock: Dictionary in unlocks:
			lines.append("  %s: %s" % [tr("ARMY_UNLOCK_" + str(unlock[&"kind"])), tr(str(unlock[&"name_key"]))])
	var effects: Array = technology[&"effects"]
	if not effects.is_empty():
		lines.append(tr("ARMY_TECH_EFFECTS") + ":")
		for effect: Dictionary in effects:
			lines.append("  " + _effect_text(effect))
	return "\n".join(lines)


func _effect_text(effect: Dictionary) -> String:
	var key: String = str(effect[&"key"])
	var scope: String = str(effect[&"scope"])
	var value: float = float(effect[&"value"])
	var text: String = tr("ARMY_EFFECT_" + key)
	if not scope.is_empty():
		var scope_text: String = tr("ARMY_SCOPE_" + scope)
		if scope_text == "ARMY_SCOPE_" + scope:
			scope_text = tr(scope)
		text += " (%s)" % scope_text
	if _MULTIPLIER_EFFECTS.has(key):
		return "%s: x%s" % [text, _number(value)]
	if _SHARE_EFFECTS.has(key):
		return "%s: %s%s %%" % [text, "+" if value >= 0.0 else "", _number(value * 100.0)]
	return "%s: %s%s" % [text, "+" if value >= 0.0 else "", _number(value)]


func _number(value: float) -> String:
	var text: String = "%.2f" % value
	while text.contains(".") and (text.ends_with("0") or text.ends_with(".")):
		text = text.left(text.length() - 1)
	return text


## Drawn by the canvas: the line from every needed technology to a node
func draw_lines(canvas: Control) -> void:
	var by_index: Dictionary = {}
	for technology: Dictionary in _technologies:
		by_index[int(technology[&"index"])] = technology
	for technology: Dictionary in _technologies:
		if int(technology[&"branch_index"]) != _selected_branch:
			continue
		var child_position: Vector2 = _node_position(technology)
		var child_top: Vector2 = child_position + Vector2(_NODE_SIZE.x / 2.0, 0.0)
		# The common horizontal is just above the emblem
		var middle_y: float = child_top.y - (_CELL_HEIGHT - _NODE_SIZE.y) / 2.0 - 6.0
		var child_researched: bool = int(technology[&"state"]) == _STATE_RESEARCHED
		var blocks: Array = technology[&"prerequisite_indices"]
		# First the grey lines, then the yellow ones over them
		for pass_number: int in 2:
			for block: Array in blocks:
				var dashed: bool = block.size() > 1
				for parent_index: int in block:
					if not by_index.has(parent_index):
						continue
					var parent: Dictionary = by_index[parent_index]
					var done: bool = child_researched and int(parent[&"state"]) == _STATE_RESEARCHED
					if (pass_number == 1) != done:
						continue
					var parent_bottom: Vector2 = _node_position(parent) + Vector2(_NODE_SIZE.x / 2.0, _EMBLEM_SIZE - 8.0 + _PLATE_HEIGHT)
					var colour: Color = _LINE_DONE_COLOUR if done else _LINE_COLOUR
					_draw_path(canvas, parent_bottom, Vector2(parent_bottom.x, middle_y), Vector2(child_top.x, middle_y), child_top, colour, dashed)


func _draw_path(canvas: Control, a: Vector2, b: Vector2, c: Vector2, d: Vector2, colour: Color, dashed: bool) -> void:
	for segment: Array in [[a, b], [b, c], [c, d]]:
		var from: Vector2 = segment[0]
		var to: Vector2 = segment[1]
		if from.is_equal_approx(to):
			continue
		if dashed:
			canvas.draw_dashed_line(from, to, colour, 2.0, 7.0)
		else:
			canvas.draw_line(from, to, colour, 2.0)
