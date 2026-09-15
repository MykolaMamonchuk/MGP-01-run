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
func test_empty_library_changes_nothing() -> void:
	PropLibrary.reload()
	for kind in ["tree", "bush", "fence", "stump", "rock", "flower"]:
		assert_null(PropLibrary.mesh(kind), "%s поки малюється вокселем" % kind)


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
