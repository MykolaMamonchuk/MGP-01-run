## ChunkLibrary — бібліотека цеглинок і збирач рівня з них.
##
## Головне, заради чого все це: та сама цеглинка мусить ставати на РІЗНІ місця різних рівнів.
## Доти рівень був текою levels/level_XX/, і номер файлу був водночас місцем — тобто чанк
## належав рівно одному рівню й одному метру. Тут перевіряємо, що зв'язок розірвано, а натомість
## з'явився контроль стиків: несумісна пара має бути ПОМИЛКОЮ ЗБІРКИ, а не обривом дороги
## посеред бігу.
extends GutTest

## Бібліотека будується словником просто в тесті: assemble() свідомо бере її параметром, а не
## лізе на диск сам, — саме щоб правила перевірялись на правилах, а не на знімку файлів.
func _lib(entries: Dictionary) -> Dictionary:
	var out := {}
	for id in entries:
		var desc: Dictionary = entries[id]
		desc["id"] = id
		out[id] = {
			"dir": "res://levels/chunks/%s" % id,
			"scene": "res://levels/chunks/%s/chunk.tscn" % id,
			"desc": desc,
		}
	return out


func _straight(length := 150.0, lanes := 3) -> Dictionary:
	return {"worlds": ["meadow"], "entry_lanes": lanes, "exit_lanes": lanes, "length_m": length}


# --- збирання ---------------------------------------------------------------------------

## Те, заради чого бібліотека й пишеться: один і той самий файл стоїть у рівні двічі, і кожен
## раз на своєму метрі. У теці-рівні це було неможливо в принципі — ім'я файлу було місцем.
func test_same_chunk_twice_lands_on_two_different_metres() -> void:
	var lib := _lib({"straight": _straight(150.0)})
	var built := ChunkLibrary.assemble(
		{"world": "meadow", "lanes": 3, "chunks": ["straight", "straight"]}, lib)
	assert_eq(built["errors"], [], "однакові цеглинки поспіль — це нормально")
	var pieces: Array = built["pieces"]
	assert_eq(pieces.size(), 2)
	assert_eq(pieces[0]["path"], pieces[1]["path"], "файл той самий")
	assert_almost_eq(float(pieces[0]["offset_m"]), 0.0, 0.001)
	assert_almost_eq(float(pieces[1]["offset_m"]), 150.0, 0.001, "друга копія — на 150-му метрі")
	assert_almost_eq(float(built["length_m"]), 300.0, 0.001)


## Зсув накопичувальний, а не «номер × 150»: цеглинки різної довжини кладуться впритул.
func test_offsets_accumulate_for_chunks_of_different_length() -> void:
	var lib := _lib({"a": _straight(40.0), "b": _straight(150.0), "c": _straight(90.0)})
	var built := ChunkLibrary.assemble(
		{"world": "meadow", "lanes": 3, "chunks": ["a", "b", "c"]}, lib)
	assert_eq(built["errors"], [])
	var offsets: Array = []
	for p in built["pieces"]:
		offsets.append(float(p["offset_m"]))
	assert_eq(offsets, [0.0, 40.0, 190.0])
	assert_almost_eq(float(built["length_m"]), 280.0, 0.001)


# --- стики ------------------------------------------------------------------------------

## Стик — це та сама вада, заради якої збирач і пишеться. Рівень із нею не збирається взагалі,
## а не збирається «якось»: інакше на бігу дорога просто обірвалась би.
func test_lane_mismatch_between_neighbours_is_an_error() -> void:
	var lib := _lib({
		"narrow": {"worlds": ["meadow"], "entry_lanes": 3, "exit_lanes": 3, "length_m": 150.0},
		"wide": {"worlds": ["meadow"], "entry_lanes": 5, "exit_lanes": 5, "length_m": 150.0},
	})
	var built := ChunkLibrary.assemble(
		{"world": "meadow", "lanes": 3, "chunks": ["narrow", "wide"]}, lib)
	assert_eq(built["errors"].size(), 1, "рівно одна скарга — на стик")
	assert_string_contains(String(built["errors"][0]), "wide")


## Розширювач (3 → 5) стик зводить: після нього наступний чекає вже 5 доріжок.
func test_widening_chunk_makes_the_next_five_lane_chunk_fit() -> void:
	var lib := _lib({
		"widen": {"worlds": ["meadow"], "entry_lanes": 3, "exit_lanes": 5, "length_m": 150.0},
		"wide": {"worlds": ["meadow"], "entry_lanes": 5, "exit_lanes": 5, "length_m": 150.0},
	})
	var built := ChunkLibrary.assemble(
		{"world": "meadow", "lanes": 3, "chunks": ["widen", "wide"]}, lib)
	assert_eq(built["errors"], [])
	assert_eq(int(built["exit_lanes"]), 5, "рівень закінчується п'ятьма доріжками")


## Перший чанк стикується не з попереднім (його нема), а з шириною САМОГО РІВНЯ з levels.json.
## Інакше рівень на 5 доріжок тихо починався б трисмуговою цеглинкою.
func test_first_chunk_must_match_the_level_lane_count() -> void:
	var lib := _lib({"narrow": _straight(150.0, 3)})
	var built := ChunkLibrary.assemble(
		{"world": "meadow", "lanes": 5, "chunks": ["narrow"]}, lib)
	assert_eq(built["errors"].size(), 1)
	assert_string_contains(String(built["errors"][0]), "5")


# --- придатність і цілісність ------------------------------------------------------------

func test_unknown_id_is_an_error_and_names_its_place_in_the_list() -> void:
	var built := ChunkLibrary.assemble(
		{"world": "meadow", "lanes": 3, "chunks": ["ghost"]}, _lib({}))
	assert_eq(built["errors"].size(), 1)
	assert_string_contains(String(built["errors"][0]), "ghost")


func test_chunk_of_another_world_is_an_error() -> void:
	var lib := _lib({"snowy": {"worlds": ["winter"], "entry_lanes": 3, "exit_lanes": 3,
		"length_m": 150.0}})
	var built := ChunkLibrary.assemble(
		{"world": "meadow", "lanes": 3, "chunks": ["snowy"]}, lib)
	assert_eq(built["errors"].size(), 1)
	assert_string_contains(String(built["errors"][0]), "meadow")


## Порожній список світів — «підходить усюди»: чисто геометрична цеглинка без прив'язки до
## біому не мусить перелічувати всі сімнадцять світів, щоб її пустили.
func test_chunk_without_world_list_fits_any_world() -> void:
	var lib := _lib({"any": {"entry_lanes": 3, "exit_lanes": 3, "length_m": 150.0, "worlds": []}})
	var built := ChunkLibrary.assemble(
		{"world": "winter", "lanes": 3, "chunks": ["any"]}, lib)
	assert_eq(built["errors"], [])


## Нульова довжина — не «нуль метрів», а зламаний опис: наступні цеглинки лягли б поверх цієї.
func test_non_positive_length_is_an_error() -> void:
	var lib := _lib({"flat": {"worlds": ["meadow"], "entry_lanes": 3, "exit_lanes": 3,
		"length_m": 0.0}})
	var built := ChunkLibrary.assemble(
		{"world": "meadow", "lanes": 3, "chunks": ["flat"]}, lib)
	assert_eq(built["errors"].size(), 1)
	assert_string_contains(String(built["errors"][0]), "length_m")


func test_empty_chunk_list_assembles_into_nothing_without_complaints() -> void:
	var built := ChunkLibrary.assemble({"world": "meadow", "lanes": 3, "chunks": []}, _lib({}))
	assert_eq(built["errors"], [])
	assert_eq(built["pieces"], [])
	assert_almost_eq(float(built["length_m"]), 0.0, 0.001)


# --- читання з диска ---------------------------------------------------------------------

const FIXTURE_ROOT := "res://levels/chunks_test_fixture"


func _make_fixture() -> void:
	DirAccess.make_dir_recursive_absolute("%s/brick" % FIXTURE_ROOT)
	var f := FileAccess.open("%s/brick/chunk.json" % FIXTURE_ROOT, FileAccess.WRITE)
	# id у файлі свідомо НЕ збігається з іменем теки — ім'я в описі має бути головним
	f.store_string(JSON.stringify({"id": "meadow_brick", "length_m": 40.0}))
	f.close()


func _remove_fixture() -> void:
	DirAccess.remove_absolute("%s/brick/chunk.json" % FIXTURE_ROOT)
	DirAccess.remove_absolute("%s/brick" % FIXTURE_ROOT)
	DirAccess.remove_absolute(FIXTURE_ROOT)


## Порожня бібліотека — не помилка: рівні-теки мусять працювати як раніше, доки цеглинок ще нема.
func test_scan_of_missing_root_returns_empty_without_crash() -> void:
	assert_eq(ChunkLibrary.scan("res://levels/chunks_that_do_not_exist"), {})


func test_scan_keys_the_library_by_id_from_the_description_not_the_folder_name() -> void:
	_make_fixture()
	var lib := ChunkLibrary.scan(FIXTURE_ROOT)
	_remove_fixture()
	assert_true(lib.has("meadow_brick"), "ключ — id з chunk.json")
	assert_false(lib.has("brick"), "а не ім'я теки")
	assert_eq(String(lib["meadow_brick"]["scene"]), "%s/brick/chunk.tscn" % FIXTURE_ROOT)
