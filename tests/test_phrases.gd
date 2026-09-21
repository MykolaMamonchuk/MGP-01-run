## БІБЛІОТЕКА ФРАЗ: цілісність даних, із яких будується дорога.
##
## Фраза — шматок дороги, де перешкоди й золото задані РАЗОМ (data/phrases.json, LDD §5).
## Помилка тут не падає й ніде не світиться: фраза з чужою дією просто не поставить
## перешкоди (Spawner3D._kind_for_action тихо повертає ""), фраза з доріжкою поза межами
## обріжеться в край, а забутий recovery_sec перетворить рівень на суцільну смугу перешкод.
## Усе це помітно лише оком і лише на плейтесті, тож стережемо числами.
extends GutTest

const PATH := "res://data/phrases.json"
## Дії, які вміє добирати світ (Spawner3D._kind_for_action) — інших у даних бути не може.
const ACTIONS := ["jump", "duck", "side", "any"]
## Фігури золота, які вміє малювати Spawner3D._spawn_gold_figure.
const FIGURES := ["line", "climb", "arc", "cluster"]
## Ролі золота в економіці (EDD): ведення, плата за ризик, святкування, джекпот.
const WHY := ["guide", "reward", "celebration", "jackpot"]
## Фрази написані на три доріжки; ширші дороги їх розтягують, тож у даних лише -1..1.
const LANE_MAX := 1


var _phrases: Array = []


func before_all() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	assert_not_null(f, "data/phrases.json на місці")
	var parsed = JSON.parse_string(f.get_as_text())
	_phrases = (parsed as Dictionary).get("phrases", []) if typeof(parsed) == TYPE_DICTIONARY else []


func _ready_phrases() -> Array:
	# `needs` — механіка, якої в грі ще нема; така фраза лежить як задум і в дорогу не йде.
	return _phrases.filter(func(p): return not (p as Dictionary).has("needs"))


func test_biblioteka_ne_porozhnia() -> void:
	assert_gt(_phrases.size(), 0, "фрази прочитались — інакше сторож стереже порожнечу")
	assert_gt(_ready_phrases().size(), 5, "придатних до вжитку фраз достатньо, щоб скласти цеглинку")


func test_identyfikatory_unikalni() -> void:
	var seen := {}
	var dupes := []
	for p in _phrases:
		var id := String((p as Dictionary).get("id", ""))
		if id == "" or seen.has(id):
			dupes.append(id)
		seen[id] = true
	assert_eq(dupes, [], "id фраз унікальні й непорожні: %s" % [dupes])


func test_obovyazkovi_polia_na_mistsi() -> void:
	var bad := []
	for p in _phrases:
		var d: Dictionary = p
		for key in ["id", "tier", "min_level", "lanes", "length_m", "recovery_sec",
				"obstacle_points", "teaches", "obstacles", "gold"]:
			if not d.has(key):
				bad.append("%s: нема %s" % [d.get("id", "?"), key])
	assert_eq(bad, [], "у фраз є всі поля: %s" % [bad])


## Дія, якої світ не вміє, — найтихіша з можливих помилок: перешкода просто не з'явиться.
func test_diyi_perechkod_tilky_vidomi() -> void:
	var bad := []
	for p in _ready_phrases():
		for o in (p as Dictionary).get("obstacles", []):
			var a := String((o as Dictionary).get("action", ""))
			if not ACTIONS.has(a):
				bad.append("%s: дія «%s»" % [(p as Dictionary)["id"], a])
	assert_eq(bad, [], "усі дії відомі: %s" % [bad])


func test_figury_zolota_tilky_vidomi() -> void:
	var bad := []
	for p in _ready_phrases():
		for g in (p as Dictionary).get("gold", []):
			var d: Dictionary = g
			if not FIGURES.has(String(d.get("kind", ""))):
				bad.append("%s: фігура «%s»" % [(p as Dictionary)["id"], d.get("kind", "")])
			if not WHY.has(String(d.get("why", ""))):
				bad.append("%s: роль «%s»" % [(p as Dictionary)["id"], d.get("why", "")])
			if int(d.get("n", 0)) <= 0:
				bad.append("%s: n = %s" % [(p as Dictionary)["id"], d.get("n")])
	assert_eq(bad, [], "фігури й ролі золота відомі: %s" % [bad])


func test_dorizhky_v_mezhakh_troh() -> void:
	var bad := []
	for p in _ready_phrases():
		var d: Dictionary = p
		for o in d.get("obstacles", []):
			if absi(int((o as Dictionary).get("lane", 0))) > LANE_MAX:
				bad.append("%s: перешкода в доріжці %s" % [d["id"], (o as Dictionary).get("lane")])
		for g in d.get("gold", []):
			var gd: Dictionary = g
			if absi(int(gd.get("lane", 0))) > LANE_MAX:
				bad.append("%s: золото в доріжці %s" % [d["id"], gd.get("lane")])
			if gd.has("to_lane") and absi(int(gd["to_lane"])) > LANE_MAX:
				bad.append("%s: climb у доріжку %s" % [d["id"], gd["to_lane"]])
	assert_eq(bad, [], "усе в межах трьох доріжок: %s" % [bad])


## Ніщо не має стирчати за межі фрази: інакше сусідні фрази накладуться, і «вдих» після
## важкого шматка з'їсть перешкода з попереднього.
func test_nichoho_ne_styrchyt_za_dovzhynu() -> void:
	var bad := []
	for p in _ready_phrases():
		var d: Dictionary = p
		var len_m := float(d["length_m"])
		for o in d.get("obstacles", []):
			if float((o as Dictionary).get("z", 0.0)) > len_m:
				bad.append("%s: перешкода на z=%s при довжині %s" % [d["id"], (o as Dictionary).get("z"), len_m])
		for g in d.get("gold", []):
			if float((g as Dictionary).get("z", 0.0)) > len_m:
				bad.append("%s: золото на z=%s при довжині %s" % [d["id"], (g as Dictionary).get("z"), len_m])
	assert_eq(bad, [], "усе вміщається у length_m: %s" % [bad])


## Після важкої фрази мусить іти спокій. Нуль дозволено лише тим, у кого нема перешкод.
func test_vazhka_fraza_maie_vdykh() -> void:
	var bad := []
	for p in _ready_phrases():
		var d: Dictionary = p
		if int(d["obstacle_points"]) > 0 and float(d["recovery_sec"]) <= 0.0:
			bad.append(String(d["id"]))
	assert_eq(bad, [], "у кожної фрази з перешкодами є вдих: %s" % [bad])


## Золото мусить ВЕСТИ. Якщо фраза перекриває доріжку, у тій самій доріжці не має лежати
## монет-«приманок» на тому самому метрі — інакше монети запрошують дитину під перешкоду.
func test_zoloto_ne_zaproshuie_pid_pereshkodu() -> void:
	var bad := []
	for p in _ready_phrases():
		var d: Dictionary = p
		for g in d.get("gold", []):
			var gd: Dictionary = g
			if String(gd.get("why", "")) == "reward":
				continue      # плата за ризик — навмисно в небезпечній доріжці, але ПІСЛЯ неї
			if String(gd.get("kind", "")) == "arc":
				continue      # дуга лежить НАД перешкодою — її для того й перестрибують
			for o in d.get("obstacles", []):
				var od: Dictionary = o
				if int(od.get("lane", 0)) != int(gd.get("lane", 0)):
					continue
				if absf(float(od.get("z", 0.0)) - float(gd.get("z", 0.0))) < 1.0:
					bad.append("%s: %s-монети в доріжці %s просто в перешкоді"
						% [d["id"], gd.get("why"), gd.get("lane")])
	assert_eq(bad, [], "монети нікуди не заманюють: %s" % [bad])


## Тир і рівень мусять рости разом: фраза тиру 3 на першому рівні — це помилка даних,
## яку видно лише тоді, коли дитина вже плаче.
func test_tyr_i_riven_uzhodzheni() -> void:
	var bad := []
	for p in _phrases:
		var d: Dictionary = p
		var tier := int(d["tier"])
		var lvl := int(d["min_level"])
		if tier >= 3 and lvl < 4:
			bad.append("%s: тир %d уже з рівня %d" % [d["id"], tier, lvl])
		if tier <= 1 and lvl > 4:
			bad.append("%s: тир %d аж із рівня %d" % [d["id"], tier, lvl])
	assert_eq(bad, [], "тир і рівень узгоджені: %s" % [bad])


## ── Чи фраза робить те, що обіцяє ──────────────────────────────────────────────

## Апекс звичайного стрибка: HOP_VELOCITY² / (2 · GRAVITY) = 4.6² / 44 ≈ 0,48 м.
const JUMP_APEX_M := 0.48
## Скільки метрів покриває стрибок на НАЙПОВІЛЬНІШОМУ рівні: 2·v/g × швидкість mid на рівні 1.
const JUMP_REACH_M := 1.5


## Найменша кількість дій, якої фраза НЕ дає уникнути.
##
## Навіщо. Легко написати фразу, яка виглядає важкою й нею не є. Мої власні «сходинки»
## обіцяли три стрибки поспіль, а перешкоди стояли в РІЗНИХ доріжках — дитина лишалась в
## одній і стрибала рівно раз. У JSON цього не побачити, на схемі важко, а числом просто.
##
## Модель, і кожна її деталь оплачена помилкою:
##   • ПЕРЕХІД між доріжками коштує 1 за доріжку. Для малюка свайп — така сама дія, як
##     стрибок; коли я рахував рух безкоштовним, «слалом» виходив легшим за «тунель»;
##   • side (хрестик) НЕПРОХІДНИЙ. Його не перестрибнути й не піднирнути, лише обійти —
##     з цією поправкою слалом із 2 дій став 4, тобто ламав правило «не більше трьох»;
##   • усереднюємо по СТАРТОВІЙ доріжці: дитина прибігає з попередньої фрази, і звідки
##     саме — невідомо. Ворота коштують нуль тому, хто вже стоїть навпроти, і два тому,
##     хто прибіг із протилежного краю.
func _min_forced_actions(p: Dictionary) -> float:
	const BIG := 999
	var rows := {}
	for o in p.get("obstacles", []):
		var z := snappedf(float((o as Dictionary).get("z", 0.0)), 0.5)
		if not rows.has(z):
			rows[z] = {}
		(rows[z] as Dictionary)[int((o as Dictionary).get("lane", 0))] = [
			String((o as Dictionary).get("action", "any")),
			String((o as Dictionary).get("motion", "")),
		]
	var zs := rows.keys()
	zs.sort()
	if zs.is_empty():
		return 0.0
	# Ціна РЕАКЦІЇ: ряд, де щось котиться чи перебігає, вимагає рішення ЗАЗДАЛЕГІДЬ.
	# Нерухома перешкода пробачає пізній свайп, рухома — ні, і це справжня складність,
	# якої позиційна модель не бачить узагалі.
	var react := 0
	for z in zs:
		for lane in (rows[z] as Dictionary):
			var m := String(((rows[z] as Dictionary)[lane] as Array)[1])
			if m == "roll" or m == "cross":
				react += 1
				break
	var total := 0.0
	for start in [-1, 0, 1]:
		var cost := {-1: BIG, 0: BIG, 1: BIG}
		cost[start] = 0
		for z in zs:
			var row: Dictionary = rows[z]
			# «cross» перебігає ВСІ доріжки — безпечного місця нема, лише вчасний ухил.
			var sweeps := false
			for lane in row:
				if String((row[lane] as Array)[1]) == "cross":
					sweeps = true
			var next := {}
			for lane in [-1, 0, 1]:
				var move := BIG
				for from_lane in [-1, 0, 1]:
					move = mini(move, int(cost[from_lane]) + absi(from_lane - lane))
				var act := String((row[lane] as Array)[0]) if row.has(lane) else ""
				if act == "side" and not sweeps:
					next[lane] = BIG
				else:
					next[lane] = move + (1 if (row.has(lane) or sweeps) else 0)
			cost = next
		var best := BIG
		for lane in [-1, 0, 1]:
			best = mini(best, int(cost[lane]))
		total += float(best)
	return total / 3.0 + float(react)


## РІВНІСТЬ, а не «не менше». Занижене число обдурить бюджет цеглинки — рівень вийде важчим
## за задум; завищене зробить його легшим. Обидва помітні лише на дитині.
func test_ochky_skladnosti_chesni() -> void:
	var bad := []
	for p in _ready_phrases():
		var d: Dictionary = p
		var forced := _min_forced_actions(d)
		if roundi(forced) != int(d["obstacle_points"]):
			bad.append("%s: заявлено %d, насправді %.2f" % [d["id"], int(d["obstacle_points"]), forced])
	assert_eq(bad, [], "очки складності чесні: %s" % [bad])


## Правило замовника: не більше ТРЬОХ дій поспіль, і це стеля для ВСІХ, а не лише для
## малюків. Для 3–7 років четверта дія — це вже не складність, а тренажер реакції.
func test_stelia_try_diyi() -> void:
	var bad := []
	for p in _ready_phrases():
		var forced := _min_forced_actions(p as Dictionary)
		if forced > 3.01:
			bad.append("%s: %.2f дії" % [(p as Dictionary)["id"], forced])
	assert_eq(bad, [], "жодна фраза не вимагає більше трьох дій: %s" % [bad])


## Бібліотека мусить мати чим наповнити бюджет складності пізніх світів. Якщо все обходиться
## за нуль-одну дію, «важкий» рівень стане просто швидшим — а замовник це назвав прямо:
## «ми нікому не маємо піддаватись, не буде цікавості грати».
func test_ie_spravdi_bezvykhidni_frazy() -> void:
	var hard := 0
	for p in _ready_phrases():
		if _min_forced_actions(p as Dictionary) >= 2.0:
			hard += 1
	assert_gte(hard, 4, "у бібліотеці є щонайменше чотири фрази від двох неминучих дій (%d)" % hard)


## Правило ширини мусить бути в кожної фрази: на 5 і 7 доріжках вона поводиться інакше, і
## «як вийде» тут означає, що стіна на широкій дорозі перестане бути стіною, а пізні світи
## безкоштовно полегшають.
func test_kozhna_fraza_znaie_shcho_robyty_na_shyrokii_dorozi() -> void:
	var bad := []
	for p in _phrases:
		var w := String((p as Dictionary).get("wide", ""))
		if not ["fill", "gate", "keep"].has(w):
			bad.append("%s: wide = «%s»" % [(p as Dictionary)["id"], w])
	assert_eq(bad, [], "у кожної фрази відоме правило ширини: %s" % [bad])


## Дуга мусить бути в межах СТРИБКА, якщо фраза не просить рампи. Моя перша версія джекпоту
## клала десять монет на висоті 1,1 м уздовж дванадцяти метрів — тобто вдвічі вище апексу й
## увосьмеро довше за стрибок. Виглядало багато, зібрати неможливо.
func test_duha_v_mezhakh_strybka() -> void:
	var bad := []
	for p in _ready_phrases():
		var d: Dictionary = p
		if (d.get("needs", []) as Array).has("ramp"):
			continue
		for g in d.get("gold", []):
			var gd: Dictionary = g
			if String(gd.get("kind", "")) != "arc":
				continue
			if float(gd.get("h", 2.6)) > JUMP_APEX_M:
				bad.append("%s: дуга на висоті %s при апексі %.2f" % [d["id"], gd.get("h"), JUMP_APEX_M])
			# Крок у дузі 1,2 м (Spawner3D.spawn_star_arc).
			if float(int(gd.get("n", 1)) - 1) * 1.2 > JUMP_REACH_M:
				bad.append("%s: дуга з %s монет довша за стрибок (%.1f м)" % [d["id"], gd.get("n"), JUMP_REACH_M])
	assert_eq(bad, [], "дуги досяжні: %s" % [bad])


## Джекпот має бути ПОМІТНО більшим за решту — інакше слово втрачає сенс і дитина не
## відчуває події. Заміряно по бібліотеці: звичайна фраза дає 5–12 номіналу.
func test_dzhekpot_spravdi_velykyi() -> void:
	var jackpots := []
	var ordinary := []
	for p in _ready_phrases():
		var nominal := 0
		var is_jackpot := false
		for g in (p as Dictionary).get("gold", []):
			nominal += int((g as Dictionary).get("n", 0)) * int((g as Dictionary).get("value", 1))
			if String((g as Dictionary).get("why", "")) == "jackpot":
				is_jackpot = true
		if is_jackpot:
			jackpots.append(nominal)
		elif nominal > 0:
			ordinary.append(nominal)
	assert_gt(jackpots.size(), 0, "джекпот у бібліотеці є")
	ordinary.sort()
	var median: float = float(ordinary[ordinary.size() / 2])
	for j in jackpots:
		assert_gt(float(j), median * 2.0,
			"джекпот (%d) щонайменше вдвічі більший за звичайну фразу (медіана %.0f)" % [j, median])


## Вісь руху мусить мати лише відомі значення: помилка в ній тиха — Spawner3D не знайде
## перешкоди з таким рухом і просто пропустить запис, лишивши в дорозі дірку.
const MOTIONS := ["", "roll", "cross", "ride"]


func test_vis_rukhu_tilky_vidoma() -> void:
	var bad := []
	for p in _phrases:
		for o in (p as Dictionary).get("obstacles", []):
			var m := String((o as Dictionary).get("motion", ""))
			if not MOTIONS.has(m):
				bad.append("%s: рух «%s»" % [(p as Dictionary)["id"], m])
	assert_eq(bad, [], "усі значення руху відомі: %s" % [bad])


## Кожен світ мусить уміти дати те, що просить фраза. Динамічні фрази написані рухом, а не
## видом, саме щоб пережити біом, — але якщо в якомусь світі нема нічого, що котиться, така
## фраза там мовчки перетвориться на порожнє місце.
func test_kozhen_svit_maie_chym_vidpovisty_na_rukh() -> void:
	var need := {}
	for p in _ready_phrases():
		for o in (p as Dictionary).get("obstacles", []):
			var m := String((o as Dictionary).get("motion", ""))
			if m != "" and m != "ride":
				need[m] = true
	assert_gt(need.size(), 0, "динамічні фрази в бібліотеці є")
	var bad := []
	for world in ["meadow", "forest", "beach", "city", "clouds"]:
		var f := FileAccess.open("res://data/worlds/%s.json" % world, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		var obstacles: Dictionary = (parsed as Dictionary).get("obstacles", {})
		for m in need:
			var found := false
			for k in obstacles:
				var d: Dictionary = obstacles[k]
				if m == "roll" and String(d.get("anim", "")) == "roll":
					found = true
				if m == "cross" and bool(d.get("moves", false)):
					found = true
			if not found:
				bad.append("%s: нема нічого з рухом «%s»" % [world, m])
	assert_eq(bad, [], "кожен світ має чим відповісти на рух: %s" % [bad])
