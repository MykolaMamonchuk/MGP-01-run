## Валідатор описів чанків (`ChunkDescriptor`) — на СИНТЕТИЧНИХ описах у пам'яті.
##
## Головне, що тут доводиться: валідатор справді ЧЕРВОНІЄ на зіпсованому вході. Метрика, яка
## не спіймала завідомо зламаний випадок, зелена завжди й не стереже нічого (memory bank,
## «спершу порахуй, потім подивись»). Тому на кожне правило тут є зіпсований опис.
##
## Описи створюються тут-таки, у пам'яті: жодного файлу-фікстури в репозиторії. Єдиний виняток —
## останній тест, який перевіряє сам ОБХІД ДИСКА (те, чим користується CLI): він робить тимчасову
## теку в `user://` і прибирає її за собою.
##
## Сьогодні описів ще нема, і перший тест від цього зелений: перевіряти нічого — не помилка.
extends GutTest

const TMP_DIR := "user://test_chunk_descriptors"


## Світи й файли, з якими звіряється опис. Синтетичні: справжні дані тут ні до чого — правило
## перевіряється правилом, а не знімком data/worlds.
func _ctx(extra := {}) -> Dictionary:
	var ctx := {
		"worlds": {
			# Лужок уміє й ухил, Ліс — ні: на цьому й ловиться дія, якої в одному зі світів нема.
			"meadow": {"obstacles": ["stump", "fence", "puddle"], "actions": ["jump", "side", "duck"]},
			"forest": {"obstacles": ["tree", "web"], "actions": ["jump", "side"]},
		},
		"files": ["chunk.json", "chunk.tscn", "layout_easy.tscn", "layout_hard.tscn"],
		"dir": "river_01",
		"source": "",
	}
	for k in extra:
		ctx[k] = extra[k]
	return ctx


## Здоровий опис — від нього відштовхуються всі зіпсовані.
func _good() -> Dictionary:
	return {
		"id": "river_01",
		"length_m": 150,
		"entry_lanes": 3,
		"exit_lanes": 3,
		"worlds": ["meadow", "forest"],
		"layouts": [
			{"file": "layout_easy.tscn", "difficulty": [0.0, 0.4], "actions": ["jump"]},
			{"file": "layout_hard.tscn", "difficulty": [0.4, 1.0], "actions": ["jump", "side"]},
		],
	}


func _broken(changes: Dictionary) -> Dictionary:
	var desc := _good()
	for k in changes:
		if changes[k] == null:
			desc.erase(k)
		else:
			desc[k] = changes[k]
	return desc


## Помилки є, і серед них є та, про яку тест. Текст перевіряється по фрагменту: важливо, щоб
## автор чанка прочитав, ЩО саме не так, а не лише «невалідно».
func _assert_complains(desc: Dictionary, fragment: String, why: String, ctx := {}) -> void:
	var errors := ChunkDescriptor.errors(desc, _ctx(ctx))
	assert_gt(errors.size(), 0, "%s — валідатор мусить почервоніти" % why)
	assert_true(", ".join(errors).contains(fragment),
		"%s — у скарзі мусить бути «%s», а сказано: %s" % [why, fragment, ", ".join(errors)])


# --- сьогодні: описів ще нема ---------------------------------------------------------------

## Зелений сьогодні (жодного chunk.json у проєкті) і лишиться осмисленим завтра: щойно описи
## з'являться, цей самий тест почне перевіряти справжні.
func test_the_project_library_has_no_broken_descriptors() -> void:
	var problems := ChunkDescriptor.report()
	assert_eq(problems.size(), 0, "описи чанків у проєкті: %s" % ", ".join(problems))


func test_a_healthy_descriptor_passes() -> void:
	var errors := ChunkDescriptor.errors(_good(), _ctx())
	assert_eq(errors.size(), 0, "здоровий опис не має скарг, а сказано: %s" % ", ".join(errors))


# --- обов'язкові поля і типи ----------------------------------------------------------------

func test_every_required_field_is_missed_when_absent() -> void:
	for field in ChunkDescriptor.REQUIRED:
		_assert_complains(_broken({field: null}), field, "нема поля «%s»" % field)


func test_a_typo_in_a_field_name_is_not_ignored() -> void:
	var desc := _broken({"lenght_m": 150})
	_assert_complains(desc, "lenght_m", "друкарська помилка в назві поля")


func test_wrong_types_are_caught() -> void:
	_assert_complains(_broken({"id": 7}), "id", "id числом")
	_assert_complains(_broken({"length_m": "150"}), "length_m", "довжина рядком")
	_assert_complains(_broken({"worlds": "meadow"}), "worlds", "світи рядком замість списку")
	_assert_complains(_broken({"layouts": {}}), "layouts", "layout'и словником замість списку")


func test_the_id_must_match_the_folder_name() -> void:
	_assert_complains(_broken({"id": "river_02"}), "тека", "id розійшовся з текою")


# --- довжина --------------------------------------------------------------------------------

func test_length_must_be_positive() -> void:
	_assert_complains(_broken({"length_m": 0}), "додатною", "нульова довжина")
	_assert_complains(_broken({"length_m": -150}), "додатною", "від'ємна довжина")


## LOOKAHEAD_M = 80: коротший чанк не встигає підтягнутись за один update()
## (docs/tasks/level-chunk-library.md, пункт 2).
func test_a_chunk_shorter_than_the_lookahead_is_refused() -> void:
	_assert_complains(_broken({"length_m": 50}), "LOOKAHEAD_M", "коротший за заглядання вперед")
	_assert_complains(_broken({"length_m": 79.9}), "LOOKAHEAD_M", "на волосок коротший")


func test_lengths_that_the_loader_can_carry_pass() -> void:
	for length in [80, 100, 150, 300, 450]:
		var errors := ChunkDescriptor.errors(_broken({"length_m": length}), _ctx())
		assert_eq(errors.size(), 0, "довжина %s м допустима, а сказано: %s"
			% [length, ", ".join(errors)])


# --- доріжки й сумісність -------------------------------------------------------------------

func test_lanes_outside_three_five_seven_are_refused() -> void:
	for lanes in [0, 1, 4, 6, 8]:
		_assert_complains(_broken({"entry_lanes": lanes}), "3, 5 або 7",
			"вхід на %d доріжок" % lanes)
		_assert_complains(_broken({"exit_lanes": lanes}), "3, 5 або 7",
			"вихід на %d доріжок" % lanes)


func test_a_sequence_of_matching_chunks_is_accepted() -> void:
	var by_id := {
		"a": {"entry_lanes": 3, "exit_lanes": 3},
		"widen": {"entry_lanes": 3, "exit_lanes": 5},
		"b": {"entry_lanes": 5, "exit_lanes": 5},
	}
	var errors := ChunkDescriptor.sequence_errors(["a", "widen", "b"], by_id)
	assert_eq(errors.size(), 0, "послідовність сходиться, а сказано: %s" % ", ".join(errors))


func test_a_broken_seam_names_both_chunks() -> void:
	var by_id := {
		"a": {"entry_lanes": 3, "exit_lanes": 3},
		"b": {"entry_lanes": 5, "exit_lanes": 5},
	}
	var errors := ChunkDescriptor.sequence_errors(["a", "b"], by_id)
	assert_eq(errors.size(), 1, "рівно одна скарга на стик")
	assert_true(errors[0].contains("a") and errors[0].contains("b"),
		"у скарзі названі обидва чанки: %s" % errors[0])


func test_an_unknown_chunk_in_a_sequence_is_named() -> void:
	var errors := ChunkDescriptor.sequence_errors(["a", "нема_такого"], {"a": {"exit_lanes": 3}})
	assert_gt(errors.size(), 0, "невідомий чанк у послідовності — помилка")
	assert_true(", ".join(errors).contains("нема_такого"), "названо саме його: %s" % ", ".join(errors))


# --- світи ----------------------------------------------------------------------------------

func test_only_real_worlds_are_allowed() -> void:
	_assert_complains(_broken({"worlds": ["medow"]}), "medow", "світу з таким ім'ям немає")
	_assert_complains(_broken({"worlds": []}), "порожній", "жодного світу")


# --- layout'и -------------------------------------------------------------------------------

func test_a_missing_layout_scene_is_caught() -> void:
	var desc := _broken({"layouts": [
		{"file": "layout_none.tscn", "difficulty": [0.0, 1.0], "actions": ["jump"]},
	]})
	_assert_complains(desc, "немає поруч", "файлу layout'а немає на диску")


func test_difficulty_range_must_be_inside_zero_one_and_not_inverted() -> void:
	var out_of_range := _broken({"layouts": [
		{"file": "layout_easy.tscn", "difficulty": [0.0, 1.4], "actions": ["jump"]},
	]})
	_assert_complains(out_of_range, "0..1", "діапазон вийшов за 0..1")
	var inverted := _broken({"layouts": [
		{"file": "layout_easy.tscn", "difficulty": [0.8, 0.2], "actions": ["jump"]},
		{"file": "layout_hard.tscn", "difficulty": [0.0, 1.0], "actions": ["jump"]},
	]})
	_assert_complains(inverted, "перевернута", "діапазон від більшого до меншого")


## Дірка в покритті — саме та мовчазна вада, заради якої валідатор і пишеться: на складності
## 0.4–0.6 чанк не мав би що показати.
func test_a_hole_in_the_difficulty_coverage_is_caught() -> void:
	var desc := _broken({"layouts": [
		{"file": "layout_easy.tscn", "difficulty": [0.0, 0.4], "actions": ["jump"]},
		{"file": "layout_hard.tscn", "difficulty": [0.6, 1.0], "actions": ["jump"]},
	]})
	_assert_complains(desc, "не покрита", "дірка посеред діапазону")


func test_coverage_that_stops_short_of_the_ends_is_caught() -> void:
	var tail := _broken({"layouts": [
		{"file": "layout_easy.tscn", "difficulty": [0.0, 0.9], "actions": ["jump"]},
	]})
	_assert_complains(tail, "не покрита", "найскладніше лишилось без layout'а")
	var head := _broken({"layouts": [
		{"file": "layout_easy.tscn", "difficulty": [0.1, 1.0], "actions": ["jump"]},
	]})
	_assert_complains(head, "не покрита", "найлегше лишилось без layout'а")


func test_overlapping_ranges_are_fine() -> void:
	var desc := _broken({"layouts": [
		{"file": "layout_easy.tscn", "difficulty": [0.0, 0.6], "actions": ["jump"]},
		{"file": "layout_hard.tscn", "difficulty": [0.4, 1.0], "actions": ["jump"]},
	]})
	var errors := ChunkDescriptor.errors(desc, _ctx())
	assert_eq(errors.size(), 0, "перекриття діапазонів дозволене, а сказано: %s" % ", ".join(errors))


# --- перешкоди ------------------------------------------------------------------------------

func test_an_obstacle_that_no_world_has_is_caught() -> void:
	var desc := _broken({"layouts": [
		{"file": "layout_easy.tscn", "difficulty": [0.0, 1.0], "obstacles": ["дракон"]},
	]})
	_assert_complains(desc, "дракон", "перешкоди немає в жодному світі")


## Найпідступніший випадок: перешкода існує, але лише в ОДНОМУ із заявлених світів. На другому
## світі той самий layout мовчки поставив би невідомий вид. Скарга мусить ще й пояснити, куди
## дивитись: для кількох світів пінять ДІЮ, а не вид (спільних видів між світами майже нема).
func test_an_obstacle_missing_in_one_declared_world_is_caught() -> void:
	var desc := _broken({"layouts": [
		{"file": "layout_easy.tscn", "difficulty": [0.0, 1.0], "obstacles": ["fence"]},
	]})
	_assert_complains(desc, "forest", "«fence» є в Лужку, але не в Лісі")
	_assert_complains(desc, "actions", "скарга підказує вживати дії")


## Вид, пінений для чанка на ОДИН світ, — законний виняток.
func test_pinning_a_kind_is_fine_for_a_single_world_chunk() -> void:
	var desc := _broken({
		"worlds": ["meadow"],
		"layouts": [
			{"file": "layout_easy.tscn", "difficulty": [0.0, 1.0], "obstacles": ["fence"]},
		],
	})
	var errors := ChunkDescriptor.errors(desc, _ctx())
	assert_eq(errors.size(), 0, "вид у чанка на один світ дозволений, а сказано: %s"
		% ", ".join(errors))


# --- дії ------------------------------------------------------------------------------------

## Заради чого й заведені дії: `jump` є в обох світах, тож багатосвітовий layout на діях живе.
func test_actions_that_every_declared_world_has_pass() -> void:
	var desc := _broken({"layouts": [
		{"file": "layout_easy.tscn", "difficulty": [0.0, 1.0], "actions": ["jump", "side"]},
	]})
	var errors := ChunkDescriptor.errors(desc, _ctx())
	assert_eq(errors.size(), 0, "дії є в обох світах, а сказано: %s" % ", ".join(errors))


func test_an_action_the_game_does_not_know_is_caught() -> void:
	var desc := _broken({"layouts": [
		{"file": "layout_easy.tscn", "difficulty": [0.0, 1.0], "actions": ["fly"]},
	]})
	_assert_complains(desc, "fly", "такої дії гра не знає")


## Дія є в одному заявленому світі й нема в другому — там маркер не було б чим наповнити.
func test_an_action_missing_in_one_declared_world_names_the_world() -> void:
	var desc := _broken({"layouts": [
		{"file": "layout_easy.tscn", "difficulty": [0.0, 1.0], "actions": ["duck"]},
	]})
	_assert_complains(desc, "forest", "у Лісі немає перешкод з дією duck")
	_assert_complains(desc, "duck", "названа саме дія")


func test_a_layout_with_neither_actions_nor_obstacles_describes_nothing() -> void:
	var empty := _broken({"layouts": [
		{"file": "layout_easy.tscn", "difficulty": [0.0, 1.0]},
	]})
	_assert_complains(empty, "нічого не описує", "layout без дій і без видів")
	var both_empty := _broken({"layouts": [
		{"file": "layout_easy.tscn", "difficulty": [0.0, 1.0], "actions": [], "obstacles": []},
	]})
	_assert_complains(both_empty, "нічого не описує", "обидва списки порожні")


# --- вибір layout'а -------------------------------------------------------------------------

## pick_layout() читає з опису самі layout'и — решта полів їй ні до чого, тож і в тестах їх нема.
func _with_layouts(layouts: Array) -> Dictionary:
	return {"id": "river_01", "layouts": layouts}


## Ім'я вибраного файлу; "" — не вибрано нічого. Так тест каже про ПРАВИЛО («виграв вужчий»),
## а не порівнює словники цілком.
func _picked(desc: Dictionary, difficulty: float, allowed := []) -> String:
	return String(ChunkDescriptor.pick_layout(desc, difficulty, allowed).get("file", ""))


## Обидва краї включні — та сама семантика, що в Difficulty.fits() і в перевірці покриття.
## Автор пише [0.3, 0.7] і має право розраховувати, що рівно 0.3 і рівно 0.7 — це «так».
func test_both_edges_of_the_difficulty_range_are_inclusive() -> void:
	var desc := _with_layouts([
		{"file": "layout_easy.tscn", "difficulty": [0.3, 0.7], "actions": ["jump"]},
	])
	for d in [0.3, 0.5, 0.7]:
		assert_eq(_picked(desc, d), "layout_easy.tscn",
			"складність %.2f у діапазоні [0.3, 0.7] — разом із краями" % d)
	for d in [0.29, 0.71]:
		assert_eq(_picked(desc, d), "",
			"складність %.2f поза діапазоном — брати нема чого" % d)


## Перевернутий діапазон — авторська помилка (валідатор на неї червоніє), і вибір її не
## «виправляє»: такий layout не підходить нікому.
func test_an_inverted_range_is_never_picked() -> void:
	var desc := _with_layouts([
		{"file": "layout_easy.tscn", "difficulty": [0.8, 0.2], "actions": ["jump"]},
	])
	for d in [0.1, 0.5, 0.9]:
		assert_eq(_picked(desc, d), "", "перевернутий діапазон не годиться й на %.2f" % d)


## Широкий 0..1 — це «запасний»: він написаний, щоб чанк мав що показати будь-де, і сам по собі
## нічого не каже про цю складність. Вузький автор зробив НАВМИСНО під неї — отже, він точніший
## і має вигравати, у якому б порядку вони не стояли.
func test_the_narrower_range_wins_over_the_wide_fallback() -> void:
	var narrow := {"file": "layout_hard.tscn", "difficulty": [0.4, 0.5], "actions": ["jump"]}
	var wide := {"file": "layout_easy.tscn", "difficulty": [0.0, 1.0], "actions": ["jump"]}
	assert_eq(_picked(_with_layouts([wide, narrow]), 0.45), "layout_hard.tscn",
		"вужчий виграє, стоячи другим")
	assert_eq(_picked(_with_layouts([narrow, wide]), 0.45), "layout_hard.tscn",
		"і стоячи першим — порядок тут нічого не вирішує")
	assert_eq(_picked(_with_layouts([wide, narrow]), 0.9), "layout_easy.tscn",
		"за межами вузького лишається запасний — на те він і запасний")


## За ОДНАКОВОЇ ширини виграє перший у списку: порядок у файлі — воля автора, і вона ж вирішує
## на стику діапазонів. Тест дивиться на обидва порядки, щоб правило не вийшло випадковістю
## обходу списку.
func test_equal_widths_keep_the_order_the_author_wrote() -> void:
	var first := {"file": "layout_easy.tscn", "difficulty": [0.0, 0.5], "actions": ["jump"]}
	var second := {"file": "layout_hard.tscn", "difficulty": [0.2, 0.7], "actions": ["jump"]}
	assert_eq(_picked(_with_layouts([first, second]), 0.3), "layout_easy.tscn",
		"обидва діапазони завширшки 0.5 — виграє написаний першим")
	assert_eq(_picked(_with_layouts([second, first]), 0.3), "layout_hard.tscn",
		"переставили місцями — виграє той, що тепер перший")


## Порожній allowed_obstacles — це «рівень не обмежує»: у data/levels.json порожній
## obstacle_types означає «всі типи біому» (рівні 4, 8, 11, 14, 17), а не «жодного».
func test_an_empty_allowed_list_does_not_forbid_anything() -> void:
	var desc := _with_layouts([
		{"file": "layout_easy.tscn", "difficulty": [0.0, 1.0], "obstacles": ["fence"]},
	])
	assert_eq(_picked(desc, 0.5, []), "layout_easy.tscn",
		"рівень нічого не обмежує — пін виду годиться")


## Пін виду — обіцянка поставити саме цю модель, і рівень мусить уміти її виконати. Бракує хоч
## одного виду зі списку — layout не годиться, навіть якщо він точніше націлений на складність.
func test_a_layout_pinning_a_forbidden_kind_is_skipped() -> void:
	var desc := _with_layouts([
		{"file": "layout_hard.tscn", "difficulty": [0.4, 0.5], "obstacles": ["stump", "fence"]},
		{"file": "layout_easy.tscn", "difficulty": [0.0, 1.0], "actions": ["jump"]},
	])
	assert_eq(_picked(desc, 0.45, ["stump"]), "layout_easy.tscn",
		"«fence» рівень не дозволяє — вужчий layout відпадає попри точніше націлення")
	assert_eq(_picked(desc, 0.45, ["stump", "fence"]), "layout_hard.tscn",
		"дозволені обидва види — той самий вужчий уже виграє")


## Layout на ДІЯХ обмеження за видами не стосується: маркер каже «тут перестрибнути», а модель
## підставить світ — уже з оглядом на obstacle_types рівня (крок 2½).
func test_an_action_layout_is_not_filtered_by_allowed_kinds() -> void:
	var desc := _with_layouts([
		{"file": "layout_easy.tscn", "difficulty": [0.0, 1.0], "actions": ["jump", "side"]},
	])
	assert_eq(_picked(desc, 0.5, ["rock"]), "layout_easy.tscn",
		"жодного спільного виду з рівнем, а layout на діях однаково годиться")


## Порожнеча — чесна відповідь, а не привід вигадати. Покриття всього 0..1 стереже валідатор,
## тож порожньо тут стає лише тоді, коли рівень просить заборонені види — і той, хто кличе,
## мусить це побачити, а не дістати підсунутий «хоч якийсь» layout.
func test_nothing_suitable_returns_an_empty_dictionary() -> void:
	var pinned := _with_layouts([
		{"file": "layout_easy.tscn", "difficulty": [0.0, 1.0], "obstacles": ["fence"]},
	])
	assert_true(ChunkDescriptor.pick_layout(pinned, 0.5, ["stump"]).is_empty(),
		"єдиний layout пінить заборонений вид — вибору немає")
	assert_true(ChunkDescriptor.pick_layout(_with_layouts([]), 0.5, []).is_empty(),
		"layout'ів нема взагалі")
	assert_true(ChunkDescriptor.pick_layout({}, 0.5, []).is_empty(),
		"опис без поля «layouts» теж нічого не дає")


# --- обхід диска (те, чим користується CLI) -------------------------------------------------

## Перевіряє не правило, а ПОШУК: що report() знаходить chunk.json у теці й доносить скаргу
## з іменем файлу. Тимчасова тека в user://, у репозиторії нічого не лишається.
func test_the_scan_finds_a_descriptor_on_disk_and_names_the_file() -> void:
	var dir_path := TMP_DIR.path_join("river_01")
	DirAccess.make_dir_recursive_absolute(dir_path)
	var f := FileAccess.open(dir_path.path_join("chunk.json"), FileAccess.WRITE)
	# Довжина 10 м — завідомо зіпсований опис: коротший за LOOKAHEAD_M.
	f.store_string('{"id": "river_01", "length_m": 10, "entry_lanes": 3, "exit_lanes": 3,'
		+ ' "worlds": ["meadow"], "layouts": []}')
	f.close()

	var found := ChunkDescriptor.find_descriptors(TMP_DIR)
	assert_eq(found.size(), 1, "знайдено рівно один опис: %s" % ", ".join(found))
	# Послідовності рівнів тут не перевіряємо: у тимчасовій бібліотеці свої id.
	var problems := ChunkDescriptor.report(TMP_DIR, ChunkDescriptor.WORLDS_DIR, "")
	assert_gt(problems.size(), 0, "зіпсований опис на диску — валідатор червоніє")
	assert_true(", ".join(problems).contains("chunk.json"),
		"у скарзі названо файл: %s" % ", ".join(problems))

	DirAccess.remove_absolute(dir_path.path_join("chunk.json"))
	DirAccess.remove_absolute(dir_path)
	DirAccess.remove_absolute(TMP_DIR)
