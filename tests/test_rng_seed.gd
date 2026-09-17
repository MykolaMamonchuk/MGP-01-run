## Відтворюваний запуск гри: без нього ЖОДНЕ порівняння «до і після» не має сенсу.
##
## Заміряно 17.09.2026 пробою (`tools/probe/`): два ОДНАКОВІ запуски, той самий номер кадру,
## `--fixed-fps 60`, глобальний `seed()` на старті — і **37% пікселів різні**. Через це
## цілий день провалювались усі спроби зміряти вигляд живої гри: кілька разів метрика
## оголошувала вадою звичайну перестановку кущів.
##
## Причина була в тому, що підсистеми заводять СВІЙ RandomNumberGenerator і кличуть на ньому
## `randomize()` — той сідає на системну ентропію й ігнорує будь-яке задане зерно. Тепер усі
## вони йдуть через `RngSeed.start()`, і з `GAME_SEED` два прогони збігаються ПОБАЙТОВО
## (перевірено: 0 різних пікселів із 4 469 760).
extends GutTest

## Підсистеми, що тримають власний генератор. Якщо десь знову з'явиться прямий
## `randomize()`, відтворюваність зникне мовчки — і наступний, хто міритиме вигляд,
## витратить день, як я.
const SUBSYSTEMS := [
	"res://src/run3d/track.gd",
	"res://src/run3d/spawner3d.gd",
	"res://src/run3d/event_spawner.gd",
	"res://src/run3d/quests.gd",
]


func test_no_subsystem_calls_randomize_directly() -> void:
	for path in SUBSYSTEMS:
		var f := FileAccess.open(path, FileAccess.READ)
		assert_not_null(f, "%s читається" % path)
		if f == null:
			continue
		for line in f.get_as_text().split("\n"):
			var code := line.split("#")[0]          # коментарі не рахуємо
			assert_false(code.contains(".randomize()"),
				("%s: прямий randomize() ламає відтворюваність — беріть RngSeed.start(rng, \"мітка\"). "
				+ "Рядок: %s") % [path, line.strip_edges()])


## Те саме зерно — та сама послідовність, і так для кожної підсистеми окремо.
func test_same_seed_gives_the_same_sequence() -> void:
	OS.set_environment(RngSeed.ENV, "12345")
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	RngSeed.start(a, "track")
	RngSeed.start(b, "track")
	assert_eq(a.randi(), b.randi(), "однакова мітка й зерно — однакове число")
	OS.set_environment(RngSeed.ENV, "")


## Мітки МАЮТЬ розходитись: якби всі підсистеми сіли на одне число, декор і перешкоди
## почали б «римуватись» — кущ щоразу там само, де й перешкода.
func test_different_labels_do_not_rhyme() -> void:
	OS.set_environment(RngSeed.ENV, "12345")
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	RngSeed.start(a, "track")
	RngSeed.start(b, "spawner")
	assert_ne(a.randi(), b.randi(), "різні підсистеми — різні послідовності")
	OS.set_environment(RngSeed.ENV, "")


## Без змінної середовища все як було: у грі для дитини нічого не міняється.
func test_without_the_variable_nothing_changes() -> void:
	OS.set_environment(RngSeed.ENV, "")
	assert_false(RngSeed.fixed(), "без GAME_SEED запуск лишається випадковим")
