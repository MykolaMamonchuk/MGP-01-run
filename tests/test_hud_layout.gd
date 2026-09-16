## HUD на чужому екрані. Гра робиться під ТЕЛЕФОНИ й ПЛАНШЕТИ, а не під вікно 1280×720,
## у якому її писали.
##
## Розтяг у проєкті — "expand": базові 1280×720 не масштабуються під форму екрана, а
## РОЗДАЮТЬСЯ по більшій осі. Заміряно: планшет 1024×768 дає полотно 1280×960, телефон
## 2340×1080 — 1560×720. Полотно ніколи не меншає, тож за екран нічого не виїжджає —
## перевірено, ця гіпотеза хибна.
##
## Вада інша й гірша на вигляд: елемент, прибитий до пікселя (пауза на x=1164), при
## базових 1280 стоїть біля правого краю, а на телефоні з полотном 1560 — за 400 точок
## від нього, тобто посеред екрана, під великим пальцем і поверх гри. Тому тут стережемо
## не «чи видно», а ПРИТУЛОК ДО КУТА: елемент, задуманий у кутку, мусить лишатися в кутку
## на будь-якій формі екрана.
extends GutTest

## 4:3 планшет (полотно вищає), базове вікно, 19.5:9 телефон (полотно ширшає).
const SHAPES := [Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(2340, 1080)]

## Скільки точок відступу від краю ще вважаємо «в кутку». Найбільший задуманий відступ
## у HUD — 96 точок (кнопка сили піднята над низом), плюс запас на округлення.
const CORNER_SLACK := 140.0

var _scene: Node
var _hud: Node


func before_each() -> void:
	_scene = load("res://src/run3d/run3d.tscn").instantiate()
	add_child(_scene)
	await wait_process_frames(10)
	_hud = _scene.get_node("HUD")


func after_each() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	_scene.free()
	_scene = null
	_hud = null


## Назва, вузол, до яких країв притулений: l/r/t/b. Знаходимо за полем HUD, а не за
## назвою вузла: назви міняються, поля лишаються.
func _watched() -> Array:
	return [
		["пауза", _hud._pause_btn, "rt"],
		["зірочки", _hud._stars_box, "rt"],
		["злиток", _hud._tally_box, "lt"],
		["серця", _hud._hearts_box, "l"],
		["для батьків", _hud._parents_btn, "lb"],
		["кнопка сили", _hud._power_btn, "rb"],
	]


func test_corner_elements_stay_in_their_corner_on_every_shape() -> void:
	assert_not_null(_hud, "HUD у сцені")
	if _hud == null:
		return
	for shape in SHAPES:
		get_tree().root.size = shape
		await wait_process_frames(4)
		var canvas: Vector2 = (_hud._root as Control).size
		for pair in _watched():
			var what: String = pair[0]
			var c: Control = pair[1]
			var sides: String = pair[2]
			assert_not_null(c, "%s є в HUD" % what)
			if c == null:
				continue
			var r := Rect2(c.global_position, c.size)
			var gap := {
				"l": r.position.x,
				"r": canvas.x - r.end.x,
				"t": r.position.y,
				"b": canvas.y - r.end.y,
			}
			for s in sides.split("", false):
				assert_lt(float(gap[s]), CORNER_SLACK,
					"%s тримається краю «%s» на %dx%d (полотно %.0fx%.0f, відступ %.0f)"
					% [what, s, shape.x, shape.y, canvas.x, canvas.y, gap[s]])
