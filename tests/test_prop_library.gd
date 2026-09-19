## Бібліотека пропсів: підміна згенерованого вокселя справжньою моделлю.
##
## Сенс у тому, що підміна має бути НЕПОМІТНОЮ для решти гри: розкладка рівнів, маркери й
## `kind` лишаються ті самі, змінюється лише те, звідки береться меш. І головне — поки
## моделі нема, все мусить працювати рівно як раніше.
extends GutTest

const HERO_MESH := "res://vendor/cartoon_eye_3d/CartoonEye3D.tscn"   # будь-яка сцена з мешем


func after_each() -> void:
	PropLibrary.reload()          # повертаємо справжній data/props.json наступним тестам


func test_unknown_kind_has_no_model() -> void:
	PropLibrary.use({})
	assert_false(PropLibrary.has("tree"), "для невідомого виду моделі нема")
	assert_null(PropLibrary.mesh("tree"), "і меша нема — Track має взяти воксель")


## Найважливіше: порожній data/props.json не має нічого міняти. Саме так воно й лежить у
## репозиторії зараз — моделей ще нема, і гра мусить малювати вокселі, як малювала.
## Вид, якого нема в props.json, мусить тихо лишитись на вокселі, а не впасти. Перевіряємо
## це на ВИГАДАНИХ іменах навмисно: раніше тут стояли справжні («bush», «tree»), і тест
## падав щоразу, коли черговий вид отримував модель — тобто карав саме за те, заради чого
## уся ця робота й робиться.
func test_unknown_kinds_stay_on_voxel() -> void:
	PropLibrary.reload()
	for kind in ["такого_виду_нема", "zzz_test_kind", "вигадка_42"]:
		assert_null(PropLibrary.mesh(kind), "%s: моделі нема — лишається воксель" % kind)
	assert_false(PropLibrary.has("такого_виду_нема"), "і бібліотека це визнає")


func test_missing_file_falls_back_to_voxel() -> void:
	PropLibrary.use({"tree": "res://assets/props/нема_такого.glb"})
	assert_false(PropLibrary.has("tree"), "шлях є, а файлу нема — вважаємо, що моделі нема")
	assert_null(PropLibrary.mesh("tree"), "і меша не даємо, а не падаємо")


func test_known_kind_returns_a_mesh() -> void:
	PropLibrary.use({"tree": HERO_MESH})
	assert_true(PropLibrary.has("tree"), "файл на місці — модель є")
	assert_not_null(PropLibrary.mesh("tree"), "віддає меш для MultiMesh-пачки декору")


## Запис може бути як простим рядком, так і об'єктом із доведенням масштабу/повороту:
## модель із генератора майже ніколи не приходить одразу в потрібному розмірі.
func test_entry_may_be_a_string_or_a_dict_with_tweaks() -> void:
	PropLibrary.use({"tree": HERO_MESH})
	var plain := PropLibrary.tweak("tree")
	assert_almost_eq(float(plain["scale"]), 1.0, 0.001, "рядком — масштаб типово 1.0")

	PropLibrary.use({"tree": {"path": HERO_MESH, "scale": 1.4, "yaw_deg": 90.0}})
	var tuned := PropLibrary.tweak("tree")
	assert_almost_eq(float(tuned["scale"]), 1.4, 0.001, "об'єктом — свій масштаб")
	assert_almost_eq(float(tuned["yaw_deg"]), 90.0, 0.001, "і свій поворот")


## Ключі, що починаються з "_", — коментарі у файлі, а не пропси.
func test_underscore_keys_are_comments_not_props() -> void:
	PropLibrary.reload()
	assert_false(PropLibrary.has("_note"), "_note — не вид пропса")


## node_for() — спільний хелпер для дев'яти місць (Tier2Segment, Ingot3D, Critter3D, …),
## які раніше самі писали "мій MeshInstance3D із мешем моделі, або нічого".
func test_node_for_returns_mesh_instance_when_model_exists() -> void:
	PropLibrary.use({"tree": HERO_MESH})
	var mi := PropLibrary.node_for("tree")
	assert_not_null(mi, "модель є — маємо готовий MeshInstance3D")
	assert_not_null(mi.mesh, "і в ньому вже стоїть меш моделі")
	mi.free()


func test_node_for_returns_null_when_no_model() -> void:
	PropLibrary.use({})
	assert_null(PropLibrary.node_for("tree"), "моделі нема — виклик бере VoxelBuilder.instance() сам")


func test_node_for_returns_null_for_broken_path() -> void:
	PropLibrary.use({"tree": "res://assets/props/нема_такого.glb"})
	assert_null(PropLibrary.node_for("tree"), "шлях є, а файлу нема — так само null, а не помилка")


## Кілька РІЗНИХ типів під одним ключем (три бочки). Перевіряємо саме те, заради чого це
## зроблено: типи не змішуються між собою — меш і доведення завжди від однієї моделі.
func test_variants_counts_list() -> void:
	PropLibrary.use({"barrel": ["res://a.glb", "res://b.glb", "res://c.glb"]})
	assert_eq(PropLibrary.variants("barrel"), 3, "три типи бочки")
	assert_eq(PropLibrary.variants("cart"), 0, "виду нема — типів нуль")
	PropLibrary.use({"cart": "res://one.glb"})
	assert_eq(PropLibrary.variants("cart"), 1, "один шлях рядком — один тип")


func test_tweak_is_per_variant() -> void:
	PropLibrary.use({"barrel": [
		{"path": "res://a.glb", "scale": 1.0},
		{"path": "res://b.glb", "scale": 2.5, "yaw_deg": 90.0}]})
	assert_eq(float(PropLibrary.tweak("barrel", 0)["scale"]), 1.0, "доведення першого типу")
	assert_eq(float(PropLibrary.tweak("barrel", 1)["scale"]), 2.5, "доведення другого типу")
	assert_eq(float(PropLibrary.tweak("barrel", 1)["yaw_deg"]), 90.0, "поворот другого типу")


## Номер за межами списку не має валити малювання: props.json можуть перечитати між тим,
## як тип вибрали, і тим, як його малюють.
func test_variant_out_of_range_falls_back() -> void:
	PropLibrary.use({"barrel": [{"path": "res://a.glb", "scale": 1.5}]})
	assert_eq(float(PropLibrary.tweak("barrel", 7)["scale"]), 1.5, "береться перший тип")


func test_pick_stays_inside_list() -> void:
	PropLibrary.use({"barrel": ["res://a.glb", "res://b.glb", "res://c.glb"]})
	for w in ["meadow", "forest", "city", "beach", "clouds"]:
		PropLibrary.use_world(w)
		assert_between(PropLibrary.pick("barrel"), 0, 2, "вибраний тип у межах списку")
	assert_eq(PropLibrary.pick("nothing"), 0, "виду нема — нульовий тип")


## Одна мапа — один тип. Це не оптимізація, а вимога вигляду: типи різняться пропорціями
## (поручні бувають 0,26 і 0,41 м), і змішані на одній вулиці читаються як помилка.
func test_one_map_keeps_one_type() -> void:
	PropLibrary.use({"barrel": ["res://a.glb", "res://b.glb", "res://c.glb"]})
	PropLibrary.use_world("meadow")
	var first := PropLibrary.pick("barrel")
	for i in 50:
		assert_eq(PropLibrary.pick("barrel"), first, "тип не міняється в межах мапи")


## …але МІЖ мапами типи мають різнитись, інакше решта моделей ніколи не потрапить у гру.
func test_maps_differ_from_each_other() -> void:
	PropLibrary.use({"barrel": ["res://a.glb", "res://b.glb", "res://c.glb"]})
	var seen := {}
	for w in ["meadow", "forest", "city", "beach", "clouds", "cave", "sky", "night"]:
		PropLibrary.use_world(w)
		seen[PropLibrary.pick("barrel")] = true
	assert_gt(seen.size(), 1, "різні мапи беруть різні типи")


## Кожен .glb у assets/props мусить бути КОМУСЬ потрібен — тобто згаданий у data/props.json.
##
## Навіщо. Модель заміняють кращою, стару лишають «про всяк випадок», і вона тихо лежить далі.
## Шкода не в мегабайтах: такий файл потрапляє в аркуші приймання (tools/prop_sheet.py,
## tools/prop_sides.py) і виглядає там як вміст гри, хоча в грі його нема. На цьому вже
## згаяли час: cart_market.glb на аркуші рендерився майже прозорим, бо в ньому взагалі нема
## матеріалу — і питання «чому модель зламана» коштувало розслідування, хоча правильна
## відповідь була «вона не вживається з минулого року».
##
## Зворотний бік — шлях у props.json, за яким файлу нема, — ловить
## test_missing_file_falls_back_to_voxel вище (гра переживає це, малюючи воксель).
func test_every_model_file_is_referenced_from_props_json() -> void:
	var f := FileAccess.open("res://data/props.json", FileAccess.READ)
	var text := f.get_as_text()
	var dir := DirAccess.open("res://assets/props")
	assert_not_null(dir, "тека моделей є")
	var names := dir.get_files()
	names.sort()
	var orphans := []
	var checked := 0
	for name in names:
		if not name.ends_with(".glb"):
			continue
		checked += 1
		if not text.contains(name):
			orphans.append(name)
	assert_gt(checked, 0, "моделі знайшлись — інакше сторож стереже порожнечу")
	assert_eq(orphans, [],
		("моделі, на які не веде жоден запис data/props.json: %s. Або вписати їх, або "
		+ "прибрати — інакше вони й далі виглядатимуть вмістом гри в аркушах приймання")
		% [orphans])
