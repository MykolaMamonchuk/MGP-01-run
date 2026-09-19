## Темп рукотворних розкладок: чи встигає дитина між двома перешкодами.
##
## Чому це окремий сторож. Випадковий спавнер розставляє перешкоди В СЕКУНДАХ і по профілю
## віку: `Spawner3D._next_gap()` бере `profile.obstacle_interval` × `density` рівня. Для малого
## (`young`) це 3–5 с, для старшого (`older`) — 1.2–2.2 с. Авторський маркер так не вміє: він
## стоїть на своєму метрі й не знає ні профілю, ні швидкості. Вік частково рятує сам собою —
## малий біжить 2.8 м/с, старший 4.2, тож ті самі метри дають різний час, — але другої
## поправки, ту, що спавнер додає інтервалом, авторська розкладка не має зовсім.
##
## Тому поріг тут не вигаданий, а ВЗЯТИЙ У САМОЇ ГРИ: пара авторських перешкод не сміє стояти
## тісніше, ніж випадковий спавнер поставив би їх на цьому ж рівні для найшвидшого профілю.
## Порушення — це не «трохи складніше», а перешкода, якої дитина фізично не встигає побачити.
##
## Рахуємо по НАЙГІРШОМУ місцю рівня: найшвидший профіль, кінець рівня (швидкість росте
## 1 + 0.35 × прогрес) і спринт останніх 20% (×1.15).
extends GutTest

## Розгін швидкості до кінця рівня й спринт — обидва з src/run3d/run3d.gd (SPEED_RAMP і
## GATE_BEFORE_SEC/спринт ×1.15). Беремо максимум, а не середнє: сторож про найтісніше місце.
const RAMP_MAX := 1.35
const SPRINT := 1.15


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Найшвидший профіль і його НАЙКОРОТШИЙ інтервал між перешкодами — саме він задає поріг.
func _fastest_profile() -> Dictionary:
	var out := {"speed": 0.0, "interval": 0.0}
	for key in _json("res://data/profiles.json").keys():
		var p = _json("res://data/profiles.json")[key]
		if typeof(p) != TYPE_DICTIONARY or not (p as Dictionary).has("speed"):
			continue
		var d: Dictionary = p
		if float(d["speed"]) <= float(out["speed"]):
			continue
		var iv: Array = d.get("obstacle_interval", [2.0, 3.0])
		out = {"speed": float(d["speed"]), "interval": float(iv[0])}
	return out


## z_m усіх перешкод розкладки, за зростанням.
func _obstacle_z(scene_path: String) -> Array:
	var out: Array = []
	var f := FileAccess.open(scene_path, FileAccess.READ)
	if f == null:
		return out
	for block in f.get_as_text().split("[node "):
		if not block.contains("role = \"obstacle\""):
			continue
		var tr := block.find("Transform3D(")
		if tr < 0:
			continue
		var args := block.substr(tr + 12).split(")")[0].split(",")
		out.append(absf(float(args[args.size() - 1])))
	out.sort()
	return out


## Перевіряємо ВСІ ПАРИ «цеглинка × рівень її світу», складені тим самим pick_layout(), яким
## їх склав би збирач: розкладка, яку сьогодні ще ніхто не взяв, завтра стане чиєюсь, і темп
## у ній має бути перевірений заздалегідь, а не тоді, коли дитина на неї налетить.
func test_no_authored_pair_is_tighter_than_the_game_would_place_it() -> void:
	var library := ChunkLibrary.scan()
	assert_gt(library.size(), 0, "бібліотека цеглинок не порожня")
	var fastest := _fastest_profile()
	var levels: Array = _json("res://data/levels.json").get("levels", [])
	var checked := 0
	for id in library.keys():
		var entry: Dictionary = library[id]
		var desc: Dictionary = entry["desc"]
		var worlds: Array = desc.get("worlds", [])
		for l in levels:
			var level: Dictionary = l
			if not worlds.is_empty() and not worlds.has(String(level["world"])):
				continue
			var layout := ChunkDescriptor.pick_layout(
				desc, Difficulty.of(level), level.get("obstacle_types", []))
			if layout.is_empty():
				continue
			# Швидкість у найгіршому місці рівня й поріг, який дала б сама гра.
			var top_speed := float(fastest["speed"]) * float(level.get("speed_mult", 1.0)) \
				* RAMP_MAX * SPRINT
			var floor_m := maxf(2.5, float(fastest["interval"])
				* float(level.get("density", 1.0)) * top_speed)
			var zs := _obstacle_z("%s/%s" % [String(entry["dir"]), String(layout.get("file", ""))])
			for i in range(1, zs.size()):
				var gap := float(zs[i]) - float(zs[i - 1])
				checked += 1
				assert_gte(gap, floor_m,
					("цеглинка «%s», розкладка %s на рівні %d: між %.0f і %.0f м лише %.1f м, "
					+ "а гра на цьому рівні не ставить ближче за %.1f м (%.1f м/с на кінці) — "
					+ "дитина не встигне побачити другу перешкоду")
					% [id, layout.get("file", ""), int(level["id"]), zs[i - 1], zs[i], gap,
						floor_m, top_speed])
	assert_gt(checked, 0, "пари перешкод знайшлись — інакше сторож стереже порожнечу")


## Шов між цеглинками — місце, де темп рветься непомітно: кожна розкладка окремо виглядає
## рівною, а разом дають довгу порожнечу. Тут не про безпеку, а про нудьгу: 40 м без жодної
## перешкоди на рівні для малят — це кілька секунд, коли робити нема чого.
const SEAM_MAX_M := 40.0


func test_no_level_has_a_long_empty_stretch_at_a_seam() -> void:
	var levels: Array = _json("res://data/levels.json").get("levels", [])
	var checked := 0
	for l in levels:
		var level: Dictionary = l
		if (level.get("chunks", []) as Array).is_empty():
			continue
		var zs: Array = []
		for piece in LevelChunkLoader.plan_of(int(level["id"]), level):
			for scene_path in (piece as Dictionary)["paths"]:
				for z in _obstacle_z(String(scene_path)):
					zs.append(float(z) + float(piece["offset_m"]))
		zs.sort()
		assert_gt(zs.size(), 0, "рівень %d має перешкоди" % int(level["id"]))
		for i in range(1, zs.size()):
			checked += 1
			assert_lte(float(zs[i]) - float(zs[i - 1]), SEAM_MAX_M,
				"рівень %d: між %.0f і %.0f м жодної перешкоди"
				% [int(level["id"]), zs[i - 1], zs[i]])
	assert_gt(checked, 0, "є принаймні один рівень, зібраний із цеглинок")
