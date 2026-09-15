## Жива камера під час бігу: крен у поворот, запізнення супроводу, ривок поля зору.
## Перевіряємо ЧИСЛОМ, бо «камера стала жвавішою» на око не перевіряється, а зламати це
## легко — досить переплутати знак, і кадр кластиме в протилежний бік від повороту.
extends GutTest


## Знак крену — найважливіше. Камера мусить лягати В бік маневру, як велосипедист у поворот.
## Герой їде праворуч, коли ціль правіше за нього, тобто pull додатний.
func test_lean_follows_the_turn() -> void:
	var right := CameraRig.lean_for(1.0, 1.0)      # ще метр праворуч
	var left := CameraRig.lean_for(-1.0, 1.0)
	assert_lt(right, 0.0, "поворот праворуч кладе кадр в один бік")
	assert_gt(left, 0.0, "ліворуч — у протилежний")
	assert_almost_eq(absf(right), absf(left), 0.0001, "обидва боки однакові")


## Пропорція, а не поріг: дрібний доворот не має смикати кадр на повний крен.
func test_small_turn_gives_small_lean() -> void:
	var full := absf(CameraRig.lean_for(1.0, 1.0))
	var tiny := absf(CameraRig.lean_for(0.1, 1.0))
	assert_almost_eq(tiny, full * 0.1, 0.0001, "крен пропорційний недоїханому зсуву")


## Крен обмежений навіть на величезному зсуві: інакше на широкій трасі кадр перекинувся б.
func test_lean_is_capped() -> void:
	assert_almost_eq(absf(CameraRig.lean_for(9.0, 1.0)), CameraRig.LEAN_ROLL, 0.0001,
		"крен упирається в стелю")


## Запізнення: камера стоїть ПОЗАДУ героя по ходу маневру, бо саме через це його видно
## зміщеним у кадрі. Якби вона йшла точно за ним, маневр читався б лише по декору.
func test_camera_trails_the_hero_during_a_turn() -> void:
	var hero_x := 0.0
	var pull := 1.0                                 # герой щойно почав рух праворуч
	var cam_x := CameraRig.follow_for(hero_x, pull)
	assert_gt(cam_x, hero_x, "камера тягнеться за ціллю, не стрибає на героя")
	assert_lt(cam_x, hero_x + pull, "але й не випереджає його")


func test_no_turn_means_no_offset() -> void:
	assert_almost_eq(CameraRig.follow_for(2.0, 0.0), 2.0, 0.0001, "маневр скінчився — камера на місці")
	assert_almost_eq(CameraRig.lean_for(0.0, 1.0), 0.0, 0.0001, "і крену нема")


## Чисті функції можуть бути правильні, а камера все одно стояти: досить забути записати
## результат у вузол. Тут перевіряємо саме ПРОВОДКУ — що drive() рухає риг.
func _rig() -> CameraRig:
	var rig := CameraRig.new()
	var c := Camera3D.new()
	c.name = "Camera3D"                 # @onready cam шукає його саме за іменем
	rig.add_child(c)
	add_child_autofree(rig)
	return rig


func test_drive_actually_moves_the_rig() -> void:
	var rig := _rig()
	await wait_process_frames(1)
	assert_almost_eq(rig.rotation.z, 0.0, 0.0001, "у спокої крену нема")
	# тримаємо маневр праворуч кілька кадрів — рух згладжений, за один кадр не доїде
	for i in 30:
		rig.drive(0.016, 0.0, 1.0, 0.0, 1.0)
	assert_lt(rig.rotation.z, -0.05, "кадр ліг у поворот")
	assert_gt(rig.position.x, 0.05, "і поїхав за героєм")
	assert_ne(rig.rotation.y, 0.0, "ніс довернувся")


func test_drive_returns_to_rest_when_the_turn_ends() -> void:
	var rig := _rig()
	await wait_process_frames(1)
	for i in 30:
		rig.drive(0.016, 0.0, 1.0, 0.0, 1.0)
	for i in 90:
		rig.drive(0.016, 0.0, 0.0, 0.0, 1.0)     # маневр скінчився
	assert_almost_eq(rig.rotation.z, 0.0, 0.01, "крен розійшовся")
	assert_almost_eq(rig.position.x, 0.0, 0.01, "камера повернулась")


## Під стрибком камера провисає — саме це дає відчуття підйому, а не просто зсув спрайта.
func test_jump_makes_the_camera_sag() -> void:
	var rig := _rig()
	await wait_process_frames(1)
	for i in 20:
		rig.drive(0.016, 0.0, 0.0, 4.0, 1.0)     # герой іде вгору
	assert_lt(rig.position.y, -0.01, "камера відстала по висоті")
