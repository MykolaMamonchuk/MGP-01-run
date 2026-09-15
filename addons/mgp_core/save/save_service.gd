## Локальне збереження (user://save.json). Жодних персональних даних дитини.
## Autoload: SaveService.
extends Node

const SAVE_PATH := "user://save.json"
const SCHEMA_VERSION := 1

## Версія НУМЕРАЦІЇ РІВНІВ у збереженні (окремо від schema: міняється тоді, коли переставили світи).
## v2 (EDD, docs/ECONOMY.md §2): світи стали Пляж 9–11 · Місто 12–14 · Хмаринки 15–17 замість
## Пляж 9–12 · Місто 13–15 · Хмаринки 16–17. Пляжний «Захід сонця» (старий 12) прибрано, решта
## пізніх рівнів з'їхала на один номер униз, а 17-й — новий фінал.
const LEVELS_VERSION := 2
## Старий номер → новий. Ключі йдуть за зростанням: 13→12 не затирає 12, бо зірки зливаємо через maxi.
const LEVELS_V2_REMAP := {"13": "12", "14": "13", "15": "14", "16": "15", "17": "16"}

var data: Dictionary = {}

func _ready() -> void:
	load_game()

func default_data() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"active_child": 0,
		"children": [ _default_child("Дитина 1") ],
		"settings": {"music": true, "sfx": true, "voice": true, "lang": "uk", "session_minutes": 10},
		"full_game": false,
	}

func _default_child(child_name: String) -> Dictionary:
	return {
		"name": child_name,
		"avatar_hero": "puf",
		"profile": "young",
		"profile_locked": false,
		"stars": 0,
		"feathers": 0,
		"unlocked_heroes": ["puf"],
		"hero_stage": {"puf": 1},
		"hero": "puf",
		"homes": [],
		"levels_version": LEVELS_VERSION,
	}

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		data = default_data()
		save_game()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	data = parsed if typeof(parsed) == TYPE_DICTIONARY else default_data()
	_migrate()

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

## Міграція + валідація форми збереження. Якщо файл поламаний — відкат до дефолту.
func _migrate() -> void:
	var d := default_data()
	# children — непорожній масив словників
	var children = data.get("children", null)
	if typeof(children) != TYPE_ARRAY or (children as Array).is_empty():
		data = d
		save_game()
		return
	for c in children:
		if typeof(c) != TYPE_DICTIONARY:
			data = d
			save_game()
			return
		# старий ключ "current_hero" → "hero" (значення переносимо, якщо "hero" ще нема)
		if (c as Dictionary).has("current_hero"):
			if not (c as Dictionary).has("hero"):
				c["hero"] = String(c["current_hero"])
			(c as Dictionary).erase("current_hero")
	# active_child — індекс у межах масиву
	data["active_child"] = clampi(int(data.get("active_child", 0)), 0, (children as Array).size() - 1)
	# settings — словник із дефолтами
	if typeof(data.get("settings", null)) != TYPE_DICTIONARY:
		data["settings"] = (d["settings"] as Dictionary).duplicate()
	else:
		var defaults: Dictionary = d["settings"]
		for k in defaults:
			if not (data["settings"] as Dictionary).has(k):
				data["settings"][k] = defaults[k]
	# full_game — булеве
	data["full_game"] = bool(data.get("full_game", false))
	data["schema"] = SCHEMA_VERSION
	migrate_levels_v2()
	save_game()


# ---------- міграція нумерації рівнів (EDD §2) ----------

## Перенумерувати ключі «номер рівня → значення» за таблицею remap.
## Зірки зливаємо через maxi: якщо і старий, і новий номер уже щось мали, лишається кращий результат.
## Чиста функція — саме її перевіряють тести.
static func remap_level_stars(src: Dictionary, remap: Dictionary) -> Dictionary:
	var out := {}
	var keys := src.keys()
	keys.sort_custom(func(a, b): return int(String(a)) < int(String(b)))
	for k in keys:
		var key := String(k)
		var dst := String(remap.get(key, key))
		out[dst] = maxi(int(out.get(dst, 0)), int(src[k]))
	return out


## Те саме для списку куплених рівнів (числа зі збереження можуть прийти як float).
## Чиста функція.
static func remap_bought(src: Array, remap: Dictionary) -> Array:
	var seen := {}
	for b in src:
		var key := str(int(b))
		seen[int(String(remap.get(key, key)))] = true
	var out := seen.keys()
	out.sort()
	return out


## Одноразова міграція нумерації рівнів після перестановки світів.
## Прапорець levels_version стоїть у КОЖНІЙ дитині: профілі мігрують незалежно.
## Повертає true, якщо хоч одну дитину справді перенумеровано.
func migrate_levels_v2() -> bool:
	var changed := false
	for c in data.get("children", []):
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var kid: Dictionary = c
		if int(kid.get("levels_version", 1)) >= LEVELS_VERSION:
			continue
		var stars = kid.get("level_stars", {})
		if typeof(stars) == TYPE_DICTIONARY:
			kid["level_stars"] = remap_level_stars(stars, LEVELS_V2_REMAP)
		var bought = kid.get("levels_bought", [])
		if typeof(bought) == TYPE_ARRAY:
			kid["levels_bought"] = remap_bought(bought, LEVELS_V2_REMAP)
		# поточний рівень теж їде за таблицею, інакше дитина відкриє мапу не там, де була
		var cur := str(int(kid.get("level", 1)))
		kid["level"] = int(String(LEVELS_V2_REMAP.get(cur, cur)))
		kid["levels_version"] = LEVELS_VERSION
		changed = true
	return changed

# --- зручні доступи ---
func child() -> Dictionary:
	return data["children"][int(data["active_child"])]

func add_stars(n: int) -> void:
	child()["stars"] = int(child()["stars"]) + n

func stars() -> int:
	return int(child()["stars"])

func setting(key: String, default = null):
	return data["settings"].get(key, default)

func set_setting(key: String, value) -> void:
	data["settings"][key] = value
	save_game()
