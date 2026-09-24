## Track.set_authored_timeline()/clear_authored_timeline() — Phase 1 «level-authoring plumbing».
## Той самий стиль інваріантів, що й tests/test_track_batching.gd (visible == recorded);
## тут ще й перевіряємо, що жоден authored-запис не губиться й не дублюється при перевкладанні.
extends GutTest

var _track: Track


func _world(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/worlds/%s.json" % name, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func before_each() -> void:
	_track = Track.new()
	# ВІДСІКАННЯ ДРІБНИЦІ ВИМИКАЄМО. Ці сторожі перевіряють ОБЛІК: що видимих екземплярів
	# рівно стільки, скільки записів, і що при перевкладанні рядів нема подвійного рахунку.
	# Відсікання за екранним розміром навмисно робить видимих МЕНШЕ, і з увімкненим порогом
	# тест міряв би не облік, а поріг. Саме відсікання стережуть окремі тести.
	_track.force_decor_cull(0.0)
	add_child_autofree(_track)
	await wait_process_frames(2)


func _records() -> int:
	var n := 0
	for ids in _track._decor_ids:
		n += (ids as PackedInt32Array).size()
	return n


## Скільки записів САМЕ цього виду. Рахувати всі не можна: авторські маркери кладуться
## ПОВЕРХ звичайного оздоблення (кущі, каміння, бочки вздовж берега), і в загальному числі
## вони тонуть. Раніше оздоблення для авторських рядів вимикалось, через що рівень після
## першої довжини траси ставав порожнім — див. Track._decorate().
## ВАЖЛИВО про вибір виду в цих тестах: він мусить бути таким, якого НЕ ставить фонове
## оздоблення. Мало перевірити пули світу — траса домішує в узбіччя ще й будівлі, які дитина
## добудувала в діорамі (data/buildings.json). На цьому вже спіймався «lantern»: тест
## рахував 8 замість 7, і зайвий предмет був не помилкою розкладки, а чужим ліхтарем.
func _records_of(kind: String) -> int:
	var layers := {}
	for key in _track._decor_layer_of.keys():
		if String(key).split("|")[0].split("#")[0] == kind:
			layers[int(_track._decor_layer_of[key])] = true
	var n := 0
	for ids in _track._decor_ids:
		for j in (ids as PackedInt32Array).size():
			if layers.has((ids as PackedInt32Array)[j]):
				n += 1
	return n


func _visible() -> int:
	var n := 0
	for mi in _track._decor_mm:
		n += (mi.multimesh as MultiMesh).visible_instance_count
	return n


func _flat_records(count: int, step: float = 4.0, kind: String = "signpost") -> Array:
	var out := []
	for i in range(count):
		out.append({
			"z_m": float(i) * step, "x_m": 0.5, "y_m": 0.0,
			"kind": kind, "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0,
		})
	return out


func test_authored_decor_placed_exactly_once_and_matches_visible() -> void:
	var records := _flat_records(10)   # z_m 0..36 — усі в початковому вікні рядів (~-5.5..38.5)
	_track.set_authored_timeline(records, [])
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_eq(_records_of("signpost"), 10, "усі 10 authored-записів потрапили рівно по одному разу")
	assert_eq(_visible(), _records(), "видимих інстансів рівно стільки, скільки записано")


func test_authored_decor_survives_full_row_wrap_without_double_counting() -> void:
	var records := _flat_records(10)
	_track.set_authored_timeline(records, [])
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	# проїхати більше, ніж довжина траси: кожен ряд перевкладеться щонайменше раз
	for i in range(Track.ROWS + 8):
		_track.advance(1.0)
	await wait_process_frames(2)
	assert_eq(_visible(), _records(), "після перевкладання рядів облік і далі збігається (нема подвійного рахунку)")


func test_authored_buildings_are_placed_via_same_add_decor_path() -> void:
	var buildings := [{"z_m": 5.0, "x_m": 3.0, "y_m": 0.0, "kind": "balloon", "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.2}]
	_track.set_authored_timeline([], buildings)
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_eq(_records_of("balloon"), 1, "будинок з authored-списку теж пишеться у _decor_ids/_decor_data")
	assert_eq(_visible(), _records(), "облік збігається з видимим")


func test_unknown_authored_kind_is_skipped_not_crashed() -> void:
	var records := [{"z_m": 5.0, "x_m": 0.0, "y_m": 0.0, "kind": "no_such_voxel_xyz", "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0}]
	_track.set_authored_timeline(records, [])
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_eq(_records_of("no_such_voxel_xyz"), 0, "неіснуючий voxel-kind мовчки пропускається (як і у випадковому декорі)")


## Регресія: без authored-таймлайну (типовий стан для всіх 17 рівнів, поки що) поведінка та сама,
## що й до цієї фічі — лужок і далі засаджується випадковим декором (tests/test_track_batching.gd).
func test_no_authored_timeline_keeps_procedural_decor() -> void:
	assert_false(_track._authored_active, "без set_authored_timeline() трек лишається процедурним за замовчуванням")
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_gt(_records(), 60, "лужок і далі засаджений випадковим декором")
	assert_eq(_visible(), _records())


func test_clear_authored_timeline_restores_procedural_decor() -> void:
	_track.set_authored_timeline(_flat_records(3), [])
	assert_true(_track._authored_active)
	_track.clear_authored_timeline()
	assert_false(_track._authored_active)
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_gt(_records(), 60, "після clear_authored_timeline() лужок знову засаджений випадковим декором")


## add_authored_timeline() — LevelChunkLoader дозавантажує наступний чанк "на ходу": попередні
## записи не зникають, нові додаються поверх (обидва — той самий шлях _add_decor()/_decorate()).
func test_add_authored_timeline_appends_without_clearing_existing() -> void:
	_track.set_authored_timeline(_flat_records(4), [])
	_track.add_authored_timeline(_flat_records(3, 4.0, "balloon"), [])
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_eq(_records_of("signpost") + _records_of("balloon"), 7, "4 із set_ + 3 із add_ — усі 7 на місці")
	assert_eq(_visible(), _records(), "облік збігається з видимим")


## Записи наступного чанку лежать ДАЛІ за поточне вікно рядів — з'являються щойно ряди
## перевкладаються настільки, щоб дістати до їхнього z_m (той самий wrap, що й основний тест).
func test_add_authored_timeline_new_records_appear_after_wrap() -> void:
	_track.set_authored_timeline(_flat_records(2), [])   # z_m 0, 4 — у початковому вікні
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_eq(_records_of("signpost"), 2)
	var far := [{"z_m": 100.0, "x_m": 0.5, "y_m": 0.0, "kind": "balloon", "lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0}]
	_track.add_authored_timeline(far, [])
	assert_eq(_records_of("signpost") + _records_of("balloon"), 2,
		"далекий запис ще не потрапив у жоден ряд одразу після дозавантаження")
	# вікно рядів — приблизно [distance-5.5, distance+38.5] (44 ряди): на distance=100 у вікні
	# лише z_m=100 (стартові 0/4 давно проскочили позаду й перевклались під нові записи —
	# так само, як і будь-який процедурний декор, це не стосується add_authored_timeline)
	for i in range(100):
		_track.advance(1.0)
	await wait_process_frames(2)
	assert_eq(_records_of("balloon"), 1, "далекий запис із дозавантаженого чанку з'явився у своєму ряду")


## Авторський місток: маркер каже ЛИШЕ «тут місток і на цьому борті», а розмір і точне місце
## рахує траса. Без цього він був НЕДОТЯГНУТИЙ — загальний шлях _add_authored_record клав базову
## дошку 2.2 м через канал Лужка завширшки 3.0, і настил обривався над водою. Помітити це
## тестом було нічим: жоден рівень маркерів bridge_plank не вживав, а поручні вже вміли
## розступатись перед авторським містком, тож половина задуму виглядала робочою.
const DECOR_STRIDE := 7   ## x, y, зсув, поворот, масштаб, фаза, розтяг — див. Track._add_decor()


## Усі екземпляри виду: [{x, stretch}]. Беремо саме з _decor_data, бо розтяг живе лише там.
func _instances_of(kind: String) -> Array:
	var layers := {}
	for key in _track._decor_layer_of.keys():
		if String(key).split("|")[0].split("#")[0] == kind:
			layers[int(_track._decor_layer_of[key])] = true
	var out := []
	for row in _track._decor_ids.size():
		var ids: PackedInt32Array = _track._decor_ids[row]
		var data: PackedFloat32Array = _track._decor_data[row]
		for j in ids.size():
			if layers.has(ids[j]):
				out.append({"x": data[j * DECOR_STRIDE], "stretch": data[j * DECOR_STRIDE + 6]})
	return out


func _bridge_marker(z: float, x: float) -> Dictionary:
	return {"z_m": z, "x_m": x, "y_m": 0.0, "kind": "bridge_plank", "lane": 0,
		"override": {}, "yaw_deg": 0.0, "scale": 1.0}


func test_authored_bridge_spans_the_canal_instead_of_stopping_over_water() -> void:
	var world := _world("meadow")
	_track.set_authored_timeline([_bridge_marker(10.0, -2.0)], [])
	_track.rebuild(world, false)
	await wait_process_frames(2)
	var canal: Dictionary = world["canal"]
	var c_width := float(canal["width"])
	var deck := Track.bridge_deck_len(c_width)
	# Довжина настилу — це базова дошка, розтягнута рівно під канал. Саме розтяг і був 1.0.
	var want_stretch := deck / 2.2
	var found := []
	for inst in _instances_of("bridge_plank"):
		# процедурні містки в Лужку теж є (bridges_every = 9) — беремо лише лівий борт біля z=10
		if float(inst["x"]) < 0.0:
			found.append(inst)
	assert_gt(found.size(), 0, "місток лівого борту поставлено")
	for inst in found:
		assert_almost_eq(float(inst["stretch"]), want_stretch, 0.01,
			"настил розтягнуто під ширину каналу %.1f м, а не лишився базовою дошкою" % c_width)
		assert_gt(absf(float(inst["x"])) - deck * 0.5, _track.road_width() * 0.5,
			"настил не залазить на дорогу")


## Знак x у маркері обирає БОРТ, а сама величина не важить: канал стоїть там, де його поставив
## світ, і підганяти число руками автор не може — воно залежить і від світу, і від ширини дороги.
func test_only_the_sign_of_x_matters_for_an_authored_bridge() -> void:
	var world := _world("meadow")
	_track.set_authored_timeline([_bridge_marker(10.0, -0.3), _bridge_marker(14.0, -9.0)], [])
	_track.rebuild(world, false)
	await wait_process_frames(2)
	var xs := {}
	for inst in _instances_of("bridge_plank"):
		if float(inst["x"]) < 0.0:
			xs["%.3f" % float(inst["x"])] = true
	assert_eq(xs.size(), 1, "обидва маркери дали місток на тому самому місці: %s" % xs.keys())


## Борт без каналу містка не дістає — інакше настил висів би над травою.
func test_authored_bridge_is_skipped_on_a_side_without_a_canal() -> void:
	var world := _world("forest")     # Ліс: canal.side = none
	_track.set_authored_timeline([_bridge_marker(10.0, -2.0)], [])
	_track.rebuild(world, false)
	await wait_process_frames(2)
	assert_eq(_instances_of("bridge_plank").size(), 0, "у Лісі каналу нема — містка теж")
