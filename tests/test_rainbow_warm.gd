## Веселка не сміє смикати гру, коли з'являється.
##
## Скарга замовника: «коли з'являється райдуга, дуже просідає FPS». Замір (tools/probe,
## EVENT=rainbow, Compatibility, Мак) показав СПЛЕСК, а не стале падіння: кадр появи 144–464 мс
## проти 19–24 у контролі, а поки веселка на екрані — +0,5 мс, у шумі. Дві причини:
##   1. кільця — літ-матеріал з емісією, непрозорий; такого шейдера більше ніде нема, і перша
##      веселка компілювала його в кадрі появи;
##   2. іскри веселки — ~40 мс при КОЖНІЙ появі: рушій викидає шейдер частинок, щойно
##      звільнено останній матеріал із тим самим набором властивостей, тож наступна веселка
##      компілювала його знову. З тієї ж причини прогрів частинок не діяв узагалі.
## Після правки: 13,8 мс на кадрі появи — нарівні з контролем.
extends GutTest


## Кільця всіх веселок сесії беруть ті самі матеріали й сітки: шейдер кілець тримає живим
## статичний кеш, і прогрів на відліку не помирає разом із прогрівальною веселкою.
func test_rings_share_materials_and_meshes_across_rainbows() -> void:
	var a := Rainbow3D.new()
	var b := Rainbow3D.new()
	add_child_autofree(a)
	add_child_autofree(b)
	var rings_a := a.get_children().filter(func(c): return c is MeshInstance3D)
	var rings_b := b.get_children().filter(func(c): return c is MeshInstance3D)
	assert_eq(rings_a.size(), Rainbow3D.COLORS.size(), "кілець стільки, скільки кольорів")
	assert_eq(rings_b.size(), rings_a.size())
	for i in rings_a.size():
		assert_same((rings_a[i] as MeshInstance3D).material_override,
			(rings_b[i] as MeshInstance3D).material_override, "кільце %d — той самий матеріал" % i)
		assert_same((rings_a[i] as MeshInstance3D).mesh, (rings_b[i] as MeshInstance3D).mesh,
			"кільце %d — та сама сітка" % i)


## Вигляд не змінився: кольори палітри, літ-матеріал з емісією 0,3, радіуси крок 0,1.
func test_ring_look_is_unchanged() -> void:
	for i in Rainbow3D.COLORS.size():
		var m := Rainbow3D.ring_material(i)
		assert_eq(m.albedo_color, Rainbow3D.COLORS[i])
		assert_eq(m.shading_mode, BaseMaterial3D.SHADING_MODE_PER_PIXEL, "освітлення не знято")
		assert_true(m.emission_enabled)
		assert_almost_eq(m.emission_energy_multiplier, 0.3, 0.0001)
		assert_eq(m.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED)
		var t := Rainbow3D.ring_mesh(i)
		assert_almost_eq(t.outer_radius, Rainbow3D.RADIUS - 0.1 * i, 0.0001)
		assert_almost_eq(t.inner_radius, t.outer_radius - 0.09, 0.0001)


## Іскри веселки звільнено — а їхній матеріал частинок (а з ним і шейдер) живий.
func test_sparkles_material_outlives_the_rainbow() -> void:
	FX._keep.clear()   # _keep статичний на весь процес: без очищення тест залежав би від порядку
	var host := Node3D.new()
	add_child_autofree(host)
	var r := Rainbow3D.new()
	host.add_child(r)
	var spark: GPUParticles3D = null
	for c in r.get_children():
		if c is GPUParticles3D:
			spark = c
	assert_not_null(spark, "іскри у веселки є")
	r.free()
	assert_true(FX.retained("sparkles"), "матеріал іскор тримається й після веселки")


## Прогрів частинок на відліку мусить ЛИШАТИ шейдери по собі — інакше він марний: його
## вузли живуть 0,35 с, і без утримання шейдери помирали разом із ними.
func test_preheat_leaves_every_effect_shader_alive() -> void:
	FX._keep.clear()
	var host := Node3D.new()
	add_child_autofree(host)
	FX.preheat(host, Vector3.ZERO)
	await wait_seconds(FX.PREHEAT_SEC + 0.25)
	assert_null(host.get_node_or_null("FXPreheat"), "прогрівальні вузли прибрано")
	var kinds := ["dust", "burst", "splash", "confetti", "sparkles", "ring"]
	for k in kinds:
		assert_true(FX.retained(k), "шейдер «%s» пережив прогрів" % k)


## Ефекти, яких прогрів не стріляє (слід єдинорога — «Райдужний міст», сердечка, атмосфера),
## теж тримають свій матеріал: першу появу вони платять, наступні — вже ні.
func test_other_effects_retain_their_material_too() -> void:
	FX._keep.clear()
	var host := Node3D.new()
	add_child_autofree(host)
	FX.trail(host, Palette.RAINBOW[0], 4).queue_free()
	FX.hearts(host, Vector3.ZERO, 2)
	FX.ambient(host, "petals").queue_free()
	for k in ["trail", "hearts", "ambient_petals"]:
		assert_true(FX.retained(k), "«%s» тримає матеріал" % k)


## Прогрівальна веселка прибирає себе сама.
func test_rainbow_preheat_cleans_up_after_itself() -> void:
	var host := Node3D.new()
	add_child_autofree(host)
	var probe := Rainbow3D.preheat(host, Vector3.ZERO)
	assert_not_null(probe)
	assert_gt(probe.get_child_count(), 0, "у прогріві справжня веселка")
	await wait_seconds(Rainbow3D.PREHEAT_SEC + 0.25)
	assert_null(host.get_node_or_null("RainbowPreheat"), "і прибралась сама")


func test_rainbow_preheat_is_safe_outside_the_tree() -> void:
	var loose := Node3D.new()
	assert_null(Rainbow3D.preheat(loose, Vector3.ZERO))
	assert_eq(loose.get_child_count(), 0)
	loose.free()
