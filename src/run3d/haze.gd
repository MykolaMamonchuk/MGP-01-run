class_name Haze
extends Node3D

## Туман завісами — заміна `Environment.fog` для слабкого пристрою.
##
## НАВІЩО. Заміряно на Redmi 8A двома замороженими точками (контролі 0,04% і 0,6%): туман
## коштує 17,0 мс на 60 м і 14,4 мс на 180 м — чверть кадру. При цьому ЖОДНА його
## властивість не важить: повітряна перспектива 0,4 -> 0 і крива глибини pow -> лінійно
## дають нуль. Отже ціна — сам ШЛЯХ туману в піксельному шейдері КОЖНОГО матеріалу, а не
## те, що він рахує. Налаштуванням це не знімається, тільки заміною.
##
## ЧОМУ САМЕ ЗАВІСИ. Тим самим методом перевірено протилежне: перекриття тут майже
## безкоштовне — сім зайвих ПОВНОЕКРАННИХ прозорих шарів коштували разом 1,5 одиниці.
## Тобто намалювати екран ще кілька разів прозорим дешево, а порахувати туман на кожен
## піксель — дорого. Завіси купують вигляд саме тією валютою, якої в нас надлишок.
##
## ЯК ЦЕ ПРАЦЮЄ. N прямокутників кольору неба висять перед камерою на відстанях d_i, не
## пишуть глибину, але ПРОХОДЯТЬ глибинний тест. Тому завіса фарбує лише ті пікселі, що
## далі за неї, — рівно те, що робить туман. Усе ближче за d_i вона не чіпає.
##
## МАТЕМАТИКА АЛЬФИ. Наш туман лінійний (`fog_depth_curve = 1.0`): від `begin` до `far`
## колір неба набирається рівномірно. Хочемо, щоб після i завіс сумарна непрозорість була
## рівно i/N. Прозорість перемножується, тож (1 - a_i) = (N-i) / (N-i+1), тобто
##
##     a_i = 1 / (N - i + 1)
##
## Остання завіса виходить суцільною — і це правильно: на `far` туман і має бути суцільним.
##
## ЧОГО ЦЕ НЕ ВМІЄ. Сходинок N штук замість гладкого схилу; на малому N видно смуги.
## І завіси не фарбують саме небо — але в нас `fog_sky_affect = 0`, тобто туман його теж
## не фарбує.

## Скільки завіс. Вісім дають сходинку 12,5% непрозорості — на око вже не смуга, а градієнт;
## менше видно, більше нема сенсу (ціна росте, різниця ні).
const CURTAINS := 8

## Запас на краях: камера трясеться (CameraRig.intensity), і завіса має лишатись більшою
## за екран у будь-якій фазі тряски, інакше з кутів визирне нефарбоване.
const MARGIN := 1.35

var _cam: Camera3D = null
var _quads: Array[MeshInstance3D] = []
var _mats: Array[StandardMaterial3D] = []
var _near_m := 8.0
var _far_m := 40.0
var _last_fov := -1.0
var _last_aspect := -1.0


func _ready() -> void:
	for i in range(CURTAINS):
		var mi := MeshInstance3D.new()
		mi.mesh = QuadMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Глибину НЕ пишемо: завіса не має ховати те, що за нею, вона має це фарбувати.
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
		m.cull_mode = BaseMaterial3D.CULL_BACK
		m.disable_receive_shadows = true
		# Сортування прозорих у Godot — за відстанню, тобто дальня завіса малюється першою.
		# Саме такий порядок і потрібен для накладання альфи.
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_quads.append(mi)
		_mats.append(m)


## Камера, під якою висять завіси. Вузол лишається дитиною Run3D, а положення бере з камери:
## так його не треба перевішувати, коли CameraRig міняє пресет.
func setup(cam: Camera3D) -> void:
	_cam = cam


## Межі й колір — ті самі, що в тумана, який ми замінюємо.
func configure(near_m: float, far_m: float, color: Color) -> void:
	_near_m = near_m
	_far_m = maxf(far_m, near_m + 1.0)
	for i in range(CURTAINS):
		var a := 1.0 / float(CURTAINS - i)
		_mats[i].albedo_color = Color(color.r, color.g, color.b, a)
	_last_fov = -1.0   # змусити перерахунок розмірів


func set_enabled(on: bool) -> void:
	for q in _quads:
		q.visible = on


func is_enabled() -> bool:
	return not _quads.is_empty() and _quads[0].visible


func _process(_dt: float) -> void:
	if _cam == null or not is_enabled():
		return
	var vp := get_viewport()
	if vp == null:
		return
	var size := vp.get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var fov := _cam.fov
	global_transform = _cam.global_transform
	# Розміри залежать лише від кута огляду й пропорцій екрана, тож перераховуємо їх не
	# щокадру, а коли вони справді змінились (пресет камери, поворот екрана).
	if is_equal_approx(fov, _last_fov) and is_equal_approx(aspect, _last_aspect):
		return
	_last_fov = fov
	_last_aspect = aspect
	var half := tan(deg_to_rad(fov) * 0.5)
	var step := (_far_m - _near_m) / float(CURTAINS)
	for i in range(CURTAINS):
		var d := _near_m + step * float(i + 1)
		var h := 2.0 * d * half * MARGIN
		(_quads[i].mesh as QuadMesh).size = Vector2(h * aspect, h)
		_quads[i].position = Vector3(0, 0, -d)
