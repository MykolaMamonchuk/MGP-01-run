## ЗВІТ ПРО ЕКОНОМІКУ РІВНІВ — одним числом на цеглинку, а не «на око».
##
## Навіщо. EDD (Confluence 2424833) рахує дохід ПО РІВНЯХ, а рівні 1–8 давно зібрані з
## 150-метрових цеглинок, які перевикористовуються між рівнями. Тобто питання «скільки
## золота має бути на цій цеглинці» з таблиці EDD напряму не читається: та сама цеглинка
## стоїть і на рівні 2, і на рівні 6. Цей звіт переводить модель EDD у ставку НА ЦЕГЛИНКУ й
## показує поруч те, що в цеглинках лежить насправді.
##
## Числа беруться з коду й даних, а не переписуються: швидкість — з profiles.json і
## Run3D.SPEED_RAMP, складність — з Difficulty.of(), розкладка — з ChunkDescriptor.pick_layout().
## Тому звіт не «застаріває» слідом за правками — він їх показує.
##
## Запускати СЦЕНОЮ, а не через -s: збирач цеглинок тягне за собою Spawner3D і Track, а ті —
## автозавантаження (AgeAdapt, AudioMgr), яких у режимі -s не існує. Малювати тут нічого не
## треба, тож --headless цілком годиться.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/economy/report.tscn
##
## Ключі середовища: PROFILE (типово mid), CSV=1 (машинний вивід замість таблиці).
extends Node

## Номінал золота за рівень із моделі EDD §2.2 (колонка «номінал», до множника й збору).
## Це ЦІЛЬ, з якою звіряємось, а не результат заміру.
const EDD_NOMINAL := {
	1: 166, 2: 191, 3: 195, 4: 221, 5: 278, 6: 315, 7: 320, 8: 359, 9: 251,
	10: 284, 11: 293, 12: 394, 13: 441, 14: 454, 15: 429, 16: 485, 17: 545,
}
## Останні 20 % рівня герой біжить зі спринтом ×1.15 (Run3D.SPRINT_MULT).
const SPRINT_FROM := 0.8
const SPRINT_MULT := 1.15
## Той самий розгін, що й Run3D.SPEED_RAMP. Дублюється числом навмисно: Run3D — Node сцени,
## а це SceneTree-скрипт без дерева, і тягнути його сюди заради однієї константи дорожче,
## ніж стерегти збіг тестом (tests/test_economy_report.gd).
const SPEED_RAMP := 0.35


func _ready() -> void:
	var profile_id := OS.get_environment("PROFILE") if OS.has_environment("PROFILE") else "mid"
	var profiles: Dictionary = _json("res://data/profiles.json")
	var base_speed := float((profiles.get(profile_id, {}) as Dictionary).get("speed", 3.5))
	var levels: Array = (_json("res://data/levels.json") as Dictionary).get("levels", [])
	var library := ChunkLibrary.scan()
	var csv := OS.get_environment("CSV") == "1"

	if csv:
		print("рівень,світ,складність,метрів,цеглинок,перешкод,на_150м_перешкод,номінал_EDD,на_150м_золота")
	else:
		print("Профіль %s, base_speed %.2f м/с. Розгін ×%.4f за рівень.\n" % [
			profile_id, base_speed, _ramp_factor()])
		print("%-3s %-8s %5s %6s %6s %6s %7s %8s %8s" % [
			"#", "світ", "скл.", "метрів", "цегл.", "перешк", "на150м", "EDD", "золота"])

	var sum_len := 0.0
	var sum_obst := 0
	for lv in levels:
		var level: Dictionary = lv
		var num := int(level["id"])
		var dist := base_speed * float(level.get("speed_mult", 1.0)) * _ramp_factor() \
			* float(level.get("duration_sec", 90.0))
		var bricks := dist / LevelChunkLoader.CHUNK_LENGTH_M
		var obst := _obstacles_of(level, library)
		var gold := float(EDD_NOMINAL.get(num, 0)) / maxf(0.1, bricks)
		sum_len += dist
		sum_obst += obst
		if csv:
			print("%d,%s,%.3f,%.0f,%.2f,%d,%.1f,%d,%.1f" % [num, level["world"],
				Difficulty.of(level), dist, bricks, obst, float(obst) / maxf(0.1, bricks),
				int(EDD_NOMINAL.get(num, 0)), gold])
		else:
			print("%-3d %-8s %5.2f %6.0f %6.1f %6d %7.1f %8d %8.0f" % [num, level["world"],
				Difficulty.of(level), dist, bricks, obst, float(obst) / maxf(0.1, bricks),
				int(EDD_NOMINAL.get(num, 0)), gold])
	if not csv:
		print("\nЗа один прохід гри: %.0f м, %.1f цеглинки, %d перешкод." % [
			sum_len, sum_len / LevelChunkLoader.CHUNK_LENGTH_M, sum_obst])
	get_tree().quit()


## Середній множник швидкості за рівень: розгін 1 + SPEED_RAMP × прогрес, плюс спринт в
## останніх 20 %. Інтеграл, а не «швидкість посередині»: різниця на рівні 17 — понад сто метрів.
func _ramp_factor() -> float:
	var r := SPEED_RAMP
	var a := SPRINT_FROM + 0.5 * r * SPRINT_FROM * SPRINT_FROM
	var whole := 1.0 + 0.5 * r
	return a + SPRINT_MULT * (whole - a)


## Скільки маркерів-перешкод дістане цей рівень: збирач уже вибрав цеглинки й розкладки,
## тож просто читаємо те, що він вибрав. Рівень без списку цеглинок повертає 0 — це не
## помилка, а факт: рівні 9–17 ще не переведені на бібліотеку.
func _obstacles_of(level: Dictionary, library: Dictionary) -> int:
	var n := 0
	for piece in LevelChunkLoader.plan_of(int(level["id"]), level):
		for path in (piece as Dictionary).get("paths", []):
			var text := _read(String(path))
			if text == "":
				continue
			n += text.count("role = \"obstacle\"")
	return n


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
