## СИНТЕТИЧНИЙ СТЕНД: одна й та сама геометрія, подана рушієві трьома способами.
##
## Навіщо. Усі заміри досі робились на живій сцені, де разом із кількістю об'єктів мінялись
## матеріали, поверхні, площа на екрані й у карті тіней. Тут не міняється НІЧОГО, крім
## способу подання: сто однакових секцій паркану, ті самі положення, той самий матеріал, та
## сама сумарна геометрія. Питання одне — що дешевше для Godot Compatibility на Adreno 505:
## сто окремих вузлів, один MultiMesh на сто екземплярів чи кілька злитих мешів.
##
## Відповідь визначає конвеєр для ВСІЄЇ гри, а не для одного паркану: квіти, гриби й каміння
## можуть проситися в MultiMesh, а паркани — в злиті шматки, і це різна робота.
##
## Метод той самий, що й у strip_probe: сходи масштабу рендера, бо час кадру на Android
## квантований по 16,67 мс і одне число на фіксованому масштабі бреше (див. docs/MEMORY.md).
extends Node3D

const SRC := "res://assets/props/fence_rail_1.glb"
## ДВІ ТИСЯЧІ, а не сто. Перший прогін зі ста дав рівно 16,7 мс на КОЖНІЙ сходинці й у
## КОЖНОМУ варіанті, зокрема на порожній сцені: сто секцій для Adreno 505 — ніщо, і кадр
## уперся в стелю синхронізації, де різниць не видно взагалі. Це та сама пастка кванта, що
## й на потужному пристрої, тільки створена штучно дешевою сценою.
const N := 2000           ## секцій у КОЖНОМУ варіанті — сумарна геометрія стала
const COLS := 50          ## сітка на весь екран, щоб усе було ВИДНО, а не відсічено
const STEP := 0.8
## Сходи заходять у надлишкову вибірку: інакше на дешевих варіантах знову впремось у стелю.
const RAMP := [0.6, 0.8, 1.0, 1.4, 2.0]
const SETTLE := 1.6
const MEASURE := 2.2
const REPORT := "user://bench_report.txt"

## Варіанти: скільки злитих шматків (0 = окремі вузли, -1 = MultiMesh).
const STEPS := [
	{"назва": "прогрів (не рахується)", "режим": -1, "warm": true},
	{"назва": "2000 окремих вузлів", "режим": 0},
	{"назва": "1 MultiMesh x 2000", "режим": -1},
	{"назва": "200 злитих по 10", "режим": 200},
	{"назва": "80 злитих по 25", "режим": 80},
	{"назва": "20 злитих по 100", "режим": 20},
	{"назва": "порожньо (межа)", "режим": -2},
	{"назва": "контроль: MultiMesh", "режим": -1},
]

var _src_mesh: Mesh
var _holder: Node3D
var _step := -1
var _rung := 0
var _rungs: Array = []
var _rows: Array = []
var _log: PackedStringArray = []
var _t := 0.0
var _measuring := false
var _ticks := PackedFloat32Array()


func _say(line: String) -> void:
	print(line)
	_log.append(line)
	var f := FileAccess.open(REPORT, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_log) + "\n")
		f.close()


func _ready() -> void:
	var scene := load(SRC) as PackedScene
	_src_mesh = _find_mesh(scene.instantiate())
	if _src_mesh == null:
		_say("СТЕНД: меш не знайдено")
		return
	# Карти нормалей уже вимкнені в грі — тут робимо те саме, щоб стенд міряв ту саму річ.
	for si in range(_src_mesh.get_surface_count()):
		var bm := _src_mesh.surface_get_material(si) as BaseMaterial3D
		if bm != null:
			bm.normal_enabled = false
			bm.normal_texture = null

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 6.0, 6.0)
	cam.rotation_degrees = Vector3(-22.0, 0.0, 0.0)
	cam.fov = 62.0
	add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	add_child(sun)
	_holder = Node3D.new()
	add_child(_holder)
	_say("СТЕНД: %d секцій, %d варіантів" % [N, STEPS.size()])
	_next()


func _find_mesh(node: Node) -> Mesh:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		return mi.mesh
	for c in node.get_children():
		var m := _find_mesh(c)
		if m != null:
			return m
	return null


## Положення i-ї секції. ОДНАКОВЕ в усіх варіантах — це і є умова досліду. Сітка, а не
## коридор: у коридорі дальні секції відсікаються, і варіанти порівнювали б різну кількість
## НАМАЛЬОВАНОГО.
func _xform(i: int) -> Transform3D:
	var col := i % COLS
	var row := i / COLS
	return Transform3D(Basis(), Vector3(
		(float(col) - float(COLS) * 0.5) * STEP, 0.0, -3.0 - STEP * float(row)))


func _build(chunks: int) -> void:
	for c in _holder.get_children():
		c.queue_free()
	if chunks == -2:
		return
	if chunks == -1:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _src_mesh
		mm.instance_count = N
		for i in range(N):
			mm.set_instance_transform(i, _xform(i))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		_holder.add_child(mmi)
		return
	if chunks == 0:
		for i in range(N):
			var mi := MeshInstance3D.new()
			mi.mesh = _src_mesh
			mi.transform = _xform(i)
			_holder.add_child(mi)
		return
	# Злиті шматки: та сама геометрія, запечена в кілька мешів. Кожен шматок лишається
	# ПРОСТОРОВО компактним — інакше його оболонка розповзається на весь рівень і відсікання
	# перестає працювати.
	var per := int(ceil(float(N) / float(chunks)))
	for c in range(chunks):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var base := _xform(c * per)
		var any := false
		for i in range(c * per, mini((c + 1) * per, N)):
			var rel := base.affine_inverse() * _xform(i)
			_append(st, rel)
			any = true
		if not any:
			continue
		# ОБОВ'ЯЗКОВО зібрати індекси назад. SurfaceTool.add_vertex() пише окремі трикутники,
		# тож без index() злитий меш несе ВДВІЧІ більше вершин, ніж джерело (перевірено:
		# 598 000 примітивів проти 293 705), і дослід порівнював би не спосіб подання, а
		# удвічі більшу геометрію.
		st.index()
		var am := st.commit()
		am.surface_set_material(0, _src_mesh.surface_get_material(0))
		var mi2 := MeshInstance3D.new()
		mi2.mesh = am
		mi2.transform = base
		_holder.add_child(mi2)


func _append(st: SurfaceTool, xf: Transform3D) -> void:
	for si in range(_src_mesh.get_surface_count()):
		var arr := _src_mesh.surface_get_arrays(si)
		var verts := arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var norms := arr[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var uvs := arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		var idx := arr[Mesh.ARRAY_INDEX] as PackedInt32Array
		var order: Array = []
		if idx != null and idx.size() > 0:
			for k in idx:
				order.append(k)
		else:
			for k in range(verts.size()):
				order.append(k)
		for k in order:
			if norms != null and norms.size() > k:
				st.set_normal(xf.basis * norms[k])
			if uvs != null and uvs.size() > k:
				st.set_uv(uvs[k])
			st.add_vertex(xf * verts[k])


func _next() -> void:
	if _step >= 0:
		_record()
	_rung = 0
	_rungs = []
	_step += 1
	if _step >= STEPS.size():
		_report()
		return
	_build(int(STEPS[_step]["режим"]))
	_apply()


func _apply() -> void:
	get_viewport().scaling_3d_scale = float(RAMP[_rung])
	_t = 0.0
	_measuring = false
	_ticks = PackedFloat32Array()


func _process(delta: float) -> void:
	_t += delta
	if not _measuring:
		if _t >= SETTLE:
			_measuring = true
			_t = 0.0
		return
	_ticks.append(delta)
	if _t < MEASURE:
		return
	var t := _ticks.duplicate()
	t.sort()
	_rungs.append(snappedf(1000.0 * t[t.size() / 2], 0.1))
	_rung += 1
	if _rung >= RAMP.size():
		_next()
	else:
		_apply()


func _record() -> void:
	if bool((STEPS[_step] as Dictionary).get("warm", false)):
		return
	var total := 0.0
	for v in _rungs:
		total += float(v)
	_rows.append({"назва": STEPS[_step]["назва"], "сума": snappedf(total, 0.1),
		"сходи": _rungs.duplicate(),
		"викл": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"верш": _geom()[0], "трик": _geom()[1]})
	var d: Dictionary = _rows[-1]
	_say("СТЕНД %-24s показник %7.1f  сходи %s  викл %4d  ВЕРШИН %7d ТРИКУТ %7d" % [
		d["назва"], d["сума"], str(d["сходи"]), d["викл"], d["верш"], d["трик"]])


## ВЛАСНИЙ ПЕРЕПИС ГЕОМЕТРІЇ. Лічильник примітивів рушія між різними способами подання
## недостовірний: для MultiMesh на 2000 екземплярів він показує 299, тобто не множить на
## кількість. Без власного числа неможливо довести, що варіанти порівнюють ОДНАКОВУ
## геометрію, — а це головна умова цього досліду.
func _geom() -> Array:
	var v := 0
	var t := 0
	for c in _holder.get_children():
		var mi := c as MeshInstance3D
		if mi != null and mi.mesh != null:
			for si in range(mi.mesh.get_surface_count()):
				var arr := mi.mesh.surface_get_arrays(si)
				v += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				var idx := arr[Mesh.ARRAY_INDEX] as PackedInt32Array
				t += (idx.size() / 3) if idx != null and idx.size() > 0 \
					else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			continue
		var mmi := c as MultiMeshInstance3D
		if mmi != null and mmi.multimesh != null and mmi.multimesh.mesh != null:
			var n := mmi.multimesh.instance_count
			for si2 in range(mmi.multimesh.mesh.get_surface_count()):
				var a2 := mmi.multimesh.mesh.surface_get_arrays(si2)
				v += (a2[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() * n
				var i2 := a2[Mesh.ARRAY_INDEX] as PackedInt32Array
				t += n * ((i2.size() / 3) if i2 != null and i2.size() > 0 \
					else (a2[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3)
	return [v, t]


func _report() -> void:
	_say("СТЕНД-ПІДСУМОК ==========================================")
	var base := float((_rows[0] as Dictionary)["сума"]) if not _rows.is_empty() else 0.0
	for r in _rows:
		var d: Dictionary = r
		_say("СТЕНД %-24s показник %7.1f (%+7.1f)  викл %4d  ВЕРШИН %7d ТРИКУТ %7d" % [
			d["назва"], float(d["сума"]), float(d["сума"]) - base, int(d["викл"]),
			int(d["верш"]), int(d["трик"])])
	_say("СТЕНД-ПІДСУМОК ==========================================")
