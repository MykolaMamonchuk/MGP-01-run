## Герой у 3D. Стоїть у початку координат, світ рухається на нього (+Z).
## Тіло — воксель з даних; очі, щічки, рот і риса (вуха/хвіст/чубчик/антенка…) — окремі частини,
## тому герой кліпає, дивиться в бік повороту, махає вухами й хвостом. Уся анімація процедурна (Tween + sin).
class_name Hero3D
extends Node3D

signal landed
signal tumble_finished

const LANE_W := 1.0
const GRAVITY := 22.0
const HOP_VELOCITY := 4.6
const FLY_HEIGHT := 1.9
const X_FREE_LIMIT := 1.3
const HEAD_TOP := 1.2
const FACE_Z := -0.37

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
var hero_id := "puf"
var feature := "tuft"
var color := Color("#FFB84D")

var _vy := 0.0
var _y := 0.0
var _tilt := 0.0
var _t := 0.0
var _blink_t := 0.0
var _next_blink := 3.0
var _look_t := 0.0
var _yawn_t := 0.0

var _body: Node3D
var _mesh: MeshInstance3D
var _face: Node3D
var _eyes: Array[Node3D] = []
var _pupils: Array[MeshInstance3D] = []
var _mouth: MeshInstance3D
var _parts: Array[Node3D] = []      # риса: вуха/хвіст/чубчик…
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _shadow: MeshInstance3D
var _vehicle: MeshInstance3D
var _sparkles: GPUParticles3D
var _tumble_tween: Tween
var _eye_scale_y := 1.0
var _duck_blend := 0.0          # 0 — стоїть, 1 — присів (плавний перехід 20/с)
var _mouth_y := 0.73            # базова висота рота (усмішка піднімає на +0.02)
var _blink_vis_t := 0.0         # таймер миготіння тіла під час невразливості
var _shield: MeshInstance3D
var _shield_popping := false    # бульбашка лопається — set_shield(false) її не ховає раніше часу


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
	shm.emission = Color("#40C4FF")
	shm.emission_energy_multiplier = 0.6
	shm.roughness = 0.2
	_shield.material_override = shm
	_shield.position.y = 0.62
	_shield.visible = false
	add_child(_shield)

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
	add_child(_shadow)

	_vehicle = VoxelBuilder.instance("shell")
	_vehicle.position.y = -0.05
	_vehicle.visible = false
	add_child(_vehicle)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	set_hero(hero_id, color.to_html(false), feature)


## Перебудувати героя: тіло з палітрою + обличчя + риса.
func set_hero(id: String, color_hex: String, feat: String = "tuft") -> void:
	hero_id = id
	feature = feat
	color = Color(color_hex)
	for c in _body.get_children():
		c.queue_free()
	_eyes.clear()
	_pupils.clear()
	_parts.clear()
	_legs.clear()
	_arms.clear()
	_sparkles = null

	_mesh = VoxelBuilder.instance("hero_puf", {"o": color_hex, "d": color.darkened(0.22).to_html(false)})
	_mesh.name = "Mesh"
	_body.add_child(_mesh)
	if feature == "cloud":
		_mesh.material_override = VoxelBuilder.material_alpha(0.72)

	_build_limbs()
	_build_face()
	_build_feature()
	_body.scale = Vector3.ONE
	_body.rotation = Vector3.ZERO
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


# ---------- капелюшок і аксесуари ----------

var hat_id := "none"
var _hat: Node3D
var _hat_spin := false
## Слоти аксесуарів: "hat", "face", "neck", "back", "trail" → один вузол на слот.
var _slots: Dictionary = {}
var _slot_voxels: Dictionary = {}
var _slot_opts: Dictionary = {}
## Чи в цієї риси є чубчик, який ховається під капелюшком.
const NO_TUFT_FEATURES := ["ears", "tail", "antenna", "stripes", "sparkle", "cloud", "sleepy"]


## Одягнути капелюшок із data/hats.json (id "none" — зняти). Кріпиться до маківки, махає разом із рисою.
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
## Слоти: "hat" (маківка), "face" (окуляри), "neck" (шарфик, гойдається), "back" (крильця/рюкзачок, махають), "trail".
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
	match slot:
		"hat":
			node.position = Vector3(0.0, HEAD_TOP - 0.02 + float(opts.get("y", 0.0)), 0.0)
		"face":
			node.position = Vector3(0.0, 0.93, FACE_Z - 0.03)
		"neck":
			node.position = Vector3(0.0, 0.62, 0.0)
		"back":
			node.position = Vector3(0.0, 0.75, 0.38)
		_:
			node.position = Vector3(0.0, 0.62, 0.0)
	_body.add_child(node)
	_slots[slot] = node
	_slot_voxels[slot] = voxel
	_slot_opts[slot] = opts
	if slot == "hat":
		_hat = node
		_hat_spin = bool(opts.get("spin", false))
		# чубчик під капелюшком ховаємо (чубчик — у всіх, хто без іншої риси)
		if not feature in NO_TUFT_FEATURES:
			for p in _parts:
				p.visible = false
		_parts.append(_hat)
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
			_parts.erase(_hat)
			_hat = null
			_hat_spin = false
			for p in _parts:
				p.visible = true
		node.queue_free()
	_slots.erase(slot)
	_slot_voxels.erase(slot)
	_slot_opts.erase(slot)


## Ніжки й лапки — окремі коробки з шарніром угорі: махають на бігу, видно і ззаду.
func _build_limbs() -> void:
	var dark := color.darkened(0.22)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.13, 0.26, 0.0)
		_box(Vector3(0.17, 0.26, 0.19), dark, Vector3(0.0, -0.13, 0.0), leg)
		_body.add_child(leg)
		_legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.4, 0.52, 0.0)
		_box(Vector3(0.12, 0.26, 0.14), dark, Vector3(0.0, -0.12, 0.0), arm)
		arm.rotation.z = side * 0.15
		_body.add_child(arm)
		_arms.append(arm)


func _box(size: Vector3, c: Color, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := Mats.box(size, c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_face() -> void:
	_face = Node3D.new()
	_face.name = "Face"
	_body.add_child(_face)
	var eye_white := Color.WHITE
	var pupil := Color("#222831")
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.15, 0.93, FACE_Z)
		_face.add_child(eye)
		_box(Vector3(0.17, 0.2, 0.04), eye_white, Vector3.ZERO, eye)
		var p := _box(Vector3(0.09, 0.11, 0.03), pupil, Vector3(0.0, -0.01, -0.02), eye)
		_box(Vector3(0.03, 0.03, 0.01), Color.WHITE, Vector3(0.025, 0.03, -0.017), p)  # блик
		_eyes.append(eye)
		_pupils.append(p)
		_box(Vector3(0.1, 0.07, 0.02), Color("#FF8A80"), Vector3(side * 0.27, 0.78, FACE_Z), _face)
	_mouth = _box(Vector3(0.14, 0.035, 0.02), Color("#5D4037"), Vector3(0.0, 0.73, FACE_Z), _face)
	_eye_scale_y = 0.55 if feature == "sleepy" else 1.0
	for e in _eyes:
		e.scale.y = _eye_scale_y


func _build_feature() -> void:
	var light := color.lightened(0.3).to_html(false)
	var dark := color.darkened(0.25)
	match feature:
		"ears":
			for side in [-1.0, 1.0]:
				var ear := Node3D.new()
				ear.position = Vector3(side * 0.22, HEAD_TOP - 0.02, 0.0)
				ear.rotation.z = -side * 0.22
				var m := VoxelBuilder.instance("part_ear", {"o": color.to_html(false)})
				m.scale.x = side
				ear.add_child(m)
				_body.add_child(ear)
				_parts.append(ear)
		"tail":
			var tail := Node3D.new()
			tail.position = Vector3(0.0, 0.32, 0.36)
			var m := VoxelBuilder.instance("part_tail", {"o": color.to_html(false), "l": light})
			m.position.z = 0.3
			tail.add_child(m)
			_body.add_child(tail)
			_parts.append(tail)
		"antenna":
			var ant := Node3D.new()
			ant.position = Vector3(0.0, HEAD_TOP - 0.02, 0.0)
			_box(Vector3(0.05, 0.34, 0.05), dark, Vector3(0.0, 0.17, 0.0), ant)
			var bulb := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.09
			sph.height = 0.18
			bulb.mesh = sph
			var bm := StandardMaterial3D.new()
			bm.albedo_color = Color("#FFF176")
			bm.emission_enabled = true
			bm.emission = Color("#FFF176")
			bm.emission_energy_multiplier = 2.0
			bulb.material_override = bm
			bulb.position.y = 0.4
			ant.add_child(bulb)
			var glow := OmniLight3D.new()
			glow.light_color = Color("#FFF176")
			glow.light_energy = 0.6
			glow.omni_range = 1.5
			glow.position.y = 0.4
			ant.add_child(glow)
			_body.add_child(ant)
			_parts.append(ant)
		"stripes":
			for y in [0.7, 0.92, 1.1]:
				_box(Vector3(0.75, 0.07, 0.75), dark, Vector3(0.0, y, 0.0), _body)
		"sparkle":
			_sparkles = FX.sparkles(_body, 0.55, 14)
		"cloud", "sleepy":
			pass
		_:
			var tuft := Node3D.new()
			tuft.position = Vector3(0.0, HEAD_TOP - 0.02, -0.05)
			tuft.add_child(VoxelBuilder.instance("part_tuft", {"t": light}))
			_body.add_child(tuft)
			_parts.append(tuft)


func is_airborne() -> bool:
	return _y > 0.02 or flying


## Стрибок. scale < 1 — нижчий (підскок на хвилі). Повертає false, якщо стрибнути не можна.
func jump(k: float = 1.0) -> bool:
	if is_airborne() or tumbling or sitting:
		return false
	_vy = jump_velocity * k * jump_scale
	ducking = false
	_squash(Vector3(0.82, 1.28, 0.82), 0.12)
	_flap(1.0)
	return true


## Короткий підскок у режимі Стрибки.
func hop() -> void:
	if _y < 0.15:
		# у присіді крок нижчий — щоб пролізти під павутинкою
		_vy = HOP_VELOCITY * (0.7 if ducking else 1.0)
		_squash(Vector3(0.9, 1.15, 0.9), 0.1)
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
	FX.burst(self, Vector3(0, 0.7, 0), Color("#40C4FF"))
	var tw := create_tween()
	tw.tween_property(_shield, "scale", Vector3.ONE * 1.4, 0.12)
	tw.tween_callback(func():
		_shield_popping = false
		# якщо за цей час щит не підібрали знову — ховаємо
		if not shield_on:
			_shield.visible = false)


## Сісти («Ще раз!»): нахил тіла вперед, очі заплющені на 0,5 с, біг вимкнено.
func sit() -> void:
	if _tumble_tween:
		_tumble_tween.kill()
		_tumble_tween = null
	tumbling = false
	ducking = false
	sitting = true
	running = false
	_body.position.y = 0.0
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


## Смішне падіння: перекид клубком 0,8 с, зірочки не втрачаються.
func tumble() -> void:
	if tumbling:
		return
	tumbling = true
	ducking = false
	_set_eyes_closed(true)
	if _tumble_tween:
		_tumble_tween.kill()
	_tumble_tween = create_tween()
	_tumble_tween.tween_property(_body, "rotation:x", TAU, 0.8).from(0.0)
	_tumble_tween.parallel().tween_property(_body, "position:y", 0.5, 0.4).from(0.0)
	_tumble_tween.tween_property(_body, "position:y", 0.0, 0.3)
	_tumble_tween.finished.connect(_end_tumble)
	FX.dust(self, Vector3(0, 0.05, 0))


func _end_tumble() -> void:
	_body.rotation.x = 0.0
	_body.position.y = 0.0
	tumbling = false
	_set_eyes_closed(false)
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


## Привітання: махає лапкою, підморгує, підскакує (меню, поява в каруселі).
func wave_hello() -> void:
	if _arms.size() < 2:
		return
	var arm := _arms[1]
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(arm, "rotation:z", 2.6, 0.25).set_trans(Tween.TRANS_BACK)
	for i in range(3):
		tw.tween_property(arm, "rotation:x", 0.5, 0.14)
		tw.tween_property(arm, "rotation:x", -0.5, 0.14)
	tw.tween_property(arm, "rotation:x", 0.0, 0.1)
	tw.tween_property(arm, "rotation:z", 0.15, 0.3).set_trans(Tween.TRANS_SINE)
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


## Сірий «ще не відкритий» вигляд (карусель героїв).
func set_locked_look(locked: bool) -> void:
	if feature == "cloud":
		return
	if not locked:
		_mesh.material_override = null
		_face.visible = true
		return
	var m := VoxelBuilder.material()
	if m is ShaderMaterial:
		var d := (m as ShaderMaterial).duplicate() as ShaderMaterial
		d.set_shader_parameter("tint_strength", 0.7)
		d.set_shader_parameter("tint", Color("#9E9E9E"))
		_mesh.material_override = d
	_face.visible = false


## Габарит для перевірки зіткнень (світові координати; герой завжди в z = 0). На платформі — вище за землю.
func hit_box() -> AABB:
	var h := 0.5 if ducking else 1.1
	return AABB(Vector3(position.x - 0.28, ground_y + _y, -0.28), Vector3(0.56, h, 0.56))


# ---------- анімація ----------

func _squash(to: Vector3, dur: float) -> void:
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_body, "scale", to, dur)
	tw.tween_property(_body, "scale", Vector3.ONE, dur * 1.5).set_trans(Tween.TRANS_ELASTIC)


## Вуха/хвіст/чубчик підскакують.
func _flap(strength: float) -> void:
	for i in range(_parts.size()):
		var p := _parts[i]
		var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		# хвіст і антенка гойдаються по z/y у _process — їм махаємо по x, щоб не перетирати
		var axis := "rotation:x" if feature in ["tail", "antenna"] else "rotation:z"
		var side := -1.0 if i == 0 else 1.0
		var base := -side * 0.22 if feature == "ears" and p != _hat else 0.0
		tw.tween_property(p, axis, base + side * 0.6 * strength, 0.12)
		tw.tween_property(p, axis, base, 0.4).set_trans(Tween.TRANS_ELASTIC)
	# крильця/рюкзачок на спині махають разом
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
				_squash(Vector3(1.18, 0.82, 1.18), 0.09)
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
	# тінь лишається на землі (або подіумі) й меншає в польоті
	_shadow.position.y = -(position.y - ground_y) + 0.015
	var k := clampf((position.y - ground_y) / 2.5, 0.0, 1.0)
	_shadow.scale = Vector3(1.0 - k * 0.5, 1.0, 1.0 - k * 0.5)
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
	# присід: плавний перехід 20/с (тіло, ніжки, лапки)
	_duck_blend = lerpf(_duck_blend, 1.0 if ducking else 0.0, minf(1.0, delta * 20.0))
	var run_f := 11.0 * run_speed_factor   # частота бігу-боба
	# ніжки й лапки: біг — махають навхрест; політ — розкинуті; присід — зігнуті й розкинуті; спокій — трохи гойдаються
	if not tumbling:
		var swing := 0.0
		var arm_swing := 0.0
		if ducking:
			swing = 1.2
			arm_swing = 0.2
		elif running and not is_airborne():
			swing = sin(_t * run_f) * 0.9
			arm_swing = -swing * 0.8
		elif is_airborne():
			swing = 0.5
			arm_swing = -1.6
		else:
			swing = sin(_t * 1.5) * 0.06
			arm_swing = sin(_t * 1.5 + 1.0) * 0.1
		for i in range(_legs.size()):
			var s := 1.0 if i == 0 else -1.0
			_legs[i].rotation.x = lerpf(_legs[i].rotation.x, swing * s if running and not ducking else swing, minf(1.0, delta * 18.0))
		for i in range(_arms.size()):
			var s := 1.0 if i == 0 else -1.0
			_arms[i].rotation.x = lerpf(_arms[i].rotation.x, arm_swing * s if running and not is_airborne() and not ducking else arm_swing, minf(1.0, delta * 14.0))
			# у присіді лапки розкинуті вбоки (±1.3); поза присідом не чіпаємо z — ним махає wave_hello
			if _duck_blend > 0.01:
				var side := -1.0 if i == 0 else 1.0
				_arms[i].rotation.z = side * lerpf(0.15, 1.3, _duck_blend)
	# шарфик гойдається
	var neck = _slots.get("neck")
	if neck != null and is_instance_valid(neck):
		neck.rotation.z = sin(_t * 3.0) * 0.12
		neck.rotation.x = sin(_t * 2.3 + 1.0) * 0.06
	if _hat_spin and is_instance_valid(_hat):
		_hat.rotation.y += delta * 7.0
	# хвіст махає, антенка гойдається
	if feature == "tail" and _parts.size() > 0 and not tumbling:
		_parts[0].rotation.y = sin(_t * 6.0) * 0.5
	elif feature == "antenna" and _parts.size() > 0:
		_parts[0].rotation.z = sin(_t * 3.0) * 0.18
	# біг-боб / дихання / присід — на тілі, щоб не ламати перекид; сидить — тіло не чіпаємо
	if not tumbling and not sitting:
		var target_scale := Vector3.ONE
		var body_y := 0.0
		var lean_x := 0.0
		var rate := 14.0
		if ducking:
			# присід помітний: широкий і низький, трохи осідає
			target_scale = Vector3(1.35, 0.42, 1.35)
			body_y = -0.05
			rate = 20.0
		elif running and not is_airborne():
			body_y = absf(sin(_t * run_f)) * 0.06 * run_speed_factor
			lean_x = -0.08
			target_scale = Vector3(1.0, 1.0 + sin(_t * run_f * 2.0) * 0.03, 1.0)
		else:
			var breath := sin(_t * 4.0) * 0.025
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


func _blink() -> void:
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for e in _eyes:
		tw.parallel().tween_property(e, "scale:y", 0.08, 0.06)
	tw.chain()
	for e in _eyes:
		tw.parallel().tween_property(e, "scale:y", _eye_scale_y, 0.08)
