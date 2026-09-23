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
## ще немає. Виправлено викликом Quality.apply() у run3d._ready(). Якщо цей виклик приберуть,
## стан «Плавно» знову мовчки малюватиме тіні, і 22 мс повернуться непоміченими.
func test_run3d_zastosovuie_yakist_sam() -> void:
	var src := FileAccess.open("res://src/run3d/run3d.gd", FileAccess.READ)
	assert_not_null(src, "run3d.gd читається")
	var text := src.get_as_text()
	assert_true(text.contains("Quality.apply()"),
		"run3d має застосовувати якість САМ: автозавантаження робить це до появи сцени")


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
