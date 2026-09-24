## Відсікання дрібного декору за ЕКРАННИМ розміром, а не за метрами.
##
## Ми вже міряли дальність у метрах — вона не дала переваги над рівномірним проріджуванням.
## Причина: великий будинок за сорок метрів і дрібний камінь за двадцять читаються зовсім
## по-різному, а поріг у метрах їх не розрізняє. Тут критерій — частка висоти екрана, як у
## Hill Drive (їхній поріг 0,02 — найчастіший із 8407 у грі).
extends GutTest


func test_velyke_lyshaietsia_dribne_znykaie() -> void:
	# Дерево 4 м і квітка 0,25 м на тій самій відстані 25 м, поріг 2%.
	assert_true(Track.decor_visible(4.0, 1.0, 25.0, 0.02), "дерево за 25 м лишається")
	assert_false(Track.decor_visible(0.25, 1.0, 25.0, 0.02), "квітка за 25 м зникає")
	# Та сама квітка зблизька — лишається.
	assert_true(Track.decor_visible(0.25, 1.0, 5.0, 0.02), "квітка за 5 м лишається")


func test_masshtab_ekzemplyara_vrahovuietsia() -> void:
	# Той самий вид, але вдвічі більший екземпляр, має зникати вдвічі далі.
	var small := Track.decor_visible(0.5, 1.0, 20.0, 0.02)
	var big := Track.decor_visible(0.5, 2.0, 20.0, 0.02)
	assert_false(small, "дрібний екземпляр за 20 м зникає")
	assert_true(big, "удвічі більший на тій самій відстані лишається")


func test_poroh_nul_nichogo_ne_rizhe() -> void:
	for h in [0.05, 0.25, 4.0]:
		for dist in [5.0, 25.0, 60.0]:
			assert_true(Track.decor_visible(h, 1.0, dist, 0.0),
				"поріг 0 означає «не відсікати» — інакше «Гарно» мовчки втратить декор")


## Поріг приходить зі стану якості, а не прибитий у трасі. ТИПОВО ВИМКНЕНО в усіх станах —
## заміряно, що навіть повне прибирання дрібниці не дає нічого: її пікселі домальовує те, що
## за нею, а її колишні 4,3 мс були освітленням на піксель, уже знятим переходом на вершину.
func test_porih_zi_stanu_yakosti() -> void:
	assert_eq(Quality.decor_cull_of(Quality.SMOOTH), 0.0,
		"типово вимкнено: заміряно нуль виграшу, а видима втрата була б")
	assert_eq(Quality.decor_cull_of(Quality.PRETTY), 0.0, "у «Гарно» тим паче")
	assert_eq(Quality.decor_cull_of("казна-що"), Quality.decor_cull_of(Quality.DEFAULT),
		"невідомий стан — це типовий, а не збій")


## І воно справді прибирає екземпляри зі сцени, а не лише рахується на папері.
func test_vidsikannia_spravdi_prybyraie() -> void:
	var track := Track.new()
	add_child_autofree(track)
	await wait_frames(2)
	var worlds: Dictionary = load("res://src/run3d/run3d.gd").load_worlds()
	track.rebuild(worlds.get("forest", {}), false)
	await wait_frames(2)
	track.force_decor_cull(0.0)
	track.call("_sync_decor", 0.016)
	var full := _visible(track)
	track.force_decor_cull(0.02)
	track.call("_sync_decor", 0.016)
	var culled := _visible(track)
	assert_gt(full, 0, "декор має бути, інакше сторож перевіряє порожнечу")
	assert_lt(culled, full, "з порогом видимих екземплярів меншає")


func _visible(track: Track) -> int:
	var n := 0
	for mi in track._decor_mm:
		n += (mi as MultiMeshInstance3D).multimesh.visible_instance_count
	return n
