## Кругла іконка пікапа: колір із data/pickups.json + знак-літера.
class_name PickupIcon
extends Control

var color := Palette.PICKUP_DEFAULT
var letter := "?"


func _init(col: Color, l: String, px: float = 56.0) -> void:
	color = col
	letter = l
	custom_minimum_size = Vector2(px, px)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5


func _draw() -> void:
	var c := size * 0.5
	var r: float = min(size.x, size.y) * 0.46
	draw_circle(c, r, color)
	draw_arc(c, r, 0.0, TAU, 48, color.darkened(0.35), 3.0)
	var f: Font = UIKit.font()
	if f == null:
		f = ThemeDB.fallback_font
	var fs := int(size.y * 0.5)
	var w := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string(f, Vector2(c.x - w * 0.5, c.y + fs * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.WHITE)
