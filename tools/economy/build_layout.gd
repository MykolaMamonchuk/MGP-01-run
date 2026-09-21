## ЗІБРАТИ РОЗКЛАДКУ ЦЕГЛИНКИ З ФРАЗ і записати її справжньою сценою.
##
## Доти розкладки (`levels/chunks/*/layout_*.tscn`) розставляли рукою в редакторі, і в них
## лежали самі перешкоди: 5–10 маркерів, жодного золота. Через це золото було єдиним, що
## лишалось випадковим, а складність цеглинки ніхто не рахував — вона просто виходила.
##
## Тепер розкладка збирається з бібліотеки фраз (data/phrases.json) під ДВА бюджети: скільки
## неминучих дій вона має вимагати й скільки номіналу золота дати. Збирач дотримується
## правил темпу (PhraseBook.compose), а номінал підганяє під бюджет (PhraseBook.place).
##
## Результат — звичайний .tscn із маркерами, який можна відкрити в редакторі й посунути
## мишею. Це навмисно: згенероване має лишатись правним, інакше автор рівня стає заручником
## генератора.
##
##   CHUNK=meadow_gate LAYOUT=layout_auto.tscn LEVEL=4 POINTS=5 GOLD=66 \
##     /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##     res://tools/economy/build_layout.tscn
##
## Ключі: CHUNK (id цеглинки), LAYOUT (ім'я файлу), LEVEL (який рівень — від нього залежить,
## які механіки вже введені), POINTS, GOLD, SEED, SPEED (м/с; типово беремо з рівня), DRY=1.
extends Node



func _ready() -> void:
	var chunk := _env("CHUNK", "")
	if chunk == "":
		push_error("build_layout: треба CHUNK=<id цеглинки>")
		get_tree().quit(1)
		return
	var dir := "res://levels/chunks/%s" % chunk
	if not DirAccess.dir_exists_absolute(dir):
		push_error("build_layout: нема теки %s" % dir)
		get_tree().quit(1)
		return
	var level := int(_env("LEVEL", "4"))
	var points := int(_env("POINTS", "5"))
	var gold := int(_env("GOLD", "73"))
	var speed := float(_env("SPEED", "0"))
	if speed <= 0.0:
		speed = _speed_of(level)
	var length := _length_of(dir)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(_env("SEED", "20260921"))
	var seq := PhraseBook.compose(PhraseBook.load_all(), level, length, speed, points, rng)
	if seq.is_empty():
		push_error("build_layout: збирач нічого не склав — перевір LEVEL і POINTS")
		get_tree().quit(1)
		return
	var placed := PhraseBook.place(seq, gold)

	print("цеглинка %s · рівень %d · %.0f м · %.2f м/с" % [chunk, level, length, speed])
	for item in seq:
		var p: Dictionary = (item as Dictionary)["phrase"]
		print("  %6.1f м  %-16s %d очок" % [float((item as Dictionary)["at_m"]), p["id"],
			int(p.get("obstacle_points", 0))])
	print("  разом: перешкод %d, монет %d, золота %d (бюджет %d), очок %d (бюджет %d)" % [
		(placed["obstacles"] as Array).size(), _coins(placed),
		PhraseBook.gold_placed(placed), gold,
		int(PhraseBook.summary(seq)["очок"]), points])

	if _env("DRY", "") == "1":
		get_tree().quit()
		return
	var path := "%s/%s" % [dir, _env("LAYOUT", "layout_auto.tscn")]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("build_layout: не записалось у %s (%d)" % [path, FileAccess.get_open_error()])
		get_tree().quit(1)
		return
	f.store_string(PhraseBook.to_scene_text(placed))
	f.close()
	print("записано: %s" % path)
	print("ДОПИШИ в chunk.json: {\"file\": \"%s\", \"difficulty\": [..], \"points\": %d, \"gold\": %d}"
		% [_env("LAYOUT", "layout_auto.tscn"), points, gold])
	get_tree().quit()


func _length_of(dir: String) -> float:
	var f := FileAccess.open("%s/chunk.json" % dir, FileAccess.READ)
	if f == null:
		return LevelChunkLoader.CHUNK_LENGTH_M
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return LevelChunkLoader.CHUNK_LENGTH_M
	return float((parsed as Dictionary).get("length_m", LevelChunkLoader.CHUNK_LENGTH_M))


## Середня швидкість рівня в м/с — та сама формула, що в tools/economy/report.gd.
func _speed_of(num: int) -> float:
	var f := FileAccess.open("res://data/levels.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
	var mult := 1.0
	if typeof(parsed) == TYPE_DICTIONARY:
		for lv in ((parsed as Dictionary).get("levels", []) as Array):
			if int((lv as Dictionary)["id"]) == num:
				mult = float((lv as Dictionary).get("speed_mult", 1.0))
	return 3.5 * mult * 1.2145


func _coins(placed: Dictionary) -> int:
	var n := 0
	for g in placed.get("gold", []):
		n += int(((g as Dictionary)["override"] as Dictionary).get("n", 0))
	return n


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.has_environment(key) else fallback
