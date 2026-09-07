## Дорога: пул рядів по 1 клітинці (3 доріжки + узбіччя + декор). Ряди їдуть на героя (+Z) і переставляються вперед.
## Зміна світу — перефарбування рядів з «перебудовою кубиками» (стаггер по z).
## Занурення (GDD v1.3 §7): стіни світу з даних — walls_near (кожен ряд, впритул до дороги), walls_far (далі, більші),
## canopy (крона над дорогою кожен 3-й ряд), sea (море на всю ширину, дорога невидима).
class_name Track
extends Node3D

const ROWS := 44
const BEHIND := 5.0          # позаду камери — ряд переставляється вперед
const LANES_W := 3.2         # ширина для 3 доріжок (базовий меш; масштабується під N)
const SIDE_W := 8.0
## Море на всю видиму ширину.
const SEA_W := 60.0
const CANOPY_Y := 3.2
const CANOPY_SCALE := 2.5

var world: Dictionary = {}
var lanes := 3
var _rows: Array[Node3D] = []
var _water: MeshInstance3D
var _water_mat: ShaderMaterial
var _scroll := 0.0
var _far: Node3D
var _hills: Array[MeshInstance3D] = []
var _clouds: Array[Node3D] = []
## Декоративне море збоку дороги (Пляж): -1 — ліворуч, 1 — праворуч, 0 — нема (world "sea_side").
var _sea_side := 0
## Море на всю ширину (world "sea": true) — дорога під героєм невидима, герой на дошці.
var _sea := false


func _ready() -> void:
	for i in range(ROWS):
		var row := Node3D.new()
		row.name = "Row%d" % i
		var center := Mats.box(Vector3(LANES_W, 0.4, 1.0), Color.GRAY)
		center.name = "Center"
		center.position.y = -0.2
		row.add_child(center)
		for side in [-1.0, 1.0]:
			var s := Mats.box(Vector3(SIDE_W, 0.4, 1.0), Color.DARK_GRAY)
			s.name = "SideL" if side < 0 else "SideR"
			s.position = Vector3(side * (LANES_W * 0.5 + SIDE_W * 0.5), -0.2, 0.0)
			row.add_child(s)
		var decor := Node3D.new()
		decor.name = "Decor"
		row.add_child(decor)
		row.position.z = BEHIND - float(i)
		row.set_meta("i", i)   # індекс ряду — для крони кожен 3-й ряд
		add_child(row)
		_rows.append(row)
	# далекий план: пагорби по боках і хмарки, що пливуть
	_far = Node3D.new()
	_far.name = "Far"
	add_child(_far)
	for i in range(14):
		var side := -1.0 if i % 2 == 0 else 1.0
		var hill := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var rad := randf_range(3.0, 6.0)
		sm.radius = rad
		sm.height = rad * randf_range(0.7, 1.1)
		sm.radial_segments = 12
		sm.rings = 6
		hill.mesh = sm
		hill.position = Vector3(side * randf_range(9.0, 16.0), -rad * 0.55, BEHIND - float(i) * 3.4 - 6.0)
		hill.name = "Hill"
		_far.add_child(hill)
		_hills.append(hill)
	for i in range(8):
		var cloud := Node3D.new()
		for j in range(3):
			var puff := Mats.box(Vector3(randf_range(0.8, 1.6), 0.5, 0.7), Color(1, 1, 1, 1))
			puff.position = Vector3(float(j) * 0.7 - 0.7, randf_range(0.0, 0.25), 0.0)
			cloud.add_child(puff)
		cloud.position = Vector3(randf_range(-12.0, 12.0), randf_range(5.0, 8.0), BEHIND - float(i) * 5.5 - 4.0)
		_far.add_child(cloud)
		_clouds.append(cloud)
	# вода для Хвилі — одна площина з вершинним шейдером
	_water = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(LANES_W + 0.4, ROWS + 4.0)
	pm.subdivide_depth = 60
	pm.subdivide_width = 6
	_water.mesh = pm
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://src/run3d/water.gdshader")
	_water.material_override = _water_mat
	_water.position = Vector3(0.0, 0.02, BEHIND - ROWS * 0.5)
	_water.visible = false
	add_child(_water)


var season: Dictionary = {}


func rebuild(w: Dictionary, animate: bool = true, s: Dictionary = {}, n_lanes: int = -1) -> void:
	world = w.duplicate()
	season = s
	# море на всю ширину (Серфінг): дорога невидима, герой на дошці; старий режим Хвиля — теж вода під дорогою
	_sea = bool(w.get("sea", false))
	var is_water := _sea or String(w.get("mode", "run")) == "slide"
	# море збоку (Пляж на піску) — узбіччя з того боку стає смужкою піску, тому знаємо це до розкладки рядів
	_sea_side = 0 if is_water else int(w.get("sea_side", 0))
	# ширина відома одразу — декор кладемо один раз під неї (і перекладаємо узбіччя під море/без моря)
	if n_lanes > 0:
		lanes = clampi(n_lanes, 3, 7)
	set_lanes(lanes, false)
	# сезон: підфарбовує землю й міняє квіти (сніг/осінь), нічого не додає до мешів
	if not s.is_empty():
		var tint := Palette.of(s.get("ground_tint"), Palette.GROUND_TINT_NONE)
		for key in ["ground", "ground_dark", "side"]:
			world[key] = (Palette.of(world.get(key), Palette.WORLD_GROUND) * tint).to_html(false)
		var dc: Array = s.get("decor_colors", [])
		if not dc.is_empty():
			world["decor_colors"] = dc
	_water.visible = is_water or _sea_side != 0
	if _water.visible:
		var wc := Palette.of(w.get("water"), Palette.WORLD_WATER)
		_water_mat.set_shader_parameter("color", wc)
		var light := wc if _sea or not is_water else Palette.of(w.get("ground_dark"), Palette.WORLD_WATER_DARK)
		_water_mat.set_shader_parameter("color_light", light.lightened(0.35))
	_layout_water()
	# пагорби у колір далекого плану світу; на морі їх не видно
	var far_mat := Mats.solid(Palette.of(world.get("far", world.get("side")), Palette.WORLD_SIDE).lightened(0.15))
	for h in _hills:
		h.material_override = far_mat
		h.visible = not _sea
	for i in range(_rows.size()):
		var row := _rows[i]
		_paint(row, i, is_water)
		_decorate(row)
		if animate:
			row.scale.y = 0.01
			var tw := create_tween()
			tw.tween_interval(0.02 * float(i))
			tw.tween_property(row, "scale:y", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioMgr.sfx("rebuild")


func _paint(row: Node3D, i: int, is_water: bool) -> void:
	var center := row.get_node("Center") as MeshInstance3D
	center.visible = not is_water
	var g := Palette.of(world.get("ground"), Palette.WORLD_GROUND)
	var gd := Palette.of(world.get("ground_dark"), Palette.WORLD_GROUND_DARK)
	center.material_override = Mats.solid(g if i % 2 == 0 else gd)
	var side := Mats.solid(Palette.of(world.get("side"), Palette.WORLD_SIDE))
	var l := row.get_node("SideL") as MeshInstance3D
	var r := row.get_node("SideR") as MeshInstance3D
	l.material_override = side
	r.material_override = side
	# на морі узбіч нема — довкола лише вода
	l.visible = not _sea
	r.visible = not _sea


## Узбіччя: стіни світу (walls_near впритул, walls_far далі й більші), ближній пояс — дрібне (квіти, гриби),
## дальній — велике (дерева, пальми), живність — зайчики; крона над дорогою кожен 3-й ряд.
## З боку моря (Пляж на піску) узбіччя — вода, декор туди не кладемо. На морі (sea) — лише буї/скелі у воді й гребені хвиль.
func _decorate(row: Node3D) -> void:
	var decor := row.get_node("Decor")
	for c in decor.get_children():
		c.queue_free()
	var kinds: Array = world.get("decor", [])
	var big: Array = world.get("decor_big", [])
	var critters: Array = world.get("critters", [])
	var colors: Array = world.get("decor_colors", [])
	var walls_near: Array = world.get("walls_near", [])
	var walls_far: Array = world.get("walls_far", [])
	var far_scale: Array = world.get("walls_far_scale", [1.4, 2.0])
	var edge := road_width() * 0.5
	for side in [-1.0, 1.0]:
		if _sea_side != 0 and signf(float(side)) == signf(float(_sea_side)):
			continue
		# стіна далека — кожен ряд, більша (буї/скелі у воді на морі)
		if not walls_far.is_empty():
			var wf := _place(decor, String(walls_far[randi() % walls_far.size()]), {}, side * (edge + randf_range(3.0, 5.0)))
			wf.scale = Vector3.ONE * randf_range(float(far_scale[0]), float(far_scale[1]))
			if _sea:
				wf.position.y = -0.05
		if _sea:
			# гребені хвиль із піною — плавають довкола траси
			if randf() < 0.3:
				var crest := _place(decor, "wave_crest", {}, side * (edge + randf_range(0.8, 6.0)))
				crest.position.y = 0.0
			continue
		# стіна близька — кожен ряд, впритул до дороги
		if not walls_near.is_empty():
			_place(decor, String(walls_near[randi() % walls_near.size()]), {}, side * (edge + randf_range(0.6, 1.4)))
		# дрібне — часто
		if not kinds.is_empty() and randf() < 0.9:
			var kind := String(kinds[randi() % kinds.size()])
			var override := {}
			if kind == "flower" and not colors.is_empty():
				override = {"p": String(colors[randi() % colors.size()])}
			_place(decor, kind, override, side * (edge + randf_range(0.5, 2.6)))
		# велике — рідше, далі
		if not big.is_empty() and randf() < 0.35:
			_place(decor, String(big[randi() % big.size()]), {}, side * (edge + randf_range(2.8, 5.5)))
		# живність — зрідка
		if not critters.is_empty() and randf() < 0.12:
			var cr := Critter3D.new()
			cr.position = Vector3(side * (edge + randf_range(1.0, 3.0)), 0.0, randf_range(-0.4, 0.4))
			decor.add_child(cr)
			cr.setup(String(critters[randi() % critters.size()]))
	# крона над дорогою — кожен 3-й ряд
	var canopy = world.get("canopy", false)
	var canopy_voxel := ""
	if typeof(canopy) == TYPE_STRING:
		canopy_voxel = String(canopy)
	elif typeof(canopy) == TYPE_BOOL and bool(canopy):
		canopy_voxel = "canopy_leaves"
	if canopy_voxel != "" and int(row.get_meta("i", 0)) % 3 == 0:
		var c := Critter3D.new()
		c.position = Vector3(randf_range(-1.0, 1.0), CANOPY_Y, randf_range(-0.3, 0.3))
		c.rotation.y = randf() * TAU
		c.scale = Vector3.ONE * CANOPY_SCALE
		decor.add_child(c)
		c.setup(canopy_voxel)


func _place(parent: Node3D, kind: String, override: Dictionary, x: float) -> Critter3D:
	var cr := Critter3D.new()
	cr.position = Vector3(x, 0.0, randf_range(-0.4, 0.4))
	cr.rotation.y = randf() * TAU
	parent.add_child(cr)
	cr.setup(kind, override)
	return cr


## Пташка перелітає дорогу час від часу.
func _spawn_bird() -> void:
	var birds: Array = world.get("birds", [])
	if birds.is_empty():
		return
	var b := Critter3D.new()
	_far.add_child(b)
	b.setup(String(birds[randi() % birds.size()]))
	var from_left := b._dir > 0
	b.position = Vector3(-13.0 if from_left else 13.0, randf_range(2.5, 4.5), randf_range(-14.0, -4.0))


var _bird_t := 5.0


func _process(delta: float) -> void:
	_bird_t -= delta
	if _bird_t < 0.0:
		_bird_t = randf_range(6.0, 14.0)
		_spawn_bird()


## Поточна ширина дороги в метрах.
func road_width() -> float:
	return float(lanes) * Hero3D.LANE_W + 0.2


## Звузити/розширити дорогу: центр масштабується по x, узбіччя відʼїжджають; кубики «перебудовуються».
func set_lanes(n: int, animate: bool = true) -> void:
	lanes = clampi(n, 3, 7)
	var w := road_width()
	var sx := w / LANES_W
	var side_x := w * 0.5 + SIDE_W * 0.5
	# з боку моря узбіччя — вузька смужка піску (1 м), далі вода
	var beach_x := w * 0.5 + 0.5
	var beach_sx := 1.0 / SIDE_W
	var i := 0
	for row in _rows:
		var center := row.get_node("Center") as Node3D
		var l := row.get_node("SideL") as Node3D
		var r := row.get_node("SideR") as Node3D
		var lx := -beach_x if _sea_side < 0 else -side_x
		var rx := beach_x if _sea_side > 0 else side_x
		l.scale.x = beach_sx if _sea_side < 0 else 1.0
		r.scale.x = beach_sx if _sea_side > 0 else 1.0
		if animate:
			_decorate(row)   # декор перекладається під нову ширину (при rebuild його кладе сам rebuild)
			var tw := create_tween()
			tw.tween_interval(0.012 * float(i))
			tw.tween_property(center, "scale:x", sx, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(l, "position:x", lx, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(r, "position:x", rx, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			center.scale.x = sx
			l.position.x = lx
			r.position.x = rx
		i += 1
	_layout_water()
	if animate:
		AudioMgr.sfx("rebuild")


## Вода: під дорогою (Хвиля) або збоку від неї (Пляж, sea_side) — ширина SIDE_W, за смужкою піску.
func _layout_water() -> void:
	if _water == null:
		return
	var w := road_width()
	if _sea:
		# море на всю видиму ширину, трохи нижче дороги (дошка сидить у воді)
		_water.scale.x = SEA_W / (LANES_W + 0.4)
		_water.position.x = 0.0
		_water.position.y = -0.05
	elif _sea_side != 0:
		_water.scale.x = SIDE_W / (LANES_W + 0.4)
		_water.position.x = float(_sea_side) * (w * 0.5 + SIDE_W * 0.5 + 1.0)
		_water.position.y = 0.02
	else:
		_water.scale.x = w / LANES_W
		_water.position.x = 0.0
		_water.position.y = 0.02


## Зсунути дорогу на dist клітинок (може бути відʼємним — відкат у Стрибках).
func advance(dist: float) -> void:
	for row in _rows:
		row.position.z += dist
		if row.position.z > BEHIND:
			row.position.z -= float(ROWS)
			_decorate(row)
		elif row.position.z < BEHIND - float(ROWS):
			row.position.z += float(ROWS)
	if _water.visible:
		_scroll += dist
		_water_mat.set_shader_parameter("scroll", _scroll)
	# далекий план рухається повільніше — паралакс
	for h in _hills:
		h.position.z += dist * 0.35
		if h.position.z > BEHIND + 8.0:
			h.position.z -= 48.0
	for c in _clouds:
		c.position.z += dist * 0.15
		c.position.x += 0.002
		if c.position.z > BEHIND + 6.0:
			c.position.z -= 46.0
			c.position.x = randf_range(-12.0, 12.0)
