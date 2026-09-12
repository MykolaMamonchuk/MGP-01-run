## Правила GDD v1.4 §3/§10 (Rules): зірки = серця, множник злитків, крадіжка сороки, штраф за удар.
## Чисті функції — без сцени.
extends GutTest


# ---------- зірки фінішу = серця, що лишились ----------

func test_stars_from_hearts() -> void:
	assert_eq(Rules.stars_from_hearts(3), 3, "усі серця — три зірки")
	assert_eq(Rules.stars_from_hearts(2), 2)
	assert_eq(Rules.stars_from_hearts(1), 1)


func test_stars_never_below_one() -> void:
	assert_eq(Rules.stars_from_hearts(0), 1, "гра без програшу: мінімум одна зірка")
	assert_eq(Rules.stars_from_hearts(-5), 1)


func test_stars_never_above_three() -> void:
	# Соня має 4 серця, але зірок на панелі три
	assert_eq(Rules.stars_from_hearts(4), 3)
	assert_eq(Rules.stars_from_hearts(99), 3)


# ---------- множник (EDD §2: без номера рівня, зі стелею ×3) ----------

func test_multiplier_starts_at_one_on_every_level() -> void:
	assert_eq(Rules.multiplier(1, 0, false), 1, "серії нема — ×1")
	assert_eq(Rules.multiplier(5, 0, false), 1, "номер рівня більше не множить")
	assert_eq(Rules.multiplier(17, 0, false), 1, "на фіналі так само ×1")


func test_multiplier_grows_every_ten_obstacles() -> void:
	assert_eq(Rules.multiplier(1, 9, false), 1, "9 перешкод — ще ×1")
	assert_eq(Rules.multiplier(1, 10, false), 2, "10 перешкод — ×2")
	assert_eq(Rules.multiplier(1, 19, false), 2)
	assert_eq(Rules.multiplier(1, 20, false), 3)


func test_multiplier_is_capped_at_three() -> void:
	assert_eq(Rules.multiplier(1, 100, false), Rules.MULT_CAP, "довга серія впирається в стелю")
	assert_eq(Rules.multiplier(17, 460, false), 3, "фінальний рівень: було ×1500, стало ×3")


func test_multiplier_x2_pickup_doubles() -> void:
	assert_eq(Rules.multiplier(2, 10, true), 4, "(1 + 10/10) = 2, з пікапом ×2 — 4")
	assert_eq(Rules.multiplier(1, 0, true), 2)
	assert_eq(Rules.multiplier(1, 999, true), 6, "стеля ×3, пікап подвоює вже її")


func test_multiplier_is_safe_on_garbage() -> void:
	assert_eq(Rules.multiplier(0, 0, false), 1, "рівня 0 не буває — не менше ×1")
	assert_eq(Rules.multiplier(-3, -7, false), 1)


# ---------- сорока краде 30 %, але не більше 150 ----------

func test_steal_amount_is_thirty_percent() -> void:
	assert_eq(Rules.steal_amount(100), 30)
	assert_eq(Rules.steal_amount(1), 0, "з одного злитка — 0, дитина не йде в мінус")
	assert_eq(Rules.steal_amount(7), 2, "донизу")
	assert_eq(Rules.steal_amount(0), 0)
	assert_eq(Rules.steal_amount(-10), 0, "від'ємних злитків не буває")


func test_steal_is_capped() -> void:
	assert_eq(Rules.steal_amount(500), Rules.STEAL_CAP, "500 × 0,3 = 150 — рівно стеля")
	assert_eq(Rules.steal_amount(2000), Rules.STEAL_CAP, "на пізніх рівнях крадіжка не росте нескінченно")
	assert_lte(Rules.steal_amount(999999), Rules.STEAL_CAP)


func test_steal_leaves_the_rest() -> void:
	var coins := 250
	var left := coins - Rules.steal_amount(coins)
	assert_eq(left, 175, "70 % лишається дитині")


# ---------- бонус фінішу ----------

func test_finish_bonus_grows_with_level() -> void:
	assert_eq(Rules.finish_bonus(1, 2), 40, "рівень 1, 2★: 20 + 20")
	assert_eq(Rules.finish_bonus(1, 3), 50)
	assert_eq(Rules.finish_bonus(17, 2), 360, "фінал на 2★")
	assert_eq(Rules.finish_bonus(17, 3), 370)
	assert_gt(Rules.finish_bonus(11, 1), Rules.finish_bonus(9, 3), "два рівні різниці важать більше за дві зірки")


func test_finish_bonus_is_safe_on_garbage() -> void:
	assert_eq(Rules.finish_bonus(0, 0), 30, "рівня 0 не буває — рахуємо як 1, зірок мінімум 1")
	assert_eq(Rules.finish_bonus(-5, 99), 50, "зірок не більше трьох")


# ---------- кожен наступний удар: −10% ----------

func test_hit_penalty_is_ten_percent() -> void:
	assert_eq(Rules.hit_penalty(100), 10)
	assert_eq(Rules.hit_penalty(125), 12, "донизу")
	assert_eq(Rules.hit_penalty(9), 0, "мало злитків — удар безкоштовний")
	assert_eq(Rules.hit_penalty(0), 0)
	assert_eq(Rules.hit_penalty(-40), 0)


func test_hit_penalty_never_goes_below_zero() -> void:
	var coins := 30
	for i in range(20):
		coins = maxi(0, coins - Rules.hit_penalty(coins))
	assert_gte(coins, 0, "скільки б не було ударів — не менше нуля")


# ---------- потік рівня без перезапуску ----------

func test_no_restart_state_left() -> void:
	# стан RESTART прибрано з Run3D: серця тепер лише перетворюються на зірки
	var f := FileAccess.open("res://src/run3d/run3d.gd", FileAccess.READ)
	assert_not_null(f, "run3d.gd на місці")
	var src := f.get_as_text()
	assert_false(src.contains("State.RESTART"), "стану RESTART більше нема")
	assert_false(src.contains("func _restart_level"), "перезапуску рівня більше нема")
	assert_true(src.contains("_magpie_steal"), "замість перезапуску — сорока краде злитки")
	assert_true(src.contains("Rules.finish_bonus("), "бонус фінішу рахує Rules, а не число в run3d")
	assert_false(src.contains("add_stars(20 + 10 * stars)"), "плаского бонусу «20 + 10×зірки» більше нема")
	assert_true(src.contains("POWER_CHARGE_PER_PICKUP"), "внесок одного злитка в заряд обмежено")


func test_events_keeps_level_restarted_signal() -> void:
	# сигнал лишився оголошеним заради сумісності, хоч його більше не шлють
	assert_true(Events.has_signal("level_restarted"), "сигнал лишився в шині")
	assert_true(Events.has_signal("coins_stolen"), "нова подія: сорока вкрала")
