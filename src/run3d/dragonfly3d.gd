## Бабка: летить попереду, міняє доріжку кожні ~2 с і лишає за собою зірочки — підказка «куди бігти» для малюків.
class_name Dragonfly3D
extends Node3D

var spawner: Spawner3D
var _lane := 0
var _t := 0.0
var _switch_t := 0.0
var _drop_t := 0.0
var _life := 6.0


func setup(sp: Spawner3D, seconds: float) -> void:
	spawner = sp
	_life = seconds
	add_child(VoxelBuilder.instance("dragonfly"))
	position = Vector3(0.0, 1.4, -3.5)


func _process(delta: float) -> void:
	_t += delta
	_life -= delta
	_switch_t += delta
	_drop_t += delta
	if _switch_t > 2.0:
		_switch_t = 0.0
		_lane = clampi(_lane + (1 if randf() < 0.5 else -1), -spawner.max_lane(), spawner.max_lane())
	position.x = lerpf(position.x, float(_lane) * Hero3D.LANE_W, minf(1.0, delta * 3.0))
	position.y = 1.4 + sin(_t * 8.0) * 0.1
	# бабка стоїть на місці відносно героя, а світ їде — зірочки лишаються позаду неї
	if _drop_t > 0.45 and is_instance_valid(spawner):
		_drop_t = 0.0
		spawner.spawn_star_at(Vector3(position.x, 0.6, position.z))
	if _life < 0.0:
		position.z -= delta * 8.0
		position.y += delta * 2.0
		if position.z < -30.0:
			queue_free()
