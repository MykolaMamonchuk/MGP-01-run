## Звідки береться відеопам'ять: по кроках, а не одним числом.
##
##   OUT=/tmp/v /Applications/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 \
##     res://tools/vram/vram_stages.tscn
##
## Проба дає одне число `texture_mem_mb` на весь прогін, і з нього не видно, що саме важке:
## текстури пропсів, буфери рушія чи те, що гра створює вже на ходу. Цей замірник друкує
## показник на кожному кроці — порожня сцена, сцена гри, рівень, — і різниця між кроками
## і є відповідь. БЕЗ `--headless`: у headless рендерер підставний і числа не ті.
extends Node

const SEED := 20260907

var _rows: Array = []


func _ready() -> void:
	seed(SEED)
	# Ручки, якими перевіряють, ЩО САМЕ важить. Ставити їх треба до першого кадру: буфери
	# рушія виділяються один раз, коли в'юпорт уперше малює 3D.
	var vp := get_viewport()
	_knobs(vp)
	print("в'юпорт %s, msaa=%d, атлас тіней=%d, масштаб 3D=%.2f" % [
		str(vp.get_visible_rect().size), vp.msaa_3d, vp.positional_shadow_atlas_size,
		vp.scaling_3d_scale])
	await _frames(10)
	_note("порожня сцена (лише буфери рушія)")

	var packed: PackedScene = load("res://src/run3d/run3d.tscn")
	_note("ресурси сцени прочитано з диска")
	var run: Node = packed.instantiate()
	_note("сцену створено (ще не в дереві)")
	add_child(run)
	# ЩЕ РАЗ, ПІСЛЯ СЦЕНИ. `run3d._ready()` застосовує стан якості сам, а той теж пише
	# `msaa_3d` — і мовчки перетирав би MSAA= зі стану, що лежить у збереженні. Тут ще не
	# було жодного кадру, тож буфери виділяться вже з нашим значенням.
	_knobs(vp)
	await _frames(1)
	_note("перший намальований кадр")
	await _frames(30)
	_note("сцена гри в меню")

	AgeAdapt.set_profile("older")
	run.menu.hide_menu()
	run._start_level(int(OS.get_environment("LEVEL")) if OS.has_environment("LEVEL") else 2)
	await _frames(240)
	_note("рівень, 240 кадрів")

	await _frames(600)
	_note("рівень, 840 кадрів")

	print("--- ВІДЕОПАМ'ЯТЬ ПО КРОКАХ ---")
	var prev := 0.0
	for r in _rows:
		print("%-34s текстури %8.1f МБ (+%7.1f)   відео %8.1f МБ" % [r[0], r[1], r[1] - prev, r[2]])
		prev = r[1]
	get_tree().quit()


func _note(label: String) -> void:
	_rows.append([
		label,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
	])


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


## Ручки з середовища. Кличемо двічі: до сцени й одразу після неї — див. коментар вище.
func _knobs(vp: Viewport) -> void:
	if OS.has_environment("MSAA"):
		vp.msaa_3d = int(OS.get_environment("MSAA")) as Viewport.MSAA
	if OS.has_environment("SHADOW_ATLAS"):
		vp.positional_shadow_atlas_size = int(OS.get_environment("SHADOW_ATLAS"))
	if OS.has_environment("SCALE"):
		vp.scaling_3d_scale = float(OS.get_environment("SCALE"))
