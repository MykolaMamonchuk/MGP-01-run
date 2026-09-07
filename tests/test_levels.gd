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


func test_camera_scales_with_lanes() -> void:
	var base := {"pos": [0.0, 3.0, 5.0], "look": [0.0, 1.0, -4.0], "fov": 60}
	var c7: Dictionary = RunScript.camera_for_lanes(base, 7)
	assert_gt(float(c7["pos"][1]), 3.0, "7 доріжок — камера вище")
	var c3: Dictionary = RunScript.camera_for_lanes(base, 3)
	assert_almost_eq(float(c3["pos"][1]), 3.0, 0.001, "3 доріжки — без змін")
	var o: Dictionary = RunScript.camera_for_lanes({"ortho": true, "size": 9.0, "pos": [3, 6, 6]}, 5)
	assert_gt(float(o["size"]), 9.0, "орто — ширша")


# ---------- 0.6.0: пляж на піску, камера всередині світу, фініш ----------

func test_beach_is_run_on_sand_with_sea_on_the_side() -> void:
	var beach: Dictionary = _worlds["beach"]
	assert_eq(String(beach["mode"]), "run", "Пляж — біг по піску (Хвиля лишилась у коді на майбутнє)")
	assert_eq(int(beach.get("sea_side", 0)), -1, "море — декоративне, ліворуч")
	assert_true(beach.has("water"), "колір моря для водяної площини")
	assert_true(beach.has("speed_factor"), "speed_factor лишається для режиму Хвиля")


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
