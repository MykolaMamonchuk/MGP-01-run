## Стеля ваги пропса. Декор малюється через MultiMesh, а MultiMesh НЕ вміє LOD: кожен
## інстанс коштує повну сітку незалежно від відстані. Тому ціна моделі множиться на
## кількість її копій у кадрі, і одна необережна модель з'їдає весь бюджет.
##
## Заміряно 18.09.2026 пробою на рівні 1: кадр тримає 145 983 трикутники, стеля телефона —
## 150–200 тисяч. Дві копії будинку house_terra, підміненого на генераторський оригінал
## (30 918 граней), дали 207 443 — тобто ДВІ моделі вистрибнули за стелю. Після
## tools/prop_prepare.py --weld --tris 3000 стало 151 603.
##
## Ліміти тут із запасом над тим, що є: не «скільки влізе», а «звідки починається біда».
extends GutTest

## Трикутників на одну модель. Це НЕ справжня межа, а сигналізація: справжня ціна — це
## трикутники × скільки копій видно в кадрі, і міряє її `tools/probe/` полем `decor_cost`
## (паркан на 899 граней коштує 70 тисяч, бо його 78 штук, а віз на 6 008 — дванадцять,
## бо їх два). Тут ловимо інше: модель, що приїхала з генератора НЕТОРКАНОЮ. Такі йдуть від
## тридцяти тисяч граней — будинок house_terra прийшов на 30 918, кущ на 104 299.
const MAX_TRIS := 7000
## Байтів на файл. Майже все це — текстура; 1024×1024 базового кольору важить близько 1,7 МБ.
const MAX_BYTES := 2_500_000


func _prop_files() -> Array:
	var out: Array = []
	var dir := DirAccess.open("res://assets/props")
	if dir == null:
		return out
	for name in dir.get_files():
		if name.get_extension() == "glb":
			out.append("res://assets/props/%s" % name)
	out.sort()
	return out


func _tris(path: String) -> int:
	var packed := load(path) as PackedScene
	if packed == null:
		return 0
	var root := packed.instantiate()
	var total := 0
	for node in _all_nodes(root):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		total += mi.mesh.get_faces().size() / 3
	root.free()
	return total


func _all_nodes(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_all_nodes(child))
	return out


func test_no_prop_model_exceeds_the_triangle_budget() -> void:
	var files := _prop_files()
	assert_gt(files.size(), 0, "пропси взагалі знайшлись")
	for path in files:
		var n := _tris(path)
		assert_lte(n, MAX_TRIS,
			"%s: %d трикутників — більше за стелю %d. Прогнати через tools/prop_prepare.py з --weld і --tris"
				% [path.get_file(), n, MAX_TRIS])


func test_no_prop_file_exceeds_the_size_budget() -> void:
	for path in _prop_files():
		var f := FileAccess.open(path, FileAccess.READ)
		assert_not_null(f, "%s читається" % path)
		if f == null:
			continue
		var size := f.get_length()
		f.close()
		assert_lte(size, MAX_BYTES,
			"%s: %d байтів — більше за стелю %d. Текстури звести через --matte і --tex-size 1024"
				% [path.get_file(), size, MAX_BYTES])
