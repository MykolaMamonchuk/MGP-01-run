## Серфінг (Пляж, GDD v1.3): Біг на дошці по морю. Керування як у Бігу (свайпи ←→ доріжка, тап — стрибок),
## дошка м'яко погойдується на хвилі.
class_name SurfMode
extends RunMode

const BOB_AMP := 0.06
const BOB_RATE := 2.5

var _t := 0.0


func mode_id() -> String:
	return "surf"


func enter() -> void:
	hero.set_vehicle(true, "surfboard")
	hero.set_duck(false)
	_t = 0.0


func exit() -> void:
	hero.set_duck(false)
	hero.wave_offset = 0.0
	hero.set_vehicle(false)


func gesture(kind: String, pos: Vector2) -> void:
	match kind:
		"tap", "swipe_up":
			if hero.jump():
				AudioMgr.sfx("splash")
		_:
			super.gesture(kind, pos)


func tick(delta: float) -> float:
	_t += delta
	# легке погойдування дошки на хвилі
	hero.wave_offset = sin(_t * BOB_RATE) * BOB_AMP
	return speed * delta
