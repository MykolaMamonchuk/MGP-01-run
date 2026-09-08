## Дорога й декор малюються пачками MultiMesh (docs/optimisation OPT-01, OPT-02).
## Тут стережемо інваріанти: скільки предметів записано в ряди — стільки й видно в шарах,
## і жоден предмет не загубився при перевкладанні рядів.
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


func _layers() -> Array:
	var out := []
	for c in _track.get_children():
		if c is MultiMeshInstance3D:
			out.append(c)
	return out


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


func test_road_is_four_layers_covering_every_row() -> void:
	var centre_even := (_track._mm_center[0].multimesh as MultiMesh).instance_count
	var centre_odd := (_track._mm_center[1].multimesh as MultiMesh).instance_count
	assert_eq(centre_even + centre_odd, Track.ROWS, "центр покриває всі ряди двома шарами (смугастість)")
	for mi in _track._mm_side:
		assert_eq((mi.multimesh as MultiMesh).instance_count, Track.ROWS, "узбіччя — інстанс на ряд")


func test_decor_layers_show_exactly_what_rows_hold() -> void:
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	# відкрите узбіччя (v1.5): пропси рідші за стіни впритул, але лужок усе одно засаджений
	assert_gt(_records(), 60, "лужок засаджений декором")
	assert_eq(_visible(), _records(), "видимих інстансів рівно стільки, скільки предметів у рядах")


func test_rows_wrapping_does_not_lose_or_double_decor() -> void:
	_track.rebuild(_world("forest"), false)
	await wait_process_frames(2)
	# проїхати більше, ніж довжина траси: кожен ряд перевкладеться щонайменше раз
	for i in range(Track.ROWS + 8):
		_track.advance(1.0)
	await wait_process_frames(2)
	assert_eq(_visible(), _records(), "після перевкладання рядів облік збігається")


func test_switching_world_reuses_layers_and_clears_old_ones() -> void:
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	var after_meadow := _layers().size()
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_eq(_layers().size(), after_meadow, "той самий світ не плодить нові шари")
	_track.rebuild(_world("beach"), false)
	await wait_process_frames(2)
	assert_eq(_visible(), _records(), "після зміни світу старі шари не показують зайвого")
