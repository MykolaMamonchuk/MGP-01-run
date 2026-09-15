## Економіка (EDD, docs/ECONOMY.md): крива «по кишені», форма data/homes.json, полиці цін.
##
## Тест НЕ перевіряє красиві числа — він перевіряє інваріант: дитина, яка проходить кожен
## рівень один раз на 2★, ЗАВЖДИ має чим заплатити за наступний рівень і за домівку друга,
## якого вже знайшла. Модель доходу — та сама, що в ECONOMY.md §2; якщо міняються дані
## (тривалість, щільність, ціни) або константи Rules — тест ловить розбіжність сам.
extends GutTest

## Скрипт автолоада — щоб дістатись до констант і чистих функцій міграції без інстанса.
const SaveScript := preload("res://addons/mgp_core/save/save_service.gd")

# ---------- константи моделі (ECONOMY.md §2.1) ----------

## Середній інтервал між групами перешкод у профілі mid, секунд (profiles.json 1.8…3.0).
const OBSTACLE_INTERVAL_MID := 2.4
## Номінал злитків, який у середньому дає одна група (лінія з 5 не за кожною групою).
const INGOTS_PER_GROUP := 4.3
## Скільки з того, що з'явилось, дитина справді підбирає (магніт 1.0).
const COLLECT_SHARE := 0.85
## Середній множник за пробіг: серія впирається в стелю ×3, один удар на 2★ її скидає.
const AVG_MULT := 2.6
## Великий злиток раз на стільки секунд.
const BIG_PERIOD_SEC := 25.0
## Сегмент другого ярусу раз на стільки секунд і скільки номіналу на ньому.
const TIER2_PERIOD_SEC := 32.5
const TIER2_VALUE := 27.0
## Світи з другим ярусом (дахи транспорту / платформи).
const TIER2_WORLDS := ["forest", "city", "clouds"]
## Математичне сподівання колеса станції: 7 числових секторів (10,20,10,50,20,30,20) з восьми.
const WHEEL_EV := 20.0
## Зірки типового першого проходження.
const TYPICAL_STARS := 2
## Мінімальний запас: скільки відсотків доходу лишається понад обов'язкові витрати.
const MIN_SLACK := 0.10

var _levels: Array = []
var _homes: Array = []


func before_all() -> void:
	_levels = LevelManager.load_levels()
	_homes = _load_json("res://data/homes.json").get("homes", [])


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "%s читається" % path)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# ---------- модель доходу ----------

## Очікуваний дохід за ОДИН прохід рівня на 2★, профіль mid (ECONOMY.md §2.2).
func expected_income(level: Dictionary) -> float:
	var dur := float(level.get("duration_sec", 0))
	var dens := float(level.get("density", 1.0))
	if dur <= 0.0 or dens <= 0.0:
		return 0.0
	var groups := dur / (OBSTACLE_INTERVAL_MID * dens)
	var face := groups * INGOTS_PER_GROUP
	face += dur / BIG_PERIOD_SEC * float(Spawner3D.BIG_VALUE)
	if TIER2_WORLDS.has(String(level.get("world", ""))):
		face += dur / TIER2_PERIOD_SEC * TIER2_VALUE
	var road := face * COLLECT_SHARE * AVG_MULT
	return road + float(Rules.finish_bonus(int(level.get("id", 1)), TYPICAL_STARS)) + WHEEL_EV


## Обов'язкові витрати після проходження рівня num: ціна НАСТУПНОГО рівня (і всіх попередніх)
## плюс домівки всіх друзів, яких на цей момент уже знайдено.
func required_after(num: int) -> int:
	var total := 0
	for l in _levels:
		if int(l.get("id", 0)) <= num + 1:
			total += int(l.get("price", 0))
	for h in _homes:
		if int((h as Dictionary).get("unlock_level", 99)) <= num:
			total += int((h as Dictionary).get("price", 0))
	return total


# ---------- крива «по кишені» ----------

func test_affordability_curve_has_slack_on_every_level() -> void:
	var earned := 0.0
	for l in _levels:
		var num := int(l["id"])
		earned += expected_income(l)
		var need := float(required_after(num))
		assert_gt(earned, 0.0, "рівень %d: модель дає дохід" % num)
		assert_gte(earned, need * (1.0 + MIN_SLACK),
			"рівень %d: зароблено %d, треба %d — запас менший за %d %%" % [num, int(earned), int(need), int(MIN_SLACK * 100.0)])


func test_gold_never_blocks_the_next_home() -> void:
	# найтугіший вузол — щойно знайдено друга: домівка має бути по кишені ТОГО Ж рівня
	var earned := 0.0
	for l in _levels:
		var num := int(l["id"])
		earned += expected_income(l)
		for h in _homes:
			if int((h as Dictionary).get("unlock_level", 99)) != num:
				continue
			assert_gte(earned, float(required_after(num)),
				"рівень %d: домівка «%s» має бути по кишені одразу" % [num, String((h as Dictionary).get("name_uk", ""))])


func test_one_full_pass_does_not_buy_everything() -> void:
	# перегравання має лишатись сенс: декор двору й крамниця не закриваються з першого разу
	var earned := 0.0
	for l in _levels:
		earned += expected_income(l)
	var sinks := 0
	for l in _levels:
		sinks += int(l.get("price", 0))
	for h in _homes:
		sinks += int((h as Dictionary).get("price", 0))
	for w in (_load_json(Diorama.DATA_PATH).get("worlds", {}) as Dictionary).values():
		for d in (w as Array):
			sinks += int((d as Dictionary).get("price", 0))
	for it in Shop.load_all():
		sinks += int((it as Dictionary).get("price", 0))
	assert_gt(float(sinks), earned, "усі сінки (%d) дорожчі за один прохід (%d)" % [sinks, int(earned)])


# ---------- data/homes.json ----------

func test_homes_shape_and_price_ladder() -> void:
	assert_eq(_homes.size(), 12, "11 друзів + сорока дванадцятою (EDD §3)")
	var want_prices := [100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600, 700]
	var prices := []
	var ids := {}
	var slots := []
	var worlds := {}
	for l in _levels:
		worlds[String(l.get("world", ""))] = true
	for h in _homes:
		var home: Dictionary = h
		var id := String(home.get("id", ""))
		assert_ne(id, "", "у домівки є id")
		assert_false(ids.has(id), "id «%s» не повторюється" % id)
		ids[id] = true
		assert_ne(String(home.get("friend", "")), "", "%s: є ім'я друга" % id)
		assert_ne(String(home.get("name_uk", "")), "", "%s: є підпис українською" % id)
		assert_true(String(home.get("element", "")) in ["land", "water", "sky"], "%s: стихія land/water/sky" % id)
		assert_true(worlds.has(String(home.get("world", ""))), "%s: світ є серед рівнів" % id)
		assert_true(typeof(home.get("requires_spark")) == TYPE_BOOL, "%s: requires_spark — булеве" % id)
		assert_between(int(home.get("unlock_level", 0)), 1, _levels.size(), "%s: друга знаходять на наявному рівні" % id)
		prices.append(int(home.get("price", 0)))
		slots.append(int(home.get("slot", -1)))
	assert_eq(prices, want_prices, "драбина цін домівок 100…600 з кроком 50 + гніздо сороки 700")
	slots.sort()
	assert_eq(slots, range(0, 12), "ділянки двору 0..11 без дірок")


func test_first_home_is_free_of_spark_and_magpie_is_last() -> void:
	assert_eq(String((_homes[0] as Dictionary).get("id", "")), "lys", "перша домівка — Лискова")
	assert_false(bool((_homes[0] as Dictionary).get("requires_spark", true)), "перша домівка не чекає вогника")
	var last: Dictionary = _homes[_homes.size() - 1]
	assert_eq(String(last.get("id", "")), "magpie", "сорока — дванадцятий друг фіналу")
	assert_eq(String(last.get("element", "")), "sky", "сорока — небесний герой")


func test_every_carousel_hero_with_home_unlock_has_a_home() -> void:
	var by_id := {}
	for h in _homes:
		by_id[String((h as Dictionary).get("id", ""))] = true
	var heroes := HeroSelect.load_heroes()
	for id in HeroSelect.order_ids(heroes):
		var u: Dictionary = (heroes[id] as Dictionary).get("unlock", {})
		if String(u.get("type", "")) != "home":
			continue
		assert_true(by_id.has(String(u.get("friend", id))), "герой %s відкривається домівкою, якої нема в homes.json" % id)


# ---------- полиці цін косметики (EDD §3) ----------

func test_shop_price_tiers() -> void:
	var common := 0
	var rare := 0
	var epic := 0
	for it in Shop.load_all():
		var price := int((it as Dictionary).get("price", 0))
		if price == 0:
			continue
		if price <= 120:
			common += 1
		elif price <= 400:
			rare += 1
		else:
			epic += 1
			assert_between(price, 600, 900, "%s: преміум-полиця 600–900" % String((it as Dictionary).get("id", "")))
		assert_gte(price, 60, "%s: дешевше за 60 злитків косметики не буває" % String((it as Dictionary).get("id", "")))
	assert_gt(common, 0, "звичайна полиця не порожня")
	assert_gte(rare, 3, "рідкісна полиця: щонайменше три предмети")
	assert_gte(epic, 2, "преміум-полиця: корона й сяйво")


# ---------- міграція нумерації рівнів (EDD §2) ----------

func test_level_remap_shifts_late_levels_down() -> void:
	var remap: Dictionary = SaveScript.LEVELS_V2_REMAP
	var out := SaveScript.remap_level_stars({"1": 3, "9": 2, "12": 1, "13": 3, "17": 2}, remap)
	assert_eq(int(out.get("1", 0)), 3, "ранні рівні не рухаються")
	assert_eq(int(out.get("9", 0)), 2, "пляж лишився пляжем")
	assert_eq(int(out.get("12", 0)), 3, "старий 13 (Парк) став 12; кращий результат перемагає")
	assert_eq(int(out.get("16", 0)), 2, "старий фінал 17 став 16")
	assert_false(out.has("17"), "17 — новий рівень, зірок там ще нема")


func test_level_remap_is_idempotent_and_safe() -> void:
	var remap: Dictionary = SaveScript.LEVELS_V2_REMAP
	var once := SaveScript.remap_level_stars({"13": 3}, remap)
	assert_eq(int(once.get("12", 0)), 3)
	assert_eq(SaveScript.remap_level_stars({}, remap).size(), 0, "порожнє збереження не падає")
	var bought := SaveScript.remap_bought([2, 3.0, 13, 17], remap)
	assert_eq(bought, [2, 3, 12, 16], "куплені рівні їдуть за тією ж таблицею, дублікатів нема")
	assert_eq(SaveScript.remap_bought([], remap), [], "нічого не куплено — нічого не мігрує")
