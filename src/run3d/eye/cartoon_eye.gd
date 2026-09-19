## ОДНЕ мультяшне око — спільна сцена для всіх звірят. Замість п'яти куль, які Hero3D ліпив
## кодом, тут справжня сцена з іменованими частинами й експортами: її видно в Інспекторі,
## можна крутити мишею й робити пресети під різні морди (див. eyes/fox_eye.tscn тощо).
##
## CartoonEye
## ├── EyeBall        — білок
## ├── Eyelid         — верхня повіка (лише якщо eyelid_cover > 0 — не в усіх пресетів)
## └── IrisPivot      — рухається ЦІЛКОМ, коли око кудись дивиться
##     ├── IrisRim    — тонкий темний обідок під райдужкою (не окремий параметр, частка Iris)
##     ├── Iris
##     ├── Pupil
##     ├── HighlightBig
##     └── HighlightSmall
##
## Чому саме IrisPivot, а не зсув кожної деталі окремо: райдужка, зіниця й блики мусять їхати
## разом і зберігати взаємне розташування — інакше при погляді вбік блик «відклеюється» від
## зіниці. Пересуваємо один вузол — решта їде за ним.
##
## Розміри — у координатах ОБЛИЧЧЯ Hero3D (той самий масштаб, що й решта рис). @tool тут
## безпечний: сцена тягне лише Mats і Palette, обидва — звичайні класи, не автозавантаження.
##
## ВАЖЛИВО про редагування: частини — обчислені, їх щоразу ліпить _rebuild() з експортів вище.
## Вони свідомо НЕ належать сцені (owner не ставимо), тож і не зберігаються в .tscn: інакше
## редактор запікав би EyeBall у пресет, а при запуску _rebuild() зносив би його разом із
## правкою — «в редакторі одне, у грі інше». Тому крутити око треба ЛИШЕ через експорти в
## Інспекторі (або в hero_lab), а не тягаючи вузли в дереві сцени.
@tool
class_name CartoonEye
extends Node3D

## Півосі білка (ширина, висота). Типове — історичний розмір воксельного ока.
@export var eye_scale := Vector2(0.105, 0.185): set = _set_eye_scale
## Райдужка як частка білка. 1.0 — майже весь білок (на великому оці читається темною плямою).
@export_range(0.1, 1.0, 0.01) var iris_scale := 0.84: set = _set_iris_scale
## Зіниця як частка РАЙДУЖКИ.
@export_range(0.1, 1.0, 0.01) var pupil_scale := 0.85: set = _set_pupil_scale
## Постійний зсув райдужки в межах білка (частки півосей): «косинка» чи погляд убік за замовчуванням.
@export var iris_offset := Vector2.ZERO: set = _set_iris_offset
## Нахил усього ока навколо погляду, градуси: мордам з розкосими очима (лис) — невеликий кут.
@export_range(-45.0, 45.0, 0.5) var eye_rotation := 0.0: set = _set_eye_rotation
## Великий блік — угорі ліворуч (з боку глядача), малий — унизу праворуч: так око читається
## живим навіть на маленькому екрані. Множник розміру обох.
@export_range(0.2, 3.0, 0.05) var highlight_scale := 1.0: set = _set_highlight_scale
## Наскільки далеко зіниця може поїхати за поглядом (частки півосей білка).
@export_range(0.0, 1.0, 0.01) var max_look_offset := 0.35
## Опуклість білка — його глибина як частка ширини. Менше = око сидить пласко в морді
## (лису так краще), більше = кулька, що стирчить.
@export_range(0.05, 1.0, 0.005) var ball_depth := BALL_DEPTH: set = _set_ball_depth
## Наскільки швидко білок «наздоганяє» СПРАВЖНІЙ НАХИЛ батька (Гц) — див. _process нижче.
## ЦЕ ЛИШЕ ПРО ОБЕРТ, не про позицію: перша спроба згладжувала світову ПОЗИЦІЮ білка й
## зламала біг/зміну смуги/стрибок (вони теж «позиція», фільтр гасив і їх — білок відставав
## від морди на кожному такому русі). Тут фільтр бачить лише те, НАСКІЛЬКИ ПОВЕРНУВСЯ батько
## (кватерніон), а сам перенос (де він зараз у світі) іде БЕЗ фільтра — тому звичайний рух
## героя білок не чіпає, а дрібний швидкий кивок голови (кілька Гц) — гасить. Нижче за
## частоту кроку (RUN/SPRINT_CADENCE_HZ, 2,2–3 Гц), інакше майже не фільтрує.
@export_range(0.2, 10.0, 0.1) var ball_stabilize_hz := 2.0
## Наскільки повіка накриває білок згори (частка половини висоти ока). 0 — повіки нема
## (типово: не всі звірята її мали в референсах). Дає той самий «сонний»/милий погляд, що
## й прижмурені очі, але як СТАЛА форма ока, а не тимчасовий вираз (див. _happy()).
@export_range(0.0, 0.6, 0.01) var eyelid_cover := 0.0: set = _set_eyelid_cover
## Колір повіки — типово шерсть героя (Hero3D виставляє її під час побудови обличчя), щоб
## повіка читалась як складка шкіри, а не чужорідна пляма.
@export var eyelid_color := Palette.H_CREAM.darkened(0.12): set = _set_eyelid_color

const BASE_SCENE := "res://src/run3d/eye/cartoon_eye.tscn"
const RIM_WIDEN := 1.12          ## обідок трохи більший за райдужку — звідси й «тонке кільце»
const BALL_DEPTH := 0.48         ## типова глибина білка як частка ширини (див. ball_depth)
const LAYER_DEPTH := 0.34        ## глибина накладок (райдужка й далі) — частка глибини білка
## На скільки перед білком стирчить кожен шар. Рахуємо саме від ПЕРЕДНЬОЇ поверхні, а не від
## центру: коли око більшає, центр лишається на місці, а поверхня їде вперед — і накладки,
## поставлені за центром, просто тонули б усередині білка.
const LIFT_RIM := 0.002
const LIFT_IRIS := 0.004
const LIFT_PUPIL := 0.007
const LIFT_HI_BIG := 0.011
const LIFT_HI_SMALL := 0.010
const LIFT_EYELID := 0.014      ## повіка стирчить перед усім іншим — вона НАЙБЛИЖЧА до глядача

var _ball: MeshInstance3D
var _pivot: Node3D
var _rim: MeshInstance3D
var _iris: MeshInstance3D
var _pupil: MeshInstance3D
var _hi_big: MeshInstance3D
var _hi_small: MeshInstance3D
var _eyelid: MeshInstance3D
var _look := Vector2.ZERO

## Згладжений НАХИЛ (лише поворот, без позиції) батька ока — див. _process().
var _smooth_basis := Basis.IDENTITY
var _smooth_ready := false


func _ready() -> void:
	_rebuild()


## Стабілізація білка. Батько ока (Face) хитається разом із головою — кивок на бігу,
## стрибок, будь-що. Розкладаємо це на ПЕРЕНОС (де зараз батько в світі — не фільтруємо
## ВЗАГАЛІ, інакше звичайний рух героя «відстає» від морди, як було першого разу) і НАХИЛ
## (як батько повернутий — саме тут живе дрібний швидкий кивок голови). Згладжуємо лише
## нахил (кватерніон), і ставимо білок туди, де він був би, якби батько повернувся на цей,
## ЗГЛАДЖЕНИЙ кут — а не на справжній. IrisPivot (дитина CartoonEye) цього не відчуває
## взагалі: вона й далі йде за РЕАЛЬНИМ, поточним нахилом батька, як завжди.
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _ball == null or not is_instance_valid(_ball):
		return
	var parent_3d := get_parent() as Node3D
	if parent_3d == null:
		return
	# get_rotation_quaternion() вимагає ЧИСТИЙ поворот — а в рига (та й у сквоша тіла)
	# батько майже завжди ще й НЕРІВНОМІРНО масштабований (Anchor_face * _face_scale упереміш
	# із кістковим масштабом моделі). orthonormalized() знімає масштаб узагалі — і білок
	# летів кудись до другого пікселя екрана, бо ми множили зсув на поворот БЕЗ масштабу,
	# у 2–3 рази більший за призначений. Тому масштаб — окремо (сирий, без згладжування:
	# він не хитається так, як поворот) — і повертаємо його на місце вже після повороту.
	var raw_basis := parent_3d.global_transform.basis
	var raw_scale := raw_basis.get_scale()
	var raw_rot := raw_basis.orthonormalized()
	if not _smooth_ready:
		_smooth_basis = raw_rot
		_smooth_ready = true
	else:
		var raw_q := raw_rot.get_rotation_quaternion()
		var smooth_q := _smooth_basis.get_rotation_quaternion().slerp(
			raw_q, clampf(delta * ball_stabilize_hz, 0.0, 1.0))
		_smooth_basis = Basis(smooth_q)
	# self.position — стала (рест) відстань від батька до цього ока; білок сидить точно в
	# origin CartoonEye (0,0,~z), тож саме вона й потрібна як важіль
	var effective_basis := _smooth_basis.scaled(raw_scale)
	_ball.global_position = parent_3d.global_transform.origin + effective_basis * position


## Куди дивиться око: (-1..1, -1..1) від центру, обмежене max_look_offset. Зберігати напрямок
## між кадрами не треба — Hero3D викликає це щокадру, коли веде погляд за чимось.
func look_at_dir(dir: Vector2) -> void:
	_look = Vector2(clampf(dir.x, -1.0, 1.0), clampf(dir.y, -1.0, 1.0))
	_place_pivot()


## Вузол, що везе райдужку, зіницю й блики — Hero3D стискає його в реакції на удар.
func iris_pivot() -> Node3D:
	return _pivot


func _set_eye_scale(v: Vector2) -> void:
	eye_scale = v
	_rebuild()


func _set_iris_scale(v: float) -> void:
	iris_scale = v
	_rebuild()


func _set_pupil_scale(v: float) -> void:
	pupil_scale = v
	_rebuild()


func _set_iris_offset(v: Vector2) -> void:
	iris_offset = v
	_place_pivot()


func _set_eye_rotation(v: float) -> void:
	eye_rotation = v
	if _ball != null:
		rotation.z = deg_to_rad(eye_rotation)


func _set_highlight_scale(v: float) -> void:
	highlight_scale = v
	_rebuild()


func _set_ball_depth(v: float) -> void:
	ball_depth = v
	_rebuild()


func _set_eyelid_cover(v: float) -> void:
	eyelid_cover = v
	_rebuild()


func _set_eyelid_color(v: Color) -> void:
	# НЕ мутуємо material_override на місці: Mats.dome_glossy кешує матеріали за кольором —
	# той самий ресурс може стояти й на інших частинах ока. _rebuild() бере СВІЖИЙ (чи вже
	# кешований під новий колір) матеріал через _part(), як і решта сеттерів.
	eyelid_color = v
	_rebuild()


## Повна перезбірка: частин мало й вони дешеві, тож простіше зібрати наново, ніж стежити за
## тим, яка саме властивість змінилась (і в Інспекторі це виглядає миттєво).
func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		c.free()
	rotation.z = deg_to_rad(eye_rotation)

	_ball = _part("EyeBall", Vector3(eye_scale.x, eye_scale.y, eye_scale.x * ball_depth),
		Palette.H_CREAM, Vector3.ZERO, self)
	_smooth_ready = false      # нова куля — почати згладжування нахилу заново, без стрибка

	_pivot = Node3D.new()
	_pivot.name = "IrisPivot"
	add_child(_pivot)

	var layer_d := eye_scale.x * ball_depth * LAYER_DEPTH
	var iris := Vector3(eye_scale.x * iris_scale, eye_scale.y * iris_scale, layer_d)
	_rim = _part("IrisRim", Vector3(iris.x * RIM_WIDEN, iris.y * RIM_WIDEN, layer_d),
		Palette.HERO_IRIS.darkened(0.45), _front(layer_d, LIFT_RIM), _pivot)
	_iris = _part("Iris", iris, Palette.HERO_IRIS, _front(layer_d, LIFT_IRIS), _pivot)
	_pupil = _part("Pupil", Vector3(iris.x * pupil_scale, iris.y * pupil_scale, layer_d),
		Palette.HERO_EYE, _front(layer_d, LIFT_PUPIL), _pivot)

	# Блики — діти IrisPivot, а НЕ зіниці: у зіниці нерівномірний масштаб, і будь-яка дитина
	# під нею стиснулась би тим самим вектором у невидиму цятку (стара помилка, див. MEMORY).
	var hi := eye_scale.x * 0.2 * highlight_scale
	var big := _front(layer_d, LIFT_HI_BIG)
	big.x = eye_scale.x * 0.22
	big.y = eye_scale.y * 0.2
	_hi_big = _part("HighlightBig", Vector3(hi, hi, layer_d), Color.WHITE, big, _pivot)
	var small := _front(layer_d, LIFT_HI_SMALL)
	small.x = -eye_scale.x * 0.2
	small.y = -eye_scale.y * 0.24
	_hi_small = _part("HighlightSmall", Vector3(hi * 0.5, hi * 0.5, layer_d), Color.WHITE, small, _pivot)

	# Повіка — приплюснутий купол, зсунутий до верху білка й трохи спереду за все інше:
	# читається як край складки шкіри, що звисає зверху, а не як окрема куля над оком.
	# _part() бере size як ПОВНИЙ масштаб вузла над сіткою радіусом 0,5 (те саме, чим
	# заданий EyeBall) — тобто піввисота білка вгору від центру = eye_scale.y * 0,5.
	_eyelid = null
	if eyelid_cover > 0.001:
		var ball_half_h := eye_scale.y * 0.5
		var lid_top := ball_half_h * 1.08          # трохи ВИЩЕ верху білка — без щілини зверху
		var lid_bottom := ball_half_h * (1.0 - 2.0 * eyelid_cover)   # ЛІНІЯ покриття
		var lid_w := eye_scale.x * 1.1
		var lid_pos := _front(layer_d, LIFT_EYELID)
		lid_pos.y = (lid_top + lid_bottom) * 0.5
		_eyelid = _part("Eyelid", Vector3(lid_w, lid_top - lid_bottom, layer_d),
			eyelid_color, lid_pos, self)
	_place_pivot()


## Позиція шару глибиною depth так, щоб його передня поверхня стирчала на lift перед білком.
func _front(depth: float, lift: float) -> Vector3:
	return Vector3(0.0, 0.0, -(eye_scale.x * ball_depth - depth) - lift)


func _part(part_name: String, size: Vector3, color: Color, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := Mats.dome_glossy(size, color)
	mi.name = part_name
	mi.position = pos
	parent.add_child(mi)
	return mi


## Зсув райдужки = постійний (iris_offset) + поточний погляд, усе в частках півосей білка.
func _place_pivot() -> void:
	if _pivot == null or not is_instance_valid(_pivot):
		return
	var off := (iris_offset + _look * max_look_offset).limit_length(1.0)
	_pivot.position = Vector3(off.x * eye_scale.x, off.y * eye_scale.y, 0.0)
