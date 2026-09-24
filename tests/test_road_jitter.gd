## Джиттер плитки: ламає «надруковану сітку», не купуючи це геометрією.
##
## Замовник скаржився, що дорога виглядає як надрукована клітинка. Причина не в тому, що шви
## є, а в тому, що вони ідеально рівні. Правка зсуває, стискає й повертає ті самі екземпляри
## MultiMesh — жодної нової вершини.
##
## Тут стережемо три речі, кожна з яких може тихо зламатись:
##   1. ДЕТЕРМІНОВАНІСТЬ — інакше ряд, що поїхав і повернувся, перемалюється на очах;
##   2. МЕЖІ — інакше плитка вилізе за свою клітинку й наїде на сусідню чи на шов;
##   3. РІЗНОМАНІТНІСТЬ — інакше «джиттер» виявиться нулем і нічого не змінить.
extends GutTest


func test_odnakove_zerno_daie_odnakovu_plytku() -> void:
	for lane in range(3):
		var a := Track.tile_jitter(12345, lane)
		var b := Track.tile_jitter(12345, lane)
		assert_eq(a, b, "та сама плитка при тому самому зерні — інакше дорога перемальовується")


func test_susidni_plytky_rizni() -> void:
	var a := Track.tile_jitter(12345, 0)
	var b := Track.tile_jitter(12345, 1)
	assert_ne(a, b, "сусідні доріжки одного ряду мають різнитись")
	var c := Track.tile_jitter(12346, 0)
	assert_ne(a, c, "сусідні ряди теж")


## Плитка не має вилазити за свою клітинку: зазор між ними 2 см, тож зсув мусить бути
## меншим, а масштаб — не більшим за одиницю.
func test_plytka_ne_vylazyt_za_klitynku() -> void:
	var worst_shift := 0.0
	var worst_scale := 0.0
	for seed_i in range(400):
		for lane in range(7):
			var j := Track.tile_jitter(seed_i * 7919, lane)
			worst_shift = maxf(worst_shift, maxf(absf(float(j[0])), absf(float(j[1]))))
			worst_scale = maxf(worst_scale, maxf(float(j[3]), float(j[4])))
			assert_between(float(j[2]), -Track.JITTER_YAW, Track.JITTER_YAW, "поворот у межах")
	assert_lt(worst_shift, Track.TILE_GAP, "зсув менший за зазор між плитками")
	assert_lte(worst_scale, 1.0, "плитка не БІЛЬШАЄ, лише вкорочується")


## Джиттер має бути справжнім, а не нулем: інакше тест вище проходив би на порожнечі.
##
## УВАГА НА ОЧІКУВАННЯ ПО ДОВЖИНІ. Спершу тут стояло «понад 4 різні довжини», і після
## налаштування тест впав — бо довжину навмисно майже перестали чіпати. Причина: саме
## масштаб розширює шов між плитками, і з укороченням до 6% дорога почала читатись як плити
## на траві. Сітку тепер ламають ЗСУВ і ПОВОРОТ, а довжина лише ледь дихає. Тож міряємо її
## тоншою міркою, а головні вимоги — до зсуву й повороту.
func test_dzhytter_spravdi_rozkydaie() -> void:
	var shifts := {}
	var yaws := {}
	var lens := {}
	for seed_i in range(200):
		var j := Track.tile_jitter(seed_i * 104729, 0)
		shifts[snappedf(float(j[0]), 0.002)] = true
		yaws[snappedf(float(j[2]), 0.005)] = true
		lens[snappedf(float(j[4]), 0.002)] = true
	assert_gt(shifts.size(), 8, "зсуви мають бути різні, а не один на всіх")
	assert_gt(yaws.size(), 6, "повороти теж — вони ламають сітку найпомітніше")
	assert_gt(lens.size(), 3, "довжина хай ледь дихає, але не завмирає зовсім")


## У стилях без зазору поперек плитки СТИКАЮТЬСЯ, тож зсув уздовж мусить бути нульовим:
## інакше верхні грані накладуться одна на одну й підуть миготіти.
func test_bez_zazoru_plytky_ne_nakladaiutsia() -> void:
	var track := Track.new()
	add_child_autofree(track)
	await wait_frames(2)
	assert_eq(track.road_style(), "grid", "типово — «grid»: прибрана основа дає 4,9 мс")
	# ЗАЗОР МУСИТЬ ВМІЩАТИ ВИНІС ПОВЕРНУТОЇ ПЛИТКИ. Джиттер повертає її на JITTER_YAW, кут
	# виходить за клітинку на hx·sin(yaw) з кожного боку. Якщо зазор менший за суму двох
	# таких виносів, сусідні плитки налазять КОПЛАНАРНИМИ верхніми гранями — миготіння.
	# Зонд геометрії на 20 тисячах пар показав 61% перетинів, коли зазору не було зовсім.
	var need: float = (Hero3D.LANE_W - Track.TILE_GAP) * sin(Track.JITTER_YAW)
	for style in ["flat", "grid"]:
		track.set_road_style(style)
		var bm := (track._mm_surface.multimesh as MultiMesh).mesh as BoxMesh
		assert_almost_eq(bm.size.z, 1.0 - need, 0.0005,
			"у стилі «%s» зазор поперек має дорівнювати виносу повороту" % style)
		# І поперечний шов мусить цей зазор ЗАКРИВАТИ: основи під плиткою тут немає.
		var xb := (track._mm_xseam.multimesh as MultiMesh).mesh as BoxMesh
		assert_almost_eq(xb.size.z, need, 0.0005,
			"у стилі «%s» шов має закривати весь зазор, інакше світиться порожнеча" % style)
	track.set_road_style("base")
	var bm2 := (track._mm_surface.multimesh as MultiMesh).mesh as BoxMesh
	assert_almost_eq(bm2.size.z, 1.0 - Track.TILE_GAP, 0.0005,
		"у «base» зазор — TILE_GAP, і саме крізь нього видно основу")


## СТОРОЖ НА ОБНУЛЕННЯ ЗСУВУ УЗДОВЖ. Рецензія показала, що цю правку не стеріг ніхто:
## прибери гілку — і весь набір лишався зеленим.
##
## Перші дві редакції цього сторожа впали самі, і обидві по ділу: перша брала голий
## Track.new() без розкладених рядів, друга — сцену, де `lanes` нульові, тож усі плитки
## сховані. Обидві перевіряли б порожнечу. Тому логіку винесено в ЧИСТУ функцію.
func test_zsuv_uzdovzh_obnuleno_bez_zazoru() -> void:
	var moved := 0
	for seed_i in range(120):
		for lane in range(3):
			assert_eq(Track.tile_dz(seed_i * 7919, lane, "grid"), 0.0,
				"у «grid» плитки стоять майже впритул — зсуву вздовж бути не може")
			assert_eq(Track.tile_dz(seed_i * 7919, lane, "flat"), 0.0, "у «flat» так само")
			if absf(Track.tile_dz(seed_i * 7919, lane, "base")) > 0.0005:
				moved += 1
	assert_gt(moved, 200, "а в «base» зсув уздовж є — інакше стерегти було б нічого")
