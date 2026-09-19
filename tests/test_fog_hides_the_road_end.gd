## Кінець дороги ховається туманом, а не показується гравцеві.
##
## Скарга замовника (зі знімком): «ось тут видно, що не має далі дороги і що вона
## підгружається, потрібно щось придумати, щоб не було нам пустоти». Траса — кільцевий буфер
## із Track.ROWS рядів по Track.ROW_DEPTH метра, тобто вона ФІЗИЧНО закінчується, і сховати
## цей край може лише туман.
##
## Показниковий туман для цього не годився: щоб він з'їв 42 м, треба така густина, що блякне
## й бочка за три кроки. Тому туман тепер по ГЛИБИНІ — до fog_depth_begin його нема зовсім,
## на fog_depth_end він суцільний. Тут стережемо саме це співвідношення: кінець туману мусить
## бути БЛИЖЧЕ за кінець траси, інакше край дороги знову видно.
extends GutTest

const RunScript := preload("res://src/run3d/run3d.gd")


## Найдальша точка траси від камери: ряди стоять від BEHIND до BEHIND − ROWS, камера — на
## pos.z позаду героя.
func _track_far_m(cam_z: float) -> float:
	return cam_z - (Track.BEHIND - float(Track.ROWS))


func test_fog_ends_before_the_track_does() -> void:
	var worlds: Dictionary = RunScript.load_worlds()
	assert_gt(worlds.size(), 0, "світи читаються")
	for id in worlds.keys():
		var cam: Dictionary = (worlds[id] as Dictionary).get("camera", {})
		var pos: Array = cam.get("pos", [0.0, 3.8, 4.6])
		var far := _track_far_m(float(pos[2]))
		assert_lt(RunScript.FOG_FAR_M, far,
			"%s: туман густішає до %.1f м, а траса кінчається на %.1f м" % [id, RunScript.FOG_FAR_M, far])


## Туман не сміє починатися впритул до героя: під ногами світ має бути різкий, як на
## референсі. І не сміє починатися після того, як уже став суцільним.
func test_fog_begins_far_enough_from_the_hero() -> void:
	var worlds: Dictionary = RunScript.load_worlds()
	for id in worlds.keys():
		var density := float((worlds[id] as Dictionary).get("fog_density", RunScript.DEFAULT_FOG))
		var begin: float = RunScript.fog_begin_for(density)
		assert_gte(begin, float(RunScript.FOG_BEGIN_RANGE[0]),
			"%s: туман не починається під ногами" % id)
		assert_lt(begin, RunScript.FOG_FAR_M, "%s: початок туману раніше за його кінець" % id)


## Густіший світ — ближчий туман. Саме так дані світів (Ліс 0,03, Лужок 0,012) лишаються
## осмисленими після переходу з показникового режиму в режим глибини.
func test_denser_world_gets_nearer_fog() -> void:
	var thick: float = RunScript.fog_begin_for(0.03)
	var thin: float = RunScript.fog_begin_for(0.012)
	assert_lt(thick, thin, "у густішому світі туман береться ближче")
	assert_eq(RunScript.fog_begin_for(RunScript.DEFAULT_FOG), RunScript.FOG_NEAR_M,
		"типова густина дає типову відстань")
	# 0 і від'ємне — не ділимо на нуль, а відсуваємо туман якнайдалі
	assert_eq(RunScript.fog_begin_for(0.0), float(RunScript.FOG_BEGIN_RANGE[1]),
		"нульова густина — туман найдалі, а не помилка")
