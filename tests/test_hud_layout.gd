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
		["батьки: продовжити", _hud._sleep_button, "b"],
	]


## Айфон із «острівцем», альбомно: виріз збоку, смужка жесту знизу. Підставляємо, бо в
## headless безпечна зона дорівнює вікну — на тестовій машині вирізу просто немає.
const NOTCH_WINDOW := Vector2i(2340, 1080)
const NOTCH_SAFE := Rect2i(132, 0, 2340 - 132 - 132, 1080 - 63)


func _root_offsets() -> Vector4:
	var r: Control = _hud._root
	return Vector4(r.offset_left, r.offset_top, r.offset_right, r.offset_bottom)


## Відступи мусять лишатися ті самі, скільки б разів їх не перераховували. Вада, що була
## до 17.09.2026: у розрахунок ішов _root.size, а він PRESET_FULL_RECT і вже підтиснутий
## попереднім застосуванням — тож коефіцієнт щоразу занижувався і HUD підповзав під виріз.
## Заміряно пробою: 27.84 → 26.76 після ОДНІЄЇ зміни розміру вікна.
func test_safe_area_padding_does_not_creep_when_reapplied() -> void:
	assert_not_null(_hud, "HUD у сцені")
	if _hud == null:
		return
	_hud._apply_safe_area(NOTCH_SAFE, NOTCH_WINDOW)
	await wait_process_frames(2)
	var first := _root_offsets()
	# Альбомно виріз збоку, тож стережемо ЛІВИЙ відступ: offset_top тут нульовий за
	# побудовою, і перевірка на нього мовчки нічого б не стерегла.
	assert_gt(first.x, 0.0, "виріз узагалі дає відступ (інакше тест нічого не стереже)")

	for i in range(3):
		_hud._apply_safe_area(NOTCH_SAFE, NOTCH_WINDOW)
		await wait_process_frames(2)
	assert_eq(_root_offsets(), first,
		"відступи не змінюються від повторного застосування (було: сповзали до вирізу)")


## Відступи підтискають САМЕ _root, тож усе, що висить поруч із ним, безпечну зону
## проґавить. Один Control-корінь на весь HUD — це і є та умова.
func test_every_hud_element_hangs_inside_the_padded_root() -> void:
	assert_not_null(_hud, "HUD у сцені")
	if _hud == null:
		return
	var roots := []
	for child in _hud.get_children():
		if child is Control:
			roots.append(child.name)
	assert_eq(roots.size(), 1,
		"у HUD рівно один Control-корінь, інакше нові елементи не отримають відступів під виріз (знайдено: %s)"
		% [roots])

	_hud._apply_safe_area(NOTCH_SAFE, NOTCH_WINDOW)
	await wait_process_frames(4)
	var safe_rect := Rect2((_hud._root as Control).global_position, (_hud._root as Control).size)
	for pair in _watched():
		var what: String = pair[0]
		var c: Control = pair[1]
		if c == null:
			continue
		var r := Rect2(c.global_position, c.size)
		assert_true(safe_rect.encloses(r),
			"%s лишається в безпечній зоні %s (елемент %s)" % [what, safe_rect, r])


func test_corner_elements_stay_in_their_corner_on_every_shape() -> void:
	assert_not_null(_hud, "HUD у сцені")
	if _hud == null:
		return
	# екран «час спати» будуємо явно: його кнопка — єдиний вихід звідти, і саме її
	# найдорожче загубити за краєм
	_hud.show_sleep(func(): pass)
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
