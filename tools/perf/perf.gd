## Замірник продуктивності. Запускає гру, стартує рівень і 900 кадрів збирає лічильники.
## Не частина гри — інструмент для docs/optimisation.
##
##   godot res://tools/perf/perf.tscn                 # вікно, справжні draw calls
##   PERF_LEVEL=8 godot res://tools/perf/perf.tscn    # інший рівень
##   godot --headless res://tools/perf/perf.tscn      # лише CPU (draw calls будуть 0)
##
## Звіт іде в консоль (рядки "PERF …") і в user://perf.txt.
## ВАЖЛИВО: міряти лише з вимкненим vsync (робимо самі) — інакше побачите стелю монітора,
## а не гру. Числа з десктопа НЕ переносяться на телефон: переносяться draw calls,
## кількість вузлів і мешів; час кадру — ні.
extends Node

const OUT := "user://perf.txt"
## Скільки кадрів усереднюємо після розігріву.
const SAMPLES := 900
## Пауза перед стартом рівня і після нього (відлік 3-2-1 + прогрів шейдерів).
const BOOT_SEC := 1.0
const WARMUP_SEC := 4.0

var _run: Node
var _sampling := false
var _n := 0
var _dt: Array = []
var _draw: Array = []
var _objs: Array = []
var _prims: Array = []


func _ready() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run = load("res://src/run3d/run3d.tscn").instantiate()
	add_child(_run)
	await get_tree().create_timer(BOOT_SEC).timeout
	_run._start_level(int(OS.get_environment("PERF_LEVEL")) if OS.has_environment("PERF_LEVEL") else 1)
	await get_tree().create_timer(WARMUP_SEC).timeout
	_sampling = true


func _process(delta: float) -> void:
	if not _sampling:
		return
	_n += 1
	_dt.append(delta * 1000.0)
	_draw.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_objs.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	_prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if _n >= SAMPLES:
		_sampling = false
		_report()
		get_tree().create_timer(0.3).timeout.connect(get_tree().quit)


func _avg(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s / maxf(1.0, float(a.size()))


func _pct(a: Array, q: float) -> float:
	var b := a.duplicate()
	b.sort()
	return float(b[clampi(int(float(b.size()) * q), 0, b.size() - 1)])


## Скільки в дереві вузлів кожного класу — звідки беруться draw calls.
func _census(n: Node, out: Dictionary) -> void:
	out[n.get_class()] = int(out.get(n.get_class(), 0)) + 1
	for c in n.get_children():
		_census(c, out)


func _report() -> void:
	var census := {}
	_census(_run, census)
	var counts := ""
	for k in ["MeshInstance3D", "GPUParticles3D", "Node3D", "Control", "Label", "Button", "OmniLight3D", "DirectionalLight3D"]:
		if census.has(k):
			counts += "%s=%d " % [k, census[k]]
	# де саме живуть меші — щоб знати, що оптимізувати першим
	var by_branch := ""
	for child in _run.get_children():
		var sub := {}
		_census(child, sub)
		if int(sub.get("MeshInstance3D", 0)) > 0:
			by_branch += "%s=%d " % [child.name, sub["MeshInstance3D"]]
	var lines := [
		"level=%s state=%d samples=%d" % [OS.get_environment("PERF_LEVEL") if OS.has_environment("PERF_LEVEL") else "1", _run.state, _n],
		"frame_ms     avg=%.2f med=%.2f p95=%.2f max=%.2f (fps_avg=%.0f)" % [
			_avg(_dt), _pct(_dt, 0.5), _pct(_dt, 0.95), _pct(_dt, 1.0), 1000.0 / maxf(0.001, _avg(_dt))],
		"draw_calls   avg=%.1f p95=%.0f" % [_avg(_draw), _pct(_draw, 0.95)],
		"objects/fr   avg=%.1f" % _avg(_objs),
		"primitives   avg=%.0f" % _avg(_prims),
		"census       " + counts,
		"meshes_by    " + by_branch,
		"physics_ms   %.3f" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0),
		"nodes=%d objects=%d orphans=%d resources=%d" % [
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)],
		"mem_static=%.1fMB video=%.1fMB texture=%.1fMB buffer=%.1fMB" % [
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0],
	]
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	for l in lines:
		print("PERF ", l)
		if f != null:
			f.store_line(l)
	if f != null:
		f.close()
