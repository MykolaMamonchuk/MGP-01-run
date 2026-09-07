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


## Жест-підказка: "tap" — пальчик з кільцями; "left/right/up/down" — товста стрілка; "hold" — пальчик і дужка.
class GestureIcon:
	extends Control

	var kind := "tap"
	var _t := 0.0

	func _init(k: String, px: float = 120.0) -> void:
		kind = k
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var u: float = min(size.x, size.y) / 120.0
		var c := size * 0.5
		var col := Color("#FFF176")
		var edge := Color("#3E2723")
		match kind:
			"left", "right", "up", "down":
				var dir := Vector2.LEFT
				if kind == "right": dir = Vector2.RIGHT
				elif kind == "up": dir = Vector2.UP
				elif kind == "down": dir = Vector2.DOWN
				var shift := dir * (sin(_t * 6.0) * 8.0 * u)
				var tip := c + dir * 48.0 * u + shift
				var base := c - dir * 30.0 * u + shift
				var n := Vector2(-dir.y, dir.x)
				var pts := PackedVector2Array([
					tip, tip - dir * 34.0 * u + n * 34.0 * u, tip - dir * 34.0 * u + n * 14.0 * u,
					base + n * 14.0 * u, base - n * 14.0 * u,
					tip - dir * 34.0 * u - n * 14.0 * u, tip - dir * 34.0 * u - n * 34.0 * u])
				draw_colored_polygon(pts, col)
				draw_polyline(pts + PackedVector2Array([pts[0]]), edge, 5.0 * u)
			"hold":
				_finger(c, u, col, edge, 0.0)
				draw_arc(c + Vector2(0, -10) * u, 46.0 * u, -PI * 0.5, -PI * 0.5 + TAU * fmod(_t * 0.5, 1.0), 40, Color("#66BB6A"), 8.0 * u)
			_:
				var press := absf(sin(_t * 5.0))
				_finger(c, u, col, edge, press * 10.0 * u)
				for i in range(2):
					var r := (18.0 + 22.0 * fmod(_t * 0.9 + 0.5 * i, 1.0)) * u
					var a := 1.0 - fmod(_t * 0.9 + 0.5 * i, 1.0)
					draw_arc(c + Vector2(0, 26) * u, r, 0.0, TAU, 32, Color(1, 1, 1, a * 0.8), 4.0 * u)

	func _finger(c: Vector2, u: float, col: Color, edge: Color, dy: float) -> void:
		var top := c + Vector2(0, -44 + dy) * u
		draw_rect(Rect2(top + Vector2(-12, 0) * u, Vector2(24, 60) * u), col)
		draw_circle(top, 12.0 * u, col)
		draw_rect(Rect2(top + Vector2(-26, 34) * u, Vector2(52, 30) * u), col)
		draw_arc(top, 12.0 * u, PI, TAU, 16, edge, 4.0 * u)
		draw_line(top + Vector2(-12, 0) * u, top + Vector2(-12, 40) * u, edge, 4.0 * u)
		draw_line(top + Vector2(12, 0) * u, top + Vector2(12, 34) * u, edge, 4.0 * u)


## Картинка предмета крамниці: фронтальна проєкція вокселя піксель-артом (перша непорожня клітинка по z).
## voxel "" + колір — слід: три іскри в цьому кольорі; voxel "" без кольору — «нічого» (кружок із рискою).
class VoxelIcon:
	extends Control

	static var _defs: Dictionary = {}     # назва → розібраний опис (кеш)

	var voxel := ""
	var color := Color(0, 0, 0, 0)

	func _init(voxel_name: String, px: float, col: Color = Color(0, 0, 0, 0)) -> void:
		voxel = voxel_name
		color = col
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	static func def_for(voxel_name: String) -> Dictionary:
		if not _defs.has(voxel_name):
			_defs[voxel_name] = VoxelBuilder.load_def("res://data/voxels/%s.json" % voxel_name)
		return _defs[voxel_name]

	## Чиста функція: фронтальна проєкція — [{x, y, color}] (рядок 0 = перед, y — знизу вгору).
	static func front_elevation(def: Dictionary) -> Array:
		var out := []
		if def.is_empty():
			return out
		var parsed := VoxelBuilder.parse(def)
		var cells: Dictionary = parsed["cells"]
		var dims: Vector3i = parsed["size"]
		for y in range(dims.y):
			for x in range(dims.x):
				for z in range(dims.z):
					var p := Vector3i(x, y, z)
					if cells.has(p):
						out.append({"x": x, "y": y, "color": cells[p]})
						break
		return out

	func _draw() -> void:
		var px: float = min(size.x, size.y)
		var c := size * 0.5
		if voxel == "":
			if color.a > 0.0:
				_sparkle(c + Vector2(-0.25, 0.15) * px, px * 0.16, color)
				_sparkle(c + Vector2(0.05, -0.2) * px, px * 0.24, color)
				_sparkle(c + Vector2(0.3, 0.22) * px, px * 0.12, color.lightened(0.3))
			else:
				draw_arc(c, px * 0.3, 0.0, TAU, 32, Color("#B0BEC5"), px * 0.07)
				draw_line(c + Vector2(-0.2, 0.2) * px, c + Vector2(0.2, -0.2) * px, Color("#B0BEC5"), px * 0.07)
			return
		var rects := front_elevation(def_for(voxel))
		if rects.is_empty():
			return
		var w := 0
		var h := 0
		for r in rects:
			w = maxi(w, int(r["x"]) + 1)
			h = maxi(h, int(r["y"]) + 1)
		var cell := floorf(px * 0.9 / float(maxi(w, h)))
		var origin := c - Vector2(w, h) * cell * 0.5
		for r in rects:
			var pos := origin + Vector2(float(int(r["x"])), float(h - 1 - int(r["y"]))) * cell
			draw_rect(Rect2(pos, Vector2(cell, cell)), r["color"])
			# ледь темніший низ клітинки — читається як піксель-арт
			draw_rect(Rect2(pos + Vector2(0, cell * 0.8), Vector2(cell, cell * 0.2)), (r["color"] as Color).darkened(0.18))

	func _sparkle(p: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 8:
			var rr := r if i % 2 == 0 else r * 0.38
			var a := -PI / 2.0 + i * PI / 4.0
			pts.append(p + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, col)


## Вкладка слота крамниці: hat — капелюх, face — окуляри, neck — шарфик, back — крильця, trail — іскри.
class SlotIcon:
	extends Control

	var slot := "hat"
	var fill := Color.WHITE
	var edge := Color("#3E2723")

	func _init(s: String, px: float = 64.0) -> void:
		slot = s
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var u: float = min(size.x, size.y) / 64.0
		match slot:
			"face":
				for cx in [20.0, 44.0]:
					draw_circle(Vector2(cx, 34) * u, 11.0 * u, Color("#B3E5FC"))
					draw_arc(Vector2(cx, 34) * u, 11.0 * u, 0.0, TAU, 24, edge, 4.0 * u)
				draw_line(Vector2(31, 34) * u, Vector2(33, 34) * u, edge, 4.0 * u)
				draw_line(Vector2(6, 30) * u, Vector2(10, 34) * u, edge, 4.0 * u)
				draw_line(Vector2(58, 30) * u, Vector2(54, 34) * u, edge, 4.0 * u)
			"neck":
				var pts := PackedVector2Array()
				for i in 13:
					var a := PI + PI * float(i) / 12.0
					pts.append(Vector2(32, 26) * u + Vector2(cos(a), sin(a) * 0.6) * 22.0 * u)
				draw_polyline(pts, Color("#EF5350"), 11.0 * u)
				draw_rect(Rect2(Vector2(36, 26) * u, Vector2(11, 30) * u), Color("#EF5350"))
				draw_rect(Rect2(Vector2(36, 50) * u, Vector2(11, 6) * u), Color("#C62828"))
			"back":
				for s in [-1.0, 1.0]:
					var pts := PackedVector2Array([
						Vector2(32 + s * 4, 32) * u, Vector2(32 + s * 28, 10) * u,
						Vector2(32 + s * 30, 30) * u, Vector2(32 + s * 22, 48) * u, Vector2(32 + s * 4, 46) * u])
					draw_colored_polygon(pts, fill)
					draw_polyline(pts + PackedVector2Array([pts[0]]), edge, 3.0 * u)
			"trail":
				for i in 3:
					var p := Vector2(14 + i * 18, 44 - i * 12) * u
					var r := (6.0 + i * 3.0) * u
					var pts := PackedVector2Array()
					for k in 8:
						var rr := r if k % 2 == 0 else r * 0.4
						var a := -PI / 2.0 + k * PI / 4.0
						pts.append(p + Vector2(cos(a), sin(a)) * rr)
					draw_colored_polygon(pts, Color("#FFD54F"))
			_:
				# капелюх: криси + тулія
				draw_rect(Rect2(Vector2(8, 40) * u, Vector2(48, 8) * u), edge)
				draw_rect(Rect2(Vector2(18, 14) * u, Vector2(28, 28) * u), fill)
				draw_rect(Rect2(Vector2(18, 34) * u, Vector2(28, 6) * u), Color("#EF5350"))
				draw_rect(Rect2(Vector2(18, 14) * u, Vector2(28, 28) * u), edge, false, 3.0 * u)


## Мапа для кнопки меню: складений аркуш із трьома панелями і пунктирною стежкою.
class MapGlyph:
	extends Control

	func _init(px: float = 56.0) -> void:
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var u: float = min(size.x, size.y) / 56.0
		var paper := Color("#FFF8E1")
		for i in 3:
			var x0 := (6.0 + i * 15.0) * u
			var dy := (4.0 if i == 1 else 0.0) * u
			var pts := PackedVector2Array([
				Vector2(x0, 10.0 * u + dy), Vector2(x0 + 15.0 * u, 10.0 * u - dy),
				Vector2(x0 + 15.0 * u, 46.0 * u - dy), Vector2(x0, 46.0 * u + dy)])
			draw_colored_polygon(pts, paper if i != 1 else paper.darkened(0.08))
		draw_circle(Vector2(16, 34) * u, 5.0 * u, Color("#66BB6A"))
		draw_circle(Vector2(40, 20) * u, 5.0 * u, Color("#EF5350"))
		var a := Vector2(16, 34) * u
		var b := Vector2(40, 20) * u
		for k in range(0, 6, 2):
			draw_line(a.lerp(b, k / 6.0), a.lerp(b, (k + 1) / 6.0), Color("#8D6E63"), 3.0 * u)


## Шестірня «Налаштування»: коло з зубцями і дірочкою.
class GearIcon:
	extends Control

	var fill := Color("#ECEFF1")

	func _init(px: float = 56.0) -> void:
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r: float = min(size.x, size.y) * 0.3
		for i in 8:
			var a := TAU * float(i) / 8.0
			var d := Vector2(cos(a), sin(a))
			var n := Vector2(-d.y, d.x) * r * 0.22
			var p0 := c + d * r * 0.8
			var p1 := c + d * r * 1.3
			draw_colored_polygon(PackedVector2Array([p0 + n, p1 + n * 0.7, p1 - n * 0.7, p0 - n]), fill)
		draw_circle(c, r, fill)
		draw_circle(c, r * 0.42, Color("#607D8B"))


## Характеристика героя (GDD v1.3 §5): "hearts" — серце, "magnet" — U-магніт (червоно-синій),
## "speed" — блискавка, "luck" — чотирикутна зірка. Без тексту.
class StatIcon:
	extends Control

	var kind := "hearts"
	var edge := Color("#3E2723")

	func _init(k: String, px: float = 36.0) -> void:
		kind = k
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var u: float = min(size.x, size.y) / 36.0
		match kind:
			"magnet":
				# дужка U: ліва ніжка червона, права синя, сірі наконечники
				var c := Vector2(18, 16) * u
				var r := 10.0 * u
				var w := 7.0 * u
				draw_arc(c, r, PI, PI * 1.5, 12, Color("#EF5350"), w)
				draw_arc(c, r, PI * 1.5, TAU, 12, Color("#42A5F5"), w)
				draw_line(c + Vector2(-r, 0), c + Vector2(-r, 12) * u, Color("#EF5350"), w)
				draw_line(c + Vector2(r, 0), c + Vector2(r, 12) * u, Color("#42A5F5"), w)
				draw_rect(Rect2(c + Vector2(-r - w * 0.5, 9.0 * u), Vector2(w, 4.0 * u)), Color("#B0BEC5"))
				draw_rect(Rect2(c + Vector2(r - w * 0.5, 9.0 * u), Vector2(w, 4.0 * u)), Color("#B0BEC5"))
			"speed":
				var pts := PackedVector2Array([
					Vector2(21, 2) * u, Vector2(9, 20) * u, Vector2(17, 20) * u,
					Vector2(14, 34) * u, Vector2(27, 14) * u, Vector2(19, 14) * u])
				draw_colored_polygon(pts, Color("#FFD54F"))
				draw_polyline(pts + PackedVector2Array([pts[0]]), edge, 2.5 * u)
			"luck":
				var c := Vector2(18, 18) * u
				var pts := PackedVector2Array()
				for i in 8:
					var rr := (16.0 if i % 2 == 0 else 5.5) * u
					var a := -PI / 2.0 + i * PI / 4.0
					pts.append(c + Vector2(cos(a), sin(a)) * rr)
				draw_colored_polygon(pts, Color("#CE93D8"))
				draw_polyline(pts + PackedVector2Array([pts[0]]), edge, 2.5 * u)
			_:
				# серце: два кола і трикутник
				var col := Color("#EF5350")
				draw_circle(Vector2(12, 13) * u, 8.0 * u, col)
				draw_circle(Vector2(24, 13) * u, 8.0 * u, col)
				draw_colored_polygon(PackedVector2Array([Vector2(4.5, 16) * u, Vector2(31.5, 16) * u, Vector2(18, 32) * u]), col)
				draw_circle(Vector2(10, 10) * u, 2.5 * u, Color(1, 1, 1, 0.7))


## Ряд із 1–4 крапок (заповнені = значення) — сила характеристики без цифр.
class StatDots:
	extends Control

	var count := 1
	var total := 4
	var fill := Color("#FFF8E1")
	var empty := Color(1, 1, 1, 0.25)

	func _init(n: int, px: float = 14.0, max_n: int = 4) -> void:
		count = clampi(n, 0, max_n)
		total = max_n
		custom_minimum_size = Vector2(px * float(total) + px * 0.5 * float(total - 1), px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var d: float = size.x / (float(total) + 0.5 * float(total - 1))
		var r := d * 0.5
		for i in total:
			var c := Vector2(r + i * d * 1.5, size.y * 0.5)
			draw_circle(c, r * 0.9, fill if i < count else empty)
			draw_arc(c, r * 0.9, 0.0, TAU, 20, Color("#3E2723"), 1.5)


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
