## Плашка «★ ціна» під купованим вузлом мапи.
class_name PriceBadge
extends Control

var price := 0


func _init(p: int) -> void:
	price = p
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(92, 32)
	pivot_offset = size * 0.5


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.MAP_BADGE_BG)
	draw_rect(Rect2(Vector2(0, size.y - 4.0), Vector2(size.x, 4.0)), Palette.MAP_BADGE_EDGE)
	# зірочка
	var c := Vector2(17, 16)
	var pts := PackedVector2Array()
	for i in 10:
		var rr := 11.0 if i % 2 == 0 else 4.8
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, Palette.STAR)
	var f: Font = UIKit.font()
	if f == null:
		f = ThemeDB.fallback_font
	draw_string(f, Vector2(32, 24), str(price), HORIZONTAL_ALIGNMENT_LEFT, 58, 22, Palette.WHITE)
