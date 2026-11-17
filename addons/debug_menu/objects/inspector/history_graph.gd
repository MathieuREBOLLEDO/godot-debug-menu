extends Control

## Courbe d'une variable numérique sur la dernière minute (variable_history.gd).
## Valeur tenue entre deux changements (escalier) ; min et max en marge.

const MARGIN: float = 4.0

var _entries: Array = [] # [temps, valeur]
var _now: float = 0.0
var _duration: float = 60.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 90)


func show_entries(entries: Array, now: float, duration: float) -> void:
	_entries = entries
	_now = now
	_duration = duration
	queue_redraw()


func _draw() -> void:
	var accent: Color = get_theme_color("font_hover_color", "MenuButton")
	var muted: Color = get_theme_color("font_color", "MenuButton")
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))
	if _entries.is_empty():
		return
	var low: float = INF
	var high: float = -INF
	for entry in _entries:
		low = minf(low, float(entry[1]))
		high = maxf(high, float(entry[1]))
	if is_equal_approx(low, high):
		low -= 1.0
		high += 1.0

	var points: PackedVector2Array = PackedVector2Array()
	for index in _entries.size():
		var point: Vector2 = _to_point(_entries[index][0], float(_entries[index][1]), low, high)
		if index > 0:
			points.append(Vector2(point.x, points[points.size() - 1].y)) # escalier
		points.append(point)
	points.append(Vector2(size.x - MARGIN, points[points.size() - 1].y)) # jusqu'à maintenant
	if points.size() >= 2:
		draw_polyline(points, accent, 1.5, true)

	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_default_font_size() - 3
	draw_string(font, Vector2(MARGIN, font_size + MARGIN), "%.3f" % high, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, muted)
	draw_string(font, Vector2(MARGIN, size.y - MARGIN), "%.3f" % low, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, muted)


func _to_point(time: float, value: float, low: float, high: float) -> Vector2:
	var x: float = remap(clampf(time, _now - _duration, _now), _now - _duration, _now, MARGIN, size.x - MARGIN)
	var y: float = remap(value, low, high, size.y - MARGIN, MARGIN)
	return Vector2(x, y)
