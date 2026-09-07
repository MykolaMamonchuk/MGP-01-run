## Хвиля (Пляж): герой ковзає на мушлі. Утримання лівої/правої половини екрана — кермо; тап — підскок на гребені.
class_name SlideMode
extends ModeBase

const STEER_SPEED := 2.6     # м/с уздовж x

var _steer := 0
var _t := 0.0


func mode_id() -> String:
	return "slide"


func enter() -> void:
	hero.set_vehicle(true)
	hero.set_duck(false)
	hero.free_x = true
	_steer = 0


func exit() -> void:
	hero.free_x = false
	hero.set_vehicle(false)
	hero.snap_to_lane()


func gesture(kind: String, _pos: Vector2) -> void:
	match kind:
		"tap", "swipe_up":
			if hero.jump(0.85):
				AudioMgr.sfx("splash")
		"swipe_left":
			hero.nudge_x(-1.0)
		"swipe_right":
			hero.nudge_x(1.0)
		"swipe_down":
			# пригнутись під балкою пірсу / сіткою (утримання тут — кермо, тому лише свайп)
			hero.set_duck(true)
			AudioMgr.sfx("slide")
			run.get_tree().create_timer(0.7).timeout.connect(Callable(run, "_release_assist_duck"))
		"hold_end":
			hero.set_duck(false)


func steer(pressed: bool, pos: Vector2) -> void:
	if not pressed:
		_steer = 0
		return
	_steer = Gestures.steer_side(pos, run.get_viewport().get_visible_rect().size.x)


func tick(delta: float) -> float:
	_t += delta
	if _steer != 0:
		hero.x_target = clampf(hero.x_target + float(_steer) * STEER_SPEED * delta, -hero.x_limit(), hero.x_limit())
		hero.tilt(float(_steer) * -0.35)
	else:
		hero.tilt(0.0)
	# погойдування на хвилі
	hero.wave_offset = sin(_t * 3.0) * 0.08
	return speed * float(world.get("speed_factor", 0.8)) * delta


func assist_distance() -> float:
	return speed * float(world.get("speed_factor", 0.8)) * 0.5


func assist(o: Obstacle3D) -> void:
	match o.action:
		"duck":
			hero.set_duck(true)
			run.get_tree().create_timer(0.7).timeout.connect(Callable(run, "_release_assist_duck"))
		"side":
			hero.x_target = clampf(hero.x_target + (-1.0 if o.position.x >= hero.position.x else 1.0), -hero.x_limit(), hero.x_limit())
		"jump":
			hero.jump(0.85)
