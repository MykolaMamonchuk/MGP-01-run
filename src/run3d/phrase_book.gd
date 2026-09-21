## БІБЛІОТЕКА ФРАЗ і збирач послідовності: з чого складається 150 метрів дороги.
##
## Фраза — шматок дороги, де перешкоди й золото задані РАЗОМ (data/phrases.json, LDD §5).
## Тут вона перетворюється на ПОСЛІДОВНІСТЬ: які фрази, в якому порядку й на яких метрах
## стоять у цеглинці, щоб укластися в бюджет складності та бюджет золота.
##
## Чому окремим класом, а не всередині інструмента розстановки. По-перше, це єдине місце,
## де живуть правила темпу, і їх треба перевіряти тестами, а не оком на згенерованій сцені.
## По-друге, той самий збирач знадобиться грі, якщо колись захочемо збирати цеглинку на
## льоту, а не заморожувати її в .tscn.
##
## Усе — чисті функції над словниками: ні вузлів, ні сцен, ні стану.
class_name PhraseBook
extends RefCounted

const PATH := "res://data/phrases.json"

const MARKER_SCRIPT := "res://src/run3d/level_marker_3d.gd"
const LAYOUT_SCRIPT := "res://src/run3d/level_layout.gd"
## Теки за роллю — ті самі, що робить tools/group_chunk_markers.py; сторож
## tests/test_level_chunk_groups.gd вимагає теку за РОЛЛЮ, а не за походженням.
const FOLDERS := {"obstacle": "Перешкоди", "gold": "Золото"}



## Скільки метрів дороги займає «вдих» тривалістю секунда. Рахується зі швидкості рівня, бо
## пауза для дитини вимірюється в СЕКУНДАХ («дай дві секунди спокійного бігу»), а дорога — в
## метрах, і на 17-му рівні та сама секунда — це вдвічі більше метрів, ніж на першому.
const MIN_TAIL_M := 2.0

## Скільки разів одну фразу можна взяти в одну цеглинку. Правило замовника; без нього
## збирач на бідному рівні просто повторює найдешевшу фразу до вичерпання бюджету.
const MAX_REPEATS := 2

## Перша й остання смуга цеглинки, де важкі фрази заборонені. Цеглинки переставляються між
## рівнями, тож стик двох цеглинок не має збігатися з піком складності: інакше важкий кінець
## однієї зійдеться з важким початком іншої й дасть зв'язку, якої ніхто не проєктував.
const CALM_EDGE_M := 20.0
## Що вважати важким на краю цеглинки.
const CALM_EDGE_POINTS := 1


static func load_all() -> Array:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("PhraseBook: нема %s" % PATH)
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("PhraseBook: %s не читається як словник" % PATH)
		return []
	return (parsed as Dictionary).get("phrases", [])


## Фрази, придатні для цього рівня: механіка вже введена (min_level) і реалізована (без needs).
static func available(phrases: Array, level: int) -> Array:
	return phrases.filter(func(p):
		var d: Dictionary = p
		return not d.has("needs") and int(d.get("min_level", 1)) <= level)


## Скільки номіналу золота несе фраза.
static func gold_of(phrase: Dictionary) -> int:
	var n := 0
	for g in phrase.get("gold", []):
		n += int((g as Dictionary).get("n", 0)) * int((g as Dictionary).get("value", 1))
	return n


## Скільки метрів займає фраза РАЗОМ із обов'язковим вдихом після неї.
static func span_of(phrase: Dictionary, speed_mps: float) -> float:
	return float(phrase.get("length_m", 10.0)) \
		+ float(phrase.get("recovery_sec", 0.0)) * maxf(0.5, speed_mps) + MIN_TAIL_M


## СКЛАСТИ ЦЕГЛИНКУ. Повертає [{phrase, at_m}] у порядку проходження.
##
## points_budget — скільки НЕМИНУЧИХ дій дозволено на цю цеглинку. Золото тут не вибирає
## нічого: дорога складається за ТЕМПОМ, а бюджет золота потім витримується номіналом
## (place). Інакше збирач набивав би цеглинку багатими фразами, псуючи ритм заради цифри.
##
## Збирач жадібний, і це свідомо: він іде зліва направо й на кожному кроці бере найкращу
## фразу з тих, що зараз дозволені. Шукати оптимум нема сенсу — «найкраща цеглинка» це не
## максимум чисел, а дотримані правила темпу.
static func compose(phrases: Array, level: int, length_m: float, speed_mps: float,
		points_budget: int, rng: RandomNumberGenerator) -> Array:
	var pool := available(phrases, level)
	if pool.is_empty():
		return []
	var budget := maxi(0, points_budget)
	var out: Array = []
	var used := {}
	var at := 0.0
	var points := 0
	var last_id := ""
	var last_points := 0
	var jackpots := 0
	var guard := 0
	while at < length_m and guard < 200:
		guard += 1
		var pick := _best_next(pool, level, at, length_m, speed_mps, used, last_id,
			last_points, budget - points, jackpots, rng)
		if pick.is_empty():
			break
		out.append({"phrase": pick, "at_m": snappedf(at, 0.1)})
		used[String(pick["id"])] = int(used.get(String(pick["id"]), 0)) + 1
		at += span_of(pick, speed_mps)
		points += int(pick.get("obstacle_points", 0))
		last_id = String(pick["id"])
		last_points = int(pick.get("obstacle_points", 0))
		if _has_jackpot(pick):
			jackpots += 1
	return out


## Найкраща фраза на цю позицію — або порожньо, якщо жодна не підходить.
static func _best_next(pool: Array, level: int, at: float, length_m: float, speed_mps: float,
		used: Dictionary, last_id: String, last_points: int, points_left: int,
		jackpots: int, rng: RandomNumberGenerator) -> Dictionary:
	var fits: Array = []
	for p in pool:
		var d: Dictionary = p
		var pts := int(d.get("obstacle_points", 0))
		if at + span_of(d, speed_mps) > length_m:
			continue                                   # не влазить у цеглинку
		if String(d["id"]) == last_id:
			continue                                   # дві однакові поспіль — ніколи
		if int(used.get(String(d["id"]), 0)) >= MAX_REPEATS:
			continue
		if pts > points_left:
			continue
		# Вдих після важкої фрази: на 2+ очки наступна мусить бути на нуль.
		if last_points >= 2 and pts > 0:
			continue
		# Спокійні краї цеглинки.
		# Край не більший за шосту частину цеглинки: інакше на короткій (≤ 40 м) КОЖНА
		# позиція виявляється краєм, і нічого важчого за одне очко не поставиться ніколи.
		var edge := minf(CALM_EDGE_M, length_m / 6.0)
		var near_edge := at < edge or at + span_of(d, speed_mps) > length_m - edge
		if near_edge and pts > CALM_EDGE_POINTS:
			continue
		if _has_jackpot(d) and jackpots >= 1:
			continue                                   # один джекпот на цеглинку
		fits.append(d)
	if fits.is_empty():
		return {}
	# З того, що дозволено, беремо найкорисніше: спершу закриваємо борг за очками, далі за
	# золотом. Інакше жадібний збирач набирає самі вдихи — вони дозволені завжди.
	var need_points := points_left > 0
	var want: Array = fits.filter(func(d):
		return (int((d as Dictionary).get("obstacle_points", 0)) > 0) == need_points)
	if want.is_empty():
		want = fits
	# Коли боргу за очками багато, беремо ВАЖЧЕ. Інакше жадібний збирач набирає найдешевші
	# дозволені фрази — на рівні 10 бюджет 12 очок витрачався на п'ять, тобто «важкий»
	# рівень відрізнявся від легкого лише швидкістю. Не «завжди найважча»: тоді цеглинка
	# стає одноманітною. Беремо половину верхнього діапазону й кидаємо жереб усередині.
	if need_points:
		var top := 0
		for d in want:
			top = maxi(top, int((d as Dictionary).get("obstacle_points", 0)))
		var floor_pts := maxi(1, (top + 1) / 2)
		var heavy: Array = want.filter(func(d):
			return int((d as Dictionary).get("obstacle_points", 0)) >= floor_pts)
		if not heavy.is_empty():
			want = heavy
	want.sort_custom(func(a, b): return String(a["id"]) < String(b["id"]))
	return want[rng.randi() % want.size()]


static func _has_jackpot(phrase: Dictionary) -> bool:
	for g in phrase.get("gold", []):
		if String((g as Dictionary).get("why", "")) == "jackpot":
			return true
	return false


## Підсумок складеної цеглинки: скільки очок і золота вийшло насправді.
static func summary(sequence: Array) -> Dictionary:
	var points := 0
	var gold := 0
	for item in sequence:
		var p: Dictionary = (item as Dictionary)["phrase"]
		points += int(p.get("obstacle_points", 0))
		gold += gold_of(p)
	return {"фраз": sequence.size(), "очок": points, "золота": gold}


## РОЗСТАВИТИ складену цеглинку в конкретні маркери — і саме тут витримується бюджет золота.
##
## Повертає {"obstacles": [...], "gold": [...]} у локальних метрах цеглинки. Записи мають
## той самий вигляд, що й розбір авторської сцени (LevelTimeline), тож їх можна або писати
## маркерами в .tscn, або віддавати спавнеру напряму.
##
## Чому номінал рахується ТУТ, а не лежить у фразі. Дві вимоги мусять виконатись одночасно:
## модель EDD чекає близько 73 номіналу з цеглинки, а замовник просив 20–32 ВИДИМІ монети —
## «монета має щось важити». Прибити номінал у фразі означає задовольнити одну з них і
## промахнутись по другій, причому промах росте з рівнем: на швидкій цеглинці фраз уміщається
## менше, тож і монет менше. Тому у фразі лежить ВАГА (1 звичайна, 2 за ризик, 3 джекпот), а
## множник підбирається на цеглинку — дитина бачить ту саму дорогу, а економіка сходиться.
static func place(sequence: Array, gold_budget: int) -> Dictionary:
	var obstacles: Array = []
	var figures: Array = []
	var weight_total := 0
	for item in sequence:
		var at := float((item as Dictionary)["at_m"])
		var p: Dictionary = (item as Dictionary)["phrase"]
		for o in p.get("obstacles", []):
			var od: Dictionary = o
			obstacles.append({
				"z_m": at + float(od.get("z", 0.0)),
				"lane": int(od.get("lane", 0)),
				"action": String(od.get("action", "any")),
				"motion": String(od.get("motion", "")),
			})
		for g in p.get("gold", []):
			var gd: Dictionary = g
			# Параметри фігури йдуть в `override` — саме звідти їх читає
			# Spawner3D._spawn_gold_figure(). Плоскими полями вони мовчки ігнорувались би,
			# і фігура ставала б типовою лінією з п'яти монет номіналом один: n, value,
			# to_lane, w, h — усе повз. Форма-еталон — LevelTimeline._append().
			var over := {}
			for key in ["n", "value", "to_lane", "w", "h"]:
				if gd.has(key):
					over[key] = gd[key]
			figures.append({
				"z_m": at + float(gd.get("z", 0.0)),
				"lane": int(gd.get("lane", 0)),
				"kind": String(gd.get("kind", "line")),
				"y_m": 0.0,
				"why": String(gd.get("why", "")),
				"override": over,
			})
			weight_total += int(gd.get("n", 0)) * int(gd.get("value", 1))
	# Множник на цеглинку. Дробовий, бо один цілий дає драбину ×1/×2 і промах до третини.
	# І БЕЗ нижньої межі в одиницю: цеглинка, чиї фрази важать більше за бюджет, трапляється
	# насправді (заміряно: сира вага гуляє 28–100 при медіані 49), і тоді золото треба
	# ЗМЕНШИТИ, а не лишити як є. Нижче за монету номіналом 1 не опустимось усе одно.
	var mult := 1.0
	if weight_total > 0 and gold_budget > 0:
		mult = float(gold_budget) / float(weight_total)
	# Залишок несемо в НОМІНАЛІ, а не в одиницях value. Різниця не косметична: номінал
	# фігури це n × value, тож похибка в половину одиниці value множиться на n і на джекпоті
	# з дванадцяти монет дає промах у шість. Найбільше страждала саме та фігура, чий сенс —
	# бути помітно великою.
	var carry := 0.0
	for fig in figures:
		var d: Dictionary = fig
		var over: Dictionary = d["override"]
		var n := maxi(1, int(over.get("n", 1)))
		var want := float(n) * float(int(over.get("value", 1))) * mult + carry
		var value := maxi(1, roundi(want / float(n)))
		carry = want - float(n * value)
		over["value"] = value
	return {"obstacles": obstacles, "gold": figures, "множник": snappedf(mult, 0.01)}


## Скільки номіналу дала розстановка насправді.
static func gold_placed(placed: Dictionary) -> int:
	var total := 0
	for g in placed.get("gold", []):
		var over: Dictionary = (g as Dictionary).get("override", {})
		total += int(over.get("n", 0)) * int(over.get("value", 1))
	return total


## СКЛАДЕНА ЦЕГЛИНКА → ТЕКСТ СЦЕНИ. Пишемо ТЕКСТОМ, а не через PackedScene: так само робить
## tools/freeze_chunk.py, і так файл лишається читабельним у git diff — згенероване
## оздоблення й розкладку переглядають саме в diff, а не в редакторі.
##
## Функція живе ТУТ, а не в інструменті, навмисно: вона — стик між збирачем і грою, а саме
## на стиках усе й ламалось (див. docs/MEMORY.md «Тести на стик, а не на боки»). Тут її
## перевіряє tests/test_phrase_book.gd, проганяючи текст назад через LevelTimeline.
static func to_scene_text(placed: Dictionary) -> String:
	var out := PackedStringArray()
	out.append("[gd_scene load_steps=3 format=3]\n")
	out.append("[ext_resource type=\"Script\" path=\"%s\" id=\"1\"]" % MARKER_SCRIPT)
	out.append("[ext_resource type=\"Script\" path=\"%s\" id=\"2\"]\n" % LAYOUT_SCRIPT)
	out.append("[node name=\"LevelLayout\" type=\"Node3D\"]")
	out.append("script = ExtResource(\"2\")\n")
	var n := 0
	for role in ["obstacle", "gold"]:
		var items: Array = placed["obstacles"] if role == "obstacle" else placed["gold"]
		if items.is_empty():
			continue
		out.append("[node name=\"%s\" type=\"Node3D\" parent=\".\"]\n" % FOLDERS[role])
		for rec in items:
			n += 1
			out.append_array(_marker(n, role, rec as Dictionary))
	return "\n".join(out)


static func _marker(n: int, role: String, rec: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var tail := String(rec.get("action", "")) if role == "obstacle" else String(rec.get("kind", ""))
	out.append("[node name=\"M%d_%s_%s\" type=\"Node3D\" parent=\"%s\"]" % [n, role, tail, FOLDERS[role]])
	out.append("script = ExtResource(\"1\")")
	out.append("role = \"%s\"" % role)
	if role == "obstacle":
		out.append("action = \"%s\"" % String(rec.get("action", "any")))
		if String(rec.get("motion", "")) != "":
			out.append("motion = \"%s\"" % String(rec["motion"]))
	else:
		out.append("kind = \"%s\"" % String(rec.get("kind", "line")))
		out.append("override = %s" % _dict_literal(rec.get("override", {})))
	out.append("lane = %d" % int(rec.get("lane", 0)))
	# z у сцені від'ємний: маркер лежить на -z, а LevelTimeline читає z_m = -position.z.
	out.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, %s)\n"
		% _num(-float(rec.get("z_m", 0.0))))
	return out


## Словник у синтаксисі .tscn. JSON.stringify не годиться: там подвійні лапки навколо
## ключів, а Godot чекає рядкові літерали — прочитається, але diff виглядатиме чужим.
static func _dict_literal(d: Dictionary) -> String:
	var parts := PackedStringArray()
	var keys := d.keys()
	keys.sort()
	for k in keys:
		var v: Variant = d[k]
		var text := "\"%s\"" % String(v) if typeof(v) == TYPE_STRING else _num(float(v))
		parts.append("\"%s\": %s" % [String(k), text])
	return "{%s}" % ", ".join(parts)


## Ціле пишемо цілим: «5.0» у lane чи n читається як float і засмічує diff.
static func _num(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, float(roundi(v))) else str(snappedf(v, 0.01))
