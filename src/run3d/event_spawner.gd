## Міні-події на дорозі (data/events.json). Кожні N секунд — випадкова за вагами профілю і режиму.
class_name EventSpawner
extends Node

var run: Node
var hero: Hero3D
var spawner: Spawner3D
var actors: Node3D           # друг, бабка — не рухаються зі світом
var profile: Dictionary = {}
var mode_id := "run"
var events_seen_segment := 0
## Обмеження рівня: які події дозволені (порожньо — всі для режиму). Порожній масив у рівні = подій нема.
var allowed_ids: Array = []
var events_enabled := true

var _events: Array = []
var _next := 25.0
var _active := ""


func _ready() -> void:
	var f := FileAccess.open("res://data/events.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			_events = parsed.get("events", [])


func configure(r: Node, h: Hero3D, sp: Spawner3D, a: Node3D, p: Dictionary, m: String) -> void:
	run = r
	hero = h
	spawner = sp
	actors = a
	profile = p
	mode_id = m
	events_seen_segment = 0
	_schedule()


func _schedule() -> void:
	var iv: Array = profile.get("event_interval", [20.0, 30.0])
	_next = randf_range(float(iv[0]), float(iv[1]))


## Чиста функція: вибір події за вагами. Для тестів приймає rng.
static func pick(events: Array, profile_name: String, mode: String, rng: RandomNumberGenerator) -> Dictionary:
	var pool := []
	var total := 0.0
	for e in events:
		if not (e.get("modes", []) as Array).has(mode):
			continue
		if e.has("_todo"):
			continue
		var w := float((e.get("weights", {}) as Dictionary).get(profile_name, 0))
		if w <= 0.0:
			continue
		pool.append([e, w])
		total += w
	if pool.is_empty():
		return {}
	var r := rng.randf() * total
	for item in pool:
		r -= float(item[1])
		if r <= 0.0:
			return item[0]
	return pool[-1][0]


func tick(delta: float) -> void:
	if _active != "" or not events_enabled:
		return
	_next -= delta
	if _next > 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# рівень задає список подій; порожній список = подій на рівні нема (туторіал)
	var pool := _events.filter(func(ev): return allowed_ids.has(String(ev.get("id", ""))))
	var e := pick(pool, AgeAdapt.current, mode_id, rng)
	_schedule()
	if e.is_empty():
		return
	_start(e)


## Дебаг: запустити подію за id негайно.
func force(id: String) -> void:
	for e in _events:
		if String(e.get("id", "")) == id:
			_active = ""
			_start(e)
			return


func _start(e: Dictionary) -> void:
	var id := String(e["id"])
	var dur := float(e.get("duration", 5.0))
	_active = id
	events_seen_segment += 1
	Events.mini_event_started.emit(id)
	AudioMgr.voice(String(e.get("voice", "wow")))
	match id:
		"rainbow":
			# портал на випадковій доріжці; політ — лише якщо дитина пробігла крізь нього (Spawner3D.check)
			var arc := Rainbow3D.new()
			arc.lane = spawner.random_lane()
			arc.position = Vector3(float(arc.lane) * Hero3D.LANE_W, 0.0, -9.0)
			spawner.add_child(arc)
			AudioMgr.sfx("rainbow")
		"friend":
			var fr := Friend3D.new()
			actors.add_child(fr)
			fr.setup(hero, Palette.FRIEND_DEFAULT, dur)
		"dragonfly":
			var d := Dragonfly3D.new()
			actors.add_child(d)
			d.setup(spawner, dur)
		"big_wave":
			hero.wave_bump()
			spawner.spawn_star_arc(1.8, 5)
			AudioMgr.sfx("wave")
		_:
			pass
	get_tree().create_timer(dur + 1.0).timeout.connect(_finish.bind(id))


func _finish(id: String) -> void:
	if _active == id:
		_active = ""
	Events.mini_event_finished.emit(id)


## На станції все активне прибираємо.
func reset() -> void:
	_active = ""
	for c in actors.get_children():
		c.queue_free()
	_schedule()
