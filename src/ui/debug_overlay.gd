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
## Перемикання: клавіша ` (тильда, ліворуч від 1), або F3, або ТАП ПО КУТКУ зліва вгорі.
## Три стани по колу — повний, лише к/с, сховано. Сховано теж потрібне: коли дивишся на
## вигляд, числа заважають.
##
## Чому саме так. F3 на Маку зайнята системою (Mission Control), і без «використовувати
## F1–F12 як звичайні функційні» вона до гри просто не доходить — замовник це й повідомив.
## Тому головна клавіша тепер ` , а F3 лишається для тих, у кого вона працює.
##
## І куток. Доти тап був ПО САМІЙ ПАНЕЛІ — а коли стан «сховано», панелі немає, тобто на
## телефоні накладку не можна було повернути взагалі. Куток є завжди.
class_name DebugOverlay
extends CanvasLayer

enum Mode { FULL, FPS_ONLY, HIDDEN }

## Над HUD (10) і над усіма екранами, інакше меню перекриє накладку.
const LAYER := 20
## Невидимий куток зліва вгорі, тап по якому перемикає накладку. Він є ЗАВЖДИ, і саме тому
## з нього можна повернути СХОВАНУ накладку. Розмір — під палець.
const CORNER := 72.0
## Як часто перемальовуємо. Кожен кадр не потрібно — очі однаково не читають швидше, а
## збирання тексту саме по собі коштує кадру.
const REFRESH_SEC := 0.2
## Вікно для середнього й для 1% low. Довше за «найгірший», бо це показники РІВНОСТІ ходу,
## і на трьох секундах вони стрибають від кожної випадковості.
const STATS_WINDOW_SEC := 8.0
## Частка найгірших кадрів, яку показуємо окремо. Для раннера рівність ходу важливіша за
## середнє: середні 16 мс при найгірших 40 — це помітні смики, а середнє про них мовчить.
const LOW_PERCENTILE := 0.01
## Скільки к/с вважаємо добрим, посереднім і поганим — за цим фарбуємо рядок кадру.
const FPS_GOOD := 55.0
const FPS_FAIR := 40.0

var mode: Mode = Mode.FULL

var _road_btn: Button = null
var _strip_btn: Button = null
var _run: Node = null
var _panel: PanelContainer
var _corner: Control
var _text: Label
var _acc := 0.0
## Мить попереднього кадру за годинником (секунди).
var _last_t := 0.0
## [час, мс] — вікно останніх кадрів, щоб дістати найгірший.
var _frames: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	# Godot міряє час кадру ОКРЕМО для процесора й для відеокарти, але лише коли попросиш.
	# Це і є головне число для телефона: воно каже, ЩО саме впирається, а не просто «повільно».
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
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

	# Невидимий перемикач у кутку. Додаємо ПІСЛЯ панелі, тож він лежить зверху й ловить тап
	# і тоді, коли панель видно, і тоді, коли її нема.
	_corner = Control.new()
	_corner.size = Vector2(CORNER, CORNER)
	_corner.mouse_filter = Control.MOUSE_FILTER_STOP
	_corner.gui_input.connect(_on_panel_input)
	root.add_child(_corner)

	# ПОРІВНЯННЯ ПОЛОТНА ДОРОГИ НАЖИВО. Три стилі (Track.set_road_style) відрізняються на
	# 0,3-0,6% пікселів, тобто на знімку їх майже не розрізнити — а оком у русі різниця в
	# тому, чи є поперечні лінії, видна одразу. Тому перемикач у самій грі: тиснеш і бачиш.
	# ДРУГА КНОПКА — варіанти досліду НАЖИВО, у русі. Потрібна тому, що заморожена проба
	# на пляжі показала 43 мс, а гра в русі — 156: заморозка там нерепрезентативна. Єдиний
	# чесний спосіб — перемикати прапорці на ходу й читати числа з цієї ж накладки.
	_strip_btn = Button.new()
	_strip_btn.anchor_left = 1.0
	_strip_btn.anchor_right = 1.0
	_strip_btn.offset_left = -340.0
	_strip_btn.offset_right = -24.0
	_strip_btn.offset_top = 236.0
	_strip_btn.offset_bottom = 308.0
	_strip_btn.add_theme_font_size_override("font_size", 22)
	_strip_btn.pressed.connect(_cycle_strip)
	root.add_child(_strip_btn)

	_road_btn = Button.new()
	# Явні прив'язка й відступи, а не PRESET: пресет перетирає position, і кнопка їде за
	# межі екрана. Місце — під кнопкою паузи справа, щоб не перекривати її пальцем.
	_road_btn.anchor_left = 1.0
	_road_btn.anchor_right = 1.0
	_road_btn.offset_left = -340.0
	_road_btn.offset_right = -24.0
	_road_btn.offset_top = 150.0
	_road_btn.offset_bottom = 222.0
	_road_btn.add_theme_font_size_override("font_size", 22)
	_road_btn.pressed.connect(_cycle_road_style)
	root.add_child(_road_btn)
	_refresh_road_btn()


## Кого розпитувати. Виклик необов'язковий: без нього накладка покаже кадр і пам'ять, тобто
## те, що вона знає й сама. Так вона не падає, якщо її почепили не на Run3D.
func setup(run: Node) -> void:
	_run = run
	# Кнопка знає про трасу лише звідси: у _ready() гри ще нема, і без цього виклику вона
	# лишалась би схованою назавжди.
	_refresh_road_btn()


## Варіанти досліду, які перемикає друга кнопка. Список навмисно короткий і саме про те,
## що зараз досліджують: на пляжі — вода. Міняється разом із задачею.
## Варіанти для порівняння НАЖИВО. «вода» перемикає не прапорець досліду, а справжній
## вибір шейдера — тобто показує рівно те, що побачить дитина.
## Варіанти для ЛУГУ: там 10 к/с при трьох доріжках, тобто найгірше з розрахунку на
## ширину дороги. Підозри: канали з водою обабіч, щільна забудова, містки.
const STRIP_SETS := [
	{"назва": "як є", "flags": [], "water": -1},
	{"назва": "без води (канали)", "flags": ["water"], "water": -1},
	{"назва": "без берегів", "flags": ["banks"], "water": -1},
	{"назва": "без забудови", "flags": ["buildings"], "water": -1},
	{"назва": "без дрібниці", "flags": ["props"], "water": -1},
	{"назва": "без декору зовсім", "flags": ["decor"], "water": -1},
	{"назва": "без завіс (туман)", "flags": [], "water": -1, "haze": false},
]

var _strip_i := 0


func _cycle_strip() -> void:
	if _run == null or not _run.has_method("debug_strip"):
		return
	_strip_i = (_strip_i + 1) % STRIP_SETS.size()
	var set_i: Dictionary = STRIP_SETS[_strip_i]
	_run.call("debug_strip", PackedStringArray(set_i["flags"]))
	var tr := _track()
	if tr != null and tr.has_method("force_water_shader"):
		tr.call("force_water_shader", int(set_i.get("water", -1)))
	# Завіси туману вмикає стан якості; тут даємо їх вимкнути для заміру.
	var hz = _run.get("haze")
	if hz != null and hz.has_method("set_enabled"):
		hz.call("set_enabled", bool(set_i.get("haze", true)))
	_refresh_strip_btn()


func _refresh_strip_btn() -> void:
	if _strip_btn == null:
		return
	_strip_btn.visible = _run != null and _run.has_method("debug_strip") and mode != Mode.HIDDEN
	_strip_btn.text = "дослід: " + String((STRIP_SETS[_strip_i] as Dictionary)["назва"])


## Назви кнопкою — словами, якими ми про це говоримо, а не назвами полів.
const ROAD_STYLES := ["base", "flat", "grid"]
const ROAD_LABELS := {
	"base": "дорога: ЗАРАЗ",
	"flat": "дорога: А (гладка)",
	"grid": "дорога: Б (з лініями)",
}


func _cycle_road_style() -> void:
	var tr := _track()
	if tr == null:
		return
	var i: int = ROAD_STYLES.find(String(tr.call("road_style")))
	tr.call("set_road_style", ROAD_STYLES[(i + 1) % ROAD_STYLES.size()])
	_refresh_road_btn()


func _refresh_road_btn() -> void:
	var tr := _track()
	if _road_btn == null:
		return
	_road_btn.visible = tr != null and mode != Mode.HIDDEN
	if tr != null:
		_road_btn.text = String(ROAD_LABELS.get(String(tr.call("road_style")), "дорога: ?"))
	_refresh_strip_btn()


func _track() -> Node:
	if _run == null:
		return null
	var tr: Node = _run.get("track") as Node
	return tr if tr != null and tr.has_method("set_road_style") else null


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		cycle()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var code := (event as InputEventKey).keycode
	if code == KEY_QUOTELEFT or code == KEY_F3:
		cycle()


func cycle() -> void:
	mode = ((mode + 1) % Mode.size()) as Mode
	_panel.visible = mode != Mode.HIDDEN
	_refresh_road_btn()
	_acc = REFRESH_SEC       # перемалювати негайно, а не за п'яту секунди


## ЛОВЕЦЬ РИВКІВ. Замовник каже «лаги», а накладка показує медіану — це різні речі: при
## медіані 55 мс окремий кадр стрибав до 203 і 385 мс, і саме його видно як смикання.
## Середнє число причини не називає, тому тут друкуємо САМ ривок разом із тим, що змінилось
## у сцені за цей кадр: скільки додалось ресурсів (значить, щось вантажилось із диска),
## об'єктів і вузлів (значить, щось будувалось). Один із трьох рядків і показує, куди йти.
##
## Поріг узятий від медіани, а не сталий: на слабкому телефоні 100 мс — це майже норма, а
## на сильному — катастрофа.
const HITCH_K := 2.5
const HITCH_MIN_MS := 60.0

var _prev_res := 0
var _prev_obj := 0
var _prev_nodes := 0


## Типовий кадр у вікні — медіана, а не середнє: одна колотнеча на 400 мс зсуває середнє
## так, що поріг ривка підскочив би й наступних ривків не спіймав.
func _typical_ms() -> float:
	if _frames.size() < 8:
		return 0.0
	var v: Array = []
	for f in _frames:
		v.append(float((f as Array)[1]))
	v.sort()
	return float(v[v.size() / 2])


func _catch_hitch(ms: float, median_ms: float) -> void:
	var res := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var obj := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var limit := maxf(HITCH_MIN_MS, median_ms * HITCH_K)
	if median_ms > 0.0 and ms > limit and _prev_res > 0:
		print("РИВОК %.0f мс (медіана %.0f) · ресурсів %+d · об'єктів %+d · вузлів %+d"
			% [ms, median_ms, res - _prev_res, obj - _prev_obj, nodes - _prev_nodes])
	_prev_res = res
	_prev_obj = obj
	_prev_nodes = nodes


func _process(delta: float) -> void:
	# Час кадру беремо ГОДИННИКОМ, а не з delta. Під `--fixed-fps` (а так ганяє проба) delta
	# синтетична й завжди рівна 16,7 мс — за нею всі кадри виглядають ідеальними, і 1% low
	# нічого не показує. Годинник каже правду в обох випадках.
	var t := float(Time.get_ticks_usec()) / 1000000.0
	var ms := (t - _last_t) * 1000.0 if _last_t > 0.0 else delta * 1000.0
	_last_t = t
	var now := t
	_frames.append([now, ms])
	while not _frames.is_empty() and now - float((_frames[0] as Array)[0]) > STATS_WINDOW_SEC:
		_frames.remove_at(0)
	_catch_hitch(ms, _typical_ms())
	if mode == Mode.HIDDEN:
		return
	_acc += delta
	if _acc < REFRESH_SEC:
		return
	_acc = 0.0
	_text.text = _fps_line() if mode == Mode.FPS_ONLY else _full_text()
	_refresh_road_btn()
	_text.add_theme_color_override("font_color", _fps_color())


## Найгірший кадр ЗА ТИМ САМИМ вікном, що й середнє з 1% low. Спершу він рахувався за
## трьома секундами, і виходила нісенітниця: «1% low 85.6, найгірший 40.2». Одне вікно —
## і числа знову можна читати одне поруч з одним.
func _worst_ms() -> float:
	var worst := 0.0
	for f in _frames:
		worst = maxf(worst, float((f as Array)[1]))
	return worst


## Середній кадр і 1% low за вікном. Повертає [середнє, 1% low, к/с за вікном].
## К/с рахуємо САМІ, а не беремо Performance.TIME_FPS: те число миттєве й стрибає так, що за
## ним не видно ні провалів, ні рівного ходу.
func _stats() -> Array:
	var ms: Array = []
	var total := 0.0
	for f in _frames:
		var v := float((f as Array)[1])
		ms.append(v)
		total += v
	if ms.is_empty():
		return [0.0, 0.0, 0.0]
	ms.sort()
	var avg := total / float(ms.size())
	# 1% low — час, гірший за 99% кадрів вікна (не середнє найгірших, а сам поріг)
	var at := mini(ms.size() - 1, int(float(ms.size()) * (1.0 - LOW_PERCENTILE)))
	return [avg, float(ms[at]), 1000.0 / maxf(avg, 0.001)]


func _render_ms() -> Array:
	var vp := get_viewport().get_viewport_rid()
	return [RenderingServer.viewport_get_measured_render_time_cpu(vp),
		RenderingServer.viewport_get_measured_render_time_gpu(vp)]


## К/с за нашим вікном, а не миттєве Performance.TIME_FPS: те стрибає так, що фарбувати за
## ним рядок означало б блимати кольором на рівному ході.
func _fps() -> float:
	return float(_stats()[2])


func _fps_color() -> Color:
	var f := _fps()
	if f >= FPS_GOOD:
		return Palette.LIME
	return Palette.GOLD if f >= FPS_FAIR else Palette.RED


func _m(id: int) -> float:
	return float(Performance.get_monitor(id))


func _fps_line() -> String:
	var st := _stats()
	return "%.0f к/с · кадр %.1f мс · 1%% low %.1f · найгірший %.1f (за %.0f с)" % [
		float(st[2]), float(st[0]), float(st[1]), _worst_ms(), STATS_WINDOW_SEC]


func _full_text() -> String:
	var rows := [_fps_line()]
	# ЩО САМЕ ВПИРАЄТЬСЯ. Якщо ЦП 7 мс, а відео 18 — чіпати треба тіні, MSAA й заповнення,
	# а не пачки й скрипти. Якщо навпаки — навпаки. Без цих двох чисел оптимізують навмання.
	var r := _render_ms()
	rows.append("ЦП %.1f мс · відео %.1f мс" % [float(r[0]), float(r[1])])
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
	rows.append("` або F3 або тап по кутку — повний / к/с / сховати")
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
	# ТІНЬ ПОКАЗУЄМО ОКРЕМО ВІД НАЗВИ ЯКОСТІ. Стан «Плавно» мав гасити тінь, а на телефоні
	# вона лишалась намальованою — і з самої назви стану цього було не видно. Тепер тут
	# СПРАВЖНЄ значення з сонця, тож розбіжність «що обрано» й «що малюється» видно одразу.
	var sun_node = _run.get("sun")
	var shadow_txt := "?" if not is_instance_valid(sun_node) \
		else ("так" if bool(sun_node.get("shadow_enabled")) else "ні")
	rows.append("швидкість %.2f м/с · метрів %.0f · профіль %s · якість %s · тінь %s"
		% [float(_run.get("speed")), float(_run.get("level_distance_m")),
			AgeAdapt.current, Quality.current(), shadow_txt])

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
