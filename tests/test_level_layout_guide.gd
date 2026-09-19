## Путівник-дорога, який LevelLayout малює в редакторі: чи знає він, ЯКИЙ світ показує.
##
## Це не косметика. Автор ставить маркери оком, дивлячись саме на цей путівник: де край дороги,
## де канал, де вода. Показати не ту ширину означає дати йому поставити декор на бігову смугу,
## а будинок — у воду, і побачить він це аж у грі.
##
## Вада, заради якої файл існує. Номер рівня путівник брав ЗІ ШЛЯХУ СЦЕНИ
## (levels/level_07/chunk_02.tscn → 7). У цеглинки бібліотеки номера нема й бути не може — вона
## лягає в різні рівні. Тобто будь-яка цеглинка малювалась типовим: три смуги, без каналу, без
## води. Для п'ятисмугової цеглинки це розходження на цілий метр з кожного боку.
extends GutTest

var _layout: LevelLayout


func before_each() -> void:
	_layout = LevelLayout.new()
	add_child_autofree(_layout)


## scene_file_path у зібраного вручну вузла порожній, тож підсовуємо шлях так само, як його
## побачив би редактор.
func _world_of(path: String) -> Dictionary:
	_layout.scene_file_path = path
	return _layout._world_data()


func test_library_chunk_takes_lanes_and_world_from_its_own_descriptor() -> void:
	var w := _world_of("res://levels/chunks/meadow_wide_field/chunk.tscn")
	assert_eq(int(w["lanes"]), 5, "п'ятисмугова цеглинка малюється на п'ять смуг")
	assert_eq(String(w["canal_side"]), "both", "і з каналом Лужка, а не без нього")
	assert_gt(float(w["canal_width"]), 0.0)


## Розкладка лежить поруч із chunk.json у тій самій теці — вона мусить бачити той самий світ.
func test_layout_scene_of_a_chunk_sees_the_same_world() -> void:
	var a := _world_of("res://levels/chunks/meadow_wide_field/chunk.tscn")
	var b := _world_of("res://levels/chunks/meadow_wide_field/layout_hard.tscn")
	assert_eq(int(b["lanes"]), int(a["lanes"]))
	assert_eq(String(b["canal_side"]), String(a["canal_side"]))


func test_three_lane_chunk_is_drawn_narrow() -> void:
	var w := _world_of("res://levels/chunks/meadow_gate/chunk.tscn")
	assert_eq(int(w["lanes"]), 3)


## Край дороги — те саме число, що й у грі (Track.road_width() / 2). Саме з ним автор звіряє,
## чи не заліз декор на смугу.
func test_road_edge_matches_the_game_for_both_widths() -> void:
	assert_almost_eq(_layout.half_road(3), 1.6, 0.001)
	assert_almost_eq(_layout.half_road(5), 2.6, 0.001)


## Сцени, які НЕ з бібліотеки, і далі шукають рівень за номером у шляху — рівні-теки нікуди
## не поділись, і ламати їх не можна.
func test_folder_level_scene_still_reads_its_level_number() -> void:
	var w := _world_of("res://levels/level_07/chunk_02.tscn")
	assert_eq(int(w["level"]), 7)


## Шлях, який не схожий ні на те, ні на те, — типове й без падіння.
func test_unknown_path_falls_back_to_defaults_without_crashing() -> void:
	var w := _world_of("res://somewhere/else.tscn")
	assert_eq(int(w["lanes"]), 3)
	assert_eq(String(w["canal_side"]), "")
