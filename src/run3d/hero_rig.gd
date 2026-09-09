## Скелетний («ригнутий») герой — альтернатива вокселям для героя з полем `"rig"` у data/heroes.json.
##
## Це КОМПОНЕНТ, а не другий клас героя: Hero3D сам вирішує, чим малювати тіло
## (вокселі-частини або цей риг), і залишає весь свій публічний API незмінним —
## доріжки, стрибок, присід, серця, щит, аксесуари, hit_reaction працюють як раніше.
## Так run3d.tscn, hero_select.gd, diorama.gd, friend3d.gd не змінюються взагалі.
##
## Що робить компонент:
##   1. вантажить `res://assets/models/<rig>.glb` (Godot імпортує його в PackedScene),
##      знаходить усередині Skeleton3D і меші;
##   2. масштабує модель під зріст героя (HEAD_TOP) і розвертає мордою в −Z;
##   3. розкладає кістки по ролях (hips/spine/neck/head/tail/fl/fr/bl/br/ear_l/ear_r,
##      плюс необов'язкові суто «малярські» tuft, nose, mane і horn) — спершу за іменами,
##      потім за геометрією, зверху — ручні `rig_bones` із даних;
##   4. фарбує МОДЕЛЬ БЕЗ ТЕКСТУР кольорами ГРАНЕЙ: меш перебудовується «розіндексованим»
##      (у кожного трикутника свої три вершини), колір і нормаль — на грань, зона рахується
##      в центроїді грані за її головною кісткою (морда, копитця, животик, кінчик хвоста,
##      вуха, чубчик і його основа, торбинка збоку…), зона → символ палітри (o/d/c/k/i/t/u/e/m) →
##      колір із heroes.json + Palette; поверх усього — необов'язковий СТИЛЬ героя
##      (`rig_style`, src/run3d/rig_styles.gd): веселка гриви й хвоста, смужки рога, зірочки;
##   5. щокадру анімує кістки процедурно (галоп, боб, вуха, хвіст, присід, стрибок, помах).
##
## Модель без анімацій і без матеріалів — саме тому все процедурне.
## Файлу нема → build() повертає false, і Hero3D спокійно малює звичайні вокселі.
class_name HeroRig
extends RefCounted

const MODELS_DIR := "res://assets/models"

## Один матеріал на всіх ригнутих героїв (див. _rig_material).
static var _rig_mat: Material

## Дублі констант Hero3D (навмисно: Hero3D посилається на HeroRig, тож зворотнє
## посилання дало б циклічну залежність class_name). Значення мають збігатися.
const HEAD_TOP := 0.98
const HEAD_H := 0.45
const HEAD_HALF_D := 0.225
const GALLOP_SWING := 0.6

## Сила rim-облямівки для гладкої моделі. У вокселів 0,18 і граней мало; у рига нормалі
## пливуть по всій поверхні, тож та сама облямівка робить героя вицвілим.
const RIG_RIM := 0.09

## Ширина воксельної голови, під яку намальоване обличчя Hero3D (очі ±0,15 + щічки ±0,2).
## Морда моделі вужча — обличчя треба стиснути, інакше очі вилазять за краї голови.
const FACE_HEAD_W := 0.525

## Посадка обличчя. Перевизначається полем `rig_face` у data/heroes.json (ручне підганяння):
##   scale — множник поверх автомасштабу «ширина голови / FACE_HEAD_W» (0,85: воксельні очі
##           на гладкій морді виглядають завеликими);
##   y     — висота очей у частках висоти голови (0,65 — трохи вище середини);
##   z     — додатковий зсув уперед (метри героя, від'ємне = глибше в морду);
##   layout — "front" (очі на передній грані морди, як у лисеняти) або "side" (очі на БОКАХ
##           голови й дивляться назовні — так у коня, оленя, будь-якої довгої морди).
const DEFAULT_FACE := {"scale": 0.85, "y": 0.65, "z": 0.0, "layout": "front"}

## Бічні очі (`layout: "side"`): наскільки вони ВТОПЛЕНІ під бік голови (метри героя —
## назовні стирчить лише передня частина меша ока, решта сидить у черепі), додатковий
## підтяг усієї групи ока до центру голови й на якій глибині вона сидить
## (частка довжини голови від переду). Раніше SIDE_EYE_OUT виносив око НАЗОВНІ, і воно
## висіло збоку в повітрі.
const SIDE_EYE_OUT := 0.005
const SIDE_EYE_IN := 0.01
const SIDE_EYE_DEPTH := 0.3

## Наскільки широку смугу по висоті голови вважаємо «висотою очей», коли шукаємо
## передню грань черепа (див. _eye_front): 0,65 ± 0,12 висоти голови.
const EYE_BAND := 0.12

## Ролі кісток. "tail", "tuft", "nose", "mane", "horn" можуть бути масивами (ланцюжок),
## решта — по одному індексу. "tuft" — чубчик/камінець на маківці, "nose" — кістки носа/писка,
## "mane" — грива вздовж шиї/потилиці, "horn" — ріг на лобі (усі чотири лише для розмальовки:
## автомапа їх не знає, задаються руками в `rig_bones` або ловляться геометрією стилю,
## див. RigStyles.remap_role).
const ROLES := ["hips", "spine", "neck", "head", "fl", "fr", "bl", "br", "ear_l", "ear_r",
	"tail", "tuft", "nose", "mane", "horn"]
const LEG_ROLES := ["fl", "fr", "bl", "br"]
const TORSO_ROLES := ["hips", "spine", "neck"]

## З ЯКИХ РОЛЕЙ складається коробка голови (посадка обличчя, площина очей, масштаб лиця).
## Писок входить — це та сама морда; а от ріг, грива й чубчик НІ: у єдинорога ріг стирчить
## на пів зросту вгору, і разом із ним коробка голови ставала вдвічі вищою, обличчя
## стискалось, а очі виїжджали на вершечок рога.
const HEAD_BOX_ROLES := ["head", "nose"]
## Ролі, які до коробки голови не потрапляють НІКОЛИ (для читабельності звіту прев'ю).
const HEAD_BOX_SKIP := ["horn", "mane", "tuft"]
## А от ШИРИНУ для бічних очей беремо з САМОГО ЧЕРЕПА (роль `head`, без писка): писок
## єдинорога вузький і довгий, і разом із ним півширина «голови» виходила не та, куди
## треба саджати око.
const HEAD_SIDE_ROLE := "head"

## Правила розмальовки (частки габариту кістки, 0..1). Перевизначаються полем
## `rig_zones` у data/heroes.json — щоб не лізти в код заради ширшої морди.
const DEFAULT_ZONES := {
	"muzzle_depth": 0.4,    ## передні 40 % глибини голови — кремова морда
	"muzzle_height": 0.55,  ## і лише нижні 55 % її висоти (лоб лишається основним кольором)
	"hoof": 0.25,           ## нижні 25 % лапки — темні копитця
	"ear_inner": 0.55,      ## передні 55 % вуха — рожева серединка (решта вуха — темний обід)
	"tail_tip": 0.35,       ## кінчик хвоста (ззаду або вгорі) — крем
	"belly": 0.42,          ## нижні 42 % тулуба — світліший животик
	"nose_tip": 0.22,       ## передні 22 % писка — темний носик (і лише верхня половина, див. NOSE_TIP_Y)
	"bag_x": 0.98,          ## наскільки далі за півширину тулуба має стирчати вершина, щоб це була торба
}

## Кінчик носа — це ще й ВЕРХНЯ половина писка: під ним губа й підборіддя, вони кремові.
const NOSE_TIP_Y := 0.5

## Чубчик: кістка чубчика сидить усередині черепа, тож ролі `tuft` слухається пів голови.
## Акцентними лишаємо тільки вершини, що стирчать вище за верх коробки голови мінус
## 10 % її висоти; решта фарбується звичайними правилами голови.
const TUFT_ABOVE := 0.1

## ОСНОВА чубчика — обідок черепа ПІД ним, завтовшки TUFT_BASE висоти коробки голови
## (смуга [верх − TUFT_ABOVE − TUFT_BASE, верх − TUFT_ABOVE]). Це та сама помаранчева щілина,
## що світилась між вухами під жовтим чубчиком: фарбуємо її темнішим золотом (зона `u`).
const TUFT_BASE := 0.08

## Скільки вершин має бути в «торбі», щоб вона взагалі рахувалась торбою, і яку частку
## тулуба поріг має право забрати (більше — це вже не сумка, а просто широкі боки).
const BAG_MIN := 40
const BAG_MAX_SHARE := 0.35
## Смуга по висоті тулуба, де шукаємо торбу (боки посередині, не шия й не пузо).
const BAG_Y_LO := 0.2
const BAG_Y_HI := 0.9
## Частка «зайвих» вершин на одному боці, після якої вважаємо торбу однобокою
## (тоді протилежний бік не фарбуємо взагалі, хай там і є пара вершин за порогом).
const BAG_ONE_SIDE := 0.8

## Скорочення `rig_marks: {"side": …}` — «усе, що стирчить далі за MARK_SIDE × півширину тулуба».
const MARK_SIDE := 0.85

## ─────────── ГЕНЕРИЧНИЙ ПОШУК БІЧНИХ НАРОСТІВ (торбинки лисеняти) ───────────
## `bag_x` міряв max |x| проти півширини ВСЬОГО тулуба — і в лисеняти не спрацьовував ніколи:
## сумка там рівно на півширині боку (max |x| == півширина), тож поріг завжди виходив за неї.
## Тому міряємо ЛОКАЛЬНО: тулуб ділиться на сітку SIDE_GRID × SIDE_GRID по (y, z), у кожній
## комірці «бік тіла» — це SIDE_PCT-перцентиль |x| (медіана завищена, коли наріст займає
## пів комірки), а «виступ» грані = |x| − цей бік. Грані з виступом > SIDE_MIN_OUT злипаються
## в купки по сусідству комірок (окрема сітка SIDE_CLUSTER_GRID, кожен бік свій), і купка
## від SIDE_MIN_FACES граней — це вже торбинка (зона `m`). Числа — В МЕТРАХ ГЕРОЯ.
const SIDE_GRID := 6
const SIDE_PCT := 0.4
const SIDE_MIN_OUT := 0.015
const SIDE_MIN_FACES := 30
const SIDE_CLUSTER_GRID := 12

## Ролі, які позначки (сердечко, латки, `rig_marks`, торбинки) НЕ чіпають ніколи: у рога свої
## смужки, у лапок копитця, у голови з писком морда, у хвоста пояси. Решта ролей (зокрема
## `mane` — пасма гриви на грудях) позначку отримати може, якщо грань лежить у коробці тулуба.
const MARK_SKIP_ROLES := ["horn", "head", "nose", "tail", "fl", "fr", "bl", "br"]
## Запас навколо коробки тулуба, у межах якого грань ще вважається «тулубною» для позначок
## (метри героя): пасмо гриви або сумка стирчить трохи ЗА поверхню тулуба.
const MARK_BOX_PAD := 0.05

## Діагностичне забарвлення (прев'ю, клавіша M): купка-торбинка й відкинутий кандидат.
const DEBUG_SIDE_OK := Color(1.0, 0.0, 1.0)
const DEBUG_SIDE_TRY := Color(0.42, 0.11, 0.48)

## Кольори зон: символи ті самі, що в палітрі вокселів (див. Hero3D._voxel_palette).
const ZONE_MAIN := "o"
const ZONE_BELLY := "d"
const ZONE_CREAM := "c"
const ZONE_DARK := "k"
const ZONE_INNER := "i"
const ZONE_TIP := "t"
const ZONE_TUFT_BASE := "u"   ## основа чубчика — акцент, темніший на 0,15 (див. Hero3D._hero_colors)
const ZONE_EAR := "e"    ## зовнішній бік вуха — темніший за животик
const ZONE_MARK := "m"   ## торбинка/плямки — колір `mark` із heroes.json

var _root: Node3D              ## вузол-обгортка (масштаб + підйом над землею), дитина Hero3D._body
var _model: Node3D             ## інстанс .glb (на ньому оберт «мордою в −Z»)
var _skel: Skeleton3D
var _meshes: Array[MeshInstance3D] = []
var _bones: Dictionary = {}    ## роль → індекс кістки; "tail" → Array[int]
var _role_cache: Dictionary = {}   ## індекс кістки → роль (з успадкуванням від батька)
var _axis_x: Dictionary = {}   ## індекс → напрямок «модельний +X» у локальних координатах кістки
var _axis_y: Dictionary = {}   ## індекс → напрямок «модельний +Y»
var _axis_z: Dictionary = {}   ## індекс → напрямок «модельний +Z» (крен голови у привітанні)
var _up_parent: Dictionary = {}    ## індекс → напрямок «вгору» в координатах БАТЬКІВСЬКОЇ кістки
var _anchors: Dictionary = {}  ## роль → Node3D у «геройських» одиницях (для аксесуарів)
var _front := -1.0             ## куди дивиться модель у власних координатах: −1 → −Z, +1 → +Z
var _scale := 1.0              ## модель → метри героя
var _inv_scale := 1.0
var _zones: Dictionary = DEFAULT_ZONES.duplicate()
var _face_cfg: Dictionary = DEFAULT_FACE.duplicate()
var _anim_cfg: Dictionary = DEFAULT_ANIM.duplicate()   ## множники `rig_anim` (див. anim_of)
## Роль лапки → індекс НИЖНЬОЇ ланки (перша дитина кістки лапки). Нема дитини — ролі нема:
## тоді лапка просто крутиться від плеча, як раніше.
var _lower_leg: Dictionary = {}
var _style: Dictionary = {}    ## стиль розмальовки з `rig_style` (див. RigStyles)
var _style_name := ""
var _model_to_skel := Transform3D.IDENTITY   ## координати моделі → координати скелета
var _skel_unit := 1.0          ## одиниць скелета в одиниці моделі (імпортер .glb любить масштаб)
var _head_box := AABB()        ## габарит вершин голови В КООРДИНАТАХ МОДЕЛІ
var _head_core_box := AABB()   ## габарит САМОГО ЧЕРЕПА (роль `head`) — по ньому сідають бічні очі
var _face_scale := 1.0         ## у скільки разів стиснуте обличчя проти воксельного
var _face_front := -HEAD_HALF_D    ## площина очей у координатах воксельної голови (−0,225 = передня грань)
var _face_node_pos := Vector3.ZERO  ## позиція вузла обличчя в координатах голови (бічні очі)
var _root_y0 := 0.0            ## «чесна» висота кореня рига (лапки на землі), м
var _sign: Dictionary = {}     ## КАЛІБРОВАНІ знаки обертів: "<роль>_<вісь>" → ±1 (див. _calibrate)
var _tail_lift_sign: Array[float] = []   ## знак підйому для кожної ланки хвоста
var _tail_wag_sign: Array[float] = []    ## знак виляння для кожної ланки хвоста
var _leg_tips: Array = []      ## [[кістка-кінчик, точка в її координатах], …] — найнижче копитце
var _zone_counts: Dictionary = {}   ## символ зони → скільки ГРАНЕЙ (діагностика прев'ю)
var _bag_info: Dictionary = {}      ## діагностика пошуку торбинки (див. face_report)
var _side_info: Array = []          ## знайдені купки бічних наростів (див. side_clusters)
var _debug_sides := false           ## прев'ю, клавіша M: підсвітити купки магентою
var _verts: Dictionary = {}         ## вихідні вершини — тільки в прев'ю (RIG=…), для перефарбування
var _colors: Dictionary = {}        ## палітра героя — там же
var _marks: Array = []              ## ручні позначки `rig_marks` (див. marks_of)
var _model_box := AABB()            ## габарит УСІХ вершин у координатах моделі (з нього — метри героя)
var _torso_box := AABB()            ## габарит граней тулуба В МЕТРАХ ГЕРОЯ (діагностика під rig_marks)
var _ready := false


# ─────────────────────────────── шлях і наявність ───────────────────────────────

## Шлях до моделі за іменем ригу з heroes.json. Чиста функція (тест перевіряє формат).
static func rig_path(rig: String) -> String:
	return "%s/%s.glb" % [MODELS_DIR, rig]


## Чи модель узагалі є в проєкті. Нема — Hero3D малює вокселі, гра не падає.
static func rig_exists(rig: String) -> bool:
	if rig == "":
		return false
	return ResourceLoader.exists(rig_path(rig))


## Правила зон для героя: дефолти + `rig_zones` із даних. Чиста функція.
static func zones_of(def: Dictionary) -> Dictionary:
	var out := DEFAULT_ZONES.duplicate()
	var z = def.get("rig_zones", {})
	if typeof(z) == TYPE_DICTIONARY:
		for k in (z as Dictionary).keys():
			if out.has(k):
				out[k] = float((z as Dictionary)[k])
	return out


## РУЧНІ ПОЗНАЧКИ `rig_marks` із heroes.json — коли наріст (торбинка, латка, нашийник) не
## ловиться геометрією `bag_x`, а власної кістки в нього нема. Список словників, кожен —
## або КОРОБКА в метрах героя (початок між лапками на землі, перед = −z, як усі константи Hero3D):
##     {"min": [x, y, z], "max": [x, y, z]}
## або СКОРОЧЕННЯ «бік тулуба» (не треба міряти x — його порахує півширина):
##     {"side": "left"|"right", "y": [0.3, 0.6], "z": [0.0, 0.5]}
##   — усі грані тулуба з цього боку далі за MARK_SIDE × півширину, у смузі y/z
##     (ЧАСТКИ габариту тулуба, 0…1; межу можна не задавати — тоді вся смуга).
## Грані, що потрапили в позначку, фарбуються в `m` (mark із heroes.json). Чиста функція.
static func marks_of(def: Dictionary) -> Array:
	var out := []
	var v = def.get("rig_marks", [])
	if typeof(v) != TYPE_ARRAY:
		return out
	for item in (v as Array):
		if typeof(item) == TYPE_DICTIONARY:
			out.append(item)
	return out


## Чи потрапляє грань у якусь ручну позначку (пара до marks_of). Чиста функція.
## `p` — центроїд грані В МЕТРАХ ГЕРОЯ, `dx` — його зсув від площини симетрії (ліворуч < 0),
## `local` — частки габариту зони (для смуг y/z скорочення), `half` — півширина тулуба, м.
static func mark_hit(marks: Array, p: Vector3, role: String, local: Vector3,
		dx: float, half: float) -> bool:
	for item in marks:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var m: Dictionary = item
		var side := String(m.get("side", ""))
		if side == "":
			if _in_box(m, p):
				return true
			continue
		if not TORSO_ROLES.has(role) or half <= 0.00001:
			continue
		# «ліворуч» у координатах героя — це −x (там і LegFL у Hero3D)
		var want := -1.0 if side == "left" else 1.0
		if signf(dx) != want or absf(dx) < half * MARK_SIDE:
			continue
		if not _in_band(m.get("y", null), local.y) or not _in_band(m.get("z", null), local.z):
			continue
		return true
	return false


## Точка всередині коробки {"min": [x,y,z], "max": [x,y,z]} (порядок кінців не важливий).
static func _in_box(m: Dictionary, p: Vector3) -> bool:
	var lo = m.get("min", null)
	var hi = m.get("max", null)
	if typeof(lo) != TYPE_ARRAY or typeof(hi) != TYPE_ARRAY \
			or (lo as Array).size() < 3 or (hi as Array).size() < 3:
		return false
	for i in range(3):
		var a := float((lo as Array)[i])
		var b := float((hi as Array)[i])
		var c := float(p[i])
		if c < minf(a, b) or c > maxf(a, b):
			return false
	return true


## Значення в смузі [lo, hi] зі списку (null або не пара чисел — смуги нема, підходить усе).
static func _in_band(band, value: float) -> bool:
	if typeof(band) != TYPE_ARRAY or (band as Array).size() < 2:
		return true
	var a := float((band as Array)[0])
	var b := float((band as Array)[1])
	return value >= minf(a, b) and value <= maxf(a, b)


## ПІДГОНКА АНІМАЦІЇ ПІД МОДЕЛЬ (`rig_anim` у heroes.json) — множники поверх профілю:
##   leg_amp  — розмах лапок (у єдинорога скінінг жорсткий, і на повному розмаху меш
##              передньої лапки «відривається» від грудей, а задньої розтягується);
##   leg_lift — згин НИЖНЬОЇ ланки лапки в махові (GAIT_LOWER_BEND).
## Дефолт — 1.0, тобто «як у профілі». Чиста функція.
const DEFAULT_ANIM := {"leg_amp": 1.0, "leg_lift": 1.0}


static func anim_of(def: Dictionary) -> Dictionary:
	var out := DEFAULT_ANIM.duplicate()
	var a = def.get("rig_anim", {})
	if typeof(a) == TYPE_DICTIONARY:
		for k in (a as Dictionary).keys():
			if out.has(k):
				out[k] = maxf(0.0, float((a as Dictionary)[k]))
	return out


## ─────────────────── природний 4-тактний крок (хода чотирилапого) ───────────────────
## Лапки ставляться НЕ риссю (діагональні пари), а по черзі: задня ліва → передня ліва →
## задня права → передня права, рівними чвертями циклу. Це та сама послідовність, що в
## справжнього коня/лиса на кроці, і саме її просив Nick.
## Індекси лапок — ті самі, що в LEG_ROLES і в Hero3D._legs: 0 fl · 1 fr · 2 bl · 3 br.
const GAIT_PHASE := [0.25, 0.75, 0.0, 0.5]
## Згин НИЖНЬОЇ ланки лапки (коліно/п'ястка) у махові, рад: лапка не волочиться по землі,
## а піднімає копитце. На поштовху (cos φ ≤ 0) ланка випрямлена.
const GAIT_LOWER_BEND := 0.5
## Підйом ВОКСЕЛЬНОЇ лапки в махові, м: там лапка — один меш без коліна, тож «згин»
## емулюємо зсувом угору (те саме число читає Hero3D).
const GAIT_PAW_LIFT := 0.03
## Легке погойдування корпусу на кроці: таз кренить навколо модельного Z на частоті циклу,
## хребет хвилює по тангажу на подвоєній, хвіст відмахує ПРОТИ крену тазу.
const GAIT_HIP_ROLL := 0.03
const GAIT_SPINE_FLEX := 0.04
const GAIT_TAIL_YAW := 0.1


## Зсув фази лапки в циклі кроку (0…1). Чиста функція — саме її перевіряє тест.
## Індекс поза 0…3 — 0.0 (краще рівний крок, ніж падіння).
static func gait_phase(leg_index: int) -> float:
	if leg_index < 0 or leg_index >= GAIT_PHASE.size():
		return 0.0
	return float(GAIT_PHASE[leg_index])


## Підйом копитця в махові (0…1): лапка йде ВПЕРЕД, поки cos φ > 0 — саме тоді вона й
## має відірватись від землі; на контакті й поштовху — нуль (ланка випрямлена).
static func gait_lift(phi: float) -> float:
	return maxf(0.0, cos(phi))


## Підскок танцю (0…1): тільки додатна половина синуса, згладжена smoothstep — без
## гострих розворотів на кінцях, які читались як смикання. Один підскок на біт.
static func dance_bounce(t: float, bps: float) -> float:
	return smoothstep(0.0, 1.0, maxf(0.0, sin(TAU * t * bps)))


## Вага підйому ПЕРЕДНЬОЇ лапки в танці (0…1): лапки чергуються на кожен біт, а перехід
## розмазаний на `ease_sec` секунд, тож замість клацання виходить перекат ваги.
## `leg_index` — 0 (передня ліва) або 1 (передня права).
static func dance_leg_weight(t: float, leg_index: int, bps: float, ease_sec: float) -> float:
	if bps <= 0.0:
		return 0.0
	var beat := int(floor(t * bps))
	var since := t - float(beat) / bps
	var e := smoothstep(0.0, 1.0, clampf(since / maxf(ease_sec, 0.0001), 0.0, 1.0))
	# на цьому біті піднята лапка (beat % 2), на минулому — інша: перекочуємо вагу
	return e if (beat % 2) == leg_index else 1.0 - e


## Посадка обличчя: дефолти + `rig_face` із даних. Чиста функція.
## `layout` — рядок ("front"/"side"), решта ключів — числа.
static func face_of(def: Dictionary) -> Dictionary:
	var out := DEFAULT_FACE.duplicate()
	var f = def.get("rig_face", {})
	if typeof(f) == TYPE_DICTIONARY:
		for k in (f as Dictionary).keys():
			if not out.has(k):
				continue
			if typeof(out[k]) == TYPE_STRING:
				out[k] = String((f as Dictionary)[k])
			else:
				out[k] = float((f as Dictionary)[k])
	return out


# ─────────────────────────── розкладка кісток за іменами ───────────────────────────

## Чиста функція: імена кісток → ролі. Розуміє і Mixamo-подібні імена
## (mixamorig:LeftUpLeg, Hips, Spine1, Neck, Head), і «людські» (Bone_Tail_02, ear.L,
## front_leg_R). Передні лапки в humanoid-ригах на чотирилапій моделі — це руки
## (Arm/Shoulder/ForeArm/Hand), задні — ноги (UpLeg/Thigh/Leg/Foot).
## Повертає {роль: індекс}, "tail" → Array[int] (від основи до кінчика).
## Ролі, яких не знайшли, у словнику просто відсутні.
static func map_bones_by_name(names: Array) -> Dictionary:
	var out := {}
	var best := {}          ## роль → бал найкращого кандидата (менше = краще)
	var tail := []          ## [[номер, індекс], …]
	for i in range(names.size()):
		var raw := String(names[i])
		var n := raw.to_lower().replace(" ", "")
		# префікс експортера (mixamorig:LeftArm, Armature|Hips)
		var cut := maxi(n.rfind(":"), n.rfind("|"))
		if cut >= 0:
			n = n.substr(cut + 1)
		if n.is_empty():
			continue
		if _is_end_bone(n):
			continue
		if n.contains("tail"):
			tail.append([_trailing_number(n), i])
			continue
		if n.contains("ear"):
			var side_e := _side_of(n)
			if side_e != 0:
				_keep(out, best, "ear_l" if side_e < 0 else "ear_r", i, 0)
			continue
		if n.contains("head"):
			_keep(out, best, "head", i, 0)
			continue
		if n.contains("neck"):
			_keep(out, best, "neck", i, _trailing_number(n))
			continue
		var leg_score := _leg_score(n)
		if leg_score >= 0:
			var side := _side_of(n)
			if side == 0:
				continue
			var front := _is_front_limb(n)
			var role := ("fl" if side < 0 else "fr") if front else ("bl" if side < 0 else "br")
			_keep(out, best, role, i, leg_score)
			continue
		if n.contains("hips") or n.contains("pelvis"):
			_keep(out, best, "hips", i, 0)
			continue
		if n.contains("spine") or n.contains("chest") or n.contains("torso"):
			_keep(out, best, "spine", i, _trailing_number(n))
			continue
		if n == "root" or n.contains("hip"):
			_keep(out, best, "hips", i, 5)      # запасний варіант, поступається справжнім hips
	if not tail.is_empty():
		tail.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
		var chain: Array[int] = []
		for e in tail:
			chain.append(int(e[1]))
		out["tail"] = chain
	return out


## Кістка-«хвостик» ієрархії (Mixamo HeadTop_End, Blender *_tip): анімувати її нема сенсу.
static func _is_end_bone(n: String) -> bool:
	for suffix in ["_end", ".end", "_tip", ".tip", "nub", "_null"]:
		if n.ends_with(suffix):
			return true
	return false


## −1 ліворуч, +1 праворуч, 0 — бік не визначено.
static func _side_of(n: String) -> int:
	if n.begins_with("l_") or n.begins_with("left") or n.contains("_left") or n.contains("left_"):
		return -1
	if n.begins_with("r_") or n.begins_with("right") or n.contains("_right") or n.contains("right_"):
		return 1
	if n.ends_with("_l") or n.ends_with(".l") or n.ends_with("-l") or n.ends_with("l"):
		# «…l» приймаємо лише коли перед ним роздільник або цифра (leg_l, ear.L, Bone2L)
		if n.length() >= 2 and (n[n.length() - 2] in ["_", ".", "-"] or n[n.length() - 2].is_valid_int()):
			return -1
	if n.ends_with("_r") or n.ends_with(".r") or n.ends_with("-r") or n.ends_with("r"):
		if n.length() >= 2 and (n[n.length() - 2] in ["_", ".", "-"] or n[n.length() - 2].is_valid_int()):
			return 1
	if n.contains("left"):
		return -1
	if n.contains("right"):
		return 1
	return 0


## Бал «наскільки це ВЕРХНЯ кістка лапки» (0 — саме вона, більше — нижче по нозі).
## −1 — це взагалі не лапка.
static func _leg_score(n: String) -> int:
	if n.contains("upleg") or n.contains("thigh") or n.contains("upperleg"):
		return 0
	if n.contains("forearm") or n.contains("lowerarm"):
		return 2
	if n.contains("shoulder") or n.contains("clavicle"):
		return 1
	if n.contains("arm"):
		return 0
	if n.contains("hand") or n.contains("paw") or n.contains("foot") or n.contains("toe"):
		return 3
	if n.contains("leg"):
		return 1
	return -1


## Передня лапка чи задня. Явні слова сильніші за humanoid-евристику.
static func _is_front_limb(n: String) -> bool:
	if n.contains("front") or n.contains("fore") and not n.contains("forearm"):
		return true
	if n.contains("hind") or n.contains("rear") or n.contains("back"):
		return false
	if n.contains("forearm"):
		return true
	return n.contains("arm") or n.contains("shoulder") or n.contains("clavicle") \
		or n.contains("hand") or n.contains("paw")


## Число в кінці імені (Spine2 → 2, Tail_03 → 3, Neck → 0).
static func _trailing_number(n: String) -> int:
	var digits := ""
	for i in range(n.length() - 1, -1, -1):
		if n[i].is_valid_int():
			digits = n[i] + digits
		else:
			break
	return int(digits) if digits != "" else 0


static func _keep(out: Dictionary, best: Dictionary, role: String, idx: int, score: int) -> void:
	if not out.has(role) or score < int(best.get(role, 1 << 30)):
		out[role] = idx
		best[role] = score


# ───────────────────────── розкладка кісток за геометрією ─────────────────────────

## Запасний варіант, коли імена нічого не сказали (Meshy інколи дає Bone_0…Bone_26).
## `_names` тут не потрібні (лишились у сигнатурі парою до map_bones_by_name і заради звітів),
## origins — глобальні (у координатах скелета) позиції спокою кісток, front — ±1 по Z.
## Логіка: найнижчі кістки з батьком вище — це чотири лапки (ділимо по знаку x і z);
## найвища — голова, вище за неї — вуха; позаду тазу на висоті тазу — хвіст.
static func map_bones_by_geometry(_names: Array, parents: Array, origins: Array, front: float) -> Dictionary:
	var out := {}
	var n := origins.size()
	if n == 0:
		return out
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for p in origins:
		lo = lo.min(p)
		hi = hi.max(p)
	var mid_y := lo.y + (hi.y - lo.y) * 0.45
	var mid_z := lo.z + (hi.z - lo.z) * 0.5
	# 1) чотири лапки: серед кісток нижньої половини беремо в кожному квадранті найВИЩУ
	#    (це стегно/плече, а не ступня) — саме її крутить галоп
	var quad := {}
	for i in range(n):
		var p: Vector3 = origins[i]
		if p.y >= mid_y:
			continue
		if absf(p.x) < (hi.x - lo.x) * 0.08:
			continue                                   # по центру — це хребет/хвіст, не лапка
		var left := p.x < 0.0
		var is_front := (p.z - mid_z) * front > 0.0
		var key := ("fl" if left else "fr") if is_front else ("bl" if left else "br")
		if not quad.has(key) or origins[quad[key]].y < p.y:
			quad[key] = i
	for k in quad.keys():
		out[k] = quad[k]
	# 2) таз — найнижча центральна кістка (або корінь ієрархії)
	var hips := -1
	for i in range(n):
		if int(parents[i]) < 0:
			hips = i
			break
	for i in range(n):
		var p: Vector3 = origins[i]
		if absf(p.x) > (hi.x - lo.x) * 0.08 or p.y >= mid_y:
			continue
		if hips < 0 or p.y < origins[hips].y:
			hips = i
	if hips >= 0:
		out["hips"] = hips
	# 3) голова — найвища центральна кістка попереду тазу; вуха — центральні вище за неї
	var head := -1
	for i in range(n):
		var p: Vector3 = origins[i]
		if absf(p.x) > (hi.x - lo.x) * 0.2:
			continue
		if hips >= 0 and (p.z - origins[hips].z) * front <= 0.0:
			continue
		if head < 0 or p.y > origins[head].y:
			head = i
	if head >= 0:
		out["head"] = head
		var ears := []
		for i in range(n):
			if i == head:
				continue
			var p: Vector3 = origins[i]
			if p.y > origins[head].y and absf(p.x) > 0.0:
				ears.append(i)
		ears.sort_custom(func(a, b): return float(origins[a].x) < float(origins[b].x))
		if ears.size() >= 2:
			out["ear_l"] = ears[0]
			out["ear_r"] = ears[ears.size() - 1]
		# шия — між тазом і головою по висоті, теж центральна
		var neck := -1
		for i in range(n):
			if i == head or i == hips:
				continue
			var p: Vector3 = origins[i]
			if absf(p.x) > (hi.x - lo.x) * 0.1:
				continue
			if p.y < mid_y or p.y > origins[head].y:
				continue
			if neck < 0 or p.y > origins[neck].y:
				neck = i
		if neck >= 0:
			out["neck"] = neck
	# 4) хребет — центральна кістка між тазом і шиєю
	if hips >= 0:
		var spine := -1
		for i in range(n):
			if out.values().has(i):
				continue
			var p: Vector3 = origins[i]
			if absf(p.x) > (hi.x - lo.x) * 0.1 or p.y < origins[hips].y:
				continue
			if spine < 0 or p.y < origins[spine].y:
				spine = i
		if spine >= 0:
			out["spine"] = spine
		# 5) хвіст — центральні кістки ЗА тазом (проти напрямку погляду), не вище за таз
		var tail: Array[int] = []
		for i in range(n):
			if out.values().has(i):
				continue
			var p: Vector3 = origins[i]
			if absf(p.x) > (hi.x - lo.x) * 0.12:
				continue
			if (p.z - origins[hips].z) * front < 0.0:
				tail.append(i)
		tail.sort_custom(func(a, b): return (origins[a].z - origins[b].z) * front > 0.0)
		if not tail.is_empty():
			out["tail"] = tail
	return out


# ──────────────────────────────── зони кольорів ────────────────────────────────

## Чиста функція: символ палітри для вершини. `local` — частки габариту ЗОНИ (див. local_of)
## у «нормалізованій» системі: x — зліва направо, y — ЗНИЗУ ВГОРУ (справжня вертикаль моделі),
## z — ВІД ПОТИЛИЦІ ДО ПЕРЕДУ (1.0 = найпередніша точка, куди б модель не дивилась).
## Саме тому морда рахується як «перед × низ», а животик — лише по y.
##
## `above` має сенс лише для ролі "tuft": true — вершина справді стирчить над черепом
## (акцентний колір), false — це просто череп під кісткою чубчика, і тоді `local` МАЄ бути
## рахований у коробці ГОЛОВИ, бо вершина йде звичайними правилами голови (морда/…/o).
static func zone_for(role: String, local: Vector3, zones: Dictionary, above := true) -> String:
	var z := zones if not zones.is_empty() else DEFAULT_ZONES
	match role:
		"head":
			if local.z >= 1.0 - float(z.get("muzzle_depth", 0.4)) \
					and local.y <= float(z.get("muzzle_height", 0.55)):
				return ZONE_CREAM
			return ZONE_MAIN
		"ear_l", "ear_r":
			# вухо цілком темне (обід), і лише передня половина — рожева серединка
			return ZONE_INNER if local.z >= 1.0 - float(z.get("ear_inner", 0.55)) else ZONE_EAR
		"nose":
			# писок увесь кремовий; темний лише справжній носик — передні `nose_tip` глибини
			# І верхня половина писка (нижче — губа з підборіддям, вони теж кремові)
			if local.z >= 1.0 - float(z.get("nose_tip", 0.22)) and local.y >= NOSE_TIP_Y:
				return ZONE_DARK
			return ZONE_CREAM
		"tuft":
			# чубчик/камінець на маківці — акцентний, але лише те, що стирчить над черепом;
			# решта гілки `tuft` — це сама голова (див. above у _paint)
			if above:
				return ZONE_TIP
			# …крім вузького обідка ПІД чубчиком: між вухами там світилась помаранчева
			# щілина, тож фарбуємо її темнішим золотом (зона `u`)
			if local.y >= 1.0 - TUFT_ABOVE - TUFT_BASE:
				return ZONE_TUFT_BASE
			return zone_for("head", local, z)
		"mane", "horn":
			# без стилю грива й ріг просто акцентні; пояси й смужки домальовує
			# RigStyles.face_paint (див. `rig_style` у heroes.json)
			return ZONE_TIP
		"fl", "fr", "bl", "br":
			return ZONE_DARK if local.y <= float(z.get("hoof", 0.25)) else ZONE_MAIN
		"tail":
			var tip := float(z.get("tail_tip", 0.35))
			# хвіст може лежати назад або стирчати вгору — кінчиком вважаємо обидва краї
			return ZONE_CREAM if local.z <= tip or local.y >= 1.0 - tip else ZONE_MAIN
		"hips", "spine", "neck":
			return ZONE_BELLY if local.y <= float(z.get("belly", 0.42)) else ZONE_MAIN
	return ZONE_MAIN


## Чесна півширина тулуба: тіло симетричне, а торба висить з ОДНОГО боку — тож за півширину
## беремо той бік, який вужчий (0,98-перцентиль замість максимуму, щоб одна випадкова точка
## не задерла результат). `dx` — зсуви по x від площини симетрії ЗІ ЗНАКОМ. Чиста функція.
## −1.0 — точок замало з якогось боку, рахувати нема з чого.
static func torso_half_width(dx: Array, min_count: int = BAG_MIN) -> float:
	var left := []
	var right := []
	for v in dx:
		var f := float(v)
		if f < 0.0:
			left.append(-f)
		else:
			right.append(f)
	if left.size() < min_count or right.size() < min_count:
		return -1.0
	left.sort()
	right.sort()
	return minf(_percentile(left, 0.98), _percentile(right, 0.98))


## Поріг «це вже торбинка, а не бік»: у моделі сумка — просто наріст на тулубі без власної
## кістки, тож ловимо її геометрією (див. torso_half_width).
## `dx` — зсуви граней тулуба по x від площини симетрії ЗІ ЗНАКОМ (одиниці моделі),
## `k` — rig_zones.bag_x, `min_count` — скільки граней має бути в купці. Чиста функція.
## −1.0 — торби нема: точок мало; за поріг вийшло менше ніж min_count (наросту нема);
## або за поріг вийшло більше ніж BAG_MAX_SHARE тулуба (тіло просто несиметричне).
static func bag_cut(dx: Array, k: float, min_count: int = BAG_MIN) -> float:
	var w := torso_half_width(dx, min_count)
	if w <= 0.00001:
		return -1.0
	# k < 1 дозволено навмисно (дефолт 0,98): бік моделі й так уже «з'їдений» перцентилем,
	# а торба буває пласка. Нижче 0,5 не пускаємо — інакше поріг забере пів тулуба,
	# і на це є ще й BAG_MAX_SHARE
	var cut := w * maxf(k, 0.5)
	var over := 0
	for v2 in dx:
		if absf(float(v2)) > cut:
			over += 1
	if over < min_count or float(over) > float(dx.size()) * BAG_MAX_SHARE:
		return -1.0
	return cut


## З якого боку висить торба: −1 ліворуч, +1 праворуч, 0 — наріст з обох боків
## (тоді це просто широкі боки, фарбуємо симетрично). Чиста функція, пара до bag_cut().
static func bag_side(dx: Array, cut: float) -> int:
	if cut <= 0.0:
		return 0
	var left := 0
	var right := 0
	for v in dx:
		var f := float(v)
		if f < -cut:
			left += 1
		elif f > cut:
			right += 1
	var total := left + right
	if total <= 0:
		return 0
	if float(left) >= float(total) * BAG_ONE_SIDE:
		return -1
	if float(right) >= float(total) * BAG_ONE_SIDE:
		return 1
	return 0


## ВИСТУП грані вбік від тіла. `pts` — грані тулуба як Vector3(dx, y, z), де dx — зсув від
## площини симетрії ЗІ ЗНАКОМ (метри героя), y і z — частки габариту тулуба (0…1).
## Для кожної комірки сітки grid × grid по (y, z) «бік тіла» = SIDE_PCT-перцентиль |dx| серед
## граней цієї комірки; виступ грані = |dx| − цей бік. Так тонкий тулуб і товсті груди мають
## кожен свою півширину, і сумка на боці видно навіть коли вона рівно на габариті моделі.
## Обидва боки йдуть в одну комірку навмисно: перцентиль тоді описує СИМЕТРИЧНЕ тіло, а
## однобокий наріст із нього стирчить. Чиста функція — саме її перевіряє тест.
static func outwardness(pts: Array, grid: int = SIDE_GRID) -> PackedFloat32Array:
	var res := PackedFloat32Array()
	var n := pts.size()
	res.resize(n)
	if n == 0:
		return res
	var g := maxi(grid, 1)
	var cells := {}                 ## ключ комірки → масив |dx|
	var keys := PackedInt32Array()
	keys.resize(n)
	for i in range(n):
		var p: Vector3 = pts[i]
		var gy := clampi(int(p.y * float(g)), 0, g - 1)
		var gz := clampi(int(p.z * float(g)), 0, g - 1)
		var k := gy * g + gz
		keys[i] = k
		if not cells.has(k):
			cells[k] = []
		(cells[k] as Array).append(absf(p.x))
	var half := {}
	for k in cells.keys():
		var a: Array = cells[k]
		a.sort()
		half[k] = _percentile(a, SIDE_PCT)
	for i in range(n):
		res[i] = absf(float((pts[i] as Vector3).x)) - float(half[keys[i]])
	return res


## КУПКИ бічних наростів: грані з виступом > `min_out` (див. outwardness) злипаються по
## сусідству комірок сітки grid × grid, окремо на лівому й правому боці. Повертає список
## купок, кожна — {"idx": PackedInt32Array, "n": int, "side": −1/+1, "ok": bool,
## "center": Vector3(dx, y, z), "size": Vector3(0, dy, dz), "out": максимальний виступ},
## відсортований від найбільшої. `ok` — у купці не менше `min_faces` граней, тобто це
## справді сумка, а не шум децимації. Чиста функція.
static func side_clusters(pts: Array, out: PackedFloat32Array, min_out: float = SIDE_MIN_OUT,
		min_faces: int = SIDE_MIN_FACES, grid: int = SIDE_CLUSTER_GRID) -> Array:
	var g := maxi(grid, 1)
	var cell := {}                  ## ключ комірки → Array[int] індексів граней
	var where := {}                 ## ключ комірки → Vector3i(бік 0/1, gy, gz)
	for i in range(mini(pts.size(), out.size())):
		if out[i] <= min_out:
			continue
		var p: Vector3 = pts[i]
		var sd := 1 if p.x >= 0.0 else 0
		var gy := clampi(int(p.y * float(g)), 0, g - 1)
		var gz := clampi(int(p.z * float(g)), 0, g - 1)
		var k := (sd * g + gy) * g + gz
		if not cell.has(k):
			cell[k] = []
			where[k] = Vector3i(sd, gy, gz)
		(cell[k] as Array).append(i)
	var seen := {}
	var clusters := []
	for start in cell.keys():
		if seen.has(start):
			continue
		seen[start] = true
		var queue := [start]
		var members := PackedInt32Array()
		while not queue.is_empty():
			var c: int = queue.pop_back()
			for i in (cell[c] as Array):
				members.append(int(i))
			var w: Vector3i = where[c]
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var ny: int = w.y + int(dy)
					var nz: int = w.z + int(dz)
					if ny < 0 or nz < 0 or ny >= g or nz >= g:
						continue
					var nk: int = (w.x * g + ny) * g + nz
					if cell.has(nk) and not seen.has(nk):
						seen[nk] = true
						queue.append(nk)
		if members.is_empty():
			continue
		var lo := Vector3.INF
		var hi := -Vector3.INF
		var sum := Vector3.ZERO
		var mx := 0.0
		for i in members:
			var p2: Vector3 = pts[i]
			lo = lo.min(p2)
			hi = hi.max(p2)
			sum += p2
			mx = maxf(mx, float(out[i]))
		var cnt := members.size()
		clusters.append({
			"idx": members,
			"n": cnt,
			"side": 1 if sum.x >= 0.0 else -1,
			"ok": cnt >= min_faces,
			"center": sum / float(cnt),
			"size": Vector3(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z),
			"out": mx,
		})
	clusters.sort_custom(func(a, b): return int(a["n"]) > int(b["n"]))
	return clusters


## Перцентиль уже відсортованого масиву чисел (без інтерполяції).
static func _percentile(sorted: Array, q: float) -> float:
	if sorted.is_empty():
		return 0.0
	var i := clampi(int(float(sorted.size()) * q), 0, sorted.size() - 1)
	return float(sorted[i])


## Частки габариту для вершини (чиста функція, пара до zone_for). `v` і `bounds` мають бути
## В КООРДИНАТАХ МОДЕЛІ (y — вертикаль), інакше «низ» і «перед» переплутаються.
static func local_of(v: Vector3, bounds: AABB, front: float) -> Vector3:
	var s := bounds.size
	var fx := 0.5 if s.x <= 0.00001 else (v.x - bounds.position.x) / s.x
	var fy := 0.5 if s.y <= 0.00001 else (v.y - bounds.position.y) / s.y
	var fz := 0.5
	if s.z > 0.00001:
		fz = (v.z - bounds.position.z) / s.z
		if front < 0.0:
			fz = 1.0 - fz          # модель дивиться в −Z: «перед» — це менші z
	return Vector3(clampf(fx, 0.0, 1.0), clampf(fy, 0.0, 1.0), clampf(fz, 0.0, 1.0))


## «Головна» кістка трикутника — та, за яку голосує більшість його вершин
## (усі три різні → беремо першу). Чиста функція: по ній грань іде в зону.
static func major_bone(a: int, b: int, c: int) -> int:
	if b == c:
		return b
	if a == c:
		return a
	return a


# ──────────────────────────────── збирання ────────────────────────────────

## Зібрати рига під `parent` (це Hero3D._body). def — опис героя з heroes.json,
## colors — {символ палітри: Color}. false — моделі нема або в ній нема скелета:
## Hero3D тоді малює звичайні вокселі.
func build(parent: Node3D, def: Dictionary, colors: Dictionary) -> bool:
	var rig := String(def.get("rig", ""))
	if not rig_exists(rig):
		return false
	var packed = load(rig_path(rig))
	if not (packed is PackedScene):
		push_warning("HeroRig: %s не PackedScene" % rig_path(rig))
		return false
	var inst = (packed as PackedScene).instantiate()
	if not (inst is Node3D):
		if inst != null:
			inst.free()
		return false
	_model = inst as Node3D
	var skels := _model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		_model.free()
		_model = null
		push_warning("HeroRig: у %s нема Skeleton3D" % rig)
		return false
	_skel = skels[0] as Skeleton3D
	for m in _model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(m as MeshInstance3D)
	if _meshes.is_empty():
		_model.free()
		_model = null
		return false

	_zones = zones_of(def)
	_face_cfg = face_of(def)
	_anim_cfg = anim_of(def)
	_marks = marks_of(def)
	# стиль розмальовки («текстура» героя): підміняє кольори символів і вміє малювати
	# грані повз зони (веселка гриви й хвоста, смужки рога, зірочки). Нема поля — {}, і
	# все працює як раніше
	_style = RigStyles.for_def(def)
	_style_name = String(def.get("rig_style", "")) if not _style.is_empty() else ""
	colors = RigStyles.palette_of(_style, colors)
	# скелет усередині .glb може бути і зсунутий, і ПОВЕРНУТИЙ (Blender-риги часто Z-вгору).
	# Тому все, що залежить від «низу» й «переду» — розкладка кісток за геометрією, габарити,
	# зони, посадка обличчя, осі анімації — рахуємо в координатах МОДЕЛІ (там y — вертикаль),
	# а в скелет переводимо вже готове.
	_model_to_skel = _rel_transform(_model, _skel)
	_skel_unit = maxf(_model_to_skel.basis.get_scale().y, 0.0001)
	_map_bones(def)
	_find_lower_legs()
	_front = _front_sign(def)

	# вершини в координатах моделі — з них і зріст, і зони кольорів
	var verts := _gather_vertices()
	var box: AABB = verts["box"]
	if box.size.y < 0.0001:
		push_warning("HeroRig: у %s порожні меші" % rig)
		_model.free()
		_model = null
		_meshes.clear()
		return false
	_scale = HEAD_TOP / maxf(box.size.y, 0.0001)
	_inv_scale = 1.0 / _scale
	_model_box = box          # потрібен _hero_point() — переклад у метри героя (rig_marks)

	_root = Node3D.new()
	_root.name = "Rig"
	_root.scale = Vector3.ONE * _scale
	_root_y0 = -box.position.y * _scale                # лапки на землю (y = 0)
	_root.position.y = _root_y0
	parent.add_child(_root)
	# розворот мордою в −Z робимо на самій моделі, тож усередині скелета
	# «перед» лишається власним переднім боком моделі (_front) — так простіше рахувати зони
	_model.rotation.y = PI if _front > 0.0 else 0.0
	_root.add_child(_model)

	# вихідні масиви мешів тримаємо ТІЛЬКИ в прев'ю (RIG=…): там клавіша M перефарбовує
	# модель у діагностичний вигляд. У грі це були б зайві мегабайти на кожного героя
	if OS.has_environment("RIG"):
		_verts = verts
		_colors = colors
	_paint(verts, colors)
	_prepare_axes()
	_calibrate_signs()
	_build_anchors(verts)
	_ready = true
	if OS.is_stdout_verbose():
		print_verbose("HeroRig %s: кістки %s" % [rig, _bones])
	return true


## Ролі кісток: імена → геометрія → ручні `rig_bones` з даних (найвищий пріоритет).
func _map_bones(def: Dictionary) -> void:
	var names: Array = []
	var parents: Array = []
	var origins: Array = []
	var s2m := _model_to_skel.affine_inverse()      # позиції кісток — у координатах моделі
	for i in range(_skel.get_bone_count()):
		names.append(_skel.get_bone_name(i))
		parents.append(_skel.get_bone_parent(i))
		origins.append(s2m * _skel.get_bone_global_rest(i).origin)
	_bones = map_bones_by_name(names)
	var geo := map_bones_by_geometry(names, parents, origins, _guess_front(origins))
	for role in geo.keys():
		if not _bones.has(role):
			_bones[role] = geo[role]
	var manual = def.get("rig_bones", {})
	if typeof(manual) == TYPE_DICTIONARY:
		for role in (manual as Dictionary).keys():
			var v = (manual as Dictionary)[role]
			if typeof(v) == TYPE_ARRAY:
				var chain: Array[int] = []
				for item in (v as Array):
					var bi := _skel.find_bone(String(item))
					if bi >= 0:
						chain.append(bi)
				if not chain.is_empty():
					_bones[String(role)] = chain
			else:
				var bi2 := _skel.find_bone(String(v))
				if bi2 >= 0:
					_bones[String(role)] = bi2
	_role_cache.clear()


## НИЖНЯ ЛАНКА кожної лапки — перша дитина кістки, яку розкладка дала за роль лапки
## (коліно / п'ястка). Саме її згинає крок, щоб копитце піднімалось у махові; позиції
## кісток лапки при цьому НІКОЛИ не зсуваються — тільки оберти, інакше жорсткий скінінг
## рве меш (передня лапка «відклеюється», задня розтягується).
func _find_lower_legs() -> void:
	_lower_leg.clear()
	if _skel == null:
		return
	for role in LEG_ROLES:
		if not _bones.has(role):
			continue
		var idx := int(_bones[role])
		for i in range(_skel.get_bone_count()):
			if _skel.get_bone_parent(i) == idx:
				_lower_leg[role] = i
				break


## Куди дивиться модель у власних координатах: +1 (морда на +Z) або −1.
## Явне `rig_front` у даних сильніше за евристику «голова попереду тазу».
func _front_sign(def: Dictionary) -> float:
	var f := String(def.get("rig_front", ""))
	if f == "+z":
		return 1.0
	if f == "-z":
		return -1.0
	if _bones.has("head") and _bones.has("hips"):
		var s2m := _model_to_skel.affine_inverse()
		var dz := (s2m * _skel.get_bone_global_rest(int(_bones["head"])).origin).z \
			- (s2m * _skel.get_bone_global_rest(int(_bones["hips"])).origin).z
		if absf(dz) > 0.0001:
			return signf(dz)
	return -1.0


## Груба оцінка переду ДО того, як ролі відомі: найвища кістка проти найнижчої по z.
func _guess_front(origins: Array) -> float:
	if origins.size() < 2:
		return -1.0
	var top := 0
	var bottom := 0
	for i in range(origins.size()):
		if origins[i].y > origins[top].y:
			top = i
		if origins[i].y < origins[bottom].y:
			bottom = i
	var dz: float = origins[top].z - origins[bottom].z
	return signf(dz) if absf(dz) > 0.0001 else -1.0


# ──────────────────────────────── кольори ────────────────────────────────

## Вершини всіх мешів У КООРДИНАТАХ МОДЕЛІ + найважча кістка кожної вершини.
## Габарити по ролях (`role_box`) теж модельні: вуха, хвіст і лапки мають власні ролі,
## тож у коробку голови потрапляють лише вершини голови (морда, ніс, чубчик).
## Повертає {"box": AABB, "per_mesh": [{"surfaces": […]}], "role_box": {роль: AABB}}
func _gather_vertices() -> Dictionary:
	var per_mesh := []
	var box := AABB()
	var first := true
	var role_box := {}
	for mi in _meshes:
		var to_model := _rel_transform(mi, _model)
		var surfaces := []
		var mesh := mi.mesh
		if mesh == null:
			per_mesh.append({"surfaces": surfaces})
			continue
		for s in range(mesh.get_surface_count()):
			var arr: Array = mesh.surface_get_arrays(s)
			if arr.size() <= Mesh.ARRAY_WEIGHTS or arr[Mesh.ARRAY_VERTEX] == null:
				continue
			var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones = arr[Mesh.ARRAY_BONES]
			var weights = arr[Mesh.ARRAY_WEIGHTS]
			var per_vertex := 0
			if bones != null and pos.size() > 0:
				per_vertex = int(bones.size() / pos.size())
			var owner_bone := PackedInt32Array()
			owner_bone.resize(pos.size())
			var mpos := PackedVector3Array()          # вершини в координатах моделі
			mpos.resize(pos.size())
			for v in range(pos.size()):
				var p: Vector3 = to_model * pos[v]
				mpos[v] = p
				if first:
					box = AABB(p, Vector3.ZERO)
					first = false
				else:
					box = box.expand(p)
				var bi := -1
				if per_vertex > 0:
					var bw := -1.0
					for w in range(per_vertex):
						var wt := float(weights[v * per_vertex + w])
						if wt > bw:
							bw = wt
							bi = int(bones[v * per_vertex + w])
				owner_bone[v] = bi
				var role := _role_of(bi)
				if role != "":
					if role_box.has(role):
						role_box[role] = (role_box[role] as AABB).expand(p)
					else:
						role_box[role] = AABB(p, Vector3.ZERO)
			surfaces.append({"arrays": arr, "model": mpos, "bone": owner_bone, "n": per_vertex})
		per_mesh.append({"surfaces": surfaces})
	return {"box": box, "per_mesh": per_mesh, "role_box": role_box}


## Роль кістки з успадкуванням по ієрархії: «LeftHand» дістає роль від «LeftArm»,
## «Spine2» — від «Spine», «HeadTop» — від «Head». Кістки поза мапою → "" (основний колір).
func _role_of(idx: int) -> String:
	if idx < 0:
		return ""
	if _role_cache.has(idx):
		return _role_cache[idx]
	var direct := ""
	for role in _bones.keys():
		var v = _bones[role]
		if typeof(v) == TYPE_ARRAY:
			if (v as Array).has(idx):
				direct = String(role)
				break
		elif int(v) == idx:
			direct = String(role)
			break
	if direct == "":
		var p := _skel.get_bone_parent(idx)
		direct = _role_of(p) if p >= 0 else ""
	_role_cache[idx] = direct
	return direct


## Трикутники всіх поверхонь: індекси трьох вершин, центроїд У КООРДИНАТАХ МОДЕЛІ й
## головна кістка грані (більшість із трьох вершин, див. major_bone). Плаский шейдинг,
## зони кольорів і пошук торбинки рахуються саме по гранях, тож список збираємо один раз.
## Повертає масив (по мешу) масивів (по поверхні) із {"tri", "cent", "bone"}.
func _gather_faces(verts: Dictionary) -> Array:
	var out := []
	for md in (verts["per_mesh"] as Array):
		var per_surface := []
		for sd in ((md as Dictionary).get("surfaces", []) as Array):
			var d: Dictionary = sd
			var arr: Array = d["arrays"]
			var mpos: PackedVector3Array = d["model"]
			var owner_bone: PackedInt32Array = d["bone"]
			var tri := PackedInt32Array()
			var src = arr[Mesh.ARRAY_INDEX]
			if src != null and (src as PackedInt32Array).size() >= 3:
				tri = src as PackedInt32Array
			else:
				# меш без індексів — трикутники йдуть підряд по три вершини
				tri.resize(mpos.size() - mpos.size() % 3)
				for i in range(tri.size()):
					tri[i] = i
			var n := int(tri.size() / 3)
			var cent := PackedVector3Array()
			cent.resize(n)
			var fb := PackedInt32Array()
			fb.resize(n)
			for f in range(n):
				var a := tri[f * 3]
				var b := tri[f * 3 + 1]
				var c := tri[f * 3 + 2]
				cent[f] = (mpos[a] + mpos[b] + mpos[c]) / 3.0
				fb[f] = major_bone(owner_bone[a], owner_bone[b], owner_bone[c])
			per_surface.append({"tri": tri, "cent": cent, "bone": fb})
		out.append(per_surface)
	return out


## Точка з координат МОДЕЛІ в «геройські» метри — рівно ті, у яких задаються коробки
## `rig_marks` і всі константи Hero3D: початок між лапками на землі, перед героя = −z.
## Це той самий перерахунок, що робить вузол _root (масштаб + підйом) і розворот _model
## мордою в −Z, тільки без дерева сцени.
func _hero_point(p: Vector3) -> Vector3:
	var q := p
	if _front > 0.0:
		q = Vector3(-p.x, p.y, -p.z)          # модель повернута на PI навколо вертикалі
	return Vector3(q.x * _scale, (p.y - _model_box.position.y) * _scale, q.z * _scale)


## Пошук торбинки на боці тулуба: збираємо зсуви по x від площини симетрії (зі знаком)
## для центроїдів ГРАНЕЙ тулуба в середній смузі по висоті й питаємо bag_cut(), з якого
## відступу починається наріст. Заразом рахуємо габарит тулуба в метрах героя (_torso_box) —
## по ньому в прев'ю видно, які числа писати в `rig_marks`.
## Повертає {"cx": площина симетрії, "cut": поріг, "side": бік торби (−1/0/+1),
## "half": чесна півширина тулуба}; cut = −1 — торби нема. Якщо наріст лише з одного боку
## (`side` ≠ 0), протилежний бік тулуба не фарбуємо взагалі — інакше бірюза лягала б плямами
## і там, де сумки нема.
func _bag_of(verts: Dictionary, faces: Array) -> Dictionary:
	var role_box: Dictionary = verts["role_box"]
	var box: AABB = verts["box"]
	var cx := box.get_center().x          # площина симетрії тіла (лапки з обох боків)
	var offsets := []
	var max_abs := 0.0
	var torso_first := true
	for m in range(faces.size()):
		for sf in (faces[m] as Array):
			var cent: PackedVector3Array = (sf as Dictionary)["cent"]
			var fb: PackedInt32Array = (sf as Dictionary)["bone"]
			for f in range(cent.size()):
				var role := _role_of(fb[f])
				if not TORSO_ROLES.has(role) or not role_box.has(role):
					continue
				# габарит ВСЬОГО тулуба в метрах героя — по ньому вибирають коробку
				# для `rig_marks` (друкується в face_report)
				var hp := _hero_point(cent[f])
				if torso_first:
					_torso_box = AABB(hp, Vector3.ZERO)
					torso_first = false
				else:
					_torso_box = _torso_box.expand(hp)
				var ly := local_of(cent[f], role_box[role], _front).y
				if ly < BAG_Y_LO or ly > BAG_Y_HI:
					continue
				var dx := cent[f].x - cx
				offsets.append(dx)
				max_abs = maxf(max_abs, absf(dx))
	# стиль із сердечком на грудях сам малює акцент тулуба — геометричний пошук торбинки
	# тоді вимикаємо: у єдинорога він ловив «сумку» на широких грудях і ляпав туди рожеве
	var heart := _style.has("chest_heart")
	var cut := -1.0 if heart else bag_cut(offsets, float(_zones.get("bag_x", 0.98)))
	var side := bag_side(offsets, cut)
	var half := torso_half_width(offsets)
	# діагностика для прев'ю: коли купка не знайшлась, по цих числах видно, куди тягти bag_x
	_bag_info = {
		"faces": offsets.size(),
		"half": half,
		"max": max_abs,
		"cut": cut,
		"side": side,
		"heart": heart,
	}
	return {"cx": cx, "cut": cut, "side": side, "half": half}


## Пошук БІЧНИХ НАРОСТІВ (сумки лисеняти) — на відміну від `bag_x`, локальний: див.
## outwardness / side_clusters. Працює в МЕТРАХ ГЕРОЯ, бере лише грані тулуба в смузі
## BAG_Y_LO…BAG_Y_HI (не шия й не пузо). `mark_cx` — площина симетрії в метрах героя.
## Повертає прапорці по гранях у тій самій формі, що й _gather_faces (меш → поверхня →
## PackedByteArray): 0 — нічого, 1 — грань у прийнятій купці (зона `m`), 2 — кандидат із
## відкинутої (замалої) купки. Заразом складає _side_info для face_report.
func _side_scan(faces: Array, mark_cx: float) -> Array:
	_side_info = []
	var pts := []
	var ref := []                   ## Vector3i(меш, поверхня, грань) для кожної точки
	if _torso_box.size.y > 0.0001:
		for m in range(faces.size()):
			var surfaces: Array = faces[m]
			for s in range(surfaces.size()):
				var sf: Dictionary = surfaces[s]
				var cent: PackedVector3Array = sf["cent"]
				var fb: PackedInt32Array = sf["bone"]
				for f in range(cent.size()):
					if not TORSO_ROLES.has(_role_of(fb[f])):
						continue
					var hp := _hero_point(cent[f])
					var l := local_of(hp, _torso_box, -1.0)
					pts.append(Vector3(hp.x - mark_cx, l.y, l.z))
					ref.append(Vector3i(m, s, f))
	var hit := {}                   ## Vector3i(меш, поверхня, грань) → 1 купка · 2 кандидат
	if not pts.is_empty():
		var out := outwardness(pts)
		# смуга по висоті: сумка висить на боці, а не на шиї й не під пузом
		for i in range(pts.size()):
			var ly := float((pts[i] as Vector3).y)
			if ly < BAG_Y_LO or ly > BAG_Y_HI:
				out[i] = -1.0
		for cl in side_clusters(pts, out):
			var c: Dictionary = cl
			_side_info.append({
				"n": int(c["n"]), "side": int(c["side"]), "ok": bool(c["ok"]),
				"center": c["center"], "size": c["size"], "out": float(c["out"]),
			})
			var mark := 1 if bool(c["ok"]) else 2
			for i in (c["idx"] as PackedInt32Array):
				hit[ref[i]] = mark
	# прапорці в тій самій формі, що й _gather_faces (меш → поверхня → байти по гранях)
	var flags := []
	for m in range(faces.size()):
		var per_surface := []
		var surfaces2: Array = faces[m]
		for s in range(surfaces2.size()):
			var cent2: PackedVector3Array = (surfaces2[s] as Dictionary)["cent"]
			var fl := PackedByteArray()
			fl.resize(cent2.size())
			if not hit.is_empty():
				for f in range(cent2.size()):
					var k := Vector3i(m, s, f)
					if hit.has(k):
						fl[f] = int(hit[k])
			per_surface.append(fl)
		flags.append(per_surface)
	return flags


## Замінити меші на копії з КОЛЬОРАМИ ГРАНЕЙ. Модель без текстур і матеріалів —
## колір іде виключно звідси, а шейдер вокселів (voxel.gdshader) читає саме COLOR,
## тож ригнутий герой виглядає з того самого матеріалу, що й воксельні частини.
##
## Кольори пишемо ТОЧНО ті, що в палітрі героя (o = "color" з heroes.json), без жодних
## перетворень — рівно як VoxelBuilder.build() робить SurfaceTool.set_color(Color(hex)).
## Обидва шляхи кладуть значення в ARRAY_COLOR однаково, тож зсуву sRGB/лінійний між
## ригом і вокселями бути не може. Якщо колір усе одно блідий — це або залишений
## імпортований матеріал (тому нижче чистимо override-и й ставимо свій material_override),
## або rim-підсвітка шейдера: на гладкій моделі граней у рази більше, ніж на вокселях,
## тож біла облямівка «з'їдає» колір — для рига приглушуємо її вдвічі.
##
## Меш перебудовуємо РОЗІНДЕКСОВАНИМ: у кожного трикутника свої три вершини, колір і нормаль
## однакові на всю грань. Так зникають дві біди спільних вершин: кольори більше не
## розмазуються градієнтом на межі зон (кожна грань цілком одного кольору) і зникає зерниста
## діагональна тінь на пласких боках (нормаль — геометрична нормаль грані, а не усереднена
## по вершині). Вершин стає ×3 (~24 тис.) — для однієї моделі це дрібниця.
## Кістки й ваги (JOINTS/WEIGHTS) просто копіюються з вихідних вершин, тож скінінг цілий.
##
## Зверху на зони лягає СТИЛЬ героя (`rig_style`, див. RigStyles): він може перекинути грань
## у нову роль (грива/ріг), підмінити символ зони (копитця `k` → рожевий `m`) або віддати
## готовий колір повз зони (веселка гриви й хвоста, золоті смужки рога, зірочки). Тому в
## _flat_arrays їде вже готовий колір грані, а не символ.
func _paint(verts: Dictionary, colors: Dictionary) -> void:
	var role_box: Dictionary = verts["role_box"]
	var per_mesh: Array = verts["per_mesh"]
	var mat := _rig_material()
	_zone_counts.clear()
	var faces := _gather_faces(verts)
	var bag := _bag_of(verts, faces)
	var bag_cx := float(bag.get("cx", 0.0))
	var bag_x := float(bag.get("cut", -1.0))
	var bag_side_sign := int(bag.get("side", 0))
	# ручні позначки `rig_marks` задані в МЕТРАХ ГЕРОЯ, тож площину симетрії й півширину
	# тулуба теж переводимо туди (півширини нема — беремо пів габариту тулуба)
	var mark_cx := _hero_point(Vector3(bag_cx, _model_box.position.y, 0.0)).x
	var mark_half := float(bag.get("half", -1.0)) * _scale
	if mark_half <= 0.0:
		mark_half = _torso_box.size.x * 0.5
	# бічні нарости (сумки) — локальний пошук, працює й там, де `bag_x` сліпий.
	# Фарбуємо їх лише коли стиль сам не малює акценти тулуба (сердечко єдинорога)
	var side_flags := _side_scan(faces, mark_cx)
	var side_paint := not _style.has("chest_heart")
	for m in range(_meshes.size()):
		var mi := _meshes[m]
		if mi.mesh == null or m >= per_mesh.size():
			continue
		var surfaces: Array = (per_mesh[m] as Dictionary).get("surfaces", [])
		if surfaces.is_empty():
			continue
		var mesh_faces: Array = faces[m]
		var out := ArrayMesh.new()
		for s in range(surfaces.size()):
			var sd: Dictionary = surfaces[s]
			var fd: Dictionary = mesh_faces[s]
			var face_cols := PackedColorArray()
			var tri: PackedInt32Array = fd["tri"]
			var cent: PackedVector3Array = fd["cent"]
			var fb: PackedInt32Array = fd["bone"]
			face_cols.resize(cent.size())
			for f in range(cent.size()):
				var role0 := _role_of(fb[f])     ## роль ДО стилю (грива лишається гривою)
				var role := role0
				var zone := ZONE_MAIN
				var styled = null            ## колір від стилю повз зони (Color або null)
				var style_tag := ""
				var sflag := int((side_flags[m][s] as PackedByteArray)[f])
				# діагностика прев'ю (клавіша M): купки бічних наростів — магентою
				if _debug_sides and sflag > 0:
					face_cols[f] = DEBUG_SIDE_OK if sflag == 1 else DEBUG_SIDE_TRY
					_zone_counts["M"] = int(_zone_counts.get("M", 0)) + 1
					continue
				if role != "" and role_box.has(role):
					# чубчик: його кістка сидить усередині черепа, тож роль `tuft` дістається
					# і звичайним граням голови. Акцентні лише ті, що стирчать над черепом,
					# решту рахуємо в коробці ГОЛОВИ і женемо звичайними правилами голови
					var box_role := role
					var above := true
					if role == "tuft" and role_box.has("head"):
						var hb: AABB = role_box["head"]
						box_role = "head"
						above = cent[f].y > hb.position.y + hb.size.y * (1.0 - TUFT_ABOVE)
					var l0 := local_of(cent[f], role_box[box_role], _front)
					var hp := _hero_point(cent[f])
					# частки габариту ВСЬОГО тулуба (метри героя, перед = −z): у них стиль
					# малює сердечко на грудях і латки на боках. Рахуємо їх ГЕОМЕТРИЧНО, а не
					# за роллю: пасма гриви єдинорога звисають по ПЕРЕДУ шиї — роль у тих
					# граней `mane`, а лежать вони рівно на грудях, де й має бути сердечко
					var torso_l := Vector3(-1.0, -1.0, -1.0)
					if not MARK_SKIP_ROLES.has(role0) and _torso_box.size.y > 0.0001 \
							and _torso_box.grow(MARK_BOX_PAD).has_point(hp):
						torso_l = local_of(hp, _torso_box, -1.0)
					# ── ПОЗНАЧКИ ПЕРШИМИ (сердечко, латки, `rig_marks`, торбинка) ──
					# Раніше вони рахувались після поясів гриви й хвоста, і грива, що впала
					# на груди, з'їдала сердечко цілком. Тепер пояси працюють лише там, де
					# позначки нема (урок 09.09, docs/MEMORY.md)
					var marked := false
					if not MARK_SKIP_ROLES.has(role0):
						var mp := RigStyles.mark_paint(_style, torso_l)
						if not mp.is_empty():
							styled = mp["color"]
							style_tag = String(mp.get("tag", "r"))
							marked = true
						elif not _marks.is_empty() \
								and mark_hit(_marks, hp, role0, l0, hp.x - mark_cx, mark_half):
							# ручні позначки з даних — найнадійніший спосіб, коли геометрія сліпа
							zone = RigStyles.swap_zone(_style, ZONE_MARK)
							marked = true
						elif side_paint and sflag == 1:
							# бічний наріст (сумка): купка граней, що стирчать за локальну
							# півширину тулуба — див. _side_scan / outwardness
							zone = RigStyles.swap_zone(_style, ZONE_MARK)
							marked = true
					if not marked:
						# стиль може перекинути грань у нову роль (грива/ріг), поки їх нема
						# в rig_bones: тоді й частки габариту рахуються під нову зону
						var rm := RigStyles.remap_role(_style, role, l0,
							_bones.has("mane"), _bones.has("horn"))
						role = String(rm["role"])
						var l: Vector3 = rm["local"]
						zone = zone_for(role, l, _zones, above)
						# стара евристика торбинки за `bag_x` — лишилась як запасний варіант
						var dx := cent[f].x - bag_cx
						if bag_x > 0.0 and TORSO_ROLES.has(role) \
								and absf(dx) > bag_x \
								and (bag_side_sign == 0 or signf(dx) == float(bag_side_sign)) \
								and l.y >= BAG_Y_LO and l.y <= BAG_Y_HI:
							zone = ZONE_MARK
						zone = RigStyles.swap_zone(_style, zone)
						# і нарешті — готовий колір повз зони (пояси гриви й хвоста, смужки
						# рога, копитця по лапках, зірочки)
						var paint := RigStyles.face_paint(_style, role, l,
							_chain_t(role, fb[f], l), _face_key(cent[f]), torso_l, zone)
						if not paint.is_empty():
							styled = paint["color"]
							style_tag = String(paint.get("tag", "s"))
				if styled != null:
					var sc: Color = styled
					face_cols[f] = sc
					_zone_counts[style_tag] = int(_zone_counts.get(style_tag, 0)) + 1
				else:
					var zc: Color = colors.get(zone, colors.get(ZONE_MAIN, Color.WHITE))
					face_cols[f] = zc
					_zone_counts[zone] = int(_zone_counts.get(zone, 0)) + 1
			var flags := 0
			if int(sd.get("n", 0)) == 8:
				flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
				_flat_arrays(sd, tri, face_cols), [], {}, flags)
			out.surface_set_material(s, mat)
		mi.mesh = out
		# імпортер .glb міг лишити на MeshInstance свій матеріал (білий albedo) —
		# він сильніший за матеріал поверхні й з'їв би наші вершинні кольори
		for s2 in range(mi.get_surface_override_material_count()):
			mi.set_surface_override_material(s2, null)
		mi.material_override = mat


## Положення грані вздовж ланцюжка кісток ролі: 0 — основа, 1 — кінчик; −1 — ланцюжка нема
## (одна кістка на весь хвіст/гриву), і тоді RigStyles.face_color бере частки габариту.
## Кістка грані може бути й НАЩАДКОМ ланки ланцюжка (роль успадковується) — тоді піднімаємось
## по батьках, поки не потрапимо в ланцюжок.
func _chain_t(role: String, bone_idx: int, _l: Vector3) -> float:
	var v = _bones.get(role, null)
	if typeof(v) != TYPE_ARRAY:
		return -1.0
	var chain: Array = v
	if chain.size() < 2:
		return -1.0
	var idx := bone_idx
	while idx >= 0 and not chain.has(idx):
		idx = _skel.get_bone_parent(idx)
	if idx < 0:
		return -1.0
	return float(chain.find(idx)) / float(chain.size() - 1)


## Детермінований «сід» грані з її центроїда (заокруглений до 0,1 мм): та сама модель —
## ті самі зірочки при кожному запуску, і від порядку мешів чи поверхонь нічого не залежить.
static func _face_key(cent: Vector3) -> int:
	return hash(Vector3i(roundi(cent.x * 10000.0), roundi(cent.y * 10000.0), roundi(cent.z * 10000.0)))


## Масиви розіндексованої поверхні: на кожен трикутник — три власні вершини з
## геометричною нормаллю грані й ГОТОВИМ кольором грані (зона вже перетворена на колір
## у _paint: там же працює стиль розмальовки). Позиції, кістки й ваги копіюються
## з вихідних вершин (у ЛОКАЛЬНИХ координатах меша — саме їх чекає ArrayMesh),
## індексів на виході нема. Напрямок нормалі звіряємо з вихідними нормалями моделі:
## обхід трикутників в експортерах буває який завгодно, а вивернута нормаль зробила б
## грань чорною.
func _flat_arrays(sd: Dictionary, tri: PackedInt32Array, face_cols: PackedColorArray) -> Array:
	var arr: Array = sd["arrays"]
	var src_pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var src_norm := PackedVector3Array()
	if arr[Mesh.ARRAY_NORMAL] != null:
		src_norm = arr[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var has_norm := src_norm.size() == src_pos.size()
	var src_bones = arr[Mesh.ARRAY_BONES]
	var src_weights = arr[Mesh.ARRAY_WEIGHTS]
	var per_v := int(sd.get("n", 0))
	var n := int(tri.size() / 3)
	var count := n * 3
	var pos := PackedVector3Array()
	pos.resize(count)
	var norm := PackedVector3Array()
	norm.resize(count)
	var cols := PackedColorArray()
	cols.resize(count)
	var has_skin: bool = per_v > 0 and src_bones != null and src_weights != null
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	if has_skin:
		bones.resize(count * per_v)
		weights.resize(count * per_v)
	for f in range(n):
		var i0 := tri[f * 3]
		var i1 := tri[f * 3 + 1]
		var i2 := tri[f * 3 + 2]
		var a := src_pos[i0]
		var b := src_pos[i1]
		var c := src_pos[i2]
		var fn := (b - a).cross(c - a)
		if fn.length_squared() < 1e-16:
			# вироджений трикутник (буває після децимації) — беремо нормаль вершини
			fn = src_norm[i0] if has_norm else Vector3.UP
		fn = fn.normalized()
		if has_norm and fn.dot(src_norm[i0] + src_norm[i1] + src_norm[i2]) < 0.0:
			fn = -fn
		var col: Color = face_cols[f]
		for k in range(3):
			var v := f * 3 + k
			var srcv := tri[f * 3 + k]
			pos[v] = src_pos[srcv]
			norm[v] = fn
			cols[v] = col
			if has_skin:
				for w in range(per_v):
					bones[v * per_v + w] = int(src_bones[srcv * per_v + w])
					weights[v * per_v + w] = float(src_weights[srcv * per_v + w])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = pos
	out[Mesh.ARRAY_NORMAL] = norm
	out[Mesh.ARRAY_COLOR] = cols
	if has_skin:
		out[Mesh.ARRAY_BONES] = bones
		out[Mesh.ARRAY_WEIGHTS] = weights
	return out


## Матеріал рига: той самий шейдер, що й у вокселів, але з м'якшою rim-облямівкою.
static func _rig_material() -> Material:
	if _rig_mat == null:
		var base := VoxelBuilder.material()
		if base is ShaderMaterial:
			var sm := (base as ShaderMaterial).duplicate() as ShaderMaterial
			sm.set_shader_parameter("rim_strength", RIG_RIM)
			_rig_mat = sm
		else:
			_rig_mat = base
	return _rig_mat


# ──────────────────────────────── точки кріплення ────────────────────────────────

## Вузли в «геройських» одиницях на кістках: голова (капелюшок), обличчя (очі/щічки/рот/окуляри),
## шия (шарфик), хребет (крильця/рюкзачок). Голова Hero3D — та сама система координат, що в
## вокселя голови: початок — низ голови по центру, висота HEAD_H, передня грань на z = −HEAD_HALF_D.
## Габарити беремо в координатах МОДЕЛІ (там y — справжня вертикаль).
func _build_anchors(verts: Dictionary) -> void:
	var role_box: Dictionary = verts["role_box"]
	var head_box := head_box_of(role_box)
	_head_box = head_box
	# ширина САМОГО черепа (без писка) — по ній сідають бічні очі
	_head_core_box = role_box.get(HEAD_SIDE_ROLE, head_box)
	var k := maxf(head_box.size.y, 0.0001) / HEAD_H         # модельних одиниць на «геройську»
	var kz := maxf(head_box.size.z, 0.0001) / (HEAD_HALF_D * 2.0)
	_face_front = _eye_front(verts, head_box, kz)
	var anchor_pos := Vector3(head_box.get_center().x, head_box.position.y, head_box.get_center().z)
	var head := _bone_node("head", anchor_pos, Vector3(k, k, maxf(kz, 0.0001)))
	_anchors["head"] = head
	if head != null:
		_anchors["face"] = _face_node(head)
	if _bones.has("neck"):
		_anchors["neck"] = _bone_node("neck", _bone_origin("neck"), Vector3(k, k, k))
	if _bones.has("spine"):
		_anchors["spine"] = _bone_node("spine", _bone_origin("spine"), Vector3(k, k, k))


## Коробка голови — об'єднання габаритів ролей HEAD_BOX_ROLES (голова + писок).
## Ріг, грива й чубчик (HEAD_BOX_SKIP) мають власні ролі й сюди НЕ входять: інакше в
## єдинорога коробка тягнеться до кінчика рога, обличчя стискається під її висоту, а очі
## сідають на ріг. Порожньо (ролі не розклались) → маленька коробка-заглушка, як було.
## Чиста функція від {роль: AABB} — тест перевіряє саме її.
static func head_box_of(role_box: Dictionary) -> AABB:
	var out := AABB(Vector3(-0.1, 0.5, -0.1), Vector3(0.2, 0.2, 0.2))
	var first := true
	for role in HEAD_BOX_ROLES:
		if not role_box.has(role):
			continue
		var b: AABB = role_box[role]
		out = b if first else out.merge(b)
		first = false
	return out


## Передня межа голови САМЕ НА ВИСОТІ ОЧЕЙ, у координатах воксельної голови (від'ємне = вперед).
## У звірят морда виступає вперед і вниз, тож передня грань УСІЄЇ коробки голови — це кінчик
## носа: посадиш очі туди — вони висять у повітрі перед мордою. Тому беремо тільки вершини
## ролі "head" (кістки носа мають власну роль) у смузі rig_face.y ± EYE_BAND і шукаємо
## найпередніші з них. Смуга порожня → чесно повертаємо передню грань коробки.
func _eye_front(verts: Dictionary, head_box: AABB, kz: float) -> float:
	var fy := float(_face_cfg.get("y", 0.65))
	var cz := head_box.get_center().z
	var best := 0.0
	var found := false
	for md in (verts["per_mesh"] as Array):
		for sd in ((md as Dictionary).get("surfaces", []) as Array):
			var mpos: PackedVector3Array = (sd as Dictionary)["model"]
			var owner_bone: PackedInt32Array = (sd as Dictionary)["bone"]
			for v in range(mpos.size()):
				if _role_of(owner_bone[v]) != "head":
					continue
				if absf(local_of(mpos[v], head_box, _front).y - fy) > EYE_BAND:
					continue
				var d := (mpos[v].z - cz) * _front       # уперед від центру коробки
				if not found or d > best:
					best = d
					found = true
	if not found:
		return -HEAD_HALF_D
	return -maxf(best, 0.0) / maxf(kz, 0.0001)


## Позиція спокою кістки в координатах МОДЕЛІ.
func _bone_origin(role: String) -> Vector3:
	return _model_to_skel.affine_inverse() * _skel.get_bone_global_rest(int(_bones[role])).origin


## Вузол обличчя всередині голови. Обличчя Hero3D намальоване під воксельну голову
## FACE_HEAD_W завширшки; морда моделі зазвичай вужча, тож стискаємо все обличчя
## (очі, зіниці, щічки, рот, окуляри) і саджаємо очі на `rig_face.y` висоти голови,
## на передню межу голови НА ЦІЙ ВИСОТІ (_eye_front) — інакше очі завбільшки з півголови
## й висять у повітрі перед носом.
func _face_node(head: Node3D) -> Node3D:
	var head_w := maxf(_head_box.size.x, 0.0001) * _scale        # ширина голови в метрах героя
	_face_scale = clampf(head_w / FACE_HEAD_W, 0.7, 1.6) * float(_face_cfg.get("scale", 1.0))
	var fy := float(_face_cfg.get("y", 0.65))
	var node := Node3D.new()
	node.name = "Anchor_face"
	node.scale = Vector3.ONE * _face_scale
	# Hero3D ставить очі на 0,5 · HEAD_H і на z = −HEAD_HALF_D − 0,01; зсуваємо вузол так,
	# щоб ПІСЛЯ масштабу вони опинились на fy · HEAD_H і рівно на _face_front (передня межа
	# голови на висоті очей, а не кінчик носа) — власний зсув частин обличчя компенсуємо
	node.position = Vector3(
		0.0,
		fy * HEAD_H - 0.5 * HEAD_H * _face_scale,
		_face_front + HEAD_HALF_D * _face_scale + float(_face_cfg.get("z", 0.0)))
	_face_node_pos = node.position
	head.add_child(node)
	return node


## Розкладка обличчя: "front" (очі на морді) або "side" (очі на БОКАХ голови). Читає
## `rig_face.layout` з heroes.json — у коня очі по боках, у лисеняти спереду.
func face_layout() -> String:
	return String(_face_cfg.get("layout", "front"))


## Куди саджати БІЧНІ очі (`layout: "side"`) — у координатах ВУЗЛА ОБЛИЧЧЯ, тобто рівно
## там, де Hero3D ставить очі й щічки:
##   half_w — півширина САМОГО ЧЕРЕПА (роль `head`, без писка/гриви/рога) МІНУС
##            SIDE_EYE_OUT і SIDE_EYE_IN: око сидить трохи ВСЕРЕДИНІ поверхні, назовні
##            стирчить лише його передня частина (раніше воно виносилось назовні й
##            «плавало» збоку від голови);
##   z      — глибина: SIDE_EYE_DEPTH довжини голови від переду.
## Висота лишається та сама, що й у фронтальної розкладки (rig_face.y висоти голови).
func face_side_spot() -> Dictionary:
	var hy := maxf(_head_box.size.y, 0.0001)
	var to_head := HEAD_H / hy                     # модельні одиниці → координати голови
	var unit_m := maxf(hy * _scale / HEAD_H, 0.0001)   # метрів героя в одиниці голови
	var fs := maxf(_face_scale, 0.0001)
	var core_w := _head_core_box.size.x if _head_core_box.size.x > 0.0001 else _head_box.size.x
	var half_w := maxf(core_w * 0.5 * to_head - (SIDE_EYE_OUT + SIDE_EYE_IN) / unit_m, 0.0)
	# передня грань коробки голови — це −HEAD_HALF_D, задня +HEAD_HALF_D
	var zz := -HEAD_HALF_D + SIDE_EYE_DEPTH * HEAD_HALF_D * 2.0
	return {"half_w": half_w / fs, "z": (zz - _face_node_pos.z) / fs}


## BoneAttachment3D + вузол, у якому осі й масштаб — «геройські» (x праворуч, −z уперед,
## одиниця = метр героя). Точка `origin_model` задана в координатах МОДЕЛІ.
func _bone_node(role: String, origin_model: Vector3, scale3: Vector3) -> Node3D:
	if not _bones.has(role):
		return null
	var idx := int(_bones[role])
	var ba := BoneAttachment3D.new()
	ba.name = "Bone_%s" % role
	_skel.add_child(ba)
	ba.bone_idx = idx
	var node := Node3D.new()
	node.name = "Anchor_%s" % role
	# з «геройських» координат у модельні: спершу масштаб, тоді розворот (якщо модель дивиться в +Z)
	var b := Basis.IDENTITY
	if _front > 0.0:
		b = Basis(Vector3.UP, PI)
	b = b.scaled(scale3)
	# кадр збираємо в координатах моделі й аж тоді переводимо в скелет: у скелета
	# власні осі (Blender-риги бувають Z-вгору), і «вгору/вперед» там уже не ті
	var t := _model_to_skel * Transform3D(b, origin_model)
	# BoneAttachment дає позу кістки; знімаємо її спокій, щоб зсув лишився сталим
	node.transform = _skel.get_bone_global_rest(idx).affine_inverse() * t
	ba.add_child(node)
	return node


## Куди Hero3D вішає капелюшок (система координат вокселя голови).
func head_anchor() -> Node3D:
	return _anchors.get("head") as Node3D


## Куди Hero3D вішає очі/щічки/рот і окуляри — той самий кадр, але стиснутий під морду.
func face_anchor() -> Node3D:
	return (_anchors.get("face") if _anchors.get("face") != null else _anchors.get("head")) as Node3D


## Точка слоту аксесуара: "neck" — шарфик, "back" — крильця/рюкзачок. null — кістки нема.
func anchor(slot: String) -> Node3D:
	match slot:
		"hat":
			return _anchors.get("head") as Node3D
		"face":
			return face_anchor()
		"neck":
			return (_anchors.get("neck") if _anchors.get("neck") != null else _anchors.get("head")) as Node3D
		"back":
			return (_anchors.get("spine") if _anchors.get("spine") != null else _anchors.get("neck")) as Node3D
	return null


## ПРЕВ'Ю, клавіша M: перефарбувати модель у діагностичний вигляд — кандидати бічних наростів
## магентою (прийнята купка) й темно-фіолетовим (купка замала, див. SIDE_MIN_FACES). Так видно,
## що саме бачить пошук сумки, і куди тягти SIDE_MIN_OUT / SIDE_MIN_FACES.
## Повертає новий стан. У грі не працює: вихідні вершини тримаємо лише в прев'ю (RIG=…).
func toggle_debug_sides() -> bool:
	if _verts.is_empty():
		return false
	_debug_sides = not _debug_sides
	_paint(_verts, _colors)
	return _debug_sides


## Знайдені купки бічних наростів — для прев'ю й тестів (див. side_clusters).
func side_info() -> Array:
	return _side_info.duplicate()


func mesh_instances() -> Array[MeshInstance3D]:
	return _meshes


## Розкладка кісток — для прев'ю, тестів і звітів: {роль: ім'я кістки}.
func bone_map() -> Dictionary:
	var out := {}
	for role in _bones.keys():
		var v = _bones[role]
		if typeof(v) == TYPE_ARRAY:
			var names := []
			for i in (v as Array):
				names.append(_skel.get_bone_name(int(i)))
			out[role] = names
		else:
			out[role] = _skel.get_bone_name(int(v))
	return out


## Скільки ГРАНЕЙ потрапило в кожну зону: {"o": 1234, "c": 210, …}. Для прев'ю й звітів —
## якщо в "c" нуль, морда не пофарбувалась; якщо в "o" все, ролі кісток не розклались.
func zone_counts() -> Dictionary:
	return _zone_counts.duplicate()


## Ім'я стилю розмальовки («unicorn») або "" — для прев'ю й тестів.
func style_name() -> String:
	return _style_name


## Голова в метрах героя (ширина × висота × глибина), масштаб обличчя й діагностика торбинки —
## для прев'ю: по них видно, чи не завелике обличчя, чи не роздулась коробка голови зайвими
## кістками і чому не знайшлась сумка (півширина тулуба проти max |x| — між ними й лежить
## `rig_zones.bag_x`). Рядок «торба:» друкується ЗАВЖДИ, навіть коли нічого не знайшлось;
## плюс габарит тулуба в метрах героя — саме в цих числах пишуться коробки `rig_marks`.
func face_report() -> String:
	var head := "голова %.2f×%.2f×%.2f м, обличчя ×%.2f (еталон %.3f м), очі на z=%.3f (грань коробки %.3f)" % [
		_head_box.size.x * _scale, _head_box.size.y * _scale, _head_box.size.z * _scale,
		_face_scale, FACE_HEAD_W, _face_front, -HEAD_HALF_D]
	# рядок «торба:» друкуємо ЗАВЖДИ, навіть коли купка не знайшлась (cut = −1) і навіть коли
	# граней тулуба нуль: саме по цих числах видно, куди тягти bag_x і чи є що ловити взагалі
	var half := float(_bag_info.get("half", -1.0))
	var mx := float(_bag_info.get("max", 0.0))
	# коробка голови ПІСЛЯ виключення рога/гриви/чубчика — по ній сідає обличчя
	var hb := "  коробка голови: ролі %s (без %s), модельні одиниці x %.3f…%.3f, y %.3f…%.3f, z %.3f…%.3f" % [
		", ".join(PackedStringArray(HEAD_BOX_ROLES)), ", ".join(PackedStringArray(HEAD_BOX_SKIP)),
		_head_box.position.x, _head_box.end.x, _head_box.position.y, _head_box.end.y,
		_head_box.position.z, _head_box.end.z]
	var bag := "  торба: граней тулуба %d, півширина %.4f, max |x| %.4f (×%.2f півширини), поріг %.4f (bag_x %.2f), бік %d%s" % [
		int(_bag_info.get("faces", 0)), half, mx, mx / maxf(half, 0.00001),
		float(_bag_info.get("cut", -1.0)), float(_zones.get("bag_x", 0.98)),
		int(_bag_info.get("side", 0)),
		" — вимкнена: стиль малює сердечко на грудях" if bool(_bag_info.get("heart", false)) else ""]
	# габарит тулуба в МЕТРАХ ГЕРОЯ — рівно ті числа, у яких пишеться `rig_marks`
	var lo := _torso_box.position
	var hi := _torso_box.end
	var torso := "  тулуб (метри героя, для rig_marks): x %.3f…%.3f, y %.3f…%.3f, z %.3f…%.3f" % [
		lo.x, hi.x, lo.y, hi.y, lo.z, hi.z]
	# купки бічних наростів (сумки) — локальний пошук замість сліпого `bag_x`
	var sides := PackedStringArray()
	for item in _side_info:
		var c: Dictionary = item
		var ctr: Vector3 = c["center"]
		var sz: Vector3 = c["size"]
		sides.append("%s %d граней, бік %s, центр x %+.3f м · y %.2f · z %.2f, розмір y %.2f × z %.2f, виступ до %.3f м" % [
			"✔" if bool(c["ok"]) else "·", int(c["n"]),
			"лівий" if int(c["side"]) < 0 else "правий",
			ctr.x, ctr.y, ctr.z, sz.y, sz.z, float(c["out"])])
	var side := "  бічні нарости (виступ > %.3f м, купка від %d граней%s): %s" % [
		SIDE_MIN_OUT, SIDE_MIN_FACES,
		"" if not _style.has("chest_heart") else ", фарбування вимкнене стилем",
		("\n    " + "\n    ".join(sides)) if sides.size() > 0 else "нема"]
	var marks := "  rig_marks: %d (ручні позначки → зона m)" % _marks.size()
	# множники анімації під модель (`rig_anim`) і чи знайшлись нижні ланки лапок
	var anim := "  rig_anim: leg_amp ×%.2f, leg_lift ×%.2f · нижніх ланок лапок %d/4" % [
		float(_anim_cfg.get("leg_amp", 1.0)), float(_anim_cfg.get("leg_lift", 1.0)),
		_lower_leg.size()]
	return "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s" % [
		head, hb, bag, side, torso, marks, anim, sign_report()]


## КАЛІБРОВАНІ знаки обертів (див. _calibrate_signs) — головна діагностика «поза дзеркальна».
## Кожен знак виміряний пробним обертом кістки: + завжди означає одне й те саме
## (лапка вперед · таз/хребет ніс угору · шия/голова ніс униз · вухо назад · хвіст угору /
## ліворуч · лапка вбік ліворуч). Якщо в моделі поза все одно дзеркальна — дивись сюди.
func sign_report() -> String:
	var keys := _sign.keys()
	keys.sort()
	var parts := PackedStringArray()
	for k in keys:
		parts.append("%s%s" % ["+" if float(_sign[k]) >= 0.0 else "−", String(k)])
	var tail := PackedStringArray()
	for i in range(_tail_lift_sign.size()):
		tail.append("%s%s" % [
			"+" if _tail_lift_sign[i] >= 0.0 else "−",
			"+" if (i < _tail_wag_sign.size() and _tail_wag_sign[i] >= 0.0) else "−"])
	return "  калібровані знаки (пробний оберт %.2f рад): %s%s\n  розкладка обличчя: %s · лапок-проб %d" % [
		CAL_ANGLE, ", ".join(parts),
		("; хвіст (підйом/виляння) %s" % " ".join(tail)) if tail.size() > 0 else "",
		face_layout(), _leg_tips.size()]


## Усі імена кісток моделі — щоб було що вписати в `rig_bones`, коли автомапа промазала.
func bone_names() -> PackedStringArray:
	var out := PackedStringArray()
	if _skel == null:
		return out
	for i in range(_skel.get_bone_count()):
		out.append(_skel.get_bone_name(i))
	return out


## Дерево кісток із позиціями спокою (у координатах скелета) — для ручної розкладки `rig_bones`,
## коли імена безіменні (Bone_NNN). Рядок: ім'я, батько, x y z (см), глибина в дереві.
func bone_dump() -> PackedStringArray:
	var out := PackedStringArray()
	if _skel == null:
		return out
	for i in range(_skel.get_bone_count()):
		var p := _skel.get_bone_parent(i)
		var g := _skel.get_bone_global_rest(i).origin * 100.0
		var depth := 0
		var q := p
		while q >= 0:
			depth += 1
			q = _skel.get_bone_parent(q)
		out.append("%s%-10s parent=%-10s x=%6.1f y=%6.1f z=%6.1f" % [
			"  ".repeat(depth), _skel.get_bone_name(i),
			_skel.get_bone_name(p) if p >= 0 else "-", g.x, g.y, g.z])
	return out


func is_ready() -> bool:
	return _ready


# ──────────────────────────────── анімація ────────────────────────────────

## Осі обертання в локальних координатах кожної кістки. Ім'я й напрямок кістки в
## Meshy-ригах непередбачувані, тому не крутимо «навколо X кістки», а щоразу беремо
## той локальний напрямок, який відповідає модельному +X (боковій осі) чи +Y (вертикалі).
func _prepare_axes() -> void:
	# модельні X/Y спершу переводимо в координати скелета (у нього можуть бути свої осі),
	# і вже звідти — в локальні координати кожної кістки
	var mb := _model_to_skel.basis.orthonormalized()
	var right := (mb * Vector3.RIGHT).normalized()
	var up := (mb * Vector3.UP).normalized()
	var back := (mb * Vector3.BACK).normalized()      # модельний +Z
	var todo := []
	for role in _bones.keys():
		var v = _bones[role]
		if typeof(v) == TYPE_ARRAY:
			todo.append_array(v as Array)
		else:
			todo.append(v)
	# нижні ланки лапок теж крутяться (згин коліна в махові) — їм потрібні ті самі осі
	todo.append_array(_lower_leg.values())
	for item in todo:
		var idx := int(item)
		# ортонормуємо: масштаб у кістці зіпсував би тотожність R_{B⁻¹a} = B⁻¹·R_a·B,
		# на якій тримається _rot()
		var inv := _skel.get_bone_global_rest(idx).basis.orthonormalized().inverse()
		_axis_x[idx] = (inv * right).normalized()
		_axis_y[idx] = (inv * up).normalized()
		_axis_z[idx] = (inv * back).normalized()
		var p := _skel.get_bone_parent(idx)
		var pb := _skel.get_bone_global_rest(p).basis.orthonormalized().inverse() if p >= 0 else Basis.IDENTITY
		_up_parent[idx] = (pb * up).normalized()


# ────────────────────── калібрування знаків (пробний оберт) ──────────────────────
#
# ЧОМУ. Раніше знак кожного оберту виводився з `_front` («модель дивиться в +Z, отже
# додатний кут — це мах уперед»). Це правда лише поки кістки лежать у спокої «вздовж моделі».
# У єдинорога вони лежать інакше — і привітання виходило дзеркальним (передні лапки вниз,
# задні вгору), а спринт топив задні копитця. Тому знаки більше НЕ вгадуються, а
# ВИМІРЮЮТЬСЯ один раз у build(): кістку пробно крутять на CAL_ANGLE, дивляться, куди
# поїхала точка-проба (кінчик її ланцюжка), і запам'ятовують знак так, щоб додатний кут
# завжди означав те саме — незалежно від моделі:
#     лапка          + = мах УПЕРЕД
#     коліно (knee)  + = копитце НАЗАД (лапка згинається, копитце піднімається)
#     таз, хребет    + = ніс УГОРУ
#     шия, голова    + = ніс УНИЗ
#     вухо           + = кінчик НАЗАД
#     хвіст (lift)   + = кінчик УГОРУ
#     хвіст (wag)    + = кінчик ЛІВОРУЧ героя
#     лапка (splay)  + = копитце ЛІВОРУЧ героя (ковзання на животі)

## Пробний кут калібрування, рад (малий — щоб не вилізти за межі суглоба, і достатній,
## щоб проба поїхала помітно далі за похибку float).
const CAL_ANGLE := 0.2
## Менший рух проби (метри героя) вважаємо «не зрушила» — знак лишається запасним.
const CAL_EPS := 0.0005

## Знак повороту з руху точки-проби. Чиста функція (саме її перевіряє тест).
## `before`/`after` — проба ДО й ПІСЛЯ пробного оберту на ДОДАТНИЙ кут, у метрах героя;
## `want` — напрямок, у який проба має їхати при додатному куті (теж метри героя).
## Повертає +1 або −1, а коли проба не зрушила — 0.0 (викликач бере запасний знак).
static func sign_from_probe(before: Vector3, after: Vector3, want: Vector3,
		eps: float = CAL_EPS) -> float:
	if want.length_squared() < 0.000001:
		return 0.0
	var d := (after - before).dot(want.normalized())
	if absf(d) < eps:
		return 0.0
	return 1.0 if d > 0.0 else -1.0


## Виміряти знаки для всіх анімованих ролей. Кличеться раз, у build(), після _prepare_axes().
func _calibrate_signs() -> void:
	_sign.clear()
	_tail_lift_sign.clear()
	_tail_wag_sign.clear()
	_leg_tips.clear()
	if _skel == null:
		return
	var fwd := Vector3(0.0, 0.0, -1.0)      # перед героя — це −z
	var up := Vector3.UP
	var back := Vector3(0.0, 0.0, 1.0)
	var left := Vector3(-1.0, 0.0, 0.0)     # ліворуч героя — це −x
	# лапки, вуха й хвіст справді ЛЕЖАТЬ уздовж своєї кістки, тож пробою беремо кінчик
	# їхнього ланцюжка: він рухається в потрібний бік із першого ж порядку малості
	for role in LEG_ROLES:
		if not _bones.has(role):
			continue
		var li := int(_bones[role])
		var lp := _probe_local(li)
		_sign["%s_swing" % role] = _measure(li, _axis_x[li], lp, fwd, -_front)
		_sign["%s_splay" % role] = _measure(li, _axis_z[li], lp, left, 1.0)
		# НИЖНЯ ланка (коліно/п'ястка): + = копитце йде НАЗАД, тобто лапка згинається
		# й піднімає копитце в махові. Знак у кожної моделі свій, тож теж міряємо
		if _lower_leg.has(role):
			var ki := int(_lower_leg[role])
			_sign["%s_knee" % role] = _measure(ki, _axis_x[ki], _probe_local(ki), back, -_front)
		_leg_tips.append(_leg_tip(li))
	for role4 in ["ear_l", "ear_r"]:
		if not _bones.has(role4):
			continue
		var ei := int(_bones[role4])
		_sign["%s_back" % role4] = _measure(ei, _axis_x[ei], _probe_local(ei), back, -_front)
	var tail = _bones.get("tail", [])
	if typeof(tail) == TYPE_ARRAY:
		# у хвоста кожна ланка своя (бічні пасма єдинорога дивляться інакше за основне)
		for item in (tail as Array):
			var ti := int(item)
			var tp := _probe_local(ti)
			_tail_lift_sign.append(_measure(ti, _axis_x[ti], tp, up, -_front))
			_tail_wag_sign.append(_measure(ti, _axis_y[ti], tp, left, 1.0))
	# А от у тулуба й голови кінчик ланцюжка не годиться: у єдинорога єдиний нащадок голови —
	# це РІГ, він стирчить угору, і кивок носом рухає його майже горизонтально (знак «угору/вниз»
	# виходить із похибки). Тому пробу беремо штучну — точку на 20 см ПОПЕРЕДУ суглоба:
	# вона їде вгору чи вниз рівно так, як морда.
	for role2 in ["hips", "spine"]:
		if not _bones.has(role2):
			continue
		var bi := int(_bones[role2])
		_sign["%s_pitch" % role2] = _measure(bi, _axis_x[bi], _probe_forward(bi), up, -_front)
	for role3 in ["neck", "head"]:
		if not _bones.has(role3):
			continue
		var ni := int(_bones[role3])
		_sign["%s_pitch" % role3] = _measure(ni, _axis_x[ni], _probe_forward(ni), -up, -_front)
	_skel.reset_bone_poses()


## Один вимір: пробний оберт кістки `idx` на CAL_ANGLE навколо `axis` (у ЛОКАЛЬНИХ
## координатах кістки) і напрямок руху точки-проби `probe` (теж локальної).
## `want` — куди проба має піти при ДОДАТНОМУ куті (метри героя),
## `fallback` — знак, коли проба не зрушила (стара формула від `_front`).
func _measure(idx: int, axis: Vector3, probe: Vector3, want: Vector3, fallback: float) -> float:
	_skel.reset_bone_poses()
	_skel.force_update_all_bone_transforms()
	var before := _hero_dir(_model_point(_skel.get_bone_global_pose(idx) * probe))
	var rest := _skel.get_bone_rest(idx).basis.get_rotation_quaternion()
	_skel.set_bone_pose_rotation(idx, rest * Quaternion(axis, CAL_ANGLE))
	_skel.force_update_all_bone_transforms()
	var after := _hero_dir(_model_point(_skel.get_bone_global_pose(idx) * probe))
	_skel.reset_bone_poses()
	var s := sign_from_probe(before, after, want)
	return s if s != 0.0 else fallback


## Штучна проба «20 см ПОПЕРЕДУ суглоба» в локальних координатах кістки: для тулуба й
## голови саме вона показує, куди їде морда (кінчик ланцюжка там може стирчати куди завгодно —
## у єдинорога це ріг). `_axis_z` — модельний +Z у локальних координатах, перед моделі — × _front.
func _probe_forward(idx: int) -> Vector3:
	var l := 0.2 * _inv_scale * _skel_unit      # 20 см героя в одиницях скелета
	return (_axis_z[idx] as Vector3) * (_front * l)


## Точка-проба кістки в ЇЇ ЛОКАЛЬНИХ координатах: позиція спокою найдальшого нащадка
## (кінчик ланцюжка — саме він і «махає»). Нащадків нема (кістка-листок) — продовжуємо
## напрямок від батька: у листка власний оберт не рухає його ж початок, тож проба потрібна
## попереду.
func _probe_local(idx: int) -> Vector3:
	var rest_inv := _skel.get_bone_global_rest(idx).affine_inverse()
	var best := -1
	var best_d := 0.0
	var here := _skel.get_bone_global_rest(idx).origin
	for i in range(_skel.get_bone_count()):
		if i == idx or not _is_descendant(i, idx):
			continue
		var d := (_skel.get_bone_global_rest(i).origin - here).length()
		if d > best_d:
			best_d = d
			best = i
	if best >= 0:
		var p := rest_inv * _skel.get_bone_global_rest(best).origin
		if p.length() > 0.000001:
			return p
	var par := _skel.get_bone_parent(idx)
	if par >= 0:
		var dir := _skel.get_bone_global_rest(idx).origin - _skel.get_bone_global_rest(par).origin
		if dir.length() > 0.000001:
			return rest_inv.basis * dir
	return Vector3(0.0, _skel_unit * 0.1, 0.0)


## Чи `idx` — нащадок `root` (сам собі нащадком не рахується).
func _is_descendant(idx: int, root: int) -> bool:
	var p := _skel.get_bone_parent(idx)
	while p >= 0:
		if p == root:
			return true
		p = _skel.get_bone_parent(p)
	return false


## Кінчик лапки для перевірки «копитця на підлозі»: найглибший нащадок кістки лапки плюс
## продовження за нього. Повертає [індекс кістки, точка в її локальних координатах].
func _leg_tip(idx: int) -> Array:
	var deep := idx
	var best_d := 0.0
	var here := _skel.get_bone_global_rest(idx).origin
	for i in range(_skel.get_bone_count()):
		if i == idx or not _is_descendant(i, idx):
			continue
		var d := (_skel.get_bone_global_rest(i).origin - here).length()
		if d > best_d:
			best_d = d
			deep = i
	return [deep, _probe_local(deep)]


## Точка з координат СКЕЛЕТА в координати моделі (там y — справжня вертикаль).
func _model_point(p: Vector3) -> Vector3:
	return _model_to_skel.affine_inverse() * p


## Точка/напрямок із координат МОДЕЛІ в «геройські» метри БЕЗ підйому над землею
## (пара до _hero_point: там ще віднімається низ габариту). Для різниць двох точок
## підйом усе одно скорочується, тож тут він і не потрібен.
func _hero_dir(p: Vector3) -> Vector3:
	if _front > 0.0:
		return Vector3(-p.x, p.y, -p.z) * _scale
	return p * _scale


## Знак ролі з калібрування (нема — 1.0: краще як було, ніж навмання).
func _s(key: String) -> float:
	return float(_sign.get(key, 1.0))


## Довернути кістку на `angle` навколо осі, заданої В ЇЇ ЛОКАЛЬНИХ координатах
## (див. _prepare_axes: там модельні X/Y перекладені в локальні). Поза множиться
## СПРАВА від спокою — тоді в координатах скелета це чистий оберт навколо модельної осі.
func _rot(idx: int, axis: Vector3, angle: float) -> void:
	if absf(angle) < 0.0005:
		return
	var rest := _skel.get_bone_rest(idx).basis.get_rotation_quaternion()
	_skel.set_bone_pose_rotation(idx, rest * Quaternion(axis, angle))


## Те саме, але двома осями за раз. Окремо кликати _rot() двічі не можна: друга поза
## рахується від СПОКОЮ і просто затерла б першу.
func _rot2(idx: int, axis_a: Vector3, angle_a: float, axis_b: Vector3, angle_b: float) -> void:
	if absf(angle_a) < 0.0005 and absf(angle_b) < 0.0005:
		return
	var rest := _skel.get_bone_rest(idx).basis.get_rotation_quaternion()
	_skel.set_bone_pose_rotation(idx, rest * Quaternion(axis_a, angle_a) * Quaternion(axis_b, angle_b))


## Те саме трьома осями (таз: тангаж + виляння танцю + крен кроку).
func _rot3(idx: int, axis_a: Vector3, angle_a: float, axis_b: Vector3, angle_b: float,
		axis_c: Vector3, angle_c: float) -> void:
	if absf(angle_a) < 0.0005 and absf(angle_b) < 0.0005 and absf(angle_c) < 0.0005:
		return
	var rest := _skel.get_bone_rest(idx).basis.get_rotation_quaternion()
	_skel.set_bone_pose_rotation(idx, rest * Quaternion(axis_a, angle_a)
		* Quaternion(axis_b, angle_b) * Quaternion(axis_c, angle_c))


## Один кадр процедурної анімації. `s` — стан із Hero3D._process:
## t, run_f, galloping, running, ducking, duck_blend, airborne, sitting, tumbling, wave,
## а від GDD v1.6 §5 ще й моторний профіль стану: prof (див. Hero3D.PROFILE_KEYS), leg_f, phase,
## speed_k (множник темпу бігу), dance_t (секунди від початку танцю), anim / anim_name.
## Свого набору чисел у ригу нема — усі амплітуди беруться з того самого профілю,
## що керує воксельним тілом (плюс множники моделі `rig_anim`, див. anim_of).
## Заморозити кістки в позі спокою (прев'ю, клавіша P): так видно, чи «кривизна» — від нашої
## анімації, чи від самої моделі/прив'язки.
var frozen := false

## Дефолт профілю: коли Hero3D його не передав (старий виклик, тест) — поводимось як RUN/IDLE.
const PROF_FALLBACK := {
	"leg_amp": GALLOP_SWING, "leg_freq": 1.0, "bob_amp": 1.0, "body_pitch": 0.0,
	"body_y": 0.0, "head_pitch": 0.0, "ears": "free", "tail": "wag",
	"limp_leg": -1, "shake": 0.0, "spin_y": 0.0, "hop": 0.0, "leg_spread": 0.0,
}
## Кут «пози вуха» за режимом профілю (рад, у бік потилиці).
const EAR_POSE := {"up": -0.25, "back": 0.35, "down": 0.8, "free": 0.0}
## Тремтіння ракети й підскоки танцю — ті самі числа, що в Hero3D (дублі навмисно,
## як і решта констант тут: зворотнє посилання дало б циклічну залежність class_name).
const SHAKE_HZ := 20.0
const SHAKE_AMP := 0.02
const DANCE_BPS := 1.5          ## біт танцю повільніший (було 2,0): рух читається спокійніше
const DANCE_HOP := 0.04         ## підскок танцю нижчий, ніж був (0,06): задні лапки не відриваються
const DANCE_SEC := 3.0
## Скільки секунд передні лапки ПЕРЕКОЧУЮТЬ вагу з однієї на другу (без клацання на біт).
const DANCE_LEG_EASE := 0.2
## Танець: у ПІДЙОМІ підскоку задні лапки довертаються вниз-назад, щоб дістати землі.
const DANCE_HIND_EXT := 0.2

## Хвіст живий У БУДЬ-ЯКОМУ стані: поверх режиму профілю завжди йде тихе виляння
## ±TAIL_IDLE на TAIL_IDLE_HZ (навіть "straight" і "wag_up" — інакше в половині станів
## хвіст стоїть кілком). Ті самі числа є в Hero3D для воксельного хвоста.
const TAIL_IDLE := 0.12
const TAIL_IDLE_HZ := 1.2

## Привітання (див. Hero3D.wave_hello): герой ЗВОДИТЬСЯ ДИБКИ на задні лапки. Нахил іде
## НАВКОЛО ТАЗУ (у ригу крутиться сама кістка hips, тож задні копитця лишаються на місці),
## задні лапки довертаються ВПЕРЕД, щоб опинитись під тілом, передні звисають: ліва
## підібгана, права махає. Голова доверстує контр-нахилом, щоб морда дивилась у камеру.
## Числа — ті самі, що в Hero3D (дублі навмисно, див. вище).
const WAVE_LIFT := -1.2       ## передня права («привіт») — середина розмаху, рад
const WAVE_LIFT_SWING := 0.2  ## розмах помаху вгору-вниз: WAVE_LIFT ± це (−1,4 … −1,0)
const WAVE_LIFT_TUCK := -0.6  ## передня ліва просто підібгана, рад
const WAVE_HIND := 0.5        ## задні лапки ВПЕРЕД — під тіло, рад (+ = мах уперед)
const WAVE_BODY_PITCH := -0.9 ## ніс угору ≈ 50°, рад (у наших знаках + = ніс униз)
const WAVE_BODY_Y := -0.09    ## таз сідає на задні лапки, м
const WAVE_HEAD_PITCH := 0.6  ## контр-нахил голови, рад (+ = морда вниз) — морда в камеру
const WAVE_OUT := 0.25        ## постійний відворот лапки назовні, рад
const WAVE_YAW := 0.25        ## розмах помаху навколо вертикалі, рад
const WAVE_HZ := 3.0          ## частота помаху, Гц
const WAVE_HEAD_ROLL := -0.15 ## крен голови до піднятої лапки (не кивок носом — той сердитий)
## Ракета: лапки звисають ВНИЗ-НАЗАД (оленята Санти) з ледь помітним похитуванням.
## Задні звисають ПРЯМІШЕ за передні — інакше герой висів «сидячи».
const ROCKET_LEG_BACK := 0.35
const ROCKET_LEG_BACK_FRONT := 0.65
const ROCKET_SWAY_HZ := 1.0
## Хвіст у ракеті ЗВИСАЄ ВНИЗ (режим "down") і повільно похитується — задертий догори
## хвіст на висоті читався як «злякався», а не «летить».
const ROCKET_TAIL_DOWN := -0.8
const ROCKET_TAIL_HZ := 0.7
const ROCKET_TAIL_SWAY := 0.1
## Хвіст у танці (режим "wag_up"): тримається вгорі й виляє навколо ВЕРТИКАЛІ.
const DANCE_TAIL_LIFT := 0.9
const DANCE_TAIL_WAG := 0.5
const DANCE_TAIL_HZ := 4.0
## Кути хвоста діляться на ланки ланцюжка (інакше кожна кістка додає свій нахил і хвіст
## згортається в бублик), але НЕ більше ніж на TAIL_CHAIN_MAX: у єдинорога в ролі `tail`
## аж 11 кісток — три окремі пасма, і поділ на 11 з'їдав виляння повністю.
const TAIL_CHAIN_MAX := 4
## Присід — це КОВЗАННЯ НА ЖИВОТІ (ідея Nick): лапки розкидані вбоки, корпус на землі.
## Ті самі числа є в Hero3D (дублі навмисно, як і решта констант тут).
const SLIDE_SPLAY := 1.1          ## розкид лапок убік, рад
const SLIDE_HEAD_PITCH := 0.1     ## морда ледь донизу (не «під перешкоду», а вздовж землі)
## Копитця на підлозі: після пози найнижчий кінчик лапки не має бути нижче за −GROUND_EPS,
## інакше піднімаємо всю модель (але не більше ніж на GROUND_LIFT_MAX — щоб бага в кістках
## не підкинула героя в небо).
const GROUND_EPS := 0.005
const GROUND_LIFT_MAX := 0.15

var _shake_t := 0.0
var _shake_off := Vector2.ZERO
var _spin_y := 0.0            ## поточне виляння танцю навколо вертикалі (рад)


func animate(delta: float, s: Dictionary) -> void:
	if not _ready or _skel == null:
		return
	_skel.reset_bone_poses()
	if _root != null and is_instance_valid(_root):
		_root.position.y = _root_y0       # підйом «копитця на підлозі» рахується в кінці кадру
	if frozen:
		return
	var t := float(s.get("t", 0.0))
	var run_f := float(s.get("run_f", 11.0))
	var galloping := bool(s.get("galloping", false))
	var running := bool(s.get("running", false))
	var airborne := bool(s.get("airborne", false))
	# ковзання (присід) працює виключно через ПЛАВНИЙ бленд: різкий прапорець `ducking`
	# смикав би позу на вході й виході
	var duck := clampf(float(s.get("duck_blend", 1.0 if bool(s.get("ducking", false)) else 0.0)),
		0.0, 1.0)
	var sitting := bool(s.get("sitting", false))
	var wave := float(s.get("wave", 0.0))
	## наскільки герой уже звівся дибки для привітання (0…1, вхід/вихід за Hero3D.WAVE_EASE)
	var wave_b := clampf(float(s.get("wave_blend", 1.0 if wave > 0.0 else 0.0)), 0.0, 1.0)
	if bool(s.get("tumbling", false)):
		return          # удар: тілом крутить твін Hero3D, кістки завмерли в спокої (як у вокселях)
	var prof: Dictionary = s.get("prof", PROF_FALLBACK)
	if prof.is_empty():
		prof = PROF_FALLBACK
	var leg_amp := float(prof.get("leg_amp", GALLOP_SWING))
	var leg_f := float(s.get("leg_f", run_f * float(prof.get("leg_freq", 1.0))))
	# фаза кроку (радіани): від неї рахуються всі чотири лапки зі своїми зсувами GAIT_PHASE
	var phase := float(s.get("phase", t * leg_f))
	var limp_leg := int(prof.get("limp_leg", -1))
	var rocket := bool(s.get("rocket", false))
	var dancing := bool(s.get("dance", false))
	var dance_t := float(s.get("dance_t", 0.0))
	## множники моделі (`rig_anim`): у єдинорога скінінг жорсткий, тож розмах приборканий
	var cfg_amp := float(_anim_cfg.get("leg_amp", 1.0))
	var cfg_lift := float(_anim_cfg.get("leg_lift", 1.0))
	## розмах лапок цієї моделі (профіль × темп бігу × множник моделі)
	var step_amp := leg_amp * float(s.get("speed_k", 1.0)) * cfg_amp

	# ── лапки: природний 4-ТАКТНИЙ КРОК (не рись!) ──
	# Копитця ставляться по черзі задня ліва → передня ліва → задня права → передня права
	# (GAIT_PHASE, рівні чверті циклу). У махові (cos φ > 0) згинається НИЖНЯ ланка лапки —
	# копитце піднімається; на контакті й поштовху лапка пряма.
	# Інші стани як були: стрибок — підібгані, ракета — звисають униз-назад (оленята Санти),
	# танець — передні по черзі, привітання — дибки, ковзання — розкидані ВБОКИ.
	# ПОЗИЦІЇ кісток лапок не чіпаємо НІКОЛИ (тільки оберти від плеча/стегна): жорсткий
	# скінінг від зсуву рве меш — саме так «відривалась» передня й розтягувалась задня.
	for role in LEG_ROLES:
		if not _bones.has(role):
			continue
		var idx := int(_bones[role])
		var front: bool = (role == "fl" or role == "fr")
		var leg_i := LEG_ROLES.find(role)                 # 0 fl · 1 fr · 2 bl · 3 br — як у Hero3D
		var a := 0.0
		var lift := 0.0                                   # 0…1, згин нижньої ланки в махові
		if rocket:
			# лапки звисають ВНИЗ-НАЗАД (мінус = назад) із повільним похитуванням ±leg_amp
			a = -(ROCKET_LEG_BACK_FRONT if front else ROCKET_LEG_BACK) \
				+ sin(t * TAU * ROCKET_SWAY_HZ) * leg_amp
		elif airborne:
			a = -leg_amp if front else leg_amp
		elif dancing:
			if front:
				# перекочування ваги з лапки на лапку — плавне (DANCE_LEG_EASE), без клацання
				var w := dance_leg_weight(t, leg_i, DANCE_BPS, DANCE_LEG_EASE)
				a = lerpf(-0.1, -leg_amp, w)
			else:
				a = 0.15 + DANCE_HIND_EXT * dance_bounce(t, DANCE_BPS)
		elif galloping:
			var phi := phase + TAU * gait_phase(leg_i)
			a = sin(phi) * step_amp
			lift = gait_lift(phi)
		else:
			a = sin(t * 1.4 + (0.0 if leg_i % 2 == 0 else 1.1)) * 0.05
		if leg_i == limp_leg:
			a *= 0.3                                # кульгає: хвора лапка ледь працює
			lift *= 0.3
		if duck > 0.001:
			# ковзання на животі: лапки не підібгані під себе, а ВИПРЯМЛЕНІ й розкидані
			# вбоки (сам розкид — оберт навколо модельного Z, нижче)
			a = lerpf(a, 0.0, duck)
			lift = lerpf(lift, 0.0, duck)
		if wave_b > 0.001:
			# привітання: стійка дибки — передня ліва підібгана, задні ВПЕРЕД під тіло
			a = lerpf(a, WAVE_LIFT_TUCK if front else WAVE_HIND, wave_b)
			lift = lerpf(lift, 0.0, wave_b)
		# Знак «додатне `a` = мах УПЕРЕД» не вгадується з _front, а ВИМІРЯНИЙ у build()
		# (див. _calibrate_signs): у єдинорога кістки лежать інакше, ніж у лисеняти, і стара
		# формула давала дзеркальну позу — передні лапки вниз, задні вгору
		var sw := _s("%s_swing" % role)
		# нижня ланка: + = копитце назад (виміряно в build), розмах — GAIT_LOWER_BEND
		if _lower_leg.has(role):
			var ki := int(_lower_leg[role])
			_rot(ki, _axis_x[ki], _s("%s_knee" % role) * lift * GAIT_LOWER_BEND * cfg_lift)
		if role == "fr" and wave_b > 0.001:
			# вітається передньою правою: махає нею вгору-вниз (WAVE_LIFT ± WAVE_LIFT_SWING)
			# і навколо вертикалі. Осі йдуть у порядку «спершу підняти, потім вильнути»
			# (у _rot2 перший аргумент застосовується ОСТАННІМ), інакше помах крутив би
			# лапку навколо неї самої
			var yaw := (WAVE_OUT * _front + sin(t * TAU * WAVE_HZ) * WAVE_YAW) * wave_b
			var hi_wave := WAVE_LIFT + sin(t * TAU * WAVE_HZ) * WAVE_LIFT_SWING
			_rot2(idx, _axis_y[idx], yaw, _axis_x[idx], sw * lerpf(a, hi_wave, wave_b))
			continue
		if duck > 0.001:
			# розкид убік: ліві лапки назовні ліворуч, праві — праворуч
			var out := (1.0 if (role == "fl" or role == "bl") else -1.0) \
				* SLIDE_SPLAY * duck * _s("%s_splay" % role)
			_rot2(idx, _axis_z[idx], out, _axis_x[idx], sw * a)
			continue
		_rot(idx, _axis_x[idx], sw * a)

	# наскільки поза НАВМИСНО опускає тіло (спринт притискає героя до землі) — рівно на стільки
	# копитцям і дозволено бути нижче нуля, решта провалу лікується підйомом у кінці кадру
	var body_floor := 0.0

	# ── таз: боб на бігу, дихання у спокої (позиція — в метрах моделі) ──
	if _bones.has("hips"):
		var hi := int(_bones["hips"])
		var bob := 0.0
		if galloping:
			bob = absf(sin(phase))
			if limp_leg >= 0:
				# кульгає — боб нерівний (другий гармонік), як і у воксельного тіла
				bob = absf(sin(phase)) * 0.7 + absf(sin(phase * 2.0 + 0.6)) * 0.3
			bob *= 0.05 * float(prof.get("bob_amp", 1.0))
		elif rocket:
			bob = sin(t * 3.0) * 0.05 * float(prof.get("bob_amp", 1.0))
		elif not running and not sitting:
			bob = sin(t * 4.0) * 0.008
		bob += float(prof.get("body_y", 0.0))
		# присіду тут більше нема: ковзання на животі опускає ВСЕ тіло (Hero3D.SLIDE_BODY_Y),
		# а таз лишається на своєму місці — інакше опускання лічилось би двічі
		if wave_b > 0.001:
			# привітання: таз сідає на задні лапки. Нахил дибки крутить тіло НАВКОЛО ТАЗУ
			# (нижче), тож окремий підйом тіла більше не потрібен — залишок добирає
			# «копитця на підлозі»
			bob = lerpf(bob - float(prof.get("body_y", 0.0)), WAVE_BODY_Y, wave_b)
		# танець: м'який підскок на кожен біт (smoothstep, без гострих розворотів синуса)
		if float(prof.get("hop", 0.0)) > 0.0:
			bob += dance_bounce(t, DANCE_BPS) * DANCE_HOP * float(prof.get("hop", 0.0))
		# ракета трясе тіло — по вертикалі це видно найкраще (боком таз рухати небезпечно)
		var shake := float(prof.get("shake", 0.0))
		if shake > 0.0:
			_shake_t += delta
			if _shake_t >= 1.0 / SHAKE_HZ:
				_shake_t = 0.0
				_shake_off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_AMP * shake
			bob += _shake_off.y
		body_floor = minf(0.0, bob)
		if absf(bob) > 0.0002:
			var rest_pos := _skel.get_bone_rest(hi).origin
			# метри героя → одиниці моделі (_inv_scale) → одиниці скелета (_skel_unit)
			_skel.set_bone_pose_position(hi, rest_pos + _up_parent[hi] * bob * _inv_scale * _skel_unit)
		# танець: виляння ±spin_y навколо вертикалі (ліворуч — назад — праворуч — назад
		# за DANCE_SEC). Кут АБСОЛЮТНИЙ, а не накопичений: коли танець урвали на середині,
		# наступний кадр уже ставить кістку рівно, і герой не лишається розвернутим
		_spin_y = sin(TAU * dance_t / DANCE_SEC) * float(prof.get("spin_y", 0.0)) if dancing else 0.0
		# знак «+ = ніс УГОРУ» виміряний у build(); у профілі body_pitch навпаки («+ = ніс униз»),
		# тому кут іде з мінусом
		var hip_pitch := sin(phase * 2.0) * 0.02 if galloping else 0.0
		# ПРИВІТАННЯ КРУТИТЬСЯ САМЕ ТУТ, на кістці тазу: її оберт має шарнір у тазі, тож
		# задні копитця лишаються на місці, а вгору їде перед (у хребта шарнір вище —
		# з ним герой «ламався» посередині й зад ішов під підлогу)
		if wave_b > 0.001:
			hip_pitch = lerpf(hip_pitch, WAVE_BODY_PITCH, wave_b)
		# крен корпусу на кроці: таз хитається навколо модельного Z на частоті циклу
		var hip_roll := sin(phase) * GAIT_HIP_ROLL if galloping else 0.0
		_rot3(hi, _axis_x[hi], -_s("hips_pitch") * hip_pitch,
			_axis_y[hi], _spin_y, _axis_z[hi], hip_roll)

	# ── хребет: на кроці хвилює на ПОДВОЄНІЙ частоті, у профілі — свій нахил ──
	if _bones.has("spine"):
		var si := int(_bones["spine"])
		var sp := _s("spine_pitch")                       # + = ніс угору (виміряно в build)
		var pitch := -sp * float(prof.get("body_pitch", 0.0))
		if galloping:
			pitch += -sp * sin(phase * 2.0) * GAIT_SPINE_FLEX
		if duck > 0.001:
			pitch = lerpf(pitch, 0.0, duck)               # ковзання: корпус лежить рівно
		if wave_b > 0.001:
			# дибки нахиляє ТАЗ (див. вище), а хребет лишається прямим — інакше нахил
			# лічився б двічі й герой складався б навпіл
			pitch = lerpf(pitch, 0.0, wave_b)
		_rot(si, _axis_x[si], pitch)

	# ── шия й голова: контр-боб до тіла; у ковзанні морда ледь донизу, вздовж землі ──
	# `head_pitch` тут — у ЗНАКАХ ПРОФІЛЮ (+ = морда вниз); у кістки він іде помножений
	# на виміряний знак ролі (_calibrate_signs), окремо для шиї й для голови
	var head_pitch := 0.0
	if galloping:
		head_pitch = sin(phase + 1.2) * 0.08
	elif not running and not sitting:
		head_pitch = sin(t * 3.0) * 0.02
	head_pitch += SLIDE_HEAD_PITCH * duck + float(prof.get("head_pitch", 0.0))
	# привітання: голова НЕ киває носом униз (це читається як сердито), а трохи хилиться
	# набік — до піднятої правої лапки (крен навколо модельного Z)
	var head_roll := WAVE_HEAD_ROLL * wave_b
	if wave_b > 0.001:
		# тіло стало дибки — голова доверстує рівно стільки ж назад, і морда лишається
		# горизонтальною (дивиться в камеру), а не задирається в небо
		head_pitch = WAVE_HEAD_PITCH * wave_b
	if _bones.has("neck"):
		var ni := int(_bones["neck"])
		_rot2(ni, _axis_x[ni], _s("neck_pitch") * head_pitch * 0.5, _axis_z[ni], head_roll * 0.4)
	if _bones.has("head"):
		var hd := int(_bones["head"])
		_rot2(hd, _axis_x[hd], _s("head_pitch") * head_pitch * 0.5, _axis_z[hd], head_roll * 0.6)

	# ── вуха: поза з профілю + інерція бобу, у спокої ледь ворушаться ──
	var ear_mode := String(prof.get("ears", "free"))
	var ear_pose := float(EAR_POSE.get(ear_mode, 0.0))
	if duck > 0.001:
		ear_pose = lerpf(ear_pose, float(EAR_POSE["back"]), duck)   # ковзання: вуха прищулені
	var ear_lag := -sin(phase - 0.9) * 0.26 if galloping else 0.0
	for i in range(2):
		var role := "ear_l" if i == 0 else "ear_r"
		if not _bones.has(role):
			continue
		var ei := int(_bones[role])
		var idle := sin(t * 1.3 + float(i)) * 0.05 if ear_mode == "free" else 0.0
		# + = кінчик НАЗАД (виміряно в build), як і в EAR_POSE
		_rot(ei, _axis_x[ei], _s("%s_back" % role) * (ear_pose + ear_lag + idle))

	# ── хвіст: махає / стирчить угору / звисає вниз (ракета) / струною / виляє вгорі (танець) ──
	var tail = _bones.get("tail", [])
	if typeof(tail) == TYPE_ARRAY:
		var chain: Array = tail
		# дільник кутів: кожна ланка додає СВІЙ нахил, тож кут ділиться на довжину ланцюжка —
		# але не більше ніж на TAIL_CHAIN_MAX. У єдинорога в ролі `tail` 11 кісток (три окремі
		# пасма), і поділ на 11 з'їдав виляння танцю повністю
		var links := float(clampi(chain.size(), 1, TAIL_CHAIN_MAX))
		var mode := String(prof.get("tail", "wag"))
		if duck > 0.5:
			mode = "straight"                   # ковзання: хвіст витягнутий назад
		var amp := 0.45 if galloping else 0.25
		var freq := 7.0 if galloping else 3.0
		match mode:
			"straight":
				amp = 0.0
			"up":
				amp = 0.12
				freq = 4.0
			"down":
				amp = 0.0
			"wag_up":
				amp = 0.0
		for i in range(chain.size()):
			var ti := int(chain[i])
			# ВІСЬ ВИЛЯННЯ — модельна вертикаль (_axis_y), ВІСЬ ПІДЙОМУ — модельна бокова
			# (_axis_x). Знаки обох ВИМІРЯНІ в build() і свої для кожної ланки: у бічних пасом
			# хвоста єдинорога кістки лежать інакше, ніж в основного. У _rot2 перший аргумент
			# застосовується ОСТАННІМ, тож спершу хвіст піднімається, і вже піднятий виляє
			var s_lift: float = _tail_lift_sign[i] if i < _tail_lift_sign.size() else -_front
			var s_wag: float = _tail_wag_sign[i] if i < _tail_wag_sign.size() else 1.0
			var yaw := sin(t * freq - float(i) * 0.6) * amp * 0.6
			var lift := 0.35 if mode == "up" else 0.0
			if mode == "down":
				# ракета: хвіст ЗВИСАЄ вниз і повільно похитується (мінус = вниз)
				lift = ROCKET_TAIL_DOWN / links
				yaw = sin(t * TAU * ROCKET_TAIL_HZ - float(i) * 0.4) * ROCKET_TAIL_SWAY
			elif mode == "wag_up":
				# танець: хвіст тримається ВГОРІ й швидко виляє ліворуч-праворуч
				lift = DANCE_TAIL_LIFT / links
				yaw = sin(t * TAU * DANCE_TAIL_HZ - float(i) * 0.5) * DANCE_TAIL_WAG / links
			# базове тихе виляння — у КОЖНОМУ режимі (навіть "straight" і в танці):
			# хвіст ніколи не стоїть кілком, хвиля біжить від основи до кінчика
			yaw += sin(t * TAU * TAIL_IDLE_HZ - float(i) * 0.4) * TAIL_IDLE
			# на кроці хвіст іще й ВРІВНОВАЖУЄ корпус: відмахує ПРОТИ крену тазу
			if galloping:
				yaw += -sin(phase) * GAIT_TAIL_YAW
			_rot2(ti, _axis_y[ti], s_wag * yaw, _axis_x[ti], s_lift * lift)

	# ── копитця на підлозі: після всіх поз найнижчий кінчик лапки не має тонути в землі ──
	_apply_ground_lift(duck, airborne, body_floor)


## Підняти всю модель, якщо після пози найнижче копитце провалилось під землю. Нахили
## (спринт, стійка дибки, підскоки танцю) крутять тіло навколо ЙОГО центру, і зад чи перед
## ідуть під підлогу — замість того, щоб гадати компенсацію на кожну позу, міряємо результат.
## У КОВЗАННІ не працює (герой навмисно лежить на землі — тому × (1 − duck)),
## у повітрі теж (лапки й мають висіти).
## `floor_y` (≤ 0) — наскільки поза НАВМИСНО опустила таз: на стільки копитцям бути нижче
## нуля дозволено (спринт притискає героя до землі, і «випрямляти» його назад не можна).
func _apply_ground_lift(duck: float, airborne: bool, floor_y: float) -> void:
	if _root == null or not is_instance_valid(_root):
		return
	var lift := 0.0
	if not airborne and not _leg_tips.is_empty():
		_skel.force_update_all_bone_transforms()
		var low := _lowest_hoof() - minf(floor_y, 0.0)
		if low < -GROUND_EPS:
			lift = clampf(-low, 0.0, GROUND_LIFT_MAX) * (1.0 - clampf(duck, 0.0, 1.0))
	_root.position.y = _root_y0 + lift


## Найнижчий кінчик лапки в метрах героя (0 — рівень землі, мінус — під землею).
## Кінчики знайдені один раз у build() (_leg_tip), тут лише читаємо позу.
func _lowest_hoof() -> float:
	var low := 0.0
	var first := true
	for e in _leg_tips:
		var idx := int((e as Array)[0])
		var loc: Vector3 = (e as Array)[1]
		var mp := _model_point(_skel.get_bone_global_pose(idx) * loc)
		var y := (mp.y - _model_box.position.y) * _scale
		if first or y < low:
			low = y
			first = false
	return low


## Прибрати рига (Hero3D перебудовує героя). Вузли гинуть разом із _body,
## але посилання чистимо, щоб animate() нічого не чіпав.
func dispose() -> void:
	_ready = false
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_model = null
	_skel = null
	_meshes.clear()
	_anchors.clear()
	_leg_tips.clear()
	_lower_leg.clear()


# ──────────────────────────────── дрібниці ────────────────────────────────

## Перетворення з координат `from` у координати `to` без дерева сцени
## (у момент build() модель ще не додана в гру, global_transform іще не той).
## Обидва вузли всередині одного інстансу .glb, тож рахуємо через спільний корінь.
static func _rel_transform(from: Node3D, to: Node3D) -> Transform3D:
	return _abs_transform(to).affine_inverse() * _abs_transform(from)


static func _abs_transform(node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n != null:
		t = n.transform * t
		n = n.get_parent() as Node3D
	return t
