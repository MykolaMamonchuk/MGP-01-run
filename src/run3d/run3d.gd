## Головна сцена (3D). Стани: MENU → MAP → COUNTDOWN → RUN → FINISH → (MAP | наступний рівень) …; HEROES з меню;
## RESTART — серця скінчились, рівень починається знову; SLEEP по таймеру.
## Оркеструє рівні (LevelManager), біом і його режим руху (v1.3: усі світи біжать), жести (свайпи/стрілки/джойстик),
## туторіал, міні-події, пікапи, мінізавдання, живе небо/сезон, ефекти. Герой стоїть у (0,0,0), світ їде на нього.
extends Node3D

enum State { MENU, MAP, HEROES, COUNTDOWN, RUN, FINISH, RESTART, SLEEP }

const WORLD_SWITCH_SEC := 0.9
const MENU_SPEED := 1.1
const STICK_REARM_PX := 26.0
const TUTORIAL_LEAD_SEC := 1.7
const TUTORIAL_SLOW := 0.6
const FINISH_AUTO_NEXT_SEC := 7.0
## Швидкість: v = base × level.speed_mult × (1 + 0.35 × прогрес); останні 20% рівня — спринт ×1.15;
## ворота фінішу з'являються за 6 с до кінця.
const SPEED_RAMP := 0.35
const SPRINT_FROM := 0.8
const SPRINT_MULT := 1.15
const GATE_BEFORE_SEC := 6.0
## Пауза «Ще раз!» перед перезапуском рівня.
const RESTART_SEC := 2.0
const DEFAULT_FOG := 0.012

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
@onready var map_screen: MapScreen = $Map
@onready var controls: ControlsLayer = $Controls
@onready var wheel: WheelLayer = $Wheel
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
var lm := LevelManager.new()
var level: Dictionary = {}
var level_num := 1
var lanes := 3

var base_speed := 4.0
var speed := 4.0
var level_t := 0.0
var level_duration := 90.0
var session_t := 0.0
var session_total := 600.0
var switching := false
var quests := Quests.new()

var _ambient: GPUParticles3D
var _weather: GPUParticles3D
var _fireflies: GPUParticles3D
var _countdown_tw: Tween
var _lanes_changed := false
var _slow := 1.0
var _slow_t := 0.0
var _finish_auto_t := 0.0
var _pending_finish: Dictionary = {}
var _sprint_announced := false
var _gate_spawned := false
## Зірочки, зібрані на цьому рівні: у SaveService потрапляють лише на фініші (перезапуск їх не зберігає).
var level_coins := 0
## Активні пікапи: вид → секунд лишилось; равлик множить швидкість.
var _effects: Dictionary = {}
var _pickup_speed := 1.0
## Множники героя (GDD v1.3 §5, stats.speed / stats.magnet) — виставляються на старті рівня.
var _hero_speed := 1.0
var _hero_magnet := 1.0

# туторіал
var _learned: Dictionary = {}
var _tutorial_action := ""
var _tutorial_count: Dictionary = {}

# жести одного пальця
var _pressed := false
var _press_time := -1.0
var _press_pos := Vector2.ZERO
var _cur_pos := Vector2.ZERO
var _swiped := false
var _stick_used := false     # після першого відхилення джойстика відпускання/утримання вже не тап/присід
var _holding := false
var _idle_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	profiles = AgeAdapt.load_profiles()
	worlds = load_worlds()
	heroes = HeroSelect.load_heroes()
	season = Seasons.current()
	var l = SaveService.child().get("learned", {})
	_learned = l if typeof(l) == TYPE_DICTIONARY else {}
	_setup_sky()

	Events.profile_changed.connect(_apply_profile)
	Events.session_warning.connect(_on_session_warning)
	Events.session_finished.connect(_on_session_finished)
	Events.star_collected.connect(_on_star_collected)
	Events.quest_completed.connect(_on_quest_completed)
	hero.landed.connect(func(): AudioMgr.sfx("land"))
	menu.play_pressed.connect(_on_play)
	menu.heroes_pressed.connect(_on_heroes)
	menu.map_pressed.connect(_on_menu_map)
	menu.settings_pressed.connect(func():
		if state == State.MENU:
			hud._request_parents())
	hero_select.chosen.connect(_on_hero_chosen)
	hero_select.closed.connect(_on_heroes_closed)
	map_screen.level_chosen.connect(_start_level)
	map_screen.closed.connect(_on_map_closed)
	controls.action.connect(_on_control_action)
	wheel.finished.connect(_on_wheel_finished)

	_apply_profile(AgeAdapt.current)
	_apply_hero(String(SaveService.child().get("hero", "puf")))
	level_num = lm.current()
	level = lm.get_level(level_num)
	_enter_world(String(level.get("world", "meadow")), true)
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


## Чиста функція (сумісність із тестами): двері вибору світу.
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


## Камера під ширину дороги: 7 доріжок — вище й далі, ортографічна — ширша.
static func camera_for_lanes(preset: Dictionary, n_lanes: int) -> Dictionary:
	var k := 1.0 + float(n_lanes - 3) * 0.16
	var out := preset.duplicate(true)
	var p: Array = out.get("pos", [0.0, 3.4, 5.6])
	out["pos"] = [float(p[0]) * k, float(p[1]) * k, float(p[2]) * k]
	if bool(out.get("ortho", false)):
		out["size"] = float(out.get("size", 9.0)) * k
	return out


func _apply_profile(profile_name: String) -> void:
	profile = profiles.get(profile_name, profiles.get("young", {}))
	base_speed = float(profile.get("speed", 4.0))
	speed = base_speed
	hero.jump_velocity = float(profile.get("jump_velocity", 7.5))
	if mode:
		mode.profile = profile
		spawner.profile = profile
		spawner.magnet = float(profile.get("star_magnet", 1.0)) * _hero_magnet
		events_spawner.profile = profile
	hud.set_profile(profile_name)
	controls.set_arrows_visible(state == State.RUN and _arrows_on())


func _arrows_on() -> bool:
	return bool(SaveService.setting("arrows", AgeAdapt.current == "young"))


func _joystick_on() -> bool:
	return bool(SaveService.setting("joystick", true))


func _apply_hero(id: String) -> void:
	if not heroes.has(id):
		id = "puf"
	var h: Dictionary = heroes.get(id, {})
	hero.set_hero(id, String(h.get("color", "#FFB84D")), String(h.get("feature", "tuft")))
	Shop.apply_to(hero)


## v1.3: усі світи — біг. "hop"/"float" (HopMode/FloatMode) застаріли й не створюються; "slide" лишився як код на майбутнє.
func _make_mode(kind: String) -> ModeBase:
	match kind:
		"surf": return SurfMode.new()
		"scooter": return ScooterMode.new()
		"float_run": return FloatRunMode.new()
		"slide": return SlideMode.new()
		_: return RunMode.new()


## rebuild_track false — той самий біом, дорогу не перебудовуємо (лише доріжки, якщо змінились); режим/спавнери — завжди.
func _enter_world(id: String, instant: bool, rebuild_track: bool = true) -> void:
	if not worlds.has(id):
		id = String(worlds.keys()[0])
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
	hero.run_speed_factor = 1.0
	hero.set_running(state != State.MENU)
	if rebuild_track:
		track.rebuild(world, not instant, season, lanes)
	elif track.lanes != lanes:
		track.set_lanes(lanes, false)
	hero.set_lanes(lanes)
	if state == State.RUN:
		# зміна біому посеред бігу (дебаг) — камеру переїжджаємо тут; на старті рівня це робить _start_level
		camera_rig.apply(camera_for_lanes(world.get("camera", {}), lanes), 0.8)
	# туман світу (Ліс густіший і темніший, Пляж — морська імла)
	if env.environment:
		env.environment.fog_density = float(world.get("fog_density", DEFAULT_FOG))
	_set_sky(clampf(session_t / session_total, 0.0, 1.0))
	_set_ambient()
	spawner.configure(profile, world, hero, mode, self)
	events_spawner.configure(self, hero, spawner, actors, profile, mode.mode_id())
	hud.set_world(String(world.get("name_uk", id)))
	AudioMgr.music(String(world.get("music", "")))
	Events.world_changed.emit(id)


# ---------- небо, сезон, атмосфера ----------

func _setup_sky() -> void:
	if env.environment == null:
		env.environment = Environment.new()
	var e := env.environment
	# суцільний колір неба (надійно на Mobile) + м'який туман: далекий план тане, стає затишно
	e.background_mode = Environment.BG_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_energy = 0.8
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	e.fog_density = 0.012
	e.fog_sky_affect = 0.0
	e.fog_aerial_perspective = 0.4


## Живе небо: день → вечір протягом сесії (t 0..1); сезон і фішка рівня (ніч/вечір) підфарбовують.
func _set_sky(t: float) -> void:
	var day := Color(String(world.get("sky", "#9BDDFF")))
	var evening := Color(String(world.get("sky_evening", "#F7B58A")))
	if not season.is_empty():
		day = day * Color(String(season.get("sky_tint", "#FFFFFF")))
	if bool(level.get("evening", false)):
		t = maxf(t, 0.8)
	var c := day.lerp(evening, t)
	var energy := lerpf(1.15, 0.7, t)
	if bool(level.get("night", false)):
		c = c.darkened(0.55).lerp(Color("#283593"), 0.5)
		energy = 0.45
	if env.environment:
		env.environment.background_color = c
		env.environment.ambient_light_color = c.lightened(0.35)
		env.environment.fog_light_color = c.lightened(0.2)
	sun.light_energy = energy
	sun.light_color = Color.WHITE.lerp(Color("#FFC59A"), t)
	var want_fireflies := t > 0.6 or bool(level.get("night", false))
	if want_fireflies and _fireflies == null:
		_fireflies = FX.ambient(ambient_root, "fireflies")
	elif not want_fireflies and _fireflies != null:
		_fireflies.queue_free()
		_fireflies = null


func _set_ambient() -> void:
	if _ambient:
		_ambient.queue_free()
		_ambient = null
	if _weather:
		_weather.queue_free()
		_weather = null
	var kind := String(season.get("particles", ""))
	if kind == "":
		kind = "petals"
	if world_id == "clouds":
		kind = "stars"
	elif world_id == "beach":
		kind = "glints"   # відблиски моря
	elif world_id == "forest" and String(season.get("particles", "")) == "":
		kind = "leaves"
	if kind != "":
		_ambient = FX.ambient(ambient_root, kind)
	if bool(level.get("rain", false)):
		_weather = FX.ambient(ambient_root, "rain")


# ---------- стани ----------

func _enter_menu(instant: bool) -> void:
	state = State.MENU
	get_tree().paused = false
	if _countdown_tw:
		_countdown_tw.kill()
		_countdown_tw = null
	hud.hide_finish()
	hud.hide_station()
	controls.set_arrows_visible(false)
	controls.stick_hide()
	spawner.spawning = false
	spawner.clear()
	events_spawner.events_enabled = false
	_end_all_pickups()
	hero.stand()
	hero.set_ground(0.0)
	hero.set_running(false)
	hero.visible = true
	hero.face_camera(true, 0.0 if instant else 0.5)
	hud.set_gameplay_visible(false)
	camera_rig.apply(CameraRig.PRESET_MENU, 0.0 if instant else 0.8)
	menu.show_menu()
	AudioMgr.music("menu")
	get_tree().create_timer(0.6).timeout.connect(func():
		if state == State.MENU:
			hero.wave_hello()
			_daily_gift())


## Подарунок дня: +30 зірочок при першому запуску за день, без таймерів «повернись» (GDD §7).
func _daily_gift() -> void:
	var today := Time.get_date_string_from_system()
	if String(SaveService.child().get("last_gift_day", "")) == today:
		return
	SaveService.child()["last_gift_day"] = today
	Events.star_collected.emit(30)
	SaveService.save_game()
	hud.flash("+30 подарунок дня!", 1.8, Color("#FFD54F"))
	FX.confetti(self, Vector3(0, 1.2, 0), 70)
	hero.cheer()
	AudioMgr.sfx("confetti")
	AudioMgr.voice("gift")


func _on_play() -> void:
	if state != State.MENU:
		return
	menu.hide_menu()
	if bool(profile.get("skip_map", false)):
		_start_level(lm.current())
	else:
		_open_map()


## Кнопка «Мапа» в меню.
func _on_menu_map() -> void:
	if state != State.MENU:
		return
	menu.hide_menu()
	_open_map()


func _open_map() -> void:
	state = State.MAP
	get_tree().paused = false
	hud.hide_finish()
	hud.set_gameplay_visible(false)
	controls.set_arrows_visible(false)
	spawner.spawning = false
	events_spawner.events_enabled = false
	map_screen.open(lm, worlds, hero.color)


func _on_map_closed() -> void:
	if state == State.MAP:
		_enter_menu(false)


## Старт рівня num: біом, доріжки, складність, туторіал → відлік.
func _start_level(num: int) -> void:
	if not lm.get_level(num).is_empty() and not lm.is_open(num):
		# рівень не куплений / попередній не пройдено (GDD v1.3 §3a) — на мапу, там купують за зірочки
		_open_map()
		return
	lm.set_current(num)
	level_num = num
	level = lm.get_level(num)
	if level.is_empty():
		level = lm.get_level(1)
		level_num = 1
	state = State.COUNTDOWN
	get_tree().paused = false
	hud.hide_finish()
	hud.set_gameplay_visible(true)
	lanes = LevelManager.lanes_for(level, profile, 0.0)
	_lanes_changed = false
	level_t = 0.0
	level_duration = float(level.get("duration_sec", 90))
	_slow = 1.0
	_sprint_announced = false
	_gate_spawned = false
	_tutorial_action = ""
	# v1.3: серця, зірочки рівня, пікапи — з нуля
	_end_all_pickups()
	level_coins = 0
	hud.set_tally(0)
	hero.stand()
	hero.set_ground(0.0)
	# характеристики героя (GDD v1.3 §5): серця й швидкість — тут, магніт — після _enter_world (configure скидає його)
	var st := HeroSelect.stats_of(heroes, hero.hero_id)
	hero.max_hearts = int(st.hearts)
	hud.set_max_hearts(hero.max_hearts)   # ряд сердець під героя (3 або 4)
	_hero_speed = float(st.speed)
	_hero_magnet = float(st.magnet)
	hero.reset_hearts()
	Events.hearts_changed.emit(hero.hearts)
	hud.set_speed(0.0)
	var learned = SaveService.child().get("learned", {})   # батьки могли скинути підказки
	_learned = learned if typeof(learned) == TYPE_DICTIONARY else {}
	var wid := String(level.get("world", "meadow"))
	# той самий біом і та сама ширина — дорогу не перебудовуємо (без «перескоку» декору)
	_enter_world(wid, wid == world_id, not (wid == world_id and lanes == track.lanes))
	spawner.magnet = float(profile.get("star_magnet", 1.0)) * _hero_magnet
	# TODO(v1.3 §5): st.luck — частота пікапів живе у Spawner3D._schedule_pickup (Pickup3D.per_minute_total), множника ще нема
	spawner.set_level(level.get("obstacle_types", []), float(level.get("density", 1.0)), lanes, bool(level.get("tutorial", false)))
	spawner.spawning = false
	events_spawner.allowed_ids = level.get("events", [])
	events_spawner.events_enabled = false
	quests.start_segment(AgeAdapt.current)
	hud.set_quest(quests.icon_kind(), 0, quests.target())
	hud.set_world("%d · %s" % [level_num, String(level.get("name_uk", ""))])
	camera_rig.apply(camera_for_lanes(world.get("camera", {}), lanes), 0.8)
	hero.visible = true
	hero.cheer()
	hero.face_camera(false, 0.6)
	get_tree().create_timer(0.6).timeout.connect(func():
		if state == State.COUNTDOWN or state == State.RUN:
			hero.set_running(true))
	AudioMgr.voice("level_%d" % level_num)
	if _countdown_tw:
		_countdown_tw.kill()
	_countdown_tw = create_tween()
	_countdown_tw.tween_interval(0.5)
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
	events_spawner.events_enabled = true
	controls.set_arrows_visible(_arrows_on())
	_idle_t = 0.0
	if not SessionTimer.running:
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
		Shop.apply_to(hero)   # аксесуари могли одягнути без вибору героя
		_enter_menu(false)


# ---------- фініш рівня ----------

func _finish() -> void:
	state = State.FINISH
	get_tree().paused = true
	controls.set_arrows_visible(false)
	controls.stick_hide()
	hero.set_duck(false)
	hero.set_running(false)
	events_spawner.reset()
	_end_all_pickups()
	# зірочки рівня стають справжніми лише тут (перезапуск їх не зберігає)
	SaveService.add_stars(level_coins)
	level_coins = 0
	hud.set_tally(0)
	var stars := LevelManager.stars_for(spawner.stars_collected_segment, spawner.stars_spawned_segment, spawner.hearts_lost_segment)
	var record := lm.complete(level_num, stars)
	SaveService.add_stars(20 + 10 * stars)
	SaveService.child()["checkpoints"] = int(SaveService.child().get("checkpoints", 0)) + 1
	SaveService.save_game()
	Stats.inc("levels_finished")
	Stats.inc("level_%d_stars_%d" % [level_num, stars])
	Stats.flush()
	AudioMgr.sfx("station")
	AudioMgr.voice("level_done" if stars < 3 else "three_stars")
	FX.confetti(self, Vector3(0, 1.2, 0), 60 + 30 * stars)
	Events.checkpoint_reached.emit(level_num)   # AgeAdapt приймає рішення між рівнями
	_finish_auto_t = -20.0   # авто-«Далі» лише після колеса
	if record and stars == 3:
		hud.flash("Три зірочки!", 1.4, Color("#FFD54F"))
	# колесо станції → потім панель із зірками
	_pending_finish = {"stars": stars}
	get_tree().create_timer(1.2).timeout.connect(func():
		if state == State.FINISH:
			wheel.spin())


func _on_wheel_finished(reward: Dictionary) -> void:
	if state != State.FINISH:
		return
	var stars_won := int(reward.get("stars", 0))
	var hat := String(reward.get("hat", ""))
	if stars_won > 0:
		Events.star_collected.emit(stars_won)
	if hat != "":
		Hats.grant(hat)
		Hats.equip(hat)
		Shop.apply_to(hero)
		FX.confetti(self, Vector3(0, 1.2, 0), 60)
	SaveService.save_game()
	_finish_auto_t = 0.0
	hud.show_finish(level_num, int(_pending_finish.get("stars", 1)), _on_finish_next, _open_map, not bool(profile.get("skip_map", false)))


func _on_finish_next() -> void:
	if state != State.FINISH:
		return
	get_tree().paused = false
	hud.hide_finish()
	var next := mini(level_num + 1, lm.count())
	if level_num >= lm.count():
		# фінал: усе пройдено — на мапу для всіх (і малят): будь-який рівень можна грати знову
		_open_map()
		return
	if bool(profile.get("skip_map", false)):
		# малята мапи не бачать — наступний рівень купується сам, якщо вистачає зірочок
		if not lm.is_open(next) and lm.can_buy(next) and SaveService.stars() >= lm.price_of(next):
			lm.buy(next)
			hud.flash("Новий рівень!", 1.2, Color("#FFD54F"))
		if not lm.is_open(next):
			_open_map()
			return
	_start_level(next)


# ---------- цикл ----------

func _process(delta: float) -> void:
	if _parents_open():
		return
	match state:
		State.SLEEP:
			return
		State.MENU, State.HEROES, State.MAP, State.COUNTDOWN, State.RESTART:
			# дорога повільно їде під меню / відліком / паузою «Ще раз!»
			var d := MENU_SPEED * delta
			track.advance(d)
			spawner.advance(d)
			return
		State.FINISH:
			# малюк не тисне «Далі» — гра йде далі сама
			_finish_auto_t += delta
			if _finish_auto_t > FINISH_AUTO_NEXT_SEC and bool(profile.get("skip_map", false)):
				_on_finish_next()
			return
	if switching:
		return
	level_t += delta
	session_t += delta
	var progress := clampf(level_t / level_duration, 0.0, 1.0)
	# розширення дороги посеред рівня — «фішка»
	if not _lanes_changed and level.has("lanes_to") and progress >= float(level.get("lanes_at", 0.5)):
		_lanes_changed = true
		_change_lanes(LevelManager.lanes_for(level, profile, progress))
	# складність: профіль × рівень × розгін до фінішу (+35%) × спринт × сповільнення туторіалу × равлик
	if _slow < 1.0:
		_slow_t -= delta
		if _slow_t <= 0.0:
			_slow = 1.0
	var sprint := 1.0
	if progress >= SPRINT_FROM:
		sprint = SPRINT_MULT
		if not _sprint_announced:
			_sprint_announced = true
			hud.flash("Фініш близько!", 1.0, Color("#FF8A65"))
			AudioMgr.voice("finish_soon")
	speed = base_speed * _hero_speed * float(level.get("speed_mult", 1.0)) * (1.0 + SPEED_RAMP * progress) * sprint * _slow * _pickup_speed
	mode.speed = speed
	spawner.set_speed(speed)
	hud.set_speed(speed)
	_tick_pickups(delta)
	# ворота фінішу — за 6 с до кінця, один раз
	if not _gate_spawned and level_duration - level_t <= GATE_BEFORE_SEC:
		_gate_spawned = true
		spawner.spawn_finish_gate()
	if _pressed and Gestures.hold_started(_held_sec(), _swiped or _stick_used, _holding):
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
	if level_t >= level_duration:
		_finish()


func _change_lanes(n: int) -> void:
	if n == lanes:
		return
	var wider := n > lanes
	lanes = n
	track.set_lanes(n, true)
	hero.set_lanes(n)
	spawner.lanes = n
	camera_rig.apply(camera_for_lanes(world.get("camera", {}), n), 0.9)
	hud.flash("Ширше!" if wider else "Вужче!", 1.0, Color("#80DEEA"))
	AudioMgr.voice("wider")


func _held_sec() -> float:
	return (Time.get_ticks_msec() - _press_time) / 1000.0 if _press_time >= 0.0 else 0.0


func _parents_open() -> bool:
	return is_instance_valid(hud) and bool(hud.get("parents_open"))


func _hero_screen_hit(pos: Vector2) -> bool:
	var sp := camera_rig.cam.unproject_position(hero.global_position + Vector3(0, 0.6, 0))
	return sp.distance_to(pos) < 130.0


# ---------- керування ----------

## Дебаг (лише debug-збірка): 1..5 — біом на льоту, L — наступний рівень, S — фініш зараз, F — веселка, D — друг, Q — завдання, M — мапа.
func _debug_key(event: InputEventKey) -> void:
	if not OS.is_debug_build() or not event.pressed or event.echo:
		return
	var world_keys := {KEY_1: "meadow", KEY_2: "forest", KEY_3: "beach", KEY_4: "city", KEY_5: "clouds"}
	if world_keys.has(event.keycode) and state == State.RUN and worlds.has(world_keys[event.keycode]):
		switching = true
		_enter_world(String(world_keys[event.keycode]), false)
		get_tree().create_timer(WORLD_SWITCH_SEC).timeout.connect(func(): switching = false)
	elif event.keycode == KEY_S and state == State.RUN:
		_finish()
	elif event.keycode == KEY_L and state == State.RUN:
		_start_level(mini(level_num + 1, lm.count()))
	elif event.keycode == KEY_M and state == State.RUN:
		_open_map()
	elif event.keycode == KEY_F and state == State.RUN:
		events_spawner.force("rainbow")
	elif event.keycode == KEY_D and state == State.RUN:
		events_spawner.force("friend")
	elif event.keycode == KEY_Q and state == State.RUN:
		Events.quest_completed.emit("debug", 10)
	elif event.keycode == KEY_W and state == State.RUN:
		_change_lanes(7 if lanes < 7 else 3)
	elif event.keycode == KEY_H and state == State.RUN:
		# дебаг: втратити серце
		if hero.lose_heart():
			Events.hearts_changed.emit(hero.hearts)
			if hero.hearts <= 0:
				_restart_level()
	elif event.keycode == KEY_P and state == State.RUN:
		# дебаг: випадковий пікап негайно
		var kinds: Array = (Pickup3D.load_all().get("kinds", {}) as Dictionary).keys()
		if not kinds.is_empty():
			var k := String(kinds[randi() % kinds.size()])
			on_pickup(k, Pickup3D.def_of(k))


## Жест від будь-якого джерела (свайп / стрілка / джойстик) — одна точка входу.
func _gesture(kind: String, pos: Vector2 = Vector2.ZERO) -> void:
	if state != State.RUN or switching:
		return
	mode.gesture(kind, pos)
	_idle_t = 0.0
	Events.gameplay_input.emit()
	_tutorial_register(kind)


func _on_control_action(kind: String) -> void:
	_gesture(kind, Vector2.ZERO)


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
			_stick_used = false
			_holding = false
			_idle_t = 0.0
			Events.player_input.emit()
			match state:
				State.MENU:
					_pressed = false
					if _hero_screen_hit(event.position):
						hero.pet()
					return
				State.HEROES:
					_pressed = false
					hero_select.tap(event.position)
					return
				State.FINISH:
					_pressed = false
					hero.pet()
					return
				State.COUNTDOWN, State.MAP, State.RESTART:
					_pressed = false
					return
			if _joystick_on():
				controls.stick_show(event.position)
		else:
			var g := Gestures.on_release(_held_sec(), _swiped or _stick_used)
			_pressed = false
			_press_time = -1.0
			_holding = false
			controls.stick_hide()
			if g != "":
				_gesture(g, event.position)
	elif event is InputEventScreenDrag and _pressed:
		_cur_pos = event.position
		var off := _cur_pos - _press_pos
		if _joystick_on() and state == State.RUN:
			controls.stick_update(off)
		if _swiped:
			# джойстик: повернув палець до центру — можна відхиляти ще раз
			if off.length() < STICK_REARM_PX:
				_swiped = false
				_press_time = Time.get_ticks_msec()
			return
		var d := Gestures.swipe_dir(_press_pos, _cur_pos)
		if d != "":
			_swiped = true
			_stick_used = true
			if state == State.HEROES:
				hero_select.move(1 if d == "swipe_left" else (-1 if d == "swipe_right" else 0))
				return
			if _holding:
				_holding = false
				mode.gesture("hold_end", _cur_pos)
			_gesture(d, _cur_pos)


func _release_assist_duck() -> void:
	if not _holding:
		hero.set_duck(false)


## Падіння героя — тряска камери.
func on_tumble() -> void:
	camera_rig.shake(0.1)


## Зірочки під час бігу йдуть у лічильник рівня (у SaveService — на фініші); поза бігом (подарунок, колесо) — одразу.
func _on_star_collected(n: int) -> void:
	if state == State.RUN:
		level_coins += n
		hud.set_tally(level_coins)
		hud.fly_star(camera_rig.cam.unproject_position(hero.global_position + Vector3(0, 0.8, 0)))
	else:
		SaveService.add_stars(n)


# ---------- життя: «Ще раз!» ----------

## Серця скінчились: герой сідає, «Ще раз!», через 2 с рівень починається знову; зірочки рівня не зберігаються.
func _restart_level() -> void:
	if state != State.RUN:
		return
	state = State.RESTART
	spawner.spawning = false
	events_spawner.events_enabled = false
	events_spawner.reset()
	controls.set_arrows_visible(false)
	controls.stick_hide()
	_end_all_pickups()
	hero.set_duck(false)
	hero.sit()
	level_coins = 0
	hud.set_tally(0)
	hud.hide_pickup()
	AudioMgr.voice("again")
	Events.level_restarted.emit(level_num)   # HUD показує «Ще раз!»
	Stats.inc("level_restarts")
	get_tree().create_timer(RESTART_SEC).timeout.connect(func():
		if state == State.RESTART:
			hero.stand()
			_start_level(level_num))


# ---------- пікапи ----------

## Spawner3D: герой підібрав пікап. def — опис із data/pickups.json.
func on_pickup(kind: String, def: Dictionary) -> void:
	if state != State.RUN:
		return
	var sec := float(def.get("seconds", 0.0))
	match kind:
		"snail":
			_pickup_speed = float(def.get("speed_mult", 0.6))
		"heart":
			if hero.gain_heart():
				Events.hearts_changed.emit(hero.hearts)
		"magnet":
			spawner.magnet_wide = true
		"shield":
			hero.set_shield(true)
		"jetpack":
			hero.fly(sec)
			spawner.spawn_star_arc(Hero3D.FLY_HEIGHT + 0.4, 6, hero.lane)
		"coin2":
			spawner.coin_mult = int(def.get("coin_mult", 2))
	if sec > 0.0:
		_effects[kind] = sec
		hud.show_pickup(kind, sec)
	Events.pickup_started.emit(kind, sec)
	hud.flash(String(def.get("name_uk", kind)), 0.8, Color(String(def.get("color", "#FFFFFF"))))
	hero.cheer()
	AudioMgr.voice("wow")


## Spawner3D: щит поглинув удар — ефект закінчується раніше часу.
func on_shield_used() -> void:
	_end_pickup("shield")


func _tick_pickups(delta: float) -> void:
	for k in _effects.keys().duplicate():
		_effects[k] = float(_effects[k]) - delta
		if float(_effects[k]) <= 0.0:
			_end_pickup(String(k))


func _end_pickup(kind: String) -> void:
	match kind:
		"snail": _pickup_speed = 1.0
		"magnet": spawner.magnet_wide = false
		"shield": hero.set_shield(false)
		"jetpack": hero.stop_fly()
		"coin2": spawner.coin_mult = 1
	var was_active := _effects.has(kind)
	_effects.erase(kind)
	if was_active:
		Events.pickup_ended.emit(kind)
	# смужка HUD — для того, що ще діє (найдовшого)
	if _effects.is_empty():
		hud.hide_pickup()
	else:
		var best := ""
		var best_t := -1.0
		for k in _effects.keys():
			if float(_effects[k]) > best_t:
				best_t = float(_effects[k])
				best = String(k)
		hud.show_pickup(best, best_t)


func _end_all_pickups() -> void:
	for k in _effects.keys().duplicate():
		_end_pickup(String(k))
	_pickup_speed = 1.0
	spawner.magnet_wide = false
	spawner.coin_mult = 1
	hero.set_shield(false)
	hero.stop_fly()
	hud.hide_pickup()


# ---------- туторіал і підказки ----------

const ACTION_HINT := {
	"jump": ["up", "Стрибни!", "hint_jump"],
	"duck": ["down", "Присядь!", "hint_duck"],
	"side": ["left", "Убік!", "hint_side"],
}


## Spawner повідомляє про перший спавн типу перешкоди на рівні з туторіалом.
func tutorial_obstacle(kind: String, action: String, free_lane: int = 99) -> void:
	if not ACTION_HINT.has(action) or _learned.has(action):
		return
	var eta := mode.seconds_to_hero(-Spawner3D.SPAWN_Z)
	get_tree().create_timer(maxf(0.1, eta - TUTORIAL_LEAD_SEC), false).timeout.connect(_tutorial_prompt.bind(action, free_lane))


func _tutorial_prompt(action: String, free_lane: int = 99) -> void:
	if state != State.RUN or _learned.has(action):
		return
	_tutorial_action = action
	var h: Array = ACTION_HINT[action]
	var gesture_kind := String(h[0])
	# «убік» — у бік вільної доріжки (якщо відома), інакше до центру
	if action == "side":
		if free_lane != 99 and free_lane != hero.lane:
			gesture_kind = "left" if free_lane < hero.lane else "right"
		else:
			gesture_kind = "left" if hero.lane > 0 else "right"
	hud.show_hint(gesture_kind, String(h[1]))
	AudioMgr.voice(String(h[2]))
	_slow = TUTORIAL_SLOW
	_slow_t = 2.0


## Дитина зробила дію сама: після 2 разів підказка для цієї дії більше не показується.
func _tutorial_register(kind: String) -> void:
	if _tutorial_action == "":
		return
	var ok := false
	match _tutorial_action:
		"jump": ok = kind in ["tap", "swipe_up"]
		"duck": ok = kind in ["swipe_down", "hold_start"]
		"side": ok = kind in ["swipe_left", "swipe_right"]
	if not ok:
		return
	_tutorial_count[_tutorial_action] = int(_tutorial_count.get(_tutorial_action, 0)) + 1
	if int(_tutorial_count[_tutorial_action]) >= 2:
		_learned[_tutorial_action] = true
		SaveService.child()["learned"] = _learned
		hero.cheer()
		AudioMgr.voice("praise")
	_tutorial_action = ""
	_slow = 1.0


## Підказка через N секунд бездіяльності — жест поточного режиму.
func _hint(delta: float) -> void:
	if not mode.wants_hint():
		return
	_idle_t += delta
	if _idle_t > float(profile.get("hint_after_sec", 5)):
		match mode.mode_id():
			"slide": hud.show_hint("hold", "Тримай збоку!")
			_: hud.show_hint("tap", "Тап — стрибок!")
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


## Сумісність із HUD (_run_is_busy).
func _leave_station() -> void:
	pass


var paused_at_station: bool:
	get:
		return state == State.FINISH

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
	if state == State.MENU or state == State.HEROES or state == State.MAP:
		return
	state = State.SLEEP
	get_tree().paused = true
	hud.hide_finish()
	controls.set_arrows_visible(false)
	controls.stick_hide()
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
