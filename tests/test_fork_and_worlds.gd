## Розвилка (Run3D.fork_ids) і дані світів (data/worlds/*.json).
extends GutTest

const RunScript := preload("res://src/run3d/run3d.gd")
const VALID_MODES := ["run", "surf", "scooter", "float_run", "slide", "hop", "float"]
const VALID_ACTIONS := ["jump", "duck", "any", "side", "gap", "boost", "rail", "wind"]

var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_rng.seed = 42


func test_fork_never_offers_forbidden_world() -> void:
	var ids: Array = RunScript.fork_ids(["meadow", "beach"], "meadow", 2, _rng)
	assert_false(ids.has("forest"), "young не бачить Лісу на Розвилці")


func test_fork_prefers_other_worlds_then_current() -> void:
	var ids: Array = RunScript.fork_ids(["meadow", "forest", "beach"], "meadow", 3, _rng)
	assert_eq(ids.size(), 3)
	assert_eq(ids[2], "meadow", "поточний світ — останнім, як «ще раз»")
	assert_true(ids.has("forest") and ids.has("beach"))


func test_fork_with_two_options_excludes_current() -> void:
	var ids: Array = RunScript.fork_ids(["meadow", "forest", "beach"], "forest", 2, _rng)
	assert_eq(ids.size(), 2)
	assert_false(ids.has("forest"), "двоє дверей — обидві в інші світи")


func test_fork_single_world_returns_it() -> void:
	var ids: Array = RunScript.fork_ids(["meadow"], "meadow", 2, _rng)
	assert_eq(ids, ["meadow"], "єдиний дозволений світ — просто далі")


func test_fork_is_deterministic_with_seed() -> void:
	var a: Array = RunScript.fork_ids(["meadow", "forest", "beach"], "meadow", 2, _rng)
	_rng.seed = 42
	var b: Array = RunScript.fork_ids(["meadow", "forest", "beach"], "meadow", 2, _rng)
	assert_eq(a, b)


func test_worlds_load_and_have_required_fields() -> void:
	var worlds: Dictionary = RunScript.load_worlds()
	assert_eq(worlds.size(), 5, "п'ять біомів на запуску (GDD v1.2 §3a)")
	for id in worlds.keys():
		var w: Dictionary = worlds[id]
		assert_true(VALID_MODES.has(w.get("mode", "")), "%s: mode один із run/surf/scooter/float_run/slide" % id)
		assert_true(w.has("camera"), "%s: є пресет камери" % id)
		assert_true(w.has("sky") and w.has("sky_evening"), "%s: небо день/вечір" % id)
		var obstacles: Dictionary = w.get("obstacles", {})
		assert_gt(obstacles.size(), 0, "%s: є перешкоди" % id)
		for k in obstacles.keys():
			var o: Dictionary = obstacles[k]
			assert_true(VALID_ACTIONS.has(o.get("action", "")), "%s/%s: дія валідна" % [id, k])
			assert_true(o.has("voxel"), "%s/%s: вказано воксель" % [id, k])
			var box: Array = o.get("box", [])
			assert_eq(box.size(), 3, "%s/%s: box — 3 числа" % [id, k])


func test_all_three_base_modes_present() -> void:
	var worlds: Dictionary = RunScript.load_worlds()
	var modes := []
	for id in worlds.keys():
		modes.append(worlds[id]["mode"])
	# v1.3: усі світи біжать — біг, серфінг, самокат, невагомий біг; Хвиля (slide) лишилась як код на майбутнє
	for m in ["run", "surf", "scooter", "float_run"]:
		assert_true(modes.has(m), "є біом з механікою %s" % m)
	assert_false(modes.has("slide"), "Хвиля поки не використовується жодним біомом")
	var slide := SlideMode.new()
	assert_eq(slide.mode_id(), "slide", "код Хвилі на місці")
