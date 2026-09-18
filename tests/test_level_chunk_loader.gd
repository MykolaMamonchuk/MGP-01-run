## LevelChunkLoader — стрімить levels/level_XX/chunk_NN.tscn по одному, замість вантажити
## увесь рівень одразу. Тести проти РЕАЛЬНИХ чанків level_01 (3 чанки, межі z=0/150/300/305) —
## tools/split_level_chunks.py вже розклав усі 17 рівнів, tools/verify_chunk_migration.gd
## підтвердив побайтну ідентичність із плаский файлом.
extends GutTest

## Чанки тепер читаються У ФОНІ (заміряно: синхронно це 70 мс на Mac і 200–350 на телефоні,
## посеред бігу). Тест не має кадрів, щоб чекати, тому кличе update() і одразу забирає
## результат. У грі так ніхто не робить: там update() іде щокадру.
func _update(distance_m: float) -> void:
	_loader.update(distance_m)
	_loader.finish_pending()

var _track: Track
var _spawner: Spawner3D
var _loader: LevelChunkLoader


func before_each() -> void:
	_track = Track.new()
	add_child_autofree(_track)
	_spawner = Spawner3D.new()
	add_child_autofree(_spawner)
	await wait_process_frames(1)
	_loader = LevelChunkLoader.new()
	gut.error_tracker.treat_push_error_as = GutUtils.TREAT_AS.FAILURE


## _apply() звільняє інстанс чанку через queue_free() (не одразу) — дати рушію дійсно
## прибрати вузли між тестами, інакше GUT рахує їх орфанами наступного тесту.
func after_each() -> void:
	await wait_process_frames(1)


## chunk_00.tscn level_01 покриває z_m ∈ [0, 150) — з нього 20 маркерів-перешкод (level_01 —
## 20 obstacle-маркерів на z 20..305, з них 20..140 потрапляють у перший чанк).
func test_start_loads_first_chunk_immediately() -> void:
	_loader.start(1, _track, _spawner)
	assert_true(_spawner._authored_active, "перший чанк уже заповнив Spawner3D")
	assert_gt(_spawner._authored_obstacles.size(), 0)
	for rec in _spawner._authored_obstacles:
		assert_lt(float(rec.get("z_m", 0.0)), LevelChunkLoader.CHUNK_LENGTH_M,
			"у Spawner3D після start() лежать лише записи першого чанку (z_m < 150)")


func test_update_does_not_load_next_chunk_before_lookahead_threshold() -> void:
	_loader.start(1, _track, _spawner)
	var n0 := _spawner._authored_obstacles.size()
	# межа першого чанку — 150; поріг дозавантаження — 150 - LOOKAHEAD_M(80) = 70
	_update(69.0)
	assert_eq(_spawner._authored_obstacles.size(), n0, "до порогу 70 м другий чанк ще не вантажиться")


func test_update_loads_next_chunk_at_lookahead_threshold() -> void:
	_loader.start(1, _track, _spawner)
	var n0 := _spawner._authored_obstacles.size()
	_update(70.0)   # рівно поріг: 150 - 80
	assert_gt(_spawner._authored_obstacles.size(), n0, "на порозі 70 м другий чанк дозавантажився")
	for rec in _spawner._authored_obstacles:
		assert_lt(float(rec.get("z_m", 0.0)), LevelChunkLoader.CHUNK_LENGTH_M * 2.0,
			"після другого чанку всі записи мають z_m < 300")


func test_update_does_not_double_load_same_chunk() -> void:
	_loader.start(1, _track, _spawner)
	_update(70.0)
	var n1 := _spawner._authored_obstacles.size()
	_update(71.0)
	_update(75.0)
	assert_eq(_spawner._authored_obstacles.size(), n1, "повторні update() у тому самому вікні не тягнуть чанк удруге")


## level_01 — 3 чанки (z 0-150, 150-300, 300-305). Проїхавши весь рівень, усі 20 authored-
## перешкод мають бути дозавантажені й ні одна не загубилась.
func test_streaming_through_whole_level_loads_every_chunk_exactly_once() -> void:
	_loader.start(1, _track, _spawner)
	var d := 0.0
	while d < 500.0:
		d += 5.0
		_update(d)
	# Скільки саме перешкод у рівні — не сталість тесту: хвости рівнів дотягували під
	# швидкий профіль (tools/extend_level_tails.py), і число мінялося. Тест стереже інше —
	# що жоден чанк не завантажено двічі й жодного не загублено, тому рахуємо очікуване
	# просто з файлів рівня.
	var want := 0
	var dir := DirAccess.open("res://levels/level_01")
	for name in dir.get_files():
		if not name.ends_with(".tscn"):
			continue
		var f := FileAccess.open("res://levels/level_01/%s" % name, FileAccess.READ)
		for block in f.get_as_text().split("[node "):
			if block.contains("role = \"obstacle\""):
				want += 1
	assert_gt(want, 0, "у рівні 1 є перешкоди")
	assert_eq(_spawner._authored_obstacles.size(), want,
		"усі %d authored-перешкод level_01 дозавантажені по чанках" % want)
	var seen := {}
	for rec in _spawner._authored_obstacles:
		var z: float = rec.get("z_m", 0.0)
		assert_false(seen.has(z), "z_m=%s зустрівся двічі — чанк завантажено повторно" % z)
		seen[z] = true


## Найдовший рівень (17, 7 чанків, 218 маркерів) — той самий наскрізний прогін, що й для
## level_01 вище, лише на найбільшому реальному рівні: перевіряє, що дроблення на 7 чанків
## не губить і не дублює жодного запису.
func test_streaming_through_longest_level_loads_every_chunk_exactly_once() -> void:
	_loader.start(17, _track, _spawner)
	var d := 0.0
	while d < 1000.0:
		d += 5.0
		_update(d)
	assert_gt(_spawner._authored_obstacles.size(), 0)
	var seen := {}
	for rec in _spawner._authored_obstacles:
		var z: float = rec.get("z_m", 0.0)
		assert_false(seen.has(z), "z_m=%s зустрівся двічі — чанк завантажено повторно" % z)
		seen[z] = true
	assert_eq(seen.size(), _spawner._authored_obstacles.size())


## Нема ані папки level_XX/, ані плаский level_XX.tscn (номер, якого не існує) — тихо
## нічого не робить, Track/Spawner3D лишаються без authored-даних, без падіння.
func test_missing_level_clears_authored_state_without_crash() -> void:
	_loader.start(999, _track, _spawner)
	assert_false(_spawner._authored_active)
	assert_false(_track._authored_active)
	_update(1000.0)   # не мало впасти й після цього


## Порожній відрізок посеред рівня — це просто відсутній chunk_NN.tscn: розрізання не пише
## файл для куска без маркерів, та й автор карти може стерти середній чанк руками в редакторі.
## Раніше перший же відсутній номер читався як «рівень скінчився», і решта рівня мовчки не
## вантажилась — на швидкому профілі це кілометр порожньої дороги. Фікстура тимчасова: теку
## level_90 збираємо тут із чанків level_01 і прибираємо в after_each().
const GAP_LEVEL := 90
const GAP_DIR := "res://levels/level_%02d" % GAP_LEVEL


func _make_gap_level() -> void:
	DirAccess.make_dir_recursive_absolute(GAP_DIR)
	var src := FileAccess.get_file_as_bytes("res://levels/level_01/chunk_00.tscn")
	for name in ["chunk_00.tscn", "chunk_02.tscn"]:   # chunk_01 свідомо відсутній
		var f := FileAccess.open("%s/%s" % [GAP_DIR, name], FileAccess.WRITE)
		f.store_buffer(src)
		f.close()


func _remove_gap_level() -> void:
	var dir := DirAccess.open(GAP_DIR)
	if dir == null:
		return
	for name in dir.get_files():
		DirAccess.remove_absolute("%s/%s" % [GAP_DIR, name])
	DirAccess.remove_absolute(GAP_DIR)


func test_missing_middle_chunk_does_not_end_the_level() -> void:
	_make_gap_level()
	_loader.start(GAP_LEVEL, _track, _spawner)
	var n0 := _spawner._authored_obstacles.size()
	assert_gt(n0, 0, "chunk_00 завантажився")
	var d := 0.0
	while d < 500.0:
		d += 5.0
		_update(d)
	assert_eq(_spawner._authored_obstacles.size(), n0 * 2,
		"пропущений chunk_01 перестрибнуто, chunk_02 усе одно завантажився")
	_remove_gap_level()


## Фонове читання: update() на порозі лише ПОДАЄ ЗАЯВКУ, а не блокує. Саме це й рятує від
## підвисання посеред бігу — заміряно, що синхронне читання зарядженого чанка коштує 70 мс на
## Mac і 200–350 мс на телефоні, і відбувалось воно за 80 м до межі, тобто на повному ходу.
func test_update_only_requests_the_chunk_and_does_not_block() -> void:
	_loader.start(1, _track, _spawner)
	var n0 := _spawner._authored_obstacles.size()
	_loader.update(70.0)                      # БЕЗ finish_pending
	assert_gte(_loader._pending_index, 0, "заявку подано, чанк читається у фоні")
	assert_eq(_spawner._authored_obstacles.size(), n0,
		"але записів ще нема — потік не закінчив, і головний потік його не чекав")
	_loader.finish_pending()
	assert_eq(_loader._pending_index, -1, "після завершення заявка знята")
	assert_gt(_spawner._authored_obstacles.size(), n0, "а записи дозавантажились")


## Доки чанк читається у фоні, друга заявка не подається: інакше два чанки поїхали б у Track
## одночасно й у непередбачуваному порядку.
func test_no_second_request_while_one_is_pending() -> void:
	_loader.start(1, _track, _spawner)
	_loader.update(70.0)
	var pending := _loader._pending_index
	var next_index := _loader._next
	_loader.update(120.0)                     # поріг наступного чанку теж перейдено
	assert_eq(_loader._pending_index, pending, "заявка та сама")
	assert_eq(_loader._next, next_index, "черга не зрушила")
	_loader.finish_pending()


## --- рівень, зібраний зі списку цеглинок ------------------------------------------------
##
## Досі рівень був текою, і номер файлу був водночас місцем: chunk_02 = 300-й метр, і та сама
## цеглинка не могла стояти в рівні двічі. Тут перевіряємо наскрізно — від запису в levels.json
## до записів у Spawner3D, — що вона таки може, і що друга копія лягає на свій метр.
## Фікстуру збираємо в справжній теці бібліотеки (як level_90 вище) і прибираємо по собі.
const BRICK_ID := "test_brick_40m"
const BRICK_DIR := "res://levels/chunks/%s" % BRICK_ID
## Довжина цеглинки; маркери всередині стоять на 10-му й 30-му метрі ВІД ЇЇ ПОЧАТКУ.
const BRICK_LEN := 40.0


func _make_brick() -> void:
	DirAccess.make_dir_recursive_absolute(BRICK_DIR)
	var desc := FileAccess.open("%s/chunk.json" % BRICK_DIR, FileAccess.WRITE)
	desc.store_string(JSON.stringify({
		"id": BRICK_ID, "worlds": ["meadow"],
		"entry_lanes": 3, "exit_lanes": 3, "length_m": BRICK_LEN,
		"layouts": [{"file": "layout.tscn", "difficulty": [0.0, 1.0]}],
	}))
	desc.close()
	# Два шари: у чанку — те, що тут завжди однакове (декор), у розкладці — перешкоди під
	# складність. Обидва мусять лягти на ОДИН зсув.
	_write_scene("chunk.tscn", """
[node name="Декор" type="Node3D" parent="."]

[node name="D1_decor_tree" type="Node3D" parent="Декор"]
script = ExtResource("1")
role = "decor"
kind = "tree"
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -2.1, 0, -5.0)
""")
	_write_scene("layout.tscn", """
[node name="Перешкоди" type="Node3D" parent="."]

[node name="M1_obstacle_stump" type="Node3D" parent="Перешкоди"]
script = ExtResource("1")
role = "obstacle"
kind = "stump"
lane = 0
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -10.0)

[node name="M2_obstacle_stump" type="Node3D" parent="Перешкоди"]
script = ExtResource("1")
role = "obstacle"
kind = "stump"
lane = 1
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -30.0)
""")


## z_m у маркері — це -position.z (та сама умова, що й у справжніх чанках).
func _write_scene(file_name: String, body: String) -> void:
	var scene := FileAccess.open("%s/%s" % [BRICK_DIR, file_name], FileAccess.WRITE)
	scene.store_string("""[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://src/run3d/level_marker_3d.gd" id="1"]
[ext_resource type="Script" path="res://src/run3d/level_layout.gd" id="2"]

[node name="LevelLayout" type="Node3D"]
script = ExtResource("2")
""" + body)
	scene.close()


func _remove_brick() -> void:
	for name in ["chunk.json", "chunk.tscn", "layout.tscn"]:
		DirAccess.remove_absolute("%s/%s" % [BRICK_DIR, name])
	DirAccess.remove_absolute(BRICK_DIR)


func _brick_level(count: int) -> Dictionary:
	var ids: Array = []
	for i in count:
		ids.append(BRICK_ID)
	return {"world": "meadow", "lanes": 3, "chunks": ids}


func test_level_assembled_from_library_places_the_same_brick_twice() -> void:
	_make_brick()
	_loader.start(1, _track, _spawner, _brick_level(3))
	var d := 0.0
	while d < 200.0:
		d += 5.0
		_update(d)
	_remove_brick()
	var zs: Array = []
	for rec in _spawner._authored_obstacles:
		zs.append(roundi(float(rec.get("z_m", 0.0))))
	zs.sort()
	# 10 і 30 у кожній копії, зсунуті на 0 / 40 / 80 — тобто цеглинка справді стала тричі,
	# і саме туди, куди її поклав збирач, а не туди, де лежить її файл.
	assert_eq(zs, [10, 30, 50, 70, 90, 110])
	# Декор лежить у ДРУГІЙ сцені цеглинки. Якби завантажувач брав лише перший файл, перешкод
	# не було б зовсім; якби лише другий — не було б цього дерева. Отже обидва шари доїхали.
	var trees := 0
	for rec in _track._authored_decor:
		if String(rec.get("kind", "")) == "tree":
			trees += 1
	assert_eq(trees, 3, "декор чанка приїхав разом із розкладкою, по разу на копію")


## Список цеглинок у рівні ПЕРЕБИВАЄ стару теку levels/level_01/: інакше рівень, переведений на
## бібліотеку, мовчки вантажив би дві розкладки одночасно.
func test_chunk_list_wins_over_the_level_folder() -> void:
	_make_brick()
	_loader.start(1, _track, _spawner, _brick_level(1))
	_remove_brick()
	assert_eq(_spawner._authored_obstacles.size(), 2, "лише дві перешкоди цеглинки")
	# Обидва шари першої цеглинки читаються СИНХРОННО, ще на екрані завантаження: інакше перші
	# метри рівня зрідка й недетерміновано лишались би без перешкод.
	assert_true(_spawner._authored_active, "розкладка вже на місці, без жодного update()")


## Зламаний стик рівень не збирає взагалі. Порожній рівень помітно одразу; рівень, зібраний
## «якось», обривався б дорогою на 900-му метрі — і шукали б це довго.
func test_broken_seam_leaves_the_level_empty_instead_of_half_assembled() -> void:
	_make_brick()
	# цеглинка чекає 3 доріжки, а рівень заявлений на 5
	var level := _brick_level(2)
	level["lanes"] = 5
	# push_error тут — не збій тесту, а ТЕ, ЩО ПЕРЕВІРЯЄТЬСЯ: зламана збірка мусить кричати.
	# Прапорець знімає before_each, а не цей рядок: GUT звіряє помилки вже ПІСЛЯ тіла тесту,
	# тож повернути суворість тут означало б не поставити її взагалі.
	gut.error_tracker.treat_push_error_as = GutUtils.TREAT_AS.NOTHING
	_loader.start(1, _track, _spawner, level)
	_remove_brick()
	assert_false(_spawner._authored_active, "жодного запису зі зламаної збірки не поїхало")


## Кожен рівень із data/levels.json мусить мати непорожній план, і кожен його файл мусить
## існувати. Сторож не про завантажувач, а про ДАНІ: сторожі-інваріанти (test_level_reach,
## test_level_widening, test_level_decor_clearance, test_level_obstacle_types) ходять цим самим
## планом, і рівень, який раптом перестав його давати, зробив би половину з них вічнозеленими.
func test_every_level_in_the_data_has_a_plan_and_all_its_files_exist() -> void:
	var f := FileAccess.open("res://data/levels.json", FileAccess.READ)
	var levels: Array = JSON.parse_string(f.get_as_text()).get("levels", [])
	assert_eq(levels.size(), 17, "рівнів сімнадцять")
	for l in levels:
		var level: Dictionary = l
		var num := int(level["id"])
		var plan := LevelChunkLoader.plan_of(num, level)
		assert_false(plan.is_empty(), "рівень %d має план" % num)
		var total := 0.0
		for piece in plan:
			for scene_path in (piece as Dictionary)["paths"]:
				assert_true(ResourceLoader.exists(String(scene_path)),
					"рівень %d: %s існує" % [num, scene_path])
			assert_almost_eq(float(piece["offset_m"]), total, 0.001,
				"рівень %d: цеглинки лягають упритул, без дір і нахлистів" % num)
			total += float(piece["length_m"])
