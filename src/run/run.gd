## Головна сцена бігу. Керує профілем, швидкістю, авто-допомогою, станціями, сном.
extends Node2D

## Тап коротший за цей час — стрибок; довший — це був присід.
const TAP_MAX_SEC := 0.25

@onready var hero: Hero = $Hero
@onready var spawner: Node2D = $Spawner
@onready var hud: CanvasLayer = $HUD
@onready var sky: ColorRect = $Sky
@onready var ground_shape: CollisionShape2D = $Ground/Shape

var profiles: Dictionary = {}
var profile: Dictionary = {}
var world: Dictionary = {}
var base_speed := 400.0
var speed := 400.0
var run_time := 0.0
var checkpoint_t := 0.0
var checkpoint_seconds := 90.0
var checkpoint_index := 0
var paused_at_station := false
var sleeping := false

var _press_time := -1.0
var _pressed := false
var _idle_t := 0.0

func _ready() -> void:
	# сцена бігу має обробляти ввід і на паузі (щоб вийти зі станції/сну)
	process_mode = Node.PROCESS_MODE_ALWAYS

	var rs := RectangleShape2D.new()
	rs.size = Vector2(2000, 200)
	ground_shape.shape = rs
	ground_shape.position = Vector2(0, 100)

	profiles = AgeAdapt.load_profiles()
	checkpoint_seconds = float(profiles.get("checkpoint_seconds", 90))
	world = _load_json("res://data/worlds/meadow.json")
	sky.color = Color(String(world["sky"]))
	_apply_profile(AgeAdapt.current)

	Events.profile_changed.connect(_apply_profile)
	Events.session_warning.connect(_on_session_warning)
	Events.session_finished.connect(_on_session_finished)
	Events.star_collected.connect(_on_star_collected)
	hero.landed.connect(_on_hero_landed)

	SessionTimer.start(float(SaveService.setting("session_minutes", 10)))
	AudioMgr.music(String(world.get("music", "")))
	AudioMgr.voice("hello")

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else {}
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _on_star_collected(n: int) -> void:
	SaveService.add_stars(n)

func _on_hero_landed() -> void:
	AudioMgr.sfx("land")

func _apply_profile(profile_name: String) -> void:
	profile = profiles.get(profile_name, profiles.get("young", {}))
	base_speed = float(profile["speed"])
	speed = base_speed
	hero.jump_velocity = float(profile["jump_velocity"])
	spawner.configure(profile, world, speed, hero)
	hud.set_profile(profile_name)

func _process(delta: float) -> void:
	if sleeping or paused_at_station or _parents_open():
		return
	run_time += delta
	checkpoint_t += delta
	# м'який розгін у межах забігу
	var ramp := float(profile.get("speed_ramp", 0.2))
	speed = base_speed * (1.0 + ramp * clamp(checkpoint_t / 60.0, 0.0, 1.0))
	spawner.set_speed(speed)
	_auto_assist()
	_hint(delta)
	# утримання → присід
	if _pressed and _press_time >= 0.0 and (Time.get_ticks_msec() - _press_time) / 1000.0 > TAP_MAX_SEC:
		hero.set_duck(true)
	# станція
	if checkpoint_t >= checkpoint_seconds:
		_station()

func _parents_open() -> bool:
	return is_instance_valid(hud) and bool(hud.get("parents_open"))

func _unhandled_input(event: InputEvent) -> void:
	if sleeping or _parents_open():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press()
		else:
			_on_release()

func _on_press() -> void:
	_pressed = true
	_press_time = Time.get_ticks_msec()
	_idle_t = 0.0
	Events.player_input.emit()
	if paused_at_station:
		_leave_station()
		return
	Events.gameplay_input.emit()

func _on_release() -> void:
	var held := 0.0
	if _press_time >= 0.0:
		held = (Time.get_ticks_msec() - _press_time) / 1000.0
	_pressed = false
	_press_time = -1.0
	# присід завжди знімається на відпусканні — і після утримання, і після тапу
	hero.set_duck(false)
	if held <= TAP_MAX_SEC:
		# короткий тап — стрибок
		hero.jump()
		AudioMgr.sfx("jump")

## Авто-допомога для малюків: частина перешкод герой долає сам.
func _auto_assist() -> void:
	for o in spawner.get_children():
		if o is Obstacle and o.auto_assist and not o._hit:
			var dist: float = o.global_position.x - hero.global_position.x
			if dist > 0.0 and dist < speed * 0.42:
				if o.kind == "branch":
					hero.set_duck(true)
					get_tree().create_timer(0.7).timeout.connect(_release_assist_duck)
				else:
					hero.jump()
				o.auto_assist = false

func _release_assist_duck() -> void:
	if not _pressed:
		hero.set_duck(false)

## Підказка через N секунд бездіяльності (герой «показує лапкою» — поки HUD-стрілка).
func _hint(delta: float) -> void:
	_idle_t += delta
	if _idle_t > float(profile.get("hint_after_sec", 5)):
		hud.show_hint()
		AudioMgr.voice("hint_tap")
		_idle_t = 0.0

func _station() -> void:
	paused_at_station = true
	get_tree().paused = true
	checkpoint_t = 0.0
	checkpoint_index += 1
	SaveService.add_stars(20)
	SaveService.save_game()
	Stats.flush()
	AudioMgr.sfx("station")
	AudioMgr.voice("station")
	hud.show_station(checkpoint_index)
	Events.checkpoint_reached.emit(checkpoint_index)

func _leave_station() -> void:
	paused_at_station = false
	get_tree().paused = false
	hud.hide_station()

func _on_session_warning(seconds_left: int) -> void:
	if seconds_left == 120:
		AudioMgr.voice("yawn")
		hud.show_yawn()
	elif seconds_left == 60:
		AudioMgr.voice("almost_sleep")

func _on_session_finished() -> void:
	sleeping = true
	get_tree().paused = true
	hero.set_duck(false)
	SaveService.save_game()
	Stats.flush()
	AudioMgr.music("lullaby")
	AudioMgr.voice("goodnight")
	hud.show_sleep(_on_sleep_continue_pressed)

func _on_sleep_continue_pressed() -> void:
	# продовжити — лише через батьків
	ParentGate.request("settings", _resume_after_sleep)

func _resume_after_sleep() -> void:
	sleeping = false
	get_tree().paused = false
	hud.hide_sleep()
	SessionTimer.start(float(SaveService.setting("session_minutes", 10)))
