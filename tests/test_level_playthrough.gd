## Наскрізний прогін рівня: чи гра взагалі доходить від старту до фінішу.
##
## У проєкті понад чотири сотні тестів, і жоден із них не проходив рівень цілком. Усі вони
## перевіряють шматки — правила, економіку, розкладку траси, — але ніхто ні разу не зміряв
## головного: що рівень починається, доходить до кінця й нараховує нагороду. Саме таке
## завмирання посеред рівня коштувало б демо найдорожче, а жоден тест його не побачив би.
##
## Рівень ведемо ВРУЧНУ: 80 секунд гри — це 4800 кадрів, і чекати їх у реальному часі не
## можна. Тому власний _process() сцени вимикаємо й кличемо його самі великими кроками.
## Відлік перед стартом при цьому лишаємо справжнім — він живе на tween, тобто в реальному
## часі, і саме там гра могла б зависнути ще до першого кроку.
extends GutTest

## Скільки викликів _process() дозволяємо, перш ніж вважати, що гра зависла. Рівень 1 —
## 80 секунд, крок 0,05 с, тобто 1600 викликів; беремо втричі з запасом.
const MAX_STEPS := 5000
const STEP := 0.05

var _scene: Node


func before_each() -> void:
	_scene = load("res://src/run3d/run3d.tscn").instantiate()
	add_child(_scene)
	await wait_process_frames(10)


func after_each() -> void:
	get_tree().paused = false
	_scene.free()
	_scene = null


## Прокрутити рівень до фінішу (або до стелі кроків). Повертає, скільки кроків знадобилось.
func _run_to_finish() -> int:
	_scene.set_process(false)   # далі кермуємо самі, щоб не чекати 80 секунд реального часу
	var steps := 0
	while _scene.state != _scene.State.FINISH and steps < MAX_STEPS:
		_scene._process(STEP)
		steps += 1
	return steps


## Меню не сміє лишатись поверх гри, хай яким шляхом рівень почався. Раніше hide_menu()
## кликав лише _on_play(), і демо-вхід (LEVEL=n), перехід на наступний рівень після фінішу
## та налагоджувальна клавіша L лишали напис «Біжимо!/Герої/Мапа» посеред екрана. Під час
## першого огляду рівнів 2–17 це закривало центр кожного знімка.
func test_starting_a_level_always_hides_the_menu() -> void:
	var menu = _scene.get_node("Menu")
	assert_not_null(menu, "меню у сцені")
	if menu == null:
		return
	menu.visible = true
	_scene._start_level(1)
	await wait_seconds(0.6)   # hide_menu ховає вузол наприкінці короткої анімації
	assert_false(menu.visible, "після старту рівня меню сховане")


func test_level_one_starts_counts_down_and_reaches_the_finish() -> void:
	_scene._start_level(1)
	assert_eq(_scene.state, _scene.State.COUNTDOWN, "рівень починається з відліку")
	# відлік живе на tween — це справжній час, інакше не перевіриш, що він узагалі спрацює
	var waited := 0.0
	while _scene.state == _scene.State.COUNTDOWN and waited < 6.0:
		await wait_seconds(0.25)
		waited += 0.25
	assert_eq(_scene.state, _scene.State.RUN, "відлік закінчився і біг почався (чекали %.1f с)" % waited)

	var steps := _run_to_finish()
	assert_lt(steps, MAX_STEPS, "рівень дійшов до фінішу, а не завис")
	assert_eq(_scene.state, _scene.State.FINISH, "стан — фініш")
	assert_gt(_scene.level_distance_m, 100.0, "траса справді проїхала, а не стояла на місці")


## Нагорода за пройдений рівень мусить дійти до збереження. Без цього рівень «проходиться»,
## а дитина не дістає нічого — і цього не видно інакше, як пройшовши рівень до кінця.
func test_finishing_a_level_awards_stars_and_marks_it_done() -> void:
	var before: int = int(SaveService.child().get("stars", 0))
	_scene._start_level(1)
	var waited := 0.0
	while _scene.state == _scene.State.COUNTDOWN and waited < 6.0:
		await wait_seconds(0.25)
		waited += 0.25
	var steps := _run_to_finish()
	assert_lt(steps, MAX_STEPS, "рівень дійшов до фінішу")
	if steps >= MAX_STEPS:
		return
	assert_gt(int(SaveService.child().get("stars", 0)), before, "зірочок побільшало")
	var done = SaveService.child().get("level_stars", {})
	assert_true(typeof(done) == TYPE_DICTIONARY and (done as Dictionary).has("1"),
		"рівень 1 записався як пройдений із зірками: %s" % [done])
	assert_gte(int(SaveService.child().get("level", 1)), 2, "наступний рівень відкрився")
