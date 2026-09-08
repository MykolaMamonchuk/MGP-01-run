## Дім-діорама (GDD v1.4 §10): чисті функції Diorama і таблиця цін data/buildings.json.
extends GutTest

var _defs: Dictionary = {}


func before_all() -> void:
	var f := FileAccess.open(Diorama.DATA_PATH, FileAccess.READ)
	assert_not_null(f, "data/buildings.json читається")
	var parsed = JSON.parse_string(f.get_as_text())
	assert_eq(typeof(parsed), TYPE_DICTIONARY, "buildings.json — словник")
	_defs = (parsed as Dictionary).get("worlds", {})


# ---------- чисті функції ----------

func test_worlds_order() -> void:
	var order := Diorama.worlds_order()
	assert_eq(order.size(), 5, "п'ять світів")
	assert_eq(String(order[0]), "meadow", "починаємо з Лужка")
	assert_eq(String(order[4]), "clouds", "закінчуємо Хмаринками")
	# копія, а не сам масив: змінили — константа не постраждала
	order.append("nowhere")
	assert_eq(Diorama.worlds_order().size(), 5, "worlds_order повертає копію")


func test_plot_positions_grid() -> void:
	var pts := Diorama.plot_positions(Diorama.PLOTS, Diorama.CELL)
	assert_eq(pts.size(), Diorama.PLOTS, "дев'ять ділянок")
	assert_eq(pts[0], Vector3(-Diorama.CELL, 0.0, -Diorama.CELL), "перша — лівий дальній кут")
	assert_eq(pts[4], Vector3(0.0, 0.0, 0.0), "центральна — у центрі острова")
	assert_eq(pts[8], Vector3(Diorama.CELL, 0.0, Diorama.CELL), "остання — правий ближній кут")
	# усі різні й у межах сітки 3×3
	var seen := {}
	for p in pts:
		assert_false(seen.has(p), "ділянки не накладаються: %s" % str(p))
		seen[p] = true
		assert_lte(absf((p as Vector3).x), Diorama.CELL, "x у межах сітки")
		assert_lte(absf((p as Vector3).z), Diorama.CELL, "z у межах сітки")
	assert_eq(Diorama.plot_positions(0, 1.4).size(), 0, "нуль ділянок — порожньо")


func test_can_afford() -> void:
	assert_true(Diorama.can_afford(30, 30), "рівно вистачає")
	assert_true(Diorama.can_afford(30, 100), "вистачає з запасом")
	assert_false(Diorama.can_afford(100, 99), "не вистачає одного злитка")
	assert_true(Diorama.can_afford(0, 0), "безплатне доступне завжди")


func test_next_building_walks_the_price_ladder() -> void:
	var defs: Array = _defs.get("meadow", [])
	assert_gt(defs.size(), 0, "у Лужка є каталог")
	var first := Diorama.next_building(defs, [])
	assert_eq(String(first.get("voxel", "")), String((defs[0] as Dictionary)["voxel"]), "порожній острів — найдешевше")
	var owned := [String((defs[0] as Dictionary)["voxel"])]
	var second := Diorama.next_building(defs, owned)
	assert_eq(String(second.get("voxel", "")), String((defs[1] as Dictionary)["voxel"]), "далі — наступне за ціною")
	# усе збудовано — більше нічого не пропонуємо
	var all := []
	for d in defs:
		all.append(String((d as Dictionary)["voxel"]))
	assert_true(Diorama.next_building(defs, all).is_empty(), "усе збудовано — порожньо")
	assert_true(Diorama.next_building([], []).is_empty(), "порожній каталог — порожньо")


# ---------- дані ----------

func test_every_world_has_full_plot_set() -> void:
	for id in Diorama.worlds_order():
		var world_id := String(id)
		assert_true(_defs.has(world_id), "є каталог для світу %s" % world_id)
		var defs: Array = _defs.get(world_id, [])
		assert_eq(defs.size(), Diorama.PLOTS, "%s: рівно %d будівель (по одній на ділянку)" % [world_id, Diorama.PLOTS])
		var ids := {}
		var prev := -1
		var total := 0
		for d in defs:
			var def: Dictionary = d
			var bid := String(def.get("id", ""))
			assert_ne(bid, "", "%s: у будівлі є id" % world_id)
			assert_false(ids.has(bid), "%s: id «%s» не повторюється" % [world_id, bid])
			ids[bid] = true
			var price := int(def.get("price", 0))
			assert_gt(price, prev, "%s/%s: ціни зростають" % [world_id, bid])
			prev = price
			total += price
			assert_ne(String(def.get("name_uk", "")), "", "%s/%s: є підпис українською" % [world_id, bid])
			var voxel := String(def.get("voxel", ""))
			assert_true(FileAccess.file_exists("res://data/voxels/%s.json" % voxel),
				"%s/%s: воксель %s існує" % [world_id, bid, voxel])
		assert_eq(int((defs[0] as Dictionary)["price"]), 30, "%s: найдешевша будівля — 30 злитків" % world_id)
		assert_eq(int((defs[defs.size() - 1] as Dictionary)["price"]), 400, "%s: найдорожча — 400 злитків" % world_id)
		assert_between(total, 1500, 2000, "%s: увесь острів коштує 1500–2000 злитків" % world_id)


func test_building_voxels_are_small_enough() -> void:
	# будівля має вміщатись у клітинку 1,4 м і лишатись дешевою за мешами (≤ ~200 вокселів)
	var checked := {}
	for id in Diorama.worlds_order():
		for d in (_defs.get(String(id), []) as Array):
			var voxel := String((d as Dictionary).get("voxel", ""))
			if checked.has(voxel):
				continue
			checked[voxel] = true
			var def := VoxelBuilder.load_def("res://data/voxels/%s.json" % voxel)
			assert_false(def.is_empty(), "%s: опис читається" % voxel)
			var parsed := VoxelBuilder.parse(def)
			var cells: Dictionary = parsed["cells"]
			var dims: Vector3i = parsed["size"]
			assert_lte(cells.size(), 200, "%s: не більше 200 вокселів" % voxel)
			var s := float(def.get("size", 0.1))
			assert_lte(float(dims.x) * s, Diorama.CELL, "%s: вміщається в клітинку по x" % voxel)
			assert_lte(float(dims.z) * s, Diorama.CELL, "%s: вміщається в клітинку по z" % voxel)
	assert_gte(checked.size(), 9, "перевірили щонайменше дев'ять моделей")
