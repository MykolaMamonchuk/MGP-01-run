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


## Точніше: кожен окремий ШМАТОК сітки (стіна, стовп, вікно — окремі коробки) мусить мати всі
## грані назовні. Міра по всій моделі цього не бачить: рецензія 26.09 знайшла, що перший
## перерахунок лишив вивернутою половину граней кожної коробки (glTF приходить із роз'єднаними
## гранями, і Blender перераховував кожну окремо), а модель у цілому мала «нормальні» 10-27%.
func _worst_piece(m: Mesh) -> float:
	var tris: Array = []
	for si in m.get_surface_count():
		var arr := m.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		var indexed: bool = idx != null and (idx as PackedInt32Array).size() > 0
		var n: int = (idx as PackedInt32Array).size() if indexed else v.size()
		for t in range(0, n, 3):
			tris.append([v[idx[t]] if indexed else v[t], v[idx[t + 1]] if indexed else v[t + 1],
				v[idx[t + 2]] if indexed else v[t + 2]])
	# Шматки — за спільними ПОЗИЦІЯМИ вершин (об'єднання множин).
	var parent := range(tris.size())
	var owner := {}
	var find := func(a: int) -> int:
		while parent[a] != a:
			parent[a] = parent[parent[a]]
			a = parent[a]
		return a
	for i in tris.size():
		for p in tris[i]:
			var key := Vector3i(roundi(p.x * 1e4), roundi(p.y * 1e4), roundi(p.z * 1e4))
			if owner.has(key):
				var ra: int = find.call(i)
				var rb: int = find.call(owner[key])
				if ra != rb:
					parent[ra] = rb
			else:
				owner[key] = i
	var groups := {}
	for i in tris.size():
		var r: int = find.call(i)
		if not groups.has(r):
			groups[r] = []
		groups[r].append(tris[i])
	var worst := 0.0
	for r in groups:
		var g: Array = groups[r]
		if g.size() < 12:
			continue   # лише замкнені коробки й більші; пласка табличка «всередину» не має
		var c := Vector3.ZERO
		for t in g:
			c += (t[0] + t[1] + t[2]) / 3.0
		c /= float(g.size())
		var inw := 0.0
		var tot := 0.0
		for t in g:
			var nn: Vector3 = (t[2] - t[0]).cross(t[1] - t[0])
			var area := nn.length() * 0.5
			tot += area
			if nn.dot((t[0] + t[1] + t[2]) / 3.0 - c) < 0.0:
				inw += area
		worst = maxf(worst, inw / maxf(tot, 1e-9))
	return worst


func test_kozhna_korobka_budynku_nazovni() -> void:
	for k in MAKE_HOUSE:
		var w := _worst_piece(_mesh("res://assets/props/%s.glb" % k))
		assert_lt(w, 0.05, "%s: у найгіршого шматка %.0f%% площі всередину" % [k, w * 100.0])
