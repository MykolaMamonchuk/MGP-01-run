## Кожен маркер у чанках мусить мати що показати в редакторі.
##
## Навіщо. Автор рівнів відкрив чанк і побачив порожню сцену. Дві причини, обидві полагоджені:
## маркери лежали в абсолютних метрах (chunk_05 стояв за 750 м від початку координат), і
## прев'ю малювалось лише для вокселів — а більшість пропсів уже .glb, тож вони не малювались
## узагалі. Тепер LevelMarker3D бере модель із PropLibrary, потім воксель, а якщо нема нічого —
## кольорову коробку за роллю, щоб маркер було ВИДНО як помилку, а не як порожнечу.
##
## Цей тест стереже дані, а не малювання: він каже, які kind у рівнях не мають ні моделі, ні
## вокселя. Такий маркер у грі теж нічого не намалює — тобто це справжня діра в рівні.
extends GutTest


## Усі kind, що трапляються в чанках усіх рівнів, разом зі списком файлів, де вони стоять.
func _kinds_in_levels() -> Dictionary:
	var out := {}
	for num in range(1, 18):
		var dir := DirAccess.open("res://levels/level_%02d" % num)
		if dir == null:
			continue
		for name in dir.get_files():
			if not name.ends_with(".tscn"):
				continue
			var f := FileAccess.open("res://levels/level_%02d/%s" % [num, name], FileAccess.READ)
			for block in f.get_as_text().split("[node "):
				var at := block.find("kind = \"")
				if at < 0:
					continue
				var kind := block.substr(at + 8).split("\"")[0]
				if kind == "":
					continue
				var role_at := block.find("role = \"")
				var role := block.substr(role_at + 8).split("\"")[0] if role_at >= 0 else "decor"
				# Ключ — «роль|вид»: перешкода бере модель інакше, ніж декор із тим самим ім'ям.
				var key := "%s|%s" % [role, kind]
				if not out.has(key):
					out[key] = []
				var where := "level_%02d/%s" % [num, name]
				if not (out[key] as Array).has(where):
					(out[key] as Array).append(where)
	return out


func test_every_kind_used_in_levels_has_a_model_or_a_voxel() -> void:
	var kinds := _kinds_in_levels()
	assert_gt(kinds.size(), 0, "види в рівнях знайшлись")
	var missing := []
	for entry in kinds.keys():
		var parts: Array = String(entry).split("|")
		var model := LevelMarker3D.model_kind(String(parts[0]), String(parts[1]))
		if PropLibrary.has(model):
			continue
		if FileAccess.file_exists("res://data/voxels/%s.json" % model):
			continue
		missing.append("%s → %s (у %s)" % [parts[1], model, (kinds[entry] as Array)[0]])
	missing.sort()
	assert_true(missing.is_empty(),
		"види без моделі й без вокселя — у грі й у редакторі вони не намалюються: %s" % [missing])


## Локальні координати: жоден маркер не має стояти далі за довжину чанка від його початку.
## Якби міграція tools/localize_chunk_z.py десь схибила, саме це й було б видно.
func test_marker_z_stays_inside_its_chunk() -> void:
	var checked := 0
	for num in range(1, 18):
		var dir := DirAccess.open("res://levels/level_%02d" % num)
		if dir == null:
			continue
		for name in dir.get_files():
			if not name.ends_with(".tscn"):
				continue
			var f := FileAccess.open("res://levels/level_%02d/%s" % [num, name], FileAccess.READ)
			var text := f.get_as_text()
			for block in text.split("[node "):
				var tr := block.find("Transform3D(")
				if tr < 0:
					continue
				var args := block.substr(tr + 12).split(")")[0].split(",")
				var z := absf(float(args[args.size() - 1]))
				checked += 1
				assert_lte(z, LevelChunkLoader.CHUNK_LENGTH_M,
					"level_%02d/%s: маркер на локальній z=%.1f — це вже поза власним чанком"
						% [num, name, z])
	assert_gt(checked, 0, "маркери знайшлись")


## Те саме, але через справжній код прев'ю: жоден вид, що трапляється в рівнях, не має
## показувати заглушку. Перевіряємо по РІЗНИХ парах «роль|вид», а не по кожному маркеру —
## їх у 105 чанках понад тисяча, а різних видів кілька десятків.
func test_no_marker_in_levels_falls_back_to_a_placeholder() -> void:
	var fell_back := []
	for entry in _kinds_in_levels().keys():
		var parts: Array = String(entry).split("|")
		var marker := LevelMarker3D.new()
		marker.role = String(parts[0])
		marker.kind = String(parts[1])
		var node := marker._preview_node()
		var mi := node as MeshInstance3D
		var is_placeholder := mi != null and mi.mesh is BoxMesh \
			and (mi.mesh as BoxMesh).size.is_equal_approx(Vector3(0.5, 0.5, 0.5))
		if is_placeholder:
			fell_back.append(String(entry))
		node.free()
		marker.free()
	fell_back.sort()
	assert_true(fell_back.is_empty(),
		"ці маркери намалюються кольоровою заглушкою замість моделі: %s" % [fell_back])


## Маркер, що каже ДІЮ замість виду, теж мусить щось показувати: автор розставляє його оком,
## і невидимий маркер читається як «тут порожньо» — це брехня (docs/MEMORY.md).
func test_action_marker_shows_a_real_obstacle_not_a_placeholder() -> void:
	for action in ["jump", "duck", "side"]:
		var marker := LevelMarker3D.new()
		marker.role = "obstacle"
		marker.action = action
		var sample := LevelMarker3D.sample_kind_for_action(action)
		assert_ne(sample, "", "для дії «%s» знайшовся представник" % action)
		var node := marker._preview_node()
		var mi := node as MeshInstance3D
		var is_placeholder := mi != null and mi.mesh is BoxMesh \
			and (mi.mesh as BoxMesh).size.is_equal_approx(Vector3(0.5, 0.5, 0.5))
		assert_false(is_placeholder,
			"маркер дії «%s» намалювався заглушкою замість перешкоди «%s»" % [action, sample])
		node.free()
		marker.free()
