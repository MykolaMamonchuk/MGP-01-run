## CartoonMouth3DIntegrated (vendor/cartoon_mouth_3d) — вендорний 3D-рот, зараз на пробі на
## лисі (rig_face.mouth_scene). Не наш код, тож перевіряємо тільки те, на що спирається
## Hero3D: структура, пози (відкриття/усмішка/нейтраль) і що воно взагалі вантажиться.
extends GutTest

const SCENE := "res://vendor/cartoon_mouth_3d/CartoonMouth3DIntegrated.tscn"

var _mouth: CartoonMouth3DIntegrated


func before_each() -> void:
	_mouth = (load(SCENE) as PackedScene).instantiate() as CartoonMouth3DIntegrated
	add_child_autofree(_mouth)
	await wait_process_frames(1)


func test_structure_has_named_parts() -> void:
	for part in ["Socket", "MouthInside", "UpperLip", "LowerJawPivot", "ArcUpper", "ArcLower"]:
		assert_not_null(_mouth.get_node_or_null(part), "є вузол %s" % part)
	assert_not_null(_mouth.get_node_or_null("LowerJawPivot/LowerLip"), "нижня губа — на щелепі")
	assert_not_null(_mouth.get_node_or_null("LowerJawPivot/Tongue"), "язик — на щелепі")


## Відкриття розводить дві дуги рота: верхня лишається лінією губ, нижня провисає, і між
## ними з'являється темна порожнина. (Раніше це був поворот еліпсоїда-щелепи — але пласкі
## губи-еліпсоїди читались як пряма риска, тож рот тепер малюється мультяшною дугою.)
func test_open_amount_parts_the_two_arcs() -> void:
	var lo := _mouth.get_node("ArcLower") as MeshInstance3D
	var inside := _mouth.get_node("MouthInside") as Node3D
	var closed_bottom: float = lo.mesh.get_aabb().position.y
	assert_false(inside.visible, "стулений рот — жодної темної щілини")

	_mouth.open_amount = 1.0
	assert_lt(lo.mesh.get_aabb().position.y, closed_bottom, "нижня дуга провисла")
	assert_true(inside.visible, "між дугами відкрилась порожнина")

	_mouth.open_amount = 0.0
	assert_almost_eq(lo.mesh.get_aabb().position.y, closed_bottom, 0.0001, "стулився назад")


func test_open_amount_is_clamped() -> void:
	_mouth.open_amount = 5.0
	assert_almost_eq(_mouth.open_amount, 1.0, 0.001, "більше за 1 не буває")
	_mouth.open_amount = -3.0
	assert_almost_eq(_mouth.open_amount, 0.0, 0.001, "менше за 0 теж")


func test_tongue_shows_only_when_licking() -> void:
	var tongue := _mouth.get_node("LowerJawPivot/Tongue") as MeshInstance3D
	_mouth.tongue_amount = 0.0
	assert_false(tongue.visible, "язика не видно, поки не облизується")
	_mouth.tongue_amount = 1.0
	assert_true(tongue.visible, "під час облизування язик з'являється")


## Усмішка ВИГИНАЄ лінію рота: середина дуги опускається нижче за кутики. Саме цього не
## вміли пласкі губи — там усмішка була нахилом на 4°, тобто нічим.
## Лінія рота — ОДИН суцільний меш-штрих (раніше був ланцюжок кульок, і рот читався
## «у крапочках»). Вигин міряємо за висотою його габаритної коробки: у прямої лінії вона
## завтовшки як сам штрих, а вигнута займає помітно більше.
func test_smile_curves_the_mouth_line() -> void:
	var up := _mouth.get_node("ArcUpper") as MeshInstance3D
	assert_not_null(up.mesh, "дуга — згенерований меш, а не набір дітей")
	assert_eq(up.get_child_count(), 0, "жодних окремих кульок усередині")

	_mouth.smile_amount = 0.0
	var flat_h: float = up.mesh.get_aabb().size.y

	_mouth.smile_amount = 0.65
	assert_gt(up.mesh.get_aabb().size.y, flat_h * 1.5, "в усмішці лінія вигнулась дугою")

	_mouth.smile_amount = 0.0
	assert_almost_eq(up.mesh.get_aabb().size.y, flat_h, 0.0001, "нейтраль повертає як було")


## Методи-анімації не мають падати (усередині — твіни; тут просто перевіряємо виклики).
func test_animation_api_does_not_error() -> void:
	_mouth.open()
	_mouth.close()
	_mouth.bite()
	_mouth.chew(2)
	_mouth.lick()
	_mouth.smile()
	_mouth.neutral()
	_mouth.eat(1)
	assert_between(_mouth.open_amount, 0.0, 1.0, "open_amount лишився в межах")
