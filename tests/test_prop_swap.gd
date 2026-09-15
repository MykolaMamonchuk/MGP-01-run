## Сім класів, які малюють пропси, після переведення на PropLibrary. Доти жоден із них не
## мав тесту, що РЕАЛЬНО створює вузол — зламану гілку фолбеку помітили б лише в грі, та й то
## не одразу (зірочки, злитки й діорама з'являються не на першому екрані).
##
## Перевіряємо головне: поки data/props.json порожній, кожен має намалюватись вокселем, як і
## раніше. Це і є критерій «підміна нічого не змінила».
extends GutTest


func after_each() -> void:
	PropLibrary.reload()


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


func test_ingot_draws_without_a_model() -> void:
	var i := Ingot3D.new()
	add_child_autofree(i)
	await wait_process_frames(1)
	assert_not_null(_mesh_of(i), "злиток малюється вокселем")


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
