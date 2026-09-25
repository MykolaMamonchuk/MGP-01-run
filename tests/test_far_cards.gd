## КАРТКИ ДАЛЕКИХ ХАТ: яка хата йде в окремий шар «farL» (дослід 25.09).
##
## Хати лугу стоять двома смугами: ближня за 7-9 м від осі дороги, дальня за 10-15 м. Дальню
## можна малювати плоскою карткою, знятою під кутом ігрової камери, — але лише ЛІВОРУЧ, де всі
## далекі хати стоять під одним поворотом (90°): картка знята саме з такої хати.
extends GutTest


## Поділ на шари — лише для досліду (Track.far_cards_split); тут його вмикаємо і завжди
## повертаємо, щоб не протік у решту набору.
func before_each() -> void:
	Track.far_cards_split = true


func after_each() -> void:
	Track.far_cards_split = false


## У звичайній грі далекі хати НЕ діляться: окремий шар — це зайвий виклик малювання на кожен
## вид хати (і ще один у тіні). Рецензія 25.09 знайшла, що поділ ішов і в релізі.
func test_u_zvychainii_hri_podilu_nema() -> void:
	Track.far_cards_split = false
	assert_eq(Track.far_card_tag("house_terra_3", -12.0, 90.0), "",
		"без досліду далека хата лишається в спільному шарі")


func _world(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/worlds/%s.json" % name, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


## Той самий шлях, яким іде гра: записи цеглинки → прогрів → декорування. Далека хата мусить
## мати СВІЙ шар «#farL» уже після прогріву, а не заводити його посеред бігу; без досліду —
## жодного зайвого шару взагалі.
func test_shar_dalekoi_khaty_ie_vzhe_pislia_prohrivu() -> void:
	var near := {"z_m": 20.0, "kind": "house_terra_3", "x_m": -8.0, "yaw_deg": 90.0}
	var far := {"z_m": 20.0, "kind": "house_terra_3", "x_m": -12.0, "yaw_deg": 90.0}
	for split in [true, false]:
		Track.far_cards_split = split
		var t := Track.new()
		add_child_autofree(t)
		await wait_process_frames(2)
		t.rebuild(_world("meadow"), false)
		await wait_process_frames(2)
		t.add_authored_timeline([], [near, far])
		var keys: Array = t._decor_layer_of.keys().map(func(k): return String(k))
		var far_layers := keys.filter(func(k): return k.begins_with("house_terra_3") and k.contains("#farL"))
		if split:
			assert_eq(far_layers.size(), 1, "у досліді далека хата має свій шар уже після прогріву")
		else:
			assert_eq(far_layers.size(), 0, "без досліду шару #farL нема")


func test_daleka_liva_khata_do_kartky() -> void:
	assert_eq(Track.far_card_tag("house_terra_3", -12.0, 90.0), "farL",
		"хата ліворуч за 12 м під поворотом 90° — у шар картки")
	assert_eq(Track.far_card_tag("house_terra", -10.0, 90.0), "farL",
		"рівно на межі — теж далека")


func test_blyzhnia_i_prava_lyshaiutsia_3d() -> void:
	assert_eq(Track.far_card_tag("house_terra_3", -8.0, 90.0), "",
		"ближня смуга (7-9 м) лишається тривимірною")
	assert_eq(Track.far_card_tag("house_terra_3", 12.0, 90.0), "",
		"праворуч повороти розкидані — картка не лягає, лишається 3D")


func test_inshyi_povorot_ne_do_kartky() -> void:
	# Картку знімали з хати під поворотом 90°. Хата під іншим кутом на ній виглядала б не
	# собою — тож лише 90°, з допуском на округлення.
	assert_eq(Track.far_card_tag("house_terra_3", -12.0, 180.0), "",
		"хата під іншим поворотом лишається тривимірною")
	assert_eq(Track.far_card_tag("house_terra_3", -12.0, 450.0), "farL",
		"450° — це ті самі 90°")


func test_lyshe_khaty_terra() -> void:
	# Картки зняті лише для house_terra*. Інший будинок у шарі картки лишився б без неї.
	for k in ["house_red", "mill", "kiosk", "tree"]:
		assert_eq(Track.far_card_tag(k, -12.0, 90.0), "", "%s — не house_terra" % k)


## Кожен вид, що може потрапити в шар картки, мусить мати знімок і запис у cards.json —
## інакше підміна мовчки лишить 3D, і дослід міряв би не те.
func test_kartky_ie_dlia_vsikh_vydiv() -> void:
	var f := FileAccess.open("res://assets/props/_exp/cards/cards.json", FileAccess.READ)
	assert_not_null(f, "cards.json є")
	var meta: Dictionary = JSON.parse_string(f.get_as_text())
	for k in ["house_terra", "house_terra_1", "house_terra_2", "house_terra_3", "house_terra_4",
			"house_terra_5", "house_terra_6", "house_terra_7", "house_terra_9"]:
		assert_true(meta.has(k), "%s є в cards.json" % k)
		assert_true(ResourceLoader.exists("res://assets/props/_exp/cards/%s_L.png" % k),
			"%s має знімок картки" % k)
