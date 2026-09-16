## Вигляд рівня: те, що легко зламати мовчки, бо на тестах воно ніяк не позначається.
##
## Тут стережемо три речі, кожна з яких уже була вадою в цьому проєкті:
##   - колір дороги задається ДАНИМИ, а не зашитий у палітру;
##   - спрайт із кількох боків має розмір однієї клітинки, а не всієї смуги;
##   - у гри ввімкнені тіні (без них кожен предмет лежить пласкою наліпкою).
extends GutTest


func _world(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/worlds/%s.json" % name, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Колір покриття був зашитий у Palette й однаковий у всіх світів: піщану стежку містечка
## не можна було відрізнити від бруківки іншого рівня інакше, як міняючи ВИД покриття —
## а вид тягне за собою й малюнок плиток.
func test_road_colour_comes_from_the_world() -> void:
	var plain: Array = Track.surface_colors("slabs")
	var tinted: Array = Track.surface_colors("slabs", "#E7C489")
	assert_ne(plain[0], tinted[0], "колір зі світу справді підміняє палітру")
	assert_eq(tinted[0], Color("#E7C489"), "і саме той, що задано")
	assert_true((tinted[1] as Color).v < (tinted[0] as Color).v, "другий відтінок темніший — з них і складається малюнок")


## Вид покриття лишається за малюнок навіть тоді, коли колір задано: інакше дошки стали б
## нерозрізненні від плит.
func test_surface_pattern_survives_the_tint() -> void:
	var a := Track.tile_color("planks", 0, 0, "#E7C489")
	var b := Track.tile_color("planks", 1, 0, "#E7C489")
	assert_ne(a, b, "дошки лишаються смугами по рядах")


func test_world_without_colour_keeps_the_palette() -> void:
	var c: Array = Track.surface_colors("slabs", null)
	assert_eq(c[0], Palette.W_SLAB, "нема поля — беремо палітру, як і раніше")


## Кущ малюється спрайтом із восьми боків. Найлегше тут помилитись у розмірі: якщо взяти
## ширину всієї СМУГИ замість однієї клітинки, кущ розтягнеться у стрічку на вісім метрів.
func test_multi_angle_sprite_uses_one_cell_not_the_whole_strip() -> void:
	PropLibrary.reload()
	if not PropLibrary.has("bush_flower"):
		pass_test("спрайта куща ще нема — крок пропущено")
		return
	var m := PropLibrary.mesh("bush_flower")
	assert_not_null(m, "меш є")
	var quad := m as QuadMesh
	assert_not_null(quad, "спрайт малюється дощечкою")
	if quad != null:
		assert_lt(quad.size.x, 1.5, "ширина — однієї клітинки, а не всієї смуги з восьми")
		assert_gt(quad.size.x, 0.05, "і не нульова")


## Без тіней кожен предмет лежить пласкою наліпкою — саме тінь дає об'єм, і саме її
## бракувало, коли рівень виглядав «жахливо».
func test_the_game_casts_shadows() -> void:
	var scene := load("res://src/run3d/run3d.tscn") as PackedScene
	assert_not_null(scene, "сцена гри читається")
	if scene == null:
		return
	var state := scene.get_state()
	var found := false
	for i in state.get_node_count():
		if state.get_node_type(i) != &"DirectionalLight3D":
			continue
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == &"shadow_enabled":
				found = found or bool(state.get_node_property_value(i, p))
	assert_true(found, "сонце в грі кидає тінь")
