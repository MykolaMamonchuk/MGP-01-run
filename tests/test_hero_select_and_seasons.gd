## Карусель героїв (порядок, відкриття, підказки) і сезони — чисті функції.
extends GutTest

var _heroes: Dictionary


func before_each() -> void:
	_heroes = HeroSelect.load_heroes()


func test_order_ids_skips_service_keys_and_sorts() -> void:
	var ids := HeroSelect.order_ids(_heroes)
	assert_eq(ids.size(), 8, "8 героїв на запуску")
	assert_eq(ids[0], "puf", "стартовий герой перший")
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
