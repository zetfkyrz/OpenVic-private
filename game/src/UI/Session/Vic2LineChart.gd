extends Control
## A line chart in the style of the graph of the budget button of the top bar of Victoria 2: the pink box with the grid and
## the dark frame, thin coloured lines on it. Lines of the group 0 use the left value axis, lines of the group 1 (another
## unit, e.g. the number of employees) the right one. Hovering shows the values of the month under the mouse.
##
## Use `set_data(labels, series)`: labels are "YYYY.MM" strings, one per point; series is an Array of Dictionaries
## { name: String, colour: Color, values: PackedFloat32Array, group: int (optional, 0), format: String (optional, "money"|"count") }.

# Colours sampled from gfx/interface/topbar_graph_bg.tga of the original interface
const BACKGROUND_TOP_COLOUR: Color = Color(0.65, 0.57, 0.545)
const BACKGROUND_BOTTOM_COLOUR: Color = Color(0.575, 0.48, 0.45)
const BORDER_COLOUR: Color = Color(0.075, 0.075, 0.075)
const INNER_BORDER_COLOUR: Color = Color(0.48, 0.41, 0.39)
const GRID_COLOUR: Color = Color(0.36, 0.28, 0.26, 0.4)
const YEAR_GRID_COLOUR: Color = Color(0.26, 0.18, 0.16, 0.55)
const ZERO_COLOUR: Color = Color(0.1, 0.05, 0.05, 0.85)
const LABEL_COLOUR: Color = Color(0.12, 0.07, 0.06)
const FONT_SIZE: int = 11
const LINE_WIDTH: float = 2.0
const GRID_LINES: int = 4
## Shortest time span of the chart in points (months): a young factory does not stretch its few months over the whole width
const MIN_POINTS: int = 12

var _labels: PackedStringArray = []
var _series: Array = []
var _hover_index: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(240, 120)


func set_data(new_labels: PackedStringArray, new_series: Array) -> void:
	_labels = new_labels
	_series = new_series
	queue_redraw()


func clear() -> void:
	set_data(PackedStringArray(), [])


func _has_group(group: int) -> bool:
	for line: Dictionary in _series:
		if int(line.get(&"group", 0)) == group:
			return true
	return false


func _plot_rect() -> Rect2:
	var left: float = 54.0
	var right: float = 46.0 if _has_group(1) else 10.0
	return Rect2(left, 10.0, maxf(size.x - left - right, 10.0), maxf(size.y - 10.0 - 22.0, 10.0))


## Rounds the range of the values to numbers that look good on an axis: [lowest, highest, step]
func _nice_range(lowest: float, highest: float) -> Array[float]:
	lowest = minf(lowest, 0.0)
	highest = maxf(highest, 0.0)
	var span: float = highest - lowest
	if span <= 0.0:
		return [0.0, 1.0, 0.25]
	var rough: float = span / float(GRID_LINES)
	var magnitude: float = pow(10.0, floorf(log(rough) / log(10.0)))
	var step: float = magnitude
	for factor: float in [1.0, 2.0, 2.5, 5.0, 10.0]:
		step = magnitude * factor
		if step >= rough:
			break
	var low: float = floorf(lowest / step) * step
	var high: float = ceilf(highest / step) * step
	if high <= low:
		high = low + step
	return [low, high, step]


func _group_range(group: int) -> Array[float]:
	var lowest: float = INF
	var highest: float = -INF
	for line: Dictionary in _series:
		if int(line.get(&"group", 0)) != group:
			continue
		for value: float in line[&"values"]:
			lowest = minf(lowest, value)
			highest = maxf(highest, value)
	if lowest == INF:
		return [0.0, 1.0, 0.25]
	return _nice_range(lowest, highest)


func _point_count() -> int:
	var count: int = _labels.size()
	for line: Dictionary in _series:
		count = maxi(count, (line[&"values"] as PackedFloat32Array).size())
	return maxi(count, MIN_POINTS)


func _x_of(index: int, plot: Rect2) -> float:
	var count: int = _point_count()
	return plot.position.x + plot.size.x * float(index) / float(maxi(count - 1, 1))


func _format_axis(value: float, step: float) -> String:
	if absf(value) >= 1000000.0:
		return "%s M" % GUINode.float_to_string_dp(value / 1000000.0, 1 if step < 1000000.0 else 0)
	if absf(value) >= 10000.0:
		return "%s k" % GUINode.float_to_string_dp(value / 1000.0, 0)
	if absf(value) >= 1000.0:
		return "%s k" % GUINode.float_to_string_dp(value / 1000.0, 1)
	if step < 1.0:
		return GUINode.float_to_string_dp(value, 2)
	return GUINode.float_to_string_dp(value, 0)


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var frame := Rect2(Vector2.ZERO, size)

	# The box of the original graph: pink, a little darker at the bottom, a dark frame with a lighter line inside it
	draw_polygon(
		PackedVector2Array([frame.position, Vector2(frame.end.x, frame.position.y), frame.end, Vector2(frame.position.x, frame.end.y)]),
		PackedColorArray([BACKGROUND_TOP_COLOUR, BACKGROUND_TOP_COLOUR, BACKGROUND_BOTTOM_COLOUR, BACKGROUND_BOTTOM_COLOUR])
	)
	draw_rect(frame.grow(-1.0), INNER_BORDER_COLOUR, false, 1.0)
	draw_rect(frame, BORDER_COLOUR, false, 1.0)

	var plot: Rect2 = _plot_rect()
	var left_range: Array[float] = _group_range(0)
	var right_range: Array[float] = _group_range(1)

	# Horizontal grid and the value axes
	for i: int in GRID_LINES + 1:
		var fraction: float = float(i) / float(GRID_LINES)
		var y: float = plot.end.y - plot.size.y * fraction
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), GRID_COLOUR, 1.0)
		var left_value: float = lerpf(left_range[0], left_range[1], fraction)
		var left_text: String = _format_axis(left_value, left_range[2])
		var left_width: float = font.get_string_size(left_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, FONT_SIZE).x
		draw_string(font, Vector2(plot.position.x - 6.0 - left_width, y + 4.0), left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, LABEL_COLOUR)
		if _has_group(1):
			var right_value: float = lerpf(right_range[0], right_range[1], fraction)
			draw_string(font, Vector2(plot.end.x + 6.0, y + 4.0), _format_axis(right_value, right_range[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, LABEL_COLOUR)

	# The line of zero of the money axis
	if left_range[0] < 0.0 and left_range[1] > 0.0:
		var zero_y: float = plot.end.y - plot.size.y * (0.0 - left_range[0]) / (left_range[1] - left_range[0])
		draw_line(Vector2(plot.position.x, zero_y), Vector2(plot.end.x, zero_y), ZERO_COLOUR, 1.0)

	# The years: a vertical line and the number of the year at every January
	var last_label_end: float = -1000.0
	for i: int in _labels.size():
		var label: String = _labels[i]
		if not label.ends_with(".01"):
			continue
		var x: float = _x_of(i, plot)
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), YEAR_GRID_COLOUR, 1.0)
		var year_text: String = label.substr(0, 4)
		var year_width: float = font.get_string_size(year_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		if x - year_width / 2.0 > last_label_end + 6.0:
			draw_string(font, Vector2(x - year_width / 2.0, size.y - 7.0), year_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, LABEL_COLOUR)
			last_label_end = x + year_width / 2.0

	# The lines
	for line: Dictionary in _series:
		var values: PackedFloat32Array = line[&"values"]
		if values.is_empty():
			continue
		var axis: Array[float] = right_range if int(line.get(&"group", 0)) == 1 else left_range
		var points := PackedVector2Array()
		for i: int in values.size():
			var fraction: float = (values[i] - axis[0]) / (axis[1] - axis[0])
			points.append(Vector2(_x_of(i, plot), plot.end.y - plot.size.y * clampf(fraction, 0.0, 1.0)))
		var colour: Color = line[&"colour"]
		if points.size() >= 2:
			draw_polyline(points, Color(0, 0, 0, 0.35), LINE_WIDTH + 1.5, true)
			draw_polyline(points, colour, LINE_WIDTH, true)
		draw_circle(points[points.size() - 1], 3.0, colour)

	# The month under the mouse
	if _hover_index >= 0 and _hover_index < _point_count():
		var hover_x: float = _x_of(_hover_index, plot)
		draw_line(Vector2(hover_x, plot.position.y), Vector2(hover_x, plot.end.y), Color(0.1, 0.05, 0.05, 0.6), 1.0)
		for line: Dictionary in _series:
			var values: PackedFloat32Array = line[&"values"]
			if _hover_index >= values.size():
				continue
			var axis: Array[float] = right_range if int(line.get(&"group", 0)) == 1 else left_range
			var fraction: float = (values[_hover_index] - axis[0]) / (axis[1] - axis[0])
			draw_circle(Vector2(hover_x, plot.end.y - plot.size.y * clampf(fraction, 0.0, 1.0)), 4.0, line[&"colour"])

	if _series.is_empty() or _labels.is_empty():
		var text: String = "Пока нет данных: статистика копится по месяцам"
		var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2((size.x - text_width) / 2.0, size.y / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, LABEL_COLOUR)


func _index_at(position_x: float) -> int:
	var plot: Rect2 = _plot_rect()
	var count: int = _point_count()
	var fraction: float = (position_x - plot.position.x) / plot.size.x
	var index: int = roundi(fraction * float(count - 1))
	if index < 0 or index >= _labels.size():
		return -1
	return index


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var index: int = _index_at((event as InputEventMouseMotion).position.x)
		if index != _hover_index:
			_hover_index = index
			queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover_index != -1:
		_hover_index = -1
		queue_redraw()


func _get_tooltip(at_position: Vector2) -> String:
	var index: int = _index_at(at_position.x)
	if index < 0:
		return ""
	var lines: PackedStringArray = [_labels[index]]
	for line: Dictionary in _series:
		var values: PackedFloat32Array = line[&"values"]
		if index >= values.size():
			continue
		var value: float = values[index]
		var text: String = GUINode.float_to_string_dp(value, 0) if line.get(&"format", "money") == "count" else GUINode.float_to_string_dp(value, 1)
		lines.append("%s: %s" % [line[&"name"], text])
	return "\n".join(lines)
