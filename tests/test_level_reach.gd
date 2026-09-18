## Чи вистачає рівня на ШВИДКУ дитину.
##
## Рівень закінчується за ЧАСОМ (level_t >= level_duration у run3d.gd), а маркери стоять у
## МЕТРАХ. Розкладені вони були під профіль mid, тож швидка дитина (older) добігала далі, ніж
## сягали маркери: заміряно по всіх 17 рівнях — остання чверть кожного не мала жодної
## перешкоди, від 90 м на першому до 311 м на сімнадцятому.
##
## Задуманий спокійний фініш — це лише останні 6 секунд (run3d.gd, GATE_BEFORE_SEC), коли
## з'являється фінішна брама й спавн вимикається. Чверть рівня — ні.
extends GutTest

## Середній множник швидкості за рівень: вона росте як 1 + 0.35 × прогрес, тож інтеграл
## по всьому рівню дає 1.175. Спринт в останніх 20% сюди навмисно не входить — вимога має
## бути обережною, інакше тест почне вимагати зайвого.
const RAMP := 1.175


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Найдальший маркер-перешкода рівня, у метрах.
func _last_obstacle_m(level: Dictionary) -> float:
	var far := 0.0
	# Сцени рівня беремо ПЛАНОМ, а не скануванням теки: рівень уже може бути зібраний зі
	# списку цеглинок, і теки levels/level_XX/ у нього просто нема. Сканування тоді обходило б
	# порожнечу — сторож лишався б зеленим, нічого не стережучи.
	for piece in LevelChunkLoader.plan_of(int(level["id"]), level):
		# Сцен у цеглинки одна або дві: сам чанк і вибрана під складність розкладка перешкод.
		# Обидві треба переглянути — маркери лежать і там, і там.
		# z маркера ЛОКАЛЬНА (від початку цеглинки) — зсув призначає той, хто її ставить.
		var offset := float(piece["offset_m"])
		for scene_path in (piece as Dictionary)["paths"]:
			var f := FileAccess.open(String(scene_path), FileAccess.READ)
			if f == null:
				continue
			for block in f.get_as_text().split("[node "):
				if not block.contains("role = \"obstacle\""):
					continue
				var tr := block.find("Transform3D(")
				if tr < 0:
					continue
				var args := block.substr(tr + 12).split(")")[0].split(",")
				far = maxf(far, absf(float(args[args.size() - 1])) + offset)
	return far


func test_every_level_has_obstacles_all_the_way_for_the_fastest_child() -> void:
	var profiles := _json("res://data/profiles.json")
	var fastest := 0.0
	for key in profiles.keys():
		var p = profiles[key]
		if typeof(p) == TYPE_DICTIONARY and (p as Dictionary).has("speed"):
			fastest = maxf(fastest, float((p as Dictionary)["speed"]))
	assert_gt(fastest, 0.0, "найшвидший профіль знайдено")

	var levels: Array = _json("res://data/levels.json").get("levels", [])
	assert_eq(levels.size(), 17, "рівнів сімнадцять")
	for l in levels:
		var level: Dictionary = l
		var num := int(level["id"])
		var need := fastest * float(level["speed_mult"]) * float(level["duration_sec"]) * RAMP
		var have := _last_obstacle_m(level)
		assert_gte(have, need,
			("рівень %d: маркери сягають %.0f м, а швидка дитина пробігає %.0f — "
			+ "хвіст без жодної перешкоди") % [num, have, need])
