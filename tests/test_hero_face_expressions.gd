## Кліпання й «щасливе обличчя» (_blink/_happy у Hero3D) — уже існували до всіх цих компонентів;
## тут перевіряємо, що вони й далі керують очима, хоч би яка реалізація зараз стояла на героєві.
## У проєкті їх три: наш CartoonEye (src/run3d/eye/), вендорний ShaderEye (vendor/cartoon_eye/)
## і вендорний CartoonEye3D (vendor/cartoon_eye_3d/). Лис зараз на пробі сидить на третьому
## (через пресет src/run3d/eye/fox_eye_3d.tscn у rig_face.eye_scene).
##
## Окремо перевіряємо саму ДИСПЕТЧЕРИЗАЦІЮ (_eye_set_lid/_eye_gaze/_eye_set_surprised) на ВСІХ
## трьох типах напряму — щоб тести залежали не від того, кого зараз увімкнено в heroes.json,
## а від того, що Hero3D вміє керувати кожним.
extends GutTest

const SHADER_EYE := "res://vendor/cartoon_eye/ShaderEye.tscn"
const EYE_3D := "res://vendor/cartoon_eye_3d/CartoonEye3D.tscn"

var _hero: Hero3D


func before_each() -> void:
	_hero = Hero3D.new()
	add_child_autofree(_hero)
	var def := Hero3D.resolve_def(Hero3D.defs(), "lys")
	_hero.set_hero("lys", Palette.of(def.get("color"), Palette.HERO_DEFAULT), String(def.get("feature", "fox")))
	await wait_process_frames(1)


func test_fox_has_two_eyes() -> void:
	assert_eq(_hero._eyes.size(), 2, "два ока")
	for e in _hero._eyes:
		assert_true(e is CartoonEye or e is ShaderEye or e is CartoonEye3D,
			"кожне око — одна з трьох реалізацій")


## Зараз (на пробу) rig_face.eye_scene лиса вказує на src/run3d/eye/fox_eye_3d.tscn — пресет
## поверх вендорного CartoonEye3D. Повернемо колись назад — цей тест і скаже, що очікування
## застаріло (а не мовчки проб'ється крізь решту перевірок).
func test_fox_is_currently_on_trial_cartoon_eye_3d() -> void:
	for e in _hero._eyes:
		assert_true(e is CartoonEye3D, "лис зараз на пробі CartoonEye3D (heroes.json rig_face.eye_scene)")


## _blink() твінить властивість кожного ока (scale:y у CartoonEye, blink_amount у вендорних —
## напрямки протилежні) за 0,06+0,08 с — надто швидко для чекання реального часу в
## headless-запуску, тож крокуємо твін вручну (Tween.custom_step, детерміновано). Це той самий
## тест, який колись спіймав баг `.parallel()` на кожному оці (крок нульової тривалості).
func test_blink_closes_and_reopens_eyes() -> void:
	# явні вид і швидкість: типово _blink() обирає їх ВИПАДКОВО (обома / по черзі /
	# підморгнути, плюс розкид швидкості) — тест має бути детермінований
	_hero._blink(Hero3D.BlinkKind.BOTH, 1.0)
	_hero._blink_tween.custom_step(0.059)          # майже все заплющення, розплющення ще не почалось
	for e in _hero._eyes:
		assert_almost_eq((e as CartoonEye3D).blink_amount, 1.0, 0.05, "під час кліпання майже заплющене")
	_hero._blink_tween.custom_step(0.09)           # добиває заплющення й усе розплющення
	for e in _hero._eyes:
		assert_almost_eq((e as CartoonEye3D).blink_amount, 0.0, 0.01, "після кліпання розплющене як було")


## _happy() одразу примружує очі (без твіна) і ширить усмішку, а за seconds — повертає все.
func test_happy_squints_eyes_and_smiles_then_reverts() -> void:
	_hero._happy(0.2)
	for e in _hero._eyes:
		assert_almost_eq((e as CartoonEye3D).blink_amount, 1.0 - Hero3D.HAPPY_EYE_SQUASH, 0.001,
			"щасливий — очі сплюснуті по вертикалі, але не заплющені")
	# усмішка йде твіном усередині 3D-рота — крокуємо його вручну, як і твіни кліпання
	_hero._mouth3d._active_tween.custom_step(0.2)
	assert_gt(_hero._mouth3d.smile_amount, 0.0, "щасливий — рот усміхнувся")
	await wait_seconds(0.35)
	for e in _hero._eyes:
		assert_almost_eq((e as CartoonEye3D).blink_amount, 0.0, 0.01, "щасливий вираз минув — очі як були")


# ---------- диспетчеризація напряму на ВСІХ трьох типах ока ----------

func test_eye_set_lid_dispatches_to_every_eye_type() -> void:
	var ce := (load(CartoonEye.BASE_SCENE) as PackedScene).instantiate() as CartoonEye
	var se := (load(SHADER_EYE) as PackedScene).instantiate() as ShaderEye
	var e3 := (load(EYE_3D) as PackedScene).instantiate() as CartoonEye3D
	for n in [ce, se, e3]:
		add_child_autofree(n)
	await wait_process_frames(1)

	_hero.call("_eye_set_lid", ce, 0.12)
	assert_almost_eq(ce.scale.y, 0.12, 0.001, "CartoonEye: значення йде напряму в scale.y")

	# _eye_scale_y лиса зараз 1.0 (не sleepy) -> blink_amount = 1 - 0.12/1.0 = 0.88
	_hero.call("_eye_set_lid", se, 0.12)
	assert_almost_eq(se.blink_amount, 0.88, 0.001, "ShaderEye: те саме число в blink_amount, обернено")

	_hero.call("_eye_set_lid", e3, 0.12)
	assert_almost_eq(e3.blink_amount, 0.88, 0.001, "CartoonEye3D: так само обернено")


func test_eye_gaze_dispatches_to_every_eye_type() -> void:
	var ce := (load(CartoonEye.BASE_SCENE) as PackedScene).instantiate() as CartoonEye
	var se := (load(SHADER_EYE) as PackedScene).instantiate() as ShaderEye
	var e3 := (load(EYE_3D) as PackedScene).instantiate() as CartoonEye3D
	for n in [ce, se, e3]:
		add_child_autofree(n)
	await wait_process_frames(1)

	_hero.call("_eye_gaze", ce, Vector2(1.0, 0.0))
	assert_ne(ce.iris_pivot().position.x, 0.0, "CartoonEye: IrisPivot поїхав убік")

	_hero.call("_eye_gaze", se, Vector2(0.5, -0.3))
	assert_almost_eq(se.gaze_x, 0.5, 0.001, "ShaderEye: gaze_x")
	assert_almost_eq(se.gaze_y, -0.3, 0.001, "ShaderEye: gaze_y")

	_hero.call("_eye_gaze", e3, Vector2(0.5, -0.3))
	assert_almost_eq(e3.gaze_x, 0.5, 0.001, "CartoonEye3D: gaze_x")
	assert_ne(e3.iris_pivot.position.x, 0.0, "CartoonEye3D: IrisPivot і справді поїхав")


func test_eye_set_surprised_dispatches_to_every_eye_type() -> void:
	var ce := (load(CartoonEye.BASE_SCENE) as PackedScene).instantiate() as CartoonEye
	var se := (load(SHADER_EYE) as PackedScene).instantiate() as ShaderEye
	var e3 := (load(EYE_3D) as PackedScene).instantiate() as CartoonEye3D
	for n in [ce, se, e3]:
		add_child_autofree(n)
	await wait_process_frames(1)
	var se_base := se.eye_height
	var e3_base := e3.eye_height

	_hero.call("_eye_set_surprised", ce, true)
	assert_almost_eq(ce.scale.x, Hero3D.HIT_EYE_SCALE, 0.001, "CartoonEye: масштаб ×HIT_EYE_SCALE")

	_hero.call("_eye_set_surprised", se, true)
	assert_gt(se.eye_height, se_base, "ShaderEye: здивоване — око вище")
	_hero.call("_eye_set_surprised", se, false)
	assert_almost_eq(se.eye_height, se_base, 0.001, "ShaderEye: нейтральне повертає як було")

	_hero.call("_eye_set_surprised", e3, true)
	assert_gt(e3.eye_height, e3_base, "CartoonEye3D: здивоване — око вище")
	_hero.call("_eye_set_surprised", e3, false)
	assert_almost_eq(e3.eye_height, e3_base, 0.001, "CartoonEye3D: нейтральне повертає як було")


## У вендорному коді set_surprised() був НАКОПИЧУВАЛЬНИМ (eye_height *= 1.08 щоразу) і не мав
## пари — після кількох ударів око лишалось роздутим назавжди. Ми це виправили; хай не вернеться.
func test_cartoon_eye_3d_surprise_does_not_accumulate() -> void:
	var e3 := (load(EYE_3D) as PackedScene).instantiate() as CartoonEye3D
	add_child_autofree(e3)
	await wait_process_frames(1)
	var base := e3.eye_height
	for i in 4:
		_hero.call("_eye_set_surprised", e3, true)
		_hero.call("_eye_set_surprised", e3, false)
	assert_almost_eq(e3.eye_height, base, 0.001, "після кількох ударів око те саме, не роздуте")


# ---------- рот ----------

## Лис зараз (на пробу) має 3D-рот (rig_face.mouth_scene). Стара коробочка _mouth при цьому
## не малюється взагалі — інакше вони б наклались одна на одну.
func test_fox_uses_3d_mouth_instead_of_the_old_box() -> void:
	assert_not_null(_hero._mouth3d, "рот — вендорний CartoonMouth3DIntegrated")
	assert_null(_hero._mouth, "стара коробочка-рот не малюється")


## _smile() і реакція на удар мусять іти через 3D-рот, коли він є (а не мовчки нічого не
## робити, як було б, якби залишились тільки старі гілки з _mouth).
## Виклики всередині компонента — твіни, тож крокуємо їх вручну (Tween.custom_step),
## детерміновано й без залежності від того, скільки триває кадр у headless-запуску.
func test_smile_and_hit_drive_the_3d_mouth() -> void:
	var m := _hero._mouth3d
	m.smile_amount = 0.0
	_hero._smile(0.2)
	m._active_tween.custom_step(0.2)
	assert_gt(m.smile_amount, 0.0, "усмішка підняла smile_amount")

	m.open_amount = 0.0
	_hero.hit_reaction(0)
	m._active_tween.custom_step(0.2)
	assert_gt(m.open_amount, 0.0, "удар відкрив рот («О»)")


## РЕГРЕСІЯ: кліпання у вендорному компоненті було реалізоване ЛИШЕ рухом повік. Щойно
## повіки сховали (у пресеті лиса вони visible = false — окремими плямами над оком вони
## виглядали чужорідно), blink_amount переставав робити будь-що видиме: око не блимало.
## Тепер без повік воно стискається по вертикалі — і це має працювати в обох випадках.
func test_blink_squashes_the_eye_when_lids_are_hidden() -> void:
	var e3 := (load(EYE_3D) as PackedScene).instantiate() as CartoonEye3D
	add_child_autofree(e3)
	await wait_process_frames(1)
	var ball := e3.get_node("Eyeball") as Node3D
	(e3.get_node("UpperLid") as Node3D).visible = false
	(e3.get_node("LowerLid") as Node3D).visible = false

	e3.blink_amount = 0.0
	var open_y := ball.scale.y
	e3.blink_amount = 1.0
	assert_lt(ball.scale.y, open_y * 0.2, "заплющене — око стиснуте майже в лінію")
	e3.blink_amount = 0.0
	assert_almost_eq(ball.scale.y, open_y, 0.001, "розплющилось назад")


## А з ВИДИМИМИ повіками працює стара механіка (рух повік), і саме око не стискається.
func test_blink_moves_lids_when_they_are_visible() -> void:
	var e3 := (load(EYE_3D) as PackedScene).instantiate() as CartoonEye3D
	add_child_autofree(e3)
	await wait_process_frames(1)
	var ball := e3.get_node("Eyeball") as Node3D
	var upper := e3.get_node("UpperLid") as Node3D
	upper.visible = true
	(e3.get_node("LowerLid") as Node3D).visible = true

	e3.blink_amount = 0.0
	var open_y := ball.scale.y
	var lid_rest := upper.position.y
	e3.blink_amount = 1.0
	assert_lt(upper.position.y, lid_rest, "повіка поїхала до центру")
	assert_almost_eq(ball.scale.y, open_y, 0.001, "саме око при цьому не стискається")


## РЕГРЕСІЯ: розмір бліків в оці був АБСОЛЮТНИЙ, а райдужка — відносна (×eye_width). Щойно
## Hero3D стискав око під конкретного героя (rig_face.eye_size), райдужка меншала, а блік
## лишався той самий — і пропорція з референсною текстурою ламалась саме в грі, хоч в
## ізольованій сцені все сходилось (наміряли 0.028 в ізоляції проти 0.147 на морді).
## Тепер блік/райдужка не залежить від того, як героєві змасштабували око.
func test_eye_highlight_keeps_its_proportion_when_the_eye_is_rescaled() -> void:
	var e3 := (load(EYE_3D) as PackedScene).instantiate() as CartoonEye3D
	add_child_autofree(e3)
	await wait_process_frames(1)
	var iris := e3.get_node("IrisPivot/Iris") as Node3D
	var hi := e3.get_node("IrisPivot/HighlightBig") as Node3D
	var before := hi.scale.x / iris.scale.x

	e3.eye_width = 0.6
	e3.eye_height = 0.55
	assert_almost_eq(hi.scale.x / iris.scale.x, before, 0.001,
		"блік лишається тією ж часткою райдужки й після стискання ока")


## РЕГРЕСІЯ: neutral() у вендорному роті зводив усмішку жорстко в нуль. Після кожної
## _smile()/_happy() лис лишався з рівною щілинкою замість своєї звичайної усміхненої міни.
func test_mouth_returns_to_its_resting_smile_not_to_a_flat_line() -> void:
	var m := _hero._mouth3d
	assert_gt(m.rest_smile, 0.0, "у лиса спокійна міна — усміхнена (пресет fox_mouth_3d)")
	m.smile()
	m._active_tween.custom_step(0.2)
	m.neutral()
	m._active_tween.custom_step(0.2)
	assert_almost_eq(m.smile_amount, m.rest_smile, 0.001,
		"після neutral() рот повертається до своєї звичайної усмішки, а не в нуль")


## РЕГРЕСІЯ: сокет рота фарбувався кольором ХУТРА, а рот сидить на світлому писку —
## навколо рота прорізались жовтогарячі сходинки. Беремо колір тієї плями, на якій рот.
func test_mouth_socket_takes_the_muzzle_color_not_the_fur() -> void:
	assert_gt(_hero._belly_c.a, 0.0, "у лиса є кремовий писок (belly_color)")
	assert_eq(_hero._mouth3d.socket_color, _hero._belly_c,
		"сокет рота — кольором писка, а не хутра")


# ---------- дзеркальні очі: зіниці й блики дивляться ВСЕРЕДИНУ ----------

## Пресет описує ОДНЕ око; друге Hero3D просить віддзеркалити. Без цього обидва ока вели
## блик в один бік — морда виходила косоока (видно було на лисі поруч із оленям).
func test_hero_mirrors_exactly_one_of_the_two_eyes() -> void:
	var mirrored := 0
	for e in _hero._eyes:
		if (e as CartoonEye3D).mirrored:
			mirrored += 1
	assert_eq(mirrored, 1, "рівно одне з двох очей дзеркальне")


## Дивлячись ПРЯМО, дзеркальне око веде райдужку в протилежний бік від звичайного —
## тобто обидва дивляться до носа.
func test_mirrored_eye_looks_the_other_way_when_facing_forward() -> void:
	var plain := (load(EYE_3D) as PackedScene).instantiate() as CartoonEye3D
	var mirror := (load(EYE_3D) as PackedScene).instantiate() as CartoonEye3D
	for n in [plain, mirror]:
		add_child_autofree(n)
		(n as CartoonEye3D).iris_offset = Vector2(0.2, 0.0)
		(n as CartoonEye3D).gaze_x = 0.0
	mirror.mirrored = true
	await wait_process_frames(1)

	assert_almost_eq(mirror.iris_pivot.position.x, -plain.iris_pivot.position.x, 0.0001,
		"прямо: дзеркальне око веде райдужку в інший бік")
	assert_ne(plain.iris_pivot.position.x, 0.0, "зсув узагалі є (інакше тест нічого не доводить)")


## А щойно герой повів очима ВБІК — дзеркальність тане: обидва ока мають вести зіниці в
## ОДИН бік, інакше одне дивилось би вліво, а друге вправо.
func test_mirroring_fades_away_when_the_eyes_look_aside() -> void:
	var plain := (load(EYE_3D) as PackedScene).instantiate() as CartoonEye3D
	var mirror := (load(EYE_3D) as PackedScene).instantiate() as CartoonEye3D
	for n in [plain, mirror]:
		add_child_autofree(n)
		(n as CartoonEye3D).iris_offset = Vector2(0.2, 0.0)
	mirror.mirrored = true
	await wait_process_frames(1)
	for n in [plain, mirror]:
		(n as CartoonEye3D).gaze_x = 1.0

	assert_almost_eq(mirror.iris_pivot.position.x, plain.iris_pivot.position.x, 0.0001,
		"погляд убік: обидва ока ведуть райдужку однаково")


# ---------- кліпання: не однакове щоразу ----------

## Підморгування — заплющується РІВНО одне око, друге лишається розплющеним.
func test_wink_closes_only_one_eye() -> void:
	_hero._blink(Hero3D.BlinkKind.WINK, 1.0)
	_hero._blink_tween.custom_step(Hero3D.BLINK_CLOSE_SEC)
	var closed := 0
	for e in _hero._eyes:
		if (e as CartoonEye3D).blink_amount > 0.9:
			closed += 1
	assert_eq(closed, 1, "підморгування: одне око заплющене, друге ні")


## Кліпання «по черзі»: друге око починає пізніше на BLINK_SEQUENCE_GAP, а не разом.
func test_sequence_blink_staggers_the_second_eye() -> void:
	_hero._blink(Hero3D.BlinkKind.SEQUENCE, 1.0)
	_hero._blink_tween.custom_step(Hero3D.BLINK_CLOSE_SEC)
	assert_gt((_hero._eyes[0] as CartoonEye3D).blink_amount, 0.9, "перше око вже заплющилось")
	assert_lt((_hero._eyes[1] as CartoonEye3D).blink_amount, 0.05, "друге ще навіть не почало")
	# ще трохи — і друге вже в процесі заплющення (але не до кінця прогону, бо тоді воно
	# встигло б і розплющитись назад)
	_hero._blink_tween.custom_step(Hero3D.BLINK_SEQUENCE_GAP * 0.6)
	assert_gt((_hero._eyes[1] as CartoonEye3D).blink_amount, 0.1, "а тоді й друге пішло")


## Швидкість кліпання розкидана: той самий вид кліпання з різними speed триває по-різному.
## Міряємо на кроці, коротшому за ШВИДКЕ заплющення, — інакше швидке встигне ще й
## розплющитись назад, і порівнювати буде нічого.
func test_blink_speed_changes_how_long_it_takes() -> void:
	var step := Hero3D.BLINK_CLOSE_SEC * 0.3
	var eye := _hero._eyes[0] as CartoonEye3D

	eye.blink_amount = 0.0
	_hero._blink(Hero3D.BlinkKind.BOTH, 0.5)
	_hero._blink_tween.custom_step(step)
	var fast := eye.blink_amount

	eye.blink_amount = 0.0
	_hero._blink(Hero3D.BlinkKind.BOTH, 2.0)
	_hero._blink_tween.custom_step(step)
	var slow := eye.blink_amount

	assert_gt(fast, slow, "швидке кліпання за той самий час заплющується дужче за повільне")


## Очі не завмирають, коли герой просто біжить прямо: погляд тихо дрейфує сам. Без цього
## зіниці й блики стоять як намальовані — і рух видно лише при зміні доріжки, тобто майже
## ніколи («щось не бачу, що вони рухаються»).
func test_gaze_drifts_by_itself_while_running_straight() -> void:
	_hero.x_target = _hero.position.x          # нікуди не повертає — саме той випадок
	await wait_process_frames(2)
	var a: float = (_hero._eyes[0] as CartoonEye3D).gaze_x
	await wait_seconds(1.2)
	var b: float = (_hero._eyes[0] as CartoonEye3D).gaze_x

	assert_gt(absf(b - a), 0.01, "погляд сам ледь блукає, а не стоїть на місці")
	assert_lt(absf(b), Hero3D.GAZE_DRIFT * 1.5, "але блукає ЛЕДЬ — не косить очима")
