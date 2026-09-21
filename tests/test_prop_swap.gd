## Сім класів, які малюють пропси, після переведення на PropLibrary. Доти жоден із них не
## мав тесту, що РЕАЛЬНО створює вузол — зламану гілку фолбеку помітили б лише в грі, та й то
## не одразу (зірочки, злитки й діорама з'являються не на першому екрані).
##
## Перевіряємо головне: поки data/props.json порожній, кожен має намалюватись вокселем, як і
## раніше. Це і є критерій «підміна нічого не змінила».
extends GutTest


func after_each() -> void:
	PropLibrary.reload()


## Дані світу читаємо файлом, а не через Run3D: у run3d.gd немає class_name, тож із тестів
## він не видний, та й тест ДАНИХ не повинен залежати від ігрового коду.
func _world(id: String) -> Dictionary:
	var f := FileAccess.open("res://data/worlds/%s.json" % id, FileAccess.READ)
	assert_not_null(f, "світ %s читається" % id)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _mesh_of(n: Node) -> MeshInstance3D:
	for c in n.get_children():
		if c is MeshInstance3D:
			return c as MeshInstance3D
		var deeper := _mesh_of(c)
		if deeper != null:
			return deeper
	return null


func test_star_draws_without_a_model() -> void:
	var s := Star3D.new()
	add_child_autofree(s)
	await wait_process_frames(1)
	assert_not_null(_mesh_of(s), "зірочка-збиралка малюється вокселем, поки моделі нема")


## Злиток меша в собі не тримає — його малює MultiMesh у Spawner3D. Але запасний воксель має
## знаходитись так само, як і раніше: без моделі гра не сміє лишитись без злитків.
func test_ingot_draws_without_a_model() -> void:
	assert_not_null(Ingot3D.mesh_for(false), "злиток малюється вокселем")
	assert_not_null(Ingot3D.mesh_for(true), "великий — теж")


## Бабка створює меш у setup(), а не в _ready() — на цьому перший варіант тесту й спіймався.
func test_dragonfly_draws_without_a_model() -> void:
	var d := Dragonfly3D.new()
	add_child_autofree(d)
	d.setup(null, 6.0)
	await wait_process_frames(1)
	assert_not_null(_mesh_of(d), "бабка малюється вокселем")


func test_critter_draws_without_a_model() -> void:
	var c := Critter3D.new()
	add_child_autofree(c)
	c.setup("bunny", {})
	await wait_process_frames(1)
	assert_not_null(_mesh_of(c), "зайчик малюється вокселем")


func test_magpie_draws_without_a_model() -> void:
	var m := Magpie3D.new()
	add_child_autofree(m)
	await wait_process_frames(1)
	assert_not_null(_mesh_of(m), "сорока малюється вокселем")


## І найголовніше: коли модель З'ЯВИТЬСЯ, вона має підмінити воксель — саме заради цього
## усе й переписувалось. Перевіряємо на самому шві, бо підставляти справжню модель у тест
## означало б тягнути в репозиторій .glb лише заради нього.
func test_model_wins_over_voxel_when_present() -> void:
	PropLibrary.use({"star": "res://vendor/cartoon_eye_3d/CartoonEye3D.tscn"})
	var from_model := PropLibrary.node_for("star")
	assert_not_null(from_model, "є модель — PropLibrary віддає готовий MeshInstance3D")
	assert_not_null(from_model.mesh, "і в ньому справді є меш")
	from_model.free()

	PropLibrary.use({})
	assert_null(PropLibrary.node_for("star"), "моделі нема — віддає null, і виклик бере воксель")


## Перетемування світу 1: `prop` — цільова модель, `voxel` — чим малюємо, поки її нема.
## Якби ці поля злили в одне, VoxelBuilder малював би рожевий куб «файлу не знайдено»
## для чотирьох видів, моделей яких ще не існує (cart_market, bush_flower, banner_line, goose).
func test_world_one_obstacles_name_their_target_model() -> void:
	var world := _world("meadow")
	var obs: Dictionary = world.get("obstacles", {})
	assert_false(obs.is_empty(), "світ 1 має перешкоди")

	var with_target := 0
	for kind in obs.keys():
		var def: Dictionary = obs[kind]
		if not def.has("prop"):
			continue
		with_target += 1
		# воксель мусить існувати ЗАВЖДИ — інакше до появи моделі буде рожевий куб
		var voxel := String(def.get("voxel", kind))
		assert_true(FileAccess.file_exists("res://data/voxels/%s.json" % voxel),
			"%s: запасний воксель %s на місці" % [kind, voxel])
	# Число росте разом зі світом і саме тому прибите: кожна нова перешкода з `prop` має
	# бути свідомим рішенням, а не з'явитись непоміченою. 10 → 11 (21.09.2026): додано
	# goose_walk — гуска, що ПЕРЕБІГАЄ дорогу. Бочка, що котиться, у Лужку вже була
	# (beehive із anim "roll"), просто нею ніхто не користувався.
	assert_eq(with_target, 11, "перешкоди першої черги з названою цільовою моделлю")


## І сам шов: коли модель зʼявиться під іменем із `prop`, вона має підмінити воксель.
func test_target_model_wins_when_it_appears() -> void:
	# Назву цільової моделі НЕ тримаємо в коді сталою. Колись пеньок цілився в «ящик», бо
	# власної моделі не було; коли вона з'явилась, тест упав на заглушці, а не на ваді.
	# Перевіряти треба сам шов: що названа модель підміняє воксель.
	var stump: Dictionary = _world("meadow")["obstacles"]["stump"]
	var target := String(stump.get("prop", ""))
	assert_ne(target, "", "пеньок називає цільову модель")

	PropLibrary.use({target: "res://vendor/cartoon_eye_3d/CartoonEye3D.tscn"})
	assert_not_null(PropLibrary.mesh(target), "модель знайдена — саме вона й малюватиметься")
	PropLibrary.use({})
	assert_null(PropLibrary.mesh(target), "моделі нема — лишається воксель пенька")


## Кожна перешкода першого світу мусить називати модель, яка СПРАВДІ є. Помилка в імені не
## падає й ніде не світиться — перешкода просто мовчки лишається кубиком, і помітити це можна
## лише оком у грі. Саме так довго жили гілка (малювалась гірляндою прапорців) і пеньок
## (малювався ящиком): назва вела не туди, куди треба, і ніхто цього не бачив.
func test_world_one_obstacle_models_actually_exist() -> void:
	var props = JSON.parse_string(FileAccess.open("res://data/props.json",
		FileAccess.READ).get_as_text())
	assert_eq(typeof(props), TYPE_DICTIONARY, "список моделей читається")
	if typeof(props) != TYPE_DICTIONARY:
		return
	var obs: Dictionary = _world("meadow").get("obstacles", {})
	var missing := []
	for kind in obs.keys():
		var def: Dictionary = obs[kind]
		var target := String(def.get("prop", ""))
		if target != "" and not (props as Dictionary).has(target):
			missing.append("%s → %s" % [kind, target])
	missing.sort()
	assert_true(missing.is_empty(),
		"перешкоди Лужка називають наявні моделі, а не порожнечу: %s" % [missing])


## Доведення моделі (scale / yaw_deg у data/props.json) має СПРАВДІ застосовуватись.
## Довго воно існувало лише в PropLibrary й нікуди не доходило: у props.json можна було
## написати будь-який масштаб, і нічого не мінялось.
func test_model_scale_and_yaw_reach_the_obstacle() -> void:
	var def := {"voxel": "stump", "prop": "crate", "box": [0.7, 0.7, 0.7], "action": "jump"}

	PropLibrary.use({})
	var plain := Obstacle3D.new()
	add_child_autofree(plain)
	plain.setup("stump", def, 0, true)
	var base: float = plain._mesh.scale.x

	PropLibrary.use({"crate": {"path": "res://vendor/cartoon_eye_3d/CartoonEye3D.tscn",
		"scale": 2.0, "yaw_deg": 90.0}})
	var tuned := Obstacle3D.new()
	add_child_autofree(tuned)
	tuned.setup("stump", def, 0, true)

	assert_almost_eq(tuned._mesh.scale.x, base * 2.0, 0.001, "масштаб із props.json застосувався")
	assert_almost_eq(tuned._mesh.rotation.y, deg_to_rad(90.0), 0.001, "і поворот теж")


## Наскрізна перевірка ланцюга: світ каже «вулик цілиться в бочку» → у props.json є модель
## бочки → Obstacle3D мусить малювати САМЕ ЇЇ, а не воксель вулика. Доти перевіряли лише
## кінці ланцюга окремо, і розрив посередині ніхто б не помітив.
func test_real_model_reaches_the_obstacle_in_game() -> void:
	PropLibrary.reload()                       # справжній data/props.json
	var barrel := PropLibrary.mesh("barrel")
	if barrel == null:
		pass_test("моделі бочки ще нема — крок пропущено")
		return

	var def: Dictionary = _world("meadow")["obstacles"]["beehive"]
	assert_eq(String(def.get("prop", "")), "barrel", "вулик цілиться в бочку")

	var o := Obstacle3D.new()
	add_child_autofree(o)
	o.setup("beehive", def, 0, true)
	# бочок у props.json кілька РІЗНИХ типів, і екземпляр бере свій — тож звіряємо не з
	# однією моделлю, а з набором: вимога тут «не воксель, а якась із бочок»
	var all_barrels: Array = []
	for i in maxi(PropLibrary.variants("barrel"), 1):
		all_barrels.append(PropLibrary.mesh("barrel", i))
	assert_true(all_barrels.has(o._mesh.mesh), "перешкода малюється мешем МОДЕЛІ, а не вокселя")
