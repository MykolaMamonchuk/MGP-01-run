## Гра гріє шейдер веселки на відліку ЛИШЕ на рівнях, де веселка буває (tests/test_rainbow_warm.gd
## пояснює, чому без прогріву перша веселка смикала кадр на 144–464 мс).
extends GutTest

var _scene: Node


func before_each() -> void:
	_scene = load("res://src/run3d/run3d.tscn").instantiate()
	add_child(_scene)
	await wait_process_frames(5)
	_scene._demo_any_level = true   # рівень 3 у чистому збереженні ще не куплений


func after_each() -> void:
	_scene.free()
	_scene = null


func test_level_with_rainbow_preheats_it() -> void:
	_scene._start_level(3)
	assert_true((_scene.events_spawner.allowed_ids as Array).has("rainbow"), "на рівні 3 веселка є")
	assert_not_null(_scene.get_node_or_null("RainbowPreheat"), "і її гріють на відліку")


func test_level_without_rainbow_does_not() -> void:
	_scene._start_level(1)
	assert_false((_scene.events_spawner.allowed_ids as Array).has("rainbow"), "на рівні 1 веселки нема")
	assert_null(_scene.get_node_or_null("RainbowPreheat"), "то й гріти нічого")
