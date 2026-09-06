## Хвиля (Пляж): герой ковзає на мушлі. Утримання лівої/правої половини екрана — кермо; тап — підскок на гребені.
class_name SlideMode
extends ModeBase

const STEER_SPEED := 2.6     # м/с уздовж x
const X_LIMIT := 1.3

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


func steer(pressed: bool, pos: Vector2) -> void:
	if not pressed:
		_steer = 0
		return
	_steer = Gestures.steer_side(pos, run.get_viewport().get_visible_rect().size.x)


func tick(delta: float) -> float:
	_t += delta
	if _steer != 0:
		hero.x_target = clampf(hero.x_target + float(_steer) * STEER_SPEED * delta, -X_LIMIT, X_LIMIT)
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
		"side":
			hero.x_target = clampf(hero.x_target + (-1.0 if o.position.x >= hero.position.x else 1.0), -X_LIMIT, X_LIMIT)
		"jump":
			hero.jump(0.85)
