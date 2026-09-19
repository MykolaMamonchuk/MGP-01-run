## Три моменти, які гравець бачить найчастіше: стрибок, перехід на сусідню доріжку і
## перечеплення об перешкоду. Довго вони були «є, але не читаються»: стрибок злітав
## застиглою позою, зміна доріжки була самим лише нахилом, а удар — обертом навколо осі.
extends GutTest

var _hero: Hero3D


func before_each() -> void:
	_hero = Hero3D.new()
	add_child_autofree(_hero)
	var def := Hero3D.resolve_def(Hero3D.defs(), "lys")
	_hero.set_hero("lys", Palette.of(def.get("color"), Palette.HERO_DEFAULT),
		String(def.get("feature", "fox")))
	await wait_process_frames(1)


## У стрибку ноги й ніс ведуться вертикальною швидкістю, а не застиглим профілем.
## 0 — злітаємо, 1 — падаємо; саме цим числом і різняться поза вгорі й перед землею.
func test_jump_phase_runs_from_takeoff_to_landing() -> void:
	assert_almost_eq(Hero3D.jump_fall_k(6.0, 6.0), 0.0, 0.001, "щойно відштовхнулись — 0")
	assert_almost_eq(Hero3D.jump_fall_k(0.0, 6.0), 0.5, 0.001, "верхівка — 0,5")
	assert_almost_eq(Hero3D.jump_fall_k(-6.0, 6.0), 1.0, 0.001, "падаємо — 1")
	assert_almost_eq(Hero3D.jump_fall_k(-99.0, 6.0), 1.0, 0.001, "швидше за розрахунок — усе одно 1")
	assert_almost_eq(Hero3D.jump_fall_k(1.0, 0.0), 0.0, 0.001, "нульова база не ділить на нуль")


## Перехід на сусідню доріжку — підскок із доворотом носа, а не саме лише ковзання.
func test_lane_change_hops_and_turns_then_settles() -> void:
	var body := _hero._body
	body.position.y = 0.0
	body.rotation.y = 0.0
	assert_true(_hero.change_lane(1), "доріжка змінилась")
	assert_not_null(_hero._lane_tween, "підскок запущено")

	_hero._lane_tween.custom_step(0.10)
	assert_gt(body.position.y, 0.0, "тіло підстрибнуло")
	assert_ne(body.rotation.y, 0.0, "і довернулось носом у бік нової доріжки")

	_hero._lane_tween.custom_step(0.40)
	assert_almost_eq(body.position.y, 0.0, 0.001, "приземлилось назад")
	assert_almost_eq(body.rotation.y, 0.0, 0.001, "і вирівнялось")


## У танці підскок не втручається: там `_body.rotation.y` веде сам танець, і двоє
## керувальників однією віссю билися б між собою.
func test_lane_change_keeps_out_of_the_dance() -> void:
	_hero.dance()
	_hero._lane_tween = null
	_hero.change_lane(1)
	assert_null(_hero._lane_tween, "під час танцю підскок не запускаємо")


## Перечеплення: тіло клює носом уперед і саме вирівнюється.
func test_stumble_pitches_forward_then_recovers() -> void:
	assert_almost_eq(_hero._stumble, 0.0, 0.001, "до удару нахилу нема")
	_hero.hit_reaction(0)
	assert_almost_eq(_hero._stumble, Hero3D.STUMBLE_PITCH, 0.001, "клюнув носом уперед")
	await wait_seconds(0.45)
	assert_lt(_hero._stumble, Hero3D.STUMBLE_PITCH * 0.6, "і вже вирівнюється")


## Прогрів шейдерів частинок: перше спрацювання кожного ефекту коштує 20–30 мс (рушій
## компілює шейдер саме тоді), і на початку рівня це видно як заїкання. Прогрів «стріляє»
## всіма ефектами наперед і за PREHEAT_SEC прибирає по собі — інакше крихітні частинки
## лишались би в сцені назавжди.
func test_particle_preheat_cleans_up_after_itself() -> void:
	FX.preheat(_hero, Vector3.ZERO)
	var probe := _hero.get_node_or_null("FXPreheat")
	assert_not_null(probe, "прогрівальні частинки з'явились у сцені")
	assert_gt(probe.get_child_count(), 0, "і в них справді щось є")

	await wait_seconds(FX.PREHEAT_SEC + 0.25)
	assert_null(_hero.get_node_or_null("FXPreheat"), "і прибрались самі")


## На вузлі поза деревом прогрів має мовчки нічого не робити, а не падати.
func test_particle_preheat_is_safe_outside_the_tree() -> void:
	var loose := Node3D.new()
	FX.preheat(loose, Vector3.ZERO)
	assert_eq(loose.get_child_count(), 0, "поза деревом нічого не створюємо")
	loose.free()
