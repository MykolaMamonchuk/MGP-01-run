## Дозавантаження цеглинки не має ні переплутати порядок записів, ні коштувати сортування.
##
## Звідки взявся: проба 21.09.2026 показала на межі чанка кадр на 24 мс — заїкання рівно там,
## де гравець перетинає стик цеглинок, і на телефоні воно втричі довше. Виявилось, що чотири
## sort_custom із лямбдою (декор, забудова, перешкоди, пікапи) перевпорядковували ВЕСЬ рівень
## щоразу, хоч нова цеглинка цілком лежить праворуч від старої, та й маркери в ній уже по
## порядку. Тепер сортування лишилось як запасний шлях — і саме його легко зламати мовчки:
## порядок, у якому записи лежать, ніде не видно, а _advance_authored() йде по них курсором.
extends GutTest


func _rec(z: float, kind: String = "tree") -> Dictionary:
	return {"z_m": z, "kind": kind}


func _zs(recs: Array) -> Array:
	var out := []
	for r in recs:
		out.append(float((r as Dictionary).get("z_m", 0.0)))
	return out


func test_sorted_by_z_bahchyt_poriadok() -> void:
	assert_true(LevelTimeline.sorted_by_z([]), "порожній список упорядкований")
	assert_true(LevelTimeline.sorted_by_z([_rec(0.0), _rec(1.0), _rec(1.0), _rec(9.0)]),
		"рівні z_m поспіль — це теж порядок")
	assert_false(LevelTimeline.sorted_by_z([_rec(0.0), _rec(9.0), _rec(1.0)]))


## Звичайний випадок: цеглинки йдуть по черзі, новий шматок весь правіше старого.
func test_cherhova_tsehlynka_dopysuietsia_v_kinets() -> void:
	var old_recs := [_rec(1.0), _rec(2.0), _rec(3.0)]
	var merged := LevelTimeline.merge_by_z(old_recs, [_rec(4.0), _rec(5.0)])
	assert_eq(_zs(merged), [1.0, 2.0, 3.0, 4.0, 5.0])


## Запасний шлях: цеглинку поставили не по черзі (бібліотека це дозволяє — та сама цеглинка
## може стояти двічі й на будь-якому зсуві). Тоді порядок мусить відновитись сортуванням.
func test_tsehlynka_ne_po_cherzi_vse_odno_vporiadkovuietsia() -> void:
	var merged := LevelTimeline.merge_by_z([_rec(10.0), _rec(20.0)], [_rec(5.0), _rec(15.0)])
	assert_eq(_zs(merged), [5.0, 10.0, 15.0, 20.0])


## І сам новий шматок може прийти переплутаним — маркери в .tscn лежать у порядку сцени,
## а не в порядку дороги.
func test_pereplutanyi_shmatok_sortuietsia() -> void:
	var merged := LevelTimeline.merge_by_z([], [_rec(7.0), _rec(2.0), _rec(5.0)])
	assert_eq(_zs(merged), [2.0, 5.0, 7.0])


func test_porozhnii_shmatok_nichoho_ne_chipaie() -> void:
	var old_recs := [_rec(1.0), _rec(2.0)]
	assert_eq(_zs(LevelTimeline.merge_by_z(old_recs, [])), [1.0, 2.0])


## Жодного запису не можна загубити: _advance_authored() йде курсором, і зниклий запис —
## це перешкода, якої на дорозі просто не буде, без жодного повідомлення.
func test_zhoden_zapys_ne_hubytsia() -> void:
	var merged := LevelTimeline.merge_by_z([_rec(10.0, "a"), _rec(1.0, "b")],
		[_rec(4.0, "c"), _rec(3.0, "d")])
	assert_eq(merged.size(), 4)
	var kinds := []
	for r in merged:
		kinds.append(String((r as Dictionary).get("kind", "")))
	kinds.sort()
	assert_eq(kinds, ["a", "b", "c", "d"])


## ЧЕРГУВАННЯ — не рідкість, а звичайний випадок. Цеглинка складається з ДВОХ сцен на одному
## зсуві (геометрія та розкладка перешкод), і друга починається з нуля там, де перша вже
## дійшла до півтораста метрів. Заміряно 21.09.2026: стик не сходився ЖОДНОГО разу за прогін,
## тобто дешевий шлях «дописати в кінець» не спрацьовував ніколи, а спрацьовувало повне
## sort_custom на 1600 записів — 7,1 мс, найдорожчий крок усього збирання цеглинки.
## Тепер це справжнє злиття двох упорядкованих списків: 7,4 → 1,1 мс.
func test_dva_shmatky_shcho_cherhuiutsia_zlyvaiutsia_vporiadkovano() -> void:
	var old_recs := [_rec(0.0, "a"), _rec(50.0, "b"), _rec(150.0, "c")]
	var merged := LevelTimeline.merge_by_z(old_recs, [_rec(10.0, "d"), _rec(60.0, "e")])
	assert_eq(_zs(merged), [0.0, 10.0, 50.0, 60.0, 150.0])
	assert_true(LevelTimeline.sorted_by_z(merged), "після злиття список упорядкований")


## Рівні z_m на стику — найлегше місце, де злиття може загубити або подвоїти запис.
func test_rivni_z_na_styku_ne_hubliatsia() -> void:
	var merged := LevelTimeline.merge_by_z([_rec(5.0, "a"), _rec(5.0, "b")],
		[_rec(5.0, "c"), _rec(5.0, "d")])
	assert_eq(merged.size(), 4)
	assert_eq(_zs(merged), [5.0, 5.0, 5.0, 5.0])


## Великий випадок — саме той, на якому міряли: два шматки по кілька сотень, що чергуються.
func test_velyke_zlyttia_nichoho_ne_hubyt() -> void:
	var a := []
	var b := []
	for i in range(400):
		a.append(_rec(float(i) * 2.0, "a"))
		b.append(_rec(float(i) * 2.0 + 1.0, "b"))
	var merged := LevelTimeline.merge_by_z(a, b)
	assert_eq(merged.size(), 800)
	assert_true(LevelTimeline.sorted_by_z(merged), "упорядковано")
	assert_eq(float((merged[0] as Dictionary)["z_m"]), 0.0)
	assert_eq(float((merged[-1] as Dictionary)["z_m"]), 799.0)
