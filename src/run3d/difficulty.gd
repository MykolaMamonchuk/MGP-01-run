## Складність рівня одним числом 0..1 — щоб чанк міг вибрати свій layout, не знаючи, на якому
## він рівні (docs/tasks/reusable-chunks.md, крок 3).
##
## Джерело правди — `data/levels.json`. Тут НЕ заводиться паралельний механізм складності:
## усі п'ять доданків беруться з полів, які вже є в рівні. Нормувальні межі (константи нижче) —
## це діапазони, які ті поля справді мають у даних; `tests/test_difficulty.gd` стереже, щоб
## дані з них не вийшли мовчки.
##
## Ваги: швидкість і щільність разом важать 0.75, бо саме вони вирішують, скільки часу дитина
## має на реакцію. Номер рівня не входить у формулу взагалі — сам по собі він нічого не означає.
##
## Усе — чисті статичні функції: без вузлів і без стану, тож перевіряються числами без сцени.
class_name Difficulty
extends RefCounted

## Множник швидкості профілю: 1.0 на рівні 1 → 2.0 на рівні 17.
const SPEED_MIN := 1.0
const SPEED_MAX := 2.0
## Множник ІНТЕРВАЛУ між перешкодами: 1.4 (рідко) → 0.7 (щільно). Менше = важче, тож вісь обернена.
const DENSITY_EASY := 1.4
const DENSITY_HARD := 0.7
## Доріжок на трасі: 3, 5 або 7. Ширша дорога = довші перебіжки вбік.
const LANES_MIN := 3
const LANES_MAX := 7
## Різних типів перешкод на рівні; порожній список у даних означає «всі типи біому», тобто максимум.
const OBSTACLE_TYPES_MAX := 8
## Довжина рівня в секундах: витривалість, найслабший із доданків.
const DURATION_MIN_SEC := 80.0
const DURATION_MAX_SEC := 130.0

const W_SPEED := 0.40
const W_DENSITY := 0.35
const W_LANES := 0.10
const W_TYPES := 0.08
const W_DURATION := 0.07

## Допуск на краях діапазону layout'а: числа складності рахуються у float, і точний збіг із
## авторським 0.4 не має вирішуватись останнім бітом.
const EDGE_EPS := 0.0001


## Складність рівня, 0..1. Рівень 1 дає 0.02, рівень 17 — рівно 1.0.
static func of(level: Dictionary) -> float:
	var p := parts(level)
	var sum := W_SPEED * float(p["speed"]) \
		+ W_DENSITY * float(p["density"]) \
		+ W_LANES * float(p["lanes"]) \
		+ W_TYPES * float(p["types"]) \
		+ W_DURATION * float(p["duration"])
	return clampf(sum, 0.0, 1.0)


## П'ять осей складності окремо, кожна вже нормована в 0..1 — для тестів і діагностики:
## коли складність двох рівнів іде не туди, видно, яка саме вісь тягне.
static func parts(level: Dictionary) -> Dictionary:
	return {
		"speed": _norm(float(level.get("speed_mult", SPEED_MIN)), SPEED_MIN, SPEED_MAX),
		"density": _norm(float(level.get("density", DENSITY_EASY)), DENSITY_EASY, DENSITY_HARD),
		"lanes": _norm(float(widest_lanes(level)), float(LANES_MIN), float(LANES_MAX)),
		"types": _norm(float(obstacle_variety(level)), 0.0, float(OBSTACLE_TYPES_MAX)),
		"duration": _norm(float(level.get("duration_sec", DURATION_MIN_SEC)), DURATION_MIN_SEC, DURATION_MAX_SEC),
	}


## Найширша дорога рівня: рівень із фішкою «розширюється» (`lanes_to`) другу половину біжить уже широким.
static func widest_lanes(level: Dictionary) -> int:
	return maxi(int(level.get("lanes", LANES_MIN)), int(level.get("lanes_to", 0)))


## Скільки різних перешкод рівень може показати. Порожній (або відсутній) `obstacle_types`
## у даних означає «всі типи біому» — це максимум різноманітності, а не нуль.
static func obstacle_variety(level: Dictionary) -> int:
	var types: Array = level.get("obstacle_types", [])
	if types.is_empty():
		return OBSTACLE_TYPES_MAX
	return mini(types.size(), OBSTACLE_TYPES_MAX)


## Чи підходить layout із таким діапазоном складності. Обидва краї включні: сусідні діапазони
## ([0.0, 0.4] і [0.4, 1.0]) на стику перекриваються, і виграє той layout, що стоїть у списку
## першим. Перевернутий діапазон (min > max) — авторська помилка, і він не підходить нікому.
static func fits(range_min: float, range_max: float, difficulty: float) -> bool:
	if range_min > range_max:
		return false
	return difficulty >= range_min - EDGE_EPS and difficulty <= range_max + EDGE_EPS


## Значення value на відрізку [from, to] → 0..1. `to` може бути МЕНШИМ за `from` (обернена
## вісь, як щільність: 1.4 легко, 0.7 важко).
static func _norm(value: float, from: float, to: float) -> float:
	if is_equal_approx(from, to):
		return 0.0
	return clampf((value - from) / (to - from), 0.0, 1.0)
