## Невагомість (Хмаринки): Стрибки з повільним падінням і вищими стрибками — герой «пливе» між хмаринками.
class_name FloatMode
extends HopMode


func mode_id() -> String:
	return "float"


func enter() -> void:
	super.enter()
	hero.gravity_scale = 0.35


func exit() -> void:
	hero.gravity_scale = 1.0


func gesture(kind: String, pos: Vector2) -> void:
	match kind:
		"swipe_down", "hold_start":
			# присід і в невагомості — пригнутись під хмарку/пташок
			hero.set_duck(true)
			run.get_tree().create_timer(0.8).timeout.connect(Callable(run, "_release_assist_duck"))
		"hold_end":
			hero.set_duck(false)
		_:
			super.gesture(kind, pos)


func assist_distance() -> float:
	return 1.8
