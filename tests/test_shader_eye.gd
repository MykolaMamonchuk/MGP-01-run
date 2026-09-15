## ShaderEye (vendor/cartoon_eye/) — вендорний компонент ока, зараз на пробі на лисі
## (rig_face.eye_scene у heroes.json). Не наш код, тож тестуємо тільки те, на що спирається
## Hero3D (див. test_hero_face_expressions.gd для диспетчеризації), не внутрішню механіку шейдера.
extends GutTest

const SCENE := "res://vendor/cartoon_eye/ShaderEye.tscn"

var _eye: ShaderEye


func before_each() -> void:
	_eye = (load(SCENE) as PackedScene).instantiate() as ShaderEye
	add_child_autofree(_eye)
	await wait_process_frames(1)


func test_loads_with_shader_material() -> void:
	var surface := _eye.get_node_or_null("EyeSurface") as MeshInstance3D
	assert_not_null(surface, "є поверхня ока")
	assert_true(surface.get_active_material(0) is ShaderMaterial, "матеріал — шейдер")


func test_look_at_offset_sets_gaze() -> void:
	_eye.look_at_offset(Vector2(0.4, -0.2))
	assert_almost_eq(_eye.gaze_x, 0.4, 0.001)
	assert_almost_eq(_eye.gaze_y, -0.2, 0.001)


func test_look_at_offset_clamps_to_unit_range() -> void:
	_eye.look_at_offset(Vector2(5.0, -5.0))
	assert_almost_eq(_eye.gaze_x, 1.0, 0.001)
	assert_almost_eq(_eye.gaze_y, -1.0, 0.001)


## blink() — власний твін ShaderEye (Tween.TRANS_SINE), не через Hero3D._blink() (той дає
## свій твін напряму на blink_amount, обходячи цей метод — див. test_hero_face_expressions.gd).
## Тут просто перевіряємо, що виклик не падає і властивість лишається в межах [0,1].
func test_blink_method_runs_without_error() -> void:
	_eye.blink()
	assert_between(_eye.blink_amount, 0.0, 1.0, "blink_amount у межах діапазону")


func test_expression_surprised_widens_eye_and_shrinks_pupil() -> void:
	var base_h := _eye.eye_height
	var base_p := _eye.pupil_size
	_eye.set_expression_surprised()
	assert_gt(_eye.eye_height, base_h, "здивування — око вище")
	assert_lt(_eye.pupil_size, base_p, "здивування — зіниця менша")
	_eye.set_expression_neutral()
	assert_almost_eq(_eye.eye_height, base_h, 0.001, "нейтральний вираз повертає як було")
