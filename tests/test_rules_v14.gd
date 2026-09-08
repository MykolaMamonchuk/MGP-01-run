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


# ---------- множник ----------

func test_multiplier_is_level_at_start() -> void:
	assert_eq(Rules.multiplier(1, 0, false), 1, "перший рівень, серії нема")
	assert_eq(Rules.multiplier(5, 0, false), 5, "п'ятий рівень — ×5")


func test_multiplier_grows_every_five_obstacles() -> void:
	assert_eq(Rules.multiplier(1, 4, false), 1, "4 перешкоди — ще ×1")
	assert_eq(Rules.multiplier(1, 5, false), 2, "5 перешкод — ×2")
	assert_eq(Rules.multiplier(1, 9, false), 2)
	assert_eq(Rules.multiplier(1, 10, false), 3)
	assert_eq(Rules.multiplier(3, 10, false), 9, "рівень 3 × (1 + 10/5)")


func test_multiplier_x2_pickup_doubles() -> void:
	assert_eq(Rules.multiplier(2, 5, true), 8, "2 × (1 + 5/5) = 4, з ×2 — 8")
	assert_eq(Rules.multiplier(1, 0, true), 2)


func test_multiplier_is_safe_on_garbage() -> void:
	assert_eq(Rules.multiplier(0, 0, false), 1, "рівня 0 не буває — не менше ×1")
	assert_eq(Rules.multiplier(-3, -7, false), 1)


# ---------- сорока краде половину ----------

func test_steal_amount_is_half() -> void:
	assert_eq(Rules.steal_amount(100), 50)
	assert_eq(Rules.steal_amount(1), 0, "з одного злитка половина — 0, дитина не йде в мінус")
	assert_eq(Rules.steal_amount(7), 3, "донизу")
	assert_eq(Rules.steal_amount(0), 0)
	assert_eq(Rules.steal_amount(-10), 0, "від'ємних злитків не буває")


func test_steal_leaves_the_rest() -> void:
	var coins := 250
	var left := coins - Rules.steal_amount(coins)
	assert_eq(left, 125, "половина лишається дитині")


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


func test_events_keeps_level_restarted_signal() -> void:
	# сигнал лишився оголошеним заради сумісності, хоч його більше не шлють
	assert_true(Events.has_signal("level_restarted"), "сигнал лишився в шині")
	assert_true(Events.has_signal("coins_stolen"), "нова подія: сорока вкрала")
