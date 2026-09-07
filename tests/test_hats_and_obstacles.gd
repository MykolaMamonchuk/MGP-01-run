## Крамниця (економіка: капелюшки + аксесуари + сліди) і каталог перешкод (≥ 8 на біом, ≥ 2 «присід», анімації, вокселі існують).
extends GutTest

const RunScript := preload("res://src/run3d/run3d.gd")
const VALID_ACTIONS := ["jump", "duck", "any", "side", "gap", "boost", "rail", "wind"]
const VALID_ANIMS := ["", "sway", "spin", "bob", "breathe", "bounce", "flap", "pulse", "drip", "wobble"]

var _items: Array = []
var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_items = Shop.load_all()
	_rng.seed = 3


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
