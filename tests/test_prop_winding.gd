## ОРІЄНТАЦІЯ ГРАНЕЙ ПРОПСІВ — НАЗОВНІ: інакше відсікання задніх граней робить стіни невидимими.
##
## 23.09 гра ввімкнула відсікання задніх граней для всіх пропсів (PropLibrary._drop_normal_maps,
## −19% ціни декору). 26.09 замовник: «будинки, які були процедурно згенеровані, — там немає
## стін». tools/make_house.py обходив вершини граней у зворотний бік, і 13 моделей мали 67–74%
## площі, повернутої всередину: поки матеріали були двосторонні, цього не було видно.
##
## Міра: частка площі трикутників, чия нормаль дивиться до центру габариту. У коробки BoxMesh
## це 0%, у звичайних моделей 3–25%, у відкритих (ящик із рейок, візок) до 48%.
extends GutTest

const MAKE_HOUSE := ["house_red", "house_teal", "house_straw", "house_small", "city_house_a",
	"city_house_b", "wall_house", "barn", "mill", "kiosk", "well", "garden", "awning_stall"]


func _inward(m: Mesh) -> float:
	var c := m.get_aabb().get_center()
	var inw := 0.0
	var tot := 0.0
	for si in m.get_surface_count():
		var arr := m.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		var indexed: bool = idx != null and (idx as PackedInt32Array).size() > 0
		var n: int = (idx as PackedInt32Array).size() if indexed else v.size()
		for t in range(0, n, 3):
			var a := v[idx[t]] if indexed else v[t]
			var b := v[idx[t + 1]] if indexed else v[t + 1]
			var e := v[idx[t + 2]] if indexed else v[t + 2]
			# Лицьова грань у Godot — за годинниковою стрілкою: нормаль (e-a)×(b-a).
			var nn := (e - a).cross(b - a)
			var area := nn.length() * 0.5
			if area < 1e-9:
				continue
			tot += area
			if nn.dot((a + b + e) / 3.0 - c) < 0.0:
				inw += area
	return inw / maxf(tot, 1e-9)


func _mesh(path: String) -> Mesh:
	var sc := (load(path) as PackedScene).instantiate()
	var m := PropLibrary._first_mesh(sc)
	sc.free()
	return m


func test_mira_pravylna_na_etaloni() -> void:
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, BoxMesh.new().get_mesh_arrays())
	assert_almost_eq(_inward(am), 0.0, 0.001, "у коробки Godot усі грані назовні")


func test_budynky_make_house_zi_stinamy() -> void:
	for k in MAKE_HOUSE:
		var f := _inward(_mesh("res://assets/props/%s.glb" % k))
		assert_lt(f, 0.35, "%s: %.0f%% площі всередину — стіни зникнуть від відсікання" % [k, f * 100.0])


func test_zhoden_props_ne_vyvernutyi() -> void:
	var d := DirAccess.open("res://assets/props")
	for f in d.get_files():
		if not f.ends_with(".glb"):
			continue
		var m := _mesh("res://assets/props/" + f)
		if m == null:
			continue
		var x := _inward(m)
		assert_lt(x, 0.6, "%s: %.0f%% площі всередину — модель вивернута" % [f, x * 100.0])
