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
