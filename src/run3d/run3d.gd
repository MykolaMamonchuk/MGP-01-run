## Головна сцена (3D). Стани: MENU → (HEROES) → COUNTDOWN → RUN ⇄ STATION (Розвилка) → … → SLEEP.
## Оркеструє профіль, світ і його режим руху, жести, міні-події, мінізавдання, живе небо/сезон, ефекти.
## Герой стоїть у (0,0,0), світ їде на нього.
extends Node3D

enum State { MENU, HEROES, COUNTDOWN, RUN, STATION, SLEEP }

const WORLD_SWITCH_SEC := 0.9
const FORK_AUTO_PICK_SEC := 10.0
const MENU_SPEED := 1.1

@onready var hero: Hero3D = $Hero
@onready var track: Track = $Track
@onready var spawner: Spawner3D = $Spawner
@onready var actors: Node3D = $Actors
@onready var camera_rig: CameraRig = $CameraRig
@onready var hud: CanvasLayer = $HUD
@onready var env: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var events_spawner: EventSpawner = $EventSpawner
@onready var menu: MenuLayer = $Menu
@onready var hero_select: HeroSelect = $HeroSelect
@onready var ambient_root: Node3D = $Ambient

var state: State = State.MENU
var profiles: Dictionary = {}
var profile: Dictionary = {}
var worlds: Dictionary = {}
var world: Dictionary = {}
var world_id := ""
var mode: ModeBase
var season: Dictionary = {}
var heroes: Dictionary = {}

var base_speed := 4.0
var speed := 4.0
var run_time := 0.0
var session_t := 0.0
var session_total := 600.0
var checkpoint_t := 0.0
var checkpoint_seconds := 90.0
var checkpoint_index := 0
var switching := false
var quests := Quests.new()

var _sky_mat: ProceduralSkyMaterial
var _ambient: GPUParticles3D
var _fireflies: GPUParticles3D
var _countdown_tw: Tween

# жести одного пальця
var _pressed := false
var _press_time := -1.0
var _press_pos := Vector2.ZERO
var _cur_pos := Vector2.ZERO
var _swiped := false
var _holding := false
var _idle_t := 0.0
var _fork_idle := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	profiles = AgeAdapt.load_profiles()
	checkpoint_seconds = float(profiles.get("checkpoint_seconds", 90))
	worlds = load_worlds()
	heroes = HeroSelect.load_heroes()
	season = Seasons.current()
	_setup_sky()

	Events.profile_changed.connect(_apply_profile)
	Events.session_warning.connect(_on_session_warning)
	Events.session_finished.connect(_on_session_finished)
	Events.star_collected.connect(_on_star_collected)
	Events.quest_completed.connect(_on_quest_completed)
	hero.landed.connect(func(): AudioMgr.sfx("land"))
	menu.play_pressed.connect(_on_play)
	menu.heroes_pressed.connect(_on_heroes)
	hero_select.chosen.connect(_on_hero_chosen)
	hero_select.closed.connect(_on_heroes_closed)

	_apply_profile(AgeAdapt.current)
	_apply_hero(String(SaveService.child().get("hero", "puf")))
	var start := String(SaveService.child().get("last_world", "meadow"))
	var allowed: Array = profile.get("worlds", ["meadow"])
	if not allowed.has(start) or not worlds.has(start):
		start = String(allowed[0]) if not allowed.is_empty() and worlds.has(allowed[0]) else String(worlds.keys()[0])
	_enter_world(start, true)
	_enter_menu(true)


# ---------- дані ----------

static func load_worlds() -> Dictionary:
	var out := {}
	var dir := DirAccess.open("res://data/worlds")
	if dir == null:
		return out
	for fname in dir.get_files():
		if not fname.ends_with(".json"):
			continue
		var f := FileAccess.open("res://data/worlds/%s" % fname, FileAccess.READ)
		if f == null:
			continue
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("id"):
			out[String(parsed["id"])] = parsed
	return out


## Чиста функція: двері Розвилки для профілю.
static func fork_ids(allowed: Array, current: String, n: int, rng: RandomNumberGenerator) -> Array:
	var others := allowed.filter(func(w): return String(w) != current)
	for i in range(others.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = others[i]
		others[i] = others[j]
		others[j] = tmp
	var out := others.slice(0, mini(n, others.size()))
	if out.size() < n and allowed.has(current):
		out.append(current)
	if out.is_empty():
		out.append(current)
	return out


func _apply_profile(profile_name: String) -> void:
	profile = profiles.get(profile_name, profiles.get("young", {}))
	base_speed = float(profile.get("speed", 4.0))
	speed = base_speed
	hero.jump_velocity = float(profile.get("jump_velocity", 7.5))
	if mode:
		mode.profile = profile
		spawner.profile = profile
		spawner.magnet = float(profile.get("star_magnet", 1.0))
		events_spawner.profile = profile
	hud.set_profile(profile_name)


func _apply_hero(id: String) -> void:
	if not heroes.has(id):
		id = "puf"
	var h: Dictionary = heroes.get(id, {})
	hero.set_hero(id, String(h.get("color", "#FFB84D")), String(h.get("feature", "tuft")))


func _make_mode(kind: String) -> ModeBase:
	match kind:
		"hop": return HopMode.new()
		"slide": return SlideMode.new()
		_: return RunMode.new()


func _enter_world(id: String, instant: bool) -> void:
	world = worlds[id]
	world_id = id
	if mode:
		mode.exit()
	mode = _make_mode(String(world.get("mode", "run")))
	mode.setup(self, hero, world, profile)
	mode.speed = speed
	mode.enter()
	hero.lane = 0
	hero.x_target = 0.0
	hero.set_running(mode.mode_id() != "hop")
	track.rebuild(world, not instant, season)
	if state == State.RUN or state == State.COUNTDOWN or instant:
		camera_rig.apply(world.get("camera", {}), 0.0 if instant else 0.8)
	_set_sky(clampf(session_t / session_total, 0.0, 1.0))
	_set_ambient()
	spawner.configure(profile, world, hero, mode, self)
	events_spawner.configure(self, hero, spawner, actors, profile, mode.mode_id())
	quests.start_segment(AgeAdapt.current)
	hud.set_quest(quests.icon_kind(), 0, quests.target())
	hud.set_world(String(world.get("name_uk", id)))
	AudioMgr.music(String(world.get("music", "")))
	if not instant:
		AudioMgr.voice("world_%s" % id)
	SaveService.child()["last_world"] = id
	Events.world_changed.emit(id)


# ---------- небо, сезон, атмосфера ----------

func _setup_sky() -> void:
	if env.environment == null:
		env.environment = Environment.new()
	var e := env.environment
	e.background_mode = Environment.BG_SKY
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sun_angle_max = 30.0
	_sky_mat.sun_curve = 0.15
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_energy = 0.75


## Живе небо: день → вечір протягом сесії (t 0..1); сезон підфарбовує.
func _set_sky(t: float) -> void:
	var day := Color(String(world.get("sky", "#9BDDFF")))
	var evening := Color(String(world.get("sky_evening", "#F7B58A")))
	if not season.is_empty():
		day = day * Color(String(season.get("sky_tint", "#FFFFFF")))
	var c := day.lerp(evening, t)
	if _sky_mat:
		_sky_mat.sky_top_color = c.darkened(0.15).lerp(Color("#5C6BC0"), t * 0.35)
		_sky_mat.sky_horizon_color = c.lightened(0.25)
		_sky_mat.ground_bottom_color = c.darkened(0.4)
		_sky_mat.ground_horizon_color = c.lightened(0.15)
	if env.environment:
		env.environment.ambient_light_color = c.lightened(0.35)
	sun.light_energy = lerpf(1.15, 0.7, t)
	sun.light_color = Color.WHITE.lerp(Color("#FFC59A"), t)
	# світлячки надвечір
	if t > 0.6 and _fireflies == null:
		_fireflies = FX.ambient(ambient_root, "fireflies")
	elif t <= 0.6 and _fireflies != null:
		_fireflies.queue_free()
		_fireflies = null


func _set_ambient() -> void:
	if _ambient:
		_ambient.queue_free()
		_ambient = null
	var kind := String(season.get("particles", ""))
	if kind == "":
		match String(world.get("mode", "run")):
			"run": kind = "petals"
			"hop": kind = "leaves"
			"slide": kind = "glints"
	if kind != "":
		_ambient = FX.ambient(ambient_root, kind)


# ---------- стани ----------

func _enter_menu(instant: bool) -> void:
	state = State.MENU
	get_tree().paused = false
	if _countdown_tw:
		_countdown_tw.kill()
		_countdown_tw = null
	hud.hide_station()
	spawner.spawning = false
	spawner.clear()
	hero.set_running(false)
	hero.visible = true
	hero.face_camera(true, 0.0 if instant else 0.5)
	hud.set_gameplay_visible(false)
	camera_rig.apply(CameraRig.PRESET_MENU, 0.0 if instant else 0.8)
	menu.show_menu()
	AudioMgr.music("menu")
	get_tree().create_timer(0.6).timeout.connect(func():
		if state == State.MENU:
			hero.wave_hello())


func _on_play() -> void:
	if state != State.MENU:
		return
	state = State.COUNTDOWN
	menu.hide_menu()
	hud.set_gameplay_visible(true)
	camera_rig.apply(world.get("camera", {}), 0.8)
	hero.cheer()
	# розвертається спиною до камери і починає бігти на місці
	hero.face_camera(false, 0.6)
	get_tree().create_timer(0.6).timeout.connect(func(): hero.set_running(true))
	_countdown_tw = create_tween()
	for i in range(3):
		_countdown_tw.tween_callback(hud.flash.bind(str(3 - i), 0.7, Color("#FFF176")))
		_countdown_tw.tween_callback(AudioMgr.sfx.bind("count"))
		_countdown_tw.tween_interval(0.7)
	_countdown_tw.tween_callback(_start_run)


func _start_run() -> void:
	state = State.RUN
	hud.flash("Біжимо!", 0.9, Color("#69F0AE"))
	AudioMgr.voice("go")
	spawner.spawning = true
	checkpoint_t = 0.0
	_idle_t = 0.0
	var minutes := float(SaveService.setting("session_minutes", 10))
	session_total = maxf(60.0, minutes * 60.0)
	SessionTimer.start(minutes)
	AudioMgr.music(String(world.get("music", "")))


func _on_heroes() -> void:
	if state != State.MENU:
		return
	state = State.HEROES
	menu.hide_menu()
	hero.visible = false
	camera_rig.apply(CameraRig.PRESET_HEROES, 0.7)
	hero_select.open(camera_rig.cam, hero.hero_id)


func _on_hero_chosen(id: String) -> void:
	_apply_hero(id)


func _on_heroes_closed() -> void:
	if state == State.HEROES:
		_enter_menu(false)


# ---------- цикл ----------

func _process(delta: float) -> void:
	if _parents_open():
		return
	match state:
		State.SLEEP:
			return
		State.MENU, State.HEROES, State.COUNTDOWN:
			# дорога повільно їде під меню — сцена жива
			var d := MENU_SPEED * delta if mode.mode_id() != "hop" else 0.0
			if d > 0.0:
				track.advance(d)
				spawner.advance(d)
			return
		State.STATION:
			_fork_idle += delta
			if _fork_idle > FORK_AUTO_PICK_SEC and hud.fork_visible():
				var opts := _fork_options()
				_on_fork_chosen(String(opts[randi() % opts.size()]["id"]))
			return
	if switching:
		return
	run_time += delta
	session_t += delta
	checkpoint_t += delta
	var ramp := float(profile.get("speed_ramp", 0.2))
	speed = base_speed * (1.0 + ramp * clampf(checkpoint_t / 60.0, 0.0, 1.0))
	mode.speed = speed
	spawner.set_speed(speed)
	if _pressed and Gestures.hold_started(_held_sec(), _swiped, _holding):
		_holding = true
		mode.gesture("hold_start", _cur_pos)
	mode.steer(_pressed and not _swiped, _cur_pos)
	var dist := mode.tick(delta)
	if absf(dist) > 0.0:
		track.advance(dist)
		spawner.advance(dist)
	spawner.check(delta)
	events_spawner.tick(delta)
	_hint(delta)
	_quest_tick()
	_set_sky(clampf(session_t / session_total, 0.0, 1.0))
	if checkpoint_t >= checkpoint_seconds:
		_station()


func _held_sec() -> float:
	return (Time.get_ticks_msec() - _press_time) / 1000.0 if _press_time >= 0.0 else 0.0


func _parents_open() -> bool:
	return is_instance_valid(hud) and bool(hud.get("parents_open"))


func _hero_screen_hit(pos: Vector2) -> bool:
	var sp := camera_rig.cam.unproject_position(hero.global_position + Vector3(0, 0.6, 0))
	return sp.distance_to(pos) < 130.0


## Дебаг (лише в редакторі/debug-збірці): 1/2/3 — світ, S — станція зараз, F — веселка, D — друг, Q — завдання виконано.
func _debug_key(event: InputEventKey) -> void:
	if not OS.is_debug_build() or not event.pressed or event.echo:
		return
	var world_keys := {KEY_1: "meadow", KEY_2: "forest", KEY_3: "beach"}
	if world_keys.has(event.keycode) and state == State.RUN and worlds.has(world_keys[event.keycode]):
		switching = true
		_enter_world(String(world_keys[event.keycode]), false)
		get_tree().create_timer(WORLD_SWITCH_SEC).timeout.connect(func(): switching = false)
	elif event.keycode == KEY_S and state == State.RUN:
		_station()
	elif event.keycode == KEY_F and state == State.RUN:
		events_spawner.force("rainbow")
	elif event.keycode == KEY_D and state == State.RUN:
		events_spawner.force("friend")
	elif event.keycode == KEY_Q and state == State.RUN:
		Events.quest_completed.emit("debug", 10)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_debug_key(event)
		return
	if state == State.SLEEP or _parents_open():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_pressed = true
			_press_time = Time.get_ticks_msec()
			_press_pos = event.position
			_cur_pos = event.position
			_swiped = false
			_holding = false
			_idle_t = 0.0
			Events.player_input.emit()
			match state:
				State.MENU:
					if _hero_screen_hit(event.position):
						hero.pet()
					return
				State.HEROES:
					hero_select.tap(event.position)
					return
				State.STATION:
					hero.pet()
					return
				State.COUNTDOWN:
					return
			Events.gameplay_input.emit()
		else:
			var g := Gestures.on_release(_held_sec(), _swiped)
			_pressed = false
			_press_time = -1.0
			_holding = false
			if g != "" and state == State.RUN and not switching:
				mode.gesture(g, event.position)
	elif event is InputEventScreenDrag and _pressed and not _swiped:
		_cur_pos = event.position
		var d := Gestures.swipe_dir(_press_pos, _cur_pos)
		if d != "":
			_swiped = true
			if state == State.HEROES:
				if d == "swipe_left":
					hero_select.move(1)
				elif d == "swipe_right":
					hero_select.move(-1)
				return
			if _holding:
				_holding = false
				mode.gesture("hold_end", _cur_pos)
			if state == State.RUN and not switching:
				mode.gesture(d, _cur_pos)
				Events.gameplay_input.emit()


func _release_assist_duck() -> void:
	if not _holding:
		hero.set_duck(false)


## Відкат на клітинку після падіння (Стрибки).
func pushback() -> void:
	if mode is HopMode:
		(mode as HopMode).step(-1)


## Падіння героя — тряска камери.
func on_tumble() -> void:
	camera_rig.shake(0.1)


func _on_star_collected(n: int) -> void:
	SaveService.add_stars(n)
	if state == State.RUN:
		hud.fly_star(camera_rig.cam.unproject_position(hero.global_position + Vector3(0, 0.8, 0)))


func _hint(delta: float) -> void:
	if not mode.wants_hint():
		return
	_idle_t += delta
	if _idle_t > float(profile.get("hint_after_sec", 5)):
		hud.show_hint()
		AudioMgr.voice("hint_tap")
		_idle_t = 0.0


func _quest_tick() -> void:
	if quests.current.is_empty():
		return
	var v := quests.progress(spawner.stars_collected_segment, spawner.passed_segment, events_spawner.events_seen_segment)
	if not quests.done:
		hud.set_quest(quests.icon_kind(), v, quests.target())


func _on_quest_completed(_id: String, reward: int) -> void:
	Events.star_collected.emit(reward)
	hud.show_quest_done(reward)
	hero.cheer()
	FX.confetti(hero, Vector3(0, 1.2, 0), 60)
	AudioMgr.sfx("confetti")
	AudioMgr.voice("praise")


# ---------- станція, Розвилка ----------

func _station() -> void:
	state = State.STATION
	get_tree().paused = true
	checkpoint_t = 0.0
	checkpoint_index += 1
	_fork_idle = 0.0
	hero.set_duck(false)
	hero.set_running(false)
	events_spawner.reset()
	SaveService.add_stars(20)
	SaveService.child()["checkpoints"] = int(SaveService.child().get("checkpoints", 0)) + 1
	SaveService.save_game()
	Stats.inc("checkpoints")
	Stats.flush()
	AudioMgr.sfx("station")
	AudioMgr.voice("station")
	# дерево на паузі — конфеті вішаємо на Run3D (ALWAYS), герой стоїть у (0,0,0)
	FX.confetti(self, Vector3(0, 1.2, 0), 80)
	hud.show_station(checkpoint_index)
	Events.checkpoint_reached.emit(checkpoint_index)
	hud.show_fork(_fork_options(), _on_fork_chosen)


func _fork_options() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var allowed: Array = profile.get("worlds", ["meadow"]).filter(func(w): return worlds.has(w))
	var ids := fork_ids(allowed, world_id, int(profile.get("fork_options", 2)), rng)
	var out := []
	for id in ids:
		var w: Dictionary = worlds[id]
		out.append({"id": id, "name_uk": w.get("name_uk", id), "accent": w.get("accent", "#F06292")})
	return out


func _on_fork_chosen(id: String) -> void:
	if state != State.STATION:
		return
	state = State.RUN
	get_tree().paused = false
	hud.hide_station()
	Stats.inc("fork_%s" % id)
	switching = true
	_enter_world(id, false)
	get_tree().create_timer(WORLD_SWITCH_SEC).timeout.connect(func(): switching = false)


## Сумісність із HUD (_run_is_busy шукає цей метод і поля paused_at_station/sleeping).
func _leave_station() -> void:
	pass


var paused_at_station: bool:
	get:
		return state == State.STATION

var sleeping: bool:
	get:
		return state == State.SLEEP


# ---------- сон ----------

func _on_session_warning(seconds_left: int) -> void:
	if state != State.RUN:
		return
	if seconds_left == 120:
		AudioMgr.voice("yawn")
		hud.show_yawn()
	elif seconds_left == 60:
		AudioMgr.voice("almost_sleep")


func _on_session_finished() -> void:
	if state == State.MENU or state == State.HEROES:
		return
	state = State.SLEEP
	get_tree().paused = true
	hero.set_duck(false)
	hero.set_running(false)
	SaveService.save_game()
	Stats.flush()
	AudioMgr.music("lullaby")
	AudioMgr.voice("goodnight")
	hud.show_sleep(_on_sleep_continue_pressed)


func _on_sleep_continue_pressed() -> void:
	ParentGate.request("settings", _resume_after_sleep)


func _resume_after_sleep() -> void:
	hud.hide_sleep()
	get_tree().paused = false
	session_t = 0.0
	_enter_menu(false)
