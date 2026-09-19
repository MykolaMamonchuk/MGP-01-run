## Фішка героя на мапі: кольоровий блок-чоловічок, який «дихає» масштабом.
class_name HeroMarker
extends Control

var color := Palette.HERO_DEFAULT
var t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(80, 90)
	pivot_offset = Vector2(40, 90)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	t += delta
	scale = Vector2(1.0 + sin(t * 4.0) * 0.04, 1.0 - sin(t * 4.0) * 0.04)
	queue_redraw()


func _draw() -> void:
	var c := Vector2(40, 40)
	draw_circle(c + Vector2(0, 48), 14.0, Palette.MARKER_SHADOW)
	draw_rect(Rect2(Vector2(22, 8), Vector2(36, 42)), color)
	draw_rect(Rect2(Vector2(26, 50), Vector2(10, 14)), color.darkened(0.2))
	draw_rect(Rect2(Vector2(44, 50), Vector2(10, 14)), color.darkened(0.2))
	for x in [31.0, 49.0]:
		draw_circle(Vector2(x, 26), 5.0, Palette.EYE_WHITE)
		draw_circle(Vector2(x + 1, 27), 2.6, Palette.HERO_EYE)
	draw_rect(Rect2(Vector2(35, 36), Vector2(10, 3)), Palette.HERO_MOUTH)
