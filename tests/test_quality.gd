## Якість зображення (OPT-11): вибір дорослого на екрані батьків.
##
## У `--headless` частина рендерних показників підставна, тож тут стережемо лише те, що
## headless бачить ЧЕСНО: значення в збереженні й значення `msaa_3d` у в'юпорті. Як це
## виглядає — знімком у справжньому вікні (tools/probe, ручка QUALITY=), а не тут.
extends GutTest

var _saved  # що стояло в збереженні до тесту — повертаємо, щоб не псувати інші тести
var _saved_msaa: int


func before_each() -> void:
	_saved = SaveService.setting(Quality.KEY, null)
	_saved_msaa = get_tree().root.msaa_3d


func after_each() -> void:
	if _saved == null:
		SaveService.data["settings"].erase(Quality.KEY)
		SaveService.save_game()
	else:
		SaveService.set_setting(Quality.KEY, _saved)
	get_tree().root.msaa_3d = _saved_msaa as Viewport.MSAA
	get_tree().paused = false


## Станів щонайменше три, і вони йдуть від найдешевшого до найдорожчого.
func test_states_are_ordered_from_cheap_to_pretty() -> void:
	assert_eq(Quality.ORDER.size(), 3, "станів якості")
	var prev := -1
	for q in Quality.ORDER:
		var m := Quality.msaa_of(q)
		assert_gt(m, prev, "стан «%s» мусить бути дорожчим за попередній" % q)
		prev = m
	assert_eq(Quality.msaa_of(Quality.SMOOTH), int(Viewport.MSAA_DISABLED), "«Плавно» — без MSAA")
	assert_eq(Quality.msaa_of(Quality.PRETTY), int(Viewport.MSAA_4X), "«Гарно» — MSAA 4×")


## Підписи — українською й без слова MSAA: їх читає батько, а не рушій.
func test_labels_are_for_parents() -> void:
	for q in Quality.ORDER:
		var l := Quality.label_of(q)
		assert_ne(l, q, "стан «%s» мусить мати людський підпис" % q)
		assert_false(l.to_lower().contains("msaa"), "підпис «%s» не має містити MSAA" % l)


## Типове — найдешевший стан: гра мобільна й для малят (див. Quality.DEFAULT).
func test_default_is_the_cheapest_state() -> void:
	assert_eq(Quality.DEFAULT, Quality.ORDER[0], "типовим мусить бути найдешевший стан")
	SaveService.data["settings"].erase(Quality.KEY)
	assert_eq(Quality.current(), Quality.DEFAULT, "порожнє збереження → типове")


## Зіпсоване значення в збереженні — це типове, а не збій.
func test_unknown_value_falls_back_to_default() -> void:
	SaveService.set_setting(Quality.KEY, "ультра-мега")
	assert_eq(Quality.current(), Quality.DEFAULT)
	Quality.set_current("ультра-мега")
	assert_eq(Quality.current(), Quality.DEFAULT, "невідому назву не приймаємо")


## Головне: вибір ЗБЕРІГАЄТЬСЯ (переживає перезапуск) і ЗАСТОСОВУЄТЬСЯ (в'юпорт одразу).
func test_choice_is_saved_read_back_and_applied() -> void:
	for q in Quality.ORDER:
		Quality.set_current(q)
		# застосовано: в'юпорт уже має нове згладжування, без перезапуску
		assert_eq(int(get_tree().root.msaa_3d), Quality.msaa_of(q), "msaa після вибору «%s»" % q)
		# збережено: значення лежить у settings
		assert_eq(String(SaveService.setting(Quality.KEY, "")), q, "у збереженні «%s»" % q)
		# прочитано назад: перечитуємо файл із диска, як при наступному запуску гри
		SaveService.load_game()
		assert_eq(Quality.current(), q, "після перечитування збереження «%s»" % q)


## Сторож самого сторожа: якщо apply() перестане чіпати в'юпорт, тест мусить це побачити.
## Тому спершу ставимо завідомо чуже значення й дивимось, що apply() його ПЕРЕБИВАЄ.
func test_apply_overrides_whatever_viewport_had() -> void:
	Quality.set_current(Quality.SMOOTH)
	get_tree().root.msaa_3d = Viewport.MSAA_8X
	Quality.apply()
	assert_eq(int(get_tree().root.msaa_3d), int(Viewport.MSAA_DISABLED), "apply() мусить перебити чуже значення")


## Ручка для замірів: apply_state міняє в'юпорт і НЕ чіпає збереження.
func test_apply_state_does_not_touch_save() -> void:
	Quality.set_current(Quality.SMOOTH)
	Quality.apply_state(Quality.PRETTY)
	assert_eq(int(get_tree().root.msaa_3d), Quality.msaa_of(Quality.PRETTY), "в'юпорт змінено")
	assert_eq(String(SaveService.setting(Quality.KEY, "")), Quality.SMOOTH, "збереження не змінено")


## Екран батьків: кнопки є, підписані по-людськи, і натискання міняє картинку одразу.
func test_parents_screen_has_quality_buttons_that_apply_at_once() -> void:
	var scene: Node = load("res://src/run3d/run3d.tscn").instantiate()
	add_child(scene)
	await wait_process_frames(10)
	var hud: Node = scene.get_node("HUD")
	Quality.set_current(Quality.SMOOTH)
	# панель будується синхронно — кадрів на паузі не чекаємо
	hud._open_parents()
	var btns: Dictionary = hud._quality_btns
	assert_eq(btns.size(), Quality.ORDER.size(), "кнопок якості на екрані батьків")
	for q in Quality.ORDER:
		assert_true(btns.has(q), "кнопка стану «%s»" % q)
		assert_eq((btns[q] as Button).text, Quality.label_of(q), "підпис кнопки «%s»" % q)
	assert_true((btns[Quality.SMOOTH] as Button).button_pressed, "чинний стан — натиснутий")
	# натиск «Гарно»: зберігається й застосовується без перезапуску
	(btns[Quality.PRETTY] as Button).emit_signal("pressed")
	assert_eq(Quality.current(), Quality.PRETTY, "вибір збережено")
	assert_eq(int(get_tree().root.msaa_3d), Quality.msaa_of(Quality.PRETTY), "в'юпорт змінено одразу")
	assert_true((btns[Quality.PRETTY] as Button).button_pressed, "нова кнопка натиснута")
	assert_false((btns[Quality.SMOOTH] as Button).button_pressed, "стара кнопка відпущена")
	hud._close_parents()
	get_tree().paused = false
	scene.free()


## Панель батьків підросла на рядок якості (800×480 → 800×620). Сторож форми: на жодній
## формі екрана — планшет 4:3, базове вікно, телефон 19.5:9 — панель не мусить вилазити за
## полотно, інакше кнопка «Назад» або сам вибір опиняться за краєм.
const SHAPES := [Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(2340, 1080)]


func test_parents_panel_fits_every_screen_shape() -> void:
	var scene: Node = load("res://src/run3d/run3d.tscn").instantiate()
	add_child(scene)
	await wait_process_frames(10)
	var hud: Node = scene.get_node("HUD")
	for shape in SHAPES:
		get_tree().root.size = shape
		await wait_process_frames(5)
		hud._open_parents()
		# панель побудовано — паузу знімаємо одразу, щоб чекання кадрів не зависло
		get_tree().paused = false
		await wait_process_frames(5)
		var canvas := hud.get_viewport().get_visible_rect().size
		var r: Rect2 = (hud._parents_panel as Control).get_global_rect()
		assert_gt(r.position.x, -1.0, "%s: панель вилізла за лівий край" % str(shape))
		assert_gt(r.position.y, -1.0, "%s: панель вилізла за верхній край" % str(shape))
		assert_lt(r.end.x, canvas.x + 1.0, "%s: панель ширша за полотно" % str(shape))
		assert_lt(r.end.y, canvas.y + 1.0, "%s: панель вища за полотно" % str(shape))
		# кнопки якості теж мусять бути на екрані, а не лише панель
		for q in Quality.ORDER:
			var b: Button = hud._quality_btns[q]
			var br := b.get_global_rect()
			assert_lt(br.end.x, canvas.x + 1.0, "%s: кнопка «%s» за правим краєм" % [str(shape), q])
			assert_lt(br.end.y, canvas.y + 1.0, "%s: кнопка «%s» за нижнім краєм" % [str(shape), q])
		hud._close_parents()
		await wait_process_frames(2)
	get_tree().root.size = Vector2i(1280, 720)
	scene.free()
