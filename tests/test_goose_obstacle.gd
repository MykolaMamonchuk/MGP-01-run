## ГУСКА-ПЕРЕШКОДА зі скелетом: роль із даних світу → стан анімації, і три моделі в грі.
##
## Реакція гуски — лише вигляд: вона шипить, коли герой наближається, і кидається кусати,
## коли він поруч, але габарит і дія перешкоди ті самі. Ламається це тихо: гуска просто
## стоїть статуєю або всі три виходять однією моделлю, і жодної помилки.
extends GutTest


func _world() -> Dictionary:
	var f := FileAccess.open("res://data/worlds/meadow.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func _goose(kind: String) -> Obstacle3D:
	var o := Obstacle3D.new()
	o.setup(kind, _world()["obstacles"][kind], 0, false)
	add_child_autofree(o)
	return o


func test_hrai_ie_trokh_husok_z_riha() -> void:
	for kind in ["cow", "goose_walk", "goose_fly"]:
		var o := _goose(kind)
		assert_not_null(o._rig, "%s: гуска зі скелетом, а не статичний меш" % kind)


func test_try_husky_pospil_rizni_modeli() -> void:
	var seen := {}
	for i in range(3):
		seen[_goose("cow")._rig_variant] = true
	assert_eq(seen.size(), 3, "три гуски поспіль — три різні моделі (усі три в грі)")


func test_stoiacha_reahuie_na_heroia() -> void:
	var o := _goose("cow")
	o.position.z = -20.0
	o.tick(0.016)
	assert_eq(o._rig_state, "stand", "далеко — стоїть")
	o.position.z = -4.0
	o.tick(0.016)
	assert_eq(o._rig_state, "hiss", "герой наближається — шипить")
	o.position.z = 0.3
	o.tick(0.016)
	assert_eq(o._rig_state, "bite", "герой поруч — кусає")
	o.position.z = 3.0
	o.tick(0.016)
	assert_eq(o._rig_state, "stand", "пробіг — заспокоїлась")


func test_letiucha_tse_pryhnys() -> void:
	var def: Dictionary = _world()["obstacles"]["goose_fly"]
	assert_eq(String(def["action"]), "duck", "під гускою, що летить, пригинаються")
	var o := _goose("goose_fly")
	o.tick(0.1)
	assert_eq(o._rig_state, "fly")
	assert_gt(o._mesh.position.y, 0.8, "летить на висоті голови, а не по землі")


func test_ta_shcho_khodyt_dyvytsia_kudy_ide() -> void:
	var o := _goose("goose_walk")
	o.range_x = 1.0
	o._dir = 1.0
	o.tick(0.016)
	assert_almost_eq(o._mesh.rotation.y, PI * 0.5, 0.01, "іде вздовж +X — дзьоб туди ж")
	o._dir = -1.0
	o.tick(0.016)
	assert_almost_eq(o._mesh.rotation.y, -PI * 0.5, 0.01, "розвернулась — дзьоб у другий бік")
