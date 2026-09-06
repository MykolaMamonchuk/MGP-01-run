## Перешкода. Без фізики: габарит (AABB) перевіряє Spawner3D. Рухається разом зі світом (+Z).
## action: "jump" (перестрибнути), "duck" (присісти), "any" (можна пробігти — бризки), "side" (обійти), "gap" (річка без колоди).
class_name Obstacle3D
extends Node3D

var kind := ""
var action := "any"
var tumble := true
var lane := 0
var box := Vector3(0.7, 0.7, 0.7)
var auto_assist := false
var moves := false
var move_speed := 0.0
var hit := false
var passed := false

var _mesh: MeshInstance3D
var _dir := 1.0
var _box_y := 0.0


func setup(k: String, def: Dictionary, l: int, assist: bool, with_mesh: bool = true) -> void:
	kind = k
	action = String(def.get("action", "any"))
	tumble = bool(def.get("tumble", true))
	lane = l
	auto_assist = assist
	moves = bool(def.get("moves", false))
	move_speed = float(def.get("move_speed", 0.0))
	var b: Array = def.get("box", [0.7, 0.7, 0.7])
	box = Vector3(float(b[0]), float(b[1]), float(b[2]))
	position.x = float(lane) * Hero3D.LANE_W
	var y := float(def.get("y", 0.0))
	# у bounding box гілки враховуємо висоту підвісу
	_box_y = y
	if with_mesh:
		_mesh = VoxelBuilder.instance(String(def.get("voxel", kind)))
		_mesh.position.y = y
		add_child(_mesh)
	else:
		# невидима «дірка» (річка без колоди) — меш-заглушка, щоб анімації не падали
		_mesh = MeshInstance3D.new()
		add_child(_mesh)


func aabb() -> AABB:
	return AABB(
		Vector3(position.x - box.x * 0.5, _box_y, position.z - box.z * 0.5),
		box
	)


func tick(delta: float) -> void:
	if moves:
		position.x += _dir * move_speed * delta
		if absf(position.x) > 1.6:
			_dir = -signf(position.x)
			position.x = clampf(position.x, -1.6, 1.6)
			_mesh.rotation.y = 0.0 if _dir > 0 else PI


## Реакція на зіткнення без перекиду (калюжа/кущ): маленький «пшик».
func splash() -> void:
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", Vector3(1.3, 0.6, 1.3), 0.1)
	tw.tween_property(_mesh, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC)
