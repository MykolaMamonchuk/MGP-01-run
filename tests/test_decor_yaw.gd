## ПОВОРОТ ДЕКОРУ: від'ємний кут — звичайний кут, а не знак «крути навмання».
##
## До 26.09 `Track._add_decor` вважав будь-який yaw < 0 випадковим. Будинки правого боку
## (-PI/2, фасадом до дороги) і рукотворні маркери з yaw_deg = -90 шість днів стояли під
## випадковим поворотом: з 486 правих хат до дороги дивились 3, і справа було видно голі стіни
## моделей, детальних лише з фасаду.
extends GutTest

const STRIDE := 7


func _one(t: Track, yaw: float) -> PackedFloat32Array:
	var ids := PackedInt32Array()
	var data := PackedFloat32Array()
	if is_nan(yaw):
		t._add_decor(ids, data, "house_terra_3", {}, 8.0, 0.0, 1.0)
	else:
		t._add_decor(ids, data, "house_terra_3", {}, 8.0, 0.0, 1.0, yaw)
	return data


func test_vidiemnyi_kut_zberihaietsia() -> void:
	var t := Track.new()
	add_child_autofree(t)
	var extra := deg_to_rad(float(PropLibrary.tweak("house_terra_3")["yaw_deg"]))
	for yaw in [-PI * 0.5, -0.1, PI * 0.5, 0.0]:
		var d := _one(t, yaw)
		assert_almost_eq(d[3], yaw + extra, 0.0001, "поворот %.2f лишився собою" % yaw)
		assert_eq(d[2], 0.0, "заданий поворот — без випадкового зсуву вздовж дороги")


func test_bez_kuta_navmannia() -> void:
	var t := Track.new()
	add_child_autofree(t)
	var seen := {}
	for i in range(8):
		seen[snappedf(_one(t, Track.RANDOM_YAW)[3], 0.001)] = true
	assert_gt(seen.size(), 4, "без заданого кута поворот випадковий, як і раніше")


## Заморожені цеглинки: ліві хати дивляться на дорогу під 90°, праві — під 270° (-90°).
func test_pravi_khaty_fasadom_do_dorohy() -> void:
	var bad := 0
	var total := 0
	for dir in DirAccess.get_directories_at("res://levels/chunks"):
		for f in DirAccess.get_files_at("res://levels/chunks/%s" % dir):
			if not f.ends_with(".tscn"):
				continue
			var packed := load("res://levels/chunks/%s/%s" % [dir, f]) as PackedScene
			var root := packed.instantiate()
			for m in root.find_children("*", "Node3D", true, false):
				if not ("kind" in m) or not String(m.get("kind")).begins_with("house_terra"):
					continue
				var x := (m as Node3D).position.x
				if absf(x) < 5.0:
					continue
				total += 1
				var want := 90.0 if x < 0.0 else 270.0
				if absf(fposmod(float(m.get("yaw_deg")), 360.0) - want) > 1.0:
					bad += 1
			root.free()
	assert_gt(total, 500, "хати знайдено")
	assert_eq(bad, 0, "усі хати обох боків фасадом до дороги")
