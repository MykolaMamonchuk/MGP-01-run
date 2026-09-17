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


func _kinds_of(num: int) -> Dictionary:
	var out := {}
	var dir := DirAccess.open("res://levels/level_%02d" % num)
	if dir == null:
		return out
	for name in dir.get_files():
		if not name.ends_with(".tscn"):
			continue
		var f := FileAccess.open("res://levels/level_%02d/%s" % [num, name], FileAccess.READ)
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
		var used := _kinds_of(num)
		for kind in used.keys():
			if not allowed.has(kind):
				extra.append("%s×%d" % [kind, used[kind]])
		extra.sort()
		assert_true(extra.is_empty(),
			("рівень %d дозволяє тільки %s, а в маркерах ще й: %s")
			% [num, allowed, extra])
