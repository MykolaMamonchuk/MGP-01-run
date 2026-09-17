## Корінь авторського чанка рівня — і єдине, що видно в редакторі, крім самих маркерів.
##
## Навіщо z_offset_m. Маркери довго лежали в АБСОЛЮТНИХ метрах рівня: chunk_01 починався на
## z = −150, chunk_05 — на −750. Відкритий у редакторі чанк через це виглядав порожнім: усе
## його добро стояло за сотні метрів від початку координат, куди камера не дивиться. Тепер
## маркер знає своє місце В ЧАНКУ, а чанк — своє місце в рівні; LevelTimeline.extract()
## складає одне з одним і віддає грі ту саму абсолютну відстань, що й раніше.
##
## Це ще й перший крок до бібліотеки чанків (docs/tasks/level-chunk-library.md): цеглинку з
## власною нумерацією можна поставити в будь-яке місце будь-якого рівня, просто змінивши
## z_offset_m.
##
## Дорога-орієнтир малюється ЛИШЕ в редакторі й ніколи не потрапляє ні в .tscn, ні в гру:
## прев'ю додається з owner = null, а LevelTimeline.extract() збирає тільки LevelMarker3D.
@tool
class_name LevelLayout
extends Node3D

## Ширина доріжки — та сама, що в Hero3D.LANE_W. Тут константа, бо редакторський вузол не
## має тягнути за собою пів гри заради одного числа.
const LANE_W := 1.0
## Півширина дороги для 3/5/7 доріжок: смуги × LANE_W + 0.2 бордюру, поділити навпіл.
const EDGES := [1.6, 2.6, 3.6]
## Скільки метрів малювати вперед. Збігається з LevelChunkLoader.CHUNK_LENGTH_M.
const GUIDE_LENGTH_M := 150.0
## Крок поперечних рисок — щоб на око читалась відстань.
const TICK_M := 10.0

## Відстань від старту рівня до початку цього чанка, у метрах. Для нарізки по 150 м це
## просто номер чанка × 150.
@export var z_offset_m: float = 0.0:
	set(v):
		z_offset_m = v
		_rebuild_guide()

## Показувати дорогу-орієнтир. Вимикається, коли вона заважає дивитись на сам декор.
@export var show_guide: bool = true:
	set(v):
		show_guide = v
		_rebuild_guide()

var _guide: Node3D = null


## Зсув чанка, прочитаний просто з ТЕКСТУ .tscn. Потрібен тестам і інструментам, які
## розбирають сцени текстом, не вантажачи їх: після переходу на локальні координати z
## маркера сама по собі більше нічого не означає без цього числа.
static func offset_from_text(text: String) -> float:
	var i := text.find("z_offset_m = ")
	if i < 0:
		return 0.0
	return float(text.substr(i + 13).split("\n")[0])


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_guide()


func _exit_tree() -> void:
	if _guide != null and is_instance_valid(_guide):
		_guide.queue_free()
	_guide = null


## Те саме, але без перевірки «ми в редакторі» — для src/debug/chunk_shot.gd, який показує
## розкладку поза редактором. У грі цього ніхто не кличе.
func _rebuild_guide_forced() -> void:
	if not is_inside_tree():
		return
	_build_guide()


func _rebuild_guide() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_build_guide()


func _build_guide() -> void:
	if _guide != null and is_instance_valid(_guide):
		_guide.queue_free()
	_guide = null
	if not show_guide:
		return
	var root := Node3D.new()
	root.add_child(_surface())
	root.add_child(_lines())
	add_child(root)
	root.owner = null
	_guide = root


## Полотно дороги — напівпрозора плита завширшки як трисмугова траса. Саме по ній видно,
## чи не стоїть декор на біговій доріжці (колись так стало 776 маркерів).
func _surface() -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(EDGES[0] * 2.0, GUIDE_LENGTH_M)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position = Vector3(0.0, -0.01, -GUIDE_LENGTH_M * 0.5)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.78, 0.55, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	return mi


## Лінії: межі доріжок, краї дороги для 3/5/7 смуг і поперечні риски через TICK_M метрів.
func _lines() -> MeshInstance3D:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var lane_c := Color(1.0, 1.0, 1.0, 0.5)
	var edge_c: Array[Color] = [Color(0.2, 0.9, 0.3), Color(1.0, 0.8, 0.2), Color(1.0, 0.4, 0.3)]
	var tick_c := Color(0.6, 0.8, 1.0, 0.6)
	for i in range(-3, 4):
		var x := float(i) * LANE_W + LANE_W * 0.5
		if absf(x) > EDGES[2]:
			continue
		_line(verts, colors, Vector3(x, 0.0, 0.0), Vector3(x, 0.0, -GUIDE_LENGTH_M), lane_c)
	for k in range(EDGES.size()):
		var e: float = EDGES[k]
		for s in [-1.0, 1.0]:
			_line(verts, colors, Vector3(e * s, 0.0, 0.0), Vector3(e * s, 0.0, -GUIDE_LENGTH_M), edge_c[k])
	var z := 0.0
	while z <= GUIDE_LENGTH_M:
		var half: float = EDGES[2] if fmod(z, 50.0) < 0.001 else EDGES[0]
		_line(verts, colors, Vector3(-half, 0.0, -z), Vector3(half, 0.0, -z), tick_c)
		z += TICK_M
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	return mi


func _line(verts: PackedVector3Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Color) -> void:
	verts.append(a)
	verts.append(b)
	colors.append(c)
	colors.append(c)
