## Дорога: пул рядів по 1 клітинці (3 доріжки + узбіччя + декор). Ряди їдуть на героя (+Z) і переставляються вперед.
## Зміна світу — перефарбування рядів з «перебудовою кубиками» (стаггер по z).
class_name Track
extends Node3D

const ROWS := 44
const BEHIND := 5.0          # позаду камери — ряд переставляється вперед
const LANES_W := 3.2
const SIDE_W := 6.0

var world: Dictionary = {}
var _rows: Array[Node3D] = []
var _water: MeshInstance3D
var _water_mat: ShaderMaterial
var _scroll := 0.0
var _far: Node3D
var _hills: Array[MeshInstance3D] = []
var _clouds: Array[Node3D] = []


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


func rebuild(w: Dictionary, animate: bool = true, s: Dictionary = {}) -> void:
	world = w.duplicate()
	season = s
	# сезон: підфарбовує землю й міняє квіти (сніг/осінь), нічого не додає до мешів
	if not s.is_empty():
		var tint := Color(String(s.get("ground_tint", "#FFFFFF")))
		for key in ["ground", "ground_dark", "side"]:
			world[key] = (Color(String(world.get(key, "#7CC46B"))) * tint).to_html(false)
		var dc: Array = s.get("decor_colors", [])
		if not dc.is_empty():
			world["decor_colors"] = dc
	var is_water := String(w.get("mode", "run")) == "slide"
	_water.visible = is_water
	if is_water:
		_water_mat.set_shader_parameter("color", Color(String(w.get("water", "#4FC3F7"))))
		_water_mat.set_shader_parameter("color_light", Color(String(w.get("ground_dark", "#29B6F6"))).lightened(0.35))
	# пагорби у колір далекого плану світу
	var far_mat := Mats.solid(Color(String(world.get("far", world.get("side", "#6DB35E")))).lightened(0.15))
	for h in _hills:
		h.material_override = far_mat
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
	var g := Color(String(world.get("ground", "#7CC46B")))
	var gd := Color(String(world.get("ground_dark", "#5FA553")))
	center.material_override = Mats.solid(g if i % 2 == 0 else gd)
	var side := Mats.solid(Color(String(world.get("side", "#6DB35E"))))
	(row.get_node("SideL") as MeshInstance3D).material_override = side
	(row.get_node("SideR") as MeshInstance3D).material_override = side


func _decorate(row: Node3D) -> void:
	var decor := row.get_node("Decor")
	for c in decor.get_children():
		c.queue_free()
	var kinds: Array = world.get("decor", [])
	if kinds.is_empty():
		return
	for side in [-1.0, 1.0]:
		if randf() > 0.7:
			continue
		var kind := String(kinds[randi() % kinds.size()])
		var colors: Array = world.get("decor_colors", [])
		var override := {}
		if kind == "flower" and not colors.is_empty():
			override = {"p": String(colors[randi() % colors.size()])}
		var mi := VoxelBuilder.instance(kind, override)
		mi.position = Vector3(side * randf_range(2.0, 4.2), 0.0, randf_range(-0.4, 0.4))
		mi.rotation.y = randf() * TAU
		decor.add_child(mi)


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
