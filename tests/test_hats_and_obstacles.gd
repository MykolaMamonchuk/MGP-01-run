## Крамниця (економіка: капелюшки + аксесуари + сліди) і каталог перешкод (≥ 8 на біом, ≥ 2 «присід», анімації, вокселі існують).
extends GutTest

const RunScript := preload("res://src/run3d/run3d.gd")
const VALID_ACTIONS := ["jump", "duck", "any", "side", "gap", "boost", "rail", "wind"]
const VALID_ANIMS := ["", "sway", "spin", "bob", "breathe", "bounce", "flap", "pulse", "drip", "wobble"]

var _items: Array = []
var _rng := RandomNumberGenerator.new()
var _child_backup: Dictionary = {}


func before_each() -> void:
	_items = Shop.load_all()
	_rng.seed = 3
	# тести крамниці пишуть у SaveService — зберігаємо профіль дитини й повертаємо після тесту
	_child_backup = SaveService.child().duplicate(true)


func after_each() -> void:
	var idx := int(SaveService.data["active_child"])
	SaveService.data["children"][idx] = _child_backup
	SaveService.save_game()


## Чистий профіль для тестів крамниці: без старих ключів, зі зірочками, поточний герой — hero.
func _fresh_child(hero: String, stars: int) -> Dictionary:
	var c := SaveService.child()
	c["hero"] = hero
	c["stars"] = stars
	c["hero_inventory"] = {}
	c["hero_equip"] = {}
	c.erase("hats_owned")
	c.erase("equip")
	c.erase("hat")
	return c


func test_shop_data() -> void:
	assert_gte(_items.size(), 20, "≥ 20 предметів у крамниці")
	var free := 0
	var ids := {}
	var per_slot := {}
	for it in _items:
		assert_true(it.has("id") and it.has("name_uk") and it.has("price") and it.has("slot"), "поля предмета")
		var id := String(it["id"])
		assert_false(ids.has(id), "%s: id унікальний" % id)
		ids[id] = true
		var slot := String(it["slot"])
		assert_true(Shop.SLOTS.has(slot), "%s: слот валідний" % id)
		per_slot[slot] = int(per_slot.get(slot, 0)) + 1
		if int(it["price"]) <= 0:
			free += 1
			assert_eq(id, Shop.none_id(slot), "безплатний — це «нічого» слота")
		var v := String(it.get("voxel", ""))
		if v != "":
			assert_true(FileAccess.file_exists("res://data/voxels/%s.json" % v), "%s: воксель існує" % id)
		if slot == "trail" and int(it["price"]) > 0:
			assert_true(String(it.get("color", "")).begins_with("#"), "%s: слід має колір" % id)
	assert_eq(free, 5, "рівно п'ять безплатних (одне «нічого» на слот)")
	for s in Shop.SLOTS:
		assert_gte(int(per_slot.get(s, 0)), 2, "%s: у слоті є що обрати" % s)
	assert_gte(Shop.by_slot(_items, "hat").size(), 11, "усі 11 капелюшків збережено")


func test_hats_wrapper_is_hat_slot_only() -> void:
	var hats := Hats.load_all()
	assert_gte(hats.size(), 11)
	for h in hats:
		assert_eq(String(h["slot"]), "hat")
	assert_eq(String(Hats.find(hats, "none").get("id", "")), "hat_none", "старий id none → hat_none")
	assert_eq(String(Hats.find(hats, "cap").get("voxel", "")), "hat_cap")


func test_buy_rules() -> void:
	var cap := {"id": "cap", "price": 60}
	assert_false(Shop.try_buy(cap, 59, [])["ok"], "не вистачає зірочок")
	var r := Shop.try_buy(cap, 60, [])
	assert_true(r["ok"])
	assert_eq(int(r["stars_left"]), 0)
	assert_true((r["owned"] as Array).has("cap"))
	var again := Shop.try_buy(cap, 5, ["cap"])
	assert_true(again["ok"], "уже куплений — безплатно")
	assert_eq(int(again["stars_left"]), 5)
	assert_true(Shop.is_owned({"id": "hat_none", "price": 0}, []), "безплатний — завжди є")


func test_random_unowned_by_slot() -> void:
	var owned := []
	for it in _items:
		if int(it["price"]) > 0 and String(it["id"]) != "crown":
			owned.append(String(it["id"]))
	assert_eq(Shop.random_unowned(_items, owned, _rng), "crown", "лишилась тільки корона (слот hat)")
	assert_eq(Shop.random_unowned(_items, owned, _rng, "face"), "", "окуляри всі куплені — порожньо")
	assert_eq(Shop.random_unowned(_items, [], _rng, "trail").begins_with("trail_"), true, "слід — зі слота trail")
	owned.append("crown")
	assert_eq(Shop.random_unowned(_items, owned, _rng), "", "усе куплено — порожньо")


func test_shop_is_per_hero() -> void:
	var c := _fresh_child("puf", 500)
	var cap := Shop.find(_items, "cap")
	assert_true(Shop.buy(cap, "puf"), "Пуф купує кепку")
	assert_eq(SaveService.stars(), 440, "ціна списана")
	assert_true(Shop.is_owned_by(cap, "puf"))
	assert_false(Shop.is_owned_by(cap, "vushko"), "куплене Пуфом не з'являється у Вушка")
	assert_true(Shop.owned("puf").has("cap"))
	assert_false(Shop.owned("vushko").has("cap"))
	assert_true(Shop.is_owned_by(Shop.find(_items, "hat_none"), "vushko"), "безплатне «нічого» — у всіх")
	# одягання теж окреме
	Shop.equip("puf", "hat", "cap")
	assert_eq(Shop.equipped("puf", "hat"), "cap")
	assert_eq(Shop.equipped("vushko", "hat"), "hat_none", "інший герой — без капелюшка")
	# подарунок колеса — конкретному герою
	Shop.grant("crown", "vushko")
	assert_true(Shop.owned("vushko").has("crown"))
	assert_false(Shop.owned("puf").has("crown"))
	# ключі збереження (GDD v1.3 §5)
	assert_true(c.has("hero_inventory") and c.has("hero_equip"), "нові ключі є")
	assert_false(c.has("hats_owned") or c.has("equip") or c.has("hat"), "старих спільних ключів нема")
	assert_eq((c["hero_inventory"] as Dictionary)["puf"], ["cap"])
	assert_eq((c["hero_inventory"] as Dictionary)["vushko"], ["crown"])
	assert_eq(((c["hero_equip"] as Dictionary)["puf"] as Dictionary)["hat"], "cap")
	# без hero_id — поточний герой (child.hero)
	c["hero"] = "vushko"
	assert_true(Shop.owned().has("crown"), "Shop.owned() — поточний герой")
	assert_true(Hats.owned().has("crown"), "Hats.owned() — теж поточний")
	Hats.equip("crown")
	assert_eq(Hats.equipped(), "crown")
	assert_eq(Shop.equipped("vushko", "hat"), "crown")
	assert_eq(Shop.equipped("puf", "hat"), "cap", "Пуф лишився в кепці")
	c["stars"] = 10
	assert_false(Shop.buy(Shop.find(_items, "halo"), "sonia"), "не вистачає — не купує")
	assert_false(Shop.owned("sonia").has("halo"))
	assert_eq(SaveService.stars(), 10, "зірочки не списані")


func test_migrates_shared_keys_to_current_hero() -> void:
	var child := {"hero": "khvostyk", "hats_owned": ["cap", "bow"], "equip": {"hat": "cap", "face": "glasses"}, "hat": "bow"}
	assert_true(Shop.migrate_child(child, "khvostyk"), "були старі ключі — змінено")
	assert_false(child.has("hats_owned"))
	assert_false(child.has("equip"))
	assert_false(child.has("hat"))
	assert_eq(child["hero_inventory"]["khvostyk"], ["cap", "bow"], "куплене перейшло поточному герою")
	assert_eq(child["hero_equip"]["khvostyk"]["hat"], "cap", "«equip» важливіший за найстаріший «hat»")
	assert_eq(child["hero_equip"]["khvostyk"]["face"], "glasses")
	assert_false((child["hero_inventory"] as Dictionary).has("puf"), "іншим героям нічого не дісталось")
	assert_false(Shop.migrate_child(child, "khvostyk"), "повторно — нічого не змінюється")
	# найстаріший формат: лише "hat": "none"
	var old := {"hat": "none"}
	assert_true(Shop.migrate_child(old, "puf"))
	assert_eq(old["hero_equip"]["puf"]["hat"], "hat_none", "none → hat_none")
	assert_true((old["hero_inventory"] as Dictionary).is_empty())
	# порожній профіль — лише створюються порожні словники
	var empty := {}
	assert_true(Shop.migrate_child(empty, "puf"))
	assert_true(empty.has("hero_inventory") and empty.has("hero_equip"))
	assert_false(Shop.migrate_child(empty, "puf"))


func test_voxel_icon_front_elevation() -> void:
	var def := VoxelBuilder.load_def("res://data/voxels/hat_cap.json")
	var rects := Icons.VoxelIcon.front_elevation(def)
	assert_gt(rects.size(), 0, "кепка має видимі клітинки спереду")
	var found := false
	for r in rects:
		assert_true(r.has("x") and r.has("y") and r.has("color"))
		if int(r["x"]) == 0 and int(r["y"]) == 0:
			found = true
			assert_eq(r["color"], Color("#1E88E5"), "передній ряд нижнього шару — темно-синій козирок")
	assert_true(found, "клітинка (0,0) є у проєкції")
	# по одній клітинці на стовпчик (x, y) — глибина сплющена
	var seen := {}
	for r in rects:
		var key := "%d:%d" % [int(r["x"]), int(r["y"])]
		assert_false(seen.has(key), "стовпчик %s лише раз" % key)
		seen[key] = true
	assert_eq(Icons.VoxelIcon.front_elevation({}).size(), 0, "порожній опис — порожньо")


func test_map_smooth_path() -> void:
	var pts := MapScreen.node_positions(17, Vector2(1280, 720))
	var path := MapScreen.MapCanvas.smooth_path(pts, 8)
	assert_eq(path.size(), 16 * 8 + 1, "8 відрізків на проміжок + остання точка")
	assert_eq(path[0], pts[0])
	assert_eq(path[-1], pts[16])
	assert_eq(path[8], pts[1], "крива проходить через вузли")


func test_each_biome_has_eight_animated_obstacles_with_two_ducks() -> void:
	var worlds: Dictionary = RunScript.load_worlds()
	for id in worlds.keys():
		var obs: Dictionary = worlds[id]["obstacles"]
		assert_gte(obs.size(), 8, "%s: ≥ 8 перешкод (GDD Додаток А)" % id)
		var ducks := 0
		var animated := 0
		for k in obs.keys():
			var o: Dictionary = obs[k]
			assert_true(VALID_ACTIONS.has(o.get("action", "")), "%s/%s: дія валідна" % [id, k])
			assert_true(VALID_ANIMS.has(o.get("anim", "")), "%s/%s: анімація валідна" % [id, k])
			assert_true(FileAccess.file_exists("res://data/voxels/%s.json" % String(o.get("voxel", k))), "%s/%s: воксель існує" % [id, k])
			if o.get("action", "") == "duck":
				ducks += 1
				assert_gt(float(o.get("y", 0.0)), 0.6, "%s/%s: «присід» висить над дорогою" % [id, k])
			if String(o.get("anim", "")) != "" or bool(o.get("moves", false)):
				animated += 1
		assert_gte(ducks, 2, "%s: ≥ 2 перешкоди «присід» (зверху)" % id)
		assert_gte(animated, 5, "%s: більшість перешкод анімовані" % id)


func test_wheel_sector_math() -> void:
	var n := 8
	for i in range(n):
		var mid := TAU * (float(i) + 0.5) / float(n)
		var angle := -PI * 0.5 - mid + TAU * 3.0
		assert_eq(WheelLayer.sector_at(angle, n), i, "сектор %d під стрілкою" % i)
