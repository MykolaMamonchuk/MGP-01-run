## Спавнер перешкод і зірочок. Усі параметри — з профілю (data/profiles.json) і світу (data/worlds/*.json).
extends Node2D

const SPAWN_X := 1400.0
const GROUND_Y := 600.0

var profile: Dictionary = {}
var world: Dictionary = {}
var speed := 400.0
var _next_obstacle := 2.0
var _next_stars := 1.0
var _rng := RandomNumberGenerator.new()
var hero: Node2D

func _ready() -> void:
	_rng.randomize()

func configure(p: Dictionary, w: Dictionary, spd: float, h: Node2D) -> void:
	profile = p
	world = w
	speed = spd
	hero = h

func set_speed(s: float) -> void:
	speed = s
	for n in get_children():
		if "speed" in n:
			n.speed = s

func _process(delta: float) -> void:
	if profile.is_empty():
		return
	_next_obstacle -= delta
	_next_stars -= delta
	if _next_obstacle <= 0.0:
		_spawn_obstacle()
		var iv: Array = profile["obstacle_interval"]
		_next_obstacle = _rng.randf_range(float(iv[0]), float(iv[1]))
	if _next_stars <= 0.0:
		_spawn_stars()
		_next_stars = _rng.randf_range(1.5, 3.0)

func _spawn_obstacle() -> void:
	var types: Array = profile["obstacle_types"]
	var kind := String(types[_rng.randi_range(0, types.size() - 1)])
	var cfg: Dictionary = world["obstacles"][kind]
	var o := Obstacle.new()
	o.position = Vector2(SPAWN_X, GROUND_Y)
	add_child(o)
	var hero_x := hero.global_position.x if hero else 340.0
	o.setup(kind, cfg, speed, _rng.randf() < float(profile["auto_assist_chance"]), hero_x)
	Events.obstacle_spawned.emit(kind, o)

func _spawn_stars() -> void:
	var n := _rng.randi_range(3, 5)
	var high := _rng.randf() < 0.4
	var base_y := GROUND_Y - (230.0 if high else 120.0)
	for i in n:
		var s := Star.new()
		var arc := -sin(float(i) / max(1, n - 1) * PI) * 60.0 if high else 0.0
		s.position = Vector2(SPAWN_X + 200.0 + i * 90.0, base_y + arc)
		add_child(s)
		s.setup(speed, float(profile["star_magnet"]), hero)
