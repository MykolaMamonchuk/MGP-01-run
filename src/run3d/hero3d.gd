## Герой у 3D — чотирилапе звірятко (GDD v1.5 §5). Стоїть у початку координат, світ рухається на нього (+Z).
## Тіло збирається з вокселів-частин (data/heroes.json → parts): тулуб, голова, чотири лапки, хвіст, двоє вух.
## Голова ≈ 45 % зросту, кубічна морда з кремовим передом і темним носиком — у вокселі голови;
## зіниці з бліком, щічки й рот — окремі меші, тому герой кліпає, дивиться в бік повороту й усміхається.
## Уся анімація процедурна (Tween + sin): галоп (передня пара лапок в антифазі із задньою), боб тіла,
## контр-боб голови, вуха з інерцією, хвіст махає.
## Старі пухнастики v1.4 лишились у heroes.json із "legacy": true — збереження з ними не падають:
## Hero3D показує першого нового героя (див. resolve_def).
class_name Hero3D
extends Node3D

signal landed
signal tumble_finished

const LANE_W := 1.0
const GRAVITY := 22.0
const HOP_VELOCITY := 4.6
const FLY_HEIGHT := 1.9
const X_FREE_LIMIT := 1.3

## Геометрія звірятка (світові метри, герой стоїть на y = 0).
## Лапка 2×3×2 × 0,075 = 0,225 заввишки; тулуб 6×5×8 × 0,075 лежить на лапках;
## голова 7×6×6 × 0,075 = 0,45 (45 % від 0,98) сидить попереду-вгорі.
const LEG_H := 0.225              ## довжина лапки = висота стегна/плеча
const TORSO_Y := 0.225            ## низ тулуба
const TORSO_Z := 0.05             ## тулуб трохи зсунутий назад — попереду місце під голову
const TORSO_TOP := 0.60
const NECK_Y := 0.53              ## шарнір голови (шия)
const NECK_Z := -0.20
const HEAD_H := 0.45
const HEAD_HALF_D := 0.225
const HEAD_TOP := 0.98            ## маківка (капелюшок) — і майже повний зріст героя
const FACE_Z := -0.425            ## передня грань голови (морда, окуляри)
const HIP_X := 0.15
const HIP_Z_FRONT := -0.14
const HIP_Z_BACK := 0.26
const TAIL_Y := 0.44
const TAIL_Z := 0.34
const GALLOP_SWING := 0.6         ## розмах лапок на бігу, рад
## Комічне зіткнення (GDD v1.4 §2): очі ×1,4, зіниці ×0,6, зсув на пів доріжки,
## оберт ±0,5 рад із поверненням за 0,5 с, 3 зірочки над головою 1,2 с, невразливість 1,5 с.
const HIT_EYE_SCALE := 1.4
const HIT_PUPIL_SCALE := 0.6
const HIT_SIDE_LANES := 0.5
const HIT_SPIN := 0.5
const HIT_STARS := 3
const HIT_STARS_SEC := 1.2
const HIT_INVULN_SEC := 1.5

## Частини за замовчуванням (герой без parts у даних, друг Friend3D, старе збереження).
const DEFAULT_PARTS := {
	"body": "hero_body",
	"head": "hero_head",
	"leg": "hero_leg",
	"tail": "hero_tail_fox",
	"ear": "hero_ear_fox",
}
const PART_KEYS := ["body", "head", "leg", "tail", "ear"]

var lane := 0
var x_target := 0.0
var free_x := false
var wave_offset := 0.0
var jump_velocity := 7.5
var tumbling := false
var ducking := false
var flying := false
var running := false           # біг-боб увімкнено (Біг/Хвиля/Стрибки), вимкнено в меню
## Темп бігу-боба: 1.0 — Біг, 0.6 — покрокові режими (Стрибки/Невагомість), де світ лише дрейфує.
var run_speed_factor := 1.0
## Рівень землі під героєм (подіум у каруселі, платформа другого рівня) — тінь лягає на нього.
var ground_y := 0.0
## Життя (GDD v1.3): 3 серця; після удару — невразливість і миготіння.
var hearts := 3
var max_hearts := 3
var invulnerable_t := 0.0
## Щит (пікап): поглинає один удар — бульбашка навколо героя.
var shield_on := false
## Сидить після втрати всіх сердець («Ще раз!») — біг-боб і нахил тіла вимкнені.
var sitting := false
## Множник стрибка режиму (невагомість ×0.8), поверх jump_velocity профілю.
var jump_scale := 1.0
var hero_id := "lys"
var feature := "fox"
var color := Palette.HERO_DEFAULT
## Колір кінчика хвоста і плямок/смужок — із даних героя (accent / mark).
var accent := Palette.H_CREAM
var mark := Palette.H_DARK

var _vy := 0.0
var _y := 0.0
var _tilt := 0.0
var _t := 0.0
var _blink_t := 0.0
var _next_blink := 3.0
var _look_t := 0.0
var _yawn_t := 0.0
var _twitch_t := 0.0

var _body: Node3D
var _mesh: MeshInstance3D            # тулуб (лишив старе ім'я: на ньому «привид» у каруселі)
var _meshes: Array[MeshInstance3D] = []   # усі воксельні частини — для матеріалів
var _head: Node3D                    # шарнір голови (шия)
var _face: Node3D
var _eyes: Array[Node3D] = []
var _pupils: Array[MeshInstance3D] = []
var _mouth: MeshInstance3D
var _parts: Array[Node3D] = []      # рухомі частини: вуха + хвіст
var _ears: Array[Node3D] = []
var _ear_base: Array[Vector3] = []  # базовий поворот вуха (розхил / звисання)
var _tail: Node3D
var _tail_base_x := 0.0
var _legs: Array[Node3D] = []       # 0 — передня ліва, 1 — передня права, 2 — задня ліва, 3 — задня права
var _shadow: MeshInstance3D
var _vehicle: MeshInstance3D
var _sparkles: GPUParticles3D
var _tumble_tween: Tween
var _eye_scale_y := 1.0
var _duck_blend := 0.0          # 0 — стоїть, 1 — присів (плавний перехід 20/с)
var _mouth_y := 0.05            # базова висота рота у координатах голови (усмішка піднімає на +0.02)
var _blink_vis_t := 0.0         # таймер миготіння тіла під час невразливості
var _wave_t := 0.0              # поки махає лапкою — _process її не чіпає
var _shield: MeshInstance3D
var _shield_popping := false    # бульбашка лопається — set_shield(false) її не ховає раніше часу


# ---------- дані героїв ----------

static var _defs_cache: Dictionary = {}
static var _defs_loaded := false


## Усі герої з data/heroes.json (з кешем). Разом зі старими (legacy) — щоб збереження не падали.
static func defs() -> Dictionary:
	if _defs_loaded:
		return _defs_cache
	_defs_loaded = true
	var f := FileAccess.open("res://data/heroes.json", FileAccess.READ)
	if f == null:
		return _defs_cache
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_defs_cache = parsed
	return _defs_cache


## Чиста функція: чи це старий пухнастик v1.4 (у каруселі його нема).
static func is_legacy(def: Dictionary) -> bool:
	return bool(def.get("legacy", false))


## Чиста функція: назви вокселів частин героя з дефолтами (body/head/leg/tail/ear).
static func part_names(def: Dictionary) -> Dictionary:
	var out := DEFAULT_PARTS.duplicate()
	var p = def.get("parts", {})
	if typeof(p) == TYPE_DICTIONARY:
		for k in PART_KEYS:
			var v := String((p as Dictionary).get(k, ""))
			if v != "":
				out[k] = v
	return out


## Чиста функція: id першого нового (не legacy) героя за order — на нього падаємо зі старого збереження.
static func first_animal_id(all: Dictionary) -> String:
	var best := ""
	var best_order := 1 << 30
	for k in all.keys():
		var key := String(k)
		if key.begins_with("_") or key == "growth":
			continue
		var def = all[k]
		if typeof(def) != TYPE_DICTIONARY or is_legacy(def):
			continue
		var o := int((def as Dictionary).get("order", 99))
		if o < best_order:
			best_order = o
			best = key
	return best


## Чиста функція: опис, за яким малюємо героя id. Старий (legacy) герой → перший новий;
## незнайомий id (напр. "friend") → порожній опис, тобто частини за замовчуванням і переданий колір.
static func resolve_def(all: Dictionary, id: String) -> Dictionary:
	var def = all.get(id, {})
	if typeof(def) != TYPE_DICTIONARY:
		return {}
	if (def as Dictionary).is_empty():
		return {}
	if not is_legacy(def):
		return def
	var fid := first_animal_id(all)
	var fallback = all.get(fid, {})
	return fallback if typeof(fallback) == TYPE_DICTIONARY else {}


func _ready() -> void:
	# бульбашка щита — напівпрозора сфера, видима лише з пікапом
	_shield = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.75
	sph.height = 1.5
	sph.radial_segments = 24
	sph.rings = 12
	_shield.mesh = sph
	var shm := StandardMaterial3D.new()
	shm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shm.albedo_color = Color(0.4, 0.8, 1.0, 0.28)
	shm.emission_enabled = true
	shm.emission = Palette.HERO_SHIELD
	shm.emission_energy_multiplier = 0.6
	shm.roughness = 0.2
	_shield.material_override = shm
	_shield.position.y = 0.62
	_shield.visible = false
	add_child(_shield)

	# тінь звірятка — витягнутий уздовж тіла овал
	_shadow = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.32
	cm.bottom_radius = 0.32
	cm.height = 0.02
	_shadow.mesh = cm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0, 0, 0.1, 0.32)
	_shadow.material_override = sm
	_shadow.scale = Vector3(0.95, 1.0, 1.5)
	add_child(_shadow)

	_vehicle = VoxelBuilder.instance("shell")
	_vehicle.position.y = -0.05
	_vehicle.visible = false
	add_child(_vehicle)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	set_hero(hero_id, color, feature)


## Перебудувати героя: тулуб + голова (з обличчям і вухами) + чотири лапки + хвіст.
func set_hero(id: String, hero_color: Color, feat: String = "fox") -> void:
	hero_id = id
	feature = feat
	color = hero_color
	for c in _body.get_children():
		c.queue_free()
	_meshes.clear()
	_eyes.clear()
	_pupils.clear()
	_parts.clear()
	_ears.clear()
	_ear_base.clear()
	_legs.clear()
	_head = null
	_tail = null
	_sparkles = null

	var def := resolve_def(defs(), id)
	# старого пухнастика показуємо як першого нового героя — разом із його кольорами
	if not def.is_empty() and def.get("color") != null and is_legacy(defs().get(id, {})):
		color = Palette.of(def.get("color"), hero_color)
	accent = Palette.of(def.get("accent"), Palette.H_CREAM)
	mark = Palette.of(def.get("mark"), color.darkened(0.3))
	var parts := part_names(def)
	var pal := _voxel_palette()

	_mesh = _part_mesh(String(parts["body"]), pal)
	_mesh.name = "Torso"
	_mesh.position = Vector3(0.0, TORSO_Y, TORSO_Z)
	_body.add_child(_mesh)

	_build_head(String(parts["head"]), String(parts["ear"]), pal)
	_build_legs(String(parts["leg"]), pal)
	_build_tail(String(parts["tail"]), pal)
	if feature == "cloud":
		for m in _meshes:
			m.material_override = VoxelBuilder.material_alpha(0.72)
	elif feature == "sparkle":
		_sparkles = FX.sparkles(_body, 0.55, 14)

	_body.scale = Vector3.ONE
	_body.rotation = Vector3.ZERO
	_body.position = Vector3.ZERO
	_duck_blend = 0.0
	# аксесуари жили на старому тілі — одягаємо знову (set_accessory сам прибирає старий вузол)
	var snapshot := _slot_voxels.duplicate()
	var opts_snapshot := _slot_opts.duplicate()
	for slot in snapshot.keys():
		var o: Dictionary = opts_snapshot.get(slot, {})
		set_accessory(String(slot), String(snapshot[slot]), o)
	if not _slots.has("hat"):
		_hat = null
		_hat_spin = false


## Палітра-підміна для всіх частин: o — основний, d — темніший, c — крем, k — темне (носик/копитця),
## i — рожева серединка вуха, t — кінчик хвоста, m — плямки/смужки.
func _voxel_palette() -> Dictionary:
	return {
		"o": color.to_html(false),
		"d": color.darkened(0.22).to_html(false),
		"c": Palette.H_CREAM.to_html(false),
		"k": Palette.H_DARK.to_html(false),
		"i": Palette.H_ACC_PINK.to_html(false),
		"t": accent.to_html(false),
		"m": mark.to_html(false),
	}


func _part_mesh(voxel: String, pal: Dictionary) -> MeshInstance3D:
	var mi := VoxelBuilder.instance(voxel, pal)
	_meshes.append(mi)
	return mi


# ---------- складання ----------

## Голова: шарнір на шиї, у ньому меш голови, обличчя, вуха й точки кріплення капелюшка/окулярів.
func _build_head(head_voxel: String, ear_voxel: String, pal: Dictionary) -> void:
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0.0, NECK_Y, NECK_Z)
	_body.add_child(_head)
	var m := _part_mesh(head_voxel, pal)
	m.name = "HeadMesh"
	_head.add_child(m)
	_build_face()
	_build_ears(ear_voxel, pal)


## Чотири лапки на шарнірах (плече/стегно), меш звисає вниз — на бігу вони махають галопом.
func _build_legs(leg_voxel: String, pal: Dictionary) -> void:
	var spots := [
		Vector3(-HIP_X, LEG_H, HIP_Z_FRONT),
		Vector3(HIP_X, LEG_H, HIP_Z_FRONT),
		Vector3(-HIP_X, LEG_H, HIP_Z_BACK),
		Vector3(HIP_X, LEG_H, HIP_Z_BACK),
	]
	var names := ["LegFL", "LegFR", "LegBL", "LegBR"]
	for i in range(spots.size()):
		var leg := Node3D.new()
		leg.name = String(names[i])
		leg.position = spots[i]
		var m := _part_mesh(leg_voxel, pal)
		m.position.y = -LEG_H
		leg.add_child(m)
		_body.add_child(leg)
		_legs.append(leg)


## Вуха на маківці: розхилені, дзеркальні; висячі (песик) відхилені вниз.
func _build_ears(ear_voxel: String, pal: Dictionary) -> void:
	var floppy := ear_voxel == "hero_ear_flop"
	var long_ear := ear_voxel == "hero_ear_long"
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var ear := Node3D.new()
		ear.name = "EarL" if i == 0 else "EarR"
		# у координатах голови: маківка — y = HEAD_H, трохи ближче до потилиці;
		# висяче вухо сидить нижче й ближче до скроні
		var ear_y := HEAD_H - 0.05 if floppy else HEAD_H - 0.02
		var ear_x := side * (0.24 if floppy else 0.15)
		ear.position = Vector3(ear_x, ear_y, 0.02)
		var base := Vector3.ZERO
		if floppy:
			base = Vector3(0.0, 0.0, side * 2.3)     # звисає вниз уздовж щоки
		elif long_ear:
			base = Vector3(0.22, 0.0, side * 0.12)   # довге вухо трохи відхилене назад
		else:
			base = Vector3(0.0, 0.0, side * 0.2)
		ear.rotation = base
		var m := _part_mesh(ear_voxel, pal)
		m.scale.x = side                              # друге вухо — дзеркальне
		ear.add_child(m)
		_head.add_child(ear)
		_ears.append(ear)
		_ear_base.append(base)
		_parts.append(ear)


## Хвіст на шарнірі ззаду-вгорі тулуба. Вертикальні хвости (песик, котик) відхиляємо назад.
func _build_tail(tail_voxel: String, pal: Dictionary) -> void:
	_tail = Node3D.new()
	_tail.name = "Tail"
	_tail.position = Vector3(0.0, TAIL_Y, TAIL_Z)
	var m := _part_mesh(tail_voxel, pal)
	match tail_voxel:
		"hero_tail_dog":
			_tail_base_x = 0.5
			m.position.y = 0.0
		"hero_tail_cat":
			_tail_base_x = 0.9
			m.position.y = 0.0
		"hero_tail_fox":
			_tail_base_x = -0.25
			m.position = Vector3(0.0, -0.09, 0.14)
		_:
			_tail_base_x = 0.0
			m.position = Vector3(0.0, -0.05, 0.05)
	_tail.rotation.x = _tail_base_x
	_tail.add_child(m)
	_body.add_child(_tail)
	_parts.append(_tail)


# ---------- капелюшок і аксесуари ----------

var hat_id := "none"
var _hat: Node3D
var _hat_spin := false
## Слоти аксесуарів: "hat", "face", "neck", "back", "trail" → один вузол на слот.
var _slots: Dictionary = {}
var _slot_voxels: Dictionary = {}
var _slot_opts: Dictionary = {}
## Лишилось від пухнастиків v1.4 (чубчика під капелюшком у звірят уже нема).
const NO_TUFT_FEATURES := ["ears", "tail", "antenna", "stripes", "sparkle", "cloud", "sleepy"]


## Одягнути капелюшок із data/hats.json (id "none" — зняти). Кріпиться до маківки, гойдається з головою.
func set_hat(id: String) -> void:
	hat_id = id
	var def := Hats.find(Hats.load_all(), id)
	var voxel := String(def.get("voxel", ""))
	if def.is_empty() or voxel == "":
		set_accessory("hat", "")
		return
	set_accessory("hat", voxel, {"y": float(def.get("y", 0.0)), "spin": bool(def.get("spin", false))})


## Аксесуар у слот. voxel — назва з data/voxels ("" — зняти). opts:
##   hat:   {"y": float, "spin": bool}
##   trail: {"color": "#hex"} — слід-іскри за героєм (voxel не потрібен; без color — зняти)
## Слоти: "hat" (маківка) і "face" (окуляри) живуть на голові, тож рухаються з нею;
## "neck" (шарфик, гойдається) і "back" (крильця/рюкзачок, махають) — на тулубі; "trail" — за героєм.
func set_accessory(slot: String, voxel: String, opts: Dictionary = {}) -> void:
	_remove_slot(slot)
	if slot == "trail":
		var col := String(opts.get("color", ""))
		if col == "":
			return
		# слід — дитина self, а не тіла, щоб сквош/присід його не тягнули
		var tr := FX.trail(self, Color(col))
		tr.position = Vector3(0.0, 0.3, 0.3)
		_slots[slot] = tr
		_slot_voxels[slot] = voxel
		_slot_opts[slot] = opts
		return
	if voxel == "":
		return
	var node := Node3D.new()
	node.name = "Acc_%s" % slot
	node.add_child(VoxelBuilder.instance(voxel))
	var parent := _body
	match slot:
		"hat":
			# у координатах голови: на маківці
			parent = _head if _head != null else _body
			node.position = Vector3(0.0, HEAD_H - 0.02 + float(opts.get("y", 0.0)), 0.0)
		"face":
			# окуляри на очах, трохи перед мордою
			parent = _head if _head != null else _body
			node.position = Vector3(0.0, 0.24, -HEAD_HALF_D - 0.03)
		"neck":
			node.position = Vector3(0.0, 0.50, -0.10)
		"back":
			node.position = Vector3(0.0, TORSO_TOP - 0.02, 0.06)
		_:
			node.position = Vector3(0.0, 0.50, 0.0)
	parent.add_child(node)
	_slots[slot] = node
	_slot_voxels[slot] = voxel
	_slot_opts[slot] = opts
	if slot == "hat":
		_hat = node
		_hat_spin = bool(opts.get("spin", false))
		_squash(Vector3(1.1, 0.9, 1.1), 0.12)
	else:
		_squash(Vector3(1.06, 0.94, 1.06), 0.1)


## Зняти все (капелюшок теж).
func clear_accessories() -> void:
	for slot in _slots.keys().duplicate():
		set_accessory(String(slot), "")
	hat_id = "none"


func _remove_slot(slot: String) -> void:
	var node = _slots.get(slot)
	if node != null and is_instance_valid(node):
		if node == _hat:
			_hat = null
			_hat_spin = false
		node.queue_free()
	_slots.erase(slot)
	_slot_voxels.erase(slot)
	_slot_opts.erase(slot)


func _box(size: Vector3, c: Color, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := Mats.box(size, c)
	mi.position = pos
	parent.add_child(mi)
	return mi


## Обличчя живе на голові (координати голови): великі очі з бліком у темних западинах вокселя,
## щічки й рот на кремовій морді.
func _build_face() -> void:
	_face = Node3D.new()
	_face.name = "Face"
	_head.add_child(_face)
	var eye_pale := Palette.H_CREAM
	var pupil := Palette.HERO_EYE
	var face_z := -HEAD_HALF_D - 0.01
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.15, 0.225, face_z)
		_face.add_child(eye)
		_box(Vector3(0.105, 0.185, 0.02), eye_pale, Vector3.ZERO, eye)
		var p := _box(Vector3(0.075, 0.15, 0.02), pupil, Vector3(0.0, 0.0, -0.015), eye)
		_box(Vector3(0.028, 0.028, 0.01), Color.WHITE, Vector3(0.02, 0.04, -0.014), p)  # блик
		_eyes.append(eye)
		_pupils.append(p)
		_box(Vector3(0.07, 0.05, 0.02), Palette.HERO_CHEEK, Vector3(side * 0.2, 0.12, face_z + 0.01), _face)
	_mouth = _box(Vector3(0.1, 0.03, 0.02), Palette.HERO_MOUTH, Vector3(0.0, _mouth_y, face_z), _face)
	_eye_scale_y = 0.55 if feature == "sleepy" else 1.0
	for e in _eyes:
		e.scale.y = _eye_scale_y


func is_airborne() -> bool:
	return _y > 0.02 or flying


## Стрибок. scale < 1 — нижчий (підскок на хвилі). Повертає false, якщо стрибнути не можна.
func jump(k: float = 1.0) -> bool:
	if is_airborne() or tumbling or sitting:
		return false
	_vy = jump_velocity * k * jump_scale
	ducking = false
	_squash(Vector3(0.9, 1.18, 0.9), 0.12)
	_flap(1.0)
	return true


## Короткий підскок у режимі Стрибки.
func hop() -> void:
	if _y < 0.15:
		# у присіді крок нижчий — щоб пролізти під павутинкою
		_vy = HOP_VELOCITY * (0.7 if ducking else 1.0)
		_squash(Vector3(0.94, 1.1, 0.94), 0.1)
		_flap(0.6)


## Кількість доріжок на дорозі (3/5/7) — з рівня.
var lanes := 3


func max_lane() -> int:
	return (lanes - 1) / 2


func x_limit() -> float:
	return float(max_lane()) * LANE_W + 0.3


## Дорога звузилась/розширилась: герой лишається на найближчій доріжці.
func set_lanes(n: int) -> void:
	lanes = clampi(n, 3, 7)
	if lanes % 2 == 0:
		lanes += 1
	lane = clampi(lane, -max_lane(), max_lane())
	x_target = clampf(x_target, -x_limit(), x_limit())
	if not free_x:
		x_target = float(lane) * LANE_W


func change_lane(dir: int) -> bool:
	var next := clampi(lane + dir, -max_lane(), max_lane())
	if next == lane:
		return false
	lane = next
	x_target = float(lane) * LANE_W
	return true


func snap_to_lane() -> void:
	lane = clampi(int(round(x_target / LANE_W)), -max_lane(), max_lane())
	x_target = float(lane) * LANE_W


func nudge_x(d: float) -> void:
	x_target = clampf(x_target + d * 0.8, -x_limit(), x_limit())


func set_duck(on: bool) -> void:
	var next := on and not tumbling
	# присів — хмаринка пилу під ногами
	if next and not ducking:
		FX.dust(self, Vector3(0, 0.03, 0))
	ducking = next


func tilt(v: float) -> void:
	_tilt = v


## Транспорт: дошка (Серфінг), мушля (Хвиля) або самокат (Місто). kind — назва вокселя.
var _vehicle_kind := "shell"
## Невагомість (Хмаринки): 0.4 — герой падає повільно.
var gravity_scale := 1.0


func set_vehicle(on: bool, kind: String = "shell") -> void:
	if on and kind != _vehicle_kind:
		_vehicle.queue_free()
		_vehicle = VoxelBuilder.instance(kind)
		# дошка/мушля сидять у воді трохи нижче
		_vehicle.position.y = -0.05 if kind in ["shell", "surfboard"] else 0.0
		add_child(_vehicle)
		_vehicle_kind = kind
	_vehicle.visible = on


# ---------- життя, щит, платформа ----------

## Скинути серця на початку рівня.
func reset_hearts() -> void:
	hearts = max_hearts
	invulnerable_t = 0.0
	_body.visible = true


## Втратити серце. Повертає false, якщо герой невразливий (удар не зараховано).
func lose_heart() -> bool:
	if invulnerable_t > 0.0:
		return false
	hearts = maxi(0, hearts - 1)
	set_invulnerable(1.5)
	return true


## +1 серце (пікап). false — уже повні.
func gain_heart() -> bool:
	if hearts >= max_hearts:
		return false
	hearts += 1
	_squash(Vector3(1.15, 0.85, 1.15), 0.12)
	FX.hearts(self, Vector3(0, 1.3, 0), 8)
	return true


## Невразливість на seconds: тіло миготить (видиме/невидиме кожні 0,1 с).
func set_invulnerable(seconds: float) -> void:
	invulnerable_t = maxf(invulnerable_t, seconds)
	_blink_vis_t = 0.0


## Щит-бульбашка (пікап): один удар поглинається.
func set_shield(on: bool) -> void:
	shield_on = on
	if on:
		_shield_popping = false
		_shield.visible = true
		_shield.scale = Vector3.ONE * 0.1
		var tw := create_tween()
		tw.tween_property(_shield, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif not _shield_popping:
		# лопання ще триває — сховає pop_shield у кінці твіну
		_shield.visible = false


## Щит лопнув — бризки й «пшик»; бульбашка ховається в кінці анімації.
func pop_shield() -> void:
	shield_on = false
	_shield_popping = true
	FX.burst(self, Vector3(0, 0.7, 0), Palette.HERO_SHIELD)
	var tw := create_tween()
	tw.tween_property(_shield, "scale", Vector3.ONE * 1.4, 0.12)
	tw.tween_callback(func():
		_shield_popping = false
		# якщо за цей час щит не підібрали знову — ховаємо
		if not shield_on:
			_shield.visible = false)


## Сісти («Ще раз!»): задні лапки підібгані, ніс донизу, очі заплющені на 0,5 с, біг вимкнено.
func sit() -> void:
	if _tumble_tween:
		_tumble_tween.kill()
		_tumble_tween = null
	tumbling = false
	ducking = false
	sitting = true
	running = false
	_body.position.y = -0.06
	_body.rotation.x = 0.3
	_body.visible = true
	invulnerable_t = 0.0
	_set_eyes_closed(true)
	get_tree().create_timer(0.5).timeout.connect(func():
		if sitting and is_instance_valid(self):
			_set_eyes_closed(false))


## Встати після сидіння (новий старт рівня).
func stand() -> void:
	sitting = false
	_body.rotation.x = 0.0
	_body.position.y = 0.0
	_set_eyes_closed(false)


## Рівень землі під героєм (платформа другого рівня). Позиція у світі не стрибає:
## коли земля піднімається — висота стрибка перераховується; невеликий спуск (пандус) — герой тримається поверхні,
## великий (зійшов із платформи вбік) — падає.
func set_ground(h: float) -> void:
	var dy := h - ground_y
	if absf(dy) < 0.0005:
		return
	ground_y = h
	if dy > 0.0:
		if _y > 0.02:
			_y = maxf(0.0, _y - dy)
			if _y <= 0.0:
				_vy = 0.0
				landed.emit()
				_squash(Vector3(1.15, 0.85, 1.15), 0.09)
		else:
			# був на землі, а земля підскочила (зайшов на платформу збоку) — підскок разом із нею
			_y = 0.0
			_vy = 0.0
			if dy > 0.6:
				_squash(Vector3(0.9, 1.15, 0.9), 0.1)
	elif dy < -0.5:
		# зійшов із платформи — падає з висоти
		if _y <= 0.02:
			_y = -dy
			_vy = 0.0
	# малий спуск (пандус вниз) — лишаємось на поверхні: _y не чіпаємо


func set_running(on: bool) -> void:
	running = on


## Комічне зіткнення (GDD v1.4 §2, реф. §3): великі очі, рот «О», відкинуло вбік на пів доріжки
## з обертом ±0,5 рад, три зірочки крутяться над головою 1,2 с, невразливість 1,5 с.
## Спавнер кличе tumble() — тому старе ім'я лишилось, а вигляд новий.
func tumble() -> void:
	# бік удару невідомий: відкидає навмання, але з краю дороги — до центру
	var dir := 1 if randf() < 0.5 else -1
	if absf(x_target) > (float(max_lane()) - 0.5) * LANE_W:
		dir = -1 if x_target > 0.0 else 1
	hit_reaction(dir)


## Комічна реакція на удар. dir — куди відкидає (−1 ліворуч, +1 праворуч, 0 — без зсуву).
func hit_reaction(dir: int = 0) -> void:
	if tumbling:
		return
	tumbling = true
	ducking = false
	# очі великі, зіниці меншають, рот «О»
	for e in _eyes:
		e.scale = Vector3(HIT_EYE_SCALE, HIT_EYE_SCALE, 1.0)
	for p in _pupils:
		p.scale = Vector3(HIT_PUPIL_SCALE, HIT_PUPIL_SCALE, 1.0)
	_mouth.scale = Vector3(1.6, 2.4, 1.0)
	_mouth.position.y = _mouth_y - 0.01
	# відкинуло вбік на пів доріжки (у межах дороги)
	if dir != 0:
		x_target = clampf(x_target + float(dir) * LANE_W * HIT_SIDE_LANES, -x_limit(), x_limit())
		lane = clampi(int(round(x_target / LANE_W)), -max_lane(), max_lane())
	_hit_stars()
	FX.burst(self, Vector3(0, HEAD_TOP, 0), Palette.STAR)
	FX.dust(self, Vector3(0, 0.05, 0))
	# невразливість ставимо відкладено: Spawner після tumble() кличе lose_heart(),
	# який мовчки нічого не робить, поки герой невразливий
	call_deferred("set_invulnerable", HIT_INVULN_SEC)
	if _tumble_tween:
		_tumble_tween.kill()
	var spin := float(dir if dir != 0 else 1) * HIT_SPIN
	_tumble_tween = create_tween()
	_tumble_tween.tween_property(_body, "rotation:y", spin, 0.18).set_trans(Tween.TRANS_BACK)
	_tumble_tween.parallel().tween_property(_body, "position:y", 0.22, 0.18)
	_tumble_tween.tween_property(_body, "rotation:y", 0.0, 0.32).set_trans(Tween.TRANS_ELASTIC)
	_tumble_tween.parallel().tween_property(_body, "position:y", 0.0, 0.32)
	_tumble_tween.finished.connect(_end_tumble)


## Три маленькі зірочки кружляють над головою 1,2 с.
func _hit_stars() -> void:
	var ring := Node3D.new()
	ring.name = "HitStars"
	ring.position = Vector3(0.0, HEAD_TOP + 0.22, 0.0)
	add_child(ring)
	for i in range(HIT_STARS):
		var s := VoxelBuilder.instance("star")
		s.scale = Vector3.ONE * 0.4
		var a := TAU * float(i) / float(HIT_STARS)
		s.position = Vector3(cos(a) * 0.32, sin(a * 2.0) * 0.05, sin(a) * 0.32)
		ring.add_child(s)
	var tw := create_tween()
	tw.tween_property(ring, "rotation:y", TAU * 2.0, HIT_STARS_SEC).from(0.0)
	tw.finished.connect(ring.queue_free)


func _end_tumble() -> void:
	_body.rotation.y = 0.0
	_body.position.y = 0.0
	tumbling = false
	# обличчя назад: очі, зіниці, рот
	for e in _eyes:
		e.scale = Vector3(1.0, _eye_scale_y, 1.0)
	for p in _pupils:
		p.scale = Vector3.ONE
	if is_instance_valid(_mouth):
		_mouth.scale = Vector3.ONE
		_mouth.position.y = _mouth_y
	# після відкидання герой стоїть на найближчій доріжці
	snap_to_lane()
	tumble_finished.emit()


## Політ (веселка): герой парить на висоті FLY_HEIGHT задані секунди.
func fly(seconds: float) -> void:
	flying = true
	_vy = 0.0
	_flap(1.0)
	get_tree().create_timer(seconds).timeout.connect(_end_fly)


func _end_fly() -> void:
	flying = false


## Зупинити політ негайно (ракета скінчилась/скинута): герой падає з поточної висоти.
func stop_fly() -> void:
	flying = false
	_vy = 0.0


func wave_bump() -> void:
	if not tumbling:
		_vy = 6.0
		_flap(1.0)


## Погладили: підскок, сквош, очі-щілинки від задоволення, усмішка, сердечка.
func pet() -> void:
	if not is_airborne() and not tumbling:
		_vy = 3.5
	_squash(Vector3(1.2, 0.8, 1.2), 0.15)
	_happy(0.7)
	_flap(0.8)
	FX.hearts(self, Vector3(0, 1.3, 0))
	AudioMgr.sfx("giggle")


## Радість (зірочки, станція): підскок, сквош, усмішка, сердечка.
func cheer() -> void:
	if not is_airborne() and not tumbling:
		_vy = 3.5
	_squash(Vector3(1.15, 0.85, 1.15), 0.12)
	_happy(0.6)
	_flap(1.0)
	FX.hearts(self, Vector3(0, 1.3, 0))


## Привітання: піднімає передню праву лапку й махає нею, підморгує (меню, поява в каруселі).
func wave_hello() -> void:
	if _legs.size() < 2:
		return
	var leg := _legs[1]
	_wave_t = 1.9                     # поки махає — _process цю лапку не чіпає
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(leg, "rotation:x", -1.7, 0.25).set_trans(Tween.TRANS_BACK)
	for i in range(3):
		tw.tween_property(leg, "rotation:z", 0.5, 0.14)
		tw.tween_property(leg, "rotation:z", -0.5, 0.14)
	tw.tween_property(leg, "rotation:z", 0.0, 0.1)
	tw.tween_property(leg, "rotation:x", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	# підморгує одним оком
	if _eyes.size() > 1:
		var tw2 := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw2.tween_interval(0.3)
		tw2.tween_property(_eyes[1], "scale:y", 0.1, 0.08)
		tw2.tween_interval(0.35)
		tw2.tween_property(_eyes[1], "scale:y", _eye_scale_y, 0.1)
	_happy(0.9)
	AudioMgr.voice("hello")


## Повернутись обличчям до камери (меню/карусель) або вперед по дорозі.
func face_camera(on: bool, duration: float = 0.5) -> void:
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(self, "rotation:y", PI if on else 0.0, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## «Пух!» росту.
func pop_grow() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 1.35, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC)
	FX.confetti(self, Vector3(0, 1.0, 0), 40)


## Сірий «ще не відкритий» вигляд (карусель героїв) — на всіх частинах звірятка.
func set_locked_look(locked: bool) -> void:
	if feature == "cloud":
		return
	if not locked:
		for m in _meshes:
			if is_instance_valid(m):
				m.material_override = null
		if _face != null:
			_face.visible = true
		return
	var m0 := VoxelBuilder.material()
	if m0 is ShaderMaterial:
		var d := (m0 as ShaderMaterial).duplicate() as ShaderMaterial
		d.set_shader_parameter("tint_strength", 0.7)
		d.set_shader_parameter("tint", Palette.HERO_GHOST)
		for m in _meshes:
			if is_instance_valid(m):
				m.material_override = d
	if _face != null:
		_face.visible = false


## Габарит для перевірки зіткнень (світові координати; герой завжди в z = 0). На платформі — вище за землю.
## Лишився таким самим, як у пухнастика v1.4, щоб перешкоди й спавнер працювали як раніше.
func hit_box() -> AABB:
	var h := 0.5 if ducking else 1.1
	return AABB(Vector3(position.x - 0.28, ground_y + _y, -0.28), Vector3(0.56, h, 0.56))


# ---------- анімація ----------

func _squash(to: Vector3, dur: float) -> void:
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_body, "scale", to, dur)
	tw.tween_property(_body, "scale", Vector3.ONE, dur * 1.5).set_trans(Tween.TRANS_ELASTIC)


## Вуха підскакують (rotation.z від базового розхилу), хвіст смикається (rotation.x),
## крильця/рюкзачок на спині махають. Осі різні з тими, що крутить _process, — не перетираються.
func _flap(strength: float) -> void:
	for i in range(_ears.size()):
		var e := _ears[i]
		if not is_instance_valid(e):
			continue
		var base: Vector3 = _ear_base[i]
		var side := -1.0 if i == 0 else 1.0
		var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(e, "rotation:z", base.z + side * 0.5 * strength, 0.12)
		tw.tween_property(e, "rotation:z", base.z, 0.4).set_trans(Tween.TRANS_ELASTIC)
	if _tail != null and is_instance_valid(_tail):
		var tw_tail := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_tail.tween_property(_tail, "rotation:x", _tail_base_x - 0.4 * strength, 0.12)
		tw_tail.tween_property(_tail, "rotation:x", _tail_base_x, 0.4).set_trans(Tween.TRANS_ELASTIC)
	var back = _slots.get("back")
	if back != null and is_instance_valid(back):
		var tw_back := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_back.tween_property(back, "rotation:x", -0.5 * strength, 0.12)
		tw_back.tween_property(back, "rotation:x", 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC)


## Щасливе обличчя: очі-щілинки (замружився від задоволення) і широка усмішка, піднята вгору — не сумна.
func _happy(seconds: float) -> void:
	_set_eyes_closed(true)
	_mouth.scale = Vector3(1.8, 2.5, 1.0)
	_mouth.position.y = _mouth_y + 0.02
	get_tree().create_timer(seconds).timeout.connect(func():
		if not is_instance_valid(_mouth):
			return
		_set_eyes_closed(false)
		_mouth.scale = Vector3.ONE
		_mouth.position.y = _mouth_y)


func _set_eyes_closed(closed: bool) -> void:
	for e in _eyes:
		e.scale.y = 0.12 if closed else _eye_scale_y


func _process(delta: float) -> void:
	_t += delta
	# x — до цілі
	position.x = lerpf(position.x, x_target, minf(1.0, delta * 12.0))
	# y — гравітація або політ
	var was_air := _y > 0.02
	if flying:
		_y = lerpf(_y, FLY_HEIGHT + sin(_t * 4.0) * 0.15, minf(1.0, delta * 4.0))
	else:
		_vy -= GRAVITY * gravity_scale * delta
		_y += _vy * delta
		if _y <= 0.0:
			_y = 0.0
			_vy = 0.0
			if was_air:
				landed.emit()
				_squash(Vector3(1.12, 0.86, 1.12), 0.09)
				_flap(-0.6)
				FX.dust(self, Vector3(0, 0.03, 0))
	var bob := 0.0
	if feature == "cloud":
		bob = 0.12 + sin(_t * 2.2) * 0.06
	position.y = ground_y + _y + bob + (wave_offset if _vehicle.visible else 0.0)
	# невразливість: тіло миготить кожні 0,1 с
	if invulnerable_t > 0.0:
		invulnerable_t -= delta
		_blink_vis_t += delta
		if _blink_vis_t >= 0.1:
			_blink_vis_t = 0.0
			_body.visible = not _body.visible
		if invulnerable_t <= 0.0:
			_body.visible = true
	# щит дихає
	if shield_on and _shield.visible:
		var sp := 1.0 + sin(_t * 5.0) * 0.04
		_shield.scale = Vector3(sp, sp, sp)
	# тінь лишається на землі (або подіумі), витягнута вздовж тіла, і меншає в польоті
	_shadow.position.y = -(position.y - ground_y) + 0.015
	var k := clampf((position.y - ground_y) / 2.5, 0.0, 1.0)
	_shadow.scale = Vector3(0.95 * (1.0 - k * 0.5), 1.0, 1.5 * (1.0 - k * 0.5))
	(_shadow.material_override as StandardMaterial3D).albedo_color.a = 0.32 * (1.0 - k * 0.7)
	# нахил: кермо + лін при зміні доріжки
	var lean := -(x_target - position.x) * 0.45
	rotation.z = lerpf(rotation.z, _tilt + lean, minf(1.0, delta * 10.0))
	# очі дивляться в бік повороту
	var look_x := clampf((x_target - position.x) * 0.12, -0.035, 0.035)
	for p in _pupils:
		p.position.x = lerpf(p.position.x, look_x, minf(1.0, delta * 8.0))
	# кліпання
	_blink_t += delta
	if _blink_t > _next_blink:
		_blink_t = 0.0
		_next_blink = randf_range(2.2, 5.0)
		_blink()
	# Соня зіває
	if feature == "sleepy":
		_yawn_t += delta
		if _yawn_t > 7.0:
			_yawn_t = 0.0
			_mouth.scale = Vector3(1.2, 3.5, 1.0)
			get_tree().create_timer(0.7).timeout.connect(func(): _mouth.scale = Vector3.ONE)
	if _wave_t > 0.0:
		_wave_t -= delta
	# присід: плавний перехід 20/с
	_duck_blend = lerpf(_duck_blend, 1.0 if ducking else 0.0, minf(1.0, delta * 20.0))
	var run_f := 11.0 * run_speed_factor        # частота галопу
	var galloping := running and not is_airborne() and not ducking and not sitting
	var swing := sin(_t * run_f) * GALLOP_SWING * clampf(run_speed_factor, 0.5, 1.4)
	# лапки: галоп (передня пара в антифазі із задньою), стрибок — підібгані, присід — під тілом
	if not tumbling:
		for i in range(_legs.size()):
			if i == 1 and _wave_t > 0.0:
				continue                        # цією лапкою зараз махає wave_hello
			var front := i < 2
			var a := 0.0
			if ducking:
				a = (-0.25 if front else 0.25) * _duck_blend
			elif is_airborne():
				a = -0.9 if front else 0.9      # у стрибку лапки підібгані під себе
			elif galloping:
				a = swing if front else -swing
			else:
				a = sin(_t * 1.4 + (0.0 if front else 1.1)) * 0.05
			_legs[i].rotation.x = lerpf(_legs[i].rotation.x, a, minf(1.0, delta * 18.0))
	# голова: контр-боб до тіла, у присіді витягується вперед-униз
	if _head != null and not tumbling:
		var head_y := NECK_Y
		var head_z := NECK_Z
		var head_pitch := 0.0
		if galloping:
			head_y += -sin(_t * run_f) * 0.02
			head_pitch = -sin(_t * run_f + 1.2) * 0.06
		elif not running and not sitting:
			head_y += sin(_t * 3.0) * 0.008
		if _duck_blend > 0.01:
			head_y = lerpf(head_y, NECK_Y - 0.04, _duck_blend)
			head_z = lerpf(head_z, NECK_Z - 0.08, _duck_blend)
			head_pitch = lerpf(head_pitch, 0.35, _duck_blend)
		_head.position.y = lerpf(_head.position.y, head_y, minf(1.0, delta * 14.0))
		_head.position.z = lerpf(_head.position.z, head_z, minf(1.0, delta * 14.0))
		_head.rotation.x = lerpf(_head.rotation.x, head_pitch, minf(1.0, delta * 12.0))
	# вуха теліпаються з інерцією (відстають від бобу), інколи сіпаються у спокої
	var ear_lag := -sin(_t * run_f - 0.9) * 0.26 if galloping else 0.0
	for i in range(_ears.size()):
		var e := _ears[i]
		if not is_instance_valid(e):
			continue
		var idle := sin(_t * 1.3 + float(i)) * 0.03
		e.rotation.x = lerpf(e.rotation.x, _ear_base[i].x + ear_lag + idle, minf(1.0, delta * 10.0))
	if not running and not _ears.is_empty():
		_twitch_t += delta
		if _twitch_t > 4.5:
			_twitch_t = randf_range(-1.5, 0.0)
			_ear_twitch()
	# хвіст махає (швидше на бігу)
	if _tail != null and is_instance_valid(_tail) and not tumbling:
		_tail.rotation.y = sin(_t * (7.0 if galloping else 3.0)) * (0.45 if galloping else 0.25)
	# шарфик гойдається
	var neck = _slots.get("neck")
	if neck != null and is_instance_valid(neck):
		neck.rotation.z = sin(_t * 3.0) * 0.12
		neck.rotation.x = sin(_t * 2.3 + 1.0) * 0.06
	if _hat_spin and is_instance_valid(_hat):
		_hat.rotation.y += delta * 7.0
	# біг-боб / дихання / присід — на тілі, щоб не ламати перекид; сидить — тіло не чіпаємо
	if not tumbling and not sitting:
		var target_scale := Vector3.ONE
		var body_y := 0.0
		var lean_x := 0.0
		var rate := 14.0
		if ducking:
			# присів: звірятко припадає до землі (голова окремо йде вперед)
			target_scale = Vector3(1.1, 0.62, 1.1)
			body_y = -0.12
			rate = 20.0
		elif galloping:
			body_y = absf(sin(_t * run_f)) * 0.05 * run_speed_factor
			lean_x = -0.05 + sin(_t * run_f * 2.0) * 0.03
			target_scale = Vector3(1.0, 1.0 + sin(_t * run_f * 2.0) * 0.025, 1.0)
		else:
			var breath := sin(_t * 4.0) * 0.02
			target_scale = Vector3(1.0 + breath, 1.0 - breath, 1.0 + breath)
		if _duck_blend > 0.01:
			rate = 20.0
		# після присіду відстань до цілі велика — пускаємо лерп і тоді (сквош-твін не заважає: він короткий)
		if _body.scale.distance_to(target_scale) < 0.3 or _duck_blend > 0.01:
			_body.scale = _body.scale.lerp(target_scale, minf(1.0, delta * rate))
		_body.position.y = lerpf(_body.position.y, body_y, minf(1.0, delta * 16.0))
		_body.rotation.x = lerpf(_body.rotation.x, lean_x, minf(1.0, delta * 6.0))
	# у спокої (меню/станція) інколи озирається
	if not running and not tumbling and not sitting:
		_look_t += delta
		if _look_t > 3.5:
			_look_t = randf_range(-2.0, 0.0)
			var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(_body, "rotation:y", randf_range(-0.5, 0.5), 0.4).set_trans(Tween.TRANS_SINE)
			tw.tween_interval(0.8)
			tw.tween_property(_body, "rotation:y", 0.0, 0.4).set_trans(Tween.TRANS_SINE)


## Одне вухо сіпається (спокій).
func _ear_twitch() -> void:
	if _ears.is_empty():
		return
	var i := randi() % _ears.size()
	var e := _ears[i]
	if not is_instance_valid(e):
		return
	var base: Vector3 = _ear_base[i]
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(e, "rotation:z", base.z + 0.35, 0.09)
	tw.tween_property(e, "rotation:z", base.z, 0.25).set_trans(Tween.TRANS_ELASTIC)


func _blink() -> void:
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for e in _eyes:
		tw.parallel().tween_property(e, "scale:y", 0.08, 0.06)
	tw.chain()
	for e in _eyes:
		tw.parallel().tween_property(e, "scale:y", _eye_scale_y, 0.08)
