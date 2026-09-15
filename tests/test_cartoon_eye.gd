## CartoonEye — спільна сцена ока (src/run3d/eye). Перевіряємо те, на що спирається решта:
## імена частин (за ними Hero3D і пресети), групу погляду й межу відведення зіниці.
extends GutTest

const BASE := "res://src/run3d/eye/cartoon_eye.tscn"

var _eye: CartoonEye


func before_each() -> void:
	_eye = (load(BASE) as PackedScene).instantiate() as CartoonEye
	add_child_autofree(_eye)
	await wait_process_frames(1)


func test_structure_has_named_parts() -> void:
	assert_not_null(_eye.get_node_or_null("EyeBall"), "білок")
	var pivot := _eye.get_node_or_null("IrisPivot")
	assert_not_null(pivot, "група погляду")
	for part in ["Iris", "Pupil", "HighlightBig", "HighlightSmall"]:
		assert_not_null(pivot.get_node_or_null(part), "%s — дитина IrisPivot" % part)


## Райдужка, зіниця й блики мусять їхати РАЗОМ: інакше при погляді вбік блик відклеюється.
func test_gaze_moves_the_whole_iris_group() -> void:
	var pivot := _eye.iris_pivot()
	var hi := pivot.get_node("HighlightBig") as Node3D
	var before := hi.position
	_eye.look_at_dir(Vector2(1.0, 0.0))
	assert_ne(pivot.position.x, 0.0, "група поїхала вбік")
	assert_eq(hi.position, before, "блик лишився на своєму місці ВСЕРЕДИНІ групи")


func test_gaze_is_clamped_by_max_look_offset() -> void:
	_eye.max_look_offset = 0.25
	_eye.look_at_dir(Vector2(5.0, 0.0))     # свідомо більше за межу
	assert_almost_eq(_eye.iris_pivot().position.x, _eye.eye_scale.x * 0.25, 0.0001,
		"відведення не більше за max_look_offset від півосі білка")


func test_iris_is_smaller_than_eyeball() -> void:
	var ball := (_eye.get_node("EyeBall") as MeshInstance3D).scale
	var iris := (_eye.iris_pivot().get_node("Iris") as MeshInstance3D).scale
	assert_lt(iris.x, ball.x, "райдужка вужча за білок")
	assert_lt(iris.y, ball.y, "райдужка нижча за білок")


## Пресети — та сама сцена з іншими типовими значеннями; головне, щоб вони вантажились і
## давали ту саму структуру (на них посилається heroes.json через rig_face.eye_scene).
func test_presets_load_and_keep_structure() -> void:
	for path in ["res://src/run3d/eye/fox_eye.tscn", "res://src/run3d/eye/bear_eye.tscn",
			"res://src/run3d/eye/dolphin_eye.tscn"]:
		assert_true(ResourceLoader.exists(path), "є пресет %s" % path)
		var eye := (load(path) as PackedScene).instantiate() as CartoonEye
		add_child_autofree(eye)
		await wait_process_frames(1)
		assert_not_null(eye.get_node_or_null("EyeBall"), "%s: білок" % path)
		assert_not_null(eye.iris_pivot(), "%s: група погляду" % path)


## Глибина білка — параметр, а не ручна правка вузла: саме її колись крутили в редакторі.
func test_ball_depth_drives_eyeball_depth() -> void:
	_eye.ball_depth = 0.2
	await wait_process_frames(1)
	var ball := _eye.get_node("EyeBall") as MeshInstance3D
	assert_almost_eq(ball.scale.z, _eye.eye_scale.x * 0.2, 0.0001, "білок сплющився за ball_depth")


## Пресети мусять містити САМЕ експорти. Якщо редактор запече в них згенеровані частини
## (EyeBall тощо), правка в Інспекторі буде видима в редакторі й зникне в грі: _rebuild()
## зносить усіх дітей і ліпить їх наново з експортів. Було саме так — хай не повториться.
func test_presets_have_no_baked_child_nodes() -> void:
	for path in ["res://src/run3d/eye/cartoon_eye.tscn", "res://src/run3d/eye/fox_eye.tscn",
			"res://src/run3d/eye/bear_eye.tscn", "res://src/run3d/eye/dolphin_eye.tscn"]:
		var text := FileAccess.get_file_as_string(path)
		assert_false(text.contains("parent="), "%s: жодного запеченого вузла" % path)


## Повіка — опційна: 0 (типово) не додає нічого зайвого, щоб решта тварин не змінилась.
func test_eyelid_absent_by_default() -> void:
	assert_almost_eq(_eye.eyelid_cover, 0.0, 0.0001, "типово повіки нема")
	assert_null(_eye.get_node_or_null("Eyelid"), "нема вузла — нема зайвого шару в кадрі")


## Задали eyelid_cover — з'явився шар Eyelid, ближче до глядача за все інше (LIFT_EYELID),
## і зникає назад, щойно повернули cover до нуля.
func test_eyelid_appears_when_cover_is_set() -> void:
	_eye.eyelid_cover = 0.3
	assert_not_null(_eye.get_node_or_null("Eyelid"), "з'явилась повіка")
	_eye.eyelid_cover = 0.0
	assert_null(_eye.get_node_or_null("Eyelid"), "прибрали cover — повіки знову нема")


## fox_eye — пресет, для якого користувач попросив повіку: перевіряємо саме те, на що
## спирається Hero3D (eyelid_cover > 0 → там тонує колір шерсті героя, див. hero3d.gd).
func test_fox_preset_has_eyelid_enabled() -> void:
	var fox := (load("res://src/run3d/eye/fox_eye.tscn") as PackedScene).instantiate() as CartoonEye
	add_child_autofree(fox)
	await wait_process_frames(1)
	assert_gt(fox.eyelid_cover, 0.0, "лис просив повіку — пресет має її вмикати")
	assert_not_null(fox.get_node_or_null("Eyelid"))


## РЕГРЕСІЯ (перша версія стабілізації гладила АБСОЛЮТНУ позицію білка й це зламало звичайний
## рух героя — біг, зміна смуги: білок відставав від морди на кожному такому русі). Тут
## фільтр бачить лише ОБЕРТ батька, тож чистий ПЕРЕНОС має йти БЕЗ жодної затримки.
func test_ball_follows_pure_translation_without_lag() -> void:
	var shaker := Node3D.new()
	add_child_autofree(shaker)
	var eye := (load(BASE) as PackedScene).instantiate() as CartoonEye
	shaker.add_child(eye)
	eye.call("_process", 1.0 / 60.0)          # стартова точка
	var ball := eye.get_node("EyeBall") as Node3D

	shaker.position = Vector3(2.0, 0.0, 0.0)   # як зміна смуги/стрибок за один кадр
	eye.call("_process", 1.0 / 60.0)
	assert_almost_eq(ball.global_position.x, 2.0, 0.001,
		"чистий перенос батька — білок іде ВІДРАЗУ, без затримки")


## Швидкий кивок (обертання) батька гаситься; IrisPivot тим часом і далі йде за РЕАЛЬНИМ
## нахилом батька («тільки внутрішні елементи рухаються» — так це сформулював користувач).
func test_ball_damps_fast_parent_rotation_iris_pivot_follows_raw() -> void:
	var lever := Vector3(0.15, 0.05, -0.2)
	var stabilized_swing := _rotation_swing(lever, 2.6, 1.5)
	var raw_swing := _rotation_swing(lever, 2.6, 999.0)      # hz величезний — фільтр не встигає

	assert_gt(raw_swing, 0.02, "сам кивок і справді помітно гойдав би непристабілізовану точку")
	assert_lt(stabilized_swing, raw_swing * 0.5,
		"стабілізований розмах (%.4f) суттєво менший за непристабілізований (%.4f)" %
		[stabilized_swing, raw_swing])

	var shaker := Node3D.new()
	add_child_autofree(shaker)
	var eye := (load(BASE) as PackedScene).instantiate() as CartoonEye
	shaker.add_child(eye)
	eye.position = lever
	eye.call("_process", 1.0 / 60.0)
	var pivot_before: Vector3 = eye.iris_pivot().position
	shaker.rotation.x = 0.3
	eye.call("_process", 1.0 / 60.0)
	assert_eq(eye.iris_pivot().position, pivot_before, "IrisPivot стабілізацію ігнорує")


## Допоміжне: заводить око під власну «хитку» (обертання, БЕЗ переносу), жене синусоїдний
## кивок 60 кроків по 1/60с і повертає розмах (max−min) світової Y білка. hz — ball_stabilize_hz.
func _rotation_swing(lever: Vector3, wobble_hz: float, hz: float) -> float:
	var shaker := Node3D.new()
	add_child_autofree(shaker)
	var eye := (load(BASE) as PackedScene).instantiate() as CartoonEye
	shaker.add_child(eye)
	eye.position = lever
	eye.ball_stabilize_hz = hz
	var step := 1.0 / 60.0
	eye.call("_process", step)
	var ball := eye.get_node("EyeBall") as Node3D
	var lo := INF
	var hi := -INF
	for i in 60:
		shaker.rotation.x = sin(i * TAU * wobble_hz * step) * 0.08
		eye.call("_process", step)
		lo = minf(lo, ball.global_position.y)
		hi = maxf(hi, ball.global_position.y)
	return hi - lo
