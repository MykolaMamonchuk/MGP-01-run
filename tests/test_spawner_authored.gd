## Spawner3D.set_authored_obstacles()/clear_authored_obstacles() — Phase 1 «level-authoring
## plumbing». _spawn_group()/_next_gap() лишаються недоторканими (перевіряємо, що випадковий
## шлях і далі працює, коли authored-список не заданий).
extends GutTest

var _spawner: Spawner3D


func _world_meadow() -> Dictionary:
	var f := FileAccess.open("res://data/worlds/meadow.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func before_each() -> void:
	_spawner = Spawner3D.new()
	add_child_autofree(_spawner)
	await wait_process_frames(1)
	_spawner.world = _world_meadow()
	_spawner.profile = {}
	_spawner.lanes = 3
	_spawner.spawning = true
	_spawner.finish_pending = false
	# _spawn_group() (випадковий шлях, не мій код) шле Events.obstacle_spawned через mode.seconds_to_hero() —
	# authored-курсор його не викликає, але тести регресії нижче йдуть саме через _spawn_group().
	var mode := ModeBase.new()
	mode.speed = 4.0
	_spawner.mode = mode


func _obstacles() -> Array:
	var out := []
	for c in _spawner.get_children():
		if c is Obstacle3D:
			out.append(c)
	return out


## SPAWN_Z = -34: authored-запис з'являється, коли distance_m сягне z_m - abs(SPAWN_Z).
func test_authored_obstacles_spawn_in_order_at_correct_distance() -> void:
	var records := [
		{"z_m": 40.0, "kind": "stump", "lane": 1, "override": {}, "yaw_deg": 0.0, "scale": 1.0},
		{"z_m": 50.0, "kind": "branch", "lane": -1, "override": {}, "yaw_deg": 0.0, "scale": 1.0},
	]
	_spawner.set_authored_obstacles(records)
	for i in range(5):
		_spawner.advance(1.0)
	assert_eq(_obstacles().size(), 0, "5 м пройдено — до порогу 40-34=6 ще не дійшли")
	_spawner.advance(1.0)   # distance_m = 6.0 — перший поріг досягнуто
	assert_eq(_obstacles().size(), 1, "перша authored-перешкода з'явилась рівно на порозі")
	assert_eq(_obstacles()[0].kind, "stump")
	for i in range(9):
		_spawner.advance(1.0)   # distance_m = 15 — другий поріг (50-34=16) ще не настав
	assert_eq(_obstacles().size(), 1, "друга перешкода ще не спавнилась")
	_spawner.advance(1.0)   # distance_m = 16.0
	assert_eq(_obstacles().size(), 2, "друга з'явилась рівно на своєму порозі")
	assert_eq(_obstacles()[1].kind, "branch")


func test_authored_obstacle_uses_marker_lane() -> void:
	var records := [{"z_m": 34.0, "kind": "fence", "lane": 1, "override": {}, "yaw_deg": 0.0, "scale": 1.0}]
	_spawner.set_authored_obstacles(records)
	_spawner.advance(0.0)   # поріг 34-34=0 — має спавнитись негайно
	assert_eq(_obstacles().size(), 1)
	assert_eq(_obstacles()[0].lane, 1, "доріжка бере значення з lane маркера, а не випадкова")


func test_authored_obstacles_do_not_spawn_when_not_spawning() -> void:
	_spawner.spawning = false
	_spawner.set_authored_obstacles([{"z_m": 34.0, "kind": "stump", "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0}])
	_spawner.advance(0.0)
	assert_eq(_obstacles().size(), 0, "spawning=false (пауза/меню) — authored-перешкоди теж не сипляться")


## Регресія: без authored-списку (усі 17 рівнів, поки що) advance() і далі веде через
## _next_gap()/_spawn_group(), як і до цієї фічі.
func test_no_authored_obstacles_keeps_random_spawn_group() -> void:
	assert_false(_spawner._authored_active)
	for i in range(200):
		_spawner.advance(0.1)
	assert_gt(_obstacles().size(), 0, "випадковий _spawn_group() і далі ставить перешкоди без authored-списку")


func test_clear_authored_obstacles_restores_random_behavior() -> void:
	_spawner.set_authored_obstacles([{"z_m": 1000.0, "kind": "stump", "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0}])
	_spawner.clear_authored_obstacles()
	assert_false(_spawner._authored_active)
	for i in range(200):
		_spawner.advance(0.1)
	assert_gt(_obstacles().size(), 0, "після clear_authored_obstacles() спавнер знову випадковий")


## add_authored_obstacles() — LevelChunkLoader дозавантажує наступний чанк рівня "на ходу":
## курсор НЕ скидається (уже застосовані записи не спавняться вдруге), нові записи
## доступні одразу після виклику.
func test_add_authored_obstacles_does_not_reset_cursor() -> void:
	_spawner.set_authored_obstacles([{"z_m": 34.0, "kind": "stump", "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0}])
	_spawner.advance(0.0)   # перший поріг (34-34=0) — спавниться негайно
	assert_eq(_obstacles().size(), 1, "перша перешкода вже застосована курсором")
	_spawner.add_authored_obstacles([{"z_m": 1000.0, "kind": "branch", "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0}])
	assert_eq(_obstacles().size(), 1, "дозавантаження далекого запису не спавнить його негайно й не чіпає вже пройдене")


func test_add_authored_obstacles_spawns_new_chunk_records_at_their_distance() -> void:
	_spawner.set_authored_obstacles([{"z_m": 34.0, "kind": "stump", "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0}])
	_spawner.advance(0.0)
	_spawner.add_authored_obstacles([{"z_m": 40.0, "kind": "branch", "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0}])
	_spawner.advance(5.0)   # distance_m = 5.0 — поріг другого запису (40-34=6) ще не настав
	assert_eq(_obstacles().size(), 1, "запис із дозавантаженого чанку ще до свого порогу")
	_spawner.advance(1.0)   # distance_m = 6.0
	assert_eq(_obstacles().size(), 2, "запис із дозавантаженого чанку з'явився рівно на порозі")
	assert_eq(_obstacles()[1].kind, "branch")


# --- збірне на авторському рівні --------------------------------------------------------
#
# Найдорожча вада цього файлу, і знайшлась вона не тестом, а заміром. Злитки й пікапи ставить
# _spawn_group(), а авторська гілка advance() виходить із функції ДО нього — тобто на рівні,
# розставленому маркерами, дитина не збирала нічого взагалі. Заміряно на 400 м до правки:
# випадковий рівень — 80 перешкод і 276 злитків, авторський — 20 перешкод і НУЛЬ злитків.
# Квест «збери 15 зірочок» на рівні 1 був недосяжний, і жоден тест цього не бачив.

func _ingots() -> Array:
	var out := []
	for c in _spawner.get_children():
		if c is Ingot3D:
			out.append(c)
	return out


func _pickups_spawned() -> Array:
	var out := []
	for c in _spawner.get_children():
		if c is Pickup3D:
			out.append(c)
	return out


func _line(count: int, step := 15.0, first := 40.0) -> Array:
	var out := []
	for i in range(count):
		out.append({"z_m": first + float(i) * step, "kind": "stump", "lane": (i % 3) - 1,
			"override": {}, "yaw_deg": 0.0, "scale": 1.0})
	return out


func test_authored_obstacles_are_followed_by_ingots() -> void:
	_spawner.set_authored_obstacles(_line(3))
	for i in range(80):
		_spawner.advance(1.0)
	assert_eq(_obstacles().size(), 3, "усі три перешкоди з'явились")
	assert_gt(_ingots().size(), 0,
		"за авторською перешкодою йде доріжка зі злитків — так само, як за випадковою групою")


## Вільна доріжка — та, у якій перешкоди НЕМА. Раніше сюди писалась доріжка самої перешкоди,
## і авто-допомога вела дитину рівно в те, що треба обійти.
func test_free_lane_is_not_the_lane_the_obstacle_stands_in() -> void:
	_spawner.set_authored_obstacles([
		{"z_m": 40.0, "kind": "stump", "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0}])
	for i in range(10):
		_spawner.advance(1.0)
	assert_eq(_obstacles().size(), 1)
	assert_ne(_obstacles()[0].free_lane, 0, "вільна доріжка не та, у якій стоїть пеньок")


## Дві перешкоди на ОДНОМУ метрі: вільною мусить лишитись третя доріжка, а не котрась із двох.
func test_free_lane_accounts_for_the_whole_group_on_one_metre() -> void:
	_spawner.set_authored_obstacles([
		{"z_m": 40.0, "kind": "stump", "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0},
		{"z_m": 40.0, "kind": "stump", "lane": -1, "override": {}, "yaw_deg": 0.0, "scale": 1.0}])
	for i in range(10):
		_spawner.advance(1.0)
	assert_eq(_obstacles().size(), 2)
	for ob in _obstacles():
		assert_eq(ob.free_lane, 1, "вільна лишилась +1 — єдина, де нічого не стоїть")


# --- авторські пікапи -------------------------------------------------------------------

func test_authored_pickup_markers_spawn_at_their_own_place() -> void:
	_spawner.set_authored_pickups([
		{"z_m": 40.0, "kind": "heart", "lane": 1, "override": {}, "yaw_deg": 0.0, "scale": 1.0}])
	for i in range(5):
		_spawner.advance(1.0)
	assert_eq(_pickups_spawned().size(), 0, "до порогу 40-34=6 пікапа ще нема")
	_spawner.advance(1.0)
	assert_eq(_pickups_spawned().size(), 1, "на порозі пікап з'явився")
	assert_eq(_pickups_spawned()[0].kind, "heart")
	assert_almost_eq(_pickups_spawned()[0].position.x, Hero3D.LANE_W, 0.01,
		"і саме в тій доріжці, яку назвав маркер")


## Пікап, якого нема в data/pickups.json, — пропуск із попередженням, а не падіння: помилка
## в описі цеглинки не мусить валити рівень.
func test_unknown_authored_pickup_is_skipped_not_crashed() -> void:
	gut.error_tracker.treat_push_error_as = GutUtils.TREAT_AS.NOTHING
	_spawner.set_authored_pickups([
		{"z_m": 40.0, "kind": "нема_такого", "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0}])
	for i in range(10):
		_spawner.advance(1.0)
	assert_eq(_pickups_spawned().size(), 0)


## Автор розставив пікапи сам — випадкові поверх них не додаються: інакше він просив би одне,
## а рівень давав би це плюс ще щось зверху.
func test_authored_pickups_switch_off_the_random_pickup_timer() -> void:
	_spawner.set_authored_pickups([
		{"z_m": 40.0, "kind": "heart", "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0}])
	_spawner._pickup_pending = ""
	_spawner._tick_pickups(100.0)
	assert_eq(_spawner._pickup_pending, "", "випадковий таймер пікапів мовчить")


# --- другий ярус на авторському рівні --------------------------------------------------
#
# Той самий корінь, що й у злитків: _spawn_tier2() кликався лише з процедурної гілки, тож на
# рівні з маркерами другого ярусу не було зовсім (заміряно: 3 сегменти на 400 м проти нуля).
# Але просто пустити сюди таймер не можна — сегмент займає 14–20 м доріжки й накрив би
# перешкоду, яку автор поставив навмисно. Тому вибір доріжки тут усвідомлений.

func _tier2_segments() -> Array:
	var out := []
	for c in _spawner.get_children():
		if c is Tier2Segment:
			out.append(c)
	return out


## Світ Лісу — у ньому "tier2": true (у Лужку його нема зовсім).
func _world_forest() -> Dictionary:
	var f := FileAccess.open("res://data/worlds/forest.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func test_tier2_appears_on_an_authored_level_in_a_lane_that_is_free() -> void:
	_spawner.world = _world_forest()
	_spawner.lanes = 5
	# усі перешкоди в центрі — крайні доріжки вільні, ярусу є куди стати
	var recs := []
	for i in range(10):
		recs.append({"z_m": 40.0 + float(i) * 15.0, "kind": "tree", "lane": 0,
			"override": {}, "yaw_deg": 0.0, "scale": 1.0})
	_spawner.set_authored_obstacles(recs)
	_spawner._tier2_due = true
	for i in range(10):
		_spawner.advance(1.0)
	assert_eq(_tier2_segments().size(), 1, "другий ярус з'явився")
	for l in _tier2_segments()[0].lanes_used:
		assert_ne(int(l), 0, "і НЕ в тій доріжці, де стоять авторські перешкоди")


## Зайняті всі доріжки — ярус не втискається, а чекає наступної нагоди. Краще без нього, ніж
## платформа поверх перешкоди.
##
## Дивимось саме на ЩЕ НЕ ЗʼЯВЛЕНІ записи, і це не дрібниця. Сегмент лягає ДАЛІ за лінію спавну
## (z = SPAWN_Z - total_length) і перетинає її протягом наступних 14–20 м ходу — тобто заважає
## тому, що з'явиться ПОТІМ. Перешкода, яка вже стоїть, опиняється перед пандусом, а не під
## платформою, і заважати не може. Перша версія цього тесту ганяла трасу на 8 м, перший запис
## устигав з'явитись, його доріжка ставала вільною — і тест вимагав від коду неправильного.
func test_tier2_waits_when_every_lane_is_busy_nearby() -> void:
	_spawner.world = _world_forest()
	_spawner.lanes = 3
	var recs := []
	for i in range(3):
		recs.append({"z_m": 40.0 + float(i) * 4.0, "kind": "tree", "lane": i - 1,
			"override": {}, "yaw_deg": 0.0, "scale": 1.0})
	_spawner.set_authored_obstacles(recs)
	_spawner._tier2_due = true
	for i in range(5):        # 5 м — перший запис з'явиться аж на 6-му (40 - 34)
		_spawner.advance(1.0)
	assert_eq(_spawner._authored_cursor, 0, "жоден запис ще не з'явився — усі три попереду")
	assert_eq(_tier2_segments().size(), 0, "усі три доріжки зайняті — ярус почекав")
	assert_true(_spawner._tier2_due, "і лишився в черзі, а не згорів")


## Порожній хвіст рівня (авторські записи скінчились) — вільні всі доріжки.
func test_tier2_appears_after_the_last_authored_obstacle() -> void:
	_spawner.world = _world_forest()
	_spawner.lanes = 3
	_spawner.set_authored_obstacles([
		{"z_m": 40.0, "kind": "tree", "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0}])
	for i in range(10):
		_spawner.advance(1.0)
	_spawner._tier2_due = true
	_spawner.advance(1.0)
	assert_eq(_tier2_segments().size(), 1)


# --- малювання злитків пачкою -----------------------------------------------------------
#
# Злиток більше не носить власного меша: усі злитки кадру малює один MultiMesh. Кожен окремим
# вузлом коштував свого draw call, а їх на екрані під шістдесят — заміряно 244 → 298 рівно
# тоді, коли злитки вперше з'явились на авторському рівні, при цілі GDD ≤150.
#
# ЩО ТУТ ПЕРЕВІРИТИ МОЖНА, А ЧОГО НІ. У --headless рендерер підставний, і MultiMesh НЕ ЗБЕРІГАЄ
# трансформів: set_instance_transform() записує, get_instance_transform() віддає нулі. Заміряно
# на голій MultiMesh: у вікні round-trip повертає (0.5, 0.6, -10), у headless — (0, 0, 0).
# Тому місця інстансів тут не перевіряються взагалі; замість них перевіряється visual_transform()
# самого злитка — саме там і живе вся арифметика, а пачка лише переписує її в буфер.
# Кількість видимих інстансів headless переживає, тож її питаємо.
#
# Кличемо _refresh_ingot_meshes() прямо, а не check(): у цій фікстурі нема героя, і check()
# обірветься на hero.hit_box() задовго до малювання.

func _pack(big: bool) -> MultiMeshInstance3D:
	for c in _spawner.get_children():
		if c is MultiMeshInstance3D and c.name == ("ЗлиткиВеликі" if big else "Злитки"):
			return c
	return null


func test_ingots_are_drawn_by_one_pack_not_one_node_each() -> void:
	assert_not_null(_pack(false), "пачка звичайних злитків є")
	assert_not_null(_pack(true), "і пачка великих")
	_spawner.spawn_star_at(Vector3(0.0, 0.6, -10.0))
	_spawner.spawn_star_at(Vector3(1.0, 0.6, -12.0))
	_spawner.spawn_star_at(Vector3(-1.0, 0.7, -14.0), Spawner3D.BIG_VALUE)
	_spawner._refresh_ingot_meshes()
	assert_eq(_pack(false).multimesh.visible_instance_count, 2, "два звичайні злитки в своїй пачці")
	assert_eq(_pack(true).multimesh.visible_instance_count, 1, "великий — в своїй")


## Місце в пачці бере visual_transform() злитка, тож перевіряємо саме його: дорога їде —
## намальоване мусить їхати разом із нею, і вбік при цьому не з'їжджати.
func test_visual_transform_follows_the_ingot() -> void:
	_spawner.spawn_star_at(Vector3(0.5, 0.6, -10.0))
	var ing: Ingot3D = null
	for c in _spawner.get_children():
		if c is Ingot3D:
			ing = c
	assert_not_null(ing)
	assert_almost_eq(ing.visual_transform().origin.z, -10.0, 0.01)
	_spawner.advance(4.0)
	assert_almost_eq(ing.visual_transform().origin.z, -6.0, 0.01, "проїхало разом із дорогою")
	assert_almost_eq(ing.visual_transform().origin.x, 0.5, 0.01, "а вбік не з'їхало")


## Погойдування й обертання НЕ чіпають місця вузла: position міряє відстань до героя, і хитати
## його означало б хитати й дальність збирання. Хитається лише намальоване.
func test_bobbing_moves_the_drawing_but_not_the_ingot() -> void:
	_spawner.spawn_star_at(Vector3(0.0, 0.6, -10.0))
	var ing: Ingot3D = null
	for c in _spawner.get_children():
		if c is Ingot3D:
			ing = c
	var y := ing.position.y
	ing.tick(0.5, _spawner.hero if _spawner.hero != null else Node3D.new(), 1.0)
	assert_eq(ing.position.y, y, "сам злиток лишився на місці")
	assert_ne(ing.visual_transform().origin.y, y, "а намальоване гойднулось")


## Пачки — не вміст траси, а спосіб її намалювати: advance() не сміє їх ані посувати, ані
## вбивати, а clear() при зміні рівня — зносити. Інакше рівень мовчки лишився б без злитків.
func test_packs_survive_the_road_moving_and_the_level_changing() -> void:
	_spawner.spawning = false     # інакше тисяча метрів наспавнить сотні злитків
	for i in 200:
		_spawner.advance(5.0)     # далеко за KILL_Z — звичайного вузла давно б не було
	assert_not_null(_pack(false), "пачка пережила тисячу метрів дороги")
	assert_almost_eq(_pack(false).position.z, 0.0, 0.001, "і лишилась на місці")
	_spawner.spawn_star_at(Vector3(0.0, 0.6, -10.0))
	_spawner._refresh_ingot_meshes()
	assert_eq(_pack(false).multimesh.visible_instance_count, 1)
	_spawner.clear()
	assert_not_null(_pack(false), "і зміну рівня теж")
	assert_eq(_pack(false).multimesh.visible_instance_count, 0, "але спорожніла")


## Стеля пачки. Злитків у кадрі буває шістдесят, але випадковий спавнер за тисячу метрів
## наробить їх сотні — і пачка мусить це пережити, показавши стільки, скільки вміщає, а не
## впасти на виході за межі буфера. Перша версія тесту вище на цьому й спіймалась: ганяла
## трасу з увімкненим спавном і отримала 256 замість одного.
func test_pack_does_not_overflow_when_there_are_more_ingots_than_it_holds() -> void:
	for i in Spawner3D.INGOT_CAP + 20:
		_spawner.spawn_star_at(Vector3(0.0, 0.6, -float(i)))
	_spawner._refresh_ingot_meshes()
	assert_eq(_pack(false).multimesh.visible_instance_count, Spawner3D.INGOT_CAP,
		"показано рівно стільки, скільки вміщає пачка")
