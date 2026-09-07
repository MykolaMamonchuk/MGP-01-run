## Крамниця (data/shop.json): капелюшки, окуляри, шарфики, спинка, сліди. Каталог, володіння, покупка за зірочки.
## Чисті функції (load_all/find/is_owned/try_buy/random_unowned) — для тестів; збереження — у SaveService.child():
##   "hats_owned": [id, …]         — куплені предмети всіх слотів (історична назва ключа)
##   "equip": {slot: id, …}        — що одягнуто в кожному слоті
class_name Shop
extends RefCounted

const PATH := "res://data/shop.json"
const SLOTS := ["hat", "face", "neck", "back", "trail"]

static var _cache: Array = []
static var _migrated := false


static func load_all() -> Array:
	if not _cache.is_empty():
		return _cache
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	_cache = parsed.get("items", []) if typeof(parsed) == TYPE_DICTIONARY else []
	return _cache


## Предмети одного слота (у порядку каталогу).
static func by_slot(all: Array, slot: String) -> Array:
	var out := []
	for it in all:
		if String(it.get("slot", "")) == slot:
			out.append(it)
	return out


static func find(all: Array, id: String) -> Dictionary:
	for it in all:
		if String(it.get("id", "")) == id:
			return it
	return {}


## Ідентифікатор «нічого» для слота (безплатний предмет).
static func none_id(slot: String) -> String:
	return slot + "_none"


## Чи є предмет у дитини: безплатні — завжди.
static func is_owned(def: Dictionary, owned: Array) -> bool:
	return int(def.get("price", 0)) <= 0 or owned.has(String(def.get("id", "")))


## Чиста функція покупки: повертає {ok, stars_left, owned}. Не чіпає збереження.
static func try_buy(def: Dictionary, stars: int, owned: Array) -> Dictionary:
	var id := String(def.get("id", ""))
	var price := int(def.get("price", 0))
	if is_owned(def, owned):
		return {"ok": true, "stars_left": stars, "owned": owned}
	if stars < price:
		return {"ok": false, "stars_left": stars, "owned": owned}
	var new_owned := owned.duplicate()
	new_owned.append(id)
	return {"ok": true, "stars_left": stars - price, "owned": new_owned}


## Випадковий ще не куплений предмет слота для колеса (або "" — усі є).
static func random_unowned(all: Array, owned: Array, rng: RandomNumberGenerator, slot: String = "hat") -> String:
	var pool := []
	for it in all:
		if String(it.get("slot", "")) != slot:
			continue
		if not is_owned(it, owned):
			pool.append(String(it["id"]))
	if pool.is_empty():
		return ""
	return pool[rng.randi() % pool.size()]


# ---------- збереження ----------

## Старий ключ "hat" → "equip".hat (одноразово за сесію).
static func _migrate() -> void:
	if _migrated:
		return
	_migrated = true
	var child := SaveService.child()
	if typeof(child.get("equip")) != TYPE_DICTIONARY:
		var eq := {}
		if child.has("hat"):
			var old := String(child["hat"])
			eq["hat"] = none_id("hat") if old == "none" or old == "" else old
		child["equip"] = eq
		SaveService.save_game()


static func owned() -> Array:
	var o = SaveService.child().get("hats_owned", [])
	return o if typeof(o) == TYPE_ARRAY else []


static func equip_map() -> Dictionary:
	_migrate()
	var e = SaveService.child().get("equip", {})
	return e if typeof(e) == TYPE_DICTIONARY else {}


## Що одягнуто в слоті (за замовчуванням — «нічого»).
static func equipped(slot: String) -> String:
	return String(equip_map().get(slot, none_id(slot)))


static func equip(slot: String, id: String) -> void:
	var e := equip_map()
	e[slot] = id
	SaveService.child()["equip"] = e
	SaveService.save_game()


## Купити й зберегти; повертає true при успіху. Зірочки списуються через SaveService.add_stars(-price).
static func buy(def: Dictionary) -> bool:
	var r := try_buy(def, SaveService.stars(), owned())
	if not bool(r["ok"]):
		return false
	var spent: int = SaveService.stars() - int(r["stars_left"])
	if spent > 0:
		SaveService.add_stars(-spent)
	SaveService.child()["hats_owned"] = r["owned"]
	SaveService.save_game()
	return true


## Подарувати предмет (колесо станції).
static func grant(id: String) -> void:
	var o := owned()
	if not o.has(id):
		o.append(id)
		SaveService.child()["hats_owned"] = o
		SaveService.save_game()


# ---------- герой ----------

## Одягнути один предмет на героя (приміряти теж). Порожній def — зняти слот.
static func apply_item(hero: Hero3D, slot: String, def: Dictionary) -> void:
	if slot == "hat":
		hero.set_hat(String(def.get("id", none_id("hat"))))
		return
	if slot == "trail":
		hero.set_accessory("trail", "", {"color": String(def.get("color", ""))})
		return
	hero.set_accessory(slot, String(def.get("voxel", "")))


## Одягнути на героя все, що збережено в "equip".
static func apply_to(hero: Hero3D) -> void:
	var all := load_all()
	for slot in SLOTS:
		apply_item(hero, String(slot), find(all, equipped(String(slot))))
