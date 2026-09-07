## Спавн перешкод, зірочок, пікапів і сегментів другого рівня за профілем, світом і рівнем;
## рух їх разом із дорогою; зіткнення (AABB, без фізики); життя героя (GDD v1.3).
class_name Spawner3D
extends Node3D

const SPAWN_Z := -34.0
const KILL_Z := 4.0
## Тривалість польоту після веселки — коротка, щоб не пропускати зірочки на землі.
const FLY_SEC := 2.6
## Зірочки — лише за групою перешкод у вільній доріжці: перша на SPAWN_Z-1.2, остання не далі SPAWN_Z-4.
const STARS_BEHIND_MIN := 1.2
const STARS_BEHIND_MAX := 4.0
const STAR_STEP := 0.9
## Пікап їде за лінією зірочок у тій самій вільній доріжці.
const PICKUP_BEHIND := 5.5
## Сегмент другого рівня — кожні 25–40 с у світах із "tier2": true.
const TIER2_INTERVAL := [25.0, 40.0]
## Невразливість після удару.
const INVULN_SEC := 1.5

var profile: Dictionary = {}
var world: Dictionary = {}
var hero: Hero3D
var mode: ModeBase
var run: Node
var speed := 4.0
var magnet := 1.0
## Пікап «магніт»: зірочки тягнуться з сусідніх доріжок.
var magnet_wide := false
## Пікап «×2»: множник зірочок.
var coin_mult := 1
## false — дорога їде порожня (меню, відлік).
var spawning := true
## Кількість доріжок (з рівня).
var lanes := 3
## Обмеження рівня: дозволені типи перешкод (порожньо — всі біому) і множник інтервалу (<1 — частіше).
var level_types: Array = []
var density := 1.0
## Туторіал: перший спавн кожного типу повідомляє Run3D.
var tutorial := false

var stars_collected_segment := 0
var stars_spawned_segment := 0
var passed_segment := 0
## Втрачених сердець на рівні — для зірок фінішу (замість падінь).
var hearts_lost_segment := 0

var _gap_left := 8.0
var _min_next_gap := 0.0
var _seen_kinds: Dictionary = {}
## Малятам перше зіткнення на рівні прощається.
var _forgiven := false
## Пікапи: дані, таймер до наступного, вид, що чекає на вільну доріжку.
var _pickups: Dictionary = {}
var _pickup_t := 20.0
var _pickup_pending := ""
## Другий рівень: активний сегмент і таймер до наступного.
var _tier2: Tier2Segment
var _tier2_t := 30.0
var _tier2_due := false


func _ready() -> void:
	_pickups = Pickup3D.load_all()


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
	hearts_lost_segment = 0
	finish_pending = false
	_forgiven = false
	_seen_kinds.clear()
	_pickup_pending = ""
	_schedule_pickup()
	_tier2 = null
	_tier2_due = false
	_tier2_t = randf_range(float(TIER2_INTERVAL[0]), float(TIER2_INTERVAL[1]))
	magnet_wide = false
	coin_mult = 1


func set_level(types: Array, dens: float, n_lanes: int, tut: bool) -> void:
	level_types = types
	density = maxf(0.4, dens)
	lanes = n_lanes
	tutorial = tut
	finish_pending = false
	_forgiven = false
	hearts_lost_segment = 0


func set_speed(s: float) -> void:
	speed = s


func clear() -> void:
	for c in get_children():
		c.queue_free()
	_tier2 = null


func max_lane() -> int:
	return (lanes - 1) / 2


func lane_list() -> Array:
	var out := []
	for l in range(-max_lane(), max_lane() + 1):
		out.append(l)
	return out


func random_lane() -> int:
	return randi_range(-max_lane(), max_lane())


## Доріжки, зайняті платформою другого рівня (на них перешкод не ставимо) —
## лише поки сегмент ще перекриває лінію спавну (його ближній кінець ще не проїхав SPAWN_Z).
func _tier2_lanes() -> Array:
	if is_instance_valid(_tier2) and _tier2.position.z + _tier2.total_length() > SPAWN_Z:
		return _tier2.lanes_used
	return []


## Зсув усього, що на дорозі, на dist клітинок.
func advance(dist: float) -> void:
	for c in get_children():
		if c is Node3D:
			c.position.z += dist
			if c.position.z > KILL_Z:
				if c == _tier2:
					_tier2 = null
				c.queue_free()
	_gap_left -= dist
	if _gap_left <= 0.0:
		_min_next_gap = 0.0
		if spawning and not finish_pending:
			if _tier2_due and (_tier2 == null or not is_instance_valid(_tier2)):
				_spawn_tier2()
			else:
				_spawn_group()
		_gap_left = maxf(_next_gap(), _min_next_gap)


func _next_gap() -> float:
	var interval: Array = profile.get("obstacle_interval", [2.0, 3.0])
	var sec := randf_range(float(interval[0]), float(interval[1])) * density
	return maxf(2.5, sec * speed)


## Рівень задає набір перешкод; порожній список — усі перешкоди біому (рівень важливіший за профіль).
func _allowed_kinds() -> Array:
	var world_kinds: Array = world.get("obstacles", {}).keys()
	if level_types.is_empty():
		return world_kinds
	return world_kinds.filter(func(k): return level_types.has(k))


## Група перешкод: ОДНА вільна доріжка, решта перекриті (young — лише половина), зірочки — суворо за групою у вільній.
## Кожна перекрита доріжка проходиться дією (стрибок/присід/убік…); у групі не більше 2 різних видів — читабельно.
## Доріжки платформи другого рівня не перекриваємо. Без перешкод (порожній список) — нічого не ставимо.
func _spawn_group() -> void:
	var kinds := _allowed_kinds()
	if kinds.is_empty() or finish_pending:
		return
	var t2 := _tier2_lanes()
	var candidates := lane_list().filter(func(l): return not t2.has(l))
	if candidates.is_empty():
		return
	var kind := String(kinds[randi() % kinds.size()])
	var used_kinds: Array = [kind]
	var free_lane := int(candidates[randi() % candidates.size()])
	# другий вид — для різноманіття
	var others := kinds.filter(func(k): return String(k) != kind)
	if not others.is_empty() and randf() < 0.6:
		used_kinds.append(String(others[randi() % others.size()]))
	var to_block := candidates.filter(func(l): return l != free_lane)
	if AgeAdapt.current == "young":
		# малятам — лише половина доріжок перекрита
		to_block.shuffle()
		to_block = to_block.slice(0, ceili(float(to_block.size()) / 2.0))
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
			run.call("tutorial_obstacle", k, String(kd.get("action", "any")), free_lane)
		_seen_kinds[k] = true
	Events.obstacle_spawned.emit(kind, mode.seconds_to_hero(-SPAWN_Z))
	# зірочки — лише у вільній доріжці й лише ЗА групою: «ведуть» дитину повз перешкоду
	var n := randi_range(3, 4)
	_spawn_stars_line(free_lane, SPAWN_Z - STARS_BEHIND_MIN, n)
	var tail := STARS_BEHIND_MIN + float(n - 1) * STAR_STEP
	# пікап, що чекає, — у тій самій вільній доріжці за зірочками
	if _pickup_pending != "":
		_spawn_pickup(_pickup_pending, free_lane, SPAWN_Z - PICKUP_BEHIND)
		_pickup_pending = ""
		tail = PICKUP_BEHIND + 0.5
	# наступна група — не раніше, ніж закінчиться хвіст зірочок/пікапа (advance() врахує)
	_min_next_gap = tail + 2.0


# ---------- фініш ----------

## Ворота фінішу вже їдуть — нічого нового не ставимо.
var finish_pending := false


## Ворота фінішу: спавняться за ~5 с шляху до героя, їдуть із дорогою, не збивають.
func spawn_finish_gate() -> void:
	finish_pending = true
	var gate := FinishGate3D.new()
	gate.setup(lanes)
	# скільки клітинок пройде світ за 5 с у цьому режимі (не далі за SPAWN_Z, не ближче 6)
	var cells_per_sec := 1.0 / maxf(0.05, mode.seconds_to_hero(1.0))
	gate.position.z = -clampf(cells_per_sec * 5.0, 6.0, -SPAWN_Z)
	add_child(gate)
	# перешкоди за ворітьми прибираємо — після фінішу падати не можна
	for c in get_children():
		if (c is Obstacle3D or c is Tier2Segment) and c.position.z < gate.position.z:
			if c == _tier2:
				_tier2 = null
			c.queue_free()


func _spawn_obstacle(kind: String, def: Dictionary, lane: int, with_mesh: bool = true) -> Obstacle3D:
	var o := Obstacle3D.new()
	var assist := randf() < float(profile.get("auto_assist_chance", 0.0))
	o.setup(kind, def, lane, assist, with_mesh)
	o.range_x = float(max_lane()) * Hero3D.LANE_W + 0.6
	o.position.z = SPAWN_Z
	add_child(o)
	return o


func _spawn_stars_line(lane: int, z0: float, n: int, y: float = 0.6, value: int = 1) -> void:
	for i in range(n):
		spawn_star_at(Vector3(float(lane) * Hero3D.LANE_W, y, z0 - float(i) * STAR_STEP), value)


## Зірочка у позиції; value 2 — подвійна (платформа другого рівня).
func spawn_star_at(pos: Vector3, value: int = 1) -> void:
	var s := Star3D.new()
	s.value = value
	s.position = pos
	add_child(s)
	stars_spawned_segment += 1


## Дуга зірочок у повітрі — для польоту (веселка, ракета) і великої хвилі. lane 99 — випадкова.
func spawn_star_arc(height: float = 2.6, count: int = 8, lane: int = 99) -> void:
	var fixed := lane != 99
	if not fixed:
		lane = random_lane()
	for i in range(count):
		if not fixed and randf() < 0.3:
			lane = clampi(lane + (1 if randf() < 0.5 else -1), -max_lane(), max_lane())
		var t := float(i) / float(maxi(1, count - 1))
		spawn_star_at(Vector3(float(lane) * Hero3D.LANE_W, height + sin(t * PI) * 0.6, -3.0 - float(i) * 1.2))


# ---------- пікапи ----------

func _schedule_pickup() -> void:
	var total := Pickup3D.per_minute_total(_pickups, AgeAdapt.current)
	if total <= 0.0:
		_pickup_t = 1e9
		return
	_pickup_t = (60.0 / total) * randf_range(0.7, 1.3)


## Таймер пікапів: коли час настав — обираємо вид, він чекає на найближчу вільну доріжку.
func _tick_pickups(delta: float) -> void:
	if _pickups.is_empty() or _pickup_pending != "" or finish_pending:
		return
	_pickup_t -= delta
	if _pickup_t > 0.0:
		return
	_schedule_pickup()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var base := float(profile.get("speed", 4.0))
	var exclude := []
	if hero.hearts >= hero.max_hearts:
		exclude.append("heart")
	_pickup_pending = Pickup3D.pick_kind(_pickups, AgeAdapt.current, speed / maxf(0.1, base), exclude, rng)


func _spawn_pickup(kind: String, lane: int, z: float) -> void:
	var p := Pickup3D.new()
	p.position = Vector3(float(lane) * Hero3D.LANE_W, 0.0, z)
	add_child(p)
	p.setup(kind)


# ---------- другий рівень ----------

func _tick_tier2(delta: float) -> void:
	if not bool(world.get("tier2", false)) or finish_pending:
		return
	if _tier2 != null and is_instance_valid(_tier2):
		return
	if _tier2_due:
		return
	_tier2_t -= delta
	if _tier2_t <= 0.0:
		_tier2_due = true


## Сегмент другого рівня замість чергової групи: платформа на 1–2 доріжках, подвійні зірочки на ній.
func _spawn_tier2() -> void:
	_tier2_due = false
	_tier2_t = randf_range(float(TIER2_INTERVAL[0]), float(TIER2_INTERVAL[1]))
	var lane := random_lane()
	var used: Array = [lane]
	if lanes >= 5 and randf() < 0.5:
		var second := clampi(lane + (1 if lane < max_lane() else -1), -max_lane(), max_lane())
		if second != lane:
			used.append(second)
	var seg := Tier2Segment.new()
	seg.setup(used, randf_range(10.0, 16.0))
	# початок координат — дальній кінець; ближній пандус починається на SPAWN_Z
	seg.position.z = SPAWN_Z - seg.total_length()
	add_child(seg)
	_tier2 = seg
	# подвійні зірочки на платформі
	var z0 := seg.platform_z0() + 0.6
	var n := int((seg.length - 1.2) / 1.2)
	for l in used:
		for i in range(n):
			spawn_star_at(Vector3(float(l) * Hero3D.LANE_W, Tier2Segment.H + 0.6, z0 + float(i) * 1.2), 2)
	# наступна група — коли ближній пандус уже проїхав повз точку спавну
	_min_next_gap = 3.0


## Земля під героєм: платформа/пандус або 0. Авто-підскок на початку пандуса вгору.
func _tick_ground() -> void:
	if _tier2 != null and is_instance_valid(_tier2):
		var h := _tier2.surface_height(hero.lane)
		if h > 0.0 and not _tier2.boosted and _tier2.at_ramp_up():
			_tier2.boosted = true
			if hero.jump(0.9):
				AudioMgr.sfx("boost")
				FX.dust(hero, Vector3(0, 0.03, 0))
		hero.set_ground(h)
	elif hero.ground_y != 0.0:
		hero.set_ground(0.0)


# ---------- цикл ----------

## Викликається кожен кадр із Run3D: рух перешкод, зіткнення, збір зірочок і пікапів, авто-допомога, веселка.
func check(delta: float) -> void:
	_tick_pickups(delta)
	_tick_tier2(delta)
	_tick_ground()
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
			if not s.collected and absf(s.position.z) < (Star3D.WIDE_REACH if magnet_wide else 3.0) and s.tick(delta, hero, magnet, magnet_wide):
				s.collect()
				stars_collected_segment += 1
				FX.burst(self, s.position)
				Events.star_collected.emit(s.value * coin_mult)
				AudioMgr.sfx("star", 1.0 + 0.08 * float(stars_collected_segment % 3))
				if stars_collected_segment % 10 == 0:
					hero.cheer()
					AudioMgr.voice("praise")
		elif c is Pickup3D:
			var p := c as Pickup3D
			if not p.collected and absf(p.position.z) < 2.0 and p.tick(delta, hero):
				p.collect()
				FX.burst(self, p.position, Palette.of(p.def.get("color"), Palette.PICKUP_DEFAULT))
				AudioMgr.sfx("pickup")
				if run.has_method("on_pickup"):
					run.call("on_pickup", p.kind, p.def)


## Зіткнення: бонуси/бризки, інакше — падіння, серце, невразливість; щит поглинає удар; малятам перший раз прощається.
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
			FX.burst(self, Vector3(hero.position.x, 0.3, 0.0), Palette.HERO_GLOW)
			Events.star_collected.emit(3 * coin_mult)
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
		FX.splash(self, Vector3(hero.position.x, 0.1, 0.0), Palette.SPLASH_WATER if o.kind == "puddle" else Palette.SPLASH_GRASS)
		AudioMgr.sfx("splash")
		return
	if hero.tumbling or hero.flying or hero.invulnerable_t > 0.0:
		return
	# щит: удар поглинуто, герой біжить далі
	if hero.shield_on:
		hero.pop_shield()
		hero.set_invulnerable(0.6)
		AudioMgr.sfx("shield")
		if run.has_method("on_shield_used"):
			run.call("on_shield_used")
		_clear_ahead(1.0)
		return
	hero.tumble()
	Events.hero_tumbled.emit(o.kind)
	AudioMgr.sfx("tumble")
	AudioMgr.voice("oops")
	if run.has_method("on_tumble"):
		run.call("on_tumble")
	_clear_ahead(2.0)
	# малятам перше зіткнення на рівні прощається
	if bool(profile.get("first_hit_forgiven", false)) and not _forgiven:
		_forgiven = true
		hero.set_invulnerable(INVULN_SEC)
		return
	if hero.lose_heart():
		hearts_lost_segment += 1
		Events.hearts_changed.emit(hero.hearts)
		if hero.hearts <= 0 and run.has_method("_restart_level"):
			run.call("_restart_level")


## Після падіння дорога на N секунд чиста — дитина встигає оговтатись.
func _clear_ahead(seconds: float) -> void:
	for c in get_children():
		if c is Obstacle3D and not (c as Obstacle3D).hit and c.position.z < 0.0 and mode.seconds_to_hero(-c.position.z) < seconds:
			c.queue_free()
