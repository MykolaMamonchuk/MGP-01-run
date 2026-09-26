## Перешкода. Без фізики: габарит (AABB) перевіряє Spawner3D. Рухається разом зі світом (+Z).
## action: "jump" (перестрибнути), "duck" (присісти), "any" (можна пробігти — бризки), "side" (обійти),
## "boost" (трамплін), "rail" (рейка-бонус), "wind" (зносить убік).
## Читабельність (GDD v1.3 §8): чорне обведення (вивернута оболонка) і смугаста «небезпечна» плитка під тими, що збивають.
## Мова перешкод (GDD v1.4 §3): силует із data/obstacle_shapes.json (поле "shape" у світі) додає маркер —
## червоно-білі смуги зверху («перестрибни»), жовто-чорні смуги на верхній балці («пригнись»),
## великий білий X на передній грані («сюди не можна»). Перешкода може вимкнути маркер полем "marker": "none".
class_name Obstacle3D
extends Node3D

## Дії без плитки: не збивають або є бонусом.
const OUTLINE_SCALE := 1.04
const SHAPES_PATH := "res://data/obstacle_shapes.json"

static var _outline_mat: Material
static var _plate_mat: ShaderMaterial
static var _stripe_mats: Dictionary = {}
static var _shapes: Dictionary = {}
static var _shapes_loaded := false

var kind := ""
var shape := ""
var marker := "none"
var action := "any"
var tumble := true
var lane := 0
var box := Vector3(0.7, 0.7, 0.7)
var auto_assist := false
var moves := false
var move_speed := 0.0
var hit := false
var passed := false
## Як предмет поводиться, коли його розбивають: "chunks" — розлітається на друзки,
## "soft" — просто пшикає й зникає. Жива істота, хмара чи павутина на кубики не б'ються,
## і брунатні друзки з корови виглядали б дико. Задається полем "breaks" у data/worlds/*.json.
var breaks := "chunks"

var _mesh: MeshInstance3D
var _dir := 1.0
var _box_y := 0.0

## СКЕЛЕТНА ТВАРИНА (поле "rig" у світі): модель зі скелетом і процедурною анімацією
## (src/run3d/goose_rig.gd), а не меш, що хитається цілим. Значення поля — роль:
##   "stand" — стоїть на доріжці; герой наближається — шипить, пробігає поруч — кусає;
##   "walk"  — переходить дорогу, дивиться туди, куди йде;
##   "fly"   — летить на висоті голови, під нею треба пригнутись.
## Реакція лише ВИГЛЯДУ: габарит і дія перешкоди ті самі, що й без рига, — дитина має
## бачити, що гуска сердиться, але правила гри від цього не змінюються.
var _rig: GooseRig
var _rig_mode := ""
var _rig_state := ""
var _rig_t := 0.0
var _rig_scale := 1.0

## «З'явитись збоку» (поле "arrive" у світі: {"from_m": 9, "done_m": 5}): гуска чекає за краєм
## дороги й приходить у свою доріжку, поки герой наближається, — дитина бачить «телеграф», а не
## раптову появу. Позиція рахується від ВІДСТАНІ до героя, а не від часу: за будь-якої швидкості
## бігу гуска вже у доріжці, коли до неї done_m. Зіткнення перевіряються лише в |z| < 1,2 м,
## тобто вже на місці.
var _arrive_from := 0.0
var _arrive_done := 0.0
var _arrive_x0 := 0.0
var _arrive_x1 := 0.0
var _arrive_ready := false

## Модель скелетної тварини вибирається НА КОЖЕН ЕКЗЕМПЛЯР, а не на мапу, як решта пропсів
## (PropLibrary.pick). Правило «одна мапа — один тип» стоїть заради рядів: паркани різної
## висоти поруч стрибали б. Гуска ж стоїть сама, і замовник хоче бачити всіх трьох (26.09).
## Лічильник, а не жереб: той самий порядок появи дає ті самі моделі.
static var _rig_counter := 0
var _rig_variant := 0


## Поставити скелетну модель виду `prop_name` у роль `mode`. false — моделі або скелета нема.
## _mesh стає порожнім вузлом-носієм: усі анімації й підйоми нижче крутять саме його, а
## модель зі скелетом сидить усередині й ворушить кістками сама.
func _setup_rig(prop_name: String, mode: String) -> bool:
	var n := PropLibrary.variants(prop_name)
	if n <= 0:
		return false
	var v := _rig_counter % n
	var e := PropLibrary._entry(prop_name, v)
	var scene := PropLibrary.scene(String(e.get("path", "")))
	if scene == null:
		return false
	var model := scene.instantiate() as Node3D
	var rig := GooseRig.new()
	if model == null or not rig.build(model):
		if model != null:
			model.free()
		return false
	_rig_counter += 1
	# Ті самі правки матеріалу, що й у решти пропсів: без карт нормалей, задні грані геть.
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		PropLibrary._drop_normal_maps((mi as MeshInstance3D).mesh)
	_mesh = MeshInstance3D.new()
	_mesh.name = "Rig"
	_mesh.add_child(model)
	_rig = rig
	_rig_mode = mode
	_rig_variant = v
	# Меш-анімації з даних (breathe/wobble…) качали б модель цілою поверх кісток.
	anim = ""
	return true


## Роль → стан рига на цей кадр. Герой стоїть у z = 0, перешкоди їдуть до нього з -Z.
const HISS_FROM_M := 7.0     ## з якої відстані гуска починає шипіти
const BITE_WITHIN_M := 1.6   ## ближче за це — кидається кусати

## Звідки гуска приходить: з того боку, де її доріжка (середня — по черзі), на 1,4 м за
## краєм доріжки, тобто вже за краєм дороги.
func _init_arrive() -> void:
	_arrive_ready = true
	_arrive_x1 = position.x
	var side := signf(_arrive_x1)
	if side == 0.0:
		side = 1.0 if _rig_counter % 2 == 0 else -1.0
	_arrive_x0 = _arrive_x1 + side * 1.4
	position.x = _arrive_x0


## 0 — ще чекає за краєм, 1 — уже в доріжці.
func arrive_k() -> float:
	if _arrive_from <= 0.0:
		return 1.0
	return smoothstep(-_arrive_from, -_arrive_done, position.z)


func _rig_state_now() -> String:
	if _arrive_from > 0.0 and _rig_mode != "fly":
		var k := arrive_k()
		if k <= 0.0:
			return "alert" if -position.z < _arrive_from + 3.0 else "peck"
		if k < 1.0:
			return "flee"   # дріботить лапами й махає крилами — біжить навперейми
	match _rig_mode:
		"stand":
			if absf(position.z) < BITE_WITHIN_M:
				return "bite"
			if position.z < 0.0 and -position.z < HISS_FROM_M:
				return "hiss"
			return "stand"
		"walk":
			return "walk"
		"fly":
			return "fly"
	return "stand"


func _tick_rig(delta: float) -> void:
	if _arrive_from > 0.0:
		if not _arrive_ready:
			_init_arrive()
		var k := arrive_k()
		position.x = lerpf(_arrive_x0, _arrive_x1, k)
		# Поки біжить — дзьобом туди, куди біжить; на місці — до героя.
		var run_yaw := PI * 0.5 * signf(_arrive_x1 - _arrive_x0)
		_mesh.rotation.y = lerpf(run_yaw, 0.0, smoothstep(0.85, 1.0, k)) if k > 0.0 else run_yaw * 0.5
	var st := _rig_state_now()
	if st != _rig_state:
		# Час від початку стану: кидок «кусає» має починатись із замаху, а не з середини.
		_rig_state = st
		_rig_t = 0.0
		_rig.state = st
	_rig_t += delta
	var lift := _rig.pose(_rig_t)
	if _rig_mode == "fly":
		# Висоту польоту задає "y" світу (під нею пригинаються); від рига лише погойдування.
		_mesh.position.y = _box_y + (lift - 0.35 * _rig.height) * _rig_scale
	if moves:
		# Модель дивиться в +Z; іти вздовж +X — поворот на +90°.
		_mesh.rotation.y = PI * 0.5 * _dir


func setup(k: String, def: Dictionary, l: int, assist: bool, with_mesh: bool = true) -> void:
	kind = k
	shape = String(def.get("shape", ""))
	# маркер: свій у перешкоди, інакше — типовий для силуету
	marker = String(def.get("marker", shape_def(shape).get("marker", "none")))
	action = String(def.get("action", "any"))
	tumble = bool(def.get("tumble", true))
	lane = l
	auto_assist = assist
	moves = bool(def.get("moves", false))
	breaks = String(def.get("breaks", "chunks"))
	move_speed = float(def.get("move_speed", 0.0))
	anim = String(def.get("anim", ""))
	var b: Array = def.get("box", [0.7, 0.7, 0.7])
	box = Vector3(float(b[0]), float(b[1]), float(b[2]))
	position.x = float(lane) * Hero3D.LANE_W
	var y := float(def.get("y", 0.0))
	# у bounding box гілки враховуємо висоту підвісу
	_box_y = y
	if with_mesh:
		# спершу бібліотека пропсів: є справжня модель для цього виду — беремо її меш,
		# нема — лишається воксель (див. src/run3d/prop_library.gd). Саме МЕШ, а не готовий
		# вузол сцени: нижче обведення бере `_mesh.mesh`, а анімації крутять сам MeshInstance3D.
		# `prop` — ЦІЛЬОВА модель, `voxel` — те, чим малюємо, поки її нема. Поля різні
		# навмисно: світ уже перетемовано (пеньок → ящик, вулик → бочка), а моделей ще нема,
		# і якби `voxel` одразу вказував на нову назву, VoxelBuilder малював би рожевий куб
		# «файлу не знайдено». Щойно модель з'явиться в data/props.json під іменем із `prop` —
		# вона підміняє воксель сама, без правок у даних світу.
		var voxel_name := String(def.get("voxel", kind))
		var prop_name := String(def.get("prop", voxel_name))
		# тип вибираємо ОДИН раз на екземпляр: меш і доведення мусять бути від тієї самої
		# моделі (див. PropLibrary.pick)
		var variant := PropLibrary.pick(prop_name)
		# Скелетна тварина: свій екземпляр моделі зі скелетом (див. _setup_rig). Не вийшло
		# (моделі нема, скелета нема) — звичайний шлях нижче, тобто меш або воксель.
		var rig_mode := String(def.get("rig", ""))
		if rig_mode != "" and _setup_rig(prop_name, rig_mode):
			variant = _rig_variant
			var arr: Dictionary = def.get("arrive", {})
			if not arr.is_empty():
				_arrive_from = float(arr.get("from_m", 9.0))
				_arrive_done = float(arr.get("done_m", 5.0))
		var prop_mesh: Mesh = null
		if _rig == null:
			prop_mesh = PropLibrary.mesh(prop_name, variant)
			if prop_mesh != null:
				_mesh = MeshInstance3D.new()
				_mesh.mesh = prop_mesh
			else:
				_mesh = VoxelBuilder.instance(voxel_name)
		_mesh.position.y = y
		# доведення моделі з data/props.json поверх масштабу зі світу (для вокселя — 1.0 / 0°)
		var tw := PropLibrary.tweak(prop_name, variant)
		_base_scale = Vector3.ONE * float(def.get("scale", 1.0)) * float(tw["scale"])
		_rig_scale = _base_scale.x
		_mesh.scale = _base_scale
		_mesh.rotation.y += deg_to_rad(float(tw["yaw_deg"]))
		add_child(_mesh)
		# Обведення — той самий меш, трохи роздутий і чорний. Воно робилось для ВОКСЕЛІВ:
		# там грані великі й рівні, і чорний контур читається як мальована лінія. На
		# низькополігональній моделі роздутий меш вилазить назовні окремими чорними
		# трикутниками — саме це й було видно на гусці й на ринковому візку. Тому для
		# справжніх моделей обведення не малюємо: у них силует тримає сама форма.
		if prop_mesh == null and _rig == null:
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
		_add_marker()
		# Плиту небезпеки (червоно-біле тло під перешкодою) прибрано на прохання замовника:
		# вона з'явилась як підказка «сюди не можна», але поруч зі справжніми моделями
		# читається як технічна розмітка, а не як частина світу. Сама перешкода тепер
		# помітна власним виглядом.
	else:
		# невидима перешкода — меш-заглушка, щоб анімації не падали
		_mesh = MeshInstance3D.new()
		add_child(_mesh)




## Каталог силуетів (data/obstacle_shapes.json) — читається один раз на запуск.
static func shapes() -> Dictionary:
	if not _shapes_loaded:
		_shapes_loaded = true
		var f := FileAccess.open(SHAPES_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("shapes", null)) == TYPE_DICTIONARY:
				_shapes = (parsed as Dictionary)["shapes"] as Dictionary
	return _shapes


## Опис силуету (порожній словник, якщо силует не заданий/невідомий).
static func shape_def(id: String) -> Dictionary:
	var v = shapes().get(id, {})
	return v if typeof(v) == TYPE_DICTIONARY else {}


## Смугастий матеріал маркера: пара кольорів на смуги (кеш — один на пару).
static func stripe_material(a: Color, b: Color, width: float = 0.12) -> ShaderMaterial:
	var key := "%s|%s|%.3f" % [a.to_html(false), b.to_html(false), width]
	if not _stripe_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://addons/mgp_core/voxel/stripes.gdshader")
		m.set_shader_parameter("color_a", a)
		m.set_shader_parameter("color_b", b)
		m.set_shader_parameter("stripe_width", width)
		_stripe_mats[key] = m
	return _stripe_mats[key] as ShaderMaterial


## Маркер силуету: смуги зверху / на балці або білий X на передній грані.
func _add_marker() -> void:
	match marker:
		"stripes_red":
			# «перестрибни»: червоно-біла стрічка по верху перешкоди
			var top := Mats.box(Vector3(box.x * 0.92, 0.06, box.z * 0.8), Palette.WHITE)
			top.material_override = stripe_material(Palette.OBSTACLE_STRIPE, Palette.OBSTACLE_STRIPE_ALT)
			top.position.y = _box_y + box.y + 0.03
			top.name = "MarkJump"
			add_child(top)
		"stripes_yellow":
			# «пригнись»: жовто-чорна стрічка на верхній балці
			var beam := Mats.box(Vector3(box.x * 0.98, 0.07, box.z * 0.9), Palette.WHITE)
			beam.material_override = stripe_material(Palette.AMBER, Palette.INK)
			beam.position.y = _box_y + box.y + 0.04
			beam.name = "MarkDuck"
			add_child(beam)
		"x_white":
			# «сюди не можна»: дві білі перекладини хрестом на передній грані
			var length := sqrt(box.x * box.x + box.y * box.y) * 0.92
			for s in [1.0, -1.0]:
				var bar := Mats.box(Vector3(0.07, length, 0.04), Palette.WHITE)
				bar.position = Vector3(0.0, _box_y + box.y * 0.5, -box.z * 0.5 - 0.03)
				bar.rotation.z = s * atan2(box.x, box.y)
				bar.name = "MarkX%s" % ("A" if s > 0.0 else "B")
				add_child(bar)
		_:
			pass


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
## Наскільки бочка, що котиться, швидша за саму трасу, м/с. Менше — майже не помітно,
## більше — дитина не встигає відреагувати (перевірено на профілі young: 2,8 м/с біг).
const ROLL_SPEED := 1.6

var _base_scale := Vector3.ONE
var _roll := 0.0                   ## накопичений кут котіння бочки


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
	if _rig != null:
		_tick_rig(delta)
	match anim:
		"sway":
			_mesh.rotation.z = sin(_t * 1.8) * 0.08
		"spin":
			_mesh.rotation.y += delta * 1.5
		"bob":
			_mesh.position.y = _box_y + sin(_t * 2.2) * 0.12
		"roll":
			# Бочка КОТИТЬСЯ на героя: крутиться навколо поперечної осі й наздоганяє його
			# швидше за саму трасу. Перешкода, яка наближається сама, читається дитині
			# інакше, ніж нерухома: її видно здалеку й на неї встигаєш зреагувати, але
			# вона змушує рухатись, а не просто оминати.
			#
			# Швидкість обертання пов'язана з розміром: бочка радіусом 0,3 м за метр шляху
			# робить метр/(2πr) обороту. Інакше вона або ковзає, або крутиться дзиґою.
			# Бочка мусить ЛЕЖАТИ на боці: її вісь — поперек дороги. Раніше я крутив її
			# навколо X, не поклавши, і вона перекидалась через голову, ніби кубик.
			# Кладемо один раз (поворот навколо Z на чверть оберту), далі крутимо навколо
			# тієї самої осі, якою вона тепер лежить.
			var r: float = maxf(box.x * 0.5, 0.05)
			position.z += ROLL_SPEED * delta
			_roll += (ROLL_SPEED * delta) / r
			_mesh.rotation = Vector3(_roll, 0.0, PI * 0.5)
			# Початок координат моделі — унизу, тож поворот на бік «топить» половину бочки
			# під землю. Піднімаємо на радіус: тепер вона лежить НА землі, а не в ній.
			_mesh.position.y = _box_y + r
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


## Суперсила «Роги напролом» (GDD v1.6 §3c): перешкода РОЗЛІТАЄТЬСЯ.
## Меш роздувається й зникає, з нього летять кубики кольору самої перешкоди — і вузол іде геть.
## Плитка небезпеки й маркер зникають разом із ним (вони діти цього ж вузла).
func shatter() -> void:
	hit = true
	passed = true
	# Колір предмета шукає Debris.color_of(): вершинні кольори (вокселі), інакше середній
	# колір текстури (справжні .glb), інакше albedo. Раніше тут була лише перша гілка, і в
	# моделі з текстурою друзки виходили кремовою заглушкою замість кольору предмета.
	var c := Palette.W_CRATE
	if is_instance_valid(_mesh) and _mesh.mesh != null:
		c = Debris.color_of(_mesh.mesh, Palette.W_CRATE)
	elif _rig != null and is_instance_valid(_mesh):
		# У скелетної тварини _mesh — порожній носій; колір — з самої моделі (біла гуска
		# інакше пшикала б кольором ящика).
		for mi in _mesh.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).mesh != null:
				c = Debris.color_of((mi as MeshInstance3D).mesh, Palette.W_CRATE)
				break
	var centre := position + Vector3(0.0, _box_y + box.y * 0.5, 0.0)
	if is_inside_tree():
		FX.burst(get_parent(), centre, c)
		# ДРУЗКИ — лише для того, що справді б'ється на шматки. Ставимо їх у того самого
		# батька, що й перешкоду: Spawner3D.advance() зсуває всіх своїх дітей разом із
		# дорогою, тож шматки їдуть із світом, а не висять у повітрі, поки дорога тікає
		# з-під них. KILL_Z прибере те, що поїхало за спину.
		if breaks == "chunks":
			Debris.burst(get_parent(), centre, c, box)
	# Сам предмет зникає ШВИДКО: моменти удару тепер тримають друзки, а довга пружинка поверх
	# них читалась би як другий, окремий предмет.
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.3, 0.55, 1.3), 0.05)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.finished.connect(queue_free)


## Реакція на зіткнення без перекиду (калюжа/кущ): маленький «пшик».
func splash() -> void:
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", _base_scale * Vector3(1.3, 0.6, 1.3), 0.1)
	tw.tween_property(_mesh, "scale", _base_scale, 0.25).set_trans(Tween.TRANS_ELASTIC)
