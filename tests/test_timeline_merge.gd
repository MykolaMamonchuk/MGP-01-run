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
