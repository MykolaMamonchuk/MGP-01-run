## Сорока-антагоніст (GDD v1.4 §3, реф. §3 «антагоніст попереду»).
## Летить попереду героя на 8–12 клітинок, висота 2,2 м, петляє між доріжками (синус),
## погойдується й «махає крилами» (сквош усього тіла — без окремих кісток).
##
## Поведінки:
##   patrol()          — типова, просто летить попереду;
##   warn_drop(lane)   — 0,8 с росте темна тінь на цільовій доріжці + «кря», тоді сигнал box_ready(lane);
##   steal()           — пікірує до героя, торба росте, сигнал stole, відлітає вгору-ліворуч, за 4 с — назад у патруль.
##
## Скін світу: world["antagonist"] — "magpie" | "pigeon" (Місто) | "comet" (Хмаринки).
## Очі круглі, білі — птах смішний, не страшний.
class_name Magpie3D
extends Node3D

## Тінь виросла — Run3D може ставити X-ящик на цю доріжку.
signal box_ready(lane: int)
## Сорока схопила злитки — Run3D списує половину.
signal stole()

enum Phase { PATROL, WARN, DIVE, AWAY }

const AHEAD_MIN := 8.0
const AHEAD_MAX := 12.0
const FLY_Y := 2.2
## Період петляння між доріжками, с.
const WEAVE_SEC := 3.6
## Скільки триває попередження перед ящиком.
const WARN_SEC := 0.8
## Ящик падає за стільки клітинок попереду героя.
const DROP_AHEAD := 6.0
## Попередження — не пляма «тут», а смуга «ця доріжка»: від z -2 до z -8 (довжина 6 клітинок).
const WARN_STRIP_LEN := 6.0
const WARN_STRIP_Z := -5.0
## Скільки сорока «відпочиває» після крадіжки.
const STEAL_REST_SEC := 4.0
## Скіни за назвою антагоніста світу.
const SKINS := {"magpie": "magpie", "pigeon": "pigeon", "comet": "comet_face"}

var hero: Hero3D
var lanes := 3
## Дропи ящиків дозволені (з 3-го рівня) — вмикає Run3D.
var drops_enabled := false

var phase: int = Phase.PATROL
var _t := 0.0
var _ahead := 10.0
var _body: Node3D
var _sack: Node3D
var _shadow: MeshInstance3D
var _target_lane := 0
var _tw: Tween


func _ready() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	set_skin("magpie")


## Птах світу: "magpie" | "pigeon" | "comet".
func set_skin(kind: String) -> void:
	for c in _body.get_children():
		c.queue_free()
	_sack = null
	var voxel := String(SKINS.get(kind, SKINS["magpie"]))
	_body.add_child(VoxelBuilder.instance(voxel))
	# торбинка зі злитками — під черевцем, майже непомітна, поки не вкрала
	_sack = Node3D.new()
	_sack.name = "Sack"
	_sack.position = Vector3(0.0, -0.16, 0.1)
	_sack.scale = Vector3.ONE * 0.6
	_sack.add_child(VoxelBuilder.instance("sack_gold"))
	_body.add_child(_sack)


func max_lane() -> int:
	return (lanes - 1) / 2


## Ширина петляння в метрах (не ширше за дорогу).
func _weave_x() -> float:
	return float(max_lane()) * Hero3D.LANE_W


func patrol() -> void:
	phase = Phase.PATROL
	_ahead = randf_range(AHEAD_MIN, AHEAD_MAX)
	visible = true


## Попередження про ящик: тінь росте на доріжці lane, тоді box_ready(lane).
func warn_drop(lane: int) -> void:
	if phase != Phase.PATROL:
		return
	phase = Phase.WARN
	_target_lane = clampi(lane, -max_lane(), max_lane())
	_show_shadow(_target_lane)
	AudioMgr.voice("kraak")
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_interval(WARN_SEC)
	_tw.tween_callback(_finish_warn)


func _finish_warn() -> void:
	_hide_shadow()
	if phase == Phase.WARN:
		phase = Phase.PATROL
		box_ready.emit(_target_lane)


## Пікірує до героя, забирає злитки й відлітає вгору-ліворуч; через 4 с — знову патруль.
func steal() -> void:
	if phase == Phase.DIVE or phase == Phase.AWAY:
		return
	_hide_shadow()
	phase = Phase.DIVE
	if _tw:
		_tw.kill()
	var hero_x := hero.position.x if is_instance_valid(hero) else 0.0
	_tw = create_tween()
	_tw.tween_property(self, "position", Vector3(hero_x, 1.2, -0.9), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.tween_callback(_grab)
	_tw.tween_property(self, "position", Vector3(hero_x - 3.2, 4.2, -7.0), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_interval(maxf(0.1, STEAL_REST_SEC - 1.45))
	_tw.tween_callback(patrol)


func _grab() -> void:
	phase = Phase.AWAY
	AudioMgr.voice("kraak")
	AudioMgr.sfx("star")
	if is_instance_valid(_sack):
		var tw := create_tween()
		tw.tween_property(_sack, "scale", Vector3.ONE * 1.5, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.2)
		tw.tween_property(_sack, "scale", Vector3.ONE * 0.6, 0.4)
	FX.burst(self, Vector3.ZERO, Palette.GOLD_BRIGHT)
	stole.emit()


# ---------- тінь-попередження ----------

## Попередження читається як «стережися ЦІЄЇ доріжки», а не «цієї плями»: ящик зʼявляється аж на
## лінії спавну (Spawner3D.SPAWN_Z) і лише потім наїжджає. Тому замість круглої тіні під точкою
## падіння кладемо темну напівпрозору смугу на всю доріжку (z −2…−8), яка пульсує прозорістю.
func _show_shadow(lane: int) -> void:
	_hide_shadow()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(Hero3D.LANE_W * 0.8, 0.02, WARN_STRIP_LEN)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Palette.SHADOW
	mi.material_override = m
	# смуга живе у світі, а не на птаху: вона лежить на дорозі попереду героя
	mi.position = Vector3(float(lane) * Hero3D.LANE_W, 0.04, WARN_STRIP_Z)
	mi.scale = Vector3(0.2, 1.0, 1.0)
	mi.top_level = true
	add_child(mi)
	_shadow = mi
	# спершу смуга «розкривається» вшир, далі — пульс прозорості (твіни на самій смузі: гинуть із нею)
	var grow := mi.create_tween()
	grow.tween_property(mi, "scale", Vector3.ONE, WARN_SEC * 0.4).set_trans(Tween.TRANS_SINE)
	var a := Palette.SHADOW.a
	var pulse := mi.create_tween()
	pulse.set_loops()
	pulse.tween_property(m, "albedo_color:a", a * 0.4, 0.22).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(m, "albedo_color:a", a, 0.22).set_trans(Tween.TRANS_SINE)


func _hide_shadow() -> void:
	if is_instance_valid(_shadow):
		_shadow.queue_free()
	_shadow = null


# ---------- цикл ----------

func _process(delta: float) -> void:
	_t += delta
	# помах крил і погойдування — сквош усього тіла, без окремих кісток
	var flap := sin(_t * 9.0)
	_body.scale = Vector3(1.0 + flap * 0.14, 1.0 - flap * 0.1, 1.0)
	_body.position.y = sin(_t * 3.0) * 0.07
	if phase != Phase.PATROL and phase != Phase.WARN:
		return
	# петляє між доріжками попереду героя
	var x := sin(_t * TAU / WEAVE_SEC) * _weave_x()
	position.x = lerpf(position.x, x, minf(1.0, delta * 3.0))
	position.y = lerpf(position.y, FLY_Y, minf(1.0, delta * 3.0))
	position.z = lerpf(position.z, -_ahead, minf(1.0, delta * 2.0))
	rotation.y = clampf((x - position.x) * 0.6, -0.5, 0.5)
