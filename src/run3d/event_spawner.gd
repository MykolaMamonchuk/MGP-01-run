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

## ДРУГ — рівно ОДИН на дорозі й не частіше ніж раз на FRIEND_COOLDOWN секунд.
## Playtest 09.09 (Місто): на доріжці стояла колона з десятка однакових синіх друзів —
## кожен виклик (зокрема дебаг-клавіша) створював ще одного, і ніхто нікого не рахував.
const FRIEND_COOLDOWN := 20.0

var _events: Array = []
var _next := 25.0
var _active := ""
var _friend: Friend3D          ## живий друг (null або вже звільнений — можна кликати нового)
var _friend_t := 0.0           ## скільки ще секунд друга не кличемо взагалі


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
	_prepare_friend()
	_schedule()


## Тіло друга будуємо ТУТ — на старті рівня, поза бігом. Заміряно: 368 і 325 мс, тобто
## шість-сім кадрів роботи. Посеред бігу це той самий ривок, який бачив замовник; на
## старті рівня він припадає на відлік, коли дитина ще не керує.
func _prepare_friend() -> void:
	if actors == null or hero == null:
		return
	if not is_instance_valid(_friend):
		_friend = Friend3D.new()
		actors.add_child(_friend)
	var t0 := Time.get_ticks_usec()
	_friend.prepare(hero, Palette.FRIEND_DEFAULT)
	if OS.has_feature("debug_hud"):
		print("ДРУГ: підготовка %.1f мс (на старті рівня, не в бігу)"
			% ((Time.get_ticks_usec() - t0) / 1000.0))


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


## Чи можна кликати друга: попередній уже пішов І кулдаун вичерпано.
func friend_allowed() -> bool:
	# «Друга можна» — коли минув кулдаун і ТЕПЕРІШНІЙ друг не бігає. Раніше тут стояло
	# `not is_instance_valid(_friend)`, бо друг звільнявся; тепер він живе весь рівень і
	# просто ховається, тож питаємо в нього самого.
	return _friend_t <= 0.0 and (not is_instance_valid(_friend) or not _friend.is_active())


func tick(delta: float) -> void:
	# кулдаун друга цокає ЗАВЖДИ — навіть поки триває інша подія
	_friend_t = maxf(0.0, _friend_t - delta)
	if _active != "" or not events_enabled:
		return
	_next -= delta
	if _next > 0.0:
		return
	var rng := RandomNumberGenerator.new()
	RngSeed.start(rng, "events")
	# рівень задає список подій; порожній список = подій на рівні нема (туторіал)
	var pool := _events.filter(func(ev): return allowed_ids.has(String(ev.get("id", ""))))
	var e := pick(pool, AgeAdapt.current, mode_id, rng)
	_schedule()
	if e.is_empty():
		return
	if String(e.get("id", "")) == "friend" and not friend_allowed():
		return          # друг ще на дорозі або щойно був — цього разу без події
	_start(e)


## Дебаг: запустити подію за id негайно. Сторожі ті самі, що й у випадкового вибору —
## інакше десять натискань клавіші дають десять друзів (саме так і сталось на playtest).
func force(id: String) -> void:
	for e in _events:
		if String(e.get("id", "")) == id:
			if id == "friend" and not friend_allowed():
				return
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
			if OS.has_feature("debug_hud"):
				_log_appearance("ВЕСЕЛКА")
		"friend":
			# Тут тепер лише ПОКАЗ уже готового тіла. Раніше стояло Friend3D.new() +
			# setup(), тобто побудова вокселів і матеріалів просто в кадрі: 368 і 325 мс за
			# годинником на Redmi 8A. Годинник лишається — ним і перевіряють, що ривка нема.
			var t0 := Time.get_ticks_usec()
			_prepare_friend()          # якщо рівень щойно почався й тіла ще нема
			if is_instance_valid(_friend):
				_friend.activate(dur)
			if OS.has_feature("debug_hud"):
				print("ДРУГ: поява %.1f мс" % ((Time.get_ticks_usec() - t0) / 1000.0))
			# поки цей друг бігає (або поки не мине кулдаун), другого не буде —
			# ні з випадкової події, ні з дебаг-клавіші
			_friend_t = maxf(FRIEND_COOLDOWN, dur + 5.0)
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


## Лише в збірці з debug_hud: найгірший кадр із перших APPEAR_FRAMES після появи події —
## у журнал телефона (`adb logcat -s godot:V`). Сплеск компіляції шейдера живе не в самому
## виклику, а в кадрі, коли новий матеріал уперше МАЛЮЄТЬСЯ, тож годинник довкола виклику
## (як у друга) його не бачить.
const APPEAR_FRAMES := 10


## Поруч друкуємо КОНТРОЛЬ — найгірший із стількох же кадрів через секунду, коли подія вже
## нічого не створює: на Redmi 8A і звичайний кадр буває 50 мс, тож число без контролю бреше.
func _log_appearance(label: String) -> void:
	var worst := await _worst_of(APPEAR_FRAMES)
	if not is_inside_tree():
		return
	for i in 60:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	var control := await _worst_of(APPEAR_FRAMES)
	print("%s: найгірший кадр із %d після появи %.1f мс, контроль %.1f мс" % [label,
		APPEAR_FRAMES, worst, control])


func _worst_of(n: int) -> float:
	var worst := 0.0
	var last := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		if not is_inside_tree():
			return worst
		var now := Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
	return worst


func _finish(id: String) -> void:
	if _active == id:
		_active = ""
	Events.mini_event_finished.emit(id)


## На станції все активне прибираємо.
func reset() -> void:
	_active = ""
	# ДРУГА НЕ ЗВІЛЬНЯЄМО. Його тіло коштує близько 300 мс, і якщо прибирати його разом з
	# рештою акторів, кожен новий рівень платив би це знову на відліку. Він і так один на
	# трасі, тож просто ховаємо.
	for c in actors.get_children():
		if c == _friend:
			continue
		c.queue_free()
	if is_instance_valid(_friend):
		_friend.call("_hide")
	_friend_t = 0.0
	_prepare_friend()
	_schedule()
