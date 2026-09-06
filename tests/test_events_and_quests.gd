## Міні-події (EventSpawner.pick) і мінізавдання (Quests.pick) — вибір за даними, чисті функції.
extends GutTest

var _rng := RandomNumberGenerator.new()
var _events: Array = []
var _quests: Array = []


func before_each() -> void:
	_rng.seed = 7
	_events = _load("res://data/events.json", "events")
	_quests = _load("res://data/quests.json", "quests")


func _load(path: String, key: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed.get(key, []) if typeof(parsed) == TYPE_DICTIONARY else []


func test_events_data_shape() -> void:
	assert_gt(_events.size(), 2)
	for e in _events:
		assert_true(e.has("id") and e.has("modes") and e.has("weights"), "%s: id/modes/weights" % e.get("id", "?"))


func test_pick_respects_mode() -> void:
	for i in 30:
		var e := EventSpawner.pick(_events, "mid", "hop", _rng)
		if e.is_empty():
			continue
		assert_true((e["modes"] as Array).has("hop"), "у Стрибках лише події для hop: %s" % e["id"])


func test_pick_skips_zero_weight_and_todo() -> void:
	for i in 40:
		var e := EventSpawner.pick(_events, "young", "hop", _rng)
		assert_false(e.get("id", "") == "bridge", "«міст падає» не для young і не реалізовано")
	for i in 40:
		var e := EventSpawner.pick(_events, "older", "run", _rng)
		assert_false(e.get("id", "") == "dragonfly", "бабка (вага 0 для older) не випадає")


func test_pick_returns_empty_when_nothing_fits() -> void:
	var e := EventSpawner.pick(_events, "older", "no_such_mode", _rng)
	assert_true(e.is_empty())


func test_weighted_pick_favours_heavier_event() -> void:
	var fake := [
		{"id": "a", "modes": ["run"], "weights": {"young": 9}},
		{"id": "b", "modes": ["run"], "weights": {"young": 1}},
	]
	var a := 0
	for i in 200:
		if EventSpawner.pick(fake, "young", "run", _rng)["id"] == "a":
			a += 1
	assert_gt(a, 140, "вага 9:1 → «a» помітно частіше (%d/200)" % a)


func test_quests_none_for_young() -> void:
	assert_true(Quests.pick(_quests, "young", _rng).is_empty(), "GDD §3: цілі — від mid")


func test_quests_exist_for_mid_and_older() -> void:
	assert_false(Quests.pick(_quests, "mid", _rng).is_empty())
	assert_false(Quests.pick(_quests, "older", _rng).is_empty())


func test_quest_progress_completes_once() -> void:
	var q := Quests.new()
	q.current = {"id": "t", "type": "stars", "target": 3, "reward": 5}
	watch_signals(Events)
	assert_eq(q.progress(1, 0, 0), 1)
	assert_false(q.done)
	assert_eq(q.progress(5, 0, 0), 3, "прогрес обрізається до цілі")
	assert_true(q.done)
	q.progress(9, 0, 0)
	assert_signal_emit_count(Events, "quest_completed", 1, "сигнал — один раз")
