## Вокселі арт-бази v1.5 (етап 6, агент вокселів): усі імена зі списку є, парсяться,
## мають хоч один воксель, без дублів координат, палітра ≤ 6 кольорів, розміри в межах брифу.
extends GutTest

## Дрібні пропси узбіччя: footprint ≤ 0,6 м, ≤ 90 вокселів.
const SMALL_PROPS := [
	"crate", "barrel", "mushroom_red", "bush_cube", "fence_low", "lantern_post",
	"signpost", "well", "hay_bale", "rock_grey", "flower_yellow", "flower_pink",
	"pumpkin", "kiosk", "awning_stall",
]
## Дерева: висота 0,9–1,4 м.
const TREES := ["tree_round", "pine_3", "palm"]
## Середні пропси (пляжна парасолька): купол ширший за стовпчик — footprint ≤ 1 м, ≤ 160 вокселів.
const MEDIUM_PROPS := ["umbrella_stripe"]
## Будиночки: 1,6–2,2 м ширина, 1,8–2,6 м висота, ≤ 260 вокселів.
## cloud_house сюди не входить: він також фігурує в data/buildings.json (дім-діорама),
## де діє суворіший ліміт test_diorama.gd — ділянка 1,4 м і ≤ 200 вокселів (див. окремий тест нижче).
const HOUSES := [
	"house_red", "house_terra", "house_teal", "house_straw",
	"city_house_a", "city_house_b", "beach_hut",
]

const ALL_NAMES := [
	"crate", "barrel", "mushroom_red", "bush_cube", "tree_round", "pine_3", "fence_low",
	"lantern_post", "signpost", "house_red", "house_terra", "house_teal", "house_straw",
	"awning_stall", "bridge_plank", "well", "hay_bale", "rock_grey", "flower_yellow",
	"flower_pink", "pumpkin", "palm", "beach_hut", "umbrella_stripe", "cloud_house",
	"city_house_a", "city_house_b", "kiosk",
]


## Скільки символів (не '.'/' ') у сирих layers — для перевірки на дублі координат
## (parse() кладе клітинки у Dictionary за координатою, тож дубль тихо перезаписав би сусіда).
func _raw_symbol_count(def: Dictionary) -> int:
	var n := 0
	var layers: Array = def.get("layers", [])
	for rows in layers:
		for row in (rows as Array):
			var s := String(row)
			for i in range(s.length()):
				var ch := s[i]
				if ch != "." and ch != " ":
					n += 1
	return n


func _bounds_m(cells: Dictionary, size: float) -> Vector3:
	var xs := []
	var ys := []
	var zs := []
	for p in cells.keys():
		var v: Vector3i = p
		xs.append(v.x)
		ys.append(v.y)
		zs.append(v.z)
	var w: float = (int(xs.max()) - int(xs.min()) + 1) * size
	var h: float = (int(ys.max()) - int(ys.min()) + 1) * size
	var d: float = (int(zs.max()) - int(zs.min()) + 1) * size
	return Vector3(w, h, d)


func test_all_names_exist_and_parse() -> void:
	for n in ALL_NAMES:
		var path := "res://data/voxels/%s.json" % n
		assert_true(FileAccess.file_exists(path), "%s: файл існує" % n)
		var def := VoxelBuilder.load_def(path)
		assert_false(def.is_empty(), "%s: валідний JSON" % n)


func test_at_least_one_voxel_and_no_duplicate_coords() -> void:
	for n in ALL_NAMES:
		var def := VoxelBuilder.load_def("res://data/voxels/%s.json" % n)
		if def.is_empty():
			continue
		var parsed := VoxelBuilder.parse(def)
		var cells: Dictionary = parsed["cells"]
		assert_gt(cells.size(), 0, "%s: є хоч один воксель" % n)
		var raw := _raw_symbol_count(def)
		assert_eq(cells.size(), raw, "%s: символи не перетинаються по координатах (без дублів)" % n)


func test_palette_at_most_six_colors() -> void:
	for n in ALL_NAMES:
		var def := VoxelBuilder.load_def("res://data/voxels/%s.json" % n)
		if def.is_empty():
			continue
		var palette: Dictionary = def.get("palette", {})
		assert_lte(palette.size(), 6, "%s: палітра ≤ 6 кольорів" % n)


func test_small_props_fit_footprint_and_voxel_budget() -> void:
	for n in SMALL_PROPS:
		var def := VoxelBuilder.load_def("res://data/voxels/%s.json" % n)
		if def.is_empty():
			continue
		var parsed := VoxelBuilder.parse(def)
		var cells: Dictionary = parsed["cells"]
		var size := float(def.get("size", 0.1))
		var b := _bounds_m(cells, size)
		var footprint := maxf(b.x, b.z)
		assert_lte(footprint, 0.61, "%s: footprint ≤ 0,6 м (%.3f)" % [n, footprint])
		assert_lte(cells.size(), 90, "%s: ≤ 90 вокселів (%d)" % [n, cells.size()])


func test_medium_props_fit_footprint_and_voxel_budget() -> void:
	for n in MEDIUM_PROPS:
		var def := VoxelBuilder.load_def("res://data/voxels/%s.json" % n)
		if def.is_empty():
			continue
		var parsed := VoxelBuilder.parse(def)
		var cells: Dictionary = parsed["cells"]
		var b := _bounds_m(cells, float(def.get("size", 0.1)))
		assert_lte(maxf(b.x, b.z), 1.01, "%s: footprint ≤ 1 м (%.3f)" % [n, maxf(b.x, b.z)])
		assert_lte(cells.size(), 160, "%s: ≤ 160 вокселів (%d)" % [n, cells.size()])


func test_trees_fit_height_range() -> void:
	for n in TREES:
		var def := VoxelBuilder.load_def("res://data/voxels/%s.json" % n)
		if def.is_empty():
			continue
		var parsed := VoxelBuilder.parse(def)
		var cells: Dictionary = parsed["cells"]
		var size := float(def.get("size", 0.1))
		var b := _bounds_m(cells, size)
		assert_between(b.y, 0.89, 1.41, "%s: висота 0,9–1,4 м (%.3f)" % [n, b.y])


func test_houses_fit_size_and_voxel_budget() -> void:
	for n in HOUSES:
		var def := VoxelBuilder.load_def("res://data/voxels/%s.json" % n)
		if def.is_empty():
			continue
		var parsed := VoxelBuilder.parse(def)
		var cells: Dictionary = parsed["cells"]
		var size := float(def.get("size", 0.1))
		var b := _bounds_m(cells, size)
		assert_between(b.x, 1.59, 2.21, "%s: ширина 1,6–2,2 м (%.3f)" % [n, b.x])
		assert_between(b.y, 1.79, 2.61, "%s: висота 1,8–2,6 м (%.3f)" % [n, b.y])
		assert_lte(cells.size(), 260, "%s: ≤ 260 вокселів (%d)" % [n, cells.size()])


## cloud_house — будиночок, але його купують на ділянку діорами (data/buildings.json,
## Diorama.CELL = 1,4 м; test_diorama.gd: ≤ 200 вокселів) — тому власна перевірка,
## не загальна test_houses_fit_size_and_voxel_budget.
func test_cloud_house_fits_diorama_plot() -> void:
	var def := VoxelBuilder.load_def("res://data/voxels/cloud_house.json")
	assert_false(def.is_empty(), "cloud_house: валідний JSON")
	var parsed := VoxelBuilder.parse(def)
	var cells: Dictionary = parsed["cells"]
	var size := float(def.get("size", 0.1))
	var b := _bounds_m(cells, size)
	assert_lte(maxf(b.x, b.z), 1.4, "cloud_house: вміщається в ділянку діорами 1,4 м")
	assert_between(b.y, 1.79, 2.61, "cloud_house: висота будиночка 1,8–2,6 м (%.3f)" % b.y)
	assert_lte(cells.size(), 200, "cloud_house: ≤ 200 вокселів (ліміт test_diorama.gd)")


func test_bridge_plank_deck_dimensions() -> void:
	var def := VoxelBuilder.load_def("res://data/voxels/bridge_plank.json")
	assert_false(def.is_empty(), "bridge_plank: валідний JSON")
	var parsed := VoxelBuilder.parse(def)
	var cells: Dictionary = parsed["cells"]
	var size := float(def.get("size", 0.1))
	var b := _bounds_m(cells, size)
	assert_almost_eq(b.x, 0.5, 0.01, "bridge_plank: палуба 0,5 м уздовж X")
	assert_almost_eq(b.z, 2.2, 0.01, "bridge_plank: палуба 2,2 м уздовж Z")
