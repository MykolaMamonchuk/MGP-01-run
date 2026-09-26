## Спавн перешкод, злитків, пікапів і сегментів другого рівня за профілем, світом і рівнем;
## рух їх разом із дорогою; зіткнення (AABB, без фізики); життя героя (GDD v1.3).
## GDD v1.4: на дорозі лежать золоті злитки (Ingot3D) трьома патернами — лінія з 5, діагональ,
## дуга над рампою/дахом; раз на 20–30 с — великий злиток «+100». Лічильники лишились старими
## (stars_collected_segment / stars_spawned_segment), сигнал збору теж — Events.star_collected(int).
## Перешкода з silhouette "vehicle" ставиться не як перешкода, а як транспорт із рампою й дахом-ярусом.
class_name Spawner3D
extends Node3D

const SPAWN_Z := -34.0
const KILL_Z := 4.0
## Тривалість польоту після веселки — коротка, щоб не пропускати зірочки на землі.
const FLY_SEC := 2.6
## Злитки — лише за групою перешкод у вільній доріжці: перший на SPAWN_Z-1.2, останній не далі SPAWN_Z-4.
const STARS_BEHIND_MIN := 1.2
const STARS_BEHIND_MAX := 4.0
const STAR_STEP := 0.9
## Патерни злитків (GDD v1.4 §3): лінія з 5 і діагональ «переходь доріжку»; дуга — на ярусі/рампі.
const INGOT_LINE := 5
## Великий злиток «+100» — раз на 20–30 с.
const BIG_INTERVAL := [20.0, 30.0]
## Номінал великого злитка. EDD §2: було 100 — з множником він сам давав більше,
## ніж уся решта дороги, і миттєво заряджав суперсилу. Напис «+20» лишається великим і золотим.
const BIG_VALUE := 20
## Пікап їде за лінією зірочок у тій самій вільній доріжці.
const PICKUP_BEHIND := 5.5
## Сегмент другого рівня — кожні 25–40 с у світах із "tier2": true.
const TIER2_INTERVAL := [25.0, 40.0]
## Невразливість після удару.
const INVULN_SEC := 1.5
## Поки рядок останньої групи не відʼїхав далі, ніж на стільки клітинок від лінії спавну,
## його єдину вільну доріжку тримаємо чистою (сорока не має права зробити рядок непрохідним).
const FREE_LANE_KEEP := 4.0
## «Райдужний міст» (GDD v1.6 §3c): скільки триває притягання всіх злитків і як швидко вони летять.
const PULL_SEC := 0.6
const PULL_LERP := 9.0
## Дії перешкод, які ламає «Роги напролом»: низькі бар'єри і X-ящики.
const BREAKABLE_ACTIONS := ["jump", "side"]
## Скільки злитків дає розбита перешкода.
const BREAK_REWARD := 5

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
## ─── суперсила героя (GDD v1.6 §3c) — прапорці ставить і знімає Run3D ───
## «Роги напролом»: перешкоди, які треба перестрибнути/обійти, розлітаються замість удару.
var break_obstacles := false
## Скільки наступних ударів поглинути мовчки («Дев'ять життів» 1, «Ведмежі обійми» 2).
var absorb_hits := 0
## Множник злитків від суперсили (окремо від пікапа «×2», бо буває дробовий: ведмідь ×1,5).
var power_coin_mult := 1.0
## true — множник суперсили діє лише в повітрі або на другому ярусі («Хитрий стрибок»).
var power_coin_air_only := false
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

## Скільки метрів проїхала дорога від старту рівня — те саме джерело правди, що й у Track
## (Run3D передає той самий підсумок в обидва advance(), щоб лічильники не розійшлись).
var distance_m := 0.0
## Авторський список перешкод рівня (res://levels/level_XX.tscn → LevelTimeline.extract()):
## якщо заданий — advance() спавнить по ньому курсором замість _next_gap()/_spawn_group().
var _authored_obstacles: Array = []
## Авторське золото: ФІГУРИ злитків, розставлені автором цеглинки (роль маркера `gold`).
var _authored_gold: Array = []
var _authored_gold_cursor := 0
## Відрізки траси (у метрах), де золото ставить ЦЕГЛИНКА, а не спавнер. Саме відрізки, а не
## один прапорець на рівень: рівень збирається зі спільної бібліотеки, тож змішаний склад —
## частина цеглинок переведена, частина ще ні — це нормальний стан міграції. З прапорцем на
## рівень вийшло б так: перша ж цеглинка із золотом вимикає випадкову лінію НАЗАВЖДИ, і всі
## наступні непереведені цеглинки лишаються геть без монет.
var _gold_regions: Array[Vector2] = []
var _authored_cursor := 0
## Авторські пікапи — маркери role = "pickup" з цеглинки. Свій курсор, бо йдуть вони своїм
## розкладом, а не за перешкодами.
var _authored_pickups: Array = []
var _authored_pickup_cursor := 0
var _authored_active := false

var _gap_left := 8.0
var _min_next_gap := 0.0
## Остання група: її вільна доріжка і z рядка (їде разом із дорогою) — щоб не перекрити її ззовні.
var _last_free_lane := 0
var _last_free_z := KILL_Z
var _seen_kinds: Dictionary = {}
## Малятам перше зіткнення на рівні прощається.
var _forgiven := false
## Пікапи: дані, таймер до наступного, вид, що чекає на вільну доріжку.
var _pickups: Dictionary = {}
var _pickup_t := 20.0
var _pickup_pending := ""
## Другий рівень: активний сегмент і таймер до наступного.
## Усі злитки кадру малюються ДВОМА MultiMesh — звичайні й великі. Кожен злиток окремим
## MeshInstance3D коштував свого draw call: заміряно 244 → 298 рівно тоді, коли злитки вперше
## з'явились на авторському рівні, при цілі GDD ≤150. Логіка злитків лишилась вузлам.
var _ingot_mm := [null, null]          ## [звичайні, великі] — MultiMeshInstance3D

var _tier2: Tier2Segment
var _tier2_t := 30.0
var _tier2_due := false
## Великий злиток «+100»: таймер і прапорець «час ставити».
var _big_t := 25.0
var _big_due := false
## Скільки ще секунд тягнути всі злитки до героя («Райдужний міст»).
var _pull_t := 0.0
## Власний генератор спавнера для вибору ВИДУ під авторську дію. Окремий і засіяний через
## RngSeed: глобальний randi() сідає на системну ентропію, і два прогони з тим самим GAME_SEED
## дали б різні рівні — це вже коштувало дня замірів (docs/MEMORY.md, перший запис).
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_pickups = Pickup3D.load_all()
	_make_ingot_meshes()
	RngSeed.start(_rng, "spawner_action")


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
	_last_free_z = KILL_Z
	_seen_kinds.clear()
	_pickup_pending = ""
	_schedule_pickup()
	_authored_pickup_cursor = 0
	_tier2 = null
	_tier2_due = false
	_tier2_t = randf_range(float(TIER2_INTERVAL[0]), float(TIER2_INTERVAL[1]))
	_big_due = false
	_big_t = randf_range(float(BIG_INTERVAL[0]), float(BIG_INTERVAL[1]))
	magnet_wide = false
	coin_mult = 1
	reset_power()
	_prewarm_props()
	# Той самий порядок появи гусок на рівні — ті самі моделі, і після перезапуску теж.
	Obstacle3D._rig_counter = 0


## Прочитати меші ВСІХ перешкод світу наперед, поки триває завантаження рівня.
##
## Навіщо. PropLibrary.mesh() кешує, але перший виклик читає GLB з диска. Заміряно
## 20.09.2026 на Лузі: 17 мешів, 27,4 мс разом — і без цього прогріву вони читались би
## по одному, кожен у тому кадрі, де його вид уперше вийшов на дорогу. Кожен вид усе одно
## прочитається за рівень, тож це не економія пам'яті, а перенесення читання туди, де на
## нього ніхто не дивиться.
##
## Типи беремо ВСІ: pick() вибирає випадково на кожен екземпляр, тож «прогріти перший» —
## значить лишити читання на другому.
##
## Чесно про межу: ЦЕ НЕ прибрало жодного зі сплесків у бігу. Ті виявились іншими (див.
## docs/MEMORY.md: перше зіткнення й збирання чанка), а лог читань після прогріву показує
## нуль звертань до диска за весь прогін — саме те, заради чого функція й потрібна.
func _prewarm_props() -> void:
	var defs: Dictionary = world.get("obstacles", {})
	for kind in defs:
		var d: Dictionary = defs[kind]
		var prop := String(d.get("prop", d.get("voxel", kind)))
		for v in range(PropLibrary.variants(prop)):
			PropLibrary.mesh(prop, v)
			# Скелетна тварина бере не меш, а цілу сцену (Obstacle3D._setup_rig).
			if d.has("rig"):
				PropLibrary.scene(String(PropLibrary._entry(prop, v).get("path", "")))


## Скільки монеток дає злиток номіналу value: пікап «×2» (цілий) × множник суперсили (дробовий).
## Множник «Хитрого стрибка» рахується лише в повітрі або на другому ярусі.
func ingot_gain(value: int) -> int:
	var k := power_coin_mult
	if power_coin_air_only and not (hero.is_airborne() or hero.ground_y > 0.0):
		k = 1.0
	return maxi(1, int(round(float(value * coin_mult) * k)))


## Зняти всі прапорці суперсили (кінець сили, старт рівня, вихід у меню).
func reset_power() -> void:
	break_obstacles = false
	absorb_hits = 0
	power_coin_mult = 1.0
	power_coin_air_only = false
	_pull_t = 0.0


## Суперсила «Райдужний міст»: усі злитки, що зараз на дорозі, летять до героя за seconds.
## Не твін, а таймер: дорога під час притягання ЇДЕ (advance() щокадру додає z), тож твін
## на фіксовану точку зривався б. Тягне _tick_pull(), а збирає звичайний Ingot3D.tick()
## у check() — множники й лічильники рахуються як завжди.
func pull_all_ingots(seconds: float = PULL_SEC) -> int:
	_pull_t = maxf(0.05, seconds)
	var n := 0
	for c in get_children():
		if c is Ingot3D and not (c as Ingot3D).collected:
			n += 1
	return n


## Тягне всі злитки до героя, поки триває «Райдужний міст».
func _tick_pull(delta: float) -> void:
	if _pull_t <= 0.0:
		return
	_pull_t = maxf(0.0, _pull_t - delta)
	var target := Vector3(hero.position.x, hero.position.y + 0.5, 0.0)
	for c in get_children():
		if c is Ingot3D and not (c as Ingot3D).collected:
			c.position = (c as Ingot3D).position.lerp(target, minf(1.0, delta * PULL_LERP))


func set_level(types: Array, dens: float, n_lanes: int, tut: bool) -> void:
	level_types = types
	density = maxf(0.4, dens)
	lanes = n_lanes
	tutorial = tut
	finish_pending = false
	_forgiven = false
	hearts_lost_segment = 0


## ГУСКИ, ЩО ПАСУТЬСЯ на узбіччі (GooseGrazer3D) — жива декорація першого світу. Вмикає рівень
## полем "grazing_geese", а світ описує їх полем "grazers" ({"prop", "every_m": [a, b]}).
## Жереб — СВІЙ генератор: зграйки не мають зсувати розстановку перешкод, яку тримає _rng.
var grazers_on := false
var _graze_rng := RandomNumberGenerator.new()
var _graze_left := 10.0


func set_grazers(on: bool) -> void:
	grazers_on = on and world.has("grazers")
	_graze_rng.seed = hash("grazers|%s" % String(world.get("id", "")))
	_graze_left = 10.0


func _advance_grazers(dist: float) -> void:
	# Лише в самому бігу: під меню, мапою й відліком дорога теж їде (advance), але гуски
	# там стояли б застиглими — check() їх не «оживляє» (рецензія 26.09).
	if not grazers_on or not spawning:
		return
	_graze_left -= dist
	if _graze_left > 0.0:
		return
	var g: Dictionary = world["grazers"]
	var every: Array = g.get("every_m", [18.0, 38.0])
	_graze_left = _graze_rng.randf_range(float(every[0]), float(every[1]))
	# Зграйка: частіше одна-дві, зрідка до п'яти.
	var r := _graze_rng.randf()
	var count := 1 if r < 0.4 else (2 if r < 0.7 else (3 if r < 0.9 else _graze_rng.randi_range(4, 5)))
	var side := -1.0 if _graze_rng.randf() < 0.5 else 1.0
	var edge := float(lanes) * 0.5 * Hero3D.LANE_W + 0.1
	var flock := GooseGrazer3D.Flock.new()
	var track: Track = run.get("track") if run != null else null
	var placed := 0
	var spots: Array[Vector3] = []
	for i in range(count):
		# Місце без декору: та сама смуга, куди траса кладе ящики, бочки й дерева узбіччя.
		# Кілька спроб; не знайшлось — ця гуска просто не приходить.
		var pos := Vector3.ZERO
		var found := false
		for attempt in range(6):
			pos = Vector3(side * (edge + _graze_rng.randf_range(0.4, 0.9)), 0.0,
				SPAWN_Z - _graze_rng.randf_range(0.7, 1.6) * float(placed + attempt))
			# Ні в декорі, ні одна в одній: прогін на телефоні 26.09 бачив зграю, злиплу в
			# купу, — гуски ставились без відстані між собою.
			var crowded := false
			for q in spots:
				if q.distance_to(pos) < GooseGrazer3D.MIN_GAP:
					crowded = true
			if not crowded and (track == null or not track.decor_near(pos.x, pos.z, 0.45)):
				found = true
				break
		if not found:
			continue
		var goose := GooseGrazer3D.new()
		if not goose.setup(String(g.get("prop", "goose")), _graze_rng):
			goose.free()
			return
		goose.flock = flock
		goose.leader = placed == 0
		goose.delay = _graze_rng.randf_range(0.12, 0.45)
		goose.road_edge = edge
		goose.position = pos
		add_child(goose)
		spots.append(pos)
		placed += 1


func set_speed(s: float) -> void:
	speed = s


func clear() -> void:
	# Вихід у меню / зміна рівня: гуски на узбіччі — лише там, де їх увімкне наступний рівень.
	grazers_on = false
	for c in get_children():
		if c is MultiMeshInstance3D:
			# Пачки злитків переживають зміну рівня: вони не вміст траси, а спосіб її
			# намалювати. Знести їх означало б лишити _ingot_mm із звільненими вузлами —
			# і рівень мовчки лишився б без жодного злитка.
			(c as MultiMeshInstance3D).multimesh.visible_instance_count = 0
			continue
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


## Зсув усього, що на дорозі, на dist клітинок. total_distance_m — той самий сумарний лічильник,
## що йде й у Track.advance() (null — рахуємо самі; так лишаються робочими старі виклики/тести).
func advance(dist: float, total_distance_m: Variant = null) -> void:
	distance_m = float(total_distance_m) if total_distance_m != null else distance_m + dist
	for c in get_children():
		if c is MultiMeshInstance3D:
			continue   # пачки злитків не «їдуть» і не гинуть: вони не вміст траси, а спосіб її намалювати
		if c is Node3D:
			c.position.z += dist
			if c.position.z > KILL_Z:
				if c == _tier2:
					_tier2 = null
				c.queue_free()
	_gap_left -= dist
	# рядок останньої групи їде разом із дорогою
	_last_free_z += dist
	_advance_authored_pickups()
	_advance_authored_gold()
	_advance_grazers(dist)
	if _authored_active:
		_advance_authored()
		return
	if _gap_left <= 0.0:
		_min_next_gap = 0.0
		if spawning and not finish_pending:
			if _tier2_due and (_tier2 == null or not is_instance_valid(_tier2)):
				_spawn_tier2()
			else:
				_spawn_group()
		_gap_left = maxf(_next_gap(), _min_next_gap)


## Задати авторський список перешкод рівня одним махом (стирає попередній): records —
## масив {z_m, kind, lane, override, ...} від LevelTimeline.extract(). Курсор — з нуля.
func set_authored_obstacles(records: Array) -> void:
	clear_authored_obstacles()
	add_authored_obstacles(records)


## Дозавантажити ще перешкод до вже наявного списку (LevelChunkLoader — наступний чанк рівня):
## на відміну від set_ курсор НЕ скидається, уже застосовані записи лишаються пройденими.
func add_authored_obstacles(records: Array) -> void:
	_authored_obstacles = LevelTimeline.merge_by_z(_authored_obstacles, records)
	_authored_active = true


## Повернутися до випадкового _next_gap()/_spawn_group() (рівні без authored .tscn — усі, поки що).
func clear_authored_obstacles() -> void:
	_authored_obstacles = []
	_authored_cursor = 0
	_authored_active = false


## Курсор по відсортованому списку: спавнимо запис, щойно дорога проїхала стільки, що він
## має зʼявитись на лінії спавну (SPAWN_Z) — та сама точка, де _spawn_obstacle() завжди ставить нові.
func _advance_authored() -> void:
	if not spawning or finish_pending:
		return
	_try_authored_tier2()
	while _authored_cursor < _authored_obstacles.size():
		var rec: Dictionary = _authored_obstacles[_authored_cursor]
		var z := float(rec.get("z_m", 0.0))
		if distance_m < z - absf(SPAWN_Z):
			break
		# Беремо ВСЮ групу цього метра, а не запис поодинці: вільну доріжку визначає група.
		# Поки автор ставить по одній перешкоді на місце, група — це один запис; але щойно
		# він поставить дві поруч, «вільною» не сміє виявитись зайнята.
		var group: Array = []
		while _authored_cursor < _authored_obstacles.size():
			var r: Dictionary = _authored_obstacles[_authored_cursor]
			if absf(float(r.get("z_m", 0.0)) - z) > 0.5:
				break
			group.append(r)
			_authored_cursor += 1
		var used := {}
		for r in group:
			used[clampi(int((r as Dictionary).get("lane", 0)), -max_lane(), max_lane())] = true
		var free_lane := _free_lane_among(used)
		var placed := false
		for r in group:
			if _spawn_authored_obstacle(r, free_lane):
				placed = true
		if placed:
			_spawn_authored_collectibles(free_lane)


## Скільки метрів ходу треба другому ярусу, щоб дитина встигла заїхати й зіскочити: найдовший
## сегмент — 16 м платформи плюс два пандуси по 2 (Tier2Segment.total_length), плюс запас на
## приземлення.
const TIER2_SPAN := 24.0


## Другий ярус на АВТОРСЬКОМУ рівні. Просто пустити сюди таймер, як на процедурному, не можна:
## сегмент займає 14–20 м доріжки, і на рукотворній розкладці він накрив би перешкоду, яку
## автор поставив навмисно, — або вона опинилась би під платформою, де дитині нічого робити.
##
## Тому дивимось, у ЯКИХ доріжках найближчі TIER2_SPAN метрів нічого не стоїть, і ставимо
## тільки туди. Немає жодної вільної — ярус просто чекає наступної нагоди, а не втискається.
func _try_authored_tier2() -> void:
	if not _tier2_due:
		return
	if _tier2 != null and is_instance_valid(_tier2):
		return
	var free := _authored_free_lanes(TIER2_SPAN)
	if free.is_empty():
		return
	_spawn_tier2(free)


## Доріжки, у яких на найближчі span метрів ходу нема жодної авторської перешкоди.
func _authored_free_lanes(span: float) -> Array:
	var busy := {}
	var until := distance_m + span
	var i := _authored_cursor
	while i < _authored_obstacles.size():
		var rec: Dictionary = _authored_obstacles[i]
		if float(rec.get("z_m", 0.0)) - absf(SPAWN_Z) > until:
			break
		busy[clampi(int(rec.get("lane", 0)), -max_lane(), max_lane())] = true
		i += 1
	var out := []
	for l in lane_list():
		if not busy.has(l):
			out.append(l)
	return out


## Доріжка, у якій на цьому метрі НЕМА перешкоди. Перевага центру: саме туди дитина
## повертається сама, і саме туди має вести доріжка зі злитків.
func _free_lane_among(used: Dictionary) -> int:
	if not used.has(0):
		return 0
	for step in range(1, max_lane() + 1):
		for l in [-step, step]:
			if not used.has(l):
				return int(l)
	return 0   # усі доріжки зайняті — рівень і так непрохідний, вести нікуди


## Збірне за авторською групою — ТЕ САМЕ, що ставить _spawn_group() за випадковою.
##
## Без цього авторський рівень не давав дитині нічого. Заміряно на 400 м: випадковий рівень —
## 80 перешкод і 276 злитків, авторський — 20 перешкод і НУЛЬ злитків, нуль пікапів. Причина
## була проста й тому непомітна: злитки й пікапи ставить _spawn_group(), а авторська гілка
## advance() виходить із функції до нього. Квест «збери 15 зірочок» на рівні 1 був недосяжний.
func _spawn_authored_collectibles(free_lane: int) -> void:
	# Золото за групою — лише коли цеглинка НЕ розставила його сама. Те саме правило, що й
	# для пікапів нижче, і з тієї ж причини: інакше автор просив би одне, а рівень давав би
	# це плюс випадкову лінію зверху, і жоден бюджет не сходився б.
	if has_authored_gold_at(distance_m + absf(SPAWN_Z)):
		# Золото тут ставить цеглинка — випадкова лінія мовчить. Але великий злиток лишається
		# за спавнером: він іде ЗА ЧАСОМ (раз на 20–30 с), а не за місцем, тож у бюджет
		# цеглинки не вміщається й вимикати його разом із лінією не можна.
		_spawn_big_if_due(free_lane, SPAWN_Z - STARS_BEHIND_MIN)
	else:
		_spawn_ingot_pattern(free_lane, SPAWN_Z - STARS_BEHIND_MIN)
	# Пікап, що чекає своєї черги, — лише коли цеглинки не розставили пікапи САМІ: інакше
	# автор просив би одне, а рівень давав би це плюс ще випадкове зверху.
	if _pickup_pending != "" and _authored_pickups.is_empty():
		_spawn_pickup(_pickup_pending, free_lane, SPAWN_Z - PICKUP_BEHIND)
		_pickup_pending = ""


## Курсор по авторських пікапах: маркер сам каже, ЩО й У ЯКІЙ доріжці, і з'являється на тій
## самій лінії спавну, що й перешкоди.
func _advance_authored_pickups() -> void:
	if not spawning or finish_pending:
		return
	while _authored_pickup_cursor < _authored_pickups.size():
		var rec: Dictionary = _authored_pickups[_authored_pickup_cursor]
		if distance_m < float(rec.get("z_m", 0.0)) - absf(SPAWN_Z):
			break
		_authored_pickup_cursor += 1
		var kind := String(rec.get("kind", ""))
		if not (_pickups.get("kinds", {}) as Dictionary).has(kind):
			push_warning("пікап «%s» не описаний у data/pickups.json — маркер пропущено" % kind)
			continue
		_spawn_pickup(kind, clampi(int(rec.get("lane", 0)), -max_lane(), max_lane()), SPAWN_Z)


func set_authored_gold(records: Array) -> void:
	clear_authored_gold()
	add_authored_gold(records)


## from_m/to_m — відрізок траси, який ця цеглинка покриває. Передає завантажувач: лише він
## знає, де цеглинка починається й де кінчається. Нуль (типове) означає «покриття невідоме»,
## і тоді відрізок не реєструється — так кличуть тести й інструменти, яким байдуже.
func add_authored_gold(records: Array, from_m: float = 0.0, to_m: float = 0.0) -> void:
	_authored_gold = LevelTimeline.merge_by_z(_authored_gold, records)
	if not records.is_empty() and to_m > from_m:
		_gold_regions.append(Vector2(from_m, to_m))


func clear_authored_gold() -> void:
	_authored_gold = []
	_authored_gold_cursor = 0
	_gold_regions = []


## Чи розставила цеглинка золото САМА — де завгодно на рівні. Для тестів і звітів.
func has_authored_gold() -> bool:
	return not _authored_gold.is_empty()


## Чи ставить цеглинка золото САМЕ ТУТ, на цьому метрі траси. Поки ні — працює старий шлях:
## лінія з 5 у вільній доріжці за групою перешкод.
##
## Відрізок невідомий (цеглинка додала золото без меж — так роблять тести) — вважаємо, що
## покрито все: інакше поруч із авторськими фігурами сипалась би ще й випадкова лінія, і
## бюджет би подвоївся. Це обережніший бік помилки.
func has_authored_gold_at(z_m: float) -> bool:
	if _authored_gold.is_empty():
		return false
	if _gold_regions.is_empty():
		return true
	for r in _gold_regions:
		if z_m >= r.x and z_m < r.y:
			return true
	return false


## Курсор по авторському золоту. Окремий від перешкод і від пікапів навмисно: фігура золота
## не прив'язана до групи перешкод — у тому й сенс, щоб її можна було покласти ТУДИ, де
## перешкод нема (святкування після важкого шматка), або у НЕбезпечну доріжку (плата за ризик).
func _advance_authored_gold() -> void:
	if not spawning or finish_pending:
		return
	while _authored_gold_cursor < _authored_gold.size():
		var rec: Dictionary = _authored_gold[_authored_gold_cursor]
		if distance_m < float(rec.get("z_m", 0.0)) - absf(SPAWN_Z):
			break
		_authored_gold_cursor += 1
		_spawn_gold_figure(rec)


## Одна фігура золота. `kind` — яка саме, `override` — її параметри:
##
##   line     пряма лінія вздовж дороги в одній доріжці     {"n": 5}
##   climb    діагональ із lane у to_lane — «перейди сюди»  {"n": 5, "to_lane": 1}
##   arc      дуга в повітрі — «тут стрибок»                {"n": 5, "h": 2.6}
##   cluster  купка на кількох доріжках — святкування/джекпот {"n": 12, "w": 3}
##
## `value` (типово 1) — номінал КОЖНОЇ монети фігури. Це та ручка, якою економіку правлять,
## не чіпаючи вигляду: дитина бачить ту саму купку, а коштує вона вдвічі більше. Прив'язувати
## дохід намертво до кількості фізичних монет не можна — тоді будь-яке балансування псує
## картинку.
func _spawn_gold_figure(rec: Dictionary) -> void:
	var kind := String(rec.get("kind", "line"))
	var ov: Dictionary = rec.get("override", {}) if typeof(rec.get("override", {})) == TYPE_DICTIONARY else {}
	var n := clampi(int(ov.get("n", INGOT_LINE)), 1, 40)
	var value := maxi(1, int(ov.get("value", 1)))
	var lane := clampi(int(rec.get("lane", 0)), -max_lane(), max_lane())
	var y := float(rec.get("y_m", 0.0))
	if y <= 0.0:
		y = 0.6
	match kind:
		"arc":
			# Дуга — єдина фігура, що вже вміла малюватись сама: нею летить герой із рампи.
			# Висоту НЕ ставимо «як у польоті»: апекс звичайного стрибка ≈ 0,5 м, і дуга на
			# 2,6 м, підписана «тут стрибок», недосяжна вп'ятеро. Типове — трохи вище голови.
			spawn_star_arc(float(ov.get("h", 1.1)), n, lane, SPAWN_Z, value)
		"climb":
			var to_lane := clampi(int(ov.get("to_lane", lane + 1)), -max_lane(), max_lane())
			for i in range(n):
				var k := float(i) / float(maxi(1, n - 1))
				var x := lerpf(float(lane), float(to_lane), k) * Hero3D.LANE_W
				spawn_star_at(Vector3(x, y, SPAWN_Z - float(i) * STAR_STEP), value)
		"cluster":
			var w := clampi(int(ov.get("w", 3)), 1, max_lane() * 2 + 1)
			var rows := ceili(float(n) / float(w))
			# Зсуваємо ВСЮ купку, а не затискаємо кожну колонку окремо. Інакше купка біля
			# краю дороги складалась: на трьох доріжках w=3 і lane=1 давали колонки 0,1,1 —
			# дві монети в одній точці. Дитина бачить одну, а лічильник рахує дві, тобто
			# рівно та розбіжність між картинкою й економікою, проти якої все це й робиться.
			var left := clampi(lane - (w - 1) / 2, -max_lane(), max_lane() - w + 1)
			var put := 0
			for r in range(rows):
				for c in range(w):
					if put >= n:
						break
					spawn_star_at(Vector3(float(left + c) * Hero3D.LANE_W, y,
						SPAWN_Z - float(r) * STAR_STEP), value)
					put += 1
		_:
			# Помилка в назві фігури не має ставати мовчазною лінією: сусідній
			# _advance_authored_pickups() на невідомий вид попереджає явно, і тут так само.
			if kind != "line":
				push_warning("фігура золота «%s» невідома (line/climb/arc/cluster) — поставлено лінію" % kind)
			for i in range(n):
				spawn_star_at(Vector3(float(lane) * Hero3D.LANE_W, y,
					SPAWN_Z - float(i) * STAR_STEP), value)


func set_authored_pickups(records: Array) -> void:
	clear_authored_pickups()
	add_authored_pickups(records)


func add_authored_pickups(records: Array) -> void:
	_authored_pickups = LevelTimeline.merge_by_z(_authored_pickups, records)


func clear_authored_pickups() -> void:
	_authored_pickups = []
	_authored_pickup_cursor = 0


## Один запис із авторського списку — тим самим _spawn_obstacle(), що й випадкові групи.
## Запис без kind, але з action («тут треба перестрибнути») — вид добирає СВІТ.
## free_lane — доріжка БЕЗ перешкоди, порахована по всій групі цього метра. Раніше сюди йшла
## доріжка самої перешкоди, тобто «вільною» оголошувалась зайнята: авто-допомога й підказка
## «убік» вели дитину рівно в те, що треба обійти.
##
## Повертає true, якщо перешкоду справді поставлено, — за поставленою групою йдуть злитки, а
## за пропущеною їм іти нема за чим.
func _spawn_authored_obstacle(rec: Dictionary, free_lane: int) -> bool:
	var kind := String(rec.get("kind", ""))
	var defs: Dictionary = world.get("obstacles", {})
	if kind == "":
		kind = _kind_for_action(String(rec.get("action", "")), String(rec.get("motion", "")))
		if kind == "":
			return false   # дії в цьому світі нема (або нема й самої дії) — запис пропущено
	if not defs.has(kind):
		return false   # автор указав перешкоду, якої нема в цьому світі — пропускаємо, а не падаємо
	var lane := clampi(int(rec.get("lane", 0)), -max_lane(), max_lane())
	_last_free_lane = free_lane
	_last_free_z = SPAWN_Z
	var ob := _spawn_obstacle(kind, defs[kind], lane)
	ob.free_lane = free_lane
	ob.position.z = _spawn_z_for(defs[kind])
	return true


## Звідки випускати перешкоду, щоб вона доїхала до героя ТОДІ, КОЛИ задумав автор.
##
## Звичайна перешкода стоїть на місці й пливе разом зі світом: від SPAWN_Z до героя вона йде
## SPAWN_Z/v секунд. А та, що КОТИТЬСЯ, додає до цього власні ROLL_SPEED, тож долає ту саму
## відстань за SPAWN_Z/(v+ROLL) — тобто приходить раніше, і тим раніше, чим повільніший
## рівень. Заміряно: на пляжі це 6,5 м випередження, і разом із мінімальним проміжком між
## рядами вікно реакції падало до 0,2 с. Для гри для малят це невідворотний удар.
##
## Тому випускаємо її далі — рівно настільки, щоб час у дорозі лишився тим самим. Тоді
## маркер означає те, що на ньому написано, на будь-якій швидкості й у будь-якому світі.
func _spawn_z_for(def: Dictionary) -> float:
	if String(def.get("anim", "")) != "roll":
		return SPAWN_Z
	var v := maxf(0.5, speed)
	return SPAWN_Z * (v + Obstacle3D.ROLL_SPEED) / v


## Вид перешкоди під ЗАДАНУ ДІЮ в поточному світі. Чанк пише дію («jump»), бо спільних видів
## між світами практично нема (Лужок ∩ Ліс — лише xbox), а jump/duck/side є всюди.
##
## Беремо лише те, що рівень і так дозволяє (_allowed_kinds() шанує obstacle_types рівня й
## викидає X-ящик), і додатково виключаємо транспорт: shape "vehicle" — це не перешкода, а
## кузов із рампою й дахом-ярусом, його ставить окремий _spawn_vehicle(). Підсунути його під
## «обійди збоку» означало б підмінити задум автора цілою конструкцією.
##
## Нема жодного придатного виду — повертаємо порожнє й гучно попереджаємо: мовчазна підміна
## («постав хоч щось») зробила б рівень непрохідним тихо, а пропуск видно і в логові, і в грі.
##
## Вибір іде через _rng (засіяний RngSeed), а не через глобальний randi(): два прогони з тим
## самим зерном мусять дати той самий рівень. Ключі сортуємо — порядок у словнику залежить від
## порядку запису в JSON, і перестановка рядків у файлі не має міняти вже знятий рівень.
## motion — яка саме: "roll" котиться назустріч, "cross" перебігає впоперек, "" байдуже.
## Транспорт ("ride") сюди не потрапляє й тут: кузов ставить окремий _spawn_vehicle().
func _kind_for_action(action: String, motion: String = "") -> String:
	if action == "":
		return ""
	if motion == "ride":
		# Кузов ставить окремий _spawn_vehicle(), і авторської розстановки в нього ще нема
		# (фрази з "ride" позначені needs). Без цього попередження маркер мовчки давав би
		# випадкову статичну перешкоду: пеньок замість воза з сіном.
		push_warning("Spawner3D: рух «ride» ще не реалізовано для авторських маркерів — запис пропущено")
		return ""
	var defs: Dictionary = world.get("obstacles", {})
	# Маркер — це і є вимога автора, тож види «на вимогу» йому доступні.
	var fits := _allowed_kinds(true).filter(func(k):
		var d: Dictionary = defs[k]
		if String(d.get("shape", "")) == "vehicle":
			return false
		if motion == "roll" and String(d.get("anim", "")) != "roll":
			return false
		if motion == "cross" and not bool(d.get("moves", false)):
			return false
		return String(d.get("action", "any")) == action)
	if fits.is_empty():
		push_warning("Spawner3D: у світі «%s» нема перешкоди з дією «%s»%s (дозволено рівнем: %s) — авторський запис пропущено"
			% [String(world.get("id", "?")), action, "" if motion == "" else " і рухом «%s»" % motion,
			   "усі біому" if level_types.is_empty() else str(level_types)])
		return ""
	fits.sort()
	return String(fits[_rng.randi() % fits.size()])


func _next_gap() -> float:
	var interval: Array = profile.get("obstacle_interval", [2.0, 3.0])
	var sec := randf_range(float(interval[0]), float(interval[1])) * density
	return maxf(2.5, sec * speed)


## X-ящик сороки: вид "xbox" або силует "x_box" із власним маркером-X
## (у звичайних перешкод того ж силуету маркер вимкнено: "marker": "none").
func _is_xbox(kind: String, def: Dictionary) -> bool:
	if kind == "xbox":
		return true
	return String(def.get("shape", "")) == "x_box" and String(def.get("marker", "")) != "none"


## Рівень задає набір перешкод; порожній список — усі перешкоди біому (рівень важливіший за профіль).
## X-ящик у випадкові групи не потрапляє — його скидає лише сорока (GDD v1.4 §3).
## on_demand=true — додати й види з `authored_only`. Це ті, що з'являються ЛИШЕ там, де їх
## попросив автор цеглинки, і ніколи у випадковій групі.
##
## Навіщо. Порожній `obstacle_types` рівня означає «усі види біому», і таких рівнів п'ять
## (4, 8, 11, 14, 17). Щойно у світі з'явилась бочка, що котиться, ці рівні почали її
## спавнити — хоч їх ніхто не чіпав і ніхто цього не проєктував. На рівні 8 це ~5–12 рухомих
## перешкод там, де автор малював статику. Гірше: проміжок між рядами рахується в метрах
## світу й про додаткові ROLL_SPEED не знає, тож на рівнях 11/14/17 вікно реакції падало до
## ~0,2 с. Нова механіка має з'являтись ТАМ, ДЕ ЗАДУМАНО, — це і є вся суть переходу від
## випадкової дороги до авторської.
func _allowed_kinds(on_demand: bool = false) -> Array:
	var defs: Dictionary = world.get("obstacles", {})
	var world_kinds: Array = defs.keys().filter(func(k):
		if _is_xbox(String(k), defs[k]):
			return false
		if not on_demand and bool((defs[k] as Dictionary).get("authored_only", false)):
			return false
		return true)
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
	# запамʼятовуємо вільну доріжку рядка — сорока не має кинути ящик саме в неї
	_last_free_lane = free_lane
	_last_free_z = SPAWN_Z
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
	var vehicle_placed := false
	for l in to_block:
		var k := String(used_kinds[randi() % used_kinds.size()])
		var d: Dictionary = world["obstacles"][k]
		# транспорт (shape: vehicle) — не перешкода, а кузов із рампою й дахом-ярусом; один на групу
		if String(d.get("shape", "")) == "vehicle":
			if not vehicle_placed and (_tier2 == null or not is_instance_valid(_tier2)):
				vehicle_placed = true
				_spawn_vehicle(int(l), d)
				continue
			var plain := used_kinds.filter(func(x): return String((world["obstacles"][x] as Dictionary).get("shape", "")) != "vehicle")
			if plain.is_empty():
				continue
			k = String(plain[0])
			d = world["obstacles"][k]
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
	# злитки — лише у вільній доріжці й лише ЗА групою: «ведуть» дитину повз перешкоду
	var tail := _spawn_ingot_pattern(free_lane, SPAWN_Z - STARS_BEHIND_MIN)
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


## Вільна доріжка останньої групи (сорока цілиться повз неї).
func last_free_lane() -> int:
	return _last_free_lane


## Найближча доріжка, що не є вільною доріжкою останньої групи; lane — якщо іншої нема.
func _lane_beside_free(lane: int) -> int:
	for d in range(1, lanes + 1):
		for s: int in [-1, 1]:
			var l := lane + d * s
			if l >= -max_lane() and l <= max_lane() and l != _last_free_lane:
				return l
	return lane


## Перешкода на замовлення ззовні (сорока скидає X-ящик у доріжку lane).
## Опис бере з поточного світу; false — у цьому біомі такої перешкоди нема, їдуть ворота фінішу
## або ящик нікуди поставити, не зробивши рядок останньої групи непрохідним.
func spawn_obstacle_kind(kind: String, lane: int) -> bool:
	var defs: Dictionary = world.get("obstacles", {})
	if finish_pending or not defs.has(kind):
		return false
	var l := clampi(lane, -max_lane(), max_lane())
	# рядок останньої групи ще біля лінії спавну — його єдину вільну доріжку не перекриваємо
	if l == _last_free_lane and _last_free_z <= SPAWN_Z + FREE_LANE_KEEP:
		l = _lane_beside_free(l)
		if l == _last_free_lane:
			return false
	_spawn_obstacle(kind, defs[kind], l)
	return true


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


## Патерн злитків за групою (GDD v1.4 §3): «лінія з 5», «діагональ» через сусідню доріжку
## або великий злиток «+100», коли настав його час. Повертає довжину хвоста в клітинках.
## Великий злиток, коли підійшов його час. Окремо від лінії навмисно: доти він жив ВСЕРЕДИНІ
## _spawn_ingot_pattern(), тобто з'являвся тільки там, де сипалась випадкова лінія. Щойно
## цеглинка починала ставити золото сама, лінія вимикалась — і `_big_due` лишався true
## назавжди, бо _tick_big() виходить одразу, поки він піднятий. Великий злиток зникав із
## рівня цілком, а це 64–104 номіналу за рівень у моделі EDD, тобто до чверті доходу.
func _spawn_big_if_due(lane: int, z0: float) -> bool:
	if not _big_due:
		return false
	_big_due = false
	_big_t = randf_range(float(BIG_INTERVAL[0]), float(BIG_INTERVAL[1]))
	spawn_star_at(Vector3(float(lane) * Hero3D.LANE_W, 0.7, z0), BIG_VALUE)
	return true


func _spawn_ingot_pattern(lane: int, z0: float) -> float:
	if _spawn_big_if_due(lane, z0):
		return STARS_BEHIND_MIN + 1.0
	var neighbours := lane_list().filter(func(l): return absi(int(l) - lane) == 1)
	if not neighbours.is_empty() and randf() < 0.35:
		# діагональ: перші два злитки у вільній доріжці, далі — «переходь доріжку»
		var to := int(neighbours[randi() % neighbours.size()])
		for i in range(INGOT_LINE):
			var l := lane if i < 2 else to
			spawn_star_at(Vector3(float(l) * Hero3D.LANE_W, 0.6, z0 - float(i) * STAR_STEP))
	else:
		_spawn_stars_line(lane, z0, INGOT_LINE)
	return STARS_BEHIND_MIN + float(INGOT_LINE - 1) * STAR_STEP


## Злиток у позиції; value 2 — подвійний (дах транспорту / платформа), 100 — великий «+100».
## Ім'я лишилось старим: Run3D і події працюють із цим API як раніше.
func spawn_star_at(pos: Vector3, value: int = 1) -> void:
	var s := Ingot3D.new()
	s.value = value
	s.position = pos
	add_child(s)
	stars_spawned_segment += 1


## Дуга зірочок у повітрі — для польоту (веселка, ракета) і великої хвилі. lane 99 — випадкова.
## z0 — де починається дуга. Типове -3.0 — це «просто перед героєм ПРЯМО ЗАРАЗ»: так її
## кличуть події польоту (веселка, ракета, рампа), і для них це правильно. Авторський маркер
## натомість стоїть на SPAWN_Z, за 34 м попереду, — без цього параметра його дуга спалахувала
## б просто в кадрі, за 26 м не там, де автор її поклав.
func spawn_star_arc(height: float = 2.6, count: int = 8, lane: int = 99, z0: float = -3.0,
		value: int = 1) -> void:
	var fixed := lane != 99
	if not fixed:
		lane = random_lane()
	for i in range(count):
		if not fixed and randf() < 0.3:
			lane = clampi(lane + (1 if randf() < 0.5 else -1), -max_lane(), max_lane())
		var t := float(i) / float(maxi(1, count - 1))
		spawn_star_at(Vector3(float(lane) * Hero3D.LANE_W, height + sin(t * PI) * 0.6,
			z0 - float(i) * 1.2), value)


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
	if not _authored_pickups.is_empty():
		return   # пікапи розставив автор — випадкові поверх них були б чужими в його задумі
	_pickup_t -= delta
	if _pickup_t > 0.0:
		return
	_schedule_pickup()
	var rng := RandomNumberGenerator.new()
	RngSeed.start(rng, "spawner")
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

## Таймер великого злитка «+100»: коли час настав — його поставить наступний патерн у вільній доріжці.
func _tick_big(delta: float) -> void:
	if finish_pending or _big_due:
		return
	_big_t -= delta
	if _big_t <= 0.0:
		_big_due = true


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
## allowed — доріжки, з яких дозволено вибирати. Порожньо = будь-яка (процедурний рівень:
## там групи ще нема, і сегмент нічому не заважає). Авторський рівень передає сюди лише ті,
## де на найближчі метри нічого не стоїть.
func _spawn_tier2(allowed: Array = []) -> void:
	_tier2_due = false
	_tier2_t = randf_range(float(TIER2_INTERVAL[0]), float(TIER2_INTERVAL[1]))
	var lane := random_lane() if allowed.is_empty() else int(allowed[randi() % allowed.size()])
	var used: Array = [lane]
	if lanes >= 5 and randf() < 0.5:
		var second := clampi(lane + (1 if lane < max_lane() else -1), -max_lane(), max_lane())
		if second != lane and (allowed.is_empty() or allowed.has(second)):
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


## Транспорт замість перешкоди в доріжці (GDD v1.4 §3): кузов на два зрости героя з рампою спереду.
## Герой або обходить його вбік, або заїжджає рампою на дах і біжить 6–10 клітинок по лінії злитків.
func _spawn_vehicle(lane: int, def: Dictionary) -> void:
	var seg := Tier2Segment.new()
	seg.setup_vehicle(lane, String(def.get("vehicle_voxel", def.get("voxel", "cart"))), randf_range(6.0, 10.0))
	# початок координат — дальній кінець даху; рампа (ближній край) стоїть на лінії спавну
	seg.position.z = SPAWN_Z - seg.total_length()
	add_child(seg)
	_tier2 = seg
	# лінія подвійних злитків по даху
	var z0 := seg.roof_z0() + 0.8
	var n := int((seg.length - 1.2) / 1.2)
	for i in range(n):
		spawn_star_at(Vector3(float(lane) * Hero3D.LANE_W, Tier2Segment.H + 0.6, z0 + float(i) * 1.2), 2)
	# дуга злитків над рампою — запрошення заїхати нагору
	var zr := seg.position.z + seg.length + Tier2Segment.RAMP
	for i in range(4):
		var t := float(i) / 3.0
		spawn_star_at(Vector3(float(lane) * Hero3D.LANE_W, 0.6 + t * Tier2Segment.H, zr - t * Tier2Segment.RAMP))
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
	_tick_big(delta)
	_tick_tier2(delta)
	_tick_ground()
	_tick_pull(delta)
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
		elif c is GooseGrazer3D:
			(c as GooseGrazer3D).tick(delta)
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
		elif c is Ingot3D:
			var s := c as Ingot3D
			if not s.collected and absf(s.position.z) < (Ingot3D.WIDE_REACH if magnet_wide else 3.0) and s.tick(delta, hero, magnet, magnet_wide):
				s.collect()
				stars_collected_segment += 1
				if s.is_big():
					# великий злиток «+100»: золотий вибух і конфеті
					FX.burst(self, s.position, Palette.GOLD_BRIGHT)
					FX.confetti(self, s.position, 24)
					AudioMgr.voice("wow")
				else:
					FX.burst(self, s.position)
				Events.star_collected.emit(ingot_gain(s.value))
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


	# Пачки злитків — в САМОМУ КІНЦІ кадру: доти вони ще рухаються магнітом, збираються й
	# зникають, і знімати з них трансформи раніше означало б малювати вчорашній кадр.
	_refresh_ingot_meshes()


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
			Events.star_collected.emit(ingot_gain(3))
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
	# суперсила «Роги напролом»: низький бар'єр або X-ящик РОЗЛІТАЄТЬСЯ, герой біжить далі
	if break_obstacles and o.tumble and BREAKABLE_ACTIONS.has(o.action) and not hero.tumbling:
		var was_passed := o.passed
		o.shatter()
		if not was_passed:
			passed_segment += 1
			Events.obstacle_passed.emit(o.kind)   # розбита рахується як пройдена (серія не рветься)
		Events.star_collected.emit(ingot_gain(BREAK_REWARD))
		stars_collected_segment += BREAK_REWARD
		stars_spawned_segment += BREAK_REWARD   # бонус не ламає відсоток зібраного
		AudioMgr.sfx("tumble")
		return
	if o.action == "any" or not o.tumble:
		o.splash()
		FX.splash(self, Vector3(hero.position.x, 0.1, 0.0), Palette.SPLASH_WATER if o.kind == "puddle" else Palette.SPLASH_GRASS)
		AudioMgr.sfx("splash")
		return
	if hero.tumbling or hero.flying or hero.invulnerable_t > 0.0:
		return
	# суперсила («Дев'ять життів», «Ведмежі обійми»): удар поглинуто мовчки, серце ціле
	if absorb_hits > 0:
		absorb_hits -= 1
		hero.set_invulnerable(INVULN_SEC)
		FX.burst(self, Vector3(hero.position.x, 0.7, 0.0), Palette.HERO_SHIELD)
		AudioMgr.sfx("shield")
		if run.has_method("on_hit_absorbed"):
			run.call("on_hit_absorbed", absorb_hits)
		_clear_ahead(1.0)
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
	# v1.4: на нулі сердець рівень НЕ перезапускається — далі вирішує Run3D (сорока краде злитки)
	if hero.lose_heart():
		hearts_lost_segment += 1
		Events.hearts_changed.emit(hero.hearts)


## Після падіння дорога на N секунд чиста — дитина встигає оговтатись.
func _clear_ahead(seconds: float) -> void:
	for c in get_children():
		if c is Obstacle3D and not (c as Obstacle3D).hit and c.position.z < 0.0 and mode.seconds_to_hero(-c.position.z) < seconds:
			c.queue_free()


# ---------- малювання злитків ----------

## Скільки місця тримаємо в пачці. Більше за все, що буває в кадрі: злитки живуть лише у
## вікні траси, і шістдесят — це вже щедро.
const INGOT_CAP := 256


## Дві пачки: звичайні злитки й великі. Робимо раз на старті — меш і матеріал у них однакові
## назавжди, міняються лише трансформи.
##
## Місце виділяємо ОДИН РАЗ, а щокадру міняємо тільки visible_instance_count. Спершу я міняв
## instance_count щокадру — і записані одразу по ньому трансформи не доїжджали: буфер
## перевиділяється, і читалися нулі. Так само робить і траса (Track._decor_layer).
func _make_ingot_meshes() -> void:
	for i in 2:
		var mesh := Ingot3D.mesh_for(i == 1)
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = INGOT_CAP
		mm.visible_instance_count = 0
		var mi := MultiMeshInstance3D.new()
		mi.name = "ЗлиткиВеликі" if i == 1 else "Злитки"
		mi.multimesh = mm
		mi.material_override = Ingot3D.glow_material()
		# Межі задаємо руками: без них пачку рахують за інстансами, а порожню — за точку в
		# нулі, і вона зникає з кадру разом з усіма злитками.
		# Від точки вбивання (KILL_Z, за спиною) до глибини спавну з запасом.
		var box := AABB(Vector3(-8.0, -2.0, SPAWN_Z - 12.0), Vector3(16.0, 8.0, KILL_Z - SPAWN_Z + 16.0))
		mm.custom_aabb = box
		mi.custom_aabb = box
		# Пачка не «їде» разом із дорогою: трансформи в ній АБСОЛЮТНІ й перезаписуються щокадру
		# з позицій самих злитків, тож advance() її не чіпає — і не сміє, інакше зсув подвоївся б.
		mi.top_level = true
		add_child(mi)
		_ingot_mm[i] = mi


## Перекласти місця живих злитків у пачки. Щокадру: злитки рухаються магнітом, крутяться й
## зникають, тож попередній кадр не переживає жодної секунди.
func _refresh_ingot_meshes() -> void:
	var lists := [[], []]
	for c in get_children():
		if c is Ingot3D:
			var s := c as Ingot3D
			lists[1 if s.is_big() else 0].append(s)
	for i in 2:
		var mi: MultiMeshInstance3D = _ingot_mm[i]
		if mi == null:
			continue
		var live: Array = lists[i]
		var n := mini(live.size(), INGOT_CAP)
		for j in n:
			mi.multimesh.set_instance_transform(j, (live[j] as Ingot3D).visual_transform())
		mi.multimesh.visible_instance_count = n
