## Скелетний герой (HeroRig): чисті функції розкладки кісток і зон розмальовки + дані heroes.json.
## Самої моделі .glb у репозиторії може ще не бути (docs/tasks/rig.md, крок «скопіювати») —
## тести це враховують і НЕ падають: перевіряють лише те, що можна перевірити без файлу.
extends GutTest

## Типовий Mixamo-подібний риг, який Meshy віддає на чотирилапій моделі:
## руки — передні лапки, ноги — задні.
const MIXAMO := [
	"mixamorig:Hips", "mixamorig:Spine", "mixamorig:Spine1", "mixamorig:Neck", "mixamorig:Head",
	"mixamorig:HeadTop_End",
	"mixamorig:LeftShoulder", "mixamorig:LeftArm", "mixamorig:LeftForeArm", "mixamorig:LeftHand",
	"mixamorig:RightShoulder", "mixamorig:RightArm", "mixamorig:RightForeArm", "mixamorig:RightHand",
	"mixamorig:LeftUpLeg", "mixamorig:LeftLeg", "mixamorig:LeftFoot",
	"mixamorig:RightUpLeg", "mixamorig:RightLeg", "mixamorig:RightFoot",
]

## «Людський» риг звірятка: явні front/back, вуха, хвіст ланцюжком.
const CRITTER := [
	"root", "pelvis", "spine_01", "neck_01", "head",
	"ear_L", "ear_R",
	"tail_01", "tail_02", "tail_03",
	"front_leg_L", "front_paw_L", "front_leg_R", "front_paw_R",
	"back_leg_L", "back_paw_L", "back_leg_R", "back_paw_R",
]


# ---------- розкладка кісток за іменами ----------

func test_mixamo_names() -> void:
	var names := MIXAMO
	var m := HeroRig.map_bones_by_name(names)
	assert_eq(String(names[int(m["hips"])]), "mixamorig:Hips")
	assert_eq(String(names[int(m["neck"])]), "mixamorig:Neck")
	assert_eq(String(names[int(m["head"])]), "mixamorig:Head", "HeadTop_End — не голова, це кінцівка ієрархії")
	assert_eq(String(names[int(m["spine"])]), "mixamorig:Spine", "з двох Spine беремо нижній")
	# передні лапки — руки, і саме ВЕРХНЯ кістка (Arm), а не ForeArm/Hand/Shoulder
	assert_eq(String(names[int(m["fl"])]), "mixamorig:LeftArm")
	assert_eq(String(names[int(m["fr"])]), "mixamorig:RightArm")
	assert_eq(String(names[int(m["bl"])]), "mixamorig:LeftUpLeg")
	assert_eq(String(names[int(m["br"])]), "mixamorig:RightUpLeg")
	assert_false(m.has("tail"), "у Mixamo-рига хвоста нема — і не вигадуємо")


func test_critter_names() -> void:
	var names := CRITTER
	var m := HeroRig.map_bones_by_name(names)
	assert_eq(String(names[int(m["hips"])]), "pelvis", "pelvis сильніший за root")
	assert_eq(String(names[int(m["spine"])]), "spine_01")
	assert_eq(String(names[int(m["neck"])]), "neck_01")
	assert_eq(String(names[int(m["head"])]), "head")
	assert_eq(String(names[int(m["ear_l"])]), "ear_L")
	assert_eq(String(names[int(m["ear_r"])]), "ear_R")
	assert_eq(String(names[int(m["fl"])]), "front_leg_L")
	assert_eq(String(names[int(m["br"])]), "back_leg_R")
	var tail: Array = m["tail"]
	assert_eq(tail.size(), 3, "три кістки хвоста")
	assert_eq(String(names[int(tail[0])]), "tail_01", "ланцюжок від основи до кінчика")
	assert_eq(String(names[int(tail[2])]), "tail_03")


func test_unknown_names_map_to_nothing() -> void:
	# саме такі імена інколи дає Meshy — тоді працює геометрична евристика й rig_bones
	var m := HeroRig.map_bones_by_name(["Bone_0", "Bone_1", "Bone_2"])
	assert_true(m.is_empty(), "з безіменних кісток за іменами нічого не витягнеш")


func test_empty_input() -> void:
	assert_true(HeroRig.map_bones_by_name([]).is_empty())


# ---------- розкладка за геометрією (запасний варіант) ----------

## Синтетичне звірятко з безіменними кістками: таз позаду-внизу, голова спереду-вгорі,
## чотири лапки по кутах, хвіст ззаду. Модель дивиться в −Z.
func test_geometry_fallback() -> void:
	var names := ["Bone_0", "Bone_1", "Bone_2", "Bone_3", "Bone_4", "Bone_5", "Bone_6", "Bone_7"]
	var parents := [-1, 0, 1, 2, 0, 0, 0, 0]
	var origins := [
		Vector3(0.0, 0.5, 0.2),      # 0 таз
		Vector3(0.0, 0.55, 0.0),     # 1 хребет
		Vector3(0.0, 0.62, -0.2),    # 2 шия
		Vector3(0.0, 0.75, -0.3),    # 3 голова
		Vector3(-0.15, 0.3, -0.15),  # 4 передня ліва
		Vector3(0.15, 0.3, -0.15),   # 5 передня права
		Vector3(-0.15, 0.3, 0.25),   # 6 задня ліва
		Vector3(0.15, 0.3, 0.25),    # 7 задня права
	]
	var m := HeroRig.map_bones_by_geometry(names, parents, origins, -1.0)
	assert_eq(int(m["fl"]), 4)
	assert_eq(int(m["fr"]), 5)
	assert_eq(int(m["bl"]), 6)
	assert_eq(int(m["br"]), 7)
	assert_eq(int(m["head"]), 3, "найвища центральна кістка попереду тазу — голова")


# ---------- зони розмальовки ----------

func test_zone_head_muzzle() -> void:
	var z := HeroRig.DEFAULT_ZONES
	# перед голови (z ≈ 1) і низ (y < 0.55) — кремова морда
	assert_eq(HeroRig.zone_for("head", Vector3(0.5, 0.3, 0.9), z), "c")
	# той самий перед, але лоб — основний колір
	assert_eq(HeroRig.zone_for("head", Vector3(0.5, 0.8, 0.9), z), "o")
	# потилиця — основний колір
	assert_eq(HeroRig.zone_for("head", Vector3(0.5, 0.3, 0.1), z), "o")


func test_zone_legs_and_ears_and_tail() -> void:
	var z := HeroRig.DEFAULT_ZONES
	for role in ["fl", "fr", "bl", "br"]:
		assert_eq(HeroRig.zone_for(role, Vector3(0.5, 0.1, 0.5), z), "k", "%s: копитце темне" % role)
		assert_eq(HeroRig.zone_for(role, Vector3(0.5, 0.9, 0.5), z), "o", "%s: стегно основне" % role)
	assert_eq(HeroRig.zone_for("ear_l", Vector3(0.5, 0.5, 0.95), z), "i", "серединка вуха рожева")
	assert_eq(HeroRig.zone_for("ear_r", Vector3(0.5, 0.5, 0.05), z), "e", "спинка вуха — темний обід, а не основний колір")
	assert_eq(HeroRig.zone_for("tail", Vector3(0.5, 0.5, 0.05), z), "c", "кінчик хвоста — крем")
	assert_eq(HeroRig.zone_for("tail", Vector3(0.5, 0.95, 0.5), z), "c", "піднятий хвіст: кінчик угорі")
	assert_eq(HeroRig.zone_for("tail", Vector3(0.5, 0.5, 0.9), z), "o", "основа хвоста — основний колір")


## Малярські ролі: чубчик на маківці й кістки писка.
func test_zone_tuft_and_nose() -> void:
	var z := HeroRig.DEFAULT_ZONES
	# чубчик акцентний ЛИШЕ коли справді стирчить над черепом (above = true)
	assert_eq(HeroRig.zone_for("tuft", Vector3(0.5, 0.5, 0.5), z), "t", "камінець над черепом — акцентний")
	# кістка чубчика сидить усередині голови, тож пів черепа теж має роль tuft:
	# такі вершини йдуть звичайними правилами голови (координати — в коробці голови)
	assert_eq(HeroRig.zone_for("tuft", Vector3(0.5, 0.8, 0.1), z, false), "o",
		"чубчик під верхом черепа — це просто голова, основний колір")
	assert_eq(HeroRig.zone_for("tuft", Vector3(0.5, 0.3, 0.9), z, false), "c",
		"чубчик під верхом черепа на морді — крем за правилами голови")
	# ніс: темний лише передній кінчик І верхня половина писка
	assert_eq(HeroRig.zone_for("nose", Vector3(0.5, 0.7, 0.95), z), "k", "кінчик носа темний")
	assert_eq(HeroRig.zone_for("nose", Vector3(0.5, 0.2, 0.95), z), "c", "під носом губа — крем")
	assert_eq(HeroRig.zone_for("nose", Vector3(0.5, 0.7, 0.7), z), "c",
		"глибина 0,7 вже за межами nose_tip=0,22 — крем")
	assert_eq(HeroRig.zone_for("nose", Vector3(0.5, 0.5, 0.2), z), "c", "решта писка — крем")


## ОСНОВА чубчика: обідок черепа одразу під ним (між вухами) світився помаранчевим —
## тепер це власна зона `u` (акцент, темніший на 0,15).
func test_zone_tuft_base_ring() -> void:
	var z := HeroRig.DEFAULT_ZONES
	# смуга [1 − TUFT_ABOVE − TUFT_BASE, 1 − TUFT_ABOVE] у коробці ГОЛОВИ
	var inside := 1.0 - HeroRig.TUFT_ABOVE - HeroRig.TUFT_BASE * 0.5
	assert_eq(HeroRig.zone_for("tuft", Vector3(0.5, inside, 0.1), z, false), "u",
		"обідок під чубчиком — темніше золото, а не помаранчева щілина")
	# нижче смуги — звичайні правила голови
	var below := 1.0 - HeroRig.TUFT_ABOVE - HeroRig.TUFT_BASE - 0.05
	assert_eq(HeroRig.zone_for("tuft", Vector3(0.5, below, 0.1), z, false), "o",
		"нижче обідка — просто голова")
	# те, що стирчить над черепом, лишається акцентним
	assert_eq(HeroRig.zone_for("tuft", Vector3(0.5, inside, 0.1), z, true), "t",
		"над черепом — сам чубчик, повний акцент")
	assert_lt(HeroRig.TUFT_BASE, 0.25, "обідок вузький, а не пів голови")


## Ручні позначки `rig_marks` — коли наріст не ловиться геометрією bag_x.
func test_marks_of_reads_data() -> void:
	assert_eq(HeroRig.marks_of({}).size(), 0, "нема поля — нема позначок")
	assert_eq(HeroRig.marks_of({"rig_marks": "торба"}).size(), 0, "не список — ігноруємо")
	var two := HeroRig.marks_of({"rig_marks": [
		{"min": [0.0, 0.0, 0.0], "max": [0.1, 0.1, 0.1]}, 7,
		{"side": "left"}]})
	assert_eq(two.size(), 2, "беремо лише словники")


func test_mark_hit_box() -> void:
	var marks := [{"min": [0.1, 0.3, -0.1], "max": [0.25, 0.6, 0.3]}]
	assert_true(HeroRig.mark_hit(marks, Vector3(0.2, 0.45, 0.1), "spine", Vector3.ZERO, 0.2, 0.18),
		"центроїд усередині коробки — це позначка")
	assert_false(HeroRig.mark_hit(marks, Vector3(-0.2, 0.45, 0.1), "spine", Vector3.ZERO, -0.2, 0.18),
		"той самий бік з іншим знаком x — повз коробку")
	assert_false(HeroRig.mark_hit(marks, Vector3(0.2, 0.9, 0.1), "spine", Vector3.ZERO, 0.2, 0.18),
		"вище коробки — не позначка")
	# роль не важлива: коробка ловить будь-яку грань (наприклад нашийник на шиї)
	assert_true(HeroRig.mark_hit(marks, Vector3(0.2, 0.45, 0.1), "head", Vector3.ZERO, 0.2, 0.18))
	# кінці можна писати в будь-якому порядку
	var flipped := [{"min": [0.25, 0.6, 0.3], "max": [0.1, 0.3, -0.1]}]
	assert_true(HeroRig.mark_hit(flipped, Vector3(0.2, 0.45, 0.1), "spine", Vector3.ZERO, 0.2, 0.18))


func test_mark_hit_side_shorthand() -> void:
	var half := 0.2
	var far := half * HeroRig.MARK_SIDE + 0.01      # за порогом 85 % півширини
	var near_x := half * HeroRig.MARK_SIDE - 0.01   # ще не наріст
	var left := [{"side": "left", "y": [0.3, 0.6]}]
	assert_true(HeroRig.mark_hit(left, Vector3.ZERO, "spine", Vector3(0.5, 0.45, 0.5), -far, half),
		"лівий бік тулуба за порогом і в смузі — позначка")
	assert_false(HeroRig.mark_hit(left, Vector3.ZERO, "spine", Vector3(0.5, 0.45, 0.5), far, half),
		"правий бік не чіпаємо")
	assert_false(HeroRig.mark_hit(left, Vector3.ZERO, "spine", Vector3(0.5, 0.45, 0.5), -near_x, half),
		"ближче за 85 % півширини — це просто бік, не наріст")
	assert_false(HeroRig.mark_hit(left, Vector3.ZERO, "spine", Vector3(0.5, 0.8, 0.5), -far, half),
		"поза смугою по висоті")
	assert_false(HeroRig.mark_hit(left, Vector3.ZERO, "fl", Vector3(0.5, 0.45, 0.5), -far, half),
		"скорочення працює лише по тулубу")
	# смуги необов'язкові — без них береться весь бік
	var right := [{"side": "right"}]
	assert_true(HeroRig.mark_hit(right, Vector3.ZERO, "neck", Vector3(0.5, 0.95, 0.5), far, half))
	assert_false(HeroRig.mark_hit(right, Vector3.ZERO, "neck", Vector3(0.5, 0.95, 0.5), far, -1.0),
		"півширини нема — рахувати нема від чого")
	assert_false(HeroRig.mark_hit([], Vector3.ZERO, "spine", Vector3(0.5, 0.45, 0.5), -far, half),
		"порожній список нічого не фарбує")


## Симетричний тулуб: зсуви по x від −w до +w, по `n` вершин з кожного боку.
static func _torso(n: int, w: float) -> Array:
	var out := []
	for i in range(n):
		var f := w * float(i) / float(maxi(n - 1, 1))
		out.append(-f)
		out.append(f)
	return out


## Торбинка збоку тулуба: у неї нема кістки, ловимо геометрією — тіло симетричне,
## торба висить з одного боку.
func test_bag_cut() -> void:
	var plain := _torso(150, 0.2)
	assert_almost_eq(HeroRig.bag_cut(plain, 1.05), -1.0, 0.0001, "симетричний тулуб — торби нема")
	# та сама модель, але праворуч наросла торба на 0,30 (у півтора рази далі за бік)
	var with_bag := plain.duplicate()
	for i in range(60):
		with_bag.append(0.3)
	var cut := HeroRig.bag_cut(with_bag, 1.05)
	assert_gt(cut, 0.2, "поріг вище за справжню півширину тулуба")
	assert_lt(cut, 0.3, "але нижче за саму торбу")
	# купка замала — це шум моделі, а не торба
	var tiny := plain.duplicate()
	for i in range(5):
		tiny.append(0.3)
	assert_almost_eq(HeroRig.bag_cut(tiny, 1.05), -1.0, 0.0001, "5 вершин — не торба")
	assert_almost_eq(HeroRig.bag_cut([0.1, -0.2], 1.05), -1.0, 0.0001, "мало вершин — не рахуємо")
	# більший bag_x — торбу вже не видно (поріг поїхав за неї)
	assert_almost_eq(HeroRig.bag_cut(with_bag, 2.0), -1.0, 0.0001, "bag_x із даних керує порогом")
	# дефолтний поріг трохи нижчий за півширину боку — торбу видно ширше
	var wide := HeroRig.bag_cut(with_bag, float(HeroRig.DEFAULT_ZONES["bag_x"]))
	assert_gt(wide, 0.0, "дефолтний bag_x = 0,98 торбу бачить")
	assert_lt(wide, cut, "0,98 бере ширшу смугу, ніж 1,05")


## Торба висить з ОДНОГО боку — протилежний бік тулуба фарбувати не можна.
func test_bag_side() -> void:
	var plain := _torso(150, 0.2)
	var with_bag := plain.duplicate()
	for i in range(60):
		with_bag.append(0.3)
	var cut := HeroRig.bag_cut(with_bag, 1.05)
	assert_eq(HeroRig.bag_side(with_bag, cut), 1, "наріст праворуч")
	var left_bag := plain.duplicate()
	for i in range(60):
		left_bag.append(-0.3)
	assert_eq(HeroRig.bag_side(left_bag, HeroRig.bag_cut(left_bag, 1.05)), -1, "наріст ліворуч")
	assert_eq(HeroRig.bag_side(with_bag, -1.0), 0, "торби нема — і боку нема")
	# симетричні широкі боки: жоден бік не переважає, фарбуємо обидва
	var both := plain.duplicate()
	for i in range(30):
		both.append(0.3)
		both.append(-0.3)
	assert_eq(HeroRig.bag_side(both, 0.25), 0, "наріст з обох боків — це не однобока торба")


## Півширина тулуба — той бік, який ВУЖЧИЙ (торба висить з одного боку й не має його задирати).
func test_torso_half_width() -> void:
	var plain := _torso(150, 0.2)
	assert_almost_eq(HeroRig.torso_half_width(plain), 0.2, 0.02, "симетричний тулуб — його ж півширина")
	var with_bag := plain.duplicate()
	for i in range(60):
		with_bag.append(0.3)
	assert_almost_eq(HeroRig.torso_half_width(with_bag), 0.2, 0.02,
		"торба праворуч не роздуває півширину — беремо вужчий бік")
	assert_almost_eq(HeroRig.torso_half_width([0.1, -0.2]), -1.0, 0.0001, "мало точок — рахувати нема з чого")


## Сітка граней тулуба: 6×6 комірок по (y, z), у кожній `per` ПАР граней (±w по x).
## Тіла в комірці має бути помітно більше, ніж наросту, — інакше перцентиль з'їде на сумку.
static func _slab(per: int, w: float) -> Array:
	var out := []
	for gy in range(6):
		for gz in range(6):
			var y := (float(gy) + 0.5) / 6.0
			var z := (float(gz) + 0.5) / 6.0
			for i in range(per):
				out.append(Vector3(w, y, z))
				out.append(Vector3(-w, y, z))
	return out


## ВИСТУП грані вбік: локальна півширина рахується в комірці сітки (y, z), тож наріст видно
## навіть коли він рівно на габариті моделі — саме на цьому «сліпнув» старий поріг bag_x.
func test_outwardness() -> void:
	var flat := _slab(20, 0.2)
	var out := HeroRig.outwardness(flat)
	assert_eq(out.size(), flat.size(), "виступ рахується на кожну грань")
	for v in out:
		assert_almost_eq(float(v), 0.0, 0.0001, "рівний бік — виступу нема")
	# сумка: у ДВОХ комірках праворуч бік відходить на 4 см
	var bag := flat.duplicate()
	for i in range(20):
		bag.append(Vector3(0.24, 0.45, 0.45))
		bag.append(Vector3(0.24, 0.45, 0.60))
	var out2 := HeroRig.outwardness(bag)
	var mx := 0.0
	var over := 0
	for i in range(out2.size()):
		mx = maxf(mx, float(out2[i]))
		if float(out2[i]) > HeroRig.SIDE_MIN_OUT:
			over += 1
	assert_almost_eq(mx, 0.04, 0.005, "наріст стирчить на 4 см за локальну півширину")
	assert_eq(over, 40, "за поріг вийшли рівно грані сумки")
	assert_eq(HeroRig.outwardness([]).size(), 0, "порожній список — порожній результат")
	# одна комірка на весь тулуб (grid = 1): 40-й перцентиль однаковий для всіх
	var one := HeroRig.outwardness([Vector3(0.1, 0.5, 0.5), Vector3(0.3, 0.5, 0.5)], 1)
	assert_almost_eq(float(one[0]), 0.0, 0.0001, "перша точка — вона ж і перцентиль")
	assert_almost_eq(float(one[1]), 0.2, 0.0001, "друга стирчить на різницю")


## Купки: сусідні комірки злипаються в одну сумку, дрібний шум відкидається за кількістю.
func test_side_clusters() -> void:
	var flat := _slab(20, 0.2)
	var pts := flat.duplicate()
	for i in range(20):
		pts.append(Vector3(0.24, 0.45, 0.45))
		pts.append(Vector3(0.24, 0.45, 0.50))       # сусідня комірка — та сама сумка
	for i in range(4):
		pts.append(Vector3(-0.24, 0.8, 0.1))        # шум ліворуч — купка замала
	var cl := HeroRig.side_clusters(pts, HeroRig.outwardness(pts))
	assert_eq(cl.size(), 2, "дві купки: сумка праворуч і шум ліворуч")
	var bag: Dictionary = cl[0]
	assert_eq(int(bag["n"]), 40, "сумка злиплась із двох комірок")
	assert_eq(int(bag["side"]), 1, "сумка праворуч")
	assert_true(bool(bag["ok"]), "40 граней ≥ SIDE_MIN_FACES — фарбуємо")
	assert_almost_eq(float((bag["center"] as Vector3).y), 0.45, 0.01, "центр по висоті")
	var noise: Dictionary = cl[1]
	assert_eq(int(noise["n"]), 4)
	assert_eq(int(noise["side"]), -1)
	assert_false(bool(noise["ok"]), "4 грані — це шум децимації, а не сумка")
	# симетричний тулуб — купок нема взагалі
	assert_eq(HeroRig.side_clusters(flat, HeroRig.outwardness(flat)).size(), 0,
		"рівні боки — нема чого фарбувати")


## Колір і нормаль тепер на ГРАНЬ, тож у трикутника має бути одна «головна» кістка.
func test_major_bone() -> void:
	assert_eq(HeroRig.major_bone(3, 3, 3), 3, "уся грань на одній кістці")
	assert_eq(HeroRig.major_bone(3, 7, 7), 7, "більшість — дві вершини з трьох")
	assert_eq(HeroRig.major_bone(7, 3, 7), 7)
	assert_eq(HeroRig.major_bone(7, 7, 3), 7)
	assert_eq(HeroRig.major_bone(1, 2, 3), 1, "усі різні — беремо першу, аби детерміновано")
	assert_eq(HeroRig.major_bone(-1, -1, 5), -1, "кістки без ваг теж голосують")


# ---------- стилі розмальовки (RigStyles) ----------

## Веселка: 6 дискретних смуг, на 0 / 0,5 / 1 — рівно стопи (перший, четвертий, останній).
func test_rainbow_stops() -> void:
	assert_eq(RigStyles.rainbow(0.0).to_html(false), "FF5E7E", "початок — рожевий")
	assert_eq(RigStyles.rainbow(0.5).to_html(false), "7CE38B", "середина — зелений (4-й із 6)")
	assert_eq(RigStyles.rainbow(1.0).to_html(false), "B18CFF", "кінчик — бузковий")
	assert_eq(RigStyles.rainbow(-3.0).to_html(false), "FF5E7E", "за межами діапазону не падаємо")
	assert_eq(RigStyles.rainbow(9.0).to_html(false), "B18CFF")
	# смуги різні: сусідні чверті не збігаються
	assert_ne(RigStyles.rainbow(0.1).to_html(false), RigStyles.rainbow(0.3).to_html(false))


func test_for_def() -> void:
	assert_true(RigStyles.for_def({}).is_empty(), "без rig_style стилю нема")
	assert_true(RigStyles.for_def({"rig_style": "немає_такого"}).is_empty(), "чуже ім'я — теж порожньо")
	var s := RigStyles.for_def({"rig_style": "unicorn"})
	assert_false(s.is_empty(), "стиль єдинорога є")
	assert_true(s.has("palette") and s.has("bands"),
		"у стилі є підміни палітри й пояси гриви/хвоста (веселки за замовчуванням більше нема)")
	assert_false(s.has("rainbow"), "єдиноріг більше не веселковий — біле тіло з пастельними акцентами")
	assert_false(s.has("sparkle"), "зірочки вимкнені")


## Підміна кольорів символів: тіло біліє, писок рожевіє, животик бузковіє.
func test_palette_of() -> void:
	var base := {"o": Color("#F4EFFF"), "c": Color("#F6E3C2"), "d": Color("#111111"),
		"m": Color("#FF8AD8")}
	var out := RigStyles.palette_of(RigStyles.for_def({"rig_style": "unicorn"}), base)
	assert_eq((out["o"] as Color).to_html(false), "FFFFFF", "тіло єдинорога біле")
	assert_eq((out["c"] as Color).to_html(false), "FBE9F0", "писок — рожево-білий")
	assert_eq((out["d"] as Color).to_html(false), "F3EEF8", "животик — бузковий")
	assert_eq((out["m"] as Color).to_html(false), "FF8AD8", "символи поза стилем не чіпаємо")
	assert_eq((base["o"] as Color).to_html(false), "F4EFFF", "вхідний словник не змінився")
	assert_eq((RigStyles.palette_of({}, base)["c"] as Color).to_html(false), "F6E3C2", "без стилю — як було")


## Копитця тепер малює сам стиль (кольори по лапках), а не підміна символа зони.
func test_zone_swap() -> void:
	var s := RigStyles.for_def({"rig_style": "unicorn"})
	assert_eq(RigStyles.swap_zone(s, "k"), "k", "єдиноріг більше не міняє символ копитця")
	assert_eq(RigStyles.swap_zone(s, "o"), "o", "решта символів не міняється")
	assert_eq(RigStyles.swap_zone({"zone_swap": {"k": "m"}}, "k"), "m", "механізм підміни лишився")
	assert_eq(RigStyles.swap_zone({}, "k"), "k", "без стилю копитця темні, як у всіх")


## Копитця єдинорога: бірюза й м'ята навхрест (fl+br ↔ fr+bl), і лише в зоні `k`.
func test_hoof_colors() -> void:
	var s := RigStyles.for_def({"rig_style": "unicorn"})
	var hoof := HeroRig.zone_for("fl", Vector3(0.5, 0.1, 0.5), HeroRig.DEFAULT_ZONES)
	assert_eq(hoof, "k", "низ лапки — темна зона, саме її перефарбовує стиль")
	for role in ["fl", "br"]:
		var c: Color = RigStyles.face_color(s, role, Vector3(0.5, 0.1, 0.5), -1.0, 1,
			Vector3(-1.0, -1.0, -1.0), hoof)
		assert_eq(c.to_html(false), "5CC8B8", "%s: бірюзове копитце" % role)
	for role2 in ["fr", "bl"]:
		var c2: Color = RigStyles.face_color(s, role2, Vector3(0.5, 0.1, 0.5), -1.0, 1,
			Vector3(-1.0, -1.0, -1.0), hoof)
		assert_eq(c2.to_html(false), "7ED9A0", "%s: м'ятне копитце" % role2)
	assert_null(RigStyles.face_color(s, "fl", Vector3(0.5, 0.9, 0.5), -1.0, 1,
		Vector3(-1.0, -1.0, -1.0), "o"), "стегно — звичайна зона, не копитце")


## Пояси гриви й хвоста: рожевий і кораловий чергуються кожні 25 % ланцюжка.
func test_bands() -> void:
	assert_eq(RigStyles.band_color(["#111111", "#222222"], 0.25, 0.0).to_html(false), "111111")
	assert_eq(RigStyles.band_color(["#111111", "#222222"], 0.25, 0.3).to_html(false), "222222")
	assert_eq(RigStyles.band_color(["#111111", "#222222"], 0.25, 0.6).to_html(false), "111111")
	assert_eq(RigStyles.band_color(["#111111", "#222222"], 0.25, 1.0).to_html(false), "222222",
		"кінчик — четвертий пояс")
	assert_eq(RigStyles.band_color([], 0.25, 0.5).to_html(false), "FFFFFF", "без кольорів не падаємо")
	# у стилі: пояси по всьому ланцюжку + рідкі помаранчеві грані
	var s := RigStyles.for_def({"rig_style": "unicorn"})
	var seen := {}
	var accent := 0
	for i in range(400):
		var c: Color = RigStyles.face_color(s, "tail", Vector3(0.5, 0.5, 0.5),
			float(i) / 399.0, i)
		seen[c.to_html(false)] = true
		if c.to_html(false) == "FFB36B":
			accent += 1
	assert_true(seen.has("F48FB1") and seen.has("FF9E7A"), "рожевий і кораловий пояси є")
	assert_between(accent, 15, 110, "помаранчевих граней мало (%d з 400)" % accent)
	assert_true(seen.size() <= 3, "жодних інших кольорів у гриві/хвості нема: %s" % seen.keys())


## Поки грива й ріг не задані кістками, вони ловляться геометрією коробки голови.
func test_remap_role_fallback() -> void:
	var s := RigStyles.for_def({"rig_style": "unicorn"})
	# ріг: верхівка голови, по центру, передня половина
	var horn := RigStyles.remap_role(s, "head", Vector3(0.5, 0.95, 0.7), false, false)
	assert_eq(String(horn["role"]), "horn")
	var hl: Vector3 = horn["local"]
	assert_between(hl.y, 0.6, 1.0, "частки перераховані під сам ріг (верхні 18 % → 0..1)")
	# грива: задні 35 % глибини, верхні 40 % висоти
	assert_eq(String(RigStyles.remap_role(s, "head", Vector3(0.5, 0.8, 0.2), false, false)["role"]), "mane")
	assert_eq(String(RigStyles.remap_role(s, "neck", Vector3(0.5, 0.9, 0.1), false, false)["role"]), "mane")
	# морда й потилиця внизу лишаються головою
	assert_eq(String(RigStyles.remap_role(s, "head", Vector3(0.5, 0.3, 0.9), false, false)["role"]), "head")
	assert_eq(String(RigStyles.remap_role(s, "head", Vector3(0.5, 0.2, 0.1), false, false)["role"]), "head")
	# ріг збоку голови — це не ріг
	assert_eq(String(RigStyles.remap_role(s, "head", Vector3(0.95, 0.95, 0.7), false, false)["role"]), "head")
	# кістки задані руками (rig_bones) — геометрія рога більше не потрібна
	assert_eq(String(RigStyles.remap_role(s, "head", Vector3(0.5, 0.95, 0.7), true, true)["role"]), "head")
	# …а от грива в єдинорога живе й поза кістками (гребінь на потилиці): `mane_fallback.always`
	assert_eq(String(RigStyles.remap_role(s, "neck", Vector3(0.5, 0.9, 0.1), true, true)["role"]), "mane",
		"кісткова гичка спереду не скасовує гребеня вздовж шиї")
	var once := {"mane_fallback": {"depth": 0.35, "height": 0.4}}
	assert_eq(String(RigStyles.remap_role(once, "neck", Vector3(0.5, 0.9, 0.1), true, false)["role"]), "neck",
		"без `always` кістки гриви вимикають геометрію, як було")
	assert_eq(String(RigStyles.remap_role({}, "head", Vector3(0.5, 0.95, 0.7), false, false)["role"]), "head",
		"без стилю ролі не вигадуються")


## Готовий колір грані повз зони: пояси гриви й хвоста, смужки рога.
func test_face_color() -> void:
	var s := RigStyles.for_def({"rig_style": "unicorn"})
	assert_null(RigStyles.face_color({}, "tail", Vector3(0.5, 0.5, 0.5), 0.0, 1), "без стилю — нічого")
	assert_null(RigStyles.face_color(s, "head", Vector3(0.5, 0.5, 0.5), -1.0, 1), "голова йде звичайною зоною")
	# хвіст: колір за положенням у ланцюжку. Акцентні грані стилю випадають за сідом, тож
	# ТОЧНІ пояси перевіряємо на стилі без акценту (сам акцент — у test_bands)
	var plain := {"bands": {"roles": ["mane", "tail"], "colors": ["#F48FB1", "#FF9E7A"], "band": 0.25}}
	var t0: Color = RigStyles.face_color(plain, "tail", Vector3(0.5, 0.5, 0.5), 0.0, 1)
	var t1: Color = RigStyles.face_color(plain, "tail", Vector3(0.5, 0.5, 0.5), 0.3, 1)
	assert_eq(t0.to_html(false), "F48FB1", "основа хвоста — рожевий пояс")
	assert_eq(t1.to_html(false), "FF9E7A", "наступні 25 % — кораловий")
	# одна кістка на всю гриву (chain_t = −1): рахуємо по z, кінчик позаду
	var back: Color = RigStyles.face_color(plain, "mane", Vector3(0.5, 0.5, 0.0), -1.0, 1)
	assert_eq(back.to_html(false), "FF9E7A", "потилиця гриви — кінець ланцюжка")
	# ріг: кремова й помаранчева смуги чергуються кожні 12 % висоти
	var a: Color = RigStyles.face_color(s, "horn", Vector3(0.5, 0.05, 0.5), -1.0, 1)
	var b: Color = RigStyles.face_color(s, "horn", Vector3(0.5, 0.18, 0.5), -1.0, 1)
	assert_eq(a.to_html(false), "F6E3C2", "перша смуга — крем")
	assert_eq(b.to_html(false), "FFB36B", "наступні 12 % — помаранчева")
	assert_eq((RigStyles.face_color(s, "horn", Vector3(0.5, 0.3, 0.5), -1.0, 1) as Color).to_html(false),
		"F6E3C2", "і знову крем")


## Сердечко на грудях: передні 25 % глибини тулуба, ±30 % ширини, 40…80 % висоти.
func test_chest_heart() -> void:
	var s := RigStyles.for_def({"rig_style": "unicorn"})
	# частки габариту ТУЛУБА: x 0 ліворуч … 1 праворуч, y знизу вгору, z = 1 перед героя
	var hit: Color = RigStyles.face_color(s, "spine", Vector3(0.5, 0.5, 0.5), -1.0, 1,
		Vector3(0.5, 0.6, 0.95))
	assert_eq(hit.to_html(false), "E9B7F2", "груди спереду по центру — лавандове сердечко")
	assert_null(RigStyles.face_color(s, "spine", Vector3(0.5, 0.5, 0.5), -1.0, 1,
		Vector3(0.5, 0.6, 0.5)), "середина тулуба — не груди")
	assert_null(RigStyles.face_color(s, "spine", Vector3(0.5, 0.5, 0.5), -1.0, 1,
		Vector3(0.9, 0.6, 0.95)), "збоку від центру сердечка нема")
	assert_null(RigStyles.face_color(s, "spine", Vector3(0.5, 0.5, 0.5), -1.0, 1,
		Vector3(0.5, 0.2, 0.95)), "нижче смуги (пузо) — не сердечко")
	assert_null(RigStyles.face_color(s, "spine", Vector3(0.5, 0.5, 0.5), -1.0, 1),
		"грань не з тулуба — сердечка нема")
	# 09.09: сердечко зробили більшим — краї грудей і глибина 0,8 тепер теж його
	for p in [Vector3(0.25, 0.45, 0.80), Vector3(0.75, 0.75, 0.99), Vector3(0.5, 0.42, 0.78)]:
		assert_eq((RigStyles.face_color(s, "neck", Vector3(0.5, 0.5, 0.5), -1.0, 1, p) as Color)
			.to_html(false), "E9B7F2", "велике сердечко бере й %s" % p)


## Позначка сильніша за пояси гриви: пасмо гриви на грудях має бути сердечком, а не смугою.
## Саме через зворотний порядок сердечко єдинорога було невидиме (урок 09.09).
func test_mark_paint_is_independent_of_role() -> void:
	var s := RigStyles.for_def({"rig_style": "unicorn"})
	var chest := Vector3(0.5, 0.6, 0.95)
	var mk := RigStyles.mark_paint(s, chest)
	assert_eq(String(mk.get("tag", "")), "r", "сердечко видно навіть роль не питаючи")
	assert_eq((mk["color"] as Color).to_html(false), "E9B7F2")
	assert_true(RigStyles.mark_paint(s, Vector3(-1.0, -1.0, -1.0)).is_empty(),
		"грань не з тулуба — позначки нема")
	assert_true(RigStyles.mark_paint({}, chest).is_empty(), "без стилю позначок нема")
	# та сама точка через face_paint із роллю гриви дає СМУГУ — тому HeroRig і питає
	# mark_paint ПЕРШИМ, ще до face_paint
	assert_eq(String(RigStyles.face_paint(s, "mane", Vector3(0.5, 0.5, 0.5), 0.5, 1, chest)
		.get("tag", "")), "w", "у face_paint пояс гриви сильніший — обхід через mark_paint")
	# HeroRig пропускає позначки лише для «своїх» ролей — грива серед них НЕ значиться
	for role in ["horn", "head", "nose", "tail", "fl", "fr", "bl", "br"]:
		assert_true(HeroRig.MARK_SKIP_ROLES.has(role), "%s позначок не отримує" % role)
	for role in ["mane", "hips", "spine", "neck"]:
		assert_false(HeroRig.MARK_SKIP_ROLES.has(role), "%s позначку отримати може" % role)


## Дві пастельні латки: м'ятна на ЛІВОМУ боці ззаду, бірюзова на ПРАВОМУ спереду.
func test_patches() -> void:
	var s := RigStyles.for_def({"rig_style": "unicorn"})
	var left: Color = RigStyles.face_color(s, "hips", Vector3(0.5, 0.5, 0.5), -1.0, 1,
		Vector3(0.2, 0.45, 0.2))
	assert_eq(left.to_html(false), "7ED9A0", "лівий бік ззаду")
	var right: Color = RigStyles.face_color(s, "spine", Vector3(0.5, 0.5, 0.5), -1.0, 1,
		Vector3(0.8, 0.45, 0.65))
	assert_eq(right.to_html(false), "5CC8B8", "правий бік спереду")
	# передні 25 % глибини — це вже сердечко, латка туди не лізе (інакше вона його з'їдала б)
	assert_eq((RigStyles.face_color(s, "spine", Vector3(0.5, 0.5, 0.5), -1.0, 1,
		Vector3(0.7, 0.45, 0.9)) as Color).to_html(false), "E9B7F2",
		"на самих грудях сердечко сильніше за латку")
	assert_null(RigStyles.face_color(s, "hips", Vector3(0.5, 0.5, 0.5), -1.0, 1,
		Vector3(0.8, 0.45, 0.2)), "правий бік ЗЗАДУ — латки нема (дзеркала не робимо)")
	assert_null(RigStyles.face_color(s, "hips", Vector3(0.5, 0.9, 0.5), -1.0, 1,
		Vector3(0.2, 0.9, 0.2)), "спина вище смуги — чиста")


## Веселка лишається доступною будь-якому стилю: `"rainbow": true` або список ролей.
func test_rainbow_option_still_available() -> void:
	var s := {"rainbow": true}
	assert_eq((RigStyles.face_color(s, "tail", Vector3(0.5, 0.5, 0.5), 0.0, 1) as Color).to_html(false),
		"FF5E7E", "true — грива й хвіст веселкою")
	assert_eq((RigStyles.face_color(s, "mane", Vector3(0.5, 0.5, 0.5), 1.0, 1) as Color).to_html(false),
		"B18CFF")
	assert_null(RigStyles.face_color(s, "spine", Vector3(0.5, 0.5, 0.5), 0.0, 1), "тулуб не веселковий")
	assert_null(RigStyles.face_color({"rainbow": false}, "tail", Vector3(0.5, 0.5, 0.5), 0.0, 1))
	assert_eq((RigStyles.face_color({"rainbow": ["head"]}, "head", Vector3(0.5, 0.5, 0.5), 0.5, 1) as Color)
		.to_html(false), "7CE38B", "список ролей теж працює")


## Зірочки: механізм лишився (єдиноріг їх вимкнув) — детермінований і рідкий.
func test_sparkle_is_deterministic_and_rare() -> void:
	var s := {"sparkle": {"roles": ["hips", "spine", "neck"], "chance": 0.03, "color": "#FFF6B0"}}
	var hits := 0
	var first := {}
	for i in range(2000):
		var c = RigStyles.face_color(s, "spine", Vector3(0.5, 0.7, 0.5), -1.0, i)
		if c != null:
			hits += 1
			first[i] = (c as Color).to_html(false)
	assert_between(hits, 20, 140, "зірочок ≈ 3 %% від 2000 граней (%d)" % hits)
	for i in first.keys():
		assert_eq(String(first[i]), "FFF6B0", "зірочка — блідо-жовта")
		var again = RigStyles.face_color(s, "spine", Vector3(0.5, 0.7, 0.5), -1.0, int(i))
		assert_not_null(again, "той самий сід — та сама зірочка (%d)" % int(i))
	assert_null(RigStyles.face_color(s, "fl", Vector3(0.5, 0.7, 0.5), -1.0, 7), "на лапках зірочок нема")
	assert_null(RigStyles.face_color(RigStyles.for_def({"rig_style": "unicorn"}), "spine",
		Vector3(0.5, 0.7, 0.5), -1.0, 3), "у єдинорога зірочок нема взагалі")


## Мітки зон для прев'ю: h ріг · w пояси · p копитця · r сердечко · g латка · s зірочка.
func test_face_paint_tags() -> void:
	var s := RigStyles.for_def({"rig_style": "unicorn"})
	assert_eq(String(RigStyles.face_paint(s, "horn", Vector3(0.5, 0.5, 0.5), -1.0, 1).get("tag", "")), "h")
	assert_eq(String(RigStyles.face_paint(s, "mane", Vector3(0.5, 0.5, 0.5), 0.5, 1).get("tag", "")), "w")
	assert_eq(String(RigStyles.face_paint(s, "tail", Vector3(0.5, 0.5, 0.5), 0.5, 1).get("tag", "")), "w")
	assert_eq(String(RigStyles.face_paint(s, "fl", Vector3(0.5, 0.1, 0.5), -1.0, 1,
		Vector3(-1.0, -1.0, -1.0), "k").get("tag", "")), "p")
	assert_eq(String(RigStyles.face_paint(s, "spine", Vector3(0.5, 0.5, 0.5), -1.0, 1,
		Vector3(0.5, 0.6, 0.95)).get("tag", "")), "r")
	assert_eq(String(RigStyles.face_paint(s, "hips", Vector3(0.5, 0.5, 0.5), -1.0, 1,
		Vector3(0.2, 0.45, 0.2)).get("tag", "")), "g")
	assert_true(RigStyles.face_paint(s, "spine", Vector3(0.5, 0.7, 0.5), -1.0, 1).is_empty(),
		"звичайна грань тулуба — {} (працює зона)")


## Нові малярські ролі мають зону і БЕЗ стилю — інакше грива й ріг були б основного кольору.
func test_zone_mane_and_horn_default() -> void:
	var z := HeroRig.DEFAULT_ZONES
	assert_eq(HeroRig.zone_for("mane", Vector3(0.5, 0.5, 0.5), z), "t", "без стилю грива акцентна")
	assert_eq(HeroRig.zone_for("horn", Vector3(0.5, 0.5, 0.5), z), "t")
	assert_true(HeroRig.ROLES.has("mane") and HeroRig.ROLES.has("horn"), "ролі є у списку")


## Коробка голови: голова + писок, БЕЗ рога, гриви й чубчика — інакше очі єдинорога
## сідали на вершечок рога, а обличчя стискалось під висоту рога.
func test_head_box_excludes_horn_and_mane() -> void:
	var head := AABB(Vector3(-0.1, 0.8, -0.1), Vector3(0.2, 0.25, 0.3))
	var box := HeroRig.head_box_of({
		"head": head,
		"horn": AABB(Vector3(-0.03, 1.0, 0.0), Vector3(0.06, 0.5, 0.06)),   # ріг угору на пів метра
		"mane": AABB(Vector3(-0.08, 0.4, -0.3), Vector3(0.16, 0.7, 0.2)),
		"tuft": AABB(Vector3(-0.1, 1.0, -0.1), Vector3(0.2, 0.2, 0.2)),
	})
	assert_almost_eq(box.size.y, head.size.y, 0.0001, "висота голови — без рога й гриви")
	assert_almost_eq(box.position.y, head.position.y, 0.0001)
	# писок входить: це та сама морда, і по ній рахується посадка обличчя
	var nose := AABB(Vector3(-0.05, 0.8, 0.2), Vector3(0.1, 0.1, 0.12))
	var with_nose := HeroRig.head_box_of({"head": head, "nose": nose})
	assert_almost_eq(with_nose.end.z, nose.end.z, 0.0001, "коробка тягнеться до кінчика писка")
	# ролей нема — коробка-заглушка, а не нульова (обличчя не має схлопнутись)
	assert_gt(HeroRig.head_box_of({}).size.y, 0.0, "без ролей лишається заглушка")
	for role in HeroRig.HEAD_BOX_SKIP:
		assert_false(HeroRig.HEAD_BOX_ROLES.has(role), "%s у коробку голови не входить" % role)


## Числа поз, які тримають героя НА ПІДЛОЗІ: стійка дибки й підскоки танцю.
func test_wave_and_dance_keep_feet_on_floor() -> void:
	# привітання: нахил крутиться НАВКОЛО ТАЗУ (у ригу — оберт самої кістки hips), тож
	# окремого підйому тіла (колишній WAVE_RISE) більше нема — таз просто сідає нижче,
	# а залишок добирає «копитця на підлозі»
	assert_lt(HeroRig.WAVE_BODY_Y, 0.0, "таз сідає на задні лапки")
	assert_gt(absf(HeroRig.WAVE_BODY_Y), 0.05, "присідання помітне — це дибка, а не поклон")
	assert_almost_eq(HeroRig.WAVE_BODY_Y, Hero3D.WAVE_BODY_Y, 0.0001, "риг і вокселі — ті самі числа")
	assert_lt(absf(HeroRig.WAVE_BODY_Y), Hero3D.GROUND_LIFT_MAX + 0.05,
		"залишок провалу має бути в межах підйому «копитця на підлозі»")
	# танець: нижчий підскок + доворот задніх лапок
	assert_almost_eq(HeroRig.DANCE_HOP, 0.04, 0.0001, "підскок 4 см")
	assert_almost_eq(HeroRig.DANCE_HOP, Hero3D.DANCE_HOP, 0.0001)
	assert_gt(HeroRig.DANCE_HIND_EXT, 0.0, "задні лапки витягуються в підйомі підскоку")
	assert_almost_eq(HeroRig.DANCE_HIND_EXT, Hero3D.DANCE_HIND_EXT, 0.0001)
	# хвіст живий у КОЖНОМУ стані
	assert_almost_eq(HeroRig.TAIL_IDLE, 0.12, 0.0001)
	assert_almost_eq(HeroRig.TAIL_IDLE_HZ, 1.2, 0.0001)
	assert_almost_eq(HeroRig.TAIL_IDLE, Hero3D.TAIL_IDLE, 0.0001, "риг і вокселі виляють однаково")
	assert_almost_eq(HeroRig.TAIL_IDLE_HZ, Hero3D.TAIL_IDLE_HZ, 0.0001)


func test_zone_belly_and_unknown() -> void:
	var z := HeroRig.DEFAULT_ZONES
	assert_eq(HeroRig.zone_for("spine", Vector3(0.5, 0.1, 0.5), z), "d", "животик світліший")
	assert_eq(HeroRig.zone_for("hips", Vector3(0.5, 0.9, 0.5), z), "o", "спина основна")
	assert_eq(HeroRig.zone_for("", Vector3(0.5, 0.5, 0.5), z), "o", "кістка без ролі — основний колір")


## Правила зон беруться з даних: ширша морда — і межа їде.
func test_zones_of_override() -> void:
	var d := HeroRig.zones_of({"rig_zones": {"muzzle_depth": 0.8, "nonsense": 5}})
	assert_almost_eq(float(d["muzzle_depth"]), 0.8, 0.0001)
	assert_almost_eq(float(d["hoof"]), float(HeroRig.DEFAULT_ZONES["hoof"]), 0.0001, "решта — дефолти")
	assert_false(d.has("nonsense"), "чужі ключі в правила не потрапляють")
	assert_eq(HeroRig.zone_for("head", Vector3(0.5, 0.3, 0.3), d), "c", "з ширшою мордою крем сягає далі")
	var tuned := HeroRig.zones_of({"rig_zones": {"bag_x": 1.3, "nose_tip": 0.5}})
	assert_almost_eq(float(tuned["bag_x"]), 1.3, 0.0001, "поріг торбинки підганяється з даних")
	assert_eq(HeroRig.zone_for("nose", Vector3(0.5, 0.7, 0.6), tuned), "k", "довший темний кінчик носа")
	var plain := HeroRig.zones_of({})
	assert_eq(plain.size(), HeroRig.DEFAULT_ZONES.size(), "без rig_zones — рівно дефолти")
	for k in HeroRig.DEFAULT_ZONES.keys():
		assert_almost_eq(float(plain[k]), float(HeroRig.DEFAULT_ZONES[k]), 0.0001, "дефолт %s" % k)


## Посадка обличчя: дефолти, ручне `rig_face`, чужі ключі не проходять.
func test_face_of_override() -> void:
	var f := HeroRig.face_of({"rig_face": {"scale": 0.8, "y": 0.7, "nonsense": 5}})
	assert_almost_eq(float(f["scale"]), 0.8, 0.0001)
	assert_almost_eq(float(f["y"]), 0.7, 0.0001)
	assert_almost_eq(float(f["z"]), float(HeroRig.DEFAULT_FACE["z"]), 0.0001, "решта — дефолти")
	assert_false(f.has("nonsense"), "чужі ключі в посадку не потрапляють")
	var plain := HeroRig.face_of({})
	assert_eq(plain.size(), HeroRig.DEFAULT_FACE.size(), "без rig_face — рівно дефолти")
	assert_almost_eq(float(plain["y"]), 0.65, 0.0001, "очі трохи вище середини голови")
	assert_almost_eq(float(plain["scale"]), 0.85, 0.0001, "воксельні очі на гладкій морді трохи меншають")
	assert_eq(String(plain["layout"]), "front", "за замовчуванням очі на морді")


## Підгонка анімації під модель (`rig_anim`): множники поверх профілю, дефолт 1.0.
func test_anim_of_override() -> void:
	var a := HeroRig.anim_of({"rig_anim": {"leg_amp": 0.75, "leg_lift": 0.35, "nonsense": 5}})
	assert_almost_eq(float(a["leg_amp"]), 0.75, 0.0001)
	assert_almost_eq(float(a["leg_lift"]), 0.35, 0.0001)
	assert_false(a.has("nonsense"), "чужі ключі в підгонку не потрапляють")
	var plain := HeroRig.anim_of({})
	assert_eq(plain.size(), HeroRig.DEFAULT_ANIM.size(), "без rig_anim — рівно дефолти")
	for k in HeroRig.DEFAULT_ANIM.keys():
		assert_almost_eq(float(plain[k]), 1.0, 0.0001, "дефолт %s — «як у профілі»" % k)
	# від'ємний множник вивернув би позу — беремо нуль
	assert_almost_eq(float(HeroRig.anim_of({"rig_anim": {"leg_amp": -2.0}})["leg_amp"]), 0.0, 0.0001)


## Розкладка обличчя: `layout` — рядок, а не число (кінь дивиться БОКАМИ голови).
func test_face_layout_side() -> void:
	assert_eq(String(HeroRig.face_of({"rig_face": {"layout": "side"}})["layout"]), "side")
	assert_eq(String(HeroRig.face_of({"rig_face": {"scale": 0.8}})["layout"]), "front",
		"інші ключі layout не чіпають")
	# числові ключі лишились числами навіть поруч із рядковим
	var mixed := HeroRig.face_of({"rig_face": {"layout": "side", "y": 0.62}})
	assert_almost_eq(float(mixed["y"]), 0.62, 0.0001)
	assert_between(HeroRig.SIDE_EYE_DEPTH, 0.0, 1.0, "глибина бічного ока — частка довжини голови")
	# око сидить трохи ВСЕРЕДИНІ поверхні черепа (назовні стирчить лише перед меша),
	# а не виноситься назовні, як раніше — тоді воно «плавало» збоку від голови
	assert_gt(HeroRig.SIDE_EYE_OUT, 0.0, "око втоплене під бік голови")
	assert_lt(HeroRig.SIDE_EYE_OUT, 0.02, "але лише трохи — інакше зіниця сховається в черепі")
	assert_gt(HeroRig.SIDE_EYE_IN, 0.0, "плюс уся група ока підтягнута до центру голови")
	assert_lt(HeroRig.SIDE_EYE_IN, 0.03)
	# ширина береться з КОРОБКИ САМОГО ЧЕРЕПА, без писка/гриви/рога
	assert_eq(HeroRig.HEAD_SIDE_ROLE, "head")
	assert_false(HeroRig.HEAD_BOX_SKIP.has(HeroRig.HEAD_SIDE_ROLE))


## Знак повороту з руху точки-проби — серце калібрування (див. HeroRig._calibrate_signs).
func test_sign_from_probe() -> void:
	var fwd := Vector3(0.0, 0.0, -1.0)      # перед героя
	# проба поїхала вперед — знак додатний
	assert_eq(HeroRig.sign_from_probe(Vector3.ZERO, Vector3(0.0, 0.0, -0.1), fwd), 1.0)
	# поїхала назад — знак від'ємний (саме тут єдиноріг вітався навпаки)
	assert_eq(HeroRig.sign_from_probe(Vector3.ZERO, Vector3(0.0, 0.0, 0.1), fwd), -1.0)
	# рух ПОПЕРЕК бажаного напрямку нічого не каже — знак невідомий
	assert_eq(HeroRig.sign_from_probe(Vector3.ZERO, Vector3(0.1, 0.0, 0.0), fwd), 0.0)
	# зовсім не зрушила (кістка-листок без проби) — теж невідомий
	assert_eq(HeroRig.sign_from_probe(Vector3.ZERO, Vector3.ZERO, fwd), 0.0)
	# порожній бажаний напрямок — не ділимо на нуль
	assert_eq(HeroRig.sign_from_probe(Vector3.ZERO, Vector3(0.0, 0.0, -0.1), Vector3.ZERO), 0.0)
	# довжина `want` не важлива, важливий напрямок
	assert_eq(HeroRig.sign_from_probe(Vector3.ZERO, Vector3(0.0, 0.3, 0.0), Vector3(0.0, 7.0, 0.0)), 1.0)
	# рух менший за поріг — шум, а не оберт
	assert_eq(HeroRig.sign_from_probe(Vector3.ZERO, Vector3(0.0, 0.0, -0.00001), fwd), 0.0)
	# коса складова рахується проєкцією
	assert_eq(HeroRig.sign_from_probe(Vector3(1.0, 1.0, 1.0), Vector3(1.5, 1.0, 0.9), fwd), 1.0)
	assert_gt(HeroRig.CAL_ANGLE, 0.0, "пробний кут додатний — інакше знак вийшов би дзеркальним")
	assert_lt(HeroRig.CAL_ANGLE, 0.6, "пробний кут малий — щоб не вилізти за межі суглоба")


## Хвіст: кути діляться на ланки, але не більше ніж на TAIL_CHAIN_MAX — інакше на
## 11-кістковому хвості єдинорога виляння танцю зникало зовсім.
func test_tail_chain_divisor() -> void:
	assert_gte(HeroRig.TAIL_CHAIN_MAX, 3, "хвіст лисеняти (3 ланки) ділиться як і раніше")
	assert_lte(HeroRig.TAIL_CHAIN_MAX, 5, "довгий хвіст не має з'їдати всю амплітуду")
	assert_eq(clampi(3, 1, HeroRig.TAIL_CHAIN_MAX), 3, "лисеня: дільник = довжина ланцюжка")
	assert_eq(clampi(11, 1, HeroRig.TAIL_CHAIN_MAX), HeroRig.TAIL_CHAIN_MAX,
		"єдиноріг: дільник обмежений, виляння лишається видимим")
	# на 11 ланках старий дільник давав ±0,045 рад на кістку — це не видно взагалі
	assert_gt(Hero3D.DANCE_TAIL_WAG / float(HeroRig.TAIL_CHAIN_MAX), 0.1,
		"на ланку лишається помітний кут")


## Частки габариту рахуються від «переду» моделі, куди б вона не дивилась.
func test_local_of_respects_front() -> void:
	var box := AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
	var front_point := Vector3(0, 1, -1)
	assert_almost_eq(HeroRig.local_of(front_point, box, -1.0).z, 1.0, 0.001, "модель дивиться в −Z")
	assert_almost_eq(HeroRig.local_of(front_point, box, 1.0).z, 0.0, 0.001, "модель дивиться в +Z")
	var flat := AABB(Vector3.ZERO, Vector3.ZERO)
	var l := HeroRig.local_of(Vector3.ZERO, flat, -1.0)
	assert_almost_eq(l.y, 0.5, 0.001, "нульовий габарит не ділить на нуль")


# ---------- дані heroes.json ----------

func test_lys_has_rig_and_path_is_well_formed() -> void:
	var all := Hero3D.defs()
	var lys: Dictionary = all.get("lys", {})
	assert_false(lys.is_empty(), "герой lys є в даних")
	var rig := String(lys.get("rig", ""))
	assert_eq(rig, "fox_no_voxel", "у лисеняти заданий скелетний риг")
	var path := HeroRig.rig_path(rig)
	assert_true(path.begins_with("res://assets/models/"), "модель лежить у res:// (інакше Godot її не імпортує)")
	assert_true(path.ends_with(".glb"))
	assert_true(lys.has("parts"), "parts лишились як запасний варіант, поки .glb не доїхав")
	# малярські ролі: чубчик на маківці й кістки писка (автомапа їх не знає — тільки руками)
	var bones: Dictionary = lys.get("rig_bones", {})
	assert_true(bones.has("tuft"), "чубчик заданий окремою роллю, інакше він просто помаранчевий")
	assert_true(bones.has("nose"), "кістки писка задані окремо — кінчик носа має бути темний")
	assert_eq(String(lys.get("accent", "")), "#F6C445", "акцент лисеняти — жовтий камінець на маківці")
	assert_eq(String(lys.get("mark", "")), "#3FC1B0", "торбинка збоку — бірюзова")
	# після переходу на грані (центроїд «всередині» боку) поріг торбинки довелось опустити
	var zones := HeroRig.zones_of(lys)
	assert_almost_eq(float(zones["bag_x"]), 0.9, 0.0001, "поріг торбинки лисеняти — 0,9 півширини")
	assert_lt(float(zones["bag_x"]), float(HeroRig.DEFAULT_ZONES["bag_x"]),
		"центроїди граней ближчі до осі, ніж вершини — поріг нижчий за дефолт")


## Єдиноріг: другий ригнутий герой, зі стилем розмальовки. Моделі `unicorn.glb` у репо ще
## може не бути — тоді малюються воксельні частини, і це не помилка даних.
func test_unicorn_hero_data() -> void:
	var all := Hero3D.defs()
	var odn: Dictionary = all.get("odn", {})
	assert_false(odn.is_empty(), "герой odn є в даних")
	assert_eq(String(odn.get("name_uk", "")), "Єдиноріг")
	assert_eq(String(odn.get("rig", "")), "unicorn", "тіло — модель зі скелетом")
	assert_eq(String(odn.get("rig_style", "")), "unicorn", "і стиль розмальовки")
	assert_false(RigStyles.for_def(odn).is_empty(), "стиль знаходиться в RIG_STYLES")
	assert_eq(int(odn.get("order", -1)), 6, "сьомий у каруселі")
	assert_eq(String(odn.get("rig_front", "")), "+z", "модель єдинорога дивиться в +z (голова й ріг там)")
	assert_true(odn.has("parts"), "воксельні частини лишились запасним варіантом")
	assert_eq(String(odn.get("accent", "")), "#F6C445", "акцент — золото рога")
	# ручна розкладка кісток за дампом прев'ю (Meshy дає безіменні Bone_NNN)
	var bones: Dictionary = odn.get("rig_bones", {})
	assert_eq(String(bones.get("hips", "")), "Bone_001", "таз — центр моделі, а не гілка гриви")
	assert_eq(String(bones.get("head", "")), "Bone_030")
	assert_eq(String(bones.get("neck", "")), "Bone_004")
	assert_eq(String(bones.get("spine", "")), "Bone_005")
	assert_eq((bones.get("horn", []) as Array), ["Bone_029"], "ріг — окрема кістка, і не голова")
	assert_eq((bones.get("mane", []) as Array).size(), 4, "гичка гриви — ланцюжок із 4 кісток")
	var tail: Array = bones.get("tail", [])
	assert_eq(tail.size(), 11, "хвіст: основний ланцюжок + дві бічні пасма")
	assert_eq(String(tail[0]), "Bone_022", "ланцюжок починається за крижами (003/002 лишаються тазом)")
	assert_false(tail.has("Bone_003") or tail.has("Bone_002"), "круп — це не хвіст")
	for role in ["fl", "fr", "bl", "br"]:
		assert_true(bones.has(role), "лапка %s задана руками" % role)
	# морда в коня довга — обличчя стискаємо сильніше й саджаємо трохи нижче
	var f := HeroRig.face_of(odn)
	assert_almost_eq(float(f["scale"]), 0.8, 0.0001)
	assert_almost_eq(float(f["y"]), 0.62, 0.0001)
	assert_eq(String(f["layout"]), "side", "кінь дивиться БОКАМИ голови, а не мордою")
	assert_eq(String(HeroRig.face_of(Hero3D.defs().get("lys", {}))["layout"]), "front",
		"у лисеняти очі лишились на морді")
	# скінінг єдинорога жорсткий: на повному розмаху меш передньої лапки «відривався»
	# від грудей, а задньої розтягувався — тому розмах і згин коліна приборкані
	var an := HeroRig.anim_of(odn)
	assert_almost_eq(float(an["leg_amp"]), 0.7, 0.0001, "розмах лапок єдинорога ×0,7")
	assert_lt(float(an["leg_lift"]), 1.0, "і згин нижньої ланки менший")
	assert_almost_eq(float(HeroRig.anim_of(Hero3D.defs().get("lys", {}))["leg_amp"]), 1.0, 0.0001,
		"у лисеняти анімація без обмежень")
	var path := HeroRig.rig_path("unicorn")
	assert_eq(path, "res://assets/models/unicorn.glb")
	if FileAccess.file_exists(path):
		assert_true(load(path) is PackedScene, "імпортований .glb — це PackedScene")


## Файлу може ще не бути — це не помилка даних, а крок для Nick (docs/tasks/rig.md).
## Коли файл на місці, перевіряємо, що він і справді читається як сцена.
func test_rig_file_optional() -> void:
	var path := HeroRig.rig_path("fox_no_voxel")
	if not FileAccess.file_exists(path):
		assert_true(true, "моделі ще нема — Hero3D малює воксельні частини, тест пропущено")
		return
	assert_true(HeroRig.rig_exists("fox_no_voxel"), "файл є — має бути й імпортований ресурс")
	var res = load(path)
	assert_true(res is PackedScene, "імпортований .glb — це PackedScene")


func test_rig_exists_is_safe_for_garbage() -> void:
	assert_false(HeroRig.rig_exists(""), "порожнє ім'я — рига нема")
	assert_false(HeroRig.rig_exists("немає_такої_моделі"))


## Герой без поля "rig" лишається воксельним — тіло Hero3D не змінилось.
func test_other_heroes_stay_voxel() -> void:
	var all := Hero3D.defs()
	for id in ["olen", "pes", "zai", "kit", "med"]:
		var def: Dictionary = all.get(id, {})
		assert_false(def.is_empty(), "%s є в даних" % id)
		assert_eq(String(def.get("rig", "")), "", "%s: без рига, малюється вокселями" % id)
