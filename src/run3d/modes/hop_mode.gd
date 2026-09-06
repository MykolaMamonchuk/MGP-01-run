## Стрибки (Ліс): темп задає дитина. Тап — крок уперед на 1 клітинку; свайп ←→ — убік; зіткнення — відкат на 1.
class_name HopMode
extends ModeBase

const STEP_SEC := 0.18

var _pending := 0.0        # скільки клітинок ще треба «прокрутити»
var _idle := 0.0
var _auto_step_sec := 0.0


func mode_id() -> String:
	return "hop"


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


## Крок на n клітинок (n < 0 — відкат після зіткнення).
func step(n: int) -> void:
	if hero.tumbling and n > 0:
		return
	_pending += float(n)
	hero.hop()
	AudioMgr.sfx("hop")


func tick(delta: float) -> float:
	# авто-крок для малюків: білочка «підштовхує», якщо дитина довго не тисне
	if _auto_step_sec > 0.0 and not hero.tumbling:
		_idle += delta
		if _idle >= _auto_step_sec:
			_idle = 0.0
			step(1)
	if absf(_pending) < 0.001:
		return 0.0
	var rate := 1.0 / STEP_SEC
	var move := signf(_pending) * minf(absf(_pending), rate * delta)
	_pending -= move
	return move


func assist(o: Obstacle3D) -> void:
	# у young авто-допомога — це просто крок убік від дерева
	if o.action == "side" and o.lane == hero.lane:
		hero.change_lane(-1 if o.lane >= 0 else 1)


## У Стрибках «час до перешкоди» — це кількість кроків; вважаємо крок ≈ 1 с.
func seconds_to_hero(dist: float) -> float:
	return dist


## Допомога спрацьовує, коли перешкода — вже наступна клітинка (ще до тапу дитини).
func assist_distance() -> float:
	return 1.6


func wants_hint() -> bool:
	return _auto_step_sec <= 0.0
