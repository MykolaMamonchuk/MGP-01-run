## Гуска, що ПАСЕТЬСЯ на узбіччі: жива декорація, а не перешкода.
##
## Не Obstacle3D навмисно: Spawner3D.check перевіряє зіткнення лише з перешкодами, тож ця гуска
## не може збити героя ніколи. Їде разом зі світом і зникає за спиною сама, як усе в спавнері.
##
## Поведінка — «телеграф» на відстань (ідея замовника 26.09):
##   далеко  → пасеться: клює траву, стоїть, поволі повертається;
##   ~10 м   → піднімає голову й повертається до героя;
##   ~4 м    → лякається: махає крилами й відбігає від дороги (не далі каналу).
## Зграя (кілька гусок): першою лякається ведуча, решта — з невеликою затримкою, ніби від неї.
class_name GooseGrazer3D
extends Node3D

const ALERT_M := 10.0
const SCARE_M := 4.0
## Наскільки далеко від дороги гуска може відбігти, м від краю дороги. Канал Лужка — з +1,5,
## поручень і настил містка — з +1,3; тулуб гуски — ~0,2 у кожен бік.
const FLEE_MAX := 1.1

## Спільний стан зграї: коли злякалась ведуча (секунди від її переляку йдуть усім).
class Flock:
	extends RefCounted
	var scared := false


var flock: Flock
var leader := false
## Затримка реакції не-ведучої, с.
var delay := 0.0
## Край дороги, м (x > 0); гуска стоїть по той бік, куди вказує знак свого x.
var road_edge := 1.6

var _rig: GooseRig
var _body: Node3D
var _scale := 1.0
var _state := ""
var _t := 0.0
var _state_t := 0.0
var _scared_t := -1.0
var _yaw_goal := 0.0
var _next_idle := 0.0
var _posed := false
## Свій лічильник моделей, а не Obstacle3D._rig_counter: інакше гуски на узбіччі зсували б, яка
## модель дістанеться гускам-перешкодам.
static var _counter := 0
## Далі за це — поза скелета не рахується (рецензія 26.09: до 9 гусок у кадрі).
const POSE_FAR_M := 22.0


func setup(prop_name: String, rng: RandomNumberGenerator) -> bool:
	var n := PropLibrary.variants(prop_name)
	if n <= 0:
		return false
	var v := _counter % n
	var scene := PropLibrary.scene(String(PropLibrary._entry(prop_name, v).get("path", "")))
	if scene == null:
		return false
	var model := scene.instantiate() as Node3D
	var rig := GooseRig.new()
	if model == null or not rig.build(model):
		if model != null:
			model.free()
		return false
	_counter += 1
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		PropLibrary._drop_normal_maps((mi as MeshInstance3D).mesh)
	_body = Node3D.new()
	_body.add_child(model)
	_scale = float(PropLibrary.tweak(prop_name, v)["scale"])
	_body.scale = Vector3.ONE * _scale
	add_child(_body)
	_rig = rig
	_t = rng.randf() * 10.0
	_yaw_goal = rng.randf_range(-PI, PI)
	_body.rotation.y = _yaw_goal
	_next_idle = rng.randf_range(1.5, 4.0)
	_set_state("peck" if rng.randf() < 0.6 else "stand")
	return true


func _set_state(s: String) -> void:
	if s == _state:
		return
	_state = s
	_state_t = 0.0
	_rig.state = s


func tick(delta: float) -> void:
	if _rig == null:
		return
	_t += delta
	_state_t += delta
	# Дорога розширилась (рівень 4: 3 → 5 доріжок) — гуска відступає разом із краєм, а не
	# лишається посеред нової доріжки.
	var sp := get_parent() as Spawner3D
	if sp != null:
		var e := float(sp.lanes) * 0.5 * Hero3D.LANE_W + 0.1
		if absf(e - road_edge) > 0.01:
			position.x += signf(position.x) * (e - road_edge)
			road_edge = e
	var ahead := -position.z
	var scared := false
	if leader and flock != null and ahead < SCARE_M:
		flock.scared = true
	if flock != null and flock.scared:
		if _scared_t < 0.0:
			_scared_t = 0.0
		else:
			_scared_t += delta
		scared = _scared_t >= (0.0 if leader else delay)
	elif flock == null and ahead < SCARE_M:
		scared = true
	if scared:
		_set_state("flee")
		# Геть від дороги: дзьобом назовні, дріботить, але не в канал.
		var out := signf(position.x)
		_yaw_goal = PI * 0.5 * out
		var lim := road_edge + FLEE_MAX
		if absf(position.x) < lim:
			position.x += out * 1.4 * delta
	elif ahead < ALERT_M and ahead > 0.0:
		_set_state("alert")
		# До героя: він у +Z, а модель дивиться в +Z — тобто поворот до нуля.
		_yaw_goal = 0.0
	else:
		_next_idle -= delta
		if _next_idle <= 0.0:
			_next_idle = 1.5 + fmod(_t * 7.3, 2.5)
			_set_state("stand" if _state == "peck" else "peck")
			_yaw_goal += (fmod(_t * 3.1, 1.6) - 0.8)
	_body.rotation.y = lerp_angle(_body.rotation.y, _yaw_goal, clampf(delta * 5.0, 0.0, 1.0))
	# Далека гуска — кілька пікселів: позу скелета не перераховуємо, стоїть як стояла.
	if ahead > POSE_FAR_M and _posed:
		return
	_posed = true
	var lift := _rig.pose(_state_t)
	_body.position.y = lift * _scale
