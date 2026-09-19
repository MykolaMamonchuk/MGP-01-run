## Сердечко життя: повне (червоне) або порожнє (сірий контур).
## Використання: var h := HeartIcon.new(44.0); h.set_full(false)
class_name HeartIcon
extends Control

var full := true
var fill := Palette.HEART
var empty := Palette.HEART_EMPTY


func _init(px: float = 44.0) -> void:
	custom_minimum_size = Vector2(px, px)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5


func set_full(on: bool) -> void:
	full = on
	queue_redraw()


func _draw() -> void:
	var s := size.x
	var c := size * 0.5
	var pts := PackedVector2Array()
	# сердечко з двох дуг і вістря
	for i in range(25):
		var t := float(i) / 24.0 * PI
		pts.append(c + Vector2(-s * 0.25 + cos(PI - t) * s * 0.25, -s * 0.12 - sin(t) * s * 0.25))
	for i in range(25):
		var t := float(i) / 24.0 * PI
		pts.append(c + Vector2(s * 0.25 + cos(PI - t) * s * 0.25, -s * 0.12 - sin(t) * s * 0.25))
	pts.append(c + Vector2(0.0, s * 0.42))
	if full:
		draw_colored_polygon(pts, fill)
		draw_polyline(pts + PackedVector2Array([pts[0]]), fill.darkened(0.3), 3.0)
	else:
		draw_polyline(pts + PackedVector2Array([pts[0]]), empty, 4.0)
