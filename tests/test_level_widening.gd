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
func _lanes_beyond(level: Dictionary, cut: float) -> Array:
	var lanes := {}
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
				var lane_at := block.find("lane = ")
				var tr_at := block.find("Transform3D(")
				if lane_at < 0 or tr_at < 0:
					continue
				var lane := int(block.substr(lane_at + 7, 4).strip_edges().split("\n")[0])
				var args := block.substr(tr_at + 12).split(")")[0].split(",")
				var z := absf(float(args[args.size() - 1])) + offset
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
		for lane in _lanes_within(level, soonest):
			assert_lte(absi(int(lane)), narrow,
				("рівень %d: смуга %d вжита ще до розширення (найраніше на %.0f м) — "
				+ "перешкода повисне за краєм вузької дороги") % [num, lane, soonest])


## Смуги перешкод, що стоять БЛИЖЧЕ за задану відстань.
func _lanes_within(level: Dictionary, cut: float) -> Array:
	var lanes := {}
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
				var lane_at := block.find("lane = ")
				var tr_at := block.find("Transform3D(")
				if lane_at < 0 or tr_at < 0:
					continue
				var lane := int(block.substr(lane_at + 7, 4).strip_edges().split("\n")[0])
				var args := block.substr(tr_at + 12).split(")")[0].split(",")
				if absf(float(args[args.size() - 1])) + offset < cut:
					lanes[lane] = true
	var out := lanes.keys()
	out.sort()
	return out


## Декор обабіч дороги мусить лишитись ЗА її краєм і після розширення. Маркери
## розставляли під вузьку дорогу (|x| ≈ 1,9–2,3 м, тобто на 0,4 м далі за край), а після
## розширення півширина дороги сама стає 2,5 або 3,5 — і дерева, пальми, парасолі та хмари
## опиняються просто на біговій смузі. Заміряно: 78 маркерів на три рівні.
##
## Орієнтири (арка через дорогу) сюди не входять навмисно: вони стоять по центру, і так і
## задумано — герой пробігає під ними.
func test_side_decor_stays_off_the_widened_road() -> void:
	var profiles := _json("res://data/profiles.json")
	var levels: Array = _json("res://data/levels.json").get("levels", [])
	for l in levels:
		var level: Dictionary = l
		if not level.has("lanes_to"):
			continue
		var num := int(level["id"])
		var half := (float(level["lanes_to"]) * 1.0 + 0.2) * 0.5   # road_width()/2
		var cut := _widen_distance(level, profiles) + MARGIN_M
		var inside := _side_decor_within(num, cut, half)
		assert_true(inside.is_empty(),
			("рівень %d: після розширення дорога сягає ±%.1f м, а на ній лишився декор: %s")
			% [num, half, inside])


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
		var lanes := _lanes_beyond(level, cut)
		assert_false(lanes.is_empty(),
			"рівень %d має перешкоди після розширення (%.0f м)" % [num, cut])
		if lanes.is_empty():
			continue
		assert_true(lanes.has(wide) and lanes.has(-wide),
			"рівень %d: після розширення вживаються й НОВІ крайні смуги ±%d, а не лише %s"
			% [num, wide, lanes])
	assert_gt(checked, 0, "рівні з розширенням у даних знайшлись")

## Бічний декор далі за cut, що опинився ближче до центру, ніж half. Маркери по центру
## (|x| < 0.3) пропускаємо — це орієнтири, вони над дорогою за задумом.
func _side_decor_within(num: int, cut: float, half: float) -> Array:
	var out := []
	var dir := DirAccess.open("res://levels/level_%02d" % num)
	if dir == null:
		return out
	for name in dir.get_files():
		if not name.ends_with(".tscn"):
			continue
		var f := FileAccess.open("res://levels/level_%02d/%s" % [num, name], FileAccess.READ)
		var text := f.get_as_text()
		# z маркера ЛОКАЛЬНА (від початку чанка); зсув — з імені файлу (сцена його не знає).
		var offset := LevelChunkLoader.offset_for(name)
		for block in text.split("[node "):
			# Godot НЕ пише властивість, що дорівнює типовій, тож у маркера декору рядка
			# role може не бути зовсім — саме так виглядає чанк, перезбережений редактором.
			# Шукати «role = "decor"» означає тихо пропустити половину маркерів.
			if block.contains("role = \"") and not block.contains("role = \"decor\""):
				continue
			if not block.contains("script = ExtResource"):
				continue
			var tr := block.find("Transform3D(")
			if tr < 0:
				continue
			var args := block.substr(tr + 12).split(")")[0].split(",")
			if args.size() < 12:
				continue
			var x := float(args[9])
			var z := absf(float(args[11])) + offset
			if z > cut and absf(x) > 0.3 and absf(x) < half:
				var kind_at := block.find("kind = \"")
				var kind := block.substr(kind_at + 8).split("\"")[0] if kind_at >= 0 else "?"
				out.append("%s на x=%.1f (z=%.0f)" % [kind, x, z])
	return out
