## Крамниця (data/shop.json): капелюшки, окуляри, шарфики, спинка, сліди. Каталог, володіння, покупка за зірочки.
## GDD v1.3 §5: предмети купуються й одягаються ОКРЕМО ДЛЯ КОЖНОГО ГЕРОЯ.
## Чисті функції (load_all/find/is_owned/try_buy/random_unowned/migrate_child) — для тестів; збереження — у SaveService.child():
##   "hero_inventory": {hero_id: [item_id, …]}     — куплене кожним героєм
##   "hero_equip":     {hero_id: {slot: item_id}}  — що одягнуто на кожному герої
## Старі спільні ключі "hats_owned" / "equip" / "hat" один раз переносяться поточному герою й видаляються.
## hero_id "" у будь-якому виклику означає поточного героя (child()["hero"], типово "puf").
class_name Shop
extends RefCounted

const PATH := "res://data/shop.json"
const SLOTS := ["hat", "face", "neck", "back", "trail"]
const KEY_INV := "hero_inventory"
const KEY_EQUIP := "hero_equip"

static var _cache: Array = []
## Для якої дитини (active_child) міграцію вже зроблено; −1 — ще ні.
static var _migrated_for := -1


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


## Чи є предмет у списку куплених: безплатні («*_none») — завжди, у всіх героїв.
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


# ---------- міграція (чиста) ----------

## Переносить старі спільні ключі "hats_owned"/"equip"/"hat" герою hero_id і видаляє їх; створює порожні
## "hero_inventory"/"hero_equip", якщо їх нема. Повертає true, якщо словник змінено.
static func migrate_child(child: Dictionary, hero_id: String) -> bool:
	var changed := false
	if typeof(child.get(KEY_INV)) != TYPE_DICTIONARY:
		child[KEY_INV] = {}
		changed = true
	if typeof(child.get(KEY_EQUIP)) != TYPE_DICTIONARY:
		child[KEY_EQUIP] = {}
		changed = true
	# куплене
	if child.has("hats_owned"):
		var old = child["hats_owned"]
		if typeof(old) == TYPE_ARRAY:
			var inv: Array = _list(child[KEY_INV], hero_id)
			for id in old:
				if not inv.has(String(id)):
					inv.append(String(id))
			child[KEY_INV][hero_id] = inv
		child.erase("hats_owned")
		changed = true
	# одягнуте: "equip" має пріоритет над найстарішим "hat"
	if child.has("equip") or child.has("hat"):
		var eq := {}
		if typeof(child.get("equip")) == TYPE_DICTIONARY:
			eq = (child["equip"] as Dictionary).duplicate()
		if child.has("hat") and not eq.has("hat"):
			var old_hat := String(child["hat"])
			eq["hat"] = none_id("hat") if old_hat == "none" or old_hat == "" else old_hat
		var cur: Dictionary = _map(child[KEY_EQUIP], hero_id)
		for s in eq.keys():
			if not cur.has(s):
				cur[s] = eq[s]
		child[KEY_EQUIP][hero_id] = cur
		child.erase("equip")
		child.erase("hat")
		changed = true
	return changed


## Копія списку з словника (або порожній).
static func _list(d: Dictionary, key: String) -> Array:
	var v = d.get(key, [])
	return (v as Array).duplicate() if typeof(v) == TYPE_ARRAY else []


## Копія словника з словника (або порожній).
static func _map(d: Dictionary, key: String) -> Dictionary:
	var v = d.get(key, {})
	return (v as Dictionary).duplicate() if typeof(v) == TYPE_DICTIONARY else {}


# ---------- збереження ----------

## Поточний герой дитини (кому дістаються покупки за замовчуванням).
static func current_hero() -> String:
	return String(SaveService.child().get("hero", "puf"))


static func _hero(hero_id: String) -> String:
	return current_hero() if hero_id == "" else hero_id


## Одноразова міграція старих ключів у поточного героя — окремо для кожної дитини (зміна active_child — знову).
static func _migrate() -> void:
	var active := int(SaveService.data.get("active_child", 0))
	if _migrated_for == active:
		return
	_migrated_for = active
	if migrate_child(SaveService.child(), current_hero()):
		SaveService.save_game()


static func _inventory() -> Dictionary:
	_migrate()
	var inv = SaveService.child().get(KEY_INV, {})
	if typeof(inv) != TYPE_DICTIONARY:
		inv = {}
		SaveService.child()[KEY_INV] = inv
	return inv


static func _equips() -> Dictionary:
	_migrate()
	var e = SaveService.child().get(KEY_EQUIP, {})
	if typeof(e) != TYPE_DICTIONARY:
		e = {}
		SaveService.child()[KEY_EQUIP] = e
	return e


## Куплене героєм (копія списку). "" — поточний герой.
static func owned(hero_id: String = "") -> Array:
	return _list(_inventory(), _hero(hero_id))


## Чи є предмет у цього героя (безплатні — у всіх).
static func is_owned_by(def: Dictionary, hero_id: String = "") -> bool:
	return is_owned(def, owned(hero_id))


## Одягнуте героєм за слотами (копія).
static func equip_map(hero_id: String = "") -> Dictionary:
	return _map(_equips(), _hero(hero_id))


## Що одягнуто в слоті героя (за замовчуванням — «нічого»).
static func equipped(hero_id: String, slot: String) -> String:
	return String(equip_map(hero_id).get(slot, none_id(slot)))


static func equip(hero_id: String, slot: String, id: String) -> void:
	var hid := _hero(hero_id)
	var e := equip_map(hid)
	e[slot] = id
	_equips()[hid] = e
	SaveService.save_game()


## Купити герою й зберегти; повертає true при успіху. Зірочки списуються через SaveService.add_stars(-price).
static func buy(def: Dictionary, hero_id: String = "") -> bool:
	var hid := _hero(hero_id)
	var r := try_buy(def, SaveService.stars(), owned(hid))
	if not bool(r["ok"]):
		return false
	var spent: int = SaveService.stars() - int(r["stars_left"])
	if spent > 0:
		SaveService.add_stars(-spent)
	_inventory()[hid] = r["owned"]
	SaveService.save_game()
	return true


## Подарувати предмет герою (колесо станції).
static func grant(id: String, hero_id: String = "") -> void:
	var hid := _hero(hero_id)
	var o := owned(hid)
	if not o.has(id):
		o.append(id)
		_inventory()[hid] = o
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


## Одягнути на героя все, що збережено для НЬОГО (hero.hero_id). Чуже спорядження не чіпає.
static func apply_to(hero: Hero3D) -> void:
	var all := load_all()
	var hid := String(hero.hero_id)
	for slot in SLOTS:
		apply_item(hero, String(slot), find(all, equipped(hid, String(slot))))
