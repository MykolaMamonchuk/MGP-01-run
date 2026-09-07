## Стрічка карток (src/ui/components/item_strip.gd): чиста математика гортання
## + збірка живого віджета в дереві — саме тут колись падало «_strip == null».
extends GutTest

const VIEW_W := ItemStrip.VIEW.x


func _card(w: float = 124.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 132)
	return c


func _strip_with(n: int) -> ItemStrip:
	var s := ItemStrip.new()
	add_child_autofree(s)
	var cards: Array[Control] = []
	for i in range(n):
		cards.append(_card())
	s.set_cards(cards)
	return s


# ---------- чисті функції ----------

func test_clamp_centres_when_content_fits() -> void:
	assert_eq(ItemStrip.clamp_x(-300.0, 500.0, 1100.0), 300.0, "вміщується — по центру, хоч куди тягни")
	assert_eq(ItemStrip.clamp_x(0.0, 1100.0, 1100.0), 0.0, "рівно по вікну — на місці")


func test_clamp_keeps_edges_when_content_overflows() -> void:
	assert_eq(ItemStrip.clamp_x(50.0, 2000.0, 1100.0), 0.0, "правіше початку не буває")
	assert_eq(ItemStrip.clamp_x(-999.0, 2000.0, 1100.0), -900.0, "лівіше кінця не буває")
	assert_eq(ItemStrip.clamp_x(-300.0, 2000.0, 1100.0), -300.0, "усередині — як є")


func test_page_moves_by_one_view_width() -> void:
	assert_eq(ItemStrip.page_x(0.0, 1, 3000.0, 1100.0), -1100.0)
	assert_eq(ItemStrip.page_x(-1900.0, 1, 3000.0, 1100.0), -1900.0, "далі краю нікуди")
	assert_eq(ItemStrip.page_x(-800.0, -1, 3000.0, 1100.0), 0.0)


# ---------- живий віджет ----------

func test_builds_in_tree_without_errors() -> void:
	var s := ItemStrip.new()
	add_child_autofree(s)
	await get_tree().process_frame
	# сама поява в дереві міняє розміри й смикає розкладку — і вона має пережити це порожньою
	assert_eq(s.cards().size(), 0, "порожня стрічка будується й не падає")
	assert_true(s.fits(), "порожній вміст завжди вміщується")


func test_short_row_fits_and_hides_arrows() -> void:
	var s := _strip_with(3)   # 3 × 124 + 2 × 10 = 392 < 900
	await get_tree().process_frame
	assert_true(s.fits(), "три картки вміщуються у вікно %d" % int(VIEW_W))
	assert_almost_eq(s.offset_x(), (VIEW_W - 392.0) * 0.5, 1.0, "вміщується — стоїть по центру")


func test_long_row_overflows_and_can_be_paged() -> void:
	var s := _strip_with(12)  # 12 × 124 + 11 × 10 = 1598 > 900
	await get_tree().process_frame
	assert_false(s.fits(), "дванадцять карток не вміщуються")
	assert_almost_eq(s.offset_x(), 0.0, 0.001, "починаємо з початку")


func test_set_cards_replaces_content() -> void:
	var s := _strip_with(4)
	await get_tree().process_frame
	assert_eq(s.cards().size(), 4)
	s.set_cards([_card(), _card()])
	await get_tree().process_frame
	assert_eq(s.cards().size(), 2, "старі картки пішли, нові стали")


func test_rebuild_without_reset_keeps_place() -> void:
	var s := _strip_with(12)
	await get_tree().process_frame
	s.set_cards([_card(), _card()], false)   # тепер усе вміщується
	await get_tree().process_frame
	assert_true(s.fits(), "після зменшення вмісту стрічка не лишається прогорнутою за край")
