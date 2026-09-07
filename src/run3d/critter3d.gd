## Живність на узбіччі: зайчик стрибає й озирається, пташка летить дугою через дорогу, гриб/пальма/планета злегка «дихають».
class_name Critter3D
extends Node3D

var kind := "bunny"
var _t := randf() * 10.0
var _mesh: MeshInstance3D
var _hop_t := randf_range(0.5, 2.0)
var _speed := 0.0
var _dir := 1.0


func setup(k: String, palette_override: Dictionary = {}) -> void:
	kind = k
	_mesh = VoxelBuilder.instance(k, palette_override)
	add_child(_mesh)
	match kind:
		"bird":
			_speed = randf_range(2.5, 4.0)
			_dir = 1.0 if randf() < 0.5 else -1.0
			rotation.y = 0.0 if _dir > 0 else PI
		"bunny":
			rotation.y = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	match kind:
		"bunny":
			_hop_t -= delta
			if _hop_t < 0.0:
				_hop_t = randf_range(0.8, 2.5)
				var tw := create_tween()
				tw.tween_property(_mesh, "position:y", 0.25, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw.tween_property(_mesh, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
				tw.parallel().tween_property(self, "rotation:y", rotation.y + randf_range(-1.2, 1.2), 0.3)
			_mesh.scale.y = 1.0 + sin(_t * 6.0) * 0.03
		"bird":
			position.x += _dir * _speed * delta
			_mesh.position.y = sin(_t * 9.0) * 0.08
			_mesh.rotation.z = sin(_t * 9.0) * 0.35   # махає крилами
			if absf(position.x) > 14.0:
				queue_free()
		_:
			_mesh.scale.y = 1.0 + sin(_t * 1.6 + position.x) * 0.02
			_mesh.rotation.z = sin(_t * 1.2 + position.z) * 0.02
