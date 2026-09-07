## Перешкода. Без фізики: габарит (AABB) перевіряє Spawner3D. Рухається разом зі світом (+Z).
## action: "jump" (перестрибнути), "duck" (присісти), "any" (можна пробігти — бризки), "side" (обійти),
## "boost" (трамплін), "rail" (рейка-бонус), "wind" (зносить убік).
## Читабельність (GDD v1.3 §8): чорне обведення (вивернута оболонка) і смугаста «небезпечна» плитка під тими, що збивають.
class_name Obstacle3D
extends Node3D

## Дії без плитки: не збивають або є бонусом.
const NO_PLATE_ACTIONS := ["any", "boost", "rail", "wind"]
const OUTLINE_SCALE := 1.04

static var _outline_mat: Material
static var _plate_mat: ShaderMaterial

var kind := ""
var action := "any"
var tumble := true
var lane := 0
var box := Vector3(0.7, 0.7, 0.7)
var auto_assist := false
var moves := false
var move_speed := 0.0
var hit := false
var passed := false

var _mesh: MeshInstance3D
var _dir := 1.0
var _box_y := 0.0


func setup(k: String, def: Dictionary, l: int, assist: bool, with_mesh: bool = true) -> void:
	kind = k
	action = String(def.get("action", "any"))
	tumble = bool(def.get("tumble", true))
	lane = l
	auto_assist = assist
	moves = bool(def.get("moves", false))
	move_speed = float(def.get("move_speed", 0.0))
	anim = String(def.get("anim", ""))
	var b: Array = def.get("box", [0.7, 0.7, 0.7])
	box = Vector3(float(b[0]), float(b[1]), float(b[2]))
	position.x = float(lane) * Hero3D.LANE_W
	var y := float(def.get("y", 0.0))
	# у bounding box гілки враховуємо висоту підвісу
	_box_y = y
	if with_mesh:
		_mesh = VoxelBuilder.instance(String(def.get("voxel", kind)))
		_mesh.position.y = y
		_base_scale = Vector3.ONE * float(def.get("scale", 1.0))
		_mesh.scale = _base_scale
		add_child(_mesh)
		# обведення: той самий меш, трохи роздутий, чорний, лицьові грані відсічені; дитина меша — повторює анімації
		var outline := MeshInstance3D.new()
		outline.mesh = _mesh.mesh
		outline.scale = Vector3.ONE * OUTLINE_SCALE
		var om := outline_material()
		if _base_scale != Vector3.ONE and om is ShaderMaterial:
			# збільшена перешкода роздула б обведення разом із собою — свій матеріал із меншим grow
			var dup := (om as ShaderMaterial).duplicate() as ShaderMaterial
			var g = dup.get_shader_parameter("grow")   # null — не перевизначено, беремо дефолт шейдера
			var grow := float(g) if g != null else 0.03
			dup.set_shader_parameter("grow", grow / maxf(0.01, _base_scale.x))
			om = dup
		outline.material_override = om
		outline.name = "Outline"
		_mesh.add_child(outline)
		if tumble and not NO_PLATE_ACTIONS.has(action):
			_plate = Mats.box(Vector3(0.9, 0.04, 0.9), Color.WHITE)
			_plate.material_override = plate_material()
			_plate.position.y = 0.02
			_plate.name = "Danger"
			add_child(_plate)
	else:
		# невидима перешкода — меш-заглушка, щоб анімації не падали
		_mesh = MeshInstance3D.new()
		add_child(_mesh)


var _plate: MeshInstance3D


## Матеріал обведення (один на всі перешкоди): шейдер-оболонка, якщо є; інакше чорний unshaded cull_front.
static func outline_material() -> Material:
	if _outline_mat == null:
		var path := "res://addons/mgp_core/voxel/voxel_outline.gdshader"
		if ResourceLoader.exists(path):
			var sm := ShaderMaterial.new()
			sm.shader = load(path)
			_outline_mat = sm
		else:
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.08, 0.08, 0.1)
			m.cull_mode = BaseMaterial3D.CULL_FRONT
			_outline_mat = m
	return _outline_mat


## Червоно-білі смуги для плитки небезпеки (один матеріал на всі).
static func plate_material() -> ShaderMaterial:
	if _plate_mat == null:
		_plate_mat = ShaderMaterial.new()
		_plate_mat.shader = load("res://addons/mgp_core/voxel/stripes.gdshader")
		_plate_mat.set_shader_parameter("color_a", Palette.OBSTACLE_STRIPE)
		_plate_mat.set_shader_parameter("color_b", Palette.OBSTACLE_STRIPE_ALT)
		_plate_mat.set_shader_parameter("stripe_width", 0.15)
	return _plate_mat


func aabb() -> AABB:
	return AABB(
		Vector3(position.x - box.x * 0.5, _box_y, position.z - box.z * 0.5),
		box
	)


## Межа руху для перебігаючих (їжачок) — уся ширина дороги, виставляє Spawner3D.
var range_x := 1.6
## Вільна доріжка групи (для «убік» авто-допомоги/підказки). 99 — невідомо.
var free_lane := 99


## Куди відступати від цієї перешкоди: до вільної доріжки, якщо відома, інакше до центру.
func side_dir(hero_lane: int) -> int:
	if free_lane != 99 and free_lane != hero_lane:
		return signi(free_lane - hero_lane)
	return -1 if lane >= 0 else 1


## Анімація з даних: sway (гойдається), spin (крутиться), bob (пливе вгору-вниз), breathe (дихає),
## bounce (стрибає, як м'яч), flap (махає), pulse (пульсує, як медуза), drip (крапає), wobble (хитається).
var anim := ""
var _t := randf() * TAU
var _drip_t := 0.0
var _base_scale := Vector3.ONE


func tick(delta: float) -> void:
	_t += delta
	if moves:
		position.x += _dir * move_speed * delta
		if absf(position.x) > range_x:
			_dir = -signf(position.x)
			position.x = clampf(position.x, -range_x, range_x)
			_mesh.rotation.y = 0.0 if _dir > 0 else PI
		# лапки «біжать»
		_mesh.position.y = _box_y + absf(sin(_t * 14.0)) * 0.05
	match anim:
		"sway":
			_mesh.rotation.z = sin(_t * 1.8) * 0.08
		"spin":
			_mesh.rotation.y += delta * 1.5
		"bob":
			_mesh.position.y = _box_y + sin(_t * 2.2) * 0.12
		"breathe":
			var s := 1.0 + sin(_t * 2.0) * 0.04
			_mesh.scale = _base_scale * Vector3(s, 1.0 / s, s)
		"bounce":
			_mesh.position.y = _box_y + absf(sin(_t * 4.0)) * 0.5
			var k := 1.0 - absf(cos(_t * 4.0)) * 0.15
			_mesh.scale = _base_scale * Vector3(1.0 + (1.0 - k), k, 1.0 + (1.0 - k))
		"flap":
			_mesh.rotation.x = sin(_t * 9.0) * 0.25
			_mesh.position.y = _box_y + sin(_t * 3.0) * 0.1
		"pulse":
			var p := 1.0 + sin(_t * 3.5) * 0.12
			_mesh.scale = _base_scale * Vector3(p, 2.0 - p, p)
			_mesh.position.y = _box_y + sin(_t * 1.5) * 0.08
		"wobble":
			_mesh.rotation.x = sin(_t * 2.5) * 0.06
			_mesh.rotation.z = cos(_t * 2.1) * 0.06
		"drip":
			_mesh.position.y = _box_y + sin(_t * 1.5) * 0.06
			_drip_t += delta
			if _drip_t > 0.7 and is_inside_tree():
				_drip_t = 0.0
				FX.splash(get_parent(), position + Vector3(0, 0.1, 0), Palette.SPLASH_WATER)
		_:
			pass


## Реакція на зіткнення без перекиду (калюжа/кущ): маленький «пшик».
func splash() -> void:
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", _base_scale * Vector3(1.3, 0.6, 1.3), 0.1)
	tw.tween_property(_mesh, "scale", _base_scale, 0.25).set_trans(Tween.TRANS_ELASTIC)
