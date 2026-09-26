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


## Під меню, мапою й відліком дорога теж їде (advance) — гуски там не з'являються; clear()
## (вихід у меню) їх вимикає зовсім. Рецензія 26.09: гуски пропливали під меню застиглими.
func test_husky_lyshe_v_bihu() -> void:
	var sp := Spawner3D.new()
	add_child_autofree(sp)
	sp.world = _world()
	sp.lanes = 3
	sp.set_grazers(true)
	sp.spawning = false
	for i in 60:
		sp._advance_grazers(2.0)
	assert_eq(sp.get_children().filter(func(c): return c is GooseGrazer3D).size(), 0,
		"поза бігом (меню, відлік) — жодної гуски")
	sp.clear()
	assert_false(sp.grazers_on, "clear() вимикає гусок до наступного рівня")


## Рівень 4: дорога 3 → 5 доріжок. Гуска на узбіччі відступає разом із краєм.
func test_rozshyrennia_dorohy_vidsuvaie_husku() -> void:
	var sp := Spawner3D.new()
	add_child_autofree(sp)
	sp.lanes = 3
	var g := GooseGrazer3D.new()
	var rng := RandomNumberGenerator.new()
	g.setup("goose", rng)
	g.road_edge = 1.6
	g.position = Vector3(2.2, 0.0, -30.0)
	sp.add_child(g)
	sp.lanes = 5
	g.tick(0.016)
	assert_gt(g.position.x, 2.6 + 0.3, "після розширення гуска знову за краєм (край 2,6)")


## Підхід збоку стартує ЗА КРАЄМ дороги для будь-якої доріжки й ширини — не в сусідній доріжці.
func test_pidkhid_startuie_za_kraiem_dorohy() -> void:
	for n_lanes in [3, 5]:
		var sp := Spawner3D.new()
		add_child_autofree(sp)
		sp.lanes = n_lanes
		var edge := float(n_lanes) * 0.5 + 0.1
		for lane in range(-(n_lanes / 2), n_lanes / 2 + 1):
			var o := Obstacle3D.new()
			o.setup("goose_run", _world()["obstacles"]["goose_run"], lane, false)
			o.position.z = -30.0
			sp.add_child(o)
			o.tick(0.016)
			assert_gt(absf(o.position.x), edge + 0.3,
				"%d доріжок, доріжка %d: гуска чекає за краєм (x=%.2f, край %.1f)" % [n_lanes, lane, o.position.x, edge])


## «Клює траву» — голова справді опускається до землі, а не кивок (рецензія 26.09).
func test_kliuie_do_zemli() -> void:
	for path in ["res://assets/props/goose_1.glb", "res://assets/props/goose_2.glb", "res://assets/props/goose_3.glb"]:
		var model := (load(path) as PackedScene).instantiate()
		add_child_autofree(model)
		var r := GooseRig.new()
		r.build(model)
		r.state = "peck"
		r.pose(0.9 * 0.5)   # середина опускання (цикл 1,8 с)
		r.skel.force_update_all_bone_transforms()
		var y := r.skel.get_bone_global_pose(r.head).origin.y
		assert_lt(y, 0.5 * r.height, "%s: голова нижче половини зросту, коли клює" % path.get_file())


## Прогін на телефоні 26.09: зграя злипалась у купу. Гуски однієї зграйки — не ближче MIN_GAP.
func test_zghraia_ne_zlypaietsia() -> void:
	var sp := Spawner3D.new()
	add_child_autofree(sp)
	sp.world = _world()
	sp.lanes = 3
	sp.set_grazers(true)
	sp.spawning = true
	var geese: Array = []
	for i in 400:
		# Світ їде, як у Spawner3D.advance: інакше всі зграйки з'являлись би в одній точці.
		for c in sp.get_children():
			(c as Node3D).position.z += 2.0
		var before := sp.get_child_count()
		sp._advance_grazers(2.0)
		# Порівнюємо гусок ОДНІЄЇ зграйки — тих, що з'явились за цей крок.
		var fresh: Array = sp.get_children().slice(before)
		for a in range(fresh.size()):
			for b in range(a + 1, fresh.size()):
				if (fresh[a] as Node3D).position.distance_to((fresh[b] as Node3D).position) < GooseGrazer3D.MIN_GAP - 0.01:
					geese.append([fresh[a], fresh[b]])
	var total: int = sp.get_children().filter(func(c): return c is GooseGrazer3D).size()
	assert_gt(total, 10, "гусок достатньо, щоб перевірка щось значила")
	assert_eq(geese.size(), 0, "жодна пара гусок зграйки не стоїть одна в одній")



class BoxInTheWay:
	extends Track
	var box_x := -2.5
	func decor_near(x: float, _z: float, r: float) -> bool:
		return absf(x - box_x) < r


## І тікаючи, гуска не забігає в ящик чи бочку (на телефоні — забігала).
func test_tikaie_ne_kriz_yashchyk() -> void:
	var g := _grazer()
	var t := BoxInTheWay.new()
	add_child_autofree(t)
	g.track_override = t
	g.position = Vector3(-2.0, 0.0, -3.0)
	for i in 60:
		g.tick(0.05)
	assert_eq(g._state, "flee", "злякалась")
	assert_gt(g.position.x, t.box_x + 0.3, "зупинилась перед ящиком, а не в ньому (x=%.2f)" % g.position.x)
