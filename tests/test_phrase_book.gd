## ЗБИРАЧ ЦЕГЛИНКИ: чи дотримані правила темпу.
##
## У PhraseBook.compose() живе весь дизайн дороги — саме він вирішує, що дитина зустріне й
## у якому порядку. Перевіряти його оком на згенерованій сцені марно: правила стосуються
## ПОСЛІДОВНОСТІ («після важкого — вдих», «не двічі те саме поспіль», «спокійні краї»), а не
## окремого місця, і зламане правило видно лише тоді, коли дитині вже не дали перепочити.
extends GutTest

var _phrases: Array = []
var _rng: RandomNumberGenerator


func before_all() -> void:
	_phrases = PhraseBook.load_all()


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 20260921


## Типова цеглинка рівня 6: 150 м, швидкість mid із розгоном, бюджет 8 очок і 85 золота.
func _brick(level: int = 6, points: int = 6, speed: float = 5.6) -> Array:
	return PhraseBook.compose(_phrases, level, 150.0, speed, points, _rng)


func test_biblioteka_chytaietsia() -> void:
	assert_gt(_phrases.size(), 10, "фрази прочитались")


func test_tsehlynka_zapovniuietsia() -> void:
	var seq := _brick()
	assert_gt(seq.size(), 4, "цеглинка набрала фрази (%d)" % seq.size())
	var last: Dictionary = seq[-1]
	assert_lt(float(last["at_m"]), 150.0, "остання фраза починається в межах цеглинки")


## Бюджет — це стеля, а не побажання. Перевищити його означає зробити рівень важчим за
## задум, і саме цього збирач має не допускати навіть тоді, коли бюджет не добрано.
func test_biudzhet_ochok_ne_perevyshchuietsia() -> void:
	for points in [0, 2, 3, 5, 6]:
		var s := PhraseBook.summary(_brick(6, points))
		assert_lte(int(s["очок"]), points, "бюджет %d не перевищено (вийшло %d)" % [points, int(s["очок"])])


## Дві однакові фрази поспіль читаються як помилка гри, а не як задум.
func test_dvi_odnakovi_ne_pospil() -> void:
	for lvl in [1, 3, 6, 10]:
		var seq := _brick(lvl)
		for i in range(seq.size() - 1):
			var a := String(((seq[i] as Dictionary)["phrase"] as Dictionary)["id"])
			var b := String(((seq[i + 1] as Dictionary)["phrase"] as Dictionary)["id"])
			assert_ne(a, b, "рівень %d: «%s» двічі поспіль" % [lvl, a])


func test_odna_fraza_ne_bilshe_dvokh_raziv() -> void:
	for lvl in [1, 3, 6, 10]:
		var count := {}
		for item in _brick(lvl):
			var id := String(((item as Dictionary)["phrase"] as Dictionary)["id"])
			count[id] = int(count.get(id, 0)) + 1
		for id in count:
			assert_lte(int(count[id]), PhraseBook.MAX_REPEATS,
				"рівень %d: «%s» узято %d разів" % [lvl, id, int(count[id])])


## ГОЛОВНЕ ПРАВИЛО ТЕМПУ: після фрази від двох дій мусить іти фраза без жодної.
func test_pislia_vazhkoi_ide_vdykh() -> void:
	for lvl in [6, 8, 10]:
		var seq := _brick(lvl, 6)
		for i in range(seq.size() - 1):
			var a: Dictionary = (seq[i] as Dictionary)["phrase"]
			if int(a.get("obstacle_points", 0)) < 2:
				continue
			var b: Dictionary = (seq[i + 1] as Dictionary)["phrase"]
			assert_eq(int(b.get("obstacle_points", 0)), 0,
				"рівень %d: після «%s» (%d очок) іде «%s» (%d), а мав іти вдих"
					% [lvl, a["id"], int(a["obstacle_points"]), b["id"], int(b.get("obstacle_points", 0))])


## Краї цеглинки спокійні: цеглинки переставляються між рівнями, і важкий кінець однієї не
## має зійтися з важким початком іншої.
func test_kraii_tsehlynky_spokiini() -> void:
	for lvl in [6, 10]:
		var seq := _brick(lvl, 6)
		for item in seq:
			var d: Dictionary = item
			var p: Dictionary = d["phrase"]
			var at := float(d["at_m"])
			var tail := at + float(p.get("length_m", 0.0))
			if at < PhraseBook.CALM_EDGE_M or tail > 150.0 - PhraseBook.CALM_EDGE_M:
				assert_lte(int(p.get("obstacle_points", 0)), PhraseBook.CALM_EDGE_POINTS,
					"рівень %d: «%s» на %.0f м — це край цеглинки" % [lvl, p["id"], at])


## Один джекпот на цеглинку: два перетворюють рідкісну подію на звичайну.
func test_odyn_dzhekpot_na_tsehlynku() -> void:
	for lvl in [6, 8, 10]:
		var n := 0
		for item in _brick(lvl, 6):
			for g in (((item as Dictionary)["phrase"] as Dictionary).get("gold", []) as Array):
				if String((g as Dictionary).get("why", "")) == "jackpot":
					n += 1
		assert_lte(n, 1, "рівень %d: джекпотів %d" % [lvl, n])


## Фрази не налазять одна на одну: наступна починається не раніше, ніж кінчається попередня
## РАЗОМ із обов'язковим вдихом.
func test_frazy_ne_nalyzayut() -> void:
	var speed := 5.6
	var seq := _brick(6, 6, speed)
	for i in range(seq.size() - 1):
		var a: Dictionary = seq[i]
		var need := float(a["at_m"]) + PhraseBook.span_of(a["phrase"], speed)
		assert_gte(float((seq[i + 1] as Dictionary)["at_m"]), need - 0.11,
			"«%s» налазить на попередню" % [((seq[i + 1] as Dictionary)["phrase"] as Dictionary)["id"]])


## Механіка не з'являється раніше свого рівня — інакше дитина зустріне бочку до того, як їй
## показали, що таке бочка.
func test_mekhanika_ne_vyperedzhaie_riven() -> void:
	for lvl in [1, 2, 3, 5]:
		for item in _brick(lvl, 6):
			var p: Dictionary = (item as Dictionary)["phrase"]
			assert_lte(int(p.get("min_level", 1)), lvl,
				"рівень %d дістав «%s» (з рівня %d)" % [lvl, p["id"], int(p.get("min_level", 1))])


## Нереалізовані механіки не потрапляють у дорогу взагалі.
func test_nerealizovane_ne_potrapliaie() -> void:
	for lvl in [1, 6, 10, 17]:
		for item in _brick(lvl, 6):
			assert_false(((item as Dictionary)["phrase"] as Dictionary).has("needs"),
				"у дорогу потрапила фраза, механіки якої ще нема")


## Туторіал мусить збиратись теж — саме на ньому бібліотека найтонша, і саме там збирач
## найлегше заганяється в глухий кут.
func test_tutorial_zbyraietsia() -> void:
	var seq := PhraseBook.compose(_phrases, 1, 150.0, 4.3, 3, _rng)
	assert_gt(seq.size(), 3, "рівень 1 набрав фрази (%d)" % seq.size())
	var s := PhraseBook.summary(seq)
	assert_lte(int(s["очок"]), 3, "і не перевищив бюджет туторіалу")


## Бюджет нуль очок — це теж дійсна цеглинка: суцільний відпочинок після важкого рівня.
func test_nulovyi_biudzhet_daie_spokiinu_tsehlynku() -> void:
	var s := PhraseBook.summary(_brick(10, 0))
	assert_eq(int(s["очок"]), 0, "жодної неминучої дії")
	assert_gt(int(s["фраз"]), 0, "але дорога не порожня")


## БЮДЖЕТ ЗОЛОТА витримується НОМІНАЛОМ, а не вибором фраз.
##
## Дві вимоги мусять виконатись одночасно, і жодна прибита цифра у фразі їх не мирить:
## модель EDD чекає ~73 номіналу з цеглинки, а замовник просив 20–32 ВИДИМІ монети. Тому в
## фразі лежить ВАГА, а множник підбирається на цеглинку. Дробовий із перенесенням залишку,
## бо один цілий множник дає драбину ×1/×2 і промах до третини.
func test_biudzhet_zolota_vytrymuietsia_nominalom() -> void:
	for budget in [50, 73, 85, 120]:
		var placed := PhraseBook.place(_brick(6), budget)
		var got := PhraseBook.gold_placed(placed)
		assert_almost_eq(float(got), float(budget), float(budget) * 0.15,
			"бюджет %d витримано (вийшло %d)" % [budget, got])


## Жодна монета не може коштувати нуль — це була б монета, яку видно й за яку нічого не дають.
func test_zhodna_moneta_ne_koshtuie_nul() -> void:
	for budget in [10, 73, 300]:
		for g in (PhraseBook.place(_brick(6), budget).get("gold", []) as Array):
			assert_gte(int((g as Dictionary).get("value", 0)), 1,
				"монета коштує щонайменше одиницю")


## Розстановка віддає ті самі метри, що й складання: фраза на 40-му метрі кладе перешкоди
## на 40 з чимось, а не на свої локальні нулі.
func test_rozstanovka_perenosyt_metry() -> void:
	var seq := _brick()
	var placed := PhraseBook.place(seq, 73)
	var obstacles: Array = placed["obstacles"]
	assert_gt(obstacles.size(), 0, "перешкоди розставлені")
	var zs := []
	for o in obstacles:
		zs.append(float((o as Dictionary)["z_m"]))
	zs.sort()
	assert_gte(zs[0], 0.0, "нічого не вилізло перед цеглинкою")
	assert_lt(zs[-1], 150.0, "і нічого за неї")


## Стеля цеглинки. Заміряно 21.09.2026: ~6 неминучих дій на 150 м, і вона НЕ РОСТЕ з
## рівнем — швидший рівень має довші вдихи в метрах, і це з'їдає виграш від важчих фраз.
## Отже складність росте не щільністю, а ШВИДКІСТЮ (ті самі шість дій ущільнюються з 5,9 с
## між ними на рівні 1 до 4,1 с на восьмому) і кількістю цеглинок. Сторож тут на те, щоб
## ніхто не прописав у бюджет цеглинки 12 очок, вважаючи, що їх хтось поставить.
func test_stelia_tsehlynky_shist_ochok() -> void:
	for lvl in [1, 6, 10]:
		var s := PhraseBook.summary(PhraseBook.compose(_phrases, lvl, 150.0, 5.6, 99, _rng))
		assert_lte(int(s["очок"]), 8, "рівень %d: стеля цеглинки не зрушила вгору" % lvl)
		assert_gte(int(s["очок"]), 4, "рівень %d: і не впала" % lvl)
