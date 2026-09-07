## Зірочка. Крутиться, притягується магнітом, зникає з «дзинь».
class_name Star3D
extends Node3D

var collected := false
var _mesh: MeshInstance3D
var _t := randf() * TAU


func _ready() -> void:
	_mesh = VoxelBuilder.instance("star")
	_mesh.rotation.x = PI * 0.5   # плоска зірка стоїть вертикально
	add_child(_mesh)


func tick(delta: float, hero: Node3D, magnet: float) -> bool:
	_t += delta
	_mesh.rotation.y += delta * 3.0
	_mesh.position.y = sin(_t * 3.0) * 0.06
	var hero_pos := Vector3(hero.position.x, hero.position.y + 0.5, 0.0)
	var d := position.distance_to(hero_pos)
	# магніт тягне лише зі СВОЄЇ доріжки (|dx| < половини доріжки), але з більшої відстані по z/y
	if absf(position.x - hero_pos.x) < 0.55 and d < magnet * 1.2:
		position = position.lerp(hero_pos, minf(1.0, delta * 10.0))
	return d < 0.5 and absf(position.x - hero_pos.x) < 0.55


func collect() -> void:
	collected = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 1.8, 0.12)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.15)
	tw.finished.connect(queue_free)
