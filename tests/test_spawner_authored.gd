## Spawner3D.set_authored_obstacles()/clear_authored_obstacles() — Phase 1 «level-authoring
## plumbing». _spawn_group()/_next_gap() лишаються недоторканими (перевіряємо, що випадковий
## шлях і далі працює, коли authored-список не заданий).
extends GutTest

var _spawner: Spawner3D


func _world_meadow() -> Dictionary:
	var f := FileAccess.open("res://data/worlds/meadow.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func before_each() -> void:
	_spawner = Spawner3D.new()
	add_child_autofree(_spawner)
	await wait_process_frames(1)
	_spawner.world = _world_meadow()
	_spawner.profile = {}
	_spawner.lanes = 3
	_spawner.spawning = true
	_spawner.finish_pending = false
	# _spawn_group() (випадковий шлях, не мій код) шле Events.obstacle_spawned через mode.seconds_to_hero() —
	# authored-курсор його не викликає, але тести регресії нижче йдуть саме через _spawn_group().
	var mode := ModeBase.new()
	mode.speed = 4.0
	_spawner.mode = mode


func _obstacles() -> Array:
	var out := []
	for c in _spawner.get_children():
		if c is Obstacle3D:
			out.append(c)
	return out


## SPAWN_Z = -34: authored-запис з'являється, коли distance_m сягне z_m - abs(SPAWN_Z).
func test_authored_obstacles_spawn_in_order_at_correct_distance() -> void:
	var records := [
		{"z_m": 40.0, "kind": "stump", "lane": 1, "override": {}, "yaw_deg": 0.0, "scale": 1.0},
		{"z_m": 50.0, "kind": "branch", "lane": -1, "override": {}, "yaw_deg": 0.0, "scale": 1.0},
	]
	_spawner.set_authored_obstacles(records)
	for i in range(5):
		_spawner.advance(1.0)
	assert_eq(_obstacles().size(), 0, "5 м пройдено — до порогу 40-34=6 ще не дійшли")
	_spawner.advance(1.0)   # distance_m = 6.0 — перший поріг досягнуто
	assert_eq(_obstacles().size(), 1, "перша authored-перешкода з'явилась рівно на порозі")
	assert_eq(_obstacles()[0].kind, "stump")
	for i in range(9):
		_spawner.advance(1.0)   # distance_m = 15 — другий поріг (50-34=16) ще не настав
	assert_eq(_obstacles().size(), 1, "друга перешкода ще не спавнилась")
	_spawner.advance(1.0)   # distance_m = 16.0
	assert_eq(_obstacles().size(), 2, "друга з'явилась рівно на своєму порозі")
	assert_eq(_obstacles()[1].kind, "branch")


func test_authored_obstacle_uses_marker_lane() -> void:
	var records := [{"z_m": 34.0, "kind": "fence", "lane": 1, "override": {}, "yaw_deg": 0.0, "scale": 1.0}]
	_spawner.set_authored_obstacles(records)
	_spawner.advance(0.0)   # поріг 34-34=0 — має спавнитись негайно
	assert_eq(_obstacles().size(), 1)
	assert_eq(_obstacles()[0].lane, 1, "доріжка бере значення з lane маркера, а не випадкова")


func test_authored_obstacles_do_not_spawn_when_not_spawning() -> void:
	_spawner.spawning = false
	_spawner.set_authored_obstacles([{"z_m": 34.0, "kind": "stump", "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0}])
	_spawner.advance(0.0)
	assert_eq(_obstacles().size(), 0, "spawning=false (пауза/меню) — authored-перешкоди теж не сипляться")


## Регресія: без authored-списку (усі 17 рівнів, поки що) advance() і далі веде через
## _next_gap()/_spawn_group(), як і до цієї фічі.
func test_no_authored_obstacles_keeps_random_spawn_group() -> void:
	assert_false(_spawner._authored_active)
	for i in range(200):
		_spawner.advance(0.1)
	assert_gt(_obstacles().size(), 0, "випадковий _spawn_group() і далі ставить перешкоди без authored-списку")


func test_clear_authored_obstacles_restores_random_behavior() -> void:
	_spawner.set_authored_obstacles([{"z_m": 1000.0, "kind": "stump", "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0}])
	_spawner.clear_authored_obstacles()
	assert_false(_spawner._authored_active)
	for i in range(200):
		_spawner.advance(0.1)
	assert_gt(_obstacles().size(), 0, "після clear_authored_obstacles() спавнер знову випадковий")
