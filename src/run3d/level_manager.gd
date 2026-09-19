## Рівні (data/levels.json): поточний, прогрес, зірки 1–3, відкриття наступного, ціни рівнів (GDD v1.3 §3a).
## Рівень стає «грабельним», коли він куплений за зірочки І попередній пройдено (≥ 1 зірка). Рівень 1 — завжди куплений.
## Чисті функції — для тестів.
class_name LevelManager
extends RefCounted

## Ціна рівня не має перевищувати стільки середніх заробітків за пробіг (перевірка таблиці цін у тестах).
const AFFORDABLE_RUNS := 3

var levels: Array = []


func _init() -> void:
	levels = load_levels()


static func load_levels() -> Array:
	var f := FileAccess.open("res://data/levels.json", FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed.get("levels", []) if typeof(parsed) == TYPE_DICTIONARY else []


func count() -> int:
	return levels.size()


## Рівень за номером 1..N (або {} якщо нема).
func get_level(num: int) -> Dictionary:
	for l in levels:
		if int(l.get("id", 0)) == num:
			return l
	return {}


## Зірки рівня за GDD §3a: 1 — дійшов (завжди); 2 — ≥ 60% зірочок; 3 — ≥ 90% або без падінь.
static func stars_for(collected: int, total: int, tumbles: int) -> int:
	if total <= 0:
		return 3 if tumbles == 0 else 1
	var ratio := float(collected) / float(total)
	if ratio >= 0.9 or tumbles == 0:
		return 3
	if ratio >= 0.6:
		return 2
	return 1


## Скільки доріжок на рівні для профілю: young обмежений max_lanes (GDD §2).
static func lanes_for(level: Dictionary, profile: Dictionary, progress: float = 0.0) -> int:
	var lanes := int(level.get("lanes", 3))
	if level.has("lanes_to") and progress >= float(level.get("lanes_at", 0.5)):
		lanes = int(level["lanes_to"])
	var cap := int(profile.get("max_lanes", 99))
	return clampi(mini(lanes, cap), 3, 7)


## Найвищий рівень, до якого дійшли за зірками (без урахування покупки): наступний після максимального пройденого.
static func unlocked_max(level_stars: Dictionary, total: int) -> int:
	var best := 0
	for k in level_stars.keys():
		if int(level_stars[k]) > 0:
			best = maxi(best, int(String(k)))
	return clampi(best + 1, 1, total)


# ---------- ціни й відкриття (GDD v1.3 §3a) ----------

## Чи є num у списку куплених (зі збереження числа можуть прийти як float).
static func _in_bought(bought: Array, num: int) -> bool:
	for b in bought:
		if int(b) == num:
			return true
	return false


## Стан вузла мапи: "open" — можна грати; "buyable" — попередній пройдено, лишилось купити; "locked" — ще рано.
static func open_state(num: int, level_stars: Dictionary, bought: Array) -> String:
	var prev_done := num == 1 or int(level_stars.get(str(num - 1), 0)) > 0
	var is_b := num == 1 or _in_bought(bought, num)
	if prev_done and is_b:
		return "open"
	if prev_done:
		return "buyable"
	return "locked"


## Найвищий відкритий (куплений і доступний) рівень 1..total.
static func unlocked_open(level_stars: Dictionary, bought: Array, total: int) -> int:
	var best := 1
	for n in range(1, total + 1):
		if open_state(n, level_stars, bought) == "open":
			best = n
	return clampi(best, 1, maxi(1, total))


## Таблиця цін «по кишені»: кожна ціна ≤ AFFORDABLE_RUNS × середній заробіток за пробіг.
static func price_table_is_affordable(prices: Array, avg_run_income: int) -> bool:
	for p in prices:
		if int(p) > AFFORDABLE_RUNS * avg_run_income:
			return false
	return true


func price_of(num: int) -> int:
	return int(get_level(num).get("price", 0))


## Усі ціни у порядку рівнів.
func prices() -> Array:
	var out := []
	for l in levels:
		out.append(int(l.get("price", 0)))
	return out


# ---------- збереження ----------

func saved_stars() -> Dictionary:
	var d = SaveService.child().get("level_stars", {})
	return d if typeof(d) == TYPE_DICTIONARY else {}


func saved_bought() -> Array:
	var a = SaveService.child().get("levels_bought", [])
	return a if typeof(a) == TYPE_ARRAY else []


func stars_of(num: int) -> int:
	return int(saved_stars().get(str(num), 0))


func is_bought(num: int) -> bool:
	return num == 1 or _in_bought(saved_bought(), num)


func open_state_of(num: int) -> String:
	return open_state(num, saved_stars(), saved_bought())


func is_open(num: int) -> bool:
	return open_state_of(num) == "open"


func can_buy(num: int) -> bool:
	return open_state_of(num) == "buyable"


## Купити рівень за зірочки: списує ціну, записує, зберігає; emit star_collected(0) оновлює лічильник у HUD.
func buy(num: int) -> bool:
	if not can_buy(num):
		return false
	var price := price_of(num)
	if SaveService.stars() < price:
		return false
	SaveService.add_stars(-price)
	var b := saved_bought()
	b.append(num)
	SaveService.child()["levels_bought"] = b
	SaveService.save_game()
	Events.star_collected.emit(0)
	return true


## Найвищий рівень, у який можна грати (куплений і попередній пройдено).
func unlocked() -> int:
	return unlocked_open(saved_stars(), saved_bought(), count())


func current() -> int:
	var c := int(SaveService.child().get("level", 1))
	return clampi(c, 1, unlocked())


func set_current(num: int) -> void:
	SaveService.child()["level"] = clampi(num, 1, count())


## Записати результат; повертає true, якщо це новий рекорд зірок.
func complete(num: int, stars: int) -> bool:
	var d := saved_stars()
	var prev := int(d.get(str(num), 0))
	d[str(num)] = maxi(prev, stars)
	SaveService.child()["level_stars"] = d
	SaveService.child()["level"] = mini(num + 1, count())
	SaveService.save_game()
	return stars > prev


## Світи у порядку появи на мапі + діапазони рівнів (для островів).
func islands() -> Array:
	var out := []
	for l in levels:
		var w := String(l.get("world", ""))
		if out.is_empty() or out[-1]["world"] != w:
			out.append({"world": w, "from": int(l["id"]), "to": int(l["id"])})
		else:
			out[-1]["to"] = int(l["id"])
	return out
