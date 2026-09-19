## Складність рівня числом (`Difficulty`) на СПРАВЖНІХ даних із `data/levels.json`.
##
## Головне, що тут зафіксовано: зростання по всьому списку рівнів НЕ монотонне, і це властивість
## самих даних, а не формули. Провали рівно три — 4→5, 8→9, 14→15, — і всі троє в тому самому
## місці: на першому рівні НОВОГО світу. Такий рівень навмисно легший за фінал попереднього
## світу (вужча дорога, один-два типи перешкод, `tutorial: true`) — це перепочинок і знайомство
## з біомом. Швидкість і щільність при цьому ростуть без жодного провалу, тест нижче це показує.
## Тому формулу під монотонність не підганяли, а описали провали й тримаємо їх у межах.
extends GutTest

## Де складність падає при переході до наступного рівня: [з, у].
## Наскільки глибоко їй дозволено провалюватись на такому перепочинку (найглибший — 4→5, 0.087).
const DIP_MAX := 0.10

var _levels: Array = []


func before_each() -> void:
	_levels = LevelManager.load_levels()
	_levels.sort_custom(func(a, b): return int(a["id"]) < int(b["id"]))


func _level(num: int) -> Dictionary:
	for l in _levels:
		if int(l.get("id", 0)) == num:
			return l
	return {}


func test_all_seventeen_levels_stay_between_zero_and_one() -> void:
	assert_eq(_levels.size(), 17, "рівнів усе ще 17")
	for l in _levels:
		var d := Difficulty.of(l)
		assert_between(d, 0.0, 1.0, "рівень %d: складність у межах 0..1" % int(l["id"]))


func test_tutorial_is_the_easiest_and_the_last_level_is_the_hardest() -> void:
	var first := Difficulty.of(_level(1))
	var last := Difficulty.of(_level(17))
	assert_almost_eq(first, 0.0, 0.05, "рівень 1 — близько нуля")
	assert_almost_eq(last, 1.0, 0.001, "рівень 17 — близько одиниці")
	for l in _levels:
		var d := Difficulty.of(l)
		if int(l["id"]) != 1:
			assert_gt(d, first, "рівень %d важчий за туторіал" % int(l["id"]))
		if int(l["id"]) != 17:
			assert_lt(d, last, "рівень %d легший за фінал" % int(l["id"]))


## ПРАВИЛО, а не знімок. Перша версія цього тесту вимагала, щоб список провалів дорівнював
## рівно [[4,5],[8,9],[14,15]] — і тоді будь-яке законне доналаштування щільності на якомусь
## рівні робило його червоним, хоч задум ніхто не порушив. Тепер перевіряється саме правило:
## провал дозволено ЛИШЕ там, де починається новий світ, і лише неглибокий. Список відомих
## провалів лишається в коментарі як факт на день заміру, а не як вимога.
##
## Станом на 18.09.2026 провалів три: 4→5 (−0,087), 8→9 (−0,027), 14→15 (−0,058). Четвертий
## відкривач світу (11→12, Місто) провалу не дає: +0,007.
func test_every_dip_only_happens_where_a_new_world_opens() -> void:
	var dips := []
	for i in range(_levels.size() - 1):
		var a: Dictionary = _levels[i]
		var b: Dictionary = _levels[i + 1]
		var da := Difficulty.of(a)
		var db := Difficulty.of(b)
		if db < da:
			dips.append([int(a["id"]), int(b["id"])])
			assert_lt(da - db, DIP_MAX, "провал %d→%d неглибокий" % [int(a["id"]), int(b["id"])])
			assert_ne(String(b.get("world", "")), String(a.get("world", "")),
				"провал %d→%d дозволено лише там, де починається новий світ" % [int(a["id"]), int(b["id"])])
			assert_true(bool(b.get("tutorial", false)),
				"рівень %d, на якому складність падає, мусить бути знайомством із біомом" % int(b["id"]))
	assert_lt(dips.size(), 5, "провалів не більше, ніж переходів між світами")


## Кожен провал пояснюється тим самим: далі починається новий світ, і його перший рівень —
## перепочинок із підказкою. Якщо дані зміняться так, що провал з'явиться посеред світу,
## цей тест почервоніє.
## Зворотний бік того самого правила: перший рівень нового світу МОЖЕ бути легшим за
## попередній, але не мусить. Тут перевіряємо лише, що кожен такий рівень справді позначений
## як знайомство з біомом — інакше «перепочинок» вийшов би випадковим, а не задуманим.
func test_every_world_opener_is_marked_as_a_tutorial() -> void:
	for i in range(_levels.size() - 1):
		var a: Dictionary = _levels[i]
		var b: Dictionary = _levels[i + 1]
		if String(a.get("world", "")) == String(b.get("world", "")):
			continue
		assert_true(bool(b.get("tutorial", false)),
			"рівень %d відкриває світ %s — має бути знайомством" % [int(b["id"]), String(b["world"])])


func test_difficulty_grows_strictly_inside_every_world() -> void:
	for i in range(_levels.size() - 1):
		var a: Dictionary = _levels[i]
		var b: Dictionary = _levels[i + 1]
		if String(a.get("world", "")) != String(b.get("world", "")):
			continue
		assert_gt(Difficulty.of(b), Difficulty.of(a),
			"усередині світу %s: %d → %d важчає" % [String(a["world"]), int(a["id"]), int(b["id"])])


## Ядро формули (швидкість + щільність, 0.75 ваги) росте без жодного провалу на всіх 17 рівнях —
## тобто немонотонність приносять саме легші доданки, а не задум прогресії.
func test_speed_and_density_core_never_drops() -> void:
	for i in range(_levels.size() - 1):
		var pa := Difficulty.parts(_levels[i])
		var pb := Difficulty.parts(_levels[i + 1])
		var core_a := Difficulty.W_SPEED * float(pa["speed"]) + Difficulty.W_DENSITY * float(pa["density"])
		var core_b := Difficulty.W_SPEED * float(pb["speed"]) + Difficulty.W_DENSITY * float(pb["density"])
		assert_gt(core_b, core_a, "ядро %d → %d росте" % [int(_levels[i]["id"]), int(_levels[i + 1]["id"])])


## Швидкість і щільність важать більше за все інше разом: рівень, у якого лише вони на максимумі,
## важчий за рівень, у якого максимальні всі три решта.
func test_speed_and_density_outweigh_lanes_types_and_duration() -> void:
	var fast := {"speed_mult": Difficulty.SPEED_MAX, "density": Difficulty.DENSITY_HARD,
		"lanes": Difficulty.LANES_MIN, "obstacle_types": ["stump"], "duration_sec": Difficulty.DURATION_MIN_SEC}
	var wide := {"speed_mult": Difficulty.SPEED_MIN, "density": Difficulty.DENSITY_EASY,
		"lanes": Difficulty.LANES_MAX, "obstacle_types": [], "duration_sec": Difficulty.DURATION_MAX_SEC}
	assert_gt(Difficulty.of(fast), Difficulty.of(wide), "швидкий і щільний важчий за широкий і довгий")
	assert_almost_eq(Difficulty.W_SPEED + Difficulty.W_DENSITY + Difficulty.W_LANES
		+ Difficulty.W_TYPES + Difficulty.W_DURATION, 1.0, 0.0001, "ваги дають рівно одиницю")


## Нормувальні межі в коді — це діапазони справжніх даних. Щойно дані з них вийдуть, складність
## почне впиратись у стелю мовчки; тест не дає цьому статись.
func test_real_data_stays_inside_the_normalising_ranges() -> void:
	for l in _levels:
		var id := int(l["id"])
		assert_between(float(l["speed_mult"]), Difficulty.SPEED_MIN, Difficulty.SPEED_MAX, "рівень %d: швидкість" % id)
		assert_between(float(l["density"]), Difficulty.DENSITY_HARD, Difficulty.DENSITY_EASY, "рівень %d: щільність" % id)
		assert_between(Difficulty.widest_lanes(l), Difficulty.LANES_MIN, Difficulty.LANES_MAX, "рівень %d: доріжки" % id)
		assert_between(float(l["duration_sec"]), Difficulty.DURATION_MIN_SEC, Difficulty.DURATION_MAX_SEC, "рівень %d: тривалість" % id)
		assert_true((l.get("obstacle_types", []) as Array).size() <= Difficulty.OBSTACLE_TYPES_MAX, "рівень %d: типів перешкод" % id)


## Порожній `obstacle_types` — це «всі типи біому», тобто максимум, а не нуль.
func test_empty_obstacle_types_mean_the_whole_biome() -> void:
	assert_eq(Difficulty.obstacle_variety({}), Difficulty.OBSTACLE_TYPES_MAX, "поля нема — всі типи")
	assert_eq(Difficulty.obstacle_variety({"obstacle_types": []}), Difficulty.OBSTACLE_TYPES_MAX, "список порожній — всі типи")
	assert_eq(Difficulty.obstacle_variety({"obstacle_types": ["stump", "puddle"]}), 2)
	assert_between(Difficulty.of({}), 0.0, 1.0, "порожній рівень не ламає формулу")


## Рівень, що розширюється посеред бігу, рахується за НАЙШИРШОЮ своєю дорогою.
func test_widening_level_counts_by_its_widest_road() -> void:
	assert_eq(Difficulty.widest_lanes({"lanes": 3, "lanes_to": 5}), 5)
	assert_eq(Difficulty.widest_lanes({"lanes": 5}), 5)
	assert_eq(Difficulty.widest_lanes(_level(4)), 5, "рівень 4 розширюється до 5")


func test_fits_covers_both_edges_of_the_range() -> void:
	assert_true(Difficulty.fits(0.0, 0.4, 0.0), "нижній край належить діапазону")
	assert_true(Difficulty.fits(0.0, 0.4, 0.4), "верхній край належить діапазону")
	assert_true(Difficulty.fits(0.4, 1.0, 0.4), "стик належить обом сусідам")
	assert_true(Difficulty.fits(0.0, 0.4, 0.2))
	assert_false(Difficulty.fits(0.0, 0.4, 0.5), "вище верхнього краю")
	assert_false(Difficulty.fits(0.4, 1.0, 0.39), "нижче нижнього краю")
	assert_false(Difficulty.fits(0.4, 1.0, -0.1))
	assert_false(Difficulty.fits(0.8, 0.2, 0.5), "перевернутий діапазон не підходить нікому")
	assert_true(Difficulty.fits(0.5, 0.5, 0.5), "точковий діапазон ловить своє число")


## Той самий чанк на рівні 1 і на рівні 17 бере різні layout'и — заради цього все й рахується.
func test_tutorial_and_final_pick_different_layouts() -> void:
	var easy := [0.0, 0.4]
	var hard := [0.4, 1.0]
	var d1 := Difficulty.of(_level(1))
	var d17 := Difficulty.of(_level(17))
	assert_true(Difficulty.fits(easy[0], easy[1], d1), "рівень 1 — простий layout")
	assert_false(Difficulty.fits(hard[0], hard[1], d1), "рівень 1 не бере складний layout")
	assert_true(Difficulty.fits(hard[0], hard[1], d17), "рівень 17 — складний layout")
	assert_false(Difficulty.fits(easy[0], easy[1], d17), "рівень 17 не бере простий layout")
