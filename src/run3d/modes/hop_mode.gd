## ЗАСТАРІЛО (GDD v1.3): усі світи — біг (RunMode і нащадки). Файл лишено як код на майбутнє; Run3D._make_mode його не створює.
## Стрибки (Ліс): темп задає дитина. Тап — крок уперед на 1 клітинку; свайп ←→ — убік; зіткнення — відкат на 1.
## Світ ще й сам повільно пливе вперед (дрейф), щоб гра не стояла, коли дитина задумалась.
class_name HopMode
extends ModeBase

const STEP_SEC := 0.18
## Дрейф: базово 0,9 клітинки/с при швидкості профілю 4, обмежено 0,6..1,6.
const DRIFT_BASE := 0.9
const DRIFT_MIN := 0.6
const DRIFT_MAX := 1.6

var _pending := 0.0        # скільки клітинок ще треба «прокрутити»
var _idle := 0.0
var _auto_step_sec := 0.0


func mode_id() -> String:
	return "hop"


func is_stepwise() -> bool:
	return true


func enter() -> void:
	hero.set_vehicle(false)
	hero.set_duck(false)
	_pending = 0.0
	_idle = 0.0
	_auto_step_sec = float(profile.get("hop_auto_step_sec", 0.0))


func gesture(kind: String, _pos: Vector2) -> void:
	_idle = 0.0
	match kind:
		"tap", "swipe_up":
			step(1)
		"swipe_left":
			if hero.change_lane(-1):
				hero.hop()
		"swipe_right":
			if hero.change_lane(1):
				hero.hop()
		"swipe_down", "hold_start":
			# пригнутись під павутинку/гілку з совою
			hero.set_duck(true)
			run.get_tree().create_timer(0.8).timeout.connect(Callable(run, "_release_assist_duck"))
		"hold_end":
			hero.set_duck(false)


## Крок на n клітинок (n < 0 — відкат після зіткнення).
func step(n: int) -> void:
	if hero.tumbling and n > 0:
		return
	_pending += float(n)
	hero.hop()
	AudioMgr.sfx("hop")


## Швидкість дрейфу (клітинок/с) — залежить від швидкості профілю/рівня.
func drift_rate() -> float:
	return clampf(DRIFT_BASE * (speed / 4.0), DRIFT_MIN, DRIFT_MAX)


func tick(delta: float) -> float:
	# авто-крок для малюків: білочка «підштовхує», якщо дитина довго не тисне
	if _auto_step_sec > 0.0 and not hero.tumbling:
		_idle += delta
		if _idle >= _auto_step_sec:
			_idle = 0.0
			step(1)
	# дрейф — завжди, окрім падіння (відкат має читатись чисто)
	var move := 0.0
	if not hero.tumbling:
		move = drift_rate() * delta
	# крок від тапу — поверх дрейфу
	if absf(_pending) >= 0.001:
		var rate := 1.0 / STEP_SEC
		var step_move := signf(_pending) * minf(absf(_pending), rate * delta)
		_pending -= step_move
		move += step_move
	return move


func assist(o: Obstacle3D) -> void:
	# у young авто-допомога — це просто крок убік від дерева або присід під павутинкою
	if o.action == "side" and o.lane == hero.lane:
		hero.change_lane(o.side_dir(hero.lane))
	elif o.action == "duck":
		hero.set_duck(true)
		run.get_tree().create_timer(1.2).timeout.connect(Callable(run, "_release_assist_duck"))


## Час до перешкоди: дрейф + приблизно 1 крок/с від дитини.
func seconds_to_hero(dist: float) -> float:
	return dist / max(0.5, drift_rate() + 1.0)


## Допомога спрацьовує, коли перешкода — вже наступна клітинка (ще до тапу дитини).
func assist_distance() -> float:
	return 1.6


func wants_hint() -> bool:
	return _auto_step_sec <= 0.0
