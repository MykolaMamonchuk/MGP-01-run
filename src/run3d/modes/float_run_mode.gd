## Невагомий біг (Хмаринки, GDD v1.3): герой біжить сам, як у Бігу, але падає повільно (гравітація 0.4)
## і відштовхується м'якше (стрибок ×0.8) — довгі плавні дуги між хмаринками.
class_name FloatRunMode
extends RunMode

const GRAVITY_SCALE := 0.4
const JUMP_SCALE := 0.8


func mode_id() -> String:
	return "float_run"


func enter() -> void:
	super.enter()
	hero.gravity_scale = GRAVITY_SCALE
	hero.jump_scale = JUMP_SCALE


func exit() -> void:
	super.exit()
	hero.gravity_scale = 1.0
	hero.jump_scale = 1.0


## У невагомості політ довший — допомога має спрацьовувати раніше.
func assist_distance() -> float:
	return speed * 0.6
