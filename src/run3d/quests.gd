## Мінізавдання на сегмент (data/quests.json), від профілю mid. Прогрес — з лічильників Spawner3D/EventSpawner.
class_name Quests
extends RefCounted

var current: Dictionary = {}
var done := false

var _all: Array = []


func _init() -> void:
	var f := FileAccess.open("res://data/quests.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			_all = parsed.get("quests", [])


## Чиста функція: вибір завдання для профілю (або {} якщо для профілю завдань нема).
static func pick(all: Array, profile_name: String, rng: RandomNumberGenerator) -> Dictionary:
	var pool := all.filter(func(q): return (q.get("profiles", []) as Array).has(profile_name))
	if pool.is_empty():
		return {}
	return pool[rng.randi() % pool.size()]


func start_segment(profile_name: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	current = pick(_all, profile_name, rng)
	done = false


## Повертає прогрес 0..target; при досягненні — done = true (один раз).
func progress(stars: int, passed: int, events: int) -> int:
	if current.is_empty():
		return 0
	var v := 0
	match String(current.get("type", "")):
		"stars": v = stars
		"passed": v = passed
		"events": v = events
	var target := int(current.get("target", 1))
	if not done and v >= target:
		done = true
		Events.quest_completed.emit(String(current.get("id", "")), int(current.get("reward", 0)))
	return mini(v, target)


func target() -> int:
	return int(current.get("target", 0))


func icon_kind() -> String:
	return String(current.get("type", ""))
