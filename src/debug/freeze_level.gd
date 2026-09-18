## «Заморозити» рівень: записати все, що процедура поставила вздовж траси, у JSON.
##
##   LEVEL=1 OUT=/tmp/level_01.json \
##     /Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://src/debug/freeze_level.tscn
##
## СЦЕНА, а не `-s скрипт`: із `-s` Godot не вантажить автолоади, і track.gd не компілюється
## («Identifier not found: AudioMgr»). На це вже наступали з пробою.
##
## Навіщо. Процедура зручна, поки світу мало. Коли рівень доводять до ладу руками, вона
## заважає: того, що вона поставила, не видно в редакторі, не можна посунути й важко
## дебажити. Тому її результат один раз перетворюють на МАРКЕРИ СЦЕНИ
## (tools/freeze_level.py), після чого рівень правиться візуально, а процедура для нього
## вимикається полем "authored" у data/levels.json.
##
## Гру тут не запускаємо: створюємо саму Track і крутимо їй advance() метр за метром. Так
## швидше в десятки разів і не залежить від героя, камери та профілю.
extends Node


func _ready() -> void:
	var num := int(OS.get_environment("LEVEL")) if OS.has_environment("LEVEL") else 1
	var out := OS.get_environment("OUT") if OS.has_environment("OUT") else "level.json"

	var levels: Array = _json("res://data/levels.json").get("levels", [])
	var level := {}
	for l in levels:
		if int((l as Dictionary).get("id", 0)) == num:
			level = l
			break
	if level.is_empty():
		print("нема рівня %d" % num)
		get_tree().quit(1)
		return
	var world := _json("res://data/worlds/%s.json" % String(level.get("world", "meadow")))
	if world.is_empty():
		print("нема світу")
		get_tree().quit(1)
		return

	# Довжина: скільки метрів проходить НАЙШВИДША дитина, плюс запас на вікно рядів.
	var profiles := _json("res://data/profiles.json")
	var fastest := 0.0
	for key in profiles.keys():
		var p = profiles[key]
		if typeof(p) == TYPE_DICTIONARY and (p as Dictionary).has("speed"):
			fastest = maxf(fastest, float((p as Dictionary)["speed"]))
	var length := fastest * float(level.get("speed_mult", 1.0)) * float(level.get("duration_sec", 90.0)) * 1.2

	var track := Track.new()
	add_child(track)
	track.record_decor = true
	track.rebuild(world, false, {}, int(level.get("lanes", 3)))
	var travelled := 0.0
	while travelled < length:
		track.advance(1.0)
		travelled += 1.0

	# Один предмет міг потрапити в журнал двічі, якщо ряд переставили на ту саму ділянку.
	var seen := {}
	var records: Array = []
	for r in track.decor_log:
		var key := "%s|%.2f|%.2f" % [r["kind"], r["z_m"], r["x_m"]]
		if seen.has(key):
			continue
		seen[key] = true
		records.append(r)
	records.sort_custom(func(a, b): return float(a["z_m"]) < float(b["z_m"]))

	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"level": num, "length_m": length, "decor": records}, "\t"))
	f.close()
	print("рівень %d: записано %d предметів на %.0f м → %s" % [num, records.size(), length, out])
	get_tree().quit()


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
