## Мапа: стежинка з 17 зупинками через 5 островів-світів. Пройдені — зірки, поточна — «дихає» з сяйвом, далі — замок.
## Усі відкриті вузли можна грати знову. Море хвилюється, хмаринки пливуть, на островах — малюнки світу.
class_name MapScreen
extends CanvasLayer

signal level_chosen(num: int)
signal closed

const NODE_R := 48.0
const REDRAW_DT := 0.05     # ~20 к/с — достатньо для хвиль

var _root: Control
var _canvas: MapCanvas
var _nodes: Array[Button] = []
var _hero_marker: Control
var _back: Button
var _title: Label
var _lm: LevelManager
var _worlds: Dictionary = {}
var _hero_color := Color("#FFB84D")
var _acc := 0.0


## Малює море, острови з малюнками, дорогу-стежинку й сяйво під поточним вузлом; кнопки-вузли лежать поверх.
class MapCanvas:
	extends Control
	var points: Array = []
	var islands: Array = []      # [{world, color, accent, from, to, name}]
	var unlocked := 1
	var current := 1
	var t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Плавна крива Катмулла-Рома через вузли, seg відрізків між сусідами. Чиста функція.
	static func smooth_path(pts: Array, seg: int = 8) -> PackedVector2Array:
		var out := PackedVector2Array()
		var n := pts.size()
		if n < 2:
			for p in pts:
				out.append(p)
			return out
		for i in range(n - 1):
			var p0: Vector2 = pts[maxi(i - 1, 0)]
			var p1: Vector2 = pts[i]
			var p2: Vector2 = pts[i + 1]
			var p3: Vector2 = pts[mini(i + 2, n - 1)]
			for k in range(seg):
				var u := float(k) / float(seg)
				var u2 := u * u
				var u3 := u2 * u
				out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3))
		out.append(pts[n - 1])
		return out

	func _draw() -> void:
		_sea()
		for isl in islands:
			_island(isl)
		_road()
		_glow()
		_clouds()

	# --- море з хвилями ---
	func _sea() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#6EC1F5"))
		var rows := int(size.y / 46.0) + 1
		for r in range(rows):
			var y := 30.0 + r * 46.0 + sin(t * 0.7 + r) * 3.0
			var pts := PackedVector2Array()
			var x := -20.0
			while x <= size.x + 20.0:
				pts.append(Vector2(x, y + sin(x * 0.035 + t * 1.6 + r * 0.8) * 5.0))
				x += 16.0
			draw_polyline(pts, Color(1, 1, 1, 0.22 + 0.08 * (r % 2)), 4.0, true)

	# --- острови ---
	func _island(isl: Dictionary) -> void:
		var pts := []
		for i in range(int(isl["from"]) - 1, int(isl["to"])):
			if i < points.size():
				pts.append(points[i])
		if pts.is_empty():
			return
		var c := Vector2.ZERO
		for p in pts: c += p
		c /= float(pts.size())
		var w := 0.0
		for p in pts: w = maxf(w, absf(p.x - c.x))
		var col: Color = isl["color"]
		var accent: Color = isl["accent"]
		# пляжна смужка → світлий берег → трава
		_blob(c + Vector2(0, 14), Vector2(w + 150.0, 172.0), Color("#F5E6B8"))
		_blob(c + Vector2(0, 6), Vector2(w + 132.0, 152.0), col.lightened(0.28))
		_blob(c + Vector2(0, 10), Vector2(w + 110.0, 128.0), col)
		_doodles(String(isl["world"]), c, w, col, accent)
		var f: Font = UIKit.font()
		if f == null:
			f = ThemeDB.fallback_font
		var label := String(isl["name"])
		draw_string(f, c + Vector2(-119, -141), label, HORIZONTAL_ALIGNMENT_CENTER, 240, 28, Color(0, 0, 0, 0.25))
		draw_string(f, c + Vector2(-120, -143), label, HORIZONTAL_ALIGNMENT_CENTER, 240, 28, Color("#3E2723"))

	func _blob(c: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in range(32):
			var a := TAU * float(i) / 32.0
			var wob := 1.0 + sin(a * 3.0 + c.x * 0.01) * 0.07 + cos(a * 5.0 + c.y * 0.02) * 0.03
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y) * wob)
		draw_colored_polygon(pts, col)

	## Малюнки світу — на кутах острова, щоб не лягати під вузли.
	func _doodles(world: String, c: Vector2, w: float, col: Color, accent: Color) -> void:
		var spots := [c + Vector2(-w - 60.0, -70.0), c + Vector2(w + 60.0, -80.0), c + Vector2(-w - 40.0, 80.0), c + Vector2(w + 50.0, 75.0), c + Vector2(0.0, 105.0)]
		match world:
			"forest":
				for i in 4:
					_tree_tri(spots[i], 1.0 + 0.15 * (i % 2), col.darkened(0.25))
			"beach":
				_palm(spots[0])
				_umbrella(spots[1], accent)
				for i in 2:
					var p: Vector2 = spots[2 + i]
					var pts := PackedVector2Array()
					for k in 9:
						pts.append(p + Vector2(-32.0 + k * 8.0, sin(k * 1.2 + t * 2.0) * 4.0))
					draw_polyline(pts, Color("#29B6F6"), 5.0, true)
			"city":
				for i in 3:
					_house(spots[i], [Color("#FFCC80"), Color("#B3E5FC"), Color("#F8BBD0")][i], accent)
			"clouds":
				_puff(spots[0], 1.0, Color(1, 1, 1, 0.95))
				_puff(spots[3], 0.8, Color(1, 1, 1, 0.95))
				# місяць і зорі
				draw_circle(spots[1], 22.0, Color("#FFF3C4"))
				draw_circle(spots[1] + Vector2(10, -6), 19.0, col)
				for i in 5:
					var p: Vector2 = spots[2] + Vector2(-40.0 + i * 20.0, sin(i * 2.1) * 18.0)
					_star(p, 5.0 + (i % 2) * 2.0, Color("#FFF176"))
			_:
				# лужок: 3 квітки й дерево
				for i in 3:
					_flower(spots[i], [accent, Color("#FFF176"), Color("#BA68C8")][i])
				_tree_round(spots[3], col)

	func _tree_tri(p: Vector2, k: float, dark: Color) -> void:
		draw_rect(Rect2(p + Vector2(-5, 18) * k, Vector2(10, 16) * k), Color("#795548"))
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -34) * k, p + Vector2(-26, 20) * k, p + Vector2(26, 20) * k]), dark)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -30) * k, p + Vector2(-16, 4) * k, p + Vector2(16, 4) * k]), dark.lightened(0.25))

	func _tree_round(p: Vector2, col: Color) -> void:
		draw_rect(Rect2(p + Vector2(-6, 6), Vector2(12, 28)), Color("#795548"))
		draw_circle(p + Vector2(0, -12), 26.0, col.darkened(0.3))
		draw_circle(p + Vector2(-14, -2), 18.0, col.darkened(0.15))
		draw_circle(p + Vector2(14, -4), 18.0, col.darkened(0.15))

	func _flower(p: Vector2, col: Color) -> void:
		draw_rect(Rect2(p + Vector2(-2, 0), Vector2(4, 26)), Color("#388E3C"))
		for i in 6:
			var a := i * PI / 3.0 + t * 0.3
			draw_circle(p + Vector2(cos(a), sin(a)) * 9.0, 6.0, col)
		draw_circle(p, 5.0, Color("#FFF176"))

	func _palm(p: Vector2) -> void:
		var pts := PackedVector2Array()
		for k in 8:
			pts.append(p + Vector2(sin(k * 0.3) * 8.0, 30.0 - k * 8.0))
		draw_polyline(pts, Color("#8D6E63"), 7.0, true)
		var top: Vector2 = pts[-1]
		for i in 5:
			var a := -PI * 0.9 + i * PI * 0.2 + sin(t * 1.5) * 0.05
			draw_line(top, top + Vector2(cos(a), sin(a)) * 30.0, Color("#43A047"), 7.0, true)

	func _umbrella(p: Vector2, col: Color) -> void:
		draw_line(p, p + Vector2(0, 34), Color("#616161"), 3.0)
		var pts := PackedVector2Array([p])
		for k in 13:
			var a := PI + PI * float(k) / 12.0
			pts.append(p + Vector2(cos(a) * 30.0, sin(a) * 18.0))
		draw_colored_polygon(pts, col)
		for k in range(1, 12, 4):
			var a := PI + PI * float(k) / 12.0
			draw_line(p, p + Vector2(cos(a) * 30.0, sin(a) * 18.0), Color(1, 1, 1, 0.8), 3.0)

	func _house(p: Vector2, wall: Color, roof: Color) -> void:
		draw_rect(Rect2(p + Vector2(-22, -10), Vector2(44, 40)), wall)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-28, -10), p + Vector2(0, -36), p + Vector2(28, -10)]), roof)
		for x in [-14.0, 6.0]:
			draw_rect(Rect2(p + Vector2(x, 0), Vector2(9, 9)), Color("#FFF59D"))
		draw_rect(Rect2(p + Vector2(-5, 14), Vector2(10, 16)), Color("#795548"))

	func _puff(p: Vector2, k: float, col: Color) -> void:
		draw_circle(p, 18.0 * k, col)
		draw_circle(p + Vector2(-20, 6) * k, 14.0 * k, col)
		draw_circle(p + Vector2(20, 6) * k, 14.0 * k, col)
		draw_circle(p + Vector2(0, 10) * k, 14.0 * k, col)

	func _star(p: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var rr := r if i % 2 == 0 else r * 0.45
			var a := -PI / 2.0 + i * PI / 5.0
			pts.append(p + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, col)

	# --- дорога ---
	func _road() -> void:
		if points.size() < 2:
			return
		var seg := 8
		var path := smooth_path(points, seg)
		draw_polyline(path, Color("#8D6E63"), 30.0, true)
		draw_polyline(path, Color("#FFF3D6"), 22.0, true)
		# далі — пунктир по центру
		var start := clampi((unlocked - 1) * seg, 0, path.size() - 1)
		var k := start
		while k + 1 < path.size():
			if ((k - start) / 2) % 2 == 0:
				draw_line(path[k], path[k + 1], Color("#BCAAA4"), 6.0, true)
			k += 1

	# --- сяйво під поточним вузлом ---
	func _glow() -> void:
		if current < 1 or current > points.size():
			return
		var p: Vector2 = points[current - 1]
		var k := 0.5 + 0.5 * sin(t * 3.0)
		var r := 48.0   # = NODE_R
		draw_circle(p, r + 26.0 + k * 8.0, Color(1.0, 0.95, 0.6, 0.25))
		draw_circle(p, r + 12.0 + k * 4.0, Color(1.0, 0.95, 0.6, 0.35))

	# --- хмаринки пливуть над мапою ---
	func _clouds() -> void:
		for i in 4:
			var span := size.x + 260.0
			var x := fmod(i * 337.0 + t * (14.0 + 4.0 * i), span) - 130.0
			var y := 40.0 + i * 150.0 + sin(t * 0.4 + i) * 6.0
			_puff(Vector2(x, y), 0.9 + 0.2 * (i % 2), Color(1, 1, 1, 0.85))


## Позиції вузлів — хвилястою стежкою зліва направо. Чиста функція.
static func node_positions(n: int, size: Vector2) -> Array:
	var out := []
	for i in range(n):
		var t := float(i) / float(maxi(1, n - 1))
		var x := lerpf(120.0, size.x - 120.0, t)
		var y := size.y * 0.55 + sin(t * PI * 3.0) * size.y * 0.22
		out.append(Vector2(x, y))
	return out


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_canvas = MapCanvas.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_canvas)
	_title = UIKit.title("Куди біжимо?", 56)
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.offset_top = 24
	_title.offset_bottom = 24
	_root.add_child(_title)
	_back = UIKit.button("‹ Назад", Color("#8D6E63"), Vector2(200, 80), 30)
	_back.position = Vector2(140, 32)
	_back.pressed.connect(func(): AudioMgr.sfx("ui_tap"); close())
	_root.add_child(_back)
	_hero_marker = HeroMarker.new()
	_root.add_child(_hero_marker)


## Хвилі й хмаринки — перемальовка ~20 к/с, лише коли мапа видима.
func _process(delta: float) -> void:
	if not visible:
		return
	_acc += delta
	if _acc >= REDRAW_DT:
		_canvas.t += _acc
		_acc = 0.0
		_canvas.queue_redraw()


class HeroMarker:
	extends Control
	var color := Color("#FFB84D")
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
		draw_circle(c + Vector2(0, 48), 14.0, Color(0, 0, 0, 0.2))
		draw_rect(Rect2(Vector2(22, 8), Vector2(36, 42)), color)
		draw_rect(Rect2(Vector2(26, 50), Vector2(10, 14)), color.darkened(0.2))
		draw_rect(Rect2(Vector2(44, 50), Vector2(10, 14)), color.darkened(0.2))
		for x in [31.0, 49.0]:
			draw_circle(Vector2(x, 26), 5.0, Color.WHITE)
			draw_circle(Vector2(x + 1, 27), 2.6, Color("#222831"))
		draw_rect(Rect2(Vector2(35, 36), Vector2(10, 3)), Color("#5D4037"))


func open(lm: LevelManager, worlds: Dictionary, hero_color: Color) -> void:
	_lm = lm
	_worlds = worlds
	_hero_color = hero_color
	visible = true
	call_deferred("_build")


func close() -> void:
	visible = false
	closed.emit()


func _build() -> void:
	for b in _nodes:
		b.queue_free()
	_nodes.clear()
	var n := _lm.count()
	var pts := node_positions(n, _root.size)
	var unlocked := _lm.unlocked()
	var current := _lm.current()
	_canvas.points = pts
	_canvas.unlocked = unlocked
	_canvas.current = current
	_canvas.islands = []
	for isl in _lm.islands():
		var w: Dictionary = _worlds.get(isl["world"], {})
		_canvas.islands.append({
			"world": String(isl["world"]), "from": isl["from"], "to": isl["to"],
			"color": Color(String(w.get("side", "#7CC46B"))), "accent": Color(String(w.get("accent", "#F06292"))),
			"name": String(w.get("name_uk", isl["world"]))})
	_canvas.queue_redraw()
	for i in range(n):
		var num := i + 1
		var lvl := _lm.get_level(num)
		var w: Dictionary = _worlds.get(String(lvl.get("world", "")), {})
		var accent := Color(String(w.get("accent", "#F06292")))
		var stars := _lm.stars_of(num)
		var is_open := num <= unlocked
		var b := UIKit.button(str(num) if is_open else "", accent if is_open else Color("#9E9E9E"), Vector2(NODE_R * 2, NODE_R * 2), 36)
		for st in ["normal", "hover", "pressed"]:
			var sb := b.get_theme_stylebox(st)
			if sb is StyleBoxFlat:
				(sb as StyleBoxFlat).set_corner_radius_all(int(NODE_R))
		b.position = pts[i] - Vector2(NODE_R, NODE_R)
		b.tooltip_text = String(lvl.get("name_uk", "")) + " — " + String(lvl.get("feature", ""))
		if is_open:
			b.pressed.connect(_on_node.bind(num))
		else:
			b.pressed.connect(func(): UIKit.shake(b); AudioMgr.sfx("locked"))
			var lock := LockIcon.new()
			lock.position = Vector2(NODE_R - 14, NODE_R - 16)
			b.add_child(lock)
		if stars > 0:
			# рядок зірок над вузлом
			var row := HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.position = Vector2(NODE_R - 13.0 * stars - 1.0 * (stars - 1), -32)
			row.add_theme_constant_override("separation", 2)
			for s in range(stars):
				row.add_child(Icons.StarIcon.new(26.0))
			b.add_child(row)
		_root.add_child(b)
		_nodes.append(b)
		UIKit.pop_in(b, 0.03 * i)
		if num == unlocked and num > 1:
			# пульс — після появи, інакше перебиває pop_in
			get_tree().create_timer(0.03 * i + 0.6).timeout.connect(func():
				if is_instance_valid(b):
					UIKit.pulse(b, 0.08, 1.0))
	# герой стоїть на поточному вузлі
	(_hero_marker as HeroMarker).color = _hero_color
	_hero_marker.position = pts[current - 1] - Vector2(40, 100)
	_hero_marker.move_to_front()
	if unlocked >= n and _lm.stars_of(n) > 0:
		# усе пройдено — грати знову будь-який рівень (без «скинути прогрес»: це для дітей)
		_title.text = "Усе пройдено! Грай знову"
	else:
		_title.text = "Рівень %d — %s" % [current, String(_lm.get_level(current).get("name_uk", ""))]


class LockIcon:
	extends Control
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(28, 32)
	func _draw() -> void:
		draw_rect(Rect2(Vector2(2, 14), Vector2(24, 18)), Color("#FFF8E1"))
		draw_arc(Vector2(14, 14), 8.0, PI, TAU, 12, Color("#FFF8E1"), 4.0, true)
		draw_circle(Vector2(14, 23), 3.5, Color("#616161"))


func _on_node(num: int) -> void:
	AudioMgr.sfx("ui_play")
	_lm.set_current(num)
	# герой перебігає на обраний вузол, тоді стартуємо
	var pts := node_positions(_lm.count(), _root.size)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_hero_marker, "position", pts[num - 1] - Vector2(40, 100), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		visible = false
		level_chosen.emit(num))
