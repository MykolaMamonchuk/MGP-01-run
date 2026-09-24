## Дослід чіпає РІВНО ТЕ, ЩО ЗАЯВЛЕНО — і нічого поруч.
##
## Навіщо окремий файл. Діагностика тричі за три дні давала хибний висновок, і щоразу тому,
## що мовчки міняла сусідню систему: вмикала шари, які світ сховав; стирала матеріал води
## будь-яким прапорцем; повертала тінь усупереч налаштуванню. Око цього не ловить — ловить
## тільки знімок усього стану до і після.
##
## Метод: переписуємо видимість і матеріали ВСЬОГО піддерева гри, застосовуємо один
## прапорець, і вимагаємо, щоб список змінених вузлів збігся з очікуваним рівно.
extends GutTest

var _run: Node = null


func before_each() -> void:
	SaveService.set_setting(Quality.KEY, Quality.SMOOTH)
	_run = load("res://src/run3d/run3d.tscn").instantiate()
	add_child_autofree(_run)
	await wait_frames(3)


## Знімок стану: для кожного Node3D — видимість, для кожного меша — ще й матеріал.
func _snapshot(n: Node, out: Dictionary) -> Dictionary:
	var s3 := n as Node3D
	if s3 != null:
		var mo: Variant = null
		var mi := n as GeometryInstance3D
		if mi != null:
			mo = mi.material_override
		out[n] = [s3.visible, mo]
	for c in n.get_children():
		_snapshot(c, out)
	return out


func _changed(flag: String) -> Array:
	var before := _snapshot(_run, {})
	_run.call("debug_strip", PackedStringArray([flag]))
	var after := _snapshot(_run, {})
	var diff: Array = []
	for k in before:
		if after.has(k) and after[k] != before[k]:
			diff.append(k)
	return diff


func test_roadbase_chipaie_lyshe_osnovu() -> void:
	var track: Node = _run.get_node("Track")
	# ОСНОВА ТЕПЕР СХОВАНА ЗА ЗАМОВЧУВАННЯМ (стиль «grid» — прибрана основа дає 4,9 мс), тож
	# прапорець на неї нічого б не змінив. Тест перевіряє ОБСЯГ прапорця, а не стан сцени,
	# тому вмикаємо стиль, у якому основа є. Без цього тест «проходив би на порожнечі».
	track.call("set_road_style", "base")
	await wait_frames(2)
	var expected: Array = (track.get("_mm_center") as Array).duplicate()
	var diff := _changed("roadbase")
	assert_eq(diff.size(), expected.size(),
		"прапорець «roadbase» має змінити рівно %d вузлів, а змінив %d" % [expected.size(), diff.size()])
	for n in diff:
		assert_true(expected.has(n), "змінено чужий вузол: %s" % n)


func test_roadtiles_chipaie_lyshe_plytku() -> void:
	var track: Node = _run.get_node("Track")
	var diff := _changed("roadtiles")
	assert_eq(diff.size(), 1, "прапорець «roadtiles» має змінити рівно один вузол")
	if diff.size() == 1:
		assert_eq(diff[0], track.get("_mm_surface"), "і це має бути плитка дороги")


## Порожній список не змінює НІЧОГО. Саме тут ховались усі три знайдені вади.
func test_porozhniy_doslid_nichogo_ne_minyaie() -> void:
	var before := _snapshot(_run, {})
	_run.call("debug_strip", PackedStringArray([]))
	var after := _snapshot(_run, {})
	var diff: Array = []
	for k in before:
		if after.has(k) and after[k] != before[k]:
			diff.append(k)
	assert_eq(diff.size(), 0, "порожній дослід змінив %d вузлів: %s" % [diff.size(), diff])


## МАТЕРІАЛИ ДЕКОРУ СПІЛЬНІ, А ШАРИ ЗАВОДЯТЬСЯ ЛІНИВО.
##
## Раніше «оригінал» матеріалу запам'ятовувався за НОМЕРОМ ШАРУ. Шар, створений уже під час
## досліду, брав за оригінал ВЖЕ ЗМІНЕНИЙ спільний матеріал — і після досліду повертав його
## в змінений стан. Наслідок заміряний: після послідовності unshaded → onemat → onetex →
## порожньо чотири шари з сорока п'яти лишались непідсвіченими, і це були шари стін. Контроль
## у пробі падав зі 175,7 до 133,1, тобто на 24%, і весь замір ішов у смітник.
##
## Тепер ключ — сам матеріал. Тест іде ТІЄЮ САМОЮ послідовністю, бо прямий перехід
## «unshaded → порожньо» ваду не показував: вона з'являлась лише після проміжних варіантів.
func test_materialy_vertaiutsia_pislia_poslidovnosti() -> void:
	_run.set("_demo_any_level", true)
	_run.call("_start_level", 1)
	await wait_frames(10)
	var mms: Array = _run.get_node("Track").get("_decor_mm")
	assert_gt(mms.size(), 10, "шари декору мають існувати, інакше сторож перевіряє порожнечу")
	var base := _modes(mms)
	for step in [["unshaded"], ["onemat"], ["onetex"], []]:
		_run.call("debug_strip", PackedStringArray(step))
		await wait_frames(2)
	assert_eq(_modes(mms), base,
		"після порожнього списку режим затінення мусить повернутись на ВСІХ шарах")


func _modes(mms: Array) -> Array:
	var out := []
	for mm in mms:
		var m = (mm as MultiMeshInstance3D).multimesh.mesh
		if m != null and m.get_surface_count() > 0:
			var bm = m.surface_get_material(0)
			if bm != null:
				out.append(bm.shading_mode)
	return out
