## Локальне збереження (user://save.json). Жодних персональних даних дитини.
## Autoload: SaveService.
extends Node

const SAVE_PATH := "user://save.json"
const SCHEMA_VERSION := 1

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
	save_game()

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
