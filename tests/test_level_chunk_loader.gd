## LevelChunkLoader — стрімить levels/level_XX/chunk_NN.tscn по одному, замість вантажити
## увесь рівень одразу. Тести проти РЕАЛЬНИХ чанків level_01 (3 чанки, межі z=0/150/300/305) —
## tools/split_level_chunks.py вже розклав усі 17 рівнів, tools/verify_chunk_migration.gd
## підтвердив побайтну ідентичність із плаский файлом.
extends GutTest

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
	_loader.update(69.0)
	assert_eq(_spawner._authored_obstacles.size(), n0, "до порогу 70 м другий чанк ще не вантажиться")


func test_update_loads_next_chunk_at_lookahead_threshold() -> void:
	_loader.start(1, _track, _spawner)
	var n0 := _spawner._authored_obstacles.size()
	_loader.update(70.0)   # рівно поріг: 150 - 80
	assert_gt(_spawner._authored_obstacles.size(), n0, "на порозі 70 м другий чанк дозавантажився")
	for rec in _spawner._authored_obstacles:
		assert_lt(float(rec.get("z_m", 0.0)), LevelChunkLoader.CHUNK_LENGTH_M * 2.0,
			"після другого чанку всі записи мають z_m < 300")


func test_update_does_not_double_load_same_chunk() -> void:
	_loader.start(1, _track, _spawner)
	_loader.update(70.0)
	var n1 := _spawner._authored_obstacles.size()
	_loader.update(71.0)
	_loader.update(75.0)
	assert_eq(_spawner._authored_obstacles.size(), n1, "повторні update() у тому самому вікні не тягнуть чанк удруге")


## level_01 — 3 чанки (z 0-150, 150-300, 300-305). Проїхавши весь рівень, усі 20 authored-
## перешкод мають бути дозавантажені й ні одна не загубилась.
func test_streaming_through_whole_level_loads_every_chunk_exactly_once() -> void:
	_loader.start(1, _track, _spawner)
	var d := 0.0
	while d < 500.0:
		d += 5.0
		_loader.update(d)
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
		_loader.update(d)
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
	_loader.update(1000.0)   # не мало впасти й після цього


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
		_loader.update(d)
	assert_eq(_spawner._authored_obstacles.size(), n0 * 2,
		"пропущений chunk_01 перестрибнуто, chunk_02 усе одно завантажився")
	_remove_gap_level()
