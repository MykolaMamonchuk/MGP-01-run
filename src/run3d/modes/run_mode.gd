## Біг (Лужок): авто-рух, 3 доріжки. Свайп ←→ — доріжка; тап / свайп ↑ — стрибок; утримання — присід.
class_name RunMode
extends ModeBase


func mode_id() -> String:
	return "run"


func enter() -> void:
	hero.set_vehicle(false)
	hero.set_duck(false)


func exit() -> void:
	hero.set_duck(false)


func gesture(kind: String, _pos: Vector2) -> void:
	match kind:
		"tap", "swipe_up":
			if hero.jump():
				AudioMgr.sfx("jump")
		"swipe_left":
			hero.change_lane(-1)
		"swipe_right":
			hero.change_lane(1)
		"swipe_down", "hold_start":
			hero.set_duck(true)
		"hold_end":
			hero.set_duck(false)


func tick(delta: float) -> float:
	return speed * delta


func assist(o: Obstacle3D) -> void:
	match o.action:
		"duck":
			hero.set_duck(true)
			run.get_tree().create_timer(0.7).timeout.connect(Callable(run, "_release_assist_duck"))
		"jump":
			hero.jump()
		"side":
			hero.change_lane(-1 if o.lane >= 0 else 1)
