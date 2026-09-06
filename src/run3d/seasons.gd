## Сезон за календарем (data/seasons.json). Чиста функція pick(month) — для тестів.
class_name Seasons
extends RefCounted


static func load_all() -> Array:
	var f := FileAccess.open("res://data/seasons.json", FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed.get("seasons", []) if typeof(parsed) == TYPE_DICTIONARY else []


static func pick(seasons: Array, month: int) -> Dictionary:
	for s in seasons:
		# JSON дає float (12.0), has(int) не збігається — порівнюємо як int
		for m in (s.get("months", []) as Array):
			if int(m) == month:
				return s
	return {}


static func current() -> Dictionary:
	return pick(load_all(), int(Time.get_date_dict_from_system().get("month", 6)))
