## Смужка часу пікапа: заповнення зменшується від 1 до 0.
class_name PickupBar
extends Control

const TRACK := Color(0, 0, 0, 0.3)

var ratio := 1.0
var color := Palette.PICKUP_DEFAULT


func _init(col: Color) -> void:
	color = col
	custom_minimum_size = Vector2(240, 28)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_ratio(r: float) -> void:
	ratio = clampf(r, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = TRACK
	bg.set_corner_radius_all(14)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	if ratio > 0.0:
		var fg := StyleBoxFlat.new()
		fg.bg_color = color
		fg.set_corner_radius_all(14)
		draw_style_box(fg, Rect2(Vector2(4, 4), Vector2((size.x - 8.0) * ratio, size.y - 8.0)))
