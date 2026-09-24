## Чому гра засинає — і чому вона НЕ сміє засинати від простою.
##
## Привід. Автопроба `src/ui/sweep_probe.gd` двічі поспіль надрукувала
## «ПРОГІН рівень 14 ПРОПУЩЕНО: гра не в бігу (стан 8)». Стан 8 — «сон». Виглядало як збій
## саме рівня 14, а виявилось арифметикою: проба веде кожен рівень 4 с прогріву + 40 с
## заміру, тобто рівень N починається на 3 + (N-1)×44 с; таймер сесії стартує разом із бігом
## рівня 1, тобто через відлік 0,5 + 3×0,7 = 2,6 с, і добігає нуля на 5,6 + 600 = 605,6 с.
## Вікно рівня 14 — [575; 619] с, і 605,6 лежить рівно в ньому. Звідси той самий рівень у
## двох прогонах поспіль: це батьківський ліміт часу, а не рівень.
##
## Що тут закріплено. Дитина керує нахилом і тапами лише коли треба й між жестами може
## мовчати десятками секунд. Тому лічильник простою `_idle_t` має право тільки на ПІДКАЗКУ,
## і жоден простій не сміє перевести гру в сон. Єдиний шлях у сон — таймер сесії. Обидва
## твердження перевіряються на справжній сцені, а не на заглушці.
extends GutTest

const SweepProbe := preload("res://src/ui/sweep_probe.gd")

## Крок ручної прокрутки. Рівень ведемо самі: 600 секунд гри — це десятки тисяч кадрів,
## і чекати їх у реальному часі не можна.
const STEP := 0.1
## Скільки мовчати. Беремо цілу сесію (10 хв) — щоб тест ловив будь-який задум «заснути
## через N секунд бездіяльності», а не лише зовсім короткий.
const SILENT_SEC := 600.0

var _scene: Node


func before_each() -> void:
	SessionTimer.stop()
	_scene = load("res://src/run3d/run3d.tscn").instantiate()
	add_child(_scene)
	await wait_process_frames(10)


func after_each() -> void:
	SessionTimer.stop()
	get_tree().paused = false
	_scene.free()
	_scene = null


## Довести рівень 1 до стану «біг». Відлік живе на tween, тобто в реальному часі.
func _begin_level_one() -> void:
	_scene._start_level(1)
	var waited := 0.0
	while _scene.state == _scene.State.COUNTDOWN and waited < 6.0:
		await wait_seconds(0.25)
		waited += 0.25


func test_a_whole_session_without_a_single_touch_never_sleeps() -> void:
	await _begin_level_one()
	assert_eq(_scene.state, _scene.State.RUN, "біг почався")
	if _scene.state != _scene.State.RUN:
		return
	# Таймер сесії зупиняємо навмисно: тут питання саме про ПРОСТІЙ, а ліміт часу —
	# в наступному тесті.
	SessionTimer.stop()
	# Рівень 1 триває 80 с і скінчився б задовго до цікавого простою — розтягуємо його.
	_scene.level_duration = SILENT_SEC + 60.0
	_scene.set_process(false)          # далі кермуємо самі
	_scene.hud.set_process(false)      # щоб підказка, раз показавшись, не згасла сама
	var steps := int(SILENT_SEC / STEP)
	for _i in range(steps):
		# Тримаємо героя живим: перешкоди — не тема цього тесту, а без невразливості
		# серця скінчились би й у таблицю полізли б чужі події.
		if _scene.hero != null and _scene.hero.has_method("set_invulnerable"):
			_scene.hero.set_invulnerable(1.0)
		_scene._process(STEP)
		if _scene.state != _scene.State.RUN:
			break
	assert_ne(_scene.state, _scene.State.SLEEP,
		"після %.0f с без жодного дотику гра НЕ спить" % SILENT_SEC)
	assert_eq(_scene.state, _scene.State.RUN,
		"після %.0f с без жодного дотику гра досі біжить" % SILENT_SEC)
	# Дві перевірки проти порожнього тесту: якщо цикл нічого не крутив, «не заснули» нічого
	# не означає.
	assert_gt(_scene.level_distance_m, 100.0, "траса справді їхала")
	assert_true(_scene.hud.hint.visible,
		"простій дійшов до підказки — отже лічильник простою справді працював")


func test_sleep_arrives_exactly_when_the_session_timer_runs_out() -> void:
	await _begin_level_one()
	assert_eq(_scene.state, _scene.State.RUN, "біг почався")
	if _scene.state != _scene.State.RUN:
		return
	# 0,2 хв = 12 с — той самий шлях, що й батьківські 10 хв, лише коротший.
	SessionTimer.start(0.2)
	SessionTimer.tick(11.0)
	assert_eq(_scene.state, _scene.State.RUN, "поки час сесії не вийшов — гра біжить")
	SessionTimer.tick(2.0)
	assert_eq(_scene.state, _scene.State.SLEEP, "час сесії вийшов — сон")
	assert_true(bool(_scene.sleeping), "сцена вважає себе сплячою")
	assert_true(get_tree().paused, "у сні дерево на паузі")


## Арифметика, через яку проба спотикається саме на рівні 14. Числа беремо з самої проби й
## із налаштувань, а не з голови: якщо котресь із них зміниться, тут буде видно, що
## «пропущений» рівень поїхав, і ніхто вдруге не шукатиме привида в рівні 14.
func test_the_sweep_probe_outlasts_one_session() -> void:
	var per_level: float = SweepProbe.WARM_SEC + SweepProbe.SEC_PER_LEVEL   # 4 + 40
	var levels := 17
	var session: float = float(SaveService.setting("session_minutes", 10)) * 60.0
	var probe_total: float = 3.0 + per_level * float(levels)    # 3 с очікування у _ready
	assert_gt(probe_total, session,
		"проба (%.0f с) довша за сесію (%.0f с) — сон посеред прогону неминучий"
			% [probe_total, session])
	# Таймер стартує на першому бігу: 3 с очікування + відлік 0,5 + 3×0,7.
	var timer_zero: float = 3.0 + 2.6 + session
	var level_at_zero := int((timer_zero - 3.0) / per_level) + 1
	assert_eq(level_at_zero, 14,
		"сесія добігає нуля на %.1f с — це рівень %d" % [timer_zero, level_at_zero])
