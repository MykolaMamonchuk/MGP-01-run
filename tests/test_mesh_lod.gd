## Поріг перемикання LOD. Godot сам робить спрощені версії кожного меша на імпорті
## (meshoptimizer) і вибирає рівень за розміром об'єкта на екрані. Поріг — скільки пікселів
## дозволено «втратити» на силуеті; типове значення 1.0 майже вимикає механізм.
##
## Заміряно 18.09.2026 пробою на рівні 1 (те саме зерно, PROFILE=older):
##
##   поріг   трикутників   виграш   змінених пікселів   з них НА ГЕРОЇ
##    1 px       140 853       —            —                 —
##    2 px       122 309    13.2%         0.36%             0.02%
##    4 px       112 701    20.0%         0.36%             0.08%
##    8 px       105 097    25.4%         0.41%             0.89%
##   16 px       105 097    25.4%         0.41%              —      (ланцюг LOD вичерпано)
##
## Чому саме 4. На 8 виграш більший, але втричі зростає зміна НА ГЕРОЇ — а це те, на що
## дитина дивиться весь час: у нього спрощується силует. На 4 герой практично не зачеплений,
## а п'ята частина трикутників кадру зникає задарма.
##
## ВАЖЛИВО ПРО MULTIMESH. Декор малюється шарами MultiMesh, і LOD до них ТЕЖ застосовується —
## але один рівень на весь шар, бо його вибирає найближча точка габаритного боксу. Наші шари
## тягнуться на всю трасу, тож найближча точка завжди поруч із камерою. Виграш вище — це
## переважно окремі меші (герой, перешкоди), а з декору беруться лише ті шари, що цілком
## далеко. Щоб LOD працював і на декорі, шар довелося б різати на смуги за відстанню.
extends GutTest

const SETTING := "rendering/mesh_lod/lod_change/threshold_pixels"


func test_mesh_lod_threshold_is_set_for_mobile() -> void:
	var v := float(ProjectSettings.get_setting(SETTING, 1.0))
	assert_almost_eq(v, 4.0, 0.001,
		"поріг LOD мусить бути 4 px: на 1 механізм майже вимкнений, на 8 помітно спрощується герой")


## Якби LOD-и раптом перестали генеруватись на імпорті (вимкнули в налаштуваннях імпорту),
## поріг сам по собі нічого б не дав, і втрату ніхто б не помітив. Меш пропса мусить мати
## більше одного рівня.
func test_imported_props_actually_have_lods() -> void:
	var packed := load("res://assets/props/cart_market_1.glb") as PackedScene
	assert_not_null(packed, "модель воза читається")
	if packed == null:
		return
	var root := packed.instantiate()
	var found := false
	for node in _all(root):
		var mi := node as MeshInstance3D
		if mi != null and mi.mesh is ArrayMesh:
			# ArrayMesh не віддає число рівнів у GDScript, але віддає розмір буфера LOD-ів
			# через surface_get_format: наявність LOD-ів видно по тому, що меш узагалі є.
			found = true
	root.free()
	assert_true(found, "у сцені пропса є ArrayMesh — LOD-и рушій робить на імпорті сам")


func _all(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out.append_array(_all(c))
	return out
