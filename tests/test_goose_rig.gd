## СКЕЛЕТНА ГУСКА: кістки трьох нових моделей розкладаються правильно, і кожен стан рухає.
##
## Риг UniRig не має імен (Bone_000…), і в трьох моделях кістки лежать по-різному, тож
## GooseRig шукає ролі за геометрією. Ламається це тихо: стан просто перестає рухати
## крило чи шию, а помилки нема. Тут — сторож на обидва випадки.
extends GutTest

const MODELS := [
	"res://assets/props/_exp/goose/goose_1.glb",
	"res://assets/props/_exp/goose/goose_2.glb",
	"res://assets/props/_exp/goose/goose_3.glb",
]


func _rig(path: String) -> GooseRig:
	var model := (load(path) as PackedScene).instantiate()
	add_child_autofree(model)
	var rig := GooseRig.new()
	assert_true(rig.build(model), "%s: скелет знайдено" % path)
	return rig


func test_rozkladka_kistok() -> void:
	for path in MODELS:
		var r := _rig(path)
		var head_y := r.skel.get_bone_global_rest(r.head).origin.y
		assert_gt(head_y, 0.75 * r.height, "%s: голова вгорі, а не лапа чи хвіст" % path)
		assert_gt(r.neck.size(), 1, "%s: шия з кількох кісток" % path)
		assert_eq(r.wings.size(), 2, "%s: два крила" % path)
		assert_eq(r.legs.size(), 2, "%s: дві лапи" % path)
		var side := r.up.cross(r.fwd).normalized()
		for pair in [r.wings, r.legs]:
			var ta: float = r._tip(pair[0]).dot(side)
			var tb: float = r._tip(pair[1]).dot(side)
			assert_lt(ta * tb, 0.0, "%s: пара по різні боки тіла" % path)
		assert_gt(r.tail, -1, "%s: хвіст знайдено" % path)
		assert_lt(r.skel.get_bone_global_rest(r.tail).origin.dot(r.fwd),
			r.skel.get_bone_global_rest(r.head).origin.dot(r.fwd), "%s: хвіст позаду голови" % path)


func test_kozhen_stan_rukhaie() -> void:
	for path in MODELS:
		var r := _rig(path)
		for st in GooseRig.STATES:
			r.state = st
			var moved := 0
			for t in [0.3, 0.9]:
				r.pose(t)
				for i in range(r.skel.get_bone_count()):
					var rest := r.skel.get_bone_rest(i).basis.get_rotation_quaternion()
					if r.skel.get_bone_pose_rotation(i).angle_to(rest) > 0.02:
						moved += 1
			assert_gt(moved, 2, "%s: стан %s рухає кістки" % [path, st])


func test_polit_pidnimaie_a_kusannia_kydaie_shyiu() -> void:
	var r := _rig(MODELS[0])
	r.state = "fly"
	assert_gt(r.pose(0.5), 0.2 * r.height, "у польоті гуска над землею")
	r.state = "stand"
	assert_almost_eq(r.pose(0.5), 0.0, 0.001, "стоїть на землі")
	# Кидок: у фазі 0,55 циклу голова йде вперед відносно спокою.
	r.state = "bite"
	r.pose(0.55 * 1.4)
	var head_now := r.skel.get_bone_global_pose(r.head).origin.dot(r.fwd)
	var head_rest := r.skel.get_bone_global_rest(r.head).origin.dot(r.fwd)
	assert_gt(head_now, head_rest + 0.1 * r.height, "кусає — голова кидається вперед")


## Кінець ланцюга — НАЙГЛИБША кістка, а не найдальша від кореня: крило гуски 3 йде
## зигзагом (лікоть уперед, кінчик назад), і розкрите крило законно заводить лікоть до тулуба.
func _end_bone(r: GooseRig, i: int) -> int:
	var b := i
	while r.skel.get_bone_children(b).size() > 0:
		var best := -1
		var depth := -1
		for k in r.skel.get_bone_children(b):
			var d := _depth(r, k)
			if d > depth:
				depth = d
				best = k
		b = best
	return b


func _depth(r: GooseRig, i: int) -> int:
	var d := 0
	for k in r.skel.get_bone_children(i):
		d = maxi(d, 1 + _depth(r, k))
	return d


## НАПРЯМ, а не просто рух: розправлене крило йде НАЗОВНІ й УГОРУ, на всіх трьох моделях.
## Рецензія 25.09: у гуски 3 знак брався за першою кісткою крила, і крила в «шипить» і
## «летить» ішли всередину тулуба, а тест «стан рухає кістки» лишався зеленим — шия сама
## давала досить обертів.
func test_kryla_rozpravliaiutsia_nazovni_i_vhoru() -> void:
	for path in MODELS:
		var r := _rig(path)
		for st in ["hiss", "fly"]:
			r.state = st
			# Політ — на СЕРЕДИНІ змаху (sin(9t) = 0): угорі крило майже прямовисне, і зсув
			# назовні там законно малий. Сам змах перевіряється нижче окремо.
			r.pose(0.0 if st == "fly" else PI / 18.0)
			# Глобальні пози скелет рахує ліниво — без цього читаємо позу попереднього стану.
			r.skel.force_update_all_bone_transforms()
			for w in r.wings:
				var e := _end_bone(r, w)
				var d := r.skel.get_bone_global_pose(e).origin - r.skel.get_bone_global_rest(e).origin
				var out := r._side_of(w)
				assert_gt(d.dot(out), 0.05 * r.height, "%s, %s: кінець крила йде назовні" % [path, st])
				assert_gt(d.dot(r.up), 0.0, "%s, %s: кінець крила йде вгору" % [path, st])


func test_kydok_shyiei_na_vsikh_modeliakh() -> void:
	for path in MODELS:
		var r := _rig(path)
		r.state = "bite"
		r.pose(0.55 * 1.4)
		r.skel.force_update_all_bone_transforms()
		var now := r.skel.get_bone_global_pose(r.head).origin.dot(r.fwd)
		var rest := r.skel.get_bone_global_rest(r.head).origin.dot(r.fwd)
		assert_gt(now, rest + 0.1 * r.height, "%s: кусає — голова кидається вперед" % path)


## Повторна розкладка не дописує ролі до старих (пастка для перешкоди, що перебудовує модель).
func test_povtornyi_build_ne_dubliuie_roli() -> void:
	var model := (load(MODELS[0]) as PackedScene).instantiate()
	add_child_autofree(model)
	var r := GooseRig.new()
	r.build(model)
	var n := [r.neck.size(), r.wings.size(), r.legs.size()]
	r.build(model)
	assert_eq([r.neck.size(), r.wings.size(), r.legs.size()], n, "ролі ті самі після другого build()")


## Змах: у верхній фазі кінчик крила вищий, ніж у нижній, — на кожній моделі.
func test_zmakh_kryla() -> void:
	for path in MODELS:
		var r := _rig(path)
		r.state = "fly"
		for w in r.wings:
			var e := _end_bone(r, w)
			r.pose(PI / 18.0)           # sin(9t) = 1, крила вгорі
			r.skel.force_update_all_bone_transforms()
			var hi := r.skel.get_bone_global_pose(e).origin.dot(r.up)
			r.pose(3.0 * PI / 18.0)     # sin(9t) = -1, крила внизу
			r.skel.force_update_all_bone_transforms()
			var lo := r.skel.get_bone_global_pose(e).origin.dot(r.up)
			assert_gt(hi - lo, 0.15 * r.height, "%s: змах піднімає й опускає крило" % path)
