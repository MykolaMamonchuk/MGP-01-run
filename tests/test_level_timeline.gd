## LevelTimeline.extract() — Phase 1 «level-authoring plumbing». Чиста функція: дерево збираємо
## в тесті вручну (LevelMarker3D.new()), без .tscn і без ресурсів (див. level_timeline.gd).
extends GutTest


func _marker(role: String, kind: String, z: float, x: float = 0.0, y: float = 0.0,
		lane: int = 0, yaw_deg: float = 0.0, scale_mul: float = 1.0, override: Dictionary = {}) -> LevelMarker3D:
	var m := LevelMarker3D.new()
	m.role = role
	m.kind = kind
	m.lane = lane
	m.yaw_deg = yaw_deg
	m.scale_mul = scale_mul
	m.override = override
	m.position = Vector3(x, y, z)
	return m


## Дерево з проміжними вузлами (Node3D-контейнерами) — екстракція має бути рекурсивною,
## а не лише по прямих дітях.
func _small_tree() -> Node3D:
	var root := Node3D.new()
	var group_a := Node3D.new()
	root.add_child(group_a)
	group_a.add_child(_marker("decor", "flower", -3.0, 0.6, 0.0))
	group_a.add_child(_marker("decor", "bush", -1.0, -0.7, 0.0))
	root.add_child(_marker("obstacle", "stump", -10.0, 0.0, 0.0, 1))
	root.add_child(_marker("obstacle", "branch", -5.0, 0.0, 0.0, -1))
	root.add_child(_marker("building", "house_red", -20.0, 3.0, 0.0))
	root.add_child(_marker("pickup", "heart", -8.0, 0.0, 0.5, 0))
	root.add_child(_marker("landmark", "arch_terracotta", -28.0))
	root.add_child(_marker("wall_near", "fence", -2.0, 2.0, 0.0))
	return root


func test_extract_buckets_by_role_and_counts() -> void:
	var out := LevelTimeline.extract(autofree(_small_tree()))
	assert_eq((out["decor"] as Array).size(), 2, "два decor-маркери, у тому числі з вкладеної групи")
	assert_eq((out["obstacles"] as Array).size(), 2)
	assert_eq((out["buildings"] as Array).size(), 1)
	assert_eq((out["pickups"] as Array).size(), 1)
	assert_eq((out["landmarks"] as Array).size(), 1)
	assert_eq((out["walls_near"] as Array).size(), 1)


func test_extract_sorts_each_bucket_by_z_m_ascending() -> void:
	var out := LevelTimeline.extract(autofree(_small_tree()))
	var obstacles: Array = out["obstacles"]
	# branch (position.z -5) стає z_m 5, stump (position.z -10) — z_m 10: branch раніше stump
	assert_eq(String(obstacles[0]["kind"]), "branch")
	assert_eq(String(obstacles[1]["kind"]), "stump")
	assert_true(float(obstacles[0]["z_m"]) < float(obstacles[1]["z_m"]))


## Знак: SPAWN_Z = -34 означає «34 м попереду»; маркер стоїть уздовж -Z так само, тож
## z_m = -position.z (без інверсії результат читався б навпаки — ближче до старту вважалось би далі).
func test_z_m_is_negated_position_z_matching_spawn_z_convention() -> void:
	var out := LevelTimeline.extract(autofree(_small_tree()))
	var obstacles: Array = out["obstacles"]
	for rec in obstacles:
		if String(rec["kind"]) == "stump":
			assert_eq(float(rec["z_m"]), 10.0, "position.z -10 → z_m +10 (10 м від старту)")
		if String(rec["kind"]) == "branch":
			assert_eq(float(rec["z_m"]), 5.0)
	var landmarks: Array = out["landmarks"]
	assert_eq(float(landmarks[0]["z_m"]), 28.0)


func test_extract_round_trips_marker_fields() -> void:
	var out := LevelTimeline.extract(autofree(_small_tree()))
	var obstacles: Array = out["obstacles"]
	var stump: Dictionary = obstacles[1]
	assert_eq(String(stump["kind"]), "stump")
	assert_eq(int(stump["lane"]), 1)
	var branch: Dictionary = obstacles[0]
	assert_eq(int(branch["lane"]), -1)
	var decor: Array = out["decor"]
	# decor[0] має бути flower (z_m 3) раніше bush (z_m 1) — сортування за z_m, не за порядком дітей
	assert_eq(String(decor[0]["kind"]), "bush")
	assert_eq(String(decor[1]["kind"]), "flower")
	assert_almost_eq(float(decor[1]["x_m"]), 0.6, 0.0001)


func test_extract_on_empty_tree_returns_empty_sorted_arrays() -> void:
	var out := LevelTimeline.extract(autofree(Node3D.new()))
	for key in ["decor", "obstacles", "pickups", "buildings", "landmarks", "walls_near"]:
		assert_true(out.has(key), "ключ '%s' присутній навіть без жодного маркера" % key)
		assert_eq((out[key] as Array).size(), 0)
