## Рівні (data/levels.json): поточний, прогрес, зірки 1–3, відкриття наступного. Чисті функції — для тестів.
class_name LevelManager
extends RefCounted

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


## Найвищий відкритий рівень (1..N): наступний після максимального пройденого.
static func unlocked_max(level_stars: Dictionary, total: int) -> int:
	var best := 0
	for k in level_stars.keys():
		if int(level_stars[k]) > 0:
			best = maxi(best, int(String(k)))
	return clampi(best + 1, 1, total)


# ---------- збереження ----------

func saved_stars() -> Dictionary:
	var d = SaveService.child().get("level_stars", {})
	return d if typeof(d) == TYPE_DICTIONARY else {}


func stars_of(num: int) -> int:
	return int(saved_stars().get(str(num), 0))


func unlocked() -> int:
	return unlocked_max(saved_stars(), count())


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
