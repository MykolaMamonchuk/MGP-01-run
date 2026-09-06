## Спавн перешкод і зірочок за профілем і світом; рух їх разом із дорогою; перевірка зіткнень (AABB, без фізики).
class_name Spawner3D
extends Node3D

const SPAWN_Z := -34.0
const KILL_Z := 4.0
## Тривалість польоту після веселки — коротка, щоб не пропускати зірочки на землі.
const FLY_SEC := 2.6

var profile: Dictionary = {}
var world: Dictionary = {}
var hero: Hero3D
var mode: ModeBase
var run: Node
var speed := 4.0
var magnet := 1.0
## false — дорога їде порожня (меню, відлік).
var spawning := true
var stars_collected_segment := 0
var passed_segment := 0

var _gap_left := 8.0


func configure(p: Dictionary, w: Dictionary, h: Hero3D, m: ModeBase, r: Node) -> void:
	profile = p
	world = w
	hero = h
	mode = m
	run = r
	magnet = float(p.get("star_magnet", 1.0))
	clear()
	_gap_left = 8.0
	stars_collected_segment = 0
	passed_segment = 0


func set_speed(s: float) -> void:
	speed = s


func clear() -> void:
	for c in get_children():
		c.queue_free()


## Зсув усього, що на дорозі, на dist клітинок.
func advance(dist: float) -> void:
	for c in get_children():
		if c is Node3D:
			c.position.z += dist
			if c.position.z > KILL_Z:
				c.queue_free()
	_gap_left -= dist
	if _gap_left <= 0.0:
		if spawning:
			_spawn_group()
		_gap_left = _next_gap()


func _next_gap() -> float:
	var interval: Array = profile.get("obstacle_interval", [2.0, 3.0])
	var sec := randf_range(float(interval[0]), float(interval[1]))
	if mode.mode_id() == "hop":
		return maxf(2.0, sec * 1.2)
	return maxf(2.5, sec * speed)


func _allowed_kinds() -> Array:
	var out := []
	var allowed: Array = profile.get("obstacle_types", [])
	for k in world.get("obstacles", {}).keys():
		if allowed.has(k):
			out.append(k)
	return out


func _spawn_group() -> void:
	var kinds := _allowed_kinds()
	if kinds.is_empty():
		_spawn_stars_line(randi_range(-1, 1), SPAWN_Z, 4)
		return
	var kind := String(kinds[randi() % kinds.size()])
	var def: Dictionary = world["obstacles"][kind]
	var blocked: Array[int] = []
	if kind == "river":
		blocked = _spawn_river(def)
	elif String(def.get("action", "any")) == "side":
		var n := 2 if AgeAdapt.current == "older" and randf() < 0.5 else 1
		var lanes := [-1, 0, 1]
		lanes.shuffle()
		for i in range(n):
			_spawn_obstacle(kind, def, int(lanes[i]))
			blocked.append(int(lanes[i]))
	else:
		var lane := randi_range(-1, 1)
		_spawn_obstacle(kind, def, lane)
		blocked.append(lane)
	# для AgeAdapt: у Стрибках час до перешкоди — це темп дитини, беремо реальний час кроків
	var eta := mode.seconds_to_hero(-SPAWN_Z) if mode.mode_id() != "hop" else -SPAWN_Z * HopMode.STEP_SEC * 3.0
	Events.obstacle_spawned.emit(kind, eta)
	# зірочки — на вільній доріжці трохи далі, щоб «вести» дитину повз перешкоду
	if randf() < 0.75:
		var free_lanes := [-1, 0, 1].filter(func(l): return not blocked.has(l))
		if not free_lanes.is_empty():
			_spawn_stars_line(int(free_lanes[randi() % free_lanes.size()]), SPAWN_Z - 2.0, randi_range(3, 5))


func _spawn_obstacle(kind: String, def: Dictionary, lane: int, with_mesh: bool = true) -> Obstacle3D:
	var o := Obstacle3D.new()
	var assist := randf() < float(profile.get("auto_assist_chance", 0.0))
	o.setup(kind, def, lane, assist, with_mesh)
	o.position.z = SPAWN_Z
	add_child(o)
	return o


## Річка: смужка води через усі доріжки, колоди на 1–2 з них, інші — «дірки» (gap).
func _spawn_river(def: Dictionary) -> Array[int]:
	var water := Mats.box(Vector3(Track.LANES_W + 0.2, 0.12, 1.0), Color(String(world.get("water", "#4FC3F7"))))
	water.position = Vector3(0.0, 0.02, SPAWN_Z)
	add_child(water)
	var lanes := [-1, 0, 1]
	lanes.shuffle()
	var logs := 1 if AgeAdapt.current == "older" else 2
	var gaps: Array[int] = []
	for i in range(3):
		var lane := int(lanes[i])
		if i < logs:
			var log_mesh := VoxelBuilder.instance("log")
			log_mesh.position = Vector3(float(lane) * Hero3D.LANE_W, 0.05, SPAWN_Z)
			add_child(log_mesh)
		else:
			_spawn_obstacle("river", def, lane, false)
			gaps.append(lane)
	return gaps


func _spawn_stars_line(lane: int, z0: float, n: int) -> void:
	for i in range(n):
		spawn_star_at(Vector3(float(lane) * Hero3D.LANE_W, 0.6, z0 - float(i) * 0.9))


func spawn_star_at(pos: Vector3) -> void:
	var s := Star3D.new()
	s.position = pos
	add_child(s)


## Дуга зірочок у повітрі — для польоту (веселка) і великої хвилі. lane 9 — випадкова.
func spawn_star_arc(height: float = 2.6, count: int = 8, lane: int = 9) -> void:
	var fixed := lane != 9
	if not fixed:
		lane = randi_range(-1, 1)
	for i in range(count):
		if not fixed and randf() < 0.3:
			lane = clampi(lane + (1 if randf() < 0.5 else -1), -1, 1)
		var t := float(i) / float(maxi(1, count - 1))
		spawn_star_at(Vector3(float(lane) * Hero3D.LANE_W, height + sin(t * PI) * 0.6, -3.0 - float(i) * 1.2))


## Викликається кожен кадр із Run3D: рух перешкод, зіткнення, збір зірочок, авто-допомога.
func check(delta: float) -> void:
	var hero_box := hero.hit_box()
	for c in get_children():
		if c is Obstacle3D:
			var o := c as Obstacle3D
			o.tick(delta)
			if not o.passed and o.position.z > 0.6:
				o.passed = true
				# у польоті (веселка) перешкоди «пройдені» не рахуються — це не заслуга дитини
				if not o.hit and not hero.flying:
					passed_segment += 1
					Events.obstacle_passed.emit(o.kind)
			if o.auto_assist and not o.hit and o.position.z < 0.0 and -o.position.z < mode.assist_distance():
				o.auto_assist = false
				mode.assist(o)
			if not o.hit and absf(o.position.z) < 1.2 and o.aabb().intersects(hero_box):
				_resolve(o)
		elif c is Rainbow3D:
			var rb := c as Rainbow3D
			if not rb.used and absf(rb.position.z) < 0.4:
				rb.used = true
				if absf(hero.position.x - rb.position.x) < 0.6 and not hero.tumbling:
					hero.fly(FLY_SEC)
					spawn_star_arc(hero.FLY_HEIGHT + 0.4, 6, rb.lane)
					FX.confetti(self, Vector3(rb.position.x, 1.0, 0.0), 30)
					AudioMgr.voice("wow")
		elif c is Star3D:
			var s := c as Star3D
			if not s.collected and absf(s.position.z) < 3.0 and s.tick(delta, hero, magnet):
				s.collect()
				stars_collected_segment += 1
				FX.burst(self, s.position)
				Events.star_collected.emit(1)
				AudioMgr.sfx("star", 1.0 + 0.08 * float(stars_collected_segment % 3))
				if stars_collected_segment % 10 == 0:
					hero.cheer()
					AudioMgr.voice("praise")


func _resolve(o: Obstacle3D) -> void:
	o.hit = true
	if o.action == "any" or not o.tumble:
		o.splash()
		FX.splash(self, Vector3(hero.position.x, 0.1, 0.0), Color("#90CAF9") if o.kind == "puddle" else Color("#A5D6A7"))
		AudioMgr.sfx("splash")
		return
	if hero.tumbling or hero.flying:
		return
	hero.tumble()
	Events.hero_tumbled.emit(o.kind)
	AudioMgr.sfx("tumble")
	AudioMgr.voice("oops")
	if run.has_method("on_tumble"):
		run.call("on_tumble")
	# у Стрибках будь-яке падіння — відкат на клітинку (GDD §3); в інших режимах pushback нічого не робить
	if run.has_method("pushback"):
		run.call("pushback")
	_clear_ahead(2.0)


## Після падіння дорога на N секунд чиста — дитина встигає оговтатись.
func _clear_ahead(seconds: float) -> void:
	for c in get_children():
		if c is Obstacle3D and not (c as Obstacle3D).hit and c.position.z < 0.0 and mode.seconds_to_hero(-c.position.z) < seconds:
			c.queue_free()
