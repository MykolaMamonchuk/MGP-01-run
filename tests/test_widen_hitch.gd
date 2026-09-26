## Ривок розширення дороги (рівень 4, 3 → 5 доріжок): 606 мс на Redmi 8A, 29 мс на Маку
## (docs/MEMORY.md, 26.09). Дві причини, два сторожі:
##  1. _decorate_authored перебирав на КОЖЕН ряд увесь накопичений таймлайн цеглинок (до
##     середини рівня 4 — 2460 записів), а set_lanes перекладав усі 44 ряди в одному кадрі;
##  2. навіть із двійковим пошуком 44 ряди разом — це ~5 мс на Маку, тобто ~100 мс на
##     телефоні, тож ряди перекладаються кожен у мить, коли рушає його ряд дороги.
extends GutTest

var _track: Track


func _world(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/worlds/%s.json" % name, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _make_track() -> Track:
	var t := Track.new()
	t.force_decor_cull(0.0)
	t.authored_only = true      # лише авторські записи — щоб рахувати їх без фонового оздоблення
	add_child_autofree(t)
	return t


func before_each() -> void:
	_track = _make_track()
	await wait_process_frames(2)


## Записи на кожні step метрів від 0 до count*step. Частина — точно на межах рядів
## (ряд i охоплює [i-5,5; i-4,5) при distance_m = 0), частина — дублікати тієї самої z.
func _records(count: int, step: float) -> Array:
	var out := []
	for i in range(count):
		out.append({"z_m": float(i) * step, "x_m": 3.5 if i % 2 == 0 else -3.5, "y_m": 0.0,
			"kind": "signpost", "lane": 0, "override": {}, "yaw_deg": 90.0, "scale": 1.0})
	return out


func _bridge(z: float, x: float) -> Dictionary:
	return {"z_m": z, "x_m": x, "y_m": 0.0, "kind": "bridge_plank", "lane": 0,
		"override": {}, "yaw_deg": 0.0, "scale": 1.0}


func test_riad_dyvytsia_lyshe_na_svoi_zapysy_a_ne_na_ves_taimlain() -> void:
	# 4000 записів на 400 м — як таймлайн кількох цеглинок, накопичений до середини рівня.
	_track.set_authored_timeline(_records(4000, 0.1), _records(400, 1.0))
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	_track.authored_visits = 0
	_track._decorate(_track._rows[10])
	# у вікні ряду (1 м) — ~10 записів декору й 1 будівля, плюс по одному, що зупиняє перегляд
	assert_lt(_track.authored_visits, 40,
		"ряд переглянув %d записів — перебір усього таймлайну (4400) повернувся" % _track.authored_visits)
	assert_gt(_track.authored_visits, 5, "і все ж щось переглянув — сторож не сліпий")


func test_vikno_riadu_bere_rivno_ti_zapysy_shcho_i_perebir() -> void:
	# Межі рядів — півцілі числа; кладемо записи і на них, і дублікати тієї самої z.
	var recs := []
	for z in [-5.5, -5.5, -5.0, -4.5, -4.5, -4.49, 0.0, 0.5, 0.5, 1.5, 10.0, 10.5, 37.49, 37.5, 38.5]:
		recs.append({"z_m": z, "x_m": 3.5, "y_m": 0.0, "kind": "signpost", "lane": 0,
			"override": {}, "yaw_deg": 90.0, "scale": 1.0})
	_track.set_authored_timeline(recs, [])
	_track.rebuild(_world("forest"), false)    # у Лісі каналу нема — жодних поручнів і містків
	await wait_process_frames(2)
	var total := 0
	for i in range(Track.ROWS):
		var lo: float = _track._row_distance_m[i] - 0.5
		var hi: float = _track._row_distance_m[i] + 0.5
		var want := 0
		for r in recs:
			if float(r["z_m"]) >= lo and float(r["z_m"]) < hi:
				want += 1
		assert_eq((_track._decor_ids[i] as PackedInt32Array).size(), want,
			"ряд %d [%.2f; %.2f): стільки ж записів, скільки дає перебір" % [i, lo, hi])
		total += want
	assert_gt(total, 10, "у вікно рядів потрапила більшість записів — перевірка не порожня")


func test_rozshyrennia_ne_perekladaie_vsi_riady_v_odnomu_kadri() -> void:
	var recs := _records(400, 0.1)
	for z in [3.0, 12.0, 25.0]:
		recs.append(_bridge(z, -2.0))
	_track.set_authored_timeline(recs, [])
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	_track.set_lanes(5, true)
	assert_gt(_track.redecorate_pending(), Track.ROWS - 4,
		"одразу після set_lanes ряди ЧЕКАЮТЬ своєї черги, а не перекладені всі разом")
	await wait_seconds(1.2)
	assert_eq(_track.redecorate_pending(), 0, "за ~0,5 с анімації перекладено всі ряди")


## Кінцевий вигляд той самий, що й від перекладання всіх рядів разом: порівнюємо з другою
## трасою, де ряди перекладено одразу під нову ширину.
func test_pislia_rozshyrennia_dekor_toi_samyi_shcho_i_vid_perekladannia_odrazu() -> void:
	var recs := _records(400, 0.1)
	for z in [3.0, 12.0, 25.0]:
		recs.append(_bridge(z, -2.0))
		recs.append(_bridge(z + 4.0, 2.0))
	var ref := _make_track()
	await wait_process_frames(2)
	for t in [_track, ref]:
		t.set_authored_timeline(recs.duplicate(true), [])
		t.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	var narrow_bridge_x := _bridge_xs(_track)
	_track.set_lanes(5, true)
	ref.set_lanes(5, false)
	for row in ref._rows:
		ref._decorate(row)
	await wait_seconds(1.2)
	for i in range(Track.ROWS):
		var a: PackedInt32Array = _track._decor_ids[i]
		var b: PackedInt32Array = ref._decor_ids[i]
		assert_eq(a.size(), b.size(), "ряд %d: стільки ж предметів" % i)
		if a.size() != b.size():
			continue
		var da: PackedFloat32Array = _track._decor_data[i]
		var db: PackedFloat32Array = ref._decor_data[i]
		for j in range(a.size()):
			assert_almost_eq(da[j * Track.DECOR_STRIDE], db[j * Track.DECOR_STRIDE], 0.0001,
				"ряд %d, предмет %d: те саме x" % [i, j])
	# містки стоять від краю дороги — отже, справді перекладені під нову ширину
	var wide_bridge_x := _bridge_xs(_track)
	assert_eq(wide_bridge_x.size(), narrow_bridge_x.size(), "містків стільки ж")
	assert_gt(wide_bridge_x.size(), 0, "містки в кадрі є — перевірка ширини не порожня")
	for j in range(wide_bridge_x.size()):
		assert_gt(absf(wide_bridge_x[j]), absf(narrow_bridge_x[j]) + 0.5,
			"місток %d відсунувся разом із краєм дороги" % j)


func _bridge_xs(t: Track) -> Array:
	var layers := {}
	for key in t._decor_layer_of.keys():
		if String(key).split("|")[0].split("#")[0] == "bridge_plank":
			layers[int(t._decor_layer_of[key])] = true
	var out := []
	for i in range(Track.ROWS):
		var ids: PackedInt32Array = t._decor_ids[i]
		for j in range(ids.size()):
			if layers.has(ids[j]):
				out.append(t._decor_data[i][j * Track.DECOR_STRIDE])
	out.sort()
	return out
