## «Заморозити» ОЗДОБЛЕННЯ ЦЕГЛИНКИ: записати в JSON усе, що процедурний декоратор поставив
## би на її 150 метрах у заданому світі.
##
##   CHUNK=meadow_village WORLD=meadow OUT=/tmp/dress.json \
##     /Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://src/debug/freeze_chunk.tscn
##
## Навіщо саме ЦЕГЛИНКА, а не рівень (як у freeze_level.gd). Процедура не просто незручна —
## вона НЕСТАЛА: заміряно 19.09.2026 на рівні 2, два прогони з різними зернами дали 3042 і
## 3018 предметів, із яких однакових лише 868. Найгірше з будинками (house_small 21↔30,
## house_teal 32↔24) і містками (104↔98), бо вони йдуть лічильниками _far_left/_bridge_left,
## тобто залежать від історії прогону, а не від місця.
##
## Заморожування в РІВЕНЬ цього не вилікує, бо рівень тепер складається з цеглинок, і та сама
## цеглинка стоїть на різних метрах різних рівнів. Заморожувати треба її власні метри — тоді
## вона виглядає однаково скрізь, де стоїть, і це саме те, чого просив замовник.
##
## Зерно СТАЛЕ, але СВОЄ для кожної цеглинки — від її id. Перша версія брала одне число на
## всіх, і всі цеглинки Лужка дістали однакові 883 маркери: рівень читався б як повтор тих
## самих 150 метрів. Стале — щоб перегенерування не переставляло все наново; своє — щоб
## цеглинки не були близнюками.
##
## Того ж вимагає і ПОЧАТКОВИЙ МЕТР: ряди сіються від «світ + відстань», тож дві цеглинки,
## заморожені з нуля, дістали б той самий дрібний декор навіть за різного зерна.
##
## СЦЕНА, а не `-s скрипт`: із `-s` Godot не вантажить автолоади й track.gd не компілюється.
extends Node

## Зерно для заморожування. Число саме по собі нічого не значить — важливо, що воно СТАЛЕ.
const FREEZE_SEED := 20260919
## Скільки метрів прокрутити понад довжину цеглинки: декоратор кладе предмети у вікні рядів
## попереду, тож без запасу останні метри лишились би порожніми.
const TAIL_M := 60.0


func _ready() -> void:
	var chunk := OS.get_environment("CHUNK")
	var out := OS.get_environment("OUT") if OS.has_environment("OUT") else "dress.json"
	if chunk == "":
		print("треба CHUNK=<id>")
		get_tree().quit(1)
		return
	var desc := _json("res://levels/chunks/%s/chunk.json" % chunk)
	if desc.is_empty():
		print("нема опису цеглинки %s" % chunk)
		get_tree().quit(1)
		return
	var worlds: Array = desc.get("worlds", [])
	var world_id := OS.get_environment("WORLD")
	if world_id == "":
		world_id = String(worlds[0]) if not worlds.is_empty() else "meadow"
	var world := _json("res://data/worlds/%s.json" % world_id)
	if world.is_empty():
		print("нема світу %s" % world_id)
		get_tree().quit(1)
		return

	var length := float(desc.get("length_m", 150.0))
	var lanes := int(desc.get("entry_lanes", 3))
	# Сідати треба НЕ на глобальний генератор, а на той, яким користується сама траса: вона
	# бере власний RandomNumberGenerator через RngSeed, а той дивиться на GAME_SEED. Перша
	# версія цього інструмента сіяла глобальний, і два прогони давали 861 і 867 предметів.
	var own := FREEZE_SEED + absi(hash(chunk)) % 100000
	OS.set_environment(RngSeed.ENV, str(own))
	seed(own)
	# Свій початковий метр — із того самого хешу, кратний ROW_DEPTH, щоб ряди лягли рівно.
	var start := float((absi(hash(chunk)) % 400) * 3)

	var track := Track.new()
	add_child(track)
	track.record_decor = true
	track.rebuild(world, false, {}, lanes)
	var travelled := 0.0
	while travelled < start + length + TAIL_M:
		track.advance(1.0)
		travelled += 1.0

	# Один предмет міг потрапити в журнал двічі, якщо ряд переставили на ту саму ділянку.
	var seen := {}
	var records: Array = []
	for r in track.decor_log:
		var z := float(r["z_m"]) - start
		if z < 0.0 or z >= length:
			continue          # беремо лише власне вікно цеглинки; хвіст — щоб декоратор устиг
		var key := "%s|%.2f|%.2f" % [r["kind"], z, r["x_m"]]
		if seen.has(key):
			continue
		seen[key] = true
		var rec: Dictionary = (r as Dictionary).duplicate()
		rec["z_m"] = z        # метри стають ЛОКАЛЬНИМИ, від початку цеглинки
		records.append(rec)
	records.sort_custom(func(a, b): return float(a["z_m"]) < float(b["z_m"]))

	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"chunk": chunk, "world": world_id, "lanes": lanes,
		"length_m": length, "decor": records}, "\t"))
	f.close()
	print("цеглинка %s (%s, %d доріжок, від %.0f м): %d предметів на %.0f м → %s"
		% [chunk, world_id, lanes, start, records.size(), length, out])
	get_tree().quit()


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
