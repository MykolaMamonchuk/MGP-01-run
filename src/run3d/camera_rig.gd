## Камера: пресети зі світу (data/worlds/*.json → "camera"), плавний переїзд між ними на станції.
class_name CameraRig
extends Node3D

@onready var cam: Camera3D = $Camera3D

## Пресети екранів (не світів): меню — близько й трохи збоку; герої — фронтально на ряд подіумів.
const PRESET_MENU := {"pos": [1.7, 1.5, 3.0], "look": [0.0, 0.75, 0.0], "fov": 55, "ortho": false}
const PRESET_HEROES := {"pos": [0.0, 1.7, 1.4], "look": [0.0, 0.7, -2.3], "fov": 58, "ortho": false}

var _tw: Tween
var _shake_tw: Tween


## Тряска (падіння героя): h/v_offset камери, без зміни трансформи.
func shake(strength: float = 0.12) -> void:
	if _shake_tw:
		_shake_tw.kill()
	_shake_tw = create_tween()
	for i in range(5):
		var k := strength * (1.0 - float(i) / 5.0)
		_shake_tw.tween_property(cam, "h_offset", randf_range(-k, k), 0.04)
		_shake_tw.parallel().tween_property(cam, "v_offset", randf_range(-k, k), 0.04)
	_shake_tw.tween_property(cam, "h_offset", 0.0, 0.05)
	_shake_tw.parallel().tween_property(cam, "v_offset", 0.0, 0.05)


func apply(preset: Dictionary, duration: float = 0.0) -> void:
	# запасний пресет — той самий «низько й близько», що й у світах (GDD v1.4 §3: герой ≈ 1/4 висоти екрана)
	var p: Array = preset.get("pos", [0.0, 1.9, 3.2])
	var l: Array = preset.get("look", [0.0, 0.8, -4.0])
	var pos := Vector3(float(p[0]), float(p[1]), float(p[2]))
	var look := Vector3(float(l[0]), float(l[1]), float(l[2]))
	var ortho := bool(preset.get("ortho", false))
	if _tw:
		_tw.kill()
	_gen += 1
	if duration <= 0.0:
		cam.position = pos
		cam.look_at_from_position(pos, look, Vector3.UP)
		_set_projection(ortho, preset)
		return
	# проекцію міняємо в середині переїзду — стрибок ховається за рухом
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(cam, "position", pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var start_basis := cam.global_transform.basis
	var target := Transform3D().looking_at(look - pos, Vector3.UP).basis
	_tw.tween_method(func(t: float): cam.basis = start_basis.slerp(target, t), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_timer(duration * 0.5).timeout.connect(_set_projection_if_current.bind(ortho, preset, _gen))


var _gen := 0

## Старий таймер від попереднього apply() не має перебити новий пресет.
func _set_projection_if_current(ortho: bool, preset: Dictionary, gen: int) -> void:
	if gen == _gen:
		_set_projection(ortho, preset)


func _set_projection(ortho: bool, preset: Dictionary) -> void:
	if ortho:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = float(preset.get("size", 9.0))
	else:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = float(preset.get("fov", 62.0))
