## Спавн перешкод і зірочок за профілем, світом і рівнем; рух їх разом із дорогою; зіткнення (AABB, без фізики).
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
## Кількість доріжок (з рівня).
var lanes := 3
## Обмеження рівня: дозволені типи перешкод (порожньо — за профілем) і множник інтервалу (<1 — частіше).
var level_types: Array = []
var density := 1.0
## Туторіал: перший спавн кожного типу повідомляє Run3D.
var tutorial := false

var stars_collected_segment := 0
var stars_spawned_segment := 0
var passed_segment := 0
var tumbles_segment := 0

var _gap_left := 8.0
var _min_next_gap := 0.0
var _seen_kinds: Dictionary = {}


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
	stars_spawned_segment = 0
	passed_segment = 0
	tumbles_segment = 0
	finish_pending = false
	_seen_kinds.clear()


func set_level(types: Array, dens: float, n_lanes: int, tut: bool) -> void:
	level_types = types
	density = maxf(0.4, dens)
	lanes = n_lanes
	tutorial = tut
	finish_pending = false


func set_speed(s: float) -> void:
	speed = s


func clear() -> void:
	for c in get_children():
		c.queue_free()


func max_lane() -> int:
	return (lanes - 1) / 2


func lane_list() -> Array:
	var out := []
	for l in range(-max_lane(), max_lane() + 1):
		out.append(l)
	return out


func random_lane() -> int:
	return randi_range(-max_lane(), max_lane())


## Зсув усього, що на дорозі, на dist клітинок.
func advance(dist: float) -> void:
	for c in get_children():
		if c is Node3D:
			c.position.z += dist
			if c.position.z > KILL_Z:
				c.queue_free()
	_gap_left -= dist
	if _gap_left <= 0.0:
		_min_next_gap = 0.0
		if spawning:
			_spawn_group()
		_gap_left = maxf(_next_gap(), _min_next_gap)


func _next_gap() -> float:
	var interval: Array = profile.get("obstacle_interval", [2.0, 3.0])
	var sec := randf_range(float(interval[0]), float(interval[1])) * density
	if mode.is_stepwise():
		return maxf(2.0, sec * 1.2)
	return maxf(2.5, sec * speed)


## Рівень задає набір перешкод; порожній список — усі перешкоди біому (рівень важливіший за профіль).
func _allowed_kinds() -> Array:
	var world_kinds: Array = world.get("obstacles", {}).keys()
	if level_types.is_empty():
		return world_kinds
	return world_kinds.filter(func(k): return level_types.has(k))


## Група перешкод: ОДНА вільна доріжка, решта перекриті (young — лише половина), зірочки ведуть у вільну.
## Кожна перекрита доріжка проходиться дією (стрибок/присід/убік…); у групі не більше 2 різних видів — читабельно.
func _spawn_group() -> void:
	var kinds := _allowed_kinds()
	if kinds.is_empty() or finish_pending:
		_spawn_stars_line(random_lane(), SPAWN_Z, 4)
		return
	var kind := String(kinds[randi() % kinds.size()])
	var def: Dictionary = world["obstacles"][kind]
	var free_lanes: Array = []
	var used_kinds: Array = [kind]
	if kind == "river":
		var gaps := _spawn_river(def)
		free_lanes = lane_list().filter(func(l): return not gaps.has(l))
	else:
		var free_lane := random_lane()
		free_lanes = [free_lane]
		# другий вид — для різноманіття, але не річка
		var others := kinds.filter(func(k): return String(k) != kind and String(k) != "river")
		if not others.is_empty() and randf() < 0.6:
			used_kinds.append(String(others[randi() % others.size()]))
		var to_block := lane_list().filter(func(l): return l != free_lane)
		if AgeAdapt.current == "young":
			# малятам — лише половина доріжок перекрита
			to_block.shuffle()
			to_block = to_block.slice(0, ceili(float(lanes - 1) / 2.0))
		var mover_placed := false
		for l in to_block:
			var k := String(used_kinds[randi() % used_kinds.size()])
			var d: Dictionary = world["obstacles"][k]
			if bool(d.get("moves", false)):
				# перебігаючий (їжачок/краб) — один на групу, інакше хаос
				if mover_placed:
					var alt := used_kinds.filter(func(x): return not bool((world["obstacles"][x] as Dictionary).get("moves", false)))
					if alt.is_empty():
						continue
					k = String(alt[0])
					d = world["obstacles"][k]
				else:
					mover_placed = true
			var ob := _spawn_obstacle(k, d, int(l))
			ob.free_lane = free_lane   # авто-допомога й підказка «убік» знають, куди саме
	# туторіал: перший спавн кожного виду
	for k in used_kinds:
		var kd: Dictionary = world["obstacles"][k]
		if tutorial and not _seen_kinds.has(k) and run.has_method("tutorial_obstacle"):
			run.call("tutorial_obstacle", k, String(kd.get("action", "any")), int(free_lanes[0]) if not free_lanes.is_empty() else 99)
		_seen_kinds[k] = true
	Events.obstacle_spawned.emit(kind, mode.seconds_to_hero(-SPAWN_Z))
	# зірочки — лише на вільній доріжці (на річці — на колоді), трохи далі: «ведуть» дитину повз перешкоду
	if not free_lanes.is_empty():
		var n := randi_range(3, 5)
		_spawn_stars_line(int(free_lanes[randi() % free_lanes.size()]), SPAWN_Z - 2.0, n)
		# наступна група — не раніше, ніж закінчиться лінія зірочок (advance() врахує)
		_min_next_gap = 2.0 + float(n) * 0.9 + 1.5


# ---------- фініш ----------

## Ворота фінішу вже їдуть — нових перешкод не ставимо, лише зірочки.
var finish_pending := false


## Ворота фінішу: спавняться за ~5 с шляху до героя, їдуть із дорогою, не збивають.
func spawn_finish_gate() -> void:
	finish_pending = true
	var gate := FinishGate3D.new()
	gate.setup(lanes)
	# скільки клітинок пройде світ за 5 с у цьому режимі (не далі за SPAWN_Z, не ближче 6)
	var cells_per_sec := 1.0 / maxf(0.05, mode.seconds_to_hero(1.0))
	if mode.is_stepwise():
		cells_per_sec = 1.0   # у Стрибках рахуємо лише дрейф — ворота точно доїдуть до фінішу
	gate.position.z = -clampf(cells_per_sec * 5.0, 6.0, -SPAWN_Z)
	add_child(gate)
	# перешкоди за ворітьми прибираємо — після фінішу падати не можна
	for c in get_children():
		if c is Obstacle3D and c.position.z < gate.position.z:
			c.queue_free()


func _spawn_obstacle(kind: String, def: Dictionary, lane: int, with_mesh: bool = true) -> Obstacle3D:
	var o := Obstacle3D.new()
	var assist := randf() < float(profile.get("auto_assist_chance", 0.0))
	o.setup(kind, def, lane, assist, with_mesh)
	o.range_x = float(max_lane()) * Hero3D.LANE_W + 0.6
	o.position.z = SPAWN_Z
	add_child(o)
	return o


## Річка: смужка води через усі доріжки, колоди на частині з них, інші — «дірки» (gap).
func _spawn_river(def: Dictionary) -> Array:
	var width := float(lanes) * Hero3D.LANE_W + 0.2
	var water := Mats.box(Vector3(width, 0.12, 1.0), Color(String(world.get("water", "#4FC3F7"))))
	water.position = Vector3(0.0, 0.02, SPAWN_Z)
	add_child(water)
	var pool := lane_list()
	pool.shuffle()
	var logs := maxi(1, lanes / 2) if AgeAdapt.current == "older" else maxi(2, (lanes * 2) / 3)
	var gaps: Array = []
	for i in range(pool.size()):
		var lane := int(pool[i])
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
	stars_spawned_segment += 1


## Дуга зірочок у повітрі — для польоту (веселка) і великої хвилі. lane 99 — випадкова.
func spawn_star_arc(height: float = 2.6, count: int = 8, lane: int = 99) -> void:
	var fixed := lane != 99
	if not fixed:
		lane = random_lane()
	for i in range(count):
		if not fixed and randf() < 0.3:
			lane = clampi(lane + (1 if randf() < 0.5 else -1), -max_lane(), max_lane())
		var t := float(i) / float(maxi(1, count - 1))
		spawn_star_at(Vector3(float(lane) * Hero3D.LANE_W, height + sin(t * PI) * 0.6, -3.0 - float(i) * 1.2))


## Викликається кожен кадр із Run3D: рух перешкод, зіткнення, збір зірочок, авто-допомога, веселка.
func check(delta: float) -> void:
	var hero_box := hero.hit_box()
	for c in get_children():
		if c is Obstacle3D:
			var o := c as Obstacle3D
			o.tick(delta)
			if not o.passed and o.position.z > 0.6:
				o.passed = true
				if not o.hit and not hero.flying:
					passed_segment += 1
					Events.obstacle_passed.emit(o.kind)
			if o.auto_assist and not o.hit and o.position.z < 0.0 and -o.position.z < mode.assist_distance() \
					and absf(o.position.x - hero.position.x) < 0.6:
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
		elif c is FinishGate3D:
			# герой пробіг під воротами — конфеті й звук фінішу (сам фініш — за часом у Run3D)
			var g := c as FinishGate3D
			if not g.passed and g.position.z > 0.0:
				g.passed = true
				FX.confetti(self, Vector3(hero.position.x, 1.6, 0.0), 90)
				AudioMgr.sfx("finish")
				hero.cheer()
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
	match o.action:
		"boost":
			# трамплін: довгий політ + зірочки дугою (лише якщо герой справді відштовхнувся)
			if not hero.tumbling and hero.jump(1.55):
				spawn_star_arc(2.0, 5, o.lane)
				FX.confetti(self, Vector3(hero.position.x, 0.5, 0.0), 20)
				AudioMgr.sfx("boost")
				AudioMgr.voice("wheee")
			return
		"rail":
			# рейка: іскри й бонус
			FX.burst(self, Vector3(hero.position.x, 0.3, 0.0), Color("#FFF176"))
			Events.star_collected.emit(3)
			stars_collected_segment += 3
			stars_spawned_segment += 3   # бонус не ламає відсоток зібраного
			AudioMgr.sfx("rail")
			return
		"wind":
			# вітер зносить на сусідню доріжку — без падіння
			var dir := 1 if hero.lane <= 0 else -1
			hero.change_lane(dir)
			hero.tilt(-0.4 * float(dir))
			get_tree().create_timer(0.4).timeout.connect(func(): hero.tilt(0.0))
			AudioMgr.sfx("wind")
			AudioMgr.voice("whoa")
			return
	if o.action == "any" or not o.tumble:
		o.splash()
		FX.splash(self, Vector3(hero.position.x, 0.1, 0.0), Color("#90CAF9") if o.kind == "puddle" else Color("#A5D6A7"))
		AudioMgr.sfx("splash")
		return
	if hero.tumbling or hero.flying:
		return
	hero.tumble()
	tumbles_segment += 1
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
