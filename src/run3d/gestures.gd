## Класифікація жестів одного пальця. Чисті функції — покриті тестами.
## Результати: "tap", "hold", "swipe_left", "swipe_right", "swipe_up", "swipe_down", "".
class_name Gestures
extends RefCounted

## Зсув у пікселях, після якого рух — це свайп, а не тремтіння пальця.
const SWIPE_PX := 60.0
## Тап коротший за цей час; довше без руху — утримання (присід/кермо).
const TAP_MAX_SEC := 0.25


## Напрямок свайпу за поточним зсувом пальця (або "" — ще не свайп).
static func swipe_dir(start: Vector2, current: Vector2) -> String:
	var d := current - start
	if d.length() < SWIPE_PX:
		return ""
	if absf(d.x) >= absf(d.y):
		return "swipe_right" if d.x > 0.0 else "swipe_left"
	return "swipe_down" if d.y > 0.0 else "swipe_up"


## Що сталося на відпусканні пальця. Якщо свайп уже спрацював — нічого ("").
static func on_release(held_sec: float, swiped: bool) -> String:
	if swiped:
		return ""
	return "tap" if held_sec <= TAP_MAX_SEC else "hold_end"


## Чи вже настав момент почати утримання (палець тримають нерухомо довше за тап).
static func hold_started(held_sec: float, swiped: bool, already_holding: bool) -> bool:
	return not swiped and not already_holding and held_sec > TAP_MAX_SEC


## Яка половина екрана натиснута — для керма у режимі «Хвиля». -1 ліва, +1 права.
static func steer_side(pos: Vector2, viewport_width: float) -> int:
	return -1 if pos.x < viewport_width * 0.5 else 1
