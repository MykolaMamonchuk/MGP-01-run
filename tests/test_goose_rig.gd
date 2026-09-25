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
