## Авторський маркер каже ДІЮ, а вид добирає світ (крок 2½, docs/tasks/reusable-chunks.md).
##
## Навіщо. Спільних ВИДІВ перешкод між світами майже нема (Лужок ∩ Ліс — лише xbox), тож чанк,
## написаний видами, не переживає й двох світів. А дії (jump/duck/side) має кожен світ. Тому
## запис із action і без kind означає «тут треба перестрибнути», а модель підставляє біом —
## з оглядом на obstacle_types рівня.
extends GutTest

var _spawner: Spawner3D


func _world(name_: String) -> Dictionary:
	var f := FileAccess.open("res://data/worlds/%s.json" % name_, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _make_spawner(world_name: String = "meadow") -> Spawner3D:
	var sp := Spawner3D.new()
	add_child_autofree(sp)
	sp.world = _world(world_name)
	sp.profile = {}
	sp.lanes = 3
	sp.spawning = true
	sp.finish_pending = false
	var mode := ModeBase.new()
	mode.speed = 4.0
	sp.mode = mode
	return sp


func before_each() -> void:
	_spawner = _make_spawner()
	await wait_process_frames(1)


func _obstacles(sp: Spawner3D = null) -> Array:
	var target := sp if sp != null else _spawner
	var out := []
	for c in target.get_children():
		if c is Obstacle3D:
			out.append(c)
	return out


## z_m 34 — рівно поріг SPAWN_Z, тобто «спавнити негайно на advance(0)».
func _rec(action: String, kind: String = "", z_m: float = 34.0, lane: int = 0) -> Dictionary:
	return {"z_m": z_m, "kind": kind, "action": action, "lane": lane,
		"override": {}, "yaw_deg": 0.0, "scale": 1.0}


func _action_of(sp: Spawner3D, kind: String) -> String:
	var defs: Dictionary = sp.world.get("obstacles", {})
	return String((defs.get(kind, {}) as Dictionary).get("action", ""))


## Головне: маркер каже дію — на дорогу лягає перешкода САМЕ ЦІЄЇ дії.
func test_action_marker_spawns_obstacle_with_that_action() -> void:
	for action in ["jump", "duck", "side"]:
		var sp := _make_spawner()
		await wait_process_frames(1)
		sp.set_authored_obstacles([_rec(action)])
		sp.advance(0.0)
		var obs := _obstacles(sp)
		assert_eq(obs.size(), 1, "дія «%s» дала перешкоду" % action)
		if obs.is_empty():
			continue
		assert_eq(_action_of(sp, obs[0].kind), action,
			"дія «%s»: світ підставив «%s», а в нього дія «%s»"
				% [action, obs[0].kind, _action_of(sp, obs[0].kind)])


## Обмеження рівня сильніше за вибір: із двох «духових» перешкод Лужка (branch, clothesline)
## рівень дозволив лише одну — саме вона й мусить стати.
func test_level_obstacle_types_limit_the_choice() -> void:
	_spawner.level_types = ["clothesline"]
	var records := []
	for i in range(8):
		records.append(_rec("duck", "", 34.0 + float(i)))
	_spawner.set_authored_obstacles(records)
	for i in range(9):
		_spawner.advance(1.0)
	var obs := _obstacles()
	assert_eq(obs.size(), 8, "усі вісім записів спавнились")
	for o in obs:
		assert_eq(o.kind, "clothesline", "рівень дозволив лише clothesline — іншого бути не може")


## Нема придатної перешкоди — запис ПРОПУСКАЄТЬСЯ, гра не падає й не ставить навмання.
## «wind» є лише в Хмаринках; у Лужку такої дії нема взагалі.
func test_action_absent_in_world_is_skipped_without_crashing() -> void:
	_spawner.set_authored_obstacles([_rec("wind"), _rec("jump", "", 35.0)])
	for i in range(3):
		_spawner.advance(1.0)
	var obs := _obstacles()
	assert_eq(obs.size(), 1, "запис із неможливою дією пропущено, наступний працює далі")
	assert_eq(_action_of(_spawner, obs[0].kind), "jump")


## Те саме, але дію відрізало обмеження рівня: у списку лише «стрибкові» види, а маркер просить
## ухилитись. Мовчазна підміна тут зробила б рівень непрохідним тихо.
func test_level_types_that_exclude_the_action_skip_the_record() -> void:
	_spawner.level_types = ["stump", "fence"]
	_spawner.set_authored_obstacles([_rec("duck")])
	_spawner.advance(0.0)
	assert_eq(_obstacles().size(), 0, "серед дозволених рівнем видів «духових» нема — запис пропущено")


## Головний сторож від регресії: маркер із kind (як усі 105 наявних чанків) працює точно як
## раніше — вид береться дослівно, дія на нього не впливає.
func test_kind_marker_keeps_working_exactly_as_before() -> void:
	_spawner.set_authored_obstacles([
		{"z_m": 34.0, "kind": "stump", "lane": 1, "override": {}, "yaw_deg": 0.0, "scale": 1.0},
		_rec("duck", "fence", 35.0, -1),
	])
	for i in range(2):
		_spawner.advance(1.0)
	var obs := _obstacles()
	assert_eq(obs.size(), 2)
	assert_eq(obs[0].kind, "stump", "запис без поля action (старий формат) — вид дослівно")
	assert_eq(obs[0].lane, 1)
	assert_eq(obs[1].kind, "fence", "kind заданий — action його не переважує")


## Вид, якого в цьому світі нема, і далі пропускається (стара поведінка не змінилась).
func test_unknown_kind_is_still_skipped() -> void:
	_spawner.set_authored_obstacles([_rec("", "kiosk_of_another_world")])
	_spawner.advance(0.0)
	assert_eq(_obstacles().size(), 0)


## Відтворюваність: два прогони з тим самим GAME_SEED дають ТОЙ САМИЙ вид. Без власного
## засіяного _rng тут стояв би глобальний randi(), і рівень мінявся б від запуску до запуску —
## саме через це замір «до/після» одного разу коштував дня (docs/MEMORY.md).
func test_same_seed_gives_the_same_kinds() -> void:
	var was := OS.get_environment(RngSeed.ENV)
	OS.set_environment(RngSeed.ENV, "20260918")
	var first := await _run_side_sequence()
	var second := await _run_side_sequence()
	OS.set_environment(RngSeed.ENV, was)
	assert_eq(first, second, "те саме зерно — та сама послідовність видів")
	assert_gt(first.size(), 0, "види добрались")


## Без фіксованого зерна вибір лишається випадковим (гра для дитини не стає одноманітною):
## на 16 записах із двох «бічних» видів Лужка мусять трапитись обидва.
func test_without_a_seed_the_choice_still_varies() -> void:
	var was := OS.get_environment(RngSeed.ENV)
	OS.set_environment(RngSeed.ENV, "")
	var kinds := await _run_side_sequence()
	OS.set_environment(RngSeed.ENV, was)
	var uniq := {}
	for k in kinds:
		uniq[k] = true
	assert_gt(uniq.size(), 1, "вибір виду не прибитий до одного значення: %s" % [kinds])


## 16 записів із дією «side» у Лужку: дозволені види — beehive і cow (xbox і транспорт
## haycart виключені навмисно). Повертає послідовність видів у порядку спавну.
func _run_side_sequence() -> Array:
	var sp := _make_spawner()
	await wait_process_frames(1)
	var records := []
	for i in range(16):
		records.append(_rec("side", "", 34.0 + float(i) * 2.0))
	sp.set_authored_obstacles(records)
	for i in range(34):
		sp.advance(1.0)
	var out := []
	for o in _obstacles(sp):
		out.append(o.kind)
	return out


## Транспорт (shape "vehicle") — це кузов із рампою й дахом-ярусом, його ставить окремий
## шлях. Під «обійди збоку» він не підставляється, хоч дія в нього й «side».
func test_vehicle_is_never_chosen_for_an_action() -> void:
	_spawner.level_types = ["haycart", "beehive"]
	var kinds := {}
	for i in range(12):
		_spawner.add_authored_obstacles([_rec("side", "", 34.0 + float(i) * 2.0)])
	for i in range(34):
		_spawner.advance(1.0)
	for o in _obstacles():
		kinds[o.kind] = true
	assert_false(kinds.has("haycart"), "haycart — транспорт, а не перешкода під дію")
	assert_true(kinds.has("beehive"), "лишився єдиний придатний вид")


## Той самий вибір працює в будь-якому світі — це і є сенс дій замість видів.
func test_action_markers_work_in_every_world() -> void:
	for world_name in ["meadow", "forest", "city", "beach", "clouds"]:
		var sp := _make_spawner(world_name)
		await wait_process_frames(1)
		sp.set_authored_obstacles([_rec("jump"), _rec("duck", "", 35.0), _rec("side", "", 36.0)])
		for i in range(3):
			sp.advance(1.0)
		assert_eq(_obstacles(sp).size(), 3,
			"у світі «%s» знайшлись перешкоди для jump, duck і side" % world_name)
