## Карусель героїв (порядок, відкриття, підказки) і сезони — чисті функції.
extends GutTest

var _heroes: Dictionary


func before_each() -> void:
	_heroes = HeroSelect.load_heroes()


func test_order_ids_skips_service_keys_and_sorts() -> void:
	var ids := HeroSelect.order_ids(_heroes)
	assert_eq(ids.size(), 6, "6 звірят у каруселі (старі пухнастики — legacy, їх не показуємо)")
	assert_eq(ids[0], "lys", "стартовий герой перший")
	assert_false(ids.has("puf"), "старий пухнастик лишився в даних, але не в каруселі")
	assert_false(ids.has("growth"))
	assert_false(ids.has("_note"))


func test_unlock_rules() -> void:
	assert_true(HeroSelect.is_unlocked({"unlock": {"type": "start"}}, 0, 0, false))
	assert_false(HeroSelect.is_unlocked({"unlock": {"type": "stars", "amount": 100}}, 99, 0, false))
	assert_true(HeroSelect.is_unlocked({"unlock": {"type": "stars", "amount": 100}}, 100, 0, false))
	assert_true(HeroSelect.is_unlocked({"unlock": {"type": "rewarded_or_stars", "amount": 300}}, 300, 0, false), "rewarded_or_stars відкривається зірочками")
	assert_true(HeroSelect.is_unlocked({"unlock": {"type": "checkpoints", "amount": 3}}, 0, 3, false))
	assert_false(HeroSelect.is_unlocked({"unlock": {"type": "full_game"}}, 9999, 99, false), "преміум — лише «Повна гра», не зірочки")
	assert_true(HeroSelect.is_unlocked({"unlock": {"type": "full_game"}}, 0, 0, true))
	assert_false(HeroSelect.is_unlocked({"unlock": {"type": "growth", "stage": 2}}, 0, 0, false, 1))
	assert_true(HeroSelect.is_unlocked({"unlock": {"type": "growth", "stage": 2}}, 0, 0, false, 2))


func test_unlock_hints() -> void:
	assert_eq(HeroSelect.unlock_hint({"unlock": {"type": "start"}}), "")
	assert_eq(HeroSelect.unlock_hint({"unlock": {"type": "stars", "amount": 100}}), "100")
	assert_true(HeroSelect.unlock_hint({"unlock": {"type": "full_game"}}).contains("батьк"), "преміум — «разом з батьками»")


func test_only_start_hero_unlocked_at_zero() -> void:
	var n := 0
	for id in HeroSelect.order_ids(_heroes):
		if HeroSelect.is_unlocked(_heroes[id], 0, 0, false):
			n += 1
	assert_eq(n, 1, "з нуля відкритий лише стартовий")


func test_stats_of_defaults_and_values() -> void:
	# нема героя / нема stats — база
	var d := HeroSelect.stats_of(_heroes, "no_such_hero")
	assert_eq(int(d["hearts"]), 3)
	assert_eq(float(d["magnet"]), 1.0)
	assert_eq(float(d["speed"]), 1.0)
	assert_eq(float(d["luck"]), 1.0)
	var partial := HeroSelect.stats_of({"x": {"stats": {"luck": 1.3}}}, "x")
	assert_eq(int(partial["hearts"]), 3, "відсутні поля — дефолт")
	assert_eq(float(partial["luck"]), 1.3)
	# дані героїв (GDD v1.3 §5)
	assert_eq(float(HeroSelect.stats_of(_heroes, "vushko")["magnet"]), 1.3, "Вушко — магніт")
	assert_eq(float(HeroSelect.stats_of(_heroes, "khvostyk")["speed"]), 1.05, "Хвостик — швидкість")
	assert_eq(float(HeroSelect.stats_of(_heroes, "antenka")["luck"]), 1.3, "Антенка — удача")
	assert_eq(int(HeroSelect.stats_of(_heroes, "sonia")["hearts"]), 4, "Соня — 4 життя")
	assert_eq(float(HeroSelect.stats_of(_heroes, "sonia")["speed"]), 0.95)
	assert_eq(float(HeroSelect.stats_of(_heroes, "khmarynka")["magnet"]), 1.2)
	for id in HeroSelect.order_ids(_heroes):
		var s := HeroSelect.stats_of(_heroes, id)
		assert_true((_heroes[id] as Dictionary).has("stats"), "%s: має stats" % id)
		assert_between(int(s["hearts"]), 3, 4, "%s: життя 3..4" % id)
		for k in ["magnet", "speed", "luck"]:
			assert_between(float(s[k]), 0.9, 1.3, "%s/%s у межах" % [id, k])


func test_stat_dots() -> void:
	assert_eq(HeroSelect.stat_dots("hearts", 3.0), 3)
	assert_eq(HeroSelect.stat_dots("hearts", 4.0), 4)
	assert_eq(HeroSelect.stat_dots("hearts", 9.0), 4, "не більше 4 крапок")
	assert_eq(HeroSelect.stat_dots("magnet", 1.0), 1, "база — одна крапка")
	assert_eq(HeroSelect.stat_dots("speed", 0.95), 1, "повільніший — все одно одна")
	assert_eq(HeroSelect.stat_dots("magnet", 1.1), 2)
	assert_eq(HeroSelect.stat_dots("magnet", 1.2), 3)
	assert_eq(HeroSelect.stat_dots("luck", 1.3), 4)
	assert_eq(HeroSelect.stat_dots("speed", 1.05), 2)


func test_strip_clamp_and_paging() -> void:
	# вміщується — по центру
	assert_eq(ItemStrip.clamp_x(-300.0, 500.0, 1100.0), 300.0)
	assert_eq(ItemStrip.clamp_x(0.0, 1100.0, 1100.0), 0.0)
	# не вміщується — від (view − content) до 0
	assert_eq(ItemStrip.clamp_x(50.0, 2000.0, 1100.0), 0.0, "правіше початку не буває")
	assert_eq(ItemStrip.clamp_x(-999.0, 2000.0, 1100.0), -900.0, "лівіше кінця не буває")
	assert_eq(ItemStrip.clamp_x(-300.0, 2000.0, 1100.0), -300.0, "усередині — як є")
	# сторінки: на ширину вікна
	assert_eq(ItemStrip.page_x(0.0, 1, 3000.0, 1100.0), -1100.0)
	assert_eq(ItemStrip.page_x(-1100.0, 1, 3000.0, 1100.0), -1900.0, "остання сторінка обрізається до краю")
	assert_eq(ItemStrip.page_x(-1900.0, 1, 3000.0, 1100.0), -1900.0, "далі нікуди")
	assert_eq(ItemStrip.page_x(-1900.0, -1, 3000.0, 1100.0), -800.0)
	assert_eq(ItemStrip.page_x(-800.0, -1, 3000.0, 1100.0), 0.0)
	assert_eq(ItemStrip.page_x(0.0, 1, 500.0, 1100.0), 300.0, "усе вміщується — стоїть по центру")


func test_seasons_cover_all_months() -> void:
	var all := Seasons.load_all()
	assert_eq(all.size(), 4)
	for m in range(1, 13):
		assert_false(Seasons.pick(all, m).is_empty(), "місяць %d має сезон" % m)
	assert_eq(Seasons.pick(all, 1).get("id"), "winter")
	assert_eq(Seasons.pick(all, 9).get("id"), "autumn")
	assert_true(Seasons.pick(all, 13).is_empty(), "поза 1..12 — порожньо")


func test_winter_has_snow() -> void:
	assert_eq(Seasons.pick(Seasons.load_all(), 12).get("particles"), "snow")
