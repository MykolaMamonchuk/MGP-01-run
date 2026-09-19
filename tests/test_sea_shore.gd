## У морського світу є БЕРЕГ, і на ньому щось стоїть.
##
## Скарга замовника: «світ пустий, гравець не має бачити пустоти». Пляж був найгіршим
## випадком із п'яти світів: гола вода до обрію, дорога невидима, забудова вимкнена. Вимкнена
## була справедливо — берега не існувало, і пляжна хатина ставала посеред моря без піску під
## нею. Тепер пісок є (Track.SHORE_GAP / SHORE_W), і на ньому стоїть те саме, що в інших
## світах: забудова двома рядами плюс дрібниця.
##
## Заміряно на рівні 10: предметів у кадрі 117 → 220, видів 6 → 15, буїв 53 → 25
## (вони були єдиним вмістом і йшли щоряду, через що читались як частокіл поперек моря).
extends GutTest

var _track: Track


func before_each() -> void:
	_track = Track.new()
	add_child_autofree(_track)
	await wait_process_frames(2)


func _world(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/worlds/%s.json" % name, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Скільки записів декору лежить у рядах — те саме число, яким міряє test_track_batching.
func _records() -> int:
	var n := 0
	for ids in _track._decor_ids:
		n += (ids as PackedInt32Array).size()
	return n


func test_sea_world_has_a_shore() -> void:
	_track.rebuild(_world("beach"), false)
	await wait_process_frames(2)
	assert_eq(_track._shore.size(), 2, "по плиті піску на борт")
	for sh in _track._shore:
		assert_true((sh as MeshInstance3D).visible, "на морі пісок видно")


func test_shore_does_not_overlap_the_water() -> void:
	_track.rebuild(_world("beach"), false)
	await wait_process_frames(2)
	# Вода — площина шириною (LANES_W + 0.4) × scale.x; пісок починається там, де вона
	# кінчається. Дві майже копланарні поверхні зубчаться на пологому куті — це вже третій
	# раз у цьому проєкті, і memory bank каже: не «підняти на волосок», а НЕ ПЕРЕКРИВАТИ.
	var water_half: float = (Track.LANES_W + 0.4) * _track._water.scale.x * 0.5
	for sh in _track._shore:
		var inner: float = absf((sh as MeshInstance3D).position.x) - Track.SHORE_W * 0.5
		assert_almost_eq(inner, water_half, 0.01,
			"пісок починається рівно там, де кінчається вода")


func test_land_worlds_have_no_shore_slabs() -> void:
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	for sh in _track._shore:
		assert_false((sh as MeshInstance3D).visible, "на суходолі плит піску не видно")


## Головне: на морі в рядах ТЕПЕР щось є, і цього «щось» помітно більше, ніж було самих
## буїв. Порогом беремо кількість рядів: у середньому хоча б по предмету на ряд.
func test_sea_rows_are_not_empty() -> void:
	_track.rebuild(_world("beach"), false)
	await wait_process_frames(2)
	var n := _records()
	assert_gt(n, Track.ROWS, "на морі в рядах лежить бодай предмет на ряд, а не порожнеча (%d)" % n)


## Забудова берега існує як види: помилка в назві не падає й ніде не світиться — берег
## просто лишиться порожнім, і помітити це можна тільки оком.
func test_beach_building_kinds_exist() -> void:
	var missing := []
	for kind in (_world("beach").get("buildings_far", []) as Array):
		if not _track._kind_exists(String(kind)):
			missing.append(kind)
	assert_eq(missing.size(), 0, "забудова Пляжу називає наявні види: %s" % [missing])
