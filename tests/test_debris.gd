## Друзки: предмет розлітається на шматки, які летять, крутяться й падають.
##
## Найважливіше тут — РУХ, і він винесений у чисту функцію Debris.piece_at(), щоб його можна
## було перевірити числами без сцени. У проєкті вже коштувало помилок те, що формула жила
## всередині вузла й перевірялась лише оком.
extends GutTest


func test_pieces_fly_up_then_fall() -> void:
	var p0 := Vector3.ZERO
	var v0 := Vector3(0.0, 4.0, 0.0)
	var up := Debris.piece_at(p0, v0, 0.1, -1.0)
	var top := Debris.piece_at(p0, v0, 0.28, -1.0)
	assert_gt(up.y, 0.0, "спершу шматок летить угору")
	assert_gt(top.y, up.y, "і ще підіймається до вершини")
	var later := Debris.piece_at(p0, v0, 0.55, -1.0)
	assert_lt(later.y, top.y, "далі падає")


func test_piece_never_sinks_below_ground() -> void:
	var ground := -0.6
	for i in range(60):
		var t := float(i) * 0.05
		var p := Debris.piece_at(Vector3(0.0, 0.2, 0.0), Vector3(1.0, 3.0, 0.5), t, ground)
		assert_gte(p.y, ground - 0.0001, "на t=%.2f шматок не провалився під землю" % t)


## Відскок мусить бути СЛАБШИЙ за падіння, інакше шматки стрибають, як м'ячики, і предмет
## читається як гумовий.
func test_bounce_is_weaker_than_the_fall() -> void:
	var ground := 0.0
	var v0 := Vector3(0.0, 4.0, 0.0)
	var first_top := 0.0
	var second_top := 0.0
	var hit_t := 0.0
	for i in range(200):
		var t := float(i) * 0.01
		var y := Debris.piece_at(Vector3.ZERO, v0, t, ground).y
		if hit_t == 0.0:
			first_top = maxf(first_top, y)
			if t > 0.1 and y <= ground + 0.0001:
				hit_t = t
		else:
			second_top = maxf(second_top, y)
	assert_gt(first_top, 0.0, "перший зліт стався")
	assert_lt(second_top, first_top, "після удару об землю шматок підстрибує нижче")


func test_horizontal_motion_continues_through_the_bounce() -> void:
	var a := Debris.piece_at(Vector3.ZERO, Vector3(2.0, 3.0, 0.0), 0.2, 0.0)
	var b := Debris.piece_at(Vector3.ZERO, Vector3(2.0, 3.0, 0.0), 0.8, 0.0)
	assert_gt(b.x, a.x, "шматок продовжує летіти вбік і після удару, а не спиняється на місці")


func test_burst_builds_one_multimesh_with_the_asked_pieces() -> void:
	var host := Node3D.new()
	add_child_autofree(host)
	var d := Debris.burst(host, Vector3(0.0, 0.5, -3.0), Palette.W_CRATE, Vector3(0.7, 0.7, 0.7), 8)
	assert_not_null(d.multimesh, "меш є")
	assert_eq(d.multimesh.instance_count, 8, "шматків стільки, скільки просили")
	assert_true(d.multimesh.use_colors, "колір на шматок — інакше вибух читається однією плямою")
	assert_eq(d.get_parent(), host, "вузол живе у того самого батька, що й предмет — щоб їхати з дорогою")


## Один вибух — один виклик малювання, скільки б не було шматків. Гра впирається в draw calls,
## тож десяток вузлів на кожен удар був би найдорожчим рішенням у найгарячішу мить кадру.
func test_a_burst_costs_a_single_draw_call() -> void:
	var host := Node3D.new()
	add_child_autofree(host)
	var d := Debris.burst(host, Vector3.ZERO, Palette.W_CRATE, Vector3.ONE, 24)
	assert_eq(d.get_child_count(), 0, "шматки не є вузлами — вони інстанси одного MultiMesh")


## Питаємо ОБЧИСЛЕННЯ, а не буфер MultiMesh: у headless рендер-сервер — заглушка, і
## get_instance_transform() віддає нулі, хоч запис пройшов. Тест по буферу перевіряв би
## порожнечу й був би зелений завжди.
func test_pieces_spread_out_instead_of_sitting_in_one_spot() -> void:
	var host := Node3D.new()
	add_child_autofree(host)
	var d := Debris.burst(host, Vector3.ZERO, Palette.W_CRATE, Vector3(0.8, 0.8, 0.8), 12)
	var seen := {}
	for i in range(12):
		var o := d.piece_position(i, 0.3)
		seen["%.2f|%.2f|%.2f" % [o.x, o.y, o.z]] = true
	assert_gt(seen.size(), 6, "шматки розлітаються в різні боки, а не купкою")


## Шматки мусять іти В РІЗНІ боки по горизонталі, а не вгору стовпом: вибух угору читається
## як фонтан, а не як «предмет розлетівся».
func test_pieces_fly_outwards_not_just_up() -> void:
	var host := Node3D.new()
	add_child_autofree(host)
	var d := Debris.burst(host, Vector3.ZERO, Palette.W_CRATE, Vector3(0.8, 0.8, 0.8), 16)
	var left := 0
	var right := 0
	for i in range(16):
		var x := d.piece_position(i, 0.3).x
		if x < -0.05:
			left += 1
		elif x > 0.05:
			right += 1
	assert_gt(left, 0, "частина шматків полетіла ліворуч")
	assert_gt(right, 0, "частина — праворуч")


## Наприкінці життя шматки стискаються в нуль, а не зникають стрибком.
func test_pieces_shrink_away_at_the_end() -> void:
	var host := Node3D.new()
	add_child_autofree(host)
	var d := Debris.burst(host, Vector3.ZERO, Palette.W_CRATE, Vector3.ONE, 4)
	assert_almost_eq(d.piece_scale(0.0), 1.0, 0.001, "спочатку шматок цілий")
	assert_almost_eq(d.piece_scale(Debris.LIFE_SEC * Debris.FADE_FROM), 1.0, 0.001,
		"до початку згасання — теж")
	assert_lt(d.piece_scale(Debris.LIFE_SEC * 0.95), 0.5, "під кінець уже майже зник")
	assert_almost_eq(d.piece_scale(Debris.LIFE_SEC), 0.0, 0.001, "наприкінці — нуль")
