## VoxelBuilder: розбір опису, відсікання прихованих граней, детермінований меш, усі файли data/voxels валідні.
extends GutTest

const CUBE := {"size": 0.5, "palette": {"a": "#FF0000"}, "layers": [["a"]]}
const TWO := {"size": 0.5, "palette": {"a": "#FF0000", "b": "#00FF00"}, "layers": [["ab"]]}


func test_single_cube_has_six_faces() -> void:
	var parsed := VoxelBuilder.parse(CUBE)
	assert_eq((parsed["cells"] as Dictionary).size(), 1)
	assert_eq(VoxelBuilder.count_faces(parsed["cells"]), 6, "самотній куб — 6 граней")


func test_neighbours_hide_shared_faces() -> void:
	var parsed := VoxelBuilder.parse(TWO)
	assert_eq((parsed["cells"] as Dictionary).size(), 2)
	assert_eq(VoxelBuilder.count_faces(parsed["cells"]), 10, "два куби поруч — 12 мінус 2 спільні")


func test_empty_symbol_and_unknown_symbol_are_skipped() -> void:
	var def := {"size": 0.5, "palette": {"a": "#FF0000"}, "layers": [["a.", "?a"]]}
	var parsed := VoxelBuilder.parse(def)
	assert_eq((parsed["cells"] as Dictionary).size(), 2, "'.' і невідомий символ пропускаються")


func test_palette_override_changes_color() -> void:
	var parsed := VoxelBuilder.parse(CUBE, {"a": "#0000FF"})
	var c: Color = parsed["cells"][Vector3i(0, 0, 0)]
	assert_almost_eq(c.b, 1.0, 0.001, "колір підмінено з палітри")


func test_build_mesh_vertex_count_matches_faces() -> void:
	var mesh := VoxelBuilder.build(CUBE)
	assert_eq(mesh.get_surface_count(), 1)
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(verts.size(), 6 * 6, "6 граней × 2 трикутники × 3 вершини")


func test_mesh_is_centered_on_xz_and_stands_on_ground() -> void:
	var mesh := VoxelBuilder.build(CUBE)
	var aabb := mesh.get_aabb()
	assert_almost_eq(aabb.position.x, -0.25, 0.001)
	assert_almost_eq(aabb.position.z, -0.25, 0.001)
	assert_almost_eq(aabb.position.y, 0.0, 0.001, "стоїть на y = 0")


## Файли, які НЕ йдуть у гру — лише довідковий дамп для src/debug/voxel_preview.gd
## (ціла модель tools/voxelize.py, потрібна дрібна сітка для порівняння з референсом).
## Бюджет ≤ 600 вокселів стереже те, що реально інстансується в грі (герой по частинах,
## перешкоди, декор) — не debug-артефакти.
const DEBUG_ONLY_FILES := ["fox_voxel.json"]


func test_all_voxel_files_parse_and_are_small() -> void:
	var dir := DirAccess.open("res://data/voxels")
	assert_not_null(dir, "папка data/voxels існує")
	if dir == null:
		return
	var n := 0
	for f in dir.get_files():
		if not f.ends_with(".json") or DEBUG_ONLY_FILES.has(f):
			continue
		n += 1
		var def := VoxelBuilder.load_def("res://data/voxels/%s" % f)
		assert_false(def.is_empty(), "%s: валідний JSON" % f)
		var parsed := VoxelBuilder.parse(def)
		var cells: int = (parsed["cells"] as Dictionary).size()
		assert_gt(cells, 0, "%s: є хоч один воксель" % f)
		assert_lt(cells, 600, "%s: ≤ 600 вокселів (GDD §3: перешкоди ≤ 200, герой більший)" % f)
	assert_gt(n, 5, "є набір воксельних файлів")


func test_missing_file_gives_fallback_not_crash() -> void:
	var mesh := VoxelBuilder.mesh("__no_such_voxel__")
	assert_not_null(mesh)
	assert_eq(mesh.get_surface_count(), 1, "рожевий кубик-заглушка")
