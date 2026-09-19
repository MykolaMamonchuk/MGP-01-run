## Дебаг-накладка: кадр, пам'ять, стан гри, герой, траса — одним екраном.
##
## Навіщо. Веб-збірку замовник ганяє на своєму телефоні, і там немає ні консолі, ні проби
## (`tools/probe/`), ні профайлера редактора. Єдиний спосіб зрозуміти, чому «щось гальмує» або
## «щось не так», — показати числа просто в кадрі. Тому тут зібрано все, що проба пише в
## `probe.json`, плюс те, чого в ній немає: стан гри, герой, траса.
##
## Накладка живе в `src/ui/`, а НЕ в `src/debug/`: тека `src/debug/*` виключена з експорту
## (див. export_presets.cfg), тож звідти вона у веб-збірку просто не потрапила б.
##
## Перемикання: клавіша F3 на комп'ютері або ТАП по самій накладці на телефоні. Три стани по
## колу — повний, лише к/с, сховано. Сховано теж потрібне: коли дивишся на вигляд, числа
## заважають.
class_name DebugOverlay
extends CanvasLayer

enum Mode { FULL, FPS_ONLY, HIDDEN }

## Над HUD (10) і над усіма екранами, інакше меню перекриє накладку.
const LAYER := 20
## Як часто перемальовуємо. Кожен кадр не потрібно — очі однаково не читають швидше, а
## збирання тексту саме по собі коштує кадру.
const REFRESH_SEC := 0.2
## За скільки секунд тримаємо найгірший кадр. Миттєве число нічого не каже: смикання триває
## один кадр і встигає зникнути, доки на нього подивишся.
const WORST_WINDOW_SEC := 3.0
## Скільки к/с вважаємо добрим, посереднім і поганим — за цим фарбуємо рядок кадру.
const FPS_GOOD := 55.0
const FPS_FAIR := 40.0

var mode: Mode = Mode.FULL

var _run: Node = null
var _panel: PanelContainer
var _text: Label
var _acc := 0.0
## [час, мс] — вікно останніх кадрів, щоб дістати найгірший.
var _frames: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.position = Vector2(20, 20)
	# Тап по накладці перемикає її стан — на телефоні клавіші F3 немає.
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_panel_input)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.INK, 0.72)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_panel)

	_text = Label.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_override("font", ThemeDB.fallback_font)
	_text.add_theme_font_size_override("font_size", 15)
	_text.add_theme_color_override("font_color", Palette.WHITE)
	_panel.add_child(_text)


## Кого розпитувати. Виклик необов'язковий: без нього накладка покаже кадр і пам'ять, тобто
## те, що вона знає й сама. Так вона не падає, якщо її почепили не на Run3D.
func setup(run: Node) -> void:
	_run = run


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		cycle()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_F3:
		cycle()


func cycle() -> void:
	mode = ((mode + 1) % Mode.size()) as Mode
	_panel.visible = mode != Mode.HIDDEN
	_acc = REFRESH_SEC       # перемалювати негайно, а не за п'яту секунди


func _process(delta: float) -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	_frames.append([now, delta * 1000.0])
	while not _frames.is_empty() and now - float((_frames[0] as Array)[0]) > WORST_WINDOW_SEC:
		_frames.remove_at(0)
	if mode == Mode.HIDDEN:
		return
	_acc += delta
	if _acc < REFRESH_SEC:
		return
	_acc = 0.0
	_text.text = _fps_line() if mode == Mode.FPS_ONLY else _full_text()
	_text.add_theme_color_override("font_color", _fps_color())


func _worst_ms() -> float:
	var worst := 0.0
	for f in _frames:
		worst = maxf(worst, float((f as Array)[1]))
	return worst


func _fps() -> float:
	return float(Performance.get_monitor(Performance.TIME_FPS))


func _fps_color() -> Color:
	var f := _fps()
	if f >= FPS_GOOD:
		return Palette.LIME
	return Palette.GOLD if f >= FPS_FAIR else Palette.RED


func _m(id: int) -> float:
	return float(Performance.get_monitor(id))


func _fps_line() -> String:
	return "%.0f к/с · %.1f мс · найгірший %.1f" % [_fps(),
		_m(Performance.TIME_PROCESS) * 1000.0, _worst_ms()]


func _full_text() -> String:
	var rows := [_fps_line()]
	rows.append("виклики %d · примітиви %s · об'єкти %d"
		% [int(_m(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			_thousands(int(_m(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))),
			int(_m(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])
	rows.append("відео %.0f МБ · текстури %.0f МБ · ОЗП %.0f МБ"
		% [_mb(_m(Performance.RENDER_VIDEO_MEM_USED)),
			_mb(_m(Performance.RENDER_TEXTURE_MEM_USED)),
			_mb(_m(Performance.MEMORY_STATIC))])
	rows.append("вузлів %d · безхазяйних %d · ресурсів %d"
		% [int(_m(Performance.OBJECT_NODE_COUNT)),
			int(_m(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			int(_m(Performance.OBJECT_RESOURCE_COUNT))])
	rows.append("——")
	rows.append_array(_game_rows())
	rows.append("——")
	rows.append(_screen_row())
	rows.append("F3 або тап — повний / к/с / сховати")
	return "\n".join(rows)


## Числа з гри. Кожне поле під вартою: накладка не сміє впасти через те, що чогось немає —
## інакше вона зламає саме ту збірку, заради якої її й робили.
func _game_rows() -> Array:
	if _run == null:
		return ["гру не під'єднано (DebugOverlay.setup)"]
	var rows := []
	var state_names := ["меню", "дім", "мапа", "герої", "відлік", "біг", "фініш", "пауза", "сон"]
	var st := int(_run.get("state"))
	rows.append("стан %s · рівень %d · %s · доріжок %d"
		% [state_names[st] if st < state_names.size() else str(st),
			int(_run.get("level_num")), String(_run.get("world_id")), int(_run.get("lanes"))])
	# Швидкість тут СПРАВЖНЯ, у метрах за секунду. HUD показує дитині інше, більше число —
	# воно для настрою, а не для заміру, і плутати їх не можна.
	rows.append("швидкість %.2f м/с · метрів %.0f · профіль %s · якість %s"
		% [float(_run.get("speed")), float(_run.get("level_distance_m")),
			AgeAdapt.current, Quality.current()])

	var hero = _run.get("hero")
	if hero != null:
		var flags := []
		if bool(hero.get("tumbling")):
			flags.append("падіння")
		if bool(hero.get("ducking")):
			flags.append("присів")
		if bool(hero.get("flying")):
			flags.append("летить")
		if bool(hero.get("shield_on")):
			flags.append("щит")
		if float(hero.get("invulnerable_t")) > 0.0:
			flags.append("невразливий %.1f с" % float(hero.get("invulnerable_t")))
		rows.append("герой: доріжка %d · x %.2f · y %.2f · серця %d/%d%s"
			% [int(hero.get("lane")), float(hero.get("x_target")),
				float((hero as Node3D).position.y), int(hero.get("hearts")),
				int(hero.get("max_hearts")),
				"" if flags.is_empty() else " · " + ", ".join(flags)])

	var track = _run.get("track")
	if track != null:
		rows.append("траса: шарів декору %d · авторських записів %d + %d будівель"
			% [(track.get("_decor_mm") as Array).size(),
				(track.get("_authored_decor") as Array).size(),
				(track.get("_authored_buildings") as Array).size()])
	var spawner = _run.get("spawner")
	if spawner != null:
		rows.append("перешкоди: авторських %d (курсор %d) · пікапів %d · розсів %s"
			% [(spawner.get("_authored_obstacles") as Array).size(),
				int(spawner.get("_authored_cursor")),
				(spawner.get("_authored_pickups") as Array).size(),
				"так" if bool(spawner.get("spawning")) else "ні"])
	rows.append("зерно: %s" % ("%d" % RngSeed.value() if RngSeed.fixed() else "випадкове"))
	return rows


func _screen_row() -> String:
	var vp := get_viewport().get_visible_rect().size
	var win := DisplayServer.window_get_size()
	return "полотно %d×%d · вікно %d×%d · %s" % [int(vp.x), int(vp.y), win.x, win.y,
		OS.get_name()]


func _mb(bytes: float) -> float:
	return bytes / 1048576.0


## 184094 → «184 094»: без цього довгі числа читаються як каша.
func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var k := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		k += 1
		if k % 3 == 0 and i > 0:
			out = " " + out
	return ("-" if n < 0 else "") + out
