## Питання до живої гри — числами й справжнім кадром. Не частина гри.
##
##   OUT=/tmp/probe STAGE=level LEVEL=1 FRAMES=300 \
##     /Applications/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 res://tools/probe/probe.tscn
##
## Пише:
##   OUT/probe.json — кожен Control сцени з глобальним прямокутником, текстом і видимістю,
##                    плюс лічильники продуктивності й розмір вікна;
##   OUT/frame.png  — кадр РАЗОМ З ІНТЕРФЕЙСОМ.
##
## ВАЖЛИВО: запускати БЕЗ `--headless`. У headless Godot не малює нічого, і UI на знімку не
## буде — саме через це раніше здавалося, що HUD можна перевірити лише мостом MCP.
##
## Детермінізм — як у tools/shots: те саме зерно, чекати КАДРАМИ (`--fixed-fps 60`), а не
## таймерами, інакше швидша машина встигає інше число кроків і порівнювати нічого.
extends Node

const SEED := 20260907

var _run: Node
var _out: String = OS.get_environment("OUT") if OS.has_environment("OUT") else "user://probe"
var _stage: String = OS.get_environment("STAGE") if OS.has_environment("STAGE") else "menu"
var _level: int = int(OS.get_environment("LEVEL")) if OS.has_environment("LEVEL") else 1
var _frames: int = int(OS.get_environment("FRAMES")) if OS.has_environment("FRAMES") else 120


func _ready() -> void:
	seed(SEED)
	DirAccess.make_dir_recursive_absolute(_out)
	# RESET=1 — міряти з чистого аркуша. Без цього проба бачить ВАШ прогрес, і той самий
	# STAGE дає різні екрани на різних машинах, тобто порівнювати «до/після» нічим.
	if OS.get_environment("RESET") == "1":
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	_run = load("res://src/run3d/run3d.tscn").instantiate()
	add_child(_run)
	await _frames_passed(30)

	if _stage == "level":
		# Профіль задає швидкість бігу, а швидкість прямо впливає на мерехтіння — без
		# фіксації два прогони порівнювати НЕ МОЖНА (наступив 17.09.2026: «до» вийшло
		# older на 42 км/год, «після» young на 28, і різниця в числах була від швидкості).
		AgeAdapt.set_profile(OS.get_environment("PROFILE") if OS.has_environment("PROFILE") else "older")
		_run.menu.hide_menu()
		_run._start_level(_level)
		await _frames_passed(_frames)
	else:
		await _frames_passed(_frames)

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/frame.png" % _out)

	# BURST=N — N кадрів ПОСПІЛЬ, без пропусків. Для пошуку миготіння: воно має підпис
	# «змінилось і повернулось», а рух камери такого не дає — там піксель їде далі.
	# PAUSE=1 спиняє дерево перед серією: що мигає й на СТОЯЧІЙ картинці — то справжнє
	# миготіння, а що зникає — то мерехтіння від руху (недосемплена дрібна деталь).
	if OS.get_environment("PAUSE") == "1":
		get_tree().paused = true
		await _frames_passed(5)
	var burst := int(OS.get_environment("BURST")) if OS.has_environment("BURST") else 0
	for i in range(burst):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/burst_%03d.png" % [_out, i])

	var hud_before := _hud_state()
	var hud_after := {}
	# RESIZE=1600x900 — змінити розмір вікна й переміряти. Відступи безпечної зони мусять
	# лишитись ТИМИ САМИМИ в частках екрана: якщо вони «сповзають» після кожної зміни
	# розміру, значить у розрахунок потрапляє вже підтиснуте полотно.
	if OS.has_environment("RESIZE"):
		var wh := OS.get_environment("RESIZE").split("x")
		if wh.size() == 2:
			get_tree().root.size = Vector2i(int(wh[0]), int(wh[1]))
			await _frames_passed(10)
			hud_after = _hud_state()

	var report := {
		"stage": _stage,
		"level": _level,
		"frames": _frames,
		"viewport": _v2(get_viewport().get_visible_rect().size),
		"hud": hud_before,
		"hud_after_resize": hud_after,
		"performance": {
			"fps": Performance.get_monitor(Performance.TIME_FPS),
			"frame_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"objects": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		},
		"controls": _controls(_run),
	}
	var f := FileAccess.open("%s/probe.json" % _out, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("PROBE ok → %s (контролів: %d)" % [_out, (report["controls"] as Array).size()])
	get_tree().quit()


func _frames_passed(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


## Стан кореня HUD — саме до нього hud.gd підтискає краї під виріз камери. Відступи тут
## у одиницях полотна; вікно й безпечна область — у пікселях, вони НЕ збігаються (розтяг
## "expand" роздає базові 1280×720 по більшій осі).
func _hud_state() -> Dictionary:
	var hud := _run.get_node_or_null("HUD")
	if hud == null or hud._root == null:
		return {}
	var root: Control = hud._root
	var safe := DisplayServer.get_display_safe_area()
	return {
		"window": _v2i(DisplayServer.window_get_size()),
		"safe_area": {"x": safe.position.x, "y": safe.position.y, "w": safe.size.x, "h": safe.size.y},
		"canvas": _v2(get_viewport().get_visible_rect().size),
		"root_size": _v2(root.size),
		"offsets": {
			"left": root.offset_left, "top": root.offset_top,
			"right": root.offset_right, "bottom": root.offset_bottom,
		},
	}


func _v2i(v: Vector2i) -> Dictionary:
	return {"x": v.x, "y": v.y}


## Усі Control'и піддерева з глобальною геометрією. Невидимі теж — саме вони найчастіше
## і винні, коли «елемент не там»: батько схований, а дитина має слушний прямокутник.
func _controls(root: Node) -> Array:
	var out := []
	for node in _walk(root):
		if node is Control:
			var c := node as Control
			var r := c.get_global_rect()
			var entry := {
				"path": String(root.get_path_to(c)),
				"type": c.get_class(),
				"rect": {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y},
				"visible": c.is_visible_in_tree(),
			}
			if "text" in c and String(c.text) != "":
				entry["text"] = String(c.text)
			out.append(entry)
	return out


func _walk(node: Node) -> Array:
	var out := [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


func _v2(v: Vector2) -> Dictionary:
	return {"x": v.x, "y": v.y}
