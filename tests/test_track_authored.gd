## Track.set_authored_timeline()/clear_authored_timeline() — Phase 1 «level-authoring plumbing».
## Той самий стиль інваріантів, що й tests/test_track_batching.gd (visible == recorded);
## тут ще й перевіряємо, що жоден authored-запис не губиться й не дублюється при перевкладанні.
extends GutTest

var _track: Track


func _world(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/worlds/%s.json" % name, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func before_each() -> void:
	_track = Track.new()
	add_child_autofree(_track)
	await wait_process_frames(2)


func _records() -> int:
	var n := 0
	for ids in _track._decor_ids:
		n += (ids as PackedInt32Array).size()
	return n


func _visible() -> int:
	var n := 0
	for mi in _track._decor_mm:
		n += (mi.multimesh as MultiMesh).visible_instance_count
	return n


func _flat_records(count: int, step: float = 4.0, kind: String = "flower") -> Array:
	var out := []
	for i in range(count):
		out.append({
			"z_m": float(i) * step, "x_m": 0.5, "y_m": 0.0,
			"kind": kind, "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0,
		})
	return out


func test_authored_decor_placed_exactly_once_and_matches_visible() -> void:
	var records := _flat_records(10)   # z_m 0..36 — усі в початковому вікні рядів (~-5.5..38.5)
	_track.set_authored_timeline(records, [])
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_eq(_records(), 10, "усі 10 authored-записів потрапили рівно по одному разу")
	assert_eq(_visible(), _records(), "видимих інстансів рівно стільки, скільки записано")


func test_authored_decor_survives_full_row_wrap_without_double_counting() -> void:
	var records := _flat_records(10)
	_track.set_authored_timeline(records, [])
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	# проїхати більше, ніж довжина траси: кожен ряд перевкладеться щонайменше раз
	for i in range(Track.ROWS + 8):
		_track.advance(1.0)
	await wait_process_frames(2)
	assert_eq(_visible(), _records(), "після перевкладання рядів облік і далі збігається (нема подвійного рахунку)")


func test_authored_buildings_are_placed_via_same_add_decor_path() -> void:
	var buildings := [{"z_m": 5.0, "x_m": 3.0, "y_m": 0.0, "kind": "house_red", "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.2}]
	_track.set_authored_timeline([], buildings)
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_eq(_records(), 1, "будинок з authored-списку теж пишеться у _decor_ids/_decor_data")
	assert_eq(_visible(), 1)


func test_unknown_authored_kind_is_skipped_not_crashed() -> void:
	var records := [{"z_m": 5.0, "x_m": 0.0, "y_m": 0.0, "kind": "no_such_voxel_xyz", "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0}]
	_track.set_authored_timeline(records, [])
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_eq(_records(), 0, "неіснуючий voxel-kind мовчки пропускається (як і у випадковому декорі)")


## Регресія: без authored-таймлайну (типовий стан для всіх 17 рівнів, поки що) поведінка та сама,
## що й до цієї фічі — лужок і далі засаджується випадковим декором (tests/test_track_batching.gd).
func test_no_authored_timeline_keeps_procedural_decor() -> void:
	assert_false(_track._authored_active, "без set_authored_timeline() трек лишається процедурним за замовчуванням")
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_gt(_records(), 60, "лужок і далі засаджений випадковим декором")
	assert_eq(_visible(), _records())


func test_clear_authored_timeline_restores_procedural_decor() -> void:
	_track.set_authored_timeline(_flat_records(3), [])
	assert_true(_track._authored_active)
	_track.clear_authored_timeline()
	assert_false(_track._authored_active)
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_gt(_records(), 60, "після clear_authored_timeline() лужок знову засаджений випадковим декором")
