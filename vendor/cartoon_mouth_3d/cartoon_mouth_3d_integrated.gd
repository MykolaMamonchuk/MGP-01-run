## Вендорний компонент рота (3D: сокет + губи + рухома нижня щелепа + язик), принесений
## користувачем у пару до CartoonEye3D. Старий рот (маленька коробочка Hero3D._mouth)
## лишається як запасний для героїв без rig_face.mouth_scene.
##
## НАШІ ПРАВКИ поверх вендорного коду (позначені "# наше:"):
##   2) сеттери зверталися до @onready-вузлів лише за is_inside_tree(); після перезавантаження
##      скрипта (@tool у відкритому редакторі) ті ставали null і кожен сеттер сипав помилку
##      в дебагер. Тепер є _nodes_ok(), який перевіряє й за потреби перечіплює вузли.
##   1) clamp()/lerp()/max() -> clampf()/lerpf()/maxf(): у проєкті попередження вважаються
##      помилками, а нетипізовані глобали повертають Variant — скрипт не компілювався.
@tool
extends Node3D
class_name CartoonMouth3DIntegrated

signal bite_point_reached
signal chew_finished
signal swallow_finished

@export_group("Fit To Face")
@export_range(0.3, 2.0, 0.01) var mouth_width := 1.0:
	set(value):
		mouth_width = value
		_apply_shape()

@export_range(0.1, 1.2, 0.01) var mouth_height := 0.34:
	set(value):
		mouth_height = value
		_apply_shape()

@export_range(0.05, 0.8, 0.01) var mouth_depth := 0.16:
	set(value):
		mouth_depth = value
		_apply_shape()

@export_range(0.0, 0.6, 0.01) var embed_depth := 0.16:
	set(value):
		embed_depth = value
		_apply_shape()

@export_range(-0.3, 0.3, 0.01) var surface_offset := 0.015:
	set(value):
		surface_offset = value
		_apply_shape()

@export_group("Muzzle / Socket")
@export var socket_enabled := true:
	set(value):
		socket_enabled = value
		_apply_shape()

@export_range(0.9, 1.5, 0.01) var socket_scale := 1.08:
	set(value):
		socket_scale = value
		_apply_shape()

@export_range(0.01, 0.35, 0.01) var socket_height := 0.10:
	set(value):
		socket_height = value
		_apply_shape()

@export var socket_color := Color("#C9824E"):
	set(value):
		socket_color = value
		_apply_colors()

@export_group("Mouth Colors")
@export var lip_color := Color("#4A2118"):
	set(value):
		lip_color = value
		_apply_colors()

@export var mouth_inside_color := Color("#21100D"):
	set(value):
		mouth_inside_color = value
		_apply_colors()

@export var tongue_color := Color("#EF7187"):
	set(value):
		tongue_color = value
		_apply_colors()

@export_group("Pose")
@export_range(0.0, 1.0, 0.01) var open_amount := 0.0:
	set(value):
		open_amount = clampf(value, 0.0, 1.0)
		_apply_pose()

## наше: спокій рота — не обов'язково рівна лінія. neutral() зводив smile_amount жорстко в
## нуль, і після кожної усмішки лис лишався з рівною щілинкою замість морди; тепер він
## повертається САМЕ СЮДИ, а пресет героя каже, яка в нього «звичайна» міна.
@export_range(-1.0, 1.0, 0.01) var rest_smile := 0.0
## наше: спокійний рот може бути ПРИВІДКРИТИЙ, із язиком. Закритий він читався як темна
## риска під носом — «взагалі не схожий на рот». Привідкритий дає темну порожнину й рожевий
## язик, і морда одразу виглядає весело.
@export_range(0.0, 1.0, 0.01) var rest_open := 0.0
@export_range(0.0, 1.0, 0.01) var rest_tongue := 0.0

## наше: МУЛЬТЯШНА ДУГА замість пласких губ-еліпсоїдів. Рот компонента складався з двох
## сплющених еліпсоїдів; кутиків у них нема, тож закритий рот читався як пряма темна риска
## («взагалі не схожий на рот»), а спроба вигнути його поворотом давала ножиці. Тепер лінія
## рота — ланцюжок кульок уздовж параболи: у спокої це усмішка, а на відкритті нижня дуга
## провисає й між дугами відкривається темна порожнина з язиком.
@export var smile_arc := true:
	set(value):
		smile_arc = value
		_apply_shape()
@export_range(8, 40, 2) var arc_segments := 24:
	set(value):
		arc_segments = value
		_apply_shape()
@export_range(0.3, 2.0, 0.05) var arc_thickness := 1.0:
	set(value):
		arc_thickness = value
		_apply_shape()
@export_range(0.0, 1.0, 0.01) var arc_curve := 0.42:
	set(value):
		arc_curve = value
		_apply_shape()

@export_range(-1.0, 1.0, 0.01) var smile_amount := 0.0:
	set(value):
		smile_amount = clampf(value, -1.0, 1.0)
		_apply_pose()

@export_range(0.0, 1.0, 0.01) var tongue_amount := 0.0:
	set(value):
		tongue_amount = clampf(value, 0.0, 1.0)
		_apply_pose()

@export_group("Animation")
@export_range(5.0, 45.0, 0.5) var max_jaw_angle_deg := 22.0
@export_range(0.05, 0.8, 0.01) var open_duration := 0.16
@export_range(0.05, 0.8, 0.01) var close_duration := 0.12
@export_range(0.05, 0.5, 0.01) var chew_step_duration := 0.11
@export_range(1, 8, 1) var default_chew_cycles := 3
@export_range(0.0, 10.0, 0.25) var chew_side_deg := 3.0
@export_range(0.05, 0.8, 0.01) var lick_duration := 0.22

@onready var socket: MeshInstance3D = $Socket
@onready var mouth_inside: MeshInstance3D = $MouthInside
@onready var upper_lip: MeshInstance3D = $UpperLip
@onready var lower_jaw_pivot: Node3D = $LowerJawPivot
@onready var lower_lip: MeshInstance3D = $LowerJawPivot/LowerLip
@onready var tongue: MeshInstance3D = $LowerJawPivot/Tongue

var _active_tween: Tween
var _base_jaw_position := Vector3.ZERO
## наше: два ланцюжки кульок — верхня лінія рота й нижня. Створюємо їх кодом (owner НЕ
## ставимо: інакше редактор запече згенерованих дітей у пресети героїв, на цьому вже
## обпікались з оком).
var _arc_up: MeshInstance3D
var _arc_lo: MeshInstance3D
var _bead_mat: StandardMaterial3D

func _ready() -> void:
	_make_materials_local()
	_apply_all()

func _apply_all() -> void:
	_apply_shape()
	_apply_colors()
	_apply_pose()

func _make_materials_local() -> void:
	for mesh_node in [socket, mouth_inside, upper_lip, lower_lip, tongue]:
		if mesh_node and mesh_node.material_override:
			mesh_node.material_override = mesh_node.material_override.duplicate()

## наше: те саме, що й в оці — після перезавантаження скрипта (@tool у відкритому редакторі)
## @onready-посилання стають null, а сеттери спрацьовують і сиплють помилки в дебагер.
func _nodes_ok() -> bool:
	if not is_inside_tree():
		return false
	if not is_instance_valid(upper_lip):
		socket = get_node_or_null("Socket") as MeshInstance3D
		mouth_inside = get_node_or_null("MouthInside") as MeshInstance3D
		upper_lip = get_node_or_null("UpperLip") as MeshInstance3D
		lower_jaw_pivot = get_node_or_null("LowerJawPivot") as Node3D
		lower_lip = get_node_or_null("LowerJawPivot/LowerLip") as MeshInstance3D
		tongue = get_node_or_null("LowerJawPivot/Tongue") as MeshInstance3D
	return is_instance_valid(upper_lip) and is_instance_valid(lower_jaw_pivot) \
		and is_instance_valid(mouth_inside) and is_instance_valid(tongue)


## наше: тримачі обох дуг. Кожна дуга — ОДИН меш-трубка, а не ланцюжок кульок: кульки
## читались окремими крапками («рот у крапочках»), скільки їх не зближуй.
func _ensure_arcs() -> void:
	if not is_inside_tree():
		return
	if _bead_mat == null:
		_bead_mat = StandardMaterial3D.new()
		_bead_mat.roughness = 0.9
	for holder_name in ["ArcUpper", "ArcLower"]:
		var mi := get_node_or_null(NodePath(holder_name)) as MeshInstance3D
		if mi == null:
			mi = MeshInstance3D.new()
			mi.name = holder_name
			mi.material_override = _bead_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
		if holder_name == "ArcUpper":
			_arc_up = mi
		else:
			_arc_lo = mi


## наше: суцільний штрих уздовж параболи — трубка круглого перерізу з округлими кінцями.
## `sag` — наскільки середина провисає (усмішка = підняті кутики, тобто середина НИЖЧА).
## Кінці тонші за середину: так лінія виглядає мальованою, а не відрізком труби.
func _arc_mesh(sag: float, half_w: float, rad: float) -> ArrayMesh:
	var segs := maxi(arc_segments, 8)
	var sides := 8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var pts: Array[Vector3] = []
	var radii: Array[float] = []
	for i in segs + 1:
		var t := float(i) / float(segs) * 2.0 - 1.0
		pts.append(Vector3(t * half_w, -(1.0 - t * t) * sag, 0.0))
		radii.append(rad * lerpf(0.45, 1.0, 1.0 - absf(t)))

	# кільце навколо кривої в точці i
	var ring := func(i: int) -> Array:
		var prev: Vector3 = pts[maxi(i - 1, 0)]
		var next: Vector3 = pts[mini(i + 1, segs)]
		var tang := (next - prev)
		if tang.length() < 0.00001:
			tang = Vector3.RIGHT
		tang = tang.normalized()
		var nrm := Vector3.FORWARD.cross(tang).normalized()
		if nrm.length() < 0.5:
			nrm = Vector3.UP
		var bin := tang.cross(nrm).normalized()
		var out: Array = []
		for j in sides:
			var a := TAU * float(j) / float(sides)
			out.append(pts[i] + (nrm * cos(a) + bin * sin(a)) * radii[i])
		return out

	var rings: Array = []
	for i in segs + 1:
		rings.append(ring.call(i))

	for i in segs:
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		for j in sides:
			var k := (j + 1) % sides
			st.add_vertex(r0[j]); st.add_vertex(r1[j]); st.add_vertex(r1[k])
			st.add_vertex(r0[j]); st.add_vertex(r1[k]); st.add_vertex(r0[k])

	# округлі кінці: віяло від крайньої точки до її кільця
	for pair in [[0, pts[0]], [segs, pts[segs]]]:
		var idx: int = pair[0]
		var tip: Vector3 = pair[1]
		var r: Array = rings[idx]
		for j in sides:
			var k := (j + 1) % sides
			if idx == 0:
				st.add_vertex(tip); st.add_vertex(r[k]); st.add_vertex(r[j])
			else:
				st.add_vertex(tip); st.add_vertex(r[j]); st.add_vertex(r[k])

	st.generate_normals()
	return st.commit()


func _apply_shape() -> void:
	if not _nodes_ok():
		return
	_ensure_arcs()

	# Entire component is pushed into the muzzle. Only the front remains visible.
	position.z = surface_offset - embed_depth

	socket.visible = socket_enabled
	socket.scale = Vector3(
		mouth_width * socket_scale,
		mouth_height * socket_scale,
		maxf(mouth_depth * 0.55, 0.03)
	)
	socket.position = Vector3(0.0, 0.0, -mouth_depth * 0.45)

	# The dark cavity sits slightly behind the lips.
	mouth_inside.scale = Vector3(
		mouth_width * 0.88,
		mouth_height * 0.58,
		maxf(mouth_depth * 0.65, 0.03)
	)
	mouth_inside.position = Vector3(0.0, 0.0, -mouth_depth * 0.20)

	# Flattened lip volumes.
	upper_lip.scale = Vector3(
		mouth_width,
		mouth_height * 0.42,
		mouth_depth
	)
	upper_lip.position = Vector3(0.0, mouth_height * 0.20, 0.0)

	_base_jaw_position = Vector3(0.0, -mouth_height * 0.20, 0.0)
	lower_lip.scale = Vector3(
		mouth_width,
		mouth_height * 0.42,
		mouth_depth
	)
	lower_lip.position = Vector3.ZERO

	tongue.scale = Vector3(
		mouth_width * 0.48,
		mouth_height * 0.26,
		mouth_depth * 0.55
	)

	# наше: коли малюємо дугу, пласкі губи-еліпсоїди не потрібні — саме вони й читались
	# як пряма риска. Порожнина й язик лишаються: вони живуть МІЖ дугами.
	upper_lip.visible = not smile_arc
	lower_lip.visible = not smile_arc

	_apply_pose()

func _apply_colors() -> void:
	if not _nodes_ok():
		return

	_set_albedo(socket, socket_color)
	_set_albedo(upper_lip, lip_color)
	_set_albedo(lower_lip, lip_color)
	_set_albedo(mouth_inside, mouth_inside_color)
	_set_albedo(tongue, tongue_color)
	if _bead_mat != null:
		_bead_mat.albedo_color = lip_color

func _set_albedo(node: MeshInstance3D, color: Color) -> void:
	if node == null:
		return
	var mat := node.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color = color

func _apply_pose() -> void:
	if not _nodes_ok():
		return

	var open_v := clampf(open_amount, 0.0, 1.0)
	var smile_v := clampf(smile_amount, -1.0, 1.0)

	# наше: коли малюємо мультяшну дугу, ВСЮ розкладку веде вона — інакше щелепа-еліпсоїд
	# і порожнина лічаться за своєю логікою й лізуть повз лінію рота.
	if smile_arc and _arc_up != null and is_instance_valid(_arc_up):
		_pose_arc(open_v, smile_v)
		return

	# Real 3D lower jaw movement.
	lower_jaw_pivot.rotation_degrees = Vector3(
		max_jaw_angle_deg * open_v,
		0.0,
		-smile_v * 2.0
	)

	lower_jaw_pivot.position = _base_jaw_position + Vector3(
		0.0,
		-mouth_height * 0.42 * open_v,
		mouth_depth * 0.05 * open_v
	)

	# Mouth cavity opens vertically but stays embedded in the muzzle.
	mouth_inside.scale.y = mouth_height * lerpf(0.16, 1.10, open_v)

	# Small smile shaping without deforming the whole face.
	upper_lip.rotation_degrees.z = -smile_v * 4.0
	lower_lip.rotation_degrees.z = smile_v * 3.0

	# Tongue remains inside and only moves forward when licking.
	tongue.visible = tongue_amount > 0.01
	if tongue.visible:
		tongue.position = Vector3(
			0.0,
			-mouth_height * 0.04 + tongue_amount * mouth_height * 0.12,
			mouth_depth * (0.05 + tongue_amount * 0.75)
		)


## наше: поза мультяшного рота. Дві дуги: верхня — лінія рота, нижня — підборіддя. У спокої
## вони збігаються в одну усміхнену лінію, на відкритті нижня провисає, і між ними
## відкривається темна порожнина з язиком на дні.
func _pose_arc(open_v: float, smile_v: float) -> void:
	var half_w := mouth_width * 0.5
	var sag := half_w * arc_curve * maxf(smile_v, 0.0)
	var drop := half_w * lerpf(0.0, 0.95, open_v)
	# радіус штриха рахуємо від ШИРИНИ рота, щоб лінія лишалась однаково товстою
	# при будь-якому розмірі рота
	var rad := half_w * 0.085 * arc_thickness
	_arc_up.mesh = _arc_mesh(sag, half_w, rad)
	_arc_lo.mesh = _arc_mesh(sag + drop, half_w, rad)
	_arc_up.position.z = mouth_depth * 0.5
	_arc_lo.position.z = mouth_depth * 0.5

	# порожнина живе рівно МІЖ дугами й зникає, коли рот стулений (інакше з-під лінії
	# визирала б темна смужка й усмішка читалась як щілина)
	mouth_inside.visible = open_v > 0.02
	mouth_inside.scale = Vector3(
		mouth_width * 0.92,
		maxf(drop, 0.001) * 1.2,
		maxf(mouth_depth * 0.65, 0.03)
	)
	mouth_inside.position = Vector3(0.0, -(sag + drop * 0.5), -mouth_depth * 0.2)

	# щелепи як окремого об'єкта тут нема — півот лише носить язик на дно порожнини
	lower_jaw_pivot.rotation_degrees = Vector3.ZERO
	lower_jaw_pivot.position = Vector3(0.0, -(sag + drop * 0.66), 0.0)
	# язик видно й при СТУЛЕНОМУ роті: облизування — це коли він визирає з-під лінії,
	# а не коли щелепа розкрита (lick() рота не відкриває)
	tongue.visible = tongue_amount > 0.01
	if tongue.visible:
		tongue.position = Vector3(0.0, 0.0, mouth_depth * (0.05 + tongue_amount * 0.55))


func open(speed_scale: float = 1.0) -> void:
	_start_tween()
	_active_tween.tween_property(
		self,
		"open_amount",
		1.0,
		open_duration / maxf(speed_scale, 0.01)
	)

func close(speed_scale: float = 1.0) -> void:
	_start_tween()
	_active_tween.tween_property(
		self,
		"open_amount",
		0.0,
		close_duration / maxf(speed_scale, 0.01)
	)

func bite() -> void:
	_start_tween()
	_active_tween.tween_property(self, "open_amount", 1.0, open_duration)
	_active_tween.tween_callback(func(): bite_point_reached.emit())
	_active_tween.tween_property(self, "open_amount", 0.04, close_duration)

func chew(cycles: int = -1) -> void:
	if cycles < 0:
		cycles = default_chew_cycles

	_start_tween()

	for i in range(cycles):
		_active_tween.tween_property(self, "open_amount", 0.22, chew_step_duration)
		_active_tween.parallel().tween_property(
			lower_jaw_pivot,
			"rotation_degrees:y",
			chew_side_deg,
			chew_step_duration
		)

		_active_tween.tween_property(self, "open_amount", 0.03, chew_step_duration)
		_active_tween.parallel().tween_property(
			lower_jaw_pivot,
			"rotation_degrees:y",
			-chew_side_deg,
			chew_step_duration
		)

	_active_tween.tween_property(
		lower_jaw_pivot,
		"rotation_degrees:y",
		0.0,
		chew_step_duration
	)
	_active_tween.tween_property(self, "open_amount", 0.0, chew_step_duration)
	_active_tween.tween_callback(func(): chew_finished.emit())

func lick() -> void:
	_start_tween()
	_active_tween.tween_property(self, "open_amount", 0.30, lick_duration * 0.35)
	_active_tween.tween_property(self, "tongue_amount", 1.0, lick_duration * 0.35)
	_active_tween.tween_property(self, "tongue_amount", 0.0, lick_duration * 0.30)
	_active_tween.tween_property(self, "open_amount", 0.0, lick_duration * 0.35)

func smile() -> void:
	_start_tween()
	_active_tween.tween_property(self, "smile_amount", 0.65, 0.18)

func neutral() -> void:
	_start_tween()
	_active_tween.tween_property(self, "smile_amount", rest_smile, 0.18)
	_active_tween.parallel().tween_property(self, "open_amount", rest_open, 0.18)
	_active_tween.parallel().tween_property(self, "tongue_amount", rest_tongue, 0.18)

func eat(chew_cycles: int = -1) -> void:
	if chew_cycles < 0:
		chew_cycles = default_chew_cycles

	_start_tween()
	_active_tween.tween_property(self, "open_amount", 1.0, open_duration)
	_active_tween.tween_callback(func(): bite_point_reached.emit())
	_active_tween.tween_property(self, "open_amount", 0.04, close_duration)

	for i in range(chew_cycles):
		_active_tween.tween_property(self, "open_amount", 0.20, chew_step_duration)
		_active_tween.parallel().tween_property(
			lower_jaw_pivot,
			"rotation_degrees:y",
			chew_side_deg,
			chew_step_duration
		)

		_active_tween.tween_property(self, "open_amount", 0.03, chew_step_duration)
		_active_tween.parallel().tween_property(
			lower_jaw_pivot,
			"rotation_degrees:y",
			-chew_side_deg,
			chew_step_duration
		)

	_active_tween.tween_property(
		lower_jaw_pivot,
		"rotation_degrees:y",
		0.0,
		chew_step_duration
	)
	_active_tween.tween_property(self, "open_amount", 0.0, chew_step_duration)
	_active_tween.tween_interval(0.12)
	_active_tween.tween_callback(func(): swallow_finished.emit())
	_active_tween.tween_property(self, "smile_amount", 0.65, 0.18)
	_active_tween.tween_callback(func(): chew_finished.emit())

func _start_tween() -> void:
	if is_instance_valid(_active_tween):
		_active_tween.kill()

	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_IN_OUT)
