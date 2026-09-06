## Перевіряє data/heroes.json.
extends GutTest

const VALID_UNLOCK_TYPES := ["start", "stars", "checkpoints", "rewarded_or_stars", "growth", "full_game"]
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
	for key in _heroes.keys():
		if key == "growth":
			continue
		var hero: Dictionary = _heroes[key]
		assert_true(hero.has("name_uk"), "%s: має бути name_uk" % key)
		assert_true(String(hero.get("name_uk", "")).length() > 0, "%s: name_uk не порожній" % key)

		var color := String(hero.get("color", ""))
		assert_not_null(re.search(color), "%s: color має бути у форматі #RRGGBB, отримано %s" % [key, color])

		var unlock: Dictionary = hero.get("unlock", {})
		var utype := String(unlock.get("type", ""))
		assert_true(VALID_UNLOCK_TYPES.has(utype), "%s: невідомий unlock.type %s" % [key, utype])

		if utype == "start":
			start_count += 1
		if utype == "rewarded_or_stars":
			assert_gt(float(unlock.get("amount", 0)), 0.0, "%s: rewarded_or_stars має amount > 0" % key)

	assert_eq(start_count, 1, "рівно один герой має unlock.type == start")


func test_growth_stages_increase() -> void:
	assert_true(_heroes.has("growth"), "має бути секція growth")
	var growth: Dictionary = _heroes["growth"]
	var stage2_stars := float(growth.get("stage2", {}).get("stars", 0))
	var stage3_stars := float(growth.get("stage3", {}).get("stars", 0))
	assert_lt(stage2_stars, stage3_stars, "growth.stage2.stars < growth.stage3.stars")
