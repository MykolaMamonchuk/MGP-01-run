## Камера: пресети зі світу (data/worlds/*.json → "camera"), плавний переїзд між ними на станції.
class_name CameraRig
extends Node3D

@onready var cam: Camera3D = $Camera3D

## Пресети екранів (не світів): меню — близько й трохи збоку; герої — фронтально на ряд подіумів.
const PRESET_MENU := {"pos": [1.7, 1.5, 3.0], "look": [0.0, 0.75, 0.0], "fov": 55, "ortho": false}
const PRESET_HEROES := {"pos": [0.0, 1.7, 1.4], "look": [0.0, 0.7, -2.3], "fov": 58, "ortho": false}

## Тілт-шифт (GDD v1.5 §3): далекий план і те, що прямо під носом, — м'які; герой різкий.
## У CameraAttributesPractical сила розмиття одна на обидва плани, тож беремо більшу (далеку).
const DOF_FAR_DISTANCE := 14.0
const DOF_FAR_TRANSITION := 8.0
const DOF_NEAR_DISTANCE := 2.2
const DOF_NEAR_TRANSITION := 1.2
const DOF_AMOUNT := 0.06

## ЖИВА КАМЕРА під час бігу. Досі камера стояла нерухомо, і весь рух був у самому герої:
## він стрибав убік, а кадр лишався як прибитий. Через це зміна доріжки читалась як
## «персонаж посунувся», а не як «ми повернули».
##
## Три речі роблять рух відчутним, і всі три беруться з ОДНОГО сигналу — наскільки герой
## ще не доїхав до своєї доріжки (`x_target - x`). Він сам собою спалахує на початку
## маневру й згасає наприкінці, тобто вже має потрібну форму, і окремих таймерів не треба.
##   - крен: кадр кладеться в поворот, як велосипедист;
##   - запізнення: камера йде за героєм не миттєво, тож він на мить зміщується в кадрі;
##   - довертання: ніс камери трохи йде в бік маневру.
## Спотикання й падіння додають ривок полем зору — кадр «зітхає», а потім вирівнюється.
##
## Усе це живе на САМОМУ РИГУ, а не на камері: пресет світу сидить у трансформі камери й
## переїжджає твінами, тож писати туди ще й покадровий рух означало б із ними битися.
const LEAN_ROLL := 0.13           ## максимальний крен у поворот, рад
const LEAN_YAW := 0.05            ## максимальне довертання носа, рад
const FOLLOW_LAG := 0.55          ## яку частку зсуву героя камера НЕ повторює одразу
const FOLLOW_EASE := 7.0          ## як швидко наздоганяє, частка за секунду
const RISE_LAG := 0.22            ## наскільки камера провисає під стрибком героя
const FOV_PUNCH := 5.0            ## ривок поля зору на спотиканні, градуси
const FOV_EASE := 4.5

var _tw: Tween
var _shake_tw: Tween
var _lean := 0.0
var _follow_x := 0.0
var _rise := 0.0
var _fov_extra := 0.0
var _base_fov := 0.0


## Крен від «недоїханого» зсуву. Пропорція, а не поріг: маленький доворот дає маленький
## нахил, тож камера не смикається на дрібницях. Знак такий, щоб кадр лягав У бік повороту.
static func lean_for(pull: float, lane_w: float) -> float:
	return -clampf(pull / maxf(lane_w, 0.001), -1.0, 1.0) * LEAN_ROLL


## Куди камера стоїть по x: не там, де герой, а позаду нього на частку зсуву. Саме через це
## герой на мить «випереджає» кадр, і маневр видно, а не лише відчувається.
static func follow_for(hero_x: float, pull: float) -> float:
	return hero_x + pull * FOLLOW_LAG


## Покадровий рух камери. delta — крок, hero_x — де герой зараз, pull — скільки йому ще
## лишилось до своєї доріжки, vy — вертикальна швидкість, lane_w — ширина доріжки.
func drive(delta: float, hero_x: float, pull: float, vy: float, lane_w: float) -> void:
	if _tw != null and _tw.is_valid():
		return               # пресет саме переїжджає — не заважаємо твінам
	var k := clampf(delta * FOLLOW_EASE, 0.0, 1.0)
	_lean = lerpf(_lean, lean_for(pull, lane_w), k)
	_follow_x = lerpf(_follow_x, follow_for(hero_x, pull), k)
	_rise = lerpf(_rise, -clampf(vy, 0.0, 6.0) * RISE_LAG, k)
	position.x = _follow_x
	position.y = _rise
	rotation.z = _lean
	rotation.y = _lean * (LEAN_YAW / LEAN_ROLL)
	if _fov_extra != 0.0:
		_fov_extra = move_toward(_fov_extra, 0.0, delta * FOV_EASE)
		if cam.projection == Camera3D.PROJECTION_PERSPECTIVE and _base_fov > 0.0:
			cam.fov = _base_fov + _fov_extra


## Ривок поля зору: кадр на мить «зітхає». Чіпляється до спотикання й падіння.
func punch(strength: float = 1.0) -> void:
	if _base_fov <= 0.0:
		_base_fov = cam.fov
	_fov_extra = FOV_PUNCH * clampf(strength, 0.0, 2.0)


## Повернути камеру в спокій (кінець забігу, меню): інакше крен лишився б висіти.
func settle() -> void:
	_lean = 0.0
	_follow_x = 0.0
	_rise = 0.0
	_fov_extra = 0.0
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	if _base_fov > 0.0 and cam.projection == Camera3D.PROJECTION_PERSPECTIVE:
		cam.fov = _base_fov


## Увімкнути/вимкнути розмиття планів (налаштування «fx_blur»).
func set_dof(on: bool) -> void:
	if not on:
		cam.attributes = null
		return
	var a := CameraAttributesPractical.new()
	a.dof_blur_far_enabled = true
	a.dof_blur_far_distance = DOF_FAR_DISTANCE
	a.dof_blur_far_transition = DOF_FAR_TRANSITION
	a.dof_blur_near_enabled = true
	a.dof_blur_near_distance = DOF_NEAR_DISTANCE
	a.dof_blur_near_transition = DOF_NEAR_TRANSITION
	a.dof_blur_amount = DOF_AMOUNT
	cam.attributes = a


## Тряска (падіння героя): h/v_offset камери, без зміни трансформи.
func shake(strength: float = 0.12) -> void:
	if _shake_tw:
		_shake_tw.kill()
	_shake_tw = create_tween()
	for i in range(5):
		var k := strength * (1.0 - float(i) / 5.0)
		_shake_tw.tween_property(cam, "h_offset", randf_range(-k, k), 0.04)
		_shake_tw.parallel().tween_property(cam, "v_offset", randf_range(-k, k), 0.04)
	_shake_tw.tween_property(cam, "h_offset", 0.0, 0.05)
	_shake_tw.parallel().tween_property(cam, "v_offset", 0.0, 0.05)


func apply(preset: Dictionary, duration: float = 0.0) -> void:
	# запасний пресет — той самий ракурс 3/4 зверху-ззаду, що й у світах (GDD v1.5 §3: герой ≈ 1/6 висоти екрана)
	var p: Array = preset.get("pos", [0.0, 3.8, 4.6])
	var l: Array = preset.get("look", [0.0, 0.5, -5.0])
	var pos := Vector3(float(p[0]), float(p[1]), float(p[2]))
	var look := Vector3(float(l[0]), float(l[1]), float(l[2]))
	var ortho := bool(preset.get("ortho", false))
	if _tw:
		_tw.kill()
	_gen += 1
	if duration <= 0.0:
		cam.position = pos
		cam.look_at_from_position(pos, look, Vector3.UP)
		_set_projection(ortho, preset)
		return
	# проекцію міняємо в середині переїзду — стрибок ховається за рухом
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(cam, "position", pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var start_basis := cam.global_transform.basis
	var target := Transform3D().looking_at(look - pos, Vector3.UP).basis
	_tw.tween_method(func(t: float): cam.basis = start_basis.slerp(target, t), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_timer(duration * 0.5).timeout.connect(_set_projection_if_current.bind(ortho, preset, _gen))


var _gen := 0

## Старий таймер від попереднього apply() не має перебити новий пресет.
func _set_projection_if_current(ortho: bool, preset: Dictionary, gen: int) -> void:
	if gen == _gen:
		_set_projection(ortho, preset)


func _set_projection(ortho: bool, preset: Dictionary) -> void:
	if ortho:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = float(preset.get("size", 9.0))
	else:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = float(preset.get("fov", 62.0))
		_base_fov = cam.fov          # ривок поля зору рахується від пресета, а не від себе
