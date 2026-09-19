## Плашка «★ ціна» під купованим вузлом мапи.
##
## Розмір задається множником: плашка мусить уміщатися ВСЕРЕДИНІ свого вузла, а вузол на
## тісному екрані меншає (див. MapScreen.node_radius). Доти плашка була прибита до 92×32 і
## звисала з кнопки на 8 px донизу — тап по самій ціні, тобто по тому, де й написано «80»,
## пролітав повз кнопку. Усі числа малюнка беруться від розміру, тож за k = 1 виходить рівно
## те, що було намальовано раніше.
class_name PriceBadge
extends Control

const BASE := Vector2(92, 32)

var price := 0


func _init(p: int, k: float = 1.0) -> void:
	price = p
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = BASE * k
	pivot_offset = size * 0.5


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.MAP_BADGE_BG)
	var edge := size.y * 0.125
	draw_rect(Rect2(Vector2(0, size.y - edge), Vector2(size.x, edge)), Palette.MAP_BADGE_EDGE)
	# зірочка
	var c := Vector2(size.y * 0.53, size.y * 0.5)
	var pts := PackedVector2Array()
	for i in 10:
		var rr := size.y * (0.344 if i % 2 == 0 else 0.15)
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, Palette.STAR)
	var f: Font = UIKit.font()
	if f == null:
		f = ThemeDB.fallback_font
	draw_string(f, Vector2(size.y, size.y * 0.75), str(price), HORIZONTAL_ALIGNMENT_LEFT,
		size.x - size.y - 2.0, int(size.y * 0.6875), Palette.WHITE)
