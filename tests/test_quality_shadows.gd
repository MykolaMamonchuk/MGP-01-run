## Сторож: у стані «Плавно» тіней НЕМА, у «Гарно» — є.
##
## Заміряно на Redmi 8A двома контрольними точками (контролі 0,06% і 0,08%): прохід тіней
## коштує 21-24 мс — чверть кадру. Інші ручки тіней перевірено й вони дають нуль: дальність
## 22 м проти 1 м однаково, роздільність карти 2048/1024/512 у межах шуму. Отже коштує сам
## прохід, і вимикати його треба цілком.
##
## Чому це можна: у героя власний намальований овал тіні (Hero3D._shadow), а не справжня
## тінь від сонця. Підказка «де я стою» лишається завжди.
extends GutTest

var _saved  # що стояло в збереженні до тесту — повертаємо, щоб не псувати інші тести
var _saved_msaa: int


func before_each() -> void:
	_saved = SaveService.setting(Quality.KEY, null)
	_saved_msaa = get_tree().root.msaa_3d


func after_each() -> void:
	Quality.unpin()
	if _saved == null:
		SaveService.data["settings"].erase(Quality.KEY)
		SaveService.save_game()
	else:
		SaveService.set_setting(Quality.KEY, _saved)
	get_tree().root.msaa_3d = _saved_msaa as Viewport.MSAA


func test_plavno_bez_tinei() -> void:
	assert_false(Quality.shadows_of(Quality.SMOOTH),
		"«Плавно» — стан для слабкого телефона, тіні там коштують чверть кадру")


func test_harno_z_tiniamy() -> void:
	assert_true(Quality.shadows_of(Quality.PRETTY), "«Гарно» лишає тіні")
	assert_true(Quality.shadows_of(Quality.MIDDLE), "середній стан лишає тіні")


func test_nevidomyi_stan_bere_typove() -> void:
	assert_eq(Quality.shadows_of("казна-що"), Quality.shadows_of(Quality.DEFAULT),
		"невідомий стан поводиться як типовий, а не падає")


## Сторож проти повторення знайденої вади: Quality._ready() кличе apply() ДО того, як
## існує сцена гри (автозавантаження готові раніше), тож тіні тоді не вимикались — сонця
## ще немає. Виправлено викликом Quality.apply() у run3d._ready().
##
## Перевіряємо НАСЛІДОК, а не наявність рядка в коді: пошук по тексту пройшов би й тоді,
## коли виклик перенесли б у мертву гілку.
func test_scena_hry_sama_zastosovuie_yakist() -> void:
	SaveService.set_setting(Quality.KEY, Quality.PRETTY)
	get_tree().root.msaa_3d = Viewport.MSAA_DISABLED   # завідомо НЕ те, що дає «Гарно»
	var run: Node = load("res://src/run3d/run3d.tscn").instantiate()
	add_child_autofree(run)
	await wait_frames(3)
	assert_eq(get_tree().root.msaa_3d, Quality.msaa_of(Quality.PRETTY),
		"сцена гри має застосувати якість САМА: автозавантаження робить це до її появи")
	assert_true((run.get_node("Sun") as DirectionalLight3D).shadow_enabled,
		"і тінь теж — це властивість світла, якого на момент автозавантаження ще немає")


## Прибитий стан для замірів сильніший за збереження: інструменти ставлять його ДО сцени,
## і run3d._ready() не має права його перетерти. Без цього ручка QUALITY= у tools/probe
## мовчки міряла б стан із save.json — та сама вада, що й таймер, який перебивав вибір.
func test_prybytyi_stan_perezhyvaie_stvorennia_sceny() -> void:
	SaveService.set_setting(Quality.KEY, Quality.SMOOTH)
	Quality.apply_state(Quality.PRETTY)
	var run: Node = load("res://src/run3d/run3d.tscn").instantiate()
	add_child_autofree(run)
	await wait_frames(3)
	assert_eq(get_tree().root.msaa_3d, Quality.msaa_of(Quality.PRETTY),
		"прибитий заміром стан має пережити створення сцени")
	assert_true((run.get_node("Sun") as DirectionalLight3D).shadow_enabled,
		"і тінь теж")
	# Але вибір дорослого сильніший за прибите.
	Quality.set_current(Quality.SMOOTH)
	assert_false((run.get_node("Sun") as DirectionalLight3D).shadow_enabled,
		"вибір у налаштуваннях знімає прибитий стан")


## Сторож проти ДРУГОЇ, дорожчої вади: риштування для замірів щосекунди перебивало вибір.
## Таймер у run3d кликав _reapply_strip() у звичайній грі, а той при порожньому списку
## прапорців ПИСАВ сонцю тінь назад. Три кадри тесту цього не ловили — таймер спрацьовує
## через секунду; на телефоні це було видно як «якість smooth · тінь так».
func test_doslid_ne_povertaie_tin_vsuperech_yakosti() -> void:
	SaveService.set_setting(Quality.KEY, Quality.SMOOTH)
	var run: Node = load("res://src/run3d/run3d.tscn").instantiate()
	add_child_autofree(run)
	await wait_frames(3)
	var sun: DirectionalLight3D = run.get_node("Sun")
	assert_false(sun.shadow_enabled, "на старті «Плавно» гасить тінь")
	# Саме те, що робив таймер щосекунди у звичайній грі.
	run.call("_reapply_strip")
	assert_false(sun.shadow_enabled, "повтор досліду НЕ повертає тінь усупереч якості")
	# І навпаки: у «Гарно» тінь є, а прапорець досліду може її забрати.
	SaveService.set_setting(Quality.KEY, Quality.PRETTY)
	run.call("_reapply_strip")
	assert_true(sun.shadow_enabled, "у «Гарно» тінь малюється")
	run.call("debug_strip", PackedStringArray(["shadows"]))
	assert_false(sun.shadow_enabled, "прапорець досліду гасить тінь і в «Гарно»")
	SaveService.set_setting(Quality.KEY, Quality.SMOOTH)


## Сторож на ТРЕТЮ вроду того самого: дослід не має права ПОКАЗАТИ те, що світ сховав.
## `_reapply_strip()` писав `visible = not прапорець` для десятка шарів, і при порожньому
## списку вмикав їх назад. Через це на морському світі проба «вмикала» плитку дороги, кадр
## із БУДЬ-ЯКИМ прапорцем показував пісок замість моря, і з цього народився хибний висновок
## про вартість основи дороги.
func test_doslid_ne_pokazuie_shovane() -> void:
	var run: Node = load("res://src/run3d/run3d.tscn").instantiate()
	add_child_autofree(run)
	await wait_frames(3)
	var tr: Node3D = run.get_node("Track")
	tr.visible = false                      # так світ ховає шар (напр. вода замість дороги)
	run.call("debug_strip", PackedStringArray(["hero"]))   # ІНШИЙ прапорець
	assert_false(tr.visible, "чужий прапорець не має вмикати сховане")
	run.call("debug_strip", PackedStringArray([]))
	assert_false(tr.visible, "і порожній список теж не має")
	# А своїм прапорцем — ховає й повертає рівно те, що було.
	tr.visible = true
	run.call("debug_strip", PackedStringArray(["track"]))
	assert_false(tr.visible, "своїм прапорцем ховає")
	run.call("debug_strip", PackedStringArray([]))
	assert_true(tr.visible, "і повертає видиме, яким воно було")


## Сторож: дослід не стирає матеріали й параметри, яких не просили чіпати.
## `mi.material_override = simple_water` стояло БЕЗ УМОВИ, а simple_water при відсутності
## водяних прапорців — null. Тобто будь-який дослід стирав шейдер води, і канали сіріли
## від прапорця `fog` так само, як від `roadbase`.
func test_doslid_ne_styraie_chuzhi_materialy() -> void:
	var run: Node = load("res://src/run3d/run3d.tscn").instantiate()
	add_child_autofree(run)
	await wait_frames(3)
	var track: Node = run.get_node("Track")
	var water = track.get("_water")
	assert_not_null(water, "вода в трасі є")
	var before = (water as MeshInstance3D).material_override
	run.call("debug_strip", PackedStringArray(["fog"]))
	assert_eq((water as MeshInstance3D).material_override, before,
		"чужий прапорець не має чіпати матеріал води")
	run.call("debug_strip", PackedStringArray([]))
	assert_eq((water as MeshInstance3D).material_override, before,
		"і порожній список теж")


## Туман: у «Плавно» його малюють ЗАВІСИ, у «Гарно» — справжній Environment.fog.
func test_tuman_zalezhyt_vid_yakosti() -> void:
	assert_false(Quality.real_fog_of(Quality.SMOOTH), "«Плавно» — завіси, не справжній туман")
	assert_true(Quality.real_fog_of(Quality.PRETTY), "«Гарно» — справжній туман")
	assert_true(Quality.real_fog_of(Quality.MIDDLE), "«Середнє» — теж справжній")
	assert_eq(Quality.real_fog_of("казна-що"), Quality.real_fog_of(Quality.DEFAULT),
		"невідомий стан — це типовий, а не збій")


## І це доходить до сцени, причому НА ЛЬОТУ: дорослий міняє якість на екрані батьків, не
## перезапускаючи гру. Сторож проти повернення вади «налаштування не доходить до сцени».
func test_scena_perekliuchaie_tuman_na_lotu() -> void:
	SaveService.set_setting(Quality.KEY, Quality.SMOOTH)
	var run: Node = load("res://src/run3d/run3d.tscn").instantiate()
	add_child_autofree(run)
	await wait_frames(3)
	var e: Environment = (run.get_node("WorldEnvironment") as WorldEnvironment).environment
	var hz: Node = run.get_node("Haze")
	assert_false(e.fog_enabled, "у «Плавно» справжнього туману нема")
	assert_true(hz.call("is_enabled"), "натомість є завіси")
	Quality.set_current(Quality.PRETTY)
	await wait_frames(2)
	assert_true(e.fog_enabled, "у «Гарно» туман вмикається без перезапуску")
	assert_false(hz.call("is_enabled"), "а завіси гаснуть")
	SaveService.set_setting(Quality.KEY, Quality.SMOOTH)


## Масштаб рендера: у «Плавно» 3D малюється в меншому буфері, у «Гарно» — у повному.
func test_masshtab_rendera_zalezhyt_vid_yakosti() -> void:
	assert_almost_eq(Quality.scale_of(Quality.SMOOTH), 0.87, 0.001,
		"«Плавно» — 0,87: заміряно 9,1 мс виграшу, і оком не видно")
	assert_almost_eq(Quality.scale_of(Quality.PRETTY), 1.0, 0.001, "«Гарно» — повний")
	assert_almost_eq(Quality.scale_of("казна-що"), Quality.scale_of(Quality.DEFAULT), 0.001,
		"невідомий стан — це типовий, а не збій")


## І це доходить до в'юпорта, причому дослід не має права перебити вибір дорослого:
## прапорець scaleNN лише ПЕРЕКРИВАЄ, а базою лишається якість.
func test_doslid_ne_navyazuie_povnyi_masshtab() -> void:
	SaveService.set_setting(Quality.KEY, Quality.SMOOTH)
	var run: Node = load("res://src/run3d/run3d.tscn").instantiate()
	add_child_autofree(run)
	await wait_frames(3)
	var vp := get_tree().root
	assert_almost_eq(vp.scaling_3d_scale, 0.87, 0.001, "у «Плавно» буфер менший")
	run.call("debug_strip", PackedStringArray(["scale70"]))
	assert_almost_eq(vp.scaling_3d_scale, 0.70, 0.001, "прапорець досліду перекриває")
	run.call("debug_strip", PackedStringArray([]))
	assert_almost_eq(vp.scaling_3d_scale, 0.87, 0.001,
		"без прапорця повертається вибір якості, а НЕ одиниця")
	vp.scaling_3d_scale = 1.0


## Освітлення декору на вершину: половина виграшу від повного вимкнення, але грані цілі.
func test_svitlo_dekoru_na_vershynu_zalezhyt_vid_yakosti() -> void:
	assert_true(Quality.vertex_lit_of(Quality.SMOOTH), "«Плавно» — на вершину: -6,9 мс")
	assert_false(Quality.vertex_lit_of(Quality.PRETTY), "«Гарно» — на піксель")
	assert_eq(Quality.vertex_lit_of("казна-що"), Quality.vertex_lit_of(Quality.DEFAULT),
		"невідомий стан — це типовий, а не збій")


## І це доходить до МАТЕРІАЛІВ декору, зокрема до шарів, заведених ПІЗНІШЕ: вони
## створюються ліниво, у міру того як їде траса.
func test_dekor_distaie_rezhym_zatinennia() -> void:
	SaveService.set_setting(Quality.KEY, Quality.SMOOTH)
	var run: Node = load("res://src/run3d/run3d.tscn").instantiate()
	add_child_autofree(run)
	await wait_frames(3)
	run.set("_demo_any_level", true)
	run.call("_start_level", 1)
	await wait_frames(10)
	var mms: Array = run.get_node("Track").get("_decor_mm")
	assert_gt(mms.size(), 10, "шари декору мають існувати, інакше сторож перевіряє порожнечу")
	var per_vertex := 0
	var total := 0
	for mm in mms:
		var mesh = (mm as MultiMeshInstance3D).multimesh.mesh
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var bm = mesh.surface_get_material(0)
		if bm == null:
			continue
		total += 1
		if bm.shading_mode == BaseMaterial3D.SHADING_MODE_PER_VERTEX:
			per_vertex += 1
	assert_eq(per_vertex, total, "у «Плавно» ВСІ шари декору рахують світло на вершину")
	# А вибір дорослого повертає на піксель, без перезапуску.
	Quality.set_current(Quality.PRETTY)
	await wait_frames(2)
	var back := 0
	for mm in mms:
		var mesh = (mm as MultiMeshInstance3D).multimesh.mesh
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var bm = mesh.surface_get_material(0)
		if bm != null and bm.shading_mode != BaseMaterial3D.SHADING_MODE_PER_VERTEX:
			back += 1
	assert_eq(back, total, "у «Гарно» всі повертаються на піксель")
	SaveService.set_setting(Quality.KEY, Quality.SMOOTH)
