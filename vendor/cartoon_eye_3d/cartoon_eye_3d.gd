## Вендорний компонент ока (справжня 3D-геометрія: куля + сокет + повіки), принесений
## користувачем на заміну пласкому ShaderEye. Обидва попередні ока лишаються в проєкті:
## наш CartoonEye (src/run3d/eye/) і ShaderEye (vendor/cartoon_eye/).
##
## НАШІ ПРАВКИ поверх вендорного коду (свідомо мінімальні, позначені коментарем "// наше:"):
##   1) eye_height типово 1.0, а не 1.15 — око має бути КРУГЛИМ (вимога Nick).
##   2) clamp()/lerp()/max() -> clampf()/lerpf()/maxf(): у проєкті попередження вважаються
##      помилками, а нетипізовані глобали повертають Variant і скрипт просто не компілювався.
##   3) Iris/Pupil (циліндри, повернуті на 90°) отримували масштаб без урахування повороту —
##      диск ставав тонким лезом руба до камери, райдужки не було видно взагалі.
##   4) iris_z рахувався від eye_depth, а не від ПІВглибини (eye_depth * 0.5) — райдужка
##      зависала перед оком, а куля тонула в голові; повіки в спокої стояли поза кулею.
##   5) сеттери зверталися до @onready-вузлів лише за is_inside_tree(); після перезавантаження
##      скрипта (@tool у відкритому редакторі) ті ставали null і кожен сеттер сипав помилку
##      в дебагер. Тепер є _nodes_ok(), який перевіряє й за потреби перечіплює вузли.
##   6) кліпання працювало ЛИШЕ через повіки — зі схованими повіками (так у лиса) око не
##      блимало взагалі. Тепер без повік воно стискається по вертикалі.
##   7) Iris/Pupil із пласких дисків стали КУПОЛАМИ, плюс з'явився темний обідок IrisRim —
##      саме це дає «градієнт» райдужки з референсної текстури (опуклість ловить світло).
##   8) блики стояли на жорстких z=0.02/0.025 і тонули за куполами райдужки/зіниці —
##      від великого бліка лишалась цятка. Тепер їхня глибина рахується від райдужки.
##   9) додано iris_offset і pupil_offset: на референсній текстурі райдужка зміщена в оці,
##      а зіниця — в райдужці (звідти світлий серп знизу-справа). Вендор такого не мав.
##  10) set_surprised() був накопичувальним (eye_height *= 1.08 щоразу) і не мав пари —
##      кожен наступний удар роздував око назавжди. Тепер рахується від базових значень,
##      а set_neutral() їх повертає (Hero3D кличе обидва — див. _eye_set_surprised).
@tool
extends Node3D
class_name CartoonEye3D

@export_group("Eyeball Shape")
@export_range(0.3, 2.0, 0.01) var eye_width := 1.0:
	set(value):
		eye_width = value
		_apply_shape()

@export_range(0.3, 2.0, 0.01) var eye_height := 1.0:     # наше: було 1.15 (овал)
	set(value):
		eye_height = value
		_apply_shape()

@export_range(0.05, 1.0, 0.01) var eye_depth := 0.34:
	set(value):
		eye_depth = value
		_apply_shape()

@export_range(0.0, 0.8, 0.01) var embed_depth := 0.34:
	set(value):
		embed_depth = value
		_apply_shape()

@export_group("Socket")
@export var socket_enabled := true:
	set(value):
		socket_enabled = value
		_apply_shape()

@export_range(0.0, 0.25, 0.005) var socket_thickness := 0.055:
	set(value):
		socket_thickness = value
		_apply_shape()

@export_range(0.9, 1.4, 0.01) var socket_scale := 1.06:
	set(value):
		socket_scale = value
		_apply_shape()

@export_group("Iris")
@export var iris_color := Color("#70472F"):
	set(value):
		iris_color = value
		_apply_colors()

@export_range(0.2, 0.95, 0.01) var iris_size := 0.67:
	set(value):
		iris_size = value
		_apply_shape()

## наше: ПОСТІЙНИЙ зсув райдужки в межах ока (частки ока), поверх погляду. На референсній
## текстурі райдужка не по центру — вона зміщена вниз-усередину, і саме це дає мордочці
## той «милий» вигляд. Гляд (gaze) додається зверху й лишається керованим з Hero3D.
@export var iris_offset := Vector2.ZERO:
	set(value):
		iris_offset = value
		_apply_gaze()

## наше: зсув ЗІНИЦІ всередині райдужки. У референсі темна пляма зсунута вгору-вліво, через
## що знизу-справа лишається світлий теплий серп — без цього зіниця виходить концентричним
## кільцем, а не тим, що на текстурі.
@export var pupil_offset := Vector2.ZERO:
	set(value):
		pupil_offset = value
		_apply_gaze()

@export_range(0.0, 0.12, 0.001) var iris_surface_offset := 0.012:
	set(value):
		iris_surface_offset = value
		_apply_shape()

@export_group("Pupil")
@export var pupil_color := Color("#21100C"):
	set(value):
		pupil_color = value
		_apply_colors()

@export_range(0.1, 0.9, 0.01) var pupil_size := 0.55:
	set(value):
		pupil_size = value
		_apply_shape()

@export_group("Highlights")
@export var highlight_color := Color.WHITE:
	set(value):
		highlight_color = value
		_apply_colors()

## наше: ДЗЕРКАЛЬНЕ око. Пресет описує одне око, а друге Hero3D просить віддзеркалити по x —
## тоді зіниці й блики дивляться ВСЕРЕДИНУ, до носа, а не обидва в один бік (так на
## референсі оленяти; у лиса вони «розбігались», і морда виходила косоока).
@export var mirrored := false:
	set(value):
		mirrored = value
		_apply_gaze()

@export_range(0.02, 0.60, 0.01) var big_highlight_size := 0.12:
	set(value):
		big_highlight_size = value
		_apply_shape()

@export var big_highlight_offset := Vector2(-0.24, 0.24):
	set(value):
		big_highlight_offset = value
		_apply_gaze()

@export_range(0.005, 0.40, 0.005) var small_highlight_size := 0.05:
	set(value):
		small_highlight_size = value
		_apply_shape()

@export var small_highlight_offset := Vector2(0.28, -0.30):
	set(value):
		small_highlight_offset = value
		_apply_gaze()

@export_group("Colors")
@export var sclera_color := Color("#FFFDF8"):
	set(value):
		sclera_color = value
		_apply_colors()

@export var socket_color := Color("#4A2D22"):
	set(value):
		socket_color = value
		_apply_colors()

@export_group("Gaze")
@export_range(-1.0, 1.0, 0.01) var gaze_x := 0.0:
	set(value):
		gaze_x = value
		_apply_gaze()

@export_range(-1.0, 1.0, 0.01) var gaze_y := 0.0:
	set(value):
		gaze_y = value
		_apply_gaze()

@export_range(0.0, 0.35, 0.01) var max_gaze_x := 0.16:
	set(value):
		max_gaze_x = value
		_apply_gaze()

@export_range(0.0, 0.35, 0.01) var max_gaze_y := 0.12:
	set(value):
		max_gaze_y = value
		_apply_gaze()

@export_group("Blink")
@export_range(0.0, 1.0, 0.01) var blink_amount := 0.0:
	set(value):
		blink_amount = value
		_apply_blink()

@export var auto_blink := true
@export_range(1.0, 10.0, 0.1) var blink_interval_min := 2.0
@export_range(1.0, 10.0, 0.1) var blink_interval_max := 5.5
@export_range(0.05, 0.5, 0.01) var blink_duration := 0.16

@onready var socket: MeshInstance3D = $Socket
@onready var eyeball: MeshInstance3D = $Eyeball
@onready var iris_pivot: Node3D = $IrisPivot
@onready var iris_rim: MeshInstance3D = $IrisPivot/IrisRim
@onready var iris: MeshInstance3D = $IrisPivot/Iris
@onready var pupil: MeshInstance3D = $IrisPivot/Pupil
@onready var highlight_big: MeshInstance3D = $IrisPivot/HighlightBig
@onready var highlight_small: MeshInstance3D = $IrisPivot/HighlightSmall
@onready var upper_lid: MeshInstance3D = $UpperLid
@onready var lower_lid: MeshInstance3D = $LowerLid

## наше: де стоїть повіка в спокої, у частках висоти ока (0.5 — рівно край кулі).
const LID_REST := 0.58
## наше: наскільки стискається око на повному блимку, коли повіки сховані (0.94 — майже в лінію).
const BLINK_SQUASH := 0.94
## наше: обідок райдужки — наскільки він ширший за неї і наскільки темніший.
const IRIS_RIM_WIDEN := 1.07
## наше: опуклість райдужки як частка глибини ока — саме вона й дає м'який градієнт.
const IRIS_DOME := 0.22
const IRIS_RIM_DARKEN := 0.42
## наше: запас (частка iris_d) понад геометрично необхідний зсув між сусідніми куполами
## (rim→iris→pupil) — див. _layer_gap(). Без запасу шари лише-лише не перетинаються, і на
## екрані це все одно читається як шумний, рябий обвід (z-fighting на майже дотичних
## поверхнях); з запасом лишається справжня, помітна щілина.
const DEPTH_MARGIN := 0.25

var _blink_timer := 0.0
var _active_blink_tween: Tween
# наше: база для виразів — щоб set_surprised() не накопичувався від удару до удару
var _base_eye_height := 0.0
var _base_pupil_size := 0.0

func _ready() -> void:
	_make_materials_local()
	_apply_all()
	_schedule_next_blink()
	_capture_expression_base()


## наше: запам'ятати «спокійні» пропорції. Кличемо і ззовні (Hero3D), якщо героєві
## виставили свої width/height вже ПІСЛЯ _ready.
func _capture_expression_base() -> void:
	_base_eye_height = eye_height
	_base_pupil_size = pupil_size

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if auto_blink:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			blink()
			_schedule_next_blink()

func _make_materials_local() -> void:
	for mesh_node in [socket, eyeball, iris_rim, iris, pupil, highlight_big, highlight_small,
			upper_lid, lower_lid]:
		if mesh_node and mesh_node.material_override:
			mesh_node.material_override = mesh_node.material_override.duplicate()

func _apply_all() -> void:
	_apply_shape()
	_apply_colors()
	_apply_gaze()
	_apply_blink()

## наше: після перезавантаження скрипта (@tool у відкритому редакторі) @onready-посилання
## стають null, а сеттери експортів усе одно спрацьовують — і кожен сипав у дебагер
## «Invalid access to property on a base object of type Nil». Тому перед кожним застосуванням
## перевіряємо вузли й за потреби перечіплюємо їх наново.
func _nodes_ok() -> bool:
	if not is_inside_tree():
		return false
	if not is_instance_valid(eyeball):
		socket = get_node_or_null("Socket") as MeshInstance3D
		eyeball = get_node_or_null("Eyeball") as MeshInstance3D
		iris_pivot = get_node_or_null("IrisPivot") as Node3D
		iris_rim = get_node_or_null("IrisPivot/IrisRim") as MeshInstance3D
		iris = get_node_or_null("IrisPivot/Iris") as MeshInstance3D
		pupil = get_node_or_null("IrisPivot/Pupil") as MeshInstance3D
		highlight_big = get_node_or_null("IrisPivot/HighlightBig") as MeshInstance3D
		highlight_small = get_node_or_null("IrisPivot/HighlightSmall") as MeshInstance3D
		upper_lid = get_node_or_null("UpperLid") as MeshInstance3D
		lower_lid = get_node_or_null("LowerLid") as MeshInstance3D
	return is_instance_valid(eyeball) and is_instance_valid(iris_pivot) \
		and is_instance_valid(upper_lid) and is_instance_valid(lower_lid)


## наше: зсув НАСТУПНОГО (вужчого) купола вперед відносно ПОПЕРЕДНЬОГО (ширшого) під ним,
## який гарантовано тримає край вужчого купола ПОПЕРЕД поверхнею ширшого — інакше вони
## геометрично перетинаються й дають рябий, шумний обвід z-fighting (див. коментар у
## _apply_shape, де це й побачили на зіниці лиса). Чиста функція — тест б'є її напряму.
##   base_d   — повний (не пів-) z-розмір ширшого купола внизу (rim_d для переходу rim→iris,
##              iris_d для переходу iris→pupil);
##   ratio    — відношення радіуса вужчого купола до ширшого (pupil_size для iris→pupil,
##              1.0 / IRIS_RIM_WIDEN для rim→iris);
##   margin_d — одиниця запасу (завжди iris_d: спільний масштаб для обох переходів).
static func _layer_gap(base_d: float, ratio: float, margin_d: float) -> float:
	var r := clampf(ratio, 0.0, 1.0)
	return 0.5 * base_d * sqrt(maxf(0.0, 1.0 - r * r)) + DEPTH_MARGIN * margin_d


func _apply_shape() -> void:
	if not _nodes_ok():
		return

	# The eyeball is a flattened 3D sphere, not a flat quad.
	eyeball.scale = Vector3(eye_width, eye_height, eye_depth)

	# Push most of the sphere back into the character head.
	eyeball.position.z = -embed_depth

	# Socket sits around the visible lens and hides the seam with the head.
	socket.visible = socket_enabled
	socket.scale = Vector3(
		eye_width * socket_scale,
		eye_height * socket_scale,
		maxf(eye_depth * 0.34, 0.03)
	)
	socket.position.z = -embed_depth - maxf(socket_thickness, 0.001)

	# Iris / pupil are very shallow 3D discs sitting on the curved eye front.
	# наше: * 0.5 — сітка кулі має радіус 0.5, тож ПІВглибина = eye_depth * 0.5. Без цього
	# райдужка зависала попереду ока, а куля тонула в голові (див. шапку файла).
	var iris_z := -embed_depth + eye_depth * 0.5 + iris_surface_offset
	iris_pivot.position.z = iris_z

	# наше: Iris/Pupil тепер КУПОЛИ (сплющені сфери), а не пласкі диски. Це і є той градієнт
	# з референсу: опукла райдужка сама ловить світло — світліша знизу, темніша згори, —
	# і жодної текстури чи шейдера для цього не треба.
	var iris_w := eye_width * iris_size
	var iris_h := eye_height * iris_size
	var iris_d := maxf(0.03, eye_depth * IRIS_DOME)
	var rim_d := iris_d * 0.9
	var pupil_d := iris_d * 0.9
	iris_rim.scale = Vector3(iris_w * IRIS_RIM_WIDEN, iris_h * IRIS_RIM_WIDEN, rim_d)
	iris.scale = Vector3(iris_w, iris_h, iris_d)
	pupil.scale = Vector3(
		iris_w * pupil_size,
		iris_h * pupil_size,
		pupil_d
	)
	# наше: повороти дітей ЗАВЖДИ обнуляємо. Пресети героїв — успадковані сцени, і редактор
	# любить запікати в них трансформи дітей; коли форма компонента змінюється (у нас диски
	# стали куполами), ті старі повороти лишаються й перекручують геометрію в лезо.
	iris_rim.rotation = Vector3.ZERO
	iris.rotation = Vector3.ZERO
	pupil.rotation = Vector3.ZERO
	highlight_big.rotation = Vector3.ZERO
	highlight_small.rotation = Vector3.ZERO

	# наше: кожен шар — купол (сплющена сфера), не пласка нашивка. На своєму КРАЇ купол
	# завжди сходить у нуль (сфера), а купол ширшого шару під ним на цьому ж радіусі ще
	# опуклий — тож старий підхід «зсунь наступний шар на довільну частку iris_d вперед»
	# (тут стояло фіксоване 0.10 / 0.22, взяте на око під одного лиса) на вужчих/ширших
	# пресетах не рятує: край вузького купола провалюється НИЖЧЕ поверхні широкого, вони
	# геометрично перетинаються, і рівно на цьому перетині — де поверхні майже дотичні —
	# з'являється рябий, шумний обвід (z-fighting). Це і побачив Nick на зіниці лиса.
	# _layer_gap() рахує зсув, який ГАРАНТОВАНО тримає край вужчого купола попереду
	# ширшого — для будь-яких iris_size/pupil_size з пресета, не тільки для лиса.
	var rim_layer_z := 0.0
	var iris_layer_z := rim_layer_z + _layer_gap(rim_d, 1.0 / IRIS_RIM_WIDEN, iris_d)
	var pupil_layer_z := iris_layer_z + _layer_gap(iris_d, pupil_size, iris_d)
	iris_rim.position.z = rim_layer_z
	iris.position.z = iris_layer_z
	pupil.position.z = pupil_layer_z

	# наше: розмір бліків тепер ВІДНОСНИЙ (×eye_width/×eye_height), як у райдужки. Був
	# абсолютний — і щойно Hero3D стискав око під конкретного героя (rig_face.eye_size),
	# райдужка меншала, а блік лишався той самий: пропорція з референсом ламалась саме в грі,
	# хоч в ізольованій сцені все сходилось. Тепер blik/райдужка = big_highlight_size/iris_size
	# незалежно від того, як героєві змасштабували око.
	highlight_big.scale = Vector3(
		big_highlight_size * eye_width,
		big_highlight_size * eye_height,
		maxf(0.01, eye_depth * 0.04)
	)

	highlight_small.scale = Vector3(
		small_highlight_size * eye_width,
		small_highlight_size * eye_height,
		maxf(0.008, eye_depth * 0.03)
	)

	# Eyelids sit just over the eye surface.
	var lid_z := iris_z + 0.01
	upper_lid.position.z = lid_z
	lower_lid.position.z = lid_z

	upper_lid.scale = Vector3(
		eye_width * 1.04,
		eye_height * 0.55,
		maxf(0.03, eye_depth * 0.10)
	)
	lower_lid.scale = Vector3(
		eye_width * 1.04,
		eye_height * 0.55,
		maxf(0.03, eye_depth * 0.10)
	)

	_apply_gaze()
	_apply_blink()

func _apply_colors() -> void:
	if not _nodes_ok():
		return

	_set_albedo(eyeball, sclera_color)
	_set_albedo(socket, socket_color)
	# наше: обідок — той самий колір райдужки, лише темніший. На референсі саме він дає оку
	# «глибину»: райдужка не пласка пляма, а диск із темнішим краєм.
	_set_albedo(iris_rim, iris_color.darkened(IRIS_RIM_DARKEN))
	_set_albedo(iris, iris_color)
	_set_albedo(pupil, pupil_color)
	_set_albedo(highlight_big, highlight_color)
	_set_albedo(highlight_small, highlight_color)
	_set_albedo(upper_lid, socket_color)
	_set_albedo(lower_lid, socket_color)

func _set_albedo(node: MeshInstance3D, color: Color) -> void:
	if node == null:
		return

	var mat := node.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color = color

func _apply_gaze() -> void:
	if not _nodes_ok():
		return

	var gx := clampf(gaze_x, -1.0, 1.0) * max_gaze_x * eye_width
	var gy := clampf(gaze_y, -1.0, 1.0) * max_gaze_y * eye_height

	# наше: постійний зсув райдужки + погляд
	iris_pivot.position.x = gx + _inward(iris_offset.x) * eye_width
	iris_pivot.position.y = gy + iris_offset.y * eye_height

	# наше: зіниця зі своїм зсувом усередині райдужки (див. pupil_offset)
	pupil.position.x = _inward(pupil_offset.x) * eye_width
	pupil.position.y = pupil_offset.y * eye_height

	# наше: z бліків був жорстко 0.02/0.025 — і вони тонули за куполами райдужки та зіниці,
	# від них лишалась крихітна цятка. Рахуємо від глибини райдужки, щоб блік ЗАВЖДИ лежав
	# поверх зіниці — на референсі він великий і добре читається.
	var hz := maxf(0.03, eye_depth * IRIS_DOME)
	highlight_big.position = Vector3(
		_inward(big_highlight_offset.x) * eye_width,
		big_highlight_offset.y * eye_height,
		hz * 0.62
	)

	highlight_small.position = Vector3(
		_inward(small_highlight_offset.x) * eye_width,
		small_highlight_offset.y * eye_height,
		hz * 0.66
	)

## наше: зсув по x із поправкою на дзеркальність — але ЛИШЕ поки око дивиться прямо.
## Щойно герой повів очима вбік, обидва ока мають вести зіниці В ОДИН бік (інакше одне
## дивилось би вліво, а друге вправо), тож дзеркальність плавно тане з ростом |gaze_x|.
func _inward(x: float) -> float:
	var side := -1.0 if mirrored else 1.0
	return lerpf(x * side, x, absf(clampf(gaze_x, -1.0, 1.0)))


func _apply_blink() -> void:
	if not _nodes_ok():
		return

	var b := clampf(blink_amount, 0.0, 1.0)

	# наше: кліпання у вендорі було ЛИШЕ рухом повік. Щойно повіки ховають (а в лиса вони
	# сховані — окремими плямами над оком вони виглядали чужорідно), blink_amount переставав
	# робити хоч щось видиме, і око просто не блимало. Тому: є повіки — рухаємо їх; нема —
	# стискаємо саме око по вертикалі, як і робить класичний мультяшний блимок.
	if upper_lid.visible or lower_lid.visible:
		# Move lids toward the center instead of scaling the eye itself.
		# наше: у спокої повіка стоїть на КРАЮ кулі (0.5 висоти), а не на 0.75 — інакше вона
		# висить окремою плямою над оком, бо край сфери радіусом 0.5 саме там.
		upper_lid.position.y = lerpf(eye_height * LID_REST, 0.0, b)
		lower_lid.position.y = lerpf(-eye_height * LID_REST, 0.0, b)

		# Slight overlap at full close avoids a gap.
		upper_lid.scale.y = eye_height * lerpf(0.25, 0.70, b)
		lower_lid.scale.y = eye_height * lerpf(0.25, 0.70, b)
		eyeball.scale.y = eye_height
		iris_pivot.scale.y = 1.0
	else:
		var open_k := 1.0 - b * BLINK_SQUASH
		eyeball.scale.y = eye_height * open_k
		iris_pivot.scale.y = open_k

func look_at_offset(offset: Vector2) -> void:
	gaze_x = clampf(offset.x, -1.0, 1.0)
	gaze_y = clampf(offset.y, -1.0, 1.0)

func blink() -> void:
	if not is_inside_tree():
		return

	if is_instance_valid(_active_blink_tween):
		_active_blink_tween.kill()

	_active_blink_tween = create_tween()
	_active_blink_tween.set_trans(Tween.TRANS_SINE)
	_active_blink_tween.set_ease(Tween.EASE_IN_OUT)
	_active_blink_tween.tween_property(self, "blink_amount", 1.0, blink_duration * 0.5)
	_active_blink_tween.tween_property(self, "blink_amount", 0.0, blink_duration * 0.5)

## наше: рахуємо від БАЗИ, а не від поточного — інакше кожен удар роздував око назавжди.
func set_surprised() -> void:
	if _base_eye_height <= 0.0:
		_capture_expression_base()
	eye_height = _base_eye_height * 1.08
	pupil_size = _base_pupil_size * 0.82
	_apply_shape()


## наше: пара до set_surprised() — у вендорному коді її просто не було.
func set_neutral() -> void:
	if _base_eye_height <= 0.0:
		return
	eye_height = _base_eye_height
	pupil_size = _base_pupil_size
	_apply_shape()

func _schedule_next_blink() -> void:
	_blink_timer = randf_range(blink_interval_min, blink_interval_max)
