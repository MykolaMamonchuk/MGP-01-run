## ПОВЕДІНКА ГУСОК (задум замовника 26.09): пасеться → підняла голову → вирішила → рух.
##
## Три поведінки: graze (GooseGrazer3D, жива декорація узбіччя), cross_run (goose_run — чекає
## за краєм і перебігає у свою доріжку) і low_fly (goose_fly — прилітає збоку, під нею
## пригинаються). Головне для дитини — «телеграф»: гуска ніколи не з'являється в доріжці
## раптово, а вже в доріжці до зіткнення лишається кілька метрів.
extends GutTest


func _world() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/worlds/meadow.json"))


func _grazer(flock: GooseGrazer3D.Flock = null, leader := true) -> GooseGrazer3D:
	var g := GooseGrazer3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	assert_true(g.setup("goose", rng), "гуска на узбіччі збудувалась")
	g.flock = flock
	g.leader = leader
	g.delay = 0.3
	g.road_edge = 1.6
	g.position = Vector3(-2.2, 0.0, -20.0)
	add_child_autofree(g)
	return g


func test_pasetsia_pidnimaie_holovu_lakaietsia() -> void:
	var g := _grazer()
	g.tick(0.05)
	assert_true(g._state in ["peck", "stand"], "далеко — пасеться")
	g.position.z = -8.0
	for i in 20:
		g.tick(0.05)
	assert_eq(g._state, "alert", "~10 м — підняла голову")
	assert_almost_eq(wrapf(g._body.rotation.y, -PI, PI), 0.0, 0.1, "і повернулась до героя")
	g.position.z = -3.0
	var x0 := g.position.x
	for i in 40:
		g.tick(0.05)
	assert_eq(g._state, "flee", "герой поруч — лякається")
	assert_lt(g.position.x, x0, "відбігає ВІД дороги (ліворуч — ще лівіше)")
	assert_gte(g.position.x, -(1.6 + GooseGrazer3D.FLEE_MAX) - 0.1, "але не в канал")


func test_zghraia_lakaietsia_vid_vedushchoi() -> void:
	var flock := GooseGrazer3D.Flock.new()
	var lead := _grazer(flock, true)
	var other := _grazer(flock, false)
	other.position.z = -6.0   # сама ще далеко від порогу переляку
	lead.position.z = -3.0
	lead.tick(0.05)
	other.tick(0.05)
	assert_eq(lead._state, "flee", "ведуча злякалась")
	assert_ne(other._state, "flee", "решта — не миттєво")
	for i in 10:
		other.tick(0.05)
	assert_eq(other._state, "flee", "а за мить — слідом за ведучою")


func _obstacle(kind: String, lane: int) -> Obstacle3D:
	var o := Obstacle3D.new()
	o.setup(kind, _world()["obstacles"][kind], lane, false)
	add_child_autofree(o)
	return o


func test_perebihaie_u_svoiu_dorizhku() -> void:
	var o := _obstacle("goose_run", -1)
	o.position.z = -20.0
	o.tick(0.016)
	assert_gt(absf(o.position.x), 1.6 + 0.3, "спершу — за краєм дороги")
	assert_true(o._rig_state in ["peck", "alert"], "і пасеться")
	o.position.z = -7.0
	o.tick(0.016)
	assert_eq(o._rig_state, "flee", "біжить навперейми")
	o.position.z = -4.0
	o.tick(0.016)
	assert_almost_eq(o.position.x, -1.0, 0.01, "за 4 м уже у своїй доріжці")
	assert_eq(o._rig_state, "hiss", "і шипить на героя")


func test_letiucha_prylitaie_zboku() -> void:
	var o := _obstacle("goose_fly", 1)
	o.position.z = -25.0
	o.tick(0.016)
	assert_gt(o.position.x, 1.6 + 0.3, "спершу — над узбіччям")
	o.position.z = -5.0
	o.tick(0.016)
	assert_almost_eq(o.position.x, 1.0, 0.01, "за 5 м уже над своєю доріжкою")
	assert_eq(o._rig_state, "fly")


## Жереб зграйок — свій: розстановка перешкод (_rng спавнера) від гусок не зсувається.
func test_zghraiky_ne_zsuvaiut_perechkody() -> void:
	var sp := Spawner3D.new()
	add_child_autofree(sp)
	sp.world = _world()
	sp.lanes = 3
	sp.set_grazers(true)
	var before := sp._rng.state
	for i in 60:
		sp._advance_grazers(2.0)
	assert_eq(sp._rng.state, before, "зграйки не чіпають генератор перешкод")
	var geese := sp.get_children().filter(func(c): return c is GooseGrazer3D)
	assert_gt(geese.size(), 1, "за 120 м з'явились гуски")
	for c in sp.get_children():
		assert_false(c is Obstacle3D, "гуска на узбіччі — не перешкода: зіткнень із нею нема")


func test_poriadok_po_rivniakh() -> void:
	var L = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	var levels: Array = L["levels"] if typeof(L) == TYPE_DICTIONARY else L
	var by_id := {}
	for l in levels:
		by_id[int(l["id"])] = l
	for id in [2, 3]:
		assert_true(bool(by_id[id].get("grazing_geese", false)), "рівень %d: гуски пасуться" % id)
		for k in by_id[id].get("obstacle_types", []):
			assert_false(String(k).begins_with("goose") or k == "cow", "рівень %d: гуска ще не перешкода" % id)
	assert_true(bool(by_id[4].get("grazing_geese", false)), "рівень 4: пасуться")
	assert_eq((by_id[4]["obstacle_types"] as Array).size(), 0, "рівень 4 — усі види: вперше перебігає й летить")
	assert_false(bool(by_id[1].get("grazing_geese", false)), "рівень 1 — ще без гусок")
