## Замочок на закритому вузлі мапи.
class_name LockIcon
extends Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(28, 32)


func _draw() -> void:
	draw_rect(Rect2(Vector2(2, 14), Vector2(24, 18)), Palette.LOCK_BODY)
	draw_arc(Vector2(14, 14), 8.0, PI, TAU, 12, Palette.LOCK_BODY, 4.0, true)
	draw_circle(Vector2(14, 23), 3.5, Palette.LOCK_HOLE)
