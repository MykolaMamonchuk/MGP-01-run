## Намальовані іконки для HUD (без емодзі та без тексту як єдиного носія смислу).
## Кожна іконка — маленький Control, який малює себе у _draw().
## Використання: var i := Icons.StarIcon.new()
class_name Icons
extends RefCounted

const SIZE_SMALL := Vector2(56, 56)
const SIZE_BIG := Vector2(96, 96)


## Жовта п'ятикутна зірочка — та сама форма, що й у star.gd.
class StarIcon:
	extends Control

	var fill := Color("#FFD54F")
	var edge := Color("#F9A825")

	func _init(px: float = 56.0) -> void:
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var r_out: float = min(size.x, size.y) * 0.46
		var r_in := r_out * 0.43
		var pts := PackedVector2Array()
		for i in 10:
			var r := r_out if i % 2 == 0 else r_in
			var a := -PI / 2.0 + i * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, fill)
		draw_polyline(pts + PackedVector2Array([pts[0]]), edge, 3.0)


## Дорослий + дитина: два кола різного розміру з «плечима».
class ParentIcon:
	extends Control

	var adult := Color("#5C6BC0")
	var kid := Color("#FF8A65")

	func _init(px: float = 64.0) -> void:
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var u: float = min(size.x, size.y) / 64.0
		# дорослий
		draw_circle(Vector2(22, 18) * u, 11.0 * u, adult)
		draw_rect(Rect2(Vector2(11, 32) * u, Vector2(22, 26) * u), adult)
		# дитина
		draw_circle(Vector2(46, 28) * u, 8.0 * u, kid)
		draw_rect(Rect2(Vector2(38, 38) * u, Vector2(16, 20) * u), kid)


## Тап: кружечок-палець із трикутником-вказівником угору.
class HandIcon:
	extends Control

	var fill := Color("#FFFFFF")
	var edge := Color("#37474F")

	func _init(px: float = 96.0) -> void:
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var u: float = min(size.x, size.y) / 96.0
		var c := Vector2(48, 58) * u
		draw_circle(c, 26.0 * u, fill)
		draw_arc(c, 26.0 * u, 0.0, TAU, 32, edge, 4.0 * u)
		var tri := PackedVector2Array([
			Vector2(48, 8) * u,
			Vector2(32, 34) * u,
			Vector2(64, 34) * u,
		])
		draw_colored_polygon(tri, edge)


## Місяць: коло мінус зміщене коло (малюємо тлом сцени).
class MoonIcon:
	extends Control

	var fill := Color("#FFF3C4")
	var back := Color(0.05, 0.05, 0.2, 1.0)

	func _init(px: float = 96.0) -> void:
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var u: float = min(size.x, size.y) / 96.0
		draw_circle(Vector2(48, 48) * u, 34.0 * u, fill)
		draw_circle(Vector2(64, 38) * u, 30.0 * u, back)


## Станція: закруглений щит на стовпчику.
class StationIcon:
	extends Control

	var sign_color := Color("#4FC3F7")
	var pole_color := Color("#8D6E63")

	func _init(px: float = 96.0) -> void:
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var u: float = min(size.x, size.y) / 96.0
		draw_rect(Rect2(Vector2(44, 40) * u, Vector2(8, 50) * u), pole_color)
		var r := Rect2(Vector2(14, 10) * u, Vector2(68, 40) * u)
		draw_rect(r, sign_color)
		draw_circle(Vector2(14, 30) * u, 20.0 * u, sign_color)
		draw_circle(Vector2(82, 30) * u, 20.0 * u, sign_color)
		draw_circle(Vector2(48, 30) * u, 9.0 * u, Color("#FFFFFF"))


## Двері Розвилки: піктограма світу. meadow — горбок і квітка; forest — дерево; beach — хвиля і сонце.
class WorldIcon:
	extends Control

	var world_id := "meadow"

	func _init(id: String, px: float = 120.0) -> void:
		world_id = id
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var u: float = min(size.x, size.y) / 120.0
		match world_id:
			"forest":
				draw_rect(Rect2(Vector2(52, 70) * u, Vector2(16, 40) * u), Color("#795548"))
				draw_circle(Vector2(60, 50) * u, 34.0 * u, Color("#2E7D32"))
				draw_circle(Vector2(44, 62) * u, 22.0 * u, Color("#43A047"))
				draw_circle(Vector2(78, 60) * u, 22.0 * u, Color("#43A047"))
			"beach":
				draw_circle(Vector2(86, 34) * u, 18.0 * u, Color("#FFEE58"))
				var pts := PackedVector2Array()
				for i in 25:
					var x := 8.0 + i * 4.3
					pts.append(Vector2(x, 78.0 + sin(i * 0.55) * 8.0) * u)
				draw_polyline(pts, Color("#29B6F6"), 10.0 * u)
				draw_rect(Rect2(Vector2(8, 92) * u, Vector2(104, 20) * u), Color("#FFE0A3"))
			_:
				draw_circle(Vector2(60, 110) * u, 60.0 * u, Color("#7CC46B"))
				draw_rect(Rect2(Vector2(58, 40) * u, Vector2(4, 30) * u), Color("#388E3C"))
				for i in 6:
					var a := i * PI / 3.0
					draw_circle(Vector2(60, 36) * u + Vector2(cos(a), sin(a)) * 12.0 * u, 8.0 * u, Color("#F06292"))
				draw_circle(Vector2(60, 36) * u, 7.0 * u, Color("#FFF176"))


## Мінізавдання: зірка / прапорець / іскра — залежно від типу.
class QuestIcon:
	extends Control

	var kind := "stars"

	func _init(k: String, px: float = 40.0) -> void:
		kind = k
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var u: float = min(size.x, size.y) / 40.0
		match kind:
			"passed":
				draw_rect(Rect2(Vector2(8, 4) * u, Vector2(4, 32) * u), Color("#8D6E63"))
				draw_colored_polygon(PackedVector2Array([Vector2(12, 4) * u, Vector2(34, 12) * u, Vector2(12, 20) * u]), Color("#EF5350"))
			"events":
				for i in 4:
					var a := i * PI / 2.0
					draw_line(Vector2(20, 20) * u, Vector2(20, 20) * u + Vector2(cos(a), sin(a)) * 16.0 * u, Color("#26C6DA"), 4.0 * u)
				draw_circle(Vector2(20, 20) * u, 6.0 * u, Color("#FFFFFF"))
			_:
				var c := Vector2(20, 20) * u
				var pts := PackedVector2Array()
				for i in 10:
					var r := (17.0 if i % 2 == 0 else 7.0) * u
					var a := -PI / 2.0 + i * PI / 5.0
					pts.append(c + Vector2(cos(a), sin(a)) * r)
				draw_colored_polygon(pts, Color("#FFD54F"))
