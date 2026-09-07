## Базова стратегія руху. Кожен світ має свою: RunMode (Біг), HopMode (Стрибки), SlideMode (Хвиля).
## Спільний контракт: enter/exit, gesture, steer, tick (повертає, на скільки клітинок зсунути світ), assist.
class_name ModeBase
extends RefCounted

var run: Node            # Run3D (без class_name — головна сцена)
var hero: Hero3D
var world: Dictionary
var profile: Dictionary
var speed := 4.0         # клітинок/с, виставляє Run3D


func setup(r: Node, h: Hero3D, w: Dictionary, p: Dictionary) -> void:
	run = r
	hero = h
	world = w
	profile = p


func mode_id() -> String:
	return "base"


## Покроковий режим (Стрибки/Невагомість): світ рухається лише на тап, час до перешкоди — у кроках.
func is_stepwise() -> bool:
	return false


func enter() -> void:
	pass


func exit() -> void:
	pass


## Дискретний жест: "tap", "hold_start", "hold_end", "swipe_left/right/up/down".
func gesture(_kind: String, _pos: Vector2) -> void:
	pass


## Неперервне утримання (Хвиля): чи натиснуто і де.
func steer(_pressed: bool, _pos: Vector2) -> void:
	pass


## Скільки клітинок пройшов світ за кадр.
func tick(_delta: float) -> float:
	return 0.0


## Авто-допомога: подолати перешкоду за дитину (young). Обʼєкт — Obstacle3D.
func assist(_obstacle: Obstacle3D) -> void:
	pass


## Скільки секунд до перешкоди, що зʼявилась на відстані dist клітинок.
func seconds_to_hero(dist: float) -> float:
	return dist / max(0.5, speed)


## На якій відстані (клітинок) авто-допомога вже має діяти.
func assist_distance() -> float:
	return speed * 0.45


## Чи достатньо давно дитина нічого не робить, щоб гра підказала.
func wants_hint() -> bool:
	return true
