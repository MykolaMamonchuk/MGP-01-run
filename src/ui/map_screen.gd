## Мапа: стежинка з 17 зупинками через 5 островів-світів у воксельному стилі гри.
## Вузли: відкритий (колір світу, номер), купується (колір світу + плашка «★ ціна», пульсує), замкнений (сірий, замок).
## Тап по купованому: вистачає зірочок — купівля, салют зірочок, герой перебігає й рівень стартує; ні — трясіння й підсвітка ціни.
## Острови — блокові східчасті плити (3 яруси по 8 px), море — блокові хвилі, стежка — камінці, реквізит — воксельні картинки.
class_name MapScreen
extends CanvasLayer

signal level_chosen(num: int)
signal closed

const NODE_R := 48.0
const REDRAW_DT := 0.05     # ~20 к/с — достатньо для хвиль
## Напис острова: розмір і на скільки вище «центру» стоїть його верх; зсув при накладанні і скільки разів пробуємо.
const LABEL_W := 240.0
const LABEL_H := 34.0
const LABEL_LIFT := 165.0
const LABEL_STEP := 40.0
const LABEL_TRIES := 4

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
## Купівля триває (салют → стрибок героя → старт): другий тап ігноруємо.
var _busy := false


## Малює море, острови з реквізитом, стежку-камінці й сяйво під поточним вузлом; кнопки-вузли лежать поверх.
class MapCanvas:
	extends Control
	## Воксельні картинки для островів: світ → назви моделей (data/voxels); малюються на кутах острова.
	const PROPS := {
		"meadow": ["tree", "flower", "bunny", "fence", "flower"],
		"forest": ["tree", "mushroom", "tree", "bunny", "mushroom"],
		"beach": ["palm", "umbrella", "palm", "umbrella", "palm"],
		"city": ["lamp", "fence", "tree", "lamp", "fence"],
		"clouds": ["cloud", "planet", "cloud", "planet", "cloud"],
	}
	const PROP_PX := [64.0, 56.0, 60.0, 52.0, 72.0]
	const STONE := Vector2(22.0, 16.0)

	static var _elev: Dictionary = {}     # назва вокселя → [{x, y, color}] (кеш фронтальної проєкції)

	var points: Array = []
	var islands: Array = []      # [{world, color, accent, from, to, name}]
	var unlocked := 1
	var current := 1
	var t := 0.0
	var _sb_stone: StyleBoxFlat
	var _sb_edge: StyleBoxFlat
	var _sb_ahead: StyleBoxFlat

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sb_stone = _rounded(Color("#FFF3D6"), 6)
		_sb_edge = _rounded(Color("#8D6E63"), 8)
		_sb_ahead = _rounded(Color(0.75, 0.7, 0.68, 0.55), 6)

	static func _rounded(col: Color, r: int) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(r)
		return sb

	## Плавна крива Катмулла-Рома через вузли, seg відрізків між сусідами. Чиста функція (камінці стежки лягають по ній).
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

	## Фронтальна проєкція вокселя (кеш).
	static func elevation(voxel_name: String) -> Array:
		if not _elev.has(voxel_name):
			_elev[voxel_name] = Icons.VoxelIcon.front_elevation(Icons.VoxelIcon.def_for(voxel_name))
		return _elev[voxel_name]

	func _draw() -> void:
		_sea()
		var rects := []
		for isl in islands:
			var r := _island_rect(isl)
			rects.append(r)
			if r.size.x > 0.0:
				_island(isl, r)
		_road()
		_glow()
		_labels(rects)
		_clouds()

	# --- море: блокові хвилі рядами ---
	func _sea() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#6EC1F5"))
		var rows := int(size.y / 40.0) + 1
		for r in range(rows):
			var y := 20.0 + r * 40.0
			var shift := fmod(t * (14.0 + 4.0 * (r % 3)), 56.0)
			var x := -56.0 + shift + 28.0 * (r % 2)
			while x <= size.x:
				var w := 28.0 if r % 2 == 0 else 20.0
				draw_rect(Rect2(Vector2(x, y), Vector2(w, 6.0)), Color(1, 1, 1, 0.28))
				draw_rect(Rect2(Vector2(x, y + 6.0), Vector2(w, 3.0)), Color(0.25, 0.55, 0.8, 0.35))
				x += 56.0

	# --- острови: блокові плити ---
	## Плита острова навколо його вузлів (для сяйва, реквізиту й напису). Порожня — якщо вузлів нема.
	func _island_rect(isl: Dictionary) -> Rect2:
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		var any := false
		for i in range(int(isl["from"]) - 1, int(isl["to"])):
			if i < points.size():
				var p: Vector2 = points[i]
				lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
				hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
				any = true
		if not any:
			return Rect2()
		return Rect2(lo - Vector2(100.0, 70.0), hi - lo + Vector2(200.0, 150.0))

	func _island(isl: Dictionary, r: Rect2) -> void:
		var col: Color = isl["color"]
		# три яруси по 8 px: пісок → світла трава → трава; під кожним — темний «обрив» на 8 px
		var tiers := [[r, Color("#F5E6B8")], [r.grow(-8.0), col.lightened(0.28)], [r.grow(-16.0), col]]
		for tier in tiers:
			var rr: Rect2 = tier[0]
			var c: Color = tier[1]
			draw_rect(Rect2(rr.position + Vector2(0, 8.0), rr.size), c.darkened(0.3))
			draw_rect(rr, c)
		_props(String(isl["world"]), r)

	## Реквізит на кутах острова; місця, що лягають на вузол, пропускаємо.
	func _props(world: String, r: Rect2) -> void:
		var names: Array = PROPS.get(world, PROPS["meadow"])
		var spots := [
			r.position + Vector2(44.0, 78.0),
			Vector2(r.end.x - 44.0, r.position.y + 82.0),
			Vector2(r.position.x + 48.0, r.end.y - 12.0),
			Vector2(r.end.x - 48.0, r.end.y - 14.0),
			Vector2(r.get_center().x, r.end.y - 10.0),
		]
		for i in range(mini(names.size(), spots.size())):
			var px: float = PROP_PX[i]
			var foot: Vector2 = spots[i]
			var centre := foot - Vector2(0, px * 0.5)
			var clear := true
			for p in points:
				if (p as Vector2).distance_to(centre) < 48.0 + px * 0.5 + 4.0:
					clear = false
					break
			if clear:
				_prop(String(names[i]), foot, px)

	## Воксельна картинка (фронтальна проєкція) з опорою в точці foot (низ по центру), найбільший бік ≈ px.
	func _prop(voxel_name: String, foot: Vector2, px: float) -> void:
		var rects := elevation(voxel_name)
		if rects.is_empty():
			return
		var w := 0
		var h := 0
		for c in rects:
			w = maxi(w, int(c["x"]) + 1)
			h = maxi(h, int(c["y"]) + 1)
		var cell := maxf(2.0, floorf(px / float(maxi(w, h))))
		var origin := foot - Vector2(float(w) * cell * 0.5, float(h) * cell)
		# тінь-плямка під реквізитом
		draw_rect(Rect2(foot + Vector2(-float(w) * cell * 0.5, -3.0), Vector2(float(w) * cell, 6.0)), Color(0, 0, 0, 0.15))
		for c in rects:
			var pos := origin + Vector2(float(int(c["x"])), float(h - 1 - int(c["y"]))) * cell
			draw_rect(Rect2(pos, Vector2(cell, cell)), c["color"])
			draw_rect(Rect2(pos + Vector2(0, cell * 0.8), Vector2(cell, cell * 0.2)), (c["color"] as Color).darkened(0.18))

	## Написи островів — без накладань між собою й на вузли (MapScreen.place_labels).
	func _labels(rects: Array) -> void:
		var anchors := []
		for r in rects:
			var rr: Rect2 = r
			# напис стає над плитою: його низ на 12 px вище верху плити
			anchors.append(Vector2(rr.get_center().x, rr.position.y + MapScreen.LABEL_LIFT - MapScreen.LABEL_H - 12.0))
		var tops := MapScreen.place_labels(anchors, points, size)
		var f: Font = UIKit.font()
		if f == null:
			f = ThemeDB.fallback_font
		for i in range(mini(tops.size(), islands.size())):
			var top: Vector2 = tops[i]
			var label := String(islands[i]["name"])
			var base := top + Vector2(0, MapScreen.LABEL_H - 8.0)
			draw_string(f, base + Vector2(1, 2), label, HORIZONTAL_ALIGNMENT_CENTER, int(MapScreen.LABEL_W), 28, Color(0, 0, 0, 0.25))
			draw_string(f, base, label, HORIZONTAL_ALIGNMENT_CENTER, int(MapScreen.LABEL_W), 28, Color("#3E2723"))

	# --- стежка з камінців ---
	func _road() -> void:
		if points.size() < 2:
			return
		var seg := 8
		var path := smooth_path(points, seg)
		var ahead_from := clampi((unlocked - 1) * seg, 0, path.size() - 1)
		var k := 0
		var i := 0
		while k < path.size():
			var p: Vector2 = path[k]
			# камінці трохи в шаховому порядку впоперек стежки
			var nxt: Vector2 = path[mini(k + 1, path.size() - 1)]
			var dir := (nxt - p).normalized() if nxt != p else Vector2.RIGHT
			var side := Vector2(-dir.y, dir.x) * (4.0 if i % 2 == 0 else -4.0)
			var c := p + side
			if k >= ahead_from and k > 0:
				_sb_ahead.draw(get_canvas_item(), Rect2(c - STONE * 0.5, STONE))
			else:
				_sb_edge.draw(get_canvas_item(), Rect2(c - STONE * 0.5 - Vector2(3, 3), STONE + Vector2(6, 8)))
				_sb_stone.draw(get_canvas_item(), Rect2(c - STONE * 0.5, STONE))
			k += 3
			i += 1

	# --- сяйво під поточним вузлом ---
	func _glow() -> void:
		if current < 1 or current > points.size():
			return
		var p: Vector2 = points[current - 1]
		var k := 0.5 + 0.5 * sin(t * 3.0)
		var r := 48.0   # = NODE_R
		draw_circle(p, r + 26.0 + k * 8.0, Color(1.0, 0.95, 0.6, 0.25))
		draw_circle(p, r + 12.0 + k * 4.0, Color(1.0, 0.95, 0.6, 0.35))

	# --- хмаринки пливуть над мапою (блокові) ---
	func _clouds() -> void:
		for i in 4:
			var span := size.x + 260.0
			var x := fmod(i * 337.0 + t * (14.0 + 4.0 * i), span) - 130.0
			var y := 40.0 + i * 150.0 + sin(t * 0.4 + i) * 6.0
			_puff_block(Vector2(x, y), 0.9 + 0.2 * (i % 2), Color(1, 1, 1, 0.85))

	func _puff_block(p: Vector2, k: float, col: Color) -> void:
		draw_rect(Rect2(p + Vector2(-40, 4) * k, Vector2(80, 12) * k), col)
		draw_rect(Rect2(p + Vector2(-30, -8) * k, Vector2(60, 20) * k), col)
		draw_rect(Rect2(p + Vector2(-16, -22) * k, Vector2(32, 16) * k), col)
		draw_rect(Rect2(p + Vector2(-40, 14) * k, Vector2(80, 4) * k), col.darkened(0.12))


## Позиції вузлів — хвилястою стежкою зліва направо. Чиста функція.
static func node_positions(n: int, size: Vector2) -> Array:
	var out := []
	for i in range(n):
		var t := float(i) / float(maxi(1, n - 1))
		var x := lerpf(120.0, size.x - 120.0, t)
		var y := size.y * 0.55 + sin(t * PI * 3.0) * size.y * 0.22
		out.append(Vector2(x, y))
	return out


## Чи перетинає прямокутник коло (центр c, радіус r).
static func _rect_hits_circle(r: Rect2, c: Vector2, radius: float) -> bool:
	var q := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
	return q.distance_to(c) < radius


## Розкладає написи островів (LABEL_W × LABEL_H): верх напису = center − (120, LABEL_LIFT); якщо напис лягає на
## попередній напис або на коло вузла (r 48) — піднімаємо на LABEL_STEP, до LABEL_TRIES разів. По x — у межах екрана.
## Повертає верхні-ліві кути. Чиста функція.
static func place_labels(centers: Array, node_points: Array, size: Vector2) -> Array:
	var out := []
	var placed: Array[Rect2] = []
	for c in centers:
		var cc: Vector2 = c
		var x := clampf(cc.x - LABEL_W * 0.5, 0.0, maxf(0.0, size.x - LABEL_W))
		var top := Vector2(x, cc.y - LABEL_LIFT)
		for _try in range(LABEL_TRIES + 1):
			var r := Rect2(top, Vector2(LABEL_W, LABEL_H))
			var hit := false
			for pr in placed:
				if pr.intersects(r):
					hit = true
					break
			if not hit:
				for p in node_points:
					if _rect_hits_circle(r, p, NODE_R):
						hit = true
						break
			if not hit or _try == LABEL_TRIES:
				break
			top.y -= LABEL_STEP
		placed.append(Rect2(top, Vector2(LABEL_W, LABEL_H)))
		out.append(top)
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


## Плашка «★ ціна» під купованим вузлом.
class PriceBadge:
	extends Control
	var price := 0
	func _init(p: int) -> void:
		price = p
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(92, 32)
		pivot_offset = size * 0.5
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.24, 0.15, 0.14, 0.92))
		draw_rect(Rect2(Vector2(0, size.y - 4.0), Vector2(size.x, 4.0)), Color(0, 0, 0, 0.35))
		# зірочка
		var c := Vector2(17, 16)
		var pts := PackedVector2Array()
		for i in 10:
			var rr := 11.0 if i % 2 == 0 else 4.8
			var a := -PI / 2.0 + i * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, Color("#FFD54F"))
		var f: Font = UIKit.font()
		if f == null:
			f = ThemeDB.fallback_font
		draw_string(f, Vector2(32, 24), str(price), HORIZONTAL_ALIGNMENT_LEFT, 58, 22, Color.WHITE)


class LockIcon:
	extends Control
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(28, 32)
	func _draw() -> void:
		draw_rect(Rect2(Vector2(2, 14), Vector2(24, 18)), Color("#FFF8E1"))
		draw_arc(Vector2(14, 14), 8.0, PI, TAU, 12, Color("#FFF8E1"), 4.0, true)
		draw_circle(Vector2(14, 23), 3.5, Color("#616161"))


func open(lm: LevelManager, worlds: Dictionary, hero_color: Color) -> void:
	_lm = lm
	_worlds = worlds
	_hero_color = hero_color
	_busy = false
	visible = true
	call_deferred("_build")


func close() -> void:
	visible = false
	closed.emit()


## Будує вузли. pop_num > 0 — пружно з'являється лише цей вузол (після купівлі), решта — одразу.
func _build(pop_num: int = 0) -> void:
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
		var st := _lm.open_state_of(num)
		var col := accent if st != "locked" else Color("#9E9E9E")
		var b := UIKit.button(str(num) if st == "open" else "", col, Vector2(NODE_R * 2, NODE_R * 2), 36)
		for sname in ["normal", "hover", "pressed"]:
			var sb := b.get_theme_stylebox(sname)
			if sb is StyleBoxFlat:
				(sb as StyleBoxFlat).set_corner_radius_all(int(NODE_R))
		b.position = pts[i] - Vector2(NODE_R, NODE_R)
		b.tooltip_text = String(lvl.get("name_uk", "")) + " — " + String(lvl.get("feature", ""))
		match st:
			"open":
				b.pressed.connect(_on_node.bind(num))
			"buyable":
				var badge := PriceBadge.new(_lm.price_of(num))
				badge.position = Vector2(NODE_R - badge.size.x * 0.5, NODE_R * 2 - 24.0)
				b.add_child(badge)
				b.pressed.connect(_on_buy.bind(num, b, badge))
			_:
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
		var delay := 0.03 * i
		if pop_num == 0 or pop_num == num:
			if pop_num == num:
				delay = 0.0
			UIKit.pop_in(b, delay)
		if st == "buyable" or (num == unlocked and num > 1):
			# пульс — після появи, інакше перебиває pop_in
			get_tree().create_timer(delay + 0.6).timeout.connect(func():
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


## Тап по купованому вузлу: вистачає — купівля, салют, вузол відкривається, герой перебігає, старт; ні — трясіння й ціна.
func _on_buy(num: int, b: Button, badge: Control) -> void:
	if _busy:
		return
	if SaveService.stars() < _lm.price_of(num):
		UIKit.shake(b)
		AudioMgr.sfx("locked")
		AudioMgr.voice("need_more")
		_flash_badge(badge)
		return
	if not _lm.buy(num):
		UIKit.shake(b)
		return
	_busy = true
	AudioMgr.sfx("confetti")
	AudioMgr.voice("level_bought")
	var centre := b.position + Vector2(NODE_R, NODE_R)
	_build(num)          # вузол став відкритим — пружно з'являється
	_burst(centre)
	get_tree().create_timer(0.5).timeout.connect(func():
		_busy = false
		if visible:
			_on_node(num))


## Підсвітка ціни: плашка збільшується й червоніє, потім назад.
func _flash_badge(badge: Control) -> void:
	if not is_instance_valid(badge):
		return
	var tw := badge.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(badge, "scale", Vector2.ONE * 1.35, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(badge, "modulate", Color("#FF8A80"), 0.12)
	tw.tween_interval(0.25)
	tw.tween_property(badge, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(badge, "modulate", Color.WHITE, 0.2)


## Салют зірочок із точки: 10 зірок розлітаються й тануть.
func _burst(centre: Vector2) -> void:
	for i in 10:
		var s := Icons.StarIcon.new(24.0)
		s.position = centre - s.size * 0.5
		s.pivot_offset = s.size * 0.5
		_root.add_child(s)
		var a := TAU * float(i) / 10.0 + randf_range(-0.2, 0.2)
		var to := centre + Vector2(cos(a), sin(a)) * randf_range(70.0, 120.0) - s.size * 0.5
		var tw := s.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(s, "position", to, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "scale", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(s.queue_free)
