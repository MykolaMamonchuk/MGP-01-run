## Рівні (data/levels.json), LevelManager (чисті функції), мапа, камера під ширину дороги.
extends GutTest

const RunScript := preload("res://src/run3d/run3d.gd")

var _levels: Array = []
var _worlds: Dictionary = {}


func before_each() -> void:
	_levels = LevelManager.load_levels()
	_worlds = RunScript.load_worlds()


func test_seventeen_levels_with_valid_worlds_and_lanes() -> void:
	assert_eq(_levels.size(), 17, "GDD §3a: 17 рівнів")
	var ids := []
	for l in _levels:
		ids.append(int(l["id"]))
		assert_true(_worlds.has(String(l.get("world", ""))), "рівень %d: біом існує" % int(l["id"]))
		assert_true(int(l.get("lanes", 0)) in [3, 5, 7], "рівень %d: доріжок 3/5/7" % int(l["id"]))
		if l.has("lanes_to"):
			assert_true(int(l["lanes_to"]) in [5, 7], "рівень %d: lanes_to 5/7" % int(l["id"]))
			assert_gt(int(l["lanes_to"]), int(l["lanes"]), "рівень %d: дорога лише розширюється" % int(l["id"]))
		assert_gt(float(l.get("duration_sec", 0)), 60.0, "рівень %d: ≥ 60 с" % int(l["id"]))
		for t in l.get("obstacle_types", []):
			assert_true((_worlds[l["world"]]["obstacles"] as Dictionary).has(t), "рівень %d: перешкода %s є в біомі" % [int(l["id"]), t])
	ids.sort()
	assert_eq(ids, range(1, 18), "id 1..17 без дірок")


func test_first_level_is_easy_and_tutorial() -> void:
	var l: Dictionary = _levels[0]
	assert_eq(int(l["lanes"]), 3)
	assert_true(bool(l.get("tutorial", false)), "рівень 1 — з лапкою-підказкою")
	assert_almost_eq(float(l["speed_mult"]), 1.0, 0.001)


func test_difficulty_grows_within_each_world() -> void:
	var prev_world := ""
	var prev_mult := 0.0
	for l in _levels:
		var w := String(l["world"])
		if w == prev_world:
			assert_gte(float(l["speed_mult"]), prev_mult, "рівень %d: швидкість не падає всередині біому" % int(l["id"]))
		prev_world = w
		prev_mult = float(l["speed_mult"])


func test_stars_rules() -> void:
	assert_eq(LevelManager.stars_for(0, 40, 5), 1, "дійшов — завжди 1")
	assert_eq(LevelManager.stars_for(24, 40, 3), 2, "60% — 2")
	assert_eq(LevelManager.stars_for(36, 40, 3), 3, "90% — 3")
	assert_eq(LevelManager.stars_for(5, 40, 0), 3, "без падінь — 3")
	assert_eq(LevelManager.stars_for(0, 0, 2), 1, "без зірочок на рівні — 1")


func test_lanes_for_profile_cap_and_progress() -> void:
	var lvl := {"lanes": 5, "lanes_to": 7, "lanes_at": 0.5}
	assert_eq(LevelManager.lanes_for(lvl, {}, 0.0), 5)
	assert_eq(LevelManager.lanes_for(lvl, {}, 0.6), 7, "після половини — ширше")
	assert_eq(LevelManager.lanes_for(lvl, {"max_lanes": 5}, 0.9), 5, "young не ширше 5 (GDD §2)")
	assert_eq(LevelManager.lanes_for({"lanes": 1}, {}, 0.0), 3, "не менше 3")


func test_unlocked_max() -> void:
	assert_eq(LevelManager.unlocked_max({}, 17), 1)
	assert_eq(LevelManager.unlocked_max({"1": 2, "2": 1}, 17), 3)
	assert_eq(LevelManager.unlocked_max({"17": 3}, 17), 17, "далі 17 не буває")
	assert_eq(LevelManager.unlocked_max({"3": 0}, 17), 1, "0 зірок — не пройдено")


func test_islands_group_consecutive_worlds() -> void:
	var lm := LevelManager.new()
	var isl := lm.islands()
	assert_eq(isl.size(), 5, "5 островів")
	assert_eq(isl[0]["world"], "meadow")
	assert_eq(int(isl[0]["from"]), 1)
	assert_eq(int(isl[-1]["to"]), 17)


func test_map_positions_inside_screen() -> void:
	var pts := MapScreen.node_positions(17, Vector2(1280, 720))
	assert_eq(pts.size(), 17)
	for p in pts:
		assert_between(p.x, 60.0, 1220.0)
		assert_between(p.y, 60.0, 660.0)
	assert_lt(pts[0].x, pts[16].x, "стежинка іде зліва направо")


# ---------- 0.7.0: ціни рівнів (GDD v1.3 §3a), стан вузла, написи островів без накладань ----------

func test_prices_present_monotonic_and_first_free() -> void:
	var prices := []
	for l in _levels:
		assert_true(l.has("price"), "рівень %d: є price" % int(l["id"]))
		prices.append(int(l.get("price", -1)))
	assert_eq(prices.size(), 17)
	assert_eq(prices[0], 0, "рівень 1 — безплатний")
	for i in range(1, prices.size()):
		assert_gt(prices[i], prices[i - 1], "рівень %d: ціна росте" % (i + 1))
	assert_eq(prices, [0, 50, 80, 120, 160, 200, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 800], "таблиця цін GDD v1.3 §3a")


func test_price_table_is_affordable() -> void:
	var lm := LevelManager.new()
	var prices := lm.prices()
	# перший острів (рівні 1–4) — за один-три пробіги при середньому заробітку 150
	assert_true(LevelManager.price_table_is_affordable(prices.slice(0, 4), 150), "Лужок: кожен рівень ≤ 3 × 150")
	# усі 17 рівнів — при середньому заробітку 300 (довші рівні, колесо, завдання)
	assert_true(LevelManager.price_table_is_affordable(prices, 300), "уся таблиця ≤ 3 × 300")
	assert_false(LevelManager.price_table_is_affordable([1000], 150), "1000 > 3 × 150")
	assert_true(LevelManager.price_table_is_affordable([], 1), "порожня таблиця — по кишені")
	assert_eq(lm.price_of(1), 0)
	assert_eq(lm.price_of(17), 800)
	assert_eq(lm.price_of(99), 0, "нема рівня — 0")


func test_open_state_cases() -> void:
	assert_eq(LevelManager.open_state(1, {}, []), "open", "рівень 1 завжди відкритий")
	assert_eq(LevelManager.open_state(2, {}, []), "locked", "рівень 1 не пройдено — 2 замкнений")
	assert_eq(LevelManager.open_state(2, {"1": 1}, []), "buyable", "рівень 1 пройдено, 2 не куплено — купується")
	assert_eq(LevelManager.open_state(2, {"1": 1}, [2]), "open", "куплено й попередній пройдено — відкритий")
	assert_eq(LevelManager.open_state(2, {"1": 1}, [2.0]), "open", "число зі збереження може бути float")
	assert_eq(LevelManager.open_state(3, {"1": 3}, [2, 3]), "locked", "рівень 2 не пройдено — 3 замкнений навіть якщо куплений")
	assert_eq(LevelManager.open_state(3, {"1": 3, "2": 0}, [2]), "locked", "0 зірок — не пройдено")


func test_unlocked_open_is_highest_playable() -> void:
	assert_eq(LevelManager.unlocked_open({}, [], 17), 1)
	assert_eq(LevelManager.unlocked_open({"1": 2}, [], 17), 1, "пройдено, але не куплено — грати можна лише 1")
	assert_eq(LevelManager.unlocked_open({"1": 2}, [2], 17), 2)
	assert_eq(LevelManager.unlocked_open({"1": 2, "2": 1}, [2], 17), 2, "3 не куплено")
	assert_eq(LevelManager.unlocked_open({"1": 2, "2": 1}, [2, 3], 17), 3)
	assert_eq(LevelManager.unlocked_open({"1": 1}, [3], 17), 1, "куплений 3 без 2 — не рахується")


func test_place_labels_no_overlap_on_17_nodes() -> void:
	var size := Vector2(1280, 720)
	var pts := MapScreen.node_positions(17, size)
	var lm := LevelManager.new()
	var centers := []
	for isl in lm.islands():
		var c := Vector2.ZERO
		var k := 0
		for i in range(int(isl["from"]) - 1, int(isl["to"])):
			c += pts[i]
			k += 1
		centers.append(c / float(k))
	var tops := MapScreen.place_labels(centers, pts, size)
	assert_eq(tops.size(), 5, "по напису на острів")
	var rects: Array[Rect2] = []
	for top in tops:
		rects.append(Rect2(top, Vector2(MapScreen.LABEL_W, MapScreen.LABEL_H)))
	for a in range(rects.size()):
		assert_between(rects[a].position.x, 0.0, size.x - MapScreen.LABEL_W, "напис %d у межах екрана по x" % a)
		for b in range(a + 1, rects.size()):
			assert_false(rects[a].intersects(rects[b]), "написи %d і %d не накладаються" % [a, b])
		for p in pts:
			var q := Vector2(clampf(p.x, rects[a].position.x, rects[a].end.x), clampf(p.y, rects[a].position.y, rects[a].end.y))
			assert_gte(q.distance_to(p), MapScreen.NODE_R, "напис %d не лягає на вузол %s" % [a, str(p)])


func test_place_labels_shifts_up_when_overlapping() -> void:
	var size := Vector2(1280, 720)
	# два острови з однаковим центром — другий напис має піднятись
	var tops := MapScreen.place_labels([Vector2(640, 400), Vector2(640, 400)], [], size)
	assert_eq(tops.size(), 2)
	assert_almost_eq((tops[0] as Vector2).y, 400.0 - MapScreen.LABEL_LIFT, 0.001)
	assert_lt((tops[1] as Vector2).y, (tops[0] as Vector2).y, "другий напис вище першого")
	assert_false(Rect2(tops[0], Vector2(MapScreen.LABEL_W, MapScreen.LABEL_H)).intersects(Rect2(tops[1], Vector2(MapScreen.LABEL_W, MapScreen.LABEL_H))))
	# вузол прямо під написом — напис піднімається
	var one := MapScreen.place_labels([Vector2(640, 400)], [Vector2(640, 400.0 - MapScreen.LABEL_LIFT + 10.0)], size)
	assert_lt((one[0] as Vector2).y, 400.0 - MapScreen.LABEL_LIFT, "піднято через вузол")
	# не більше 4 зсувів
	var stuck := MapScreen.place_labels([Vector2(640, 400)], [Vector2(640, 100), Vector2(640, 140), Vector2(640, 180), Vector2(640, 220), Vector2(640, 260)], size)
	assert_gte((one[0] as Vector2).y, 400.0 - MapScreen.LABEL_LIFT - MapScreen.LABEL_STEP * MapScreen.LABEL_TRIES)
	assert_almost_eq((stuck[0] as Vector2).y, 400.0 - MapScreen.LABEL_LIFT - MapScreen.LABEL_STEP * MapScreen.LABEL_TRIES, 0.001, "рівно 4 зсуви, далі не пробуємо")


func test_smooth_path_keeps_endpoints() -> void:
	var pts := [Vector2(0, 0), Vector2(100, 50), Vector2(200, 0)]
	var path := MapScreen.MapCanvas.smooth_path(pts, 4)
	assert_eq(path.size(), 9, "2 відрізки × 4 + кінець")
	assert_eq(path[0], pts[0])
	assert_eq(path[-1], pts[-1])


func test_camera_scales_with_lanes() -> void:
	var base := {"pos": [0.0, 3.0, 5.0], "look": [0.0, 1.0, -4.0], "fov": 60}
	var c7: Dictionary = RunScript.camera_for_lanes(base, 7)
	assert_gt(float(c7["pos"][1]), 3.0, "7 доріжок — камера вище")
	var c3: Dictionary = RunScript.camera_for_lanes(base, 3)
	assert_almost_eq(float(c3["pos"][1]), 3.0, 0.001, "3 доріжки — без змін")
	var o: Dictionary = RunScript.camera_for_lanes({"ortho": true, "size": 9.0, "pos": [3, 6, 6]}, 5)
	assert_gt(float(o["size"]), 9.0, "орто — ширша")


# ---------- 0.6.0: пляж на піску, камера всередині світу, фініш ----------

func test_beach_is_surf_on_sea() -> void:
	var beach: Dictionary = _worlds["beach"]
	assert_eq(String(beach["mode"]), "surf", "Пляж — серфінг (v1.3)")
	assert_true(bool(beach.get("sea", false)), "море на всю ширину, герой на дошці")
	assert_true(beach.has("water"), "колір моря для водяної площини")
	assert_true(beach.has("speed_factor"), "множник швидкості режиму Серфінг")


func test_world_cameras_are_perspective_and_low() -> void:
	for id in _worlds.keys():
		var cam: Dictionary = _worlds[id].get("camera", {})
		assert_false(bool(cam.get("ortho", false)), "%s: камера перспективна, всередині світу" % id)
		assert_true(cam.has("fov"), "%s: є fov" % id)
		var pos: Array = cam.get("pos", [])
		assert_eq(pos.size(), 3, "%s: pos — 3 числа" % id)
		assert_lt(float(pos[1]), 4.0, "%s: камера низько (не «з висоти пташки»)" % id)


func test_beach_levels_have_no_big_wave_but_have_friends() -> void:
	for l in _levels:
		if String(l["world"]) != "beach":
			continue
		var ev: Array = l.get("events", [])
		assert_false(ev.has("big_wave"), "рівень %d: big_wave лише для Хвилі" % int(l["id"]))
		assert_true(ev.has("friend") or ev.has("rainbow"), "рівень %d: є друг або веселка" % int(l["id"]))


func test_level_events_match_world_mode() -> void:
	# кожна подія рівня має бути дозволена в режимі його біому (data/events.json → modes)
	var f := FileAccess.open("res://data/events.json", FileAccess.READ)
	assert_not_null(f)
	var parsed = JSON.parse_string(f.get_as_text())
	var by_id := {}
	for e in parsed.get("events", []):
		by_id[String(e["id"])] = e
	for l in _levels:
		var mode := String(_worlds[l["world"]].get("mode", "run"))
		for ev in l.get("events", []):
			assert_true(by_id.has(ev), "рівень %d: подія %s існує" % [int(l["id"]), ev])
			if by_id.has(ev):
				assert_true((by_id[ev].get("modes", []) as Array).has(mode), "рівень %d: подія %s буває в режимі %s" % [int(l["id"]), ev, mode])


func test_decor_big_voxels_exist() -> void:
	for id in _worlds.keys():
		var big: Array = _worlds[id].get("decor_big", [])
		assert_gte(big.size(), 4, "%s: ≥ 4 великих декорацій біля дороги" % id)
		for v in big:
			assert_true(FileAccess.file_exists("res://data/voxels/%s.json" % String(v)), "%s: декор %s існує" % [id, v])
		for v in _worlds[id].get("decor", []):
			assert_true(FileAccess.file_exists("res://data/voxels/%s.json" % String(v)), "%s: декор %s існує" % [id, v])


func test_hop_drift_is_clamped() -> void:
	var m := HopMode.new()
	m.speed = 4.0
	assert_almost_eq(m.drift_rate(), 0.9, 0.001, "базовий дрейф 0,9 клітинки/с")
	m.speed = 1.0
	assert_almost_eq(m.drift_rate(), 0.6, 0.001, "не повільніше 0,6")
	m.speed = 20.0
	assert_almost_eq(m.drift_rate(), 1.6, 0.001, "не швидше 1,6")
	m.speed = 4.0
	assert_almost_eq(m.seconds_to_hero(3.8), 2.0, 0.001, "час до перешкоди: дрейф + 1 крок/с")


func test_finish_gate_width_follows_lanes() -> void:
	var g := FinishGate3D.new()
	g.setup(7)
	assert_gt(g.get_child_count(), 4, "стовпчики, прапорці, банер, іскри")
	assert_false(g.passed)
	g.free()
