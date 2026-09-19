## Зелена «галочка»: предмет одягнено.
class_name CheckIcon
extends Control


func _init(px: float = 26.0) -> void:
	custom_minimum_size = Vector2(px, px)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var u: float = min(size.x, size.y) / 26.0
	draw_polyline(PackedVector2Array([Vector2(4, 14) * u, Vector2(10, 21) * u, Vector2(23, 5) * u]), Palette.ITEM_EQUIPPED, 5.0 * u)
