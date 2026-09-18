## Маркери чанка лежать у ТЕКАХ за роллю — і теки стоять рівно в нулі.
##
## Навіщо. Пласким списком під коренем маркери ще читалися, поки їх два десятки. Заморожений
## рівень дає ~900 маркерів на чанк, і в такому списку автор не знайде нічого. Тепер під
## коренем стоять вузли-теки («Декор», «Перешкоди», «Пікапи», «Будівлі», «Орієнтири»,
## «Стіни»), а маркери лежать у своїй. Розкладку робить tools/group_chunk_markers.py.
##
## Чим це небезпечно й що саме тут стережеться. LevelTimeline._append() бере z із
## marker.position — тобто з ЛОКАЛЬНОЇ позиції відносно БЕЗПОСЕРЕДНЬОГО батька, а трансформ
## теки він не читає взагалі. Доки тека стоїть у 0,0,0, це те саме число, що й раніше. Але
## варто комусь зсунути теку в редакторі (потягнути мишею, вирівняти «щоб було видно») — і
## весь її вміст поїде в редакторі, а в грі лишиться на місці. Помилка мовчазна: сцена
## виглядає інакше, ніж рівень. Тому тут два окремі сторожі: один каже, що екстракція теку
## ІГНОРУЄ (нижче, на зібраному вручну дереві), другий — що жодна тека в жодному з 105
## чанків не зсунута.
extends GutTest

## Ролі й імена їхніх тек — ті самі, що в tools/group_chunk_markers.py; ключі збігаються з
## LevelTimeline.ROLE_KEYS.
const FOLDERS := {
	"decor": "Декор",
	"obstacle": "Перешкоди",
	"pickup": "Пікапи",
	"building": "Будівлі",
	"landmark": "Орієнтири",
	"wall_near": "Стіни",
}


func _chunk_paths() -> Array:
	var out := []
	for num in range(1, 18):
		var dir := DirAccess.open("res://levels/level_%02d" % num)
		if dir == null:
			continue
		var names := []
		for name in dir.get_files():
			if name.ends_with(".tscn"):
				names.append(name)
		names.sort()
		for name in names:
			out.append("res://levels/level_%02d/%s" % [num, name])
	return out


func _text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""


## Значення атрибута заголовка вузла ("[node name=\"X\" ... parent=\"Y\"]" → X / Y).
func _attr(head: String, key: String) -> String:
	var at := head.find('%s="' % key)
	if at < 0:
		return ""
	return head.substr(at + key.length() + 2).split("\"")[0]


## Кожен маркер (блок зі script = ExtResource і parent=) мусить лежати в теці своєї ролі.
## Корінь скрипт теж має, але parent= в нього немає; у теки немає скрипта.
func test_every_marker_sits_in_the_folder_of_its_role() -> void:
	var wrong := []
	var markers := 0
	for path in _chunk_paths():
		for block in _text(path).split("[node "):
			var head := block.split("]")[0]
			var body := block.substr(head.length() + 1)
			if not body.contains("script = ExtResource") or not head.contains("parent="):
				continue
			markers += 1
			# Godot НЕ пише властивість, що дорівнює типовій, тож у маркера декору рядка
			# role може не бути зовсім — це той самий decor.
			var role := "decor"
			var role_at := body.find("role = \"")
			if role_at >= 0:
				role = body.substr(role_at + 8).split("\"")[0]
			var want := String(FOLDERS.get(role, ""))
			var parent := _attr(head, "parent")
			if want == "":
				wrong.append("%s: роль %s не має теки" % [path, role])
			elif parent != want:
				wrong.append("%s: %s (%s) лежить у «%s», а мав би у «%s»"
					% [path, _attr(head, "name"), role, parent, want])
	assert_gt(markers, 2000, "маркери в чанках знайшлись")
	assert_true(wrong.is_empty(), "маркери не в своїй теці: %s" % [wrong.slice(0, 5)])


## Теки — ГОЛІ Node3D просто під коренем: без скрипта, без transform і без порожніх.
## Порожня тека — це шум у дереві, який автор мусив би згортати руками.
func test_folders_are_bare_nodes_under_the_root_and_none_is_empty() -> void:
	var bad := []
	for path in _chunk_paths():
		var used := {}
		var declared := {}
		for block in _text(path).split("[node "):
			var head := block.split("]")[0]
			if not head.contains("parent="):
				continue
			var body := block.substr(head.length() + 1)
			var name := _attr(head, "name")
			if body.contains("script = ExtResource"):
				used[_attr(head, "parent")] = true
				continue
			if not FOLDERS.values().has(name):
				bad.append("%s: вузол «%s» без скрипта — це не маркер і не тека" % [path, name])
				continue
			declared[name] = true
			if _attr(head, "parent") != ".":
				bad.append("%s: тека «%s» не під коренем" % [path, name])
			if body.contains("transform = "):
				bad.append(("%s: тека «%s» має transform — її вміст поїде в редакторі, "
					+ "а в грі лишиться на місці") % [path, name])
		for name in declared.keys():
			if not used.has(name):
				bad.append("%s: тека «%s» порожня" % [path, name])
	assert_true(bad.is_empty(), "теки чанків не такі, як треба: %s" % [bad.slice(0, 5)])


## Той самий сторож, але не по тексту, а по СПРАВЖНЬОМУ дереву: між коренем і маркером не
## сміє стояти жодного зсуву. Саме цей тест почервонів би, якби теку посунули мишею в
## редакторі — текстовий сторож вище ловить лише дописаний рядок transform, а цей рахує
## трансформ, хоч би як він у сцену потрапив.
func test_no_folder_shifts_its_markers() -> void:
	var shifted := []
	var checked := 0
	for path in _chunk_paths():
		var packed := load(path) as PackedScene
		assert_not_null(packed, "чанк %s читається" % path)
		if packed == null:
			continue
		var root := packed.instantiate()
		for marker in _markers_of(root):
			checked += 1
			var extra := Transform3D.IDENTITY
			var node: Node = marker.get_parent()
			while node != null and node != root:
				extra = (node as Node3D).transform * extra
				node = node.get_parent()
			if not extra.is_equal_approx(Transform3D.IDENTITY):
				shifted.append("%s: %s зсунуто на %s" % [path, marker.name, extra.origin])
		root.free()
	assert_gt(checked, 2000, "маркери в зібраних чанках знайшлись")
	assert_true(shifted.is_empty(), "теки зсувають маркери: %s" % [shifted.slice(0, 5)])


func _markers_of(node: Node) -> Array:
	var out := []
	for child in node.get_children():
		if child is LevelMarker3D:
			out.append(child)
		out.append_array(_markers_of(child))
	return out


## LevelTimeline._collect() рекурсивний — але це треба перевірити, а не вірити. Число
## записів після групування мусить збігатися з числом маркерів у тексті чанка: якби обхід
## дивився лише на прямих дітей кореня, він побачив би самі теки, тобто НУЛЬ.
func test_extract_still_finds_every_marker_through_the_folders() -> void:
	var total_text := 0
	var total_extracted := 0
	for path in _chunk_paths():
		var in_text := 0
		for block in _text(path).split("[node "):
			var head := block.split("]")[0]
			var body := block.substr(head.length() + 1)
			if body.contains("script = ExtResource") and head.contains("parent="):
				in_text += 1
		var root := (load(path) as PackedScene).instantiate()
		var out := LevelTimeline.extract(root)
		root.free()
		var n := 0
		for key in out.keys():
			n += (out[key] as Array).size()
		assert_eq(n, in_text, "%s: зібрано %d маркерів із %d" % [path, n, in_text])
		total_text += in_text
		total_extracted += n
	assert_gt(total_text, 2000, "маркери знайшлись")
	assert_eq(total_extracted, total_text)


## Чому теку не можна зсувати — на пальцях. Тека з ненульовою позицією для екстракції
## НЕ ІСНУЄ: маркер віддає свою локальну z, і рівень у грі лишається на місці, тоді як у
## редакторі його вміст поїхав. Тест стереже саме цю поведінку — вона й робить перевірку
## «тека в нулі» обов'язковою.
func test_extract_ignores_the_folder_transform_which_is_why_folders_must_stay_at_zero() -> void:
	var root := Node3D.new()
	var folder := Node3D.new()
	folder.name = "Перешкоди"
	folder.position = Vector3(7.0, 0.0, -50.0)   # хтось потягнув теку мишею
	root.add_child(folder)
	var marker := LevelMarker3D.new()
	marker.role = "obstacle"
	marker.kind = "stump"
	marker.position = Vector3(0.0, 0.0, -10.0)
	folder.add_child(marker)
	var out := LevelTimeline.extract(autofree(root))
	var obstacles: Array = out["obstacles"]
	assert_eq(obstacles.size(), 1, "маркер знайдено й крізь теку")
	assert_almost_eq(float(obstacles[0]["z_m"]), 10.0, 0.0001,
		"зсув теки в гру не потрапляє — тому тека мусить стояти в нулі")
	assert_almost_eq(float(obstacles[0]["x_m"]), 0.0, 0.0001)
