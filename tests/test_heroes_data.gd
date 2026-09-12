## Перевіряє data/heroes.json.
extends GutTest

## "home" (EDD §3) — новий і єдиний тип для звірят каруселі поруч зі "start";
## решта лишилась ЛИШЕ у legacy-пухнастиків заради старих збережень.
const VALID_UNLOCK_TYPES := ["start", "home", "stars", "checkpoints", "rewarded_or_stars", "growth", "full_game"]
## v1.5: звірята (fox…bear); решта — риси старих пухнастиків (legacy), лишились заради збережень.
const VALID_FEATURES := ["fox", "deer", "dog", "bunny", "cat", "bear", "unicorn", "dolphin", "turtle",
	"tuft", "ears", "tail", "antenna", "stripes", "cloud", "sparkle", "sleepy"]
const HEX_COLOR_RE := "^#[0-9A-Fa-f]{6}$"

var _heroes: Dictionary


func before_each() -> void:
	var f := FileAccess.open("res://data/heroes.json", FileAccess.READ)
	assert_not_null(f, "data/heroes.json має відкриватися")
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	assert_true(typeof(parsed) == TYPE_DICTIONARY, "heroes.json — об'єкт")
	_heroes = parsed


func test_each_hero_shape() -> void:
	var re := RegEx.new()
	re.compile(HEX_COLOR_RE)
	var start_count := 0
	var orders := []
	for key in _heroes.keys():
		if key == "growth" or String(key).begins_with("_"):
			continue
		var hero: Dictionary = _heroes[key]
		assert_true(VALID_FEATURES.has(hero.get("feature", "")), "%s: feature одна з відомих" % key)
		# старі пухнастики (legacy) у каруселі не показуються — їхні order і unlock уже не рахуємо
		var legacy := bool(hero.get("legacy", false))
		if not legacy:
			orders.append(int(hero.get("order", -1)))
		assert_true(hero.has("name_uk"), "%s: має бути name_uk" % key)
		assert_true(String(hero.get("name_uk", "")).length() > 0, "%s: name_uk не порожній" % key)

		var color := String(hero.get("color", ""))
		assert_not_null(re.search(color), "%s: color має бути у форматі #RRGGBB, отримано %s" % [key, color])

		var unlock: Dictionary = hero.get("unlock", {})
		var utype := String(unlock.get("type", ""))
		assert_true(VALID_UNLOCK_TYPES.has(utype), "%s: невідомий unlock.type %s" % [key, utype])

		if utype == "start" and not legacy:
			start_count += 1
		if utype == "rewarded_or_stars":
			assert_gt(float(unlock.get("amount", 0)), 0.0, "%s: rewarded_or_stars має amount > 0" % key)

	assert_eq(start_count, 1, "рівно один герой каруселі має unlock.type == start")
	# EDD §3: усі інші звірята каруселі відкриваються ЛИШЕ добудованою домівкою
	for key in _heroes.keys():
		if key == "growth" or String(key).begins_with("_"):
			continue
		var h: Dictionary = _heroes[key]
		if bool(h.get("legacy", false)):
			continue
		var t := String((h.get("unlock", {}) as Dictionary).get("type", ""))
		assert_true(t in ["start", "home"], "%s: у звірят каруселі лише start або home, а не %s" % [key, t])
	orders.sort()
	assert_eq(orders, [0, 1, 2, 3, 4, 5, 6, 7, 8], "order — 0..8 без дірок (дев'ять звірят у каруселі)")


func test_growth_stages_increase() -> void:
	assert_true(_heroes.has("growth"), "має бути секція growth")
	var growth: Dictionary = _heroes["growth"]
	var stage2_stars := float(growth.get("stage2", {}).get("stars", 0))
	var stage3_stars := float(growth.get("stage3", {}).get("stars", 0))
	assert_lt(stage2_stars, stage3_stars, "growth.stage2.stars < growth.stage3.stars")
