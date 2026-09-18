## Кожен рівень кидає лише ті перешкоди, які сам дозволив.
##
## У data/levels.json є поле obstacle_types — воно й задає криву навчання: перший рівень
## тільки пеньок і калюжа, другий додає гілку, третій кущ і ящик, і так далі. Поле живе
## лише для ВИПАДКОВОГО спавнера (Spawner3D._allowed_kinds), а рівні з авторськими
## маркерами його оминають: _spawn_authored_obstacle() питає тільки, чи є такий вид у світі.
##
## Тож зламати це можна мовчки — жоден інший тест на маркери не дивиться. І один раз уже
## було зламано: рівень 1 (туторіал «лапка показує стрибок», дозволено stump і puddle)
## насправді кидав корів, вози, вулики, білизну й ящики — 21 зайва перешкода з 27.
extends GutTest


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _kinds_of(level: Dictionary) -> Dictionary:
	var out := {}
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
				var at := block.find("kind = \"")
				if at < 0:
					continue
				var kind := block.substr(at + 8).split("\"")[0]
				out[kind] = int(out.get(kind, 0)) + 1
	return out


func test_authored_obstacles_respect_the_levels_own_type_list() -> void:
	var levels: Array = _json("res://data/levels.json").get("levels", [])
	for l in levels:
		var level: Dictionary = l
		var allowed: Array = level.get("obstacle_types", [])
		if allowed.is_empty():
			continue        # порожній список = усі види біому, обмежень нема
		var num := int(level["id"])
		var extra := []
		var used := _kinds_of(level)
		# Сторож стереже порожнечу («зайвих видів нема»), тож мусить довести, що взагалі щось
		# бачив: план, який зненацька став порожнім, інакше зробив би його вічнозеленим.
		assert_false(used.is_empty(), "рівень %d: маркери-перешкоди знайдено" % num)
		for kind in used.keys():
			if not allowed.has(kind):
				extra.append("%s×%d" % [kind, used[kind]])
		extra.sort()
		assert_true(extra.is_empty(),
			("рівень %d дозволяє тільки %s, а в маркерах ще й: %s")
			% [num, allowed, extra])


## Маркер-ДІЯ («тут перестрибнути») моделі не називає — її добирає світ із того, що рівень
## дозволив. Тому дія, під яку в цьому рівні нема жодного дозволеного виду, не падає й нічого
## не ламає: Spawner3D просто пропускає запис. На трасі це діра в розкладці, і зрозуміти її
## причину, дивлячись на гру, майже неможливо.
##
## Перевіряємо не самі чанки й не самі рівні, а ВСІ ПАРИ, які правила дозволяють скласти:
## цеглинка × рівень її світу. Саме тому, що рівень 1 сьогодні бере легку розкладку на видах,
## а важкої на діях не бере ніхто: чекати, доки хтось її візьме, означало б мати сторожа, який
## нічого не стереже. Пару складаємо тим самим pick_layout(), яким її склав би збирач, — тож
## і поріг складності тут справжній, а не переписаний.
##
## xbox і транспорт виключені тими самими правилами, що й у Spawner3D._kind_for_action():
## X-ящик кидає лише сорока, а «vehicle» — це кузов із рампою, а не перешкода.
func _actions_in(scene_path: String) -> Array:
	var out := {}
	var f := FileAccess.open(scene_path, FileAccess.READ)
	if f == null:
		return []
	for block in f.get_as_text().split("[node "):
		if not block.contains("role = \"obstacle\""):
			continue
		var at := block.find("action = \"")
		if at < 0:
			continue
		var action := block.substr(at + 10).split("\"")[0]
		if action != "":
			out[action] = true
	return out.keys()


## Види світу, які рівень дозволяє і які взагалі можуть стати авторською перешкодою.
func _spawnable_kinds(level: Dictionary) -> Dictionary:
	var world := _json("res://data/worlds/%s.json" % String(level["world"]))
	var defs: Dictionary = world.get("obstacles", {})
	var allowed: Array = level.get("obstacle_types", [])
	var out := {}
	for kind in defs.keys():
		var d: Dictionary = defs[kind]
		if String(kind) == "xbox" or String(d.get("shape", "")) == "vehicle":
			continue
		if not allowed.is_empty() and not allowed.has(kind):
			continue
		out[kind] = String(d.get("action", ""))
	return out


func test_every_layout_action_has_a_kind_in_every_level_that_could_take_it() -> void:
	var library := ChunkLibrary.scan()
	assert_gt(library.size(), 0, "бібліотека цеглинок не порожня")
	var levels: Array = _json("res://data/levels.json").get("levels", [])
	var pairs := 0
	var with_actions := 0
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
			pairs += 1
			var scene_path := "%s/%s" % [String(entry["dir"]), String(layout.get("file", ""))]
			var actions := _actions_in(scene_path)
			if actions.is_empty():
				continue
			with_actions += 1
			var kinds := _spawnable_kinds(level)
			for action in actions:
				var fits := []
				for kind in kinds.keys():
					if kinds[kind] == String(action):
						fits.append(kind)
				assert_false(fits.is_empty(),
					("цеглинка «%s» на рівні %d (%s): розкладка %s просить дію «%s», але жодна "
					+ "дозволена перешкода світу її не вміє — Spawner3D мовчки пропустить ці "
					+ "записи, і на трасі буде діра")
					% [id, int(level["id"]), String(level["world"]),
						layout.get("file", ""), action])
	assert_gt(pairs, 0, "хоч одна пара «цеглинка × рівень» склалась")
	assert_gt(with_actions, 0, "і хоч одна з них бере розкладку на ДІЯХ — інакше цей тест "
		+ "стереже порожнечу")
