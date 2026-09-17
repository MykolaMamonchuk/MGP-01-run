## Рівні з фішкою «дорога розширюється» (4, 11, 16): чи нові смуги взагалі вживаються.
##
## Вада, заради якої цей файл існує: після розширення маркери перешкод і далі користувалися
## лише старим набором смуг. Заміряно: у нових крайніх смугах було НУЛЬ перешкод на всі три
## рівні. Дитина могла просто триматися скраю й до фінішу нікого не зустріти — тобто сама
## фішка рівня нічого не важила.
##
## Точку розширення гра рахує за ЧАСОМ (progress = level_t / level_duration, поріг lanes_at),
## а маркери стоять у МЕТРАХ — тож для швидкого й повільного профілю це різна відстань. Тут
## беремо НАЙПІЗНІШУ з профілів: далі за неї дорога вже широка для будь-якої дитини.
extends GutTest

## Запас за точкою розширення — той самий, що в tools/widen_level_lanes.py.
const MARGIN_M := 10.0


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Відстань, на якій дорога вже точно розширилась для БУДЬ-ЯКОГО профілю.
## Швидкість росте як speed × speed_mult × (1 + 0.35 × прогрес), тож пройдений шлях —
## v·D·(p + 0.175p²).
func _widen_distance(level: Dictionary, profiles: Dictionary) -> float:
	var at := float(level.get("lanes_at", 0.5))
	var dur := float(level.get("duration_sec", 90.0))
	var mult := float(level.get("speed_mult", 1.0))
	var best := 0.0
	for key in profiles.keys():
		var p = profiles[key]
		if typeof(p) != TYPE_DICTIONARY or not (p as Dictionary).has("speed"):
			continue
		var v := float((p as Dictionary)["speed"]) * mult
		best = maxf(best, v * dur * (at + 0.175 * at * at))
	return best


## Смуги перешкод рівня далі за задану відстань — читаємо .tscn як текст, бо LevelMarker3D
## живе у сценах, а не в даних.
func _lanes_beyond(num: int, cut: float) -> Array:
	var lanes := {}
	var dir := DirAccess.open("res://levels/level_%02d" % num)
	if dir == null:
		return []
	for name in dir.get_files():
		if not name.ends_with(".tscn"):
			continue
		var f := FileAccess.open("res://levels/level_%02d/%s" % [num, name], FileAccess.READ)
		var text := f.get_as_text()
		for block in text.split("[node "):
			if not block.contains("role = \"obstacle\""):
				continue
			var lane_at := block.find("lane = ")
			var tr_at := block.find("Transform3D(")
			if lane_at < 0 or tr_at < 0:
				continue
			var lane := int(block.substr(lane_at + 7, 4).strip_edges().split("\n")[0])
			var args := block.substr(tr_at + 12).split(")")[0].split(",")
			var z := absf(float(args[args.size() - 1]))
			if z > cut:
				lanes[lane] = true
	var out := lanes.keys()
	out.sort()
	return out


## Зворотний бік тієї самої вади й важливіший за неї: перешкода в НОВІЙ смузі не сміє
## з'явитись, доки дорога ще вузька — вона повисне за краєм. Точку розширення гра рахує за
## часом, тож для повільної дитини це НАЙРАНІША з профілів відстань — її й перевіряємо.
func test_no_obstacle_uses_a_wide_lane_before_the_road_widens() -> void:
	var profiles := _json("res://data/profiles.json")
	var levels: Array = _json("res://data/levels.json").get("levels", [])
	for l in levels:
		var level: Dictionary = l
		if not level.has("lanes_to"):
			continue
		var num := int(level["id"])
		var narrow: int = int(level["lanes"]) / 2
		var at := float(level.get("lanes_at", 0.5))
		var dur := float(level.get("duration_sec", 90.0))
		var mult := float(level.get("speed_mult", 1.0))
		# найРАНІША відстань розширення — найповільніший профіль
		var soonest := INF
		for key in profiles.keys():
			var p = profiles[key]
			if typeof(p) != TYPE_DICTIONARY or not (p as Dictionary).has("speed"):
				continue
			var v := float((p as Dictionary)["speed"]) * mult
			soonest = minf(soonest, v * dur * (at + 0.175 * at * at))
		for lane in _lanes_within(num, soonest):
			assert_lte(absi(int(lane)), narrow,
				("рівень %d: смуга %d вжита ще до розширення (найраніше на %.0f м) — "
				+ "перешкода повисне за краєм вузької дороги") % [num, lane, soonest])


## Смуги перешкод, що стоять БЛИЖЧЕ за задану відстань.
func _lanes_within(num: int, cut: float) -> Array:
	var lanes := {}
	var dir := DirAccess.open("res://levels/level_%02d" % num)
	if dir == null:
		return []
	for name in dir.get_files():
		if not name.ends_with(".tscn"):
			continue
		var f := FileAccess.open("res://levels/level_%02d/%s" % [num, name], FileAccess.READ)
		for block in f.get_as_text().split("[node "):
			if not block.contains("role = \"obstacle\""):
				continue
			var lane_at := block.find("lane = ")
			var tr_at := block.find("Transform3D(")
			if lane_at < 0 or tr_at < 0:
				continue
			var lane := int(block.substr(lane_at + 7, 4).strip_edges().split("\n")[0])
			var args := block.substr(tr_at + 12).split(")")[0].split(",")
			if absf(float(args[args.size() - 1])) < cut:
				lanes[lane] = true
	var out := lanes.keys()
	out.sort()
	return out


func test_widened_levels_use_their_new_outer_lanes() -> void:
	var profiles := _json("res://data/profiles.json")
	var levels: Array = _json("res://data/levels.json").get("levels", [])
	var checked := 0
	for l in levels:
		var level: Dictionary = l
		if not level.has("lanes_to"):
			continue
		checked += 1
		var num := int(level["id"])
		var wide: int = int(level["lanes_to"]) / 2
		var cut := _widen_distance(level, profiles) + MARGIN_M
		var lanes := _lanes_beyond(num, cut)
		assert_false(lanes.is_empty(),
			"рівень %d має перешкоди після розширення (%.0f м)" % [num, cut])
		if lanes.is_empty():
			continue
		assert_true(lanes.has(wide) and lanes.has(-wide),
			"рівень %d: після розширення вживаються й НОВІ крайні смуги ±%d, а не лише %s"
			% [num, wide, lanes])
	assert_gt(checked, 0, "рівні з розширенням у даних знайшлись")
