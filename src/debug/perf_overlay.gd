## Лічильник кадрів і що саме їх з'їдає. Вмикається змінною оточення, у звичайній грі його
## нема взагалі.
##
## Навіщо не просто FPS. Саме число кадрів каже, що погано, але не каже ЧОМУ. У цій грі
## реальних підозрюваних троє, і вони розрізняються:
##   - забагато викликів малювання (кожен предмет окремо замість пачки MultiMesh);
##   - забагато трикутників (моделі з надлишковою геометрією);
##   - робота в самому кадрі на процесорі (розкладка декору, спавн перешкод).
## Тому поруч із кадрами показуємо виклики, трикутники й час кадру — тоді видно, котрий із
## трьох тягне вниз, і не треба гадати.
##
##     PERF=1 LEVEL=1 godot res://src/run3d/run3d.tscn
extends CanvasLayer

const UPDATE_SEC := 0.25       ## частіше — числа стрибають і їх неможливо читати

var _label: Label
var _t := 0.0
var _worst := 0.0              ## найдовший кадр за весь сеанс: середнє ховає ривки


static func attach(host: Node) -> CanvasLayer:
	if OS.get_environment("PERF") == "":
		return null
	var o := new()
	host.add_child(o)
	return o


func _ready() -> void:
	layer = 128                # поверх усього HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(12.0, 90.0)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)


func _process(delta: float) -> void:
	_worst = maxf(_worst, delta)
	_t += delta
	if _t < UPDATE_SEC:
		return
	_t = 0.0
	var fps := Engine.get_frames_per_second()
	var draw := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var tris := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var vram := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	# друкуємо ще й у консоль: так числа можна зняти з запуску без очей на екрані
	if OS.get_environment("PERF_LOG") != "":
		print("ПРОФІЛЬ к/с=%d найдовший_мс=%.1f виклики=%d трикутники=%d вузли=%d" % [
			fps, _worst * 1000.0, draw, tris, get_tree().get_node_count()])
	_label.text = "%d к/с   найдовший кадр %.0f мс\nвикликів малювання %d\nтрикутників %s\nвідеопам'ять %.0f МБ\nвузлів %d" % [
		fps, _worst * 1000.0, draw, _thousands(tris), float(vram) / 1048576.0,
		get_tree().get_node_count()]


## Розділяємо тисячі: 1 200 000 читається, 1200000 — ні.
func _thousands(v: int) -> String:
	var s := str(v)
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += " "
		out += s[i]
	return out
