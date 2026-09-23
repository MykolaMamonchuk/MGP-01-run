## ПРОГІН ПО ВАРІАНТАХ СЦЕНИ прямо на пристрої: сам вимикає шматки й сам друкує час кадру.
##
## Навіщо. Кадр на Redmi 8A — 133 мс, і розкласти його можна лише дослідом. Робити шість
## дослідів шістьма збірками — півгодини й шість різних APK, які вже не зовсім порівнянні.
## Тут одна збірка проганяє всі варіанти поспіль, тими самими очима й на тій самій сцені.
##
## Живе в src/ui/, а не в src/debug/: друга тека ВИКЛЮЧЕНА з експорту (docs/web.md), тож на
## пристрої її просто не було б.
##
## Вмикається прапорцем збірки "strip_probe" — його ставлять у пресет на час замірів.
extends Node

## Скільки чекати після зміни варіанта, перш ніж почати міряти: сцені треба перемалюватись,
## а драйверу — дійти до сталого стану. На семи кадрах за секунду це помітний час.
const SETTLE_SEC := 1.8
## Скільки міряти кожну сходинку масштабу.
const MEASURE_SEC := 2.2

## СХОДИ МАСШТАБУ РЕНДЕРА — обхід кванта. Android пакує кадр по 16,67 мс на рівні
## компонувальника системи, і вимкнути це з гри не можна: ні DisplayServer, ні
## display/window/vsync/vsync_mode=0 не діють, а часомір GPU у бекенді Compatibility
## повертає нулі. Один замір тому завжди падає на цілий квант і ховає все, що менше за
## 16,67 мс. Але якщо проганяти варіант на кількох масштабах, крива перетинає межі квантів
## у різних місцях, і СУМА медіан стає неперервною й монотонною за справжньою ціною.
## Це звичайний дизеринг квантованого вимірювача, тільки замість шуму — відомі сходи.
const RAMP := ["45", "60", "75", "90", "100"]

## УВАГА: фіксований масштаб годиться ЛИШЕ для питання «чи тримає профіль ціль», де ціль
## сама є межею кванта. Для порівняння варіантів між собою він НЕ годиться: 22.09.2026 такий
## прогін дав 133,7 / 133,3 / 116,7 / 116,7 / 100,0 — тобто рівно 8, 7 і 6 квантів, причому
## два різні варіанти збіглися в одне число. Порівнювати варіанти можна тільки сходами.
##
## Крок може задати СВІЙ фіксований масштаб ("scale": "70") — тоді сходи не потрібні.
## Так міряють не «що дорожче», а «чи вкладається профіль у ціль», і там квант не заважає:
## ціль 33,3 мс сама є межею кванта (два інтервали, 30 к/с), тож чесна продуктова метрика —
## ЧАСТКА КАДРІВ, що вклались у два кванти. Один довгий замір замість п'яти коротких.
const MEASURE_FIXED_SEC := 7.0
## Ціль профілю слабкого пристрою: 30 к/с. Трохи запасу на похибку годинника.
const TARGET_MS := 33.4

## ОБОВ'ЯЗКОВО ПОВТОРЮВАТИ БАЗУ В КІНЦІ. Adreno 505 дроселює: заміряно, що за десять
## хвилин прогону CPU падає з 2,02 до 1,30 ГГц, і той самий варіант дає 94 мс на початку
## й 130 у середині. Без контрольного заміру наприкінці неможливо відрізнити «стало гірше
## від зміни» від «телефон нагрівся». Це та сама вимога, що й контрольний прогін проби на
## Маку (docs/MEMORY.md), тільки причина фізична.
## Перший прогін (21.09.2026) показав: декор і забудова коштують 39 мс зі 133, тіні 22, а
## кількість викликів і примітивів майже ні до чого (половина забудови дала лише 2,8 мс).
## Отже лишається 94 мс НА ПОРОЖНІЙ сцені, і саме їх шукає цей набір: повноекранні ефекти
## (світіння, кольорокорекція, туман) і великі поверхні (вода, небо).
## Дві фази. Перша розбирає ПІДЛОГУ — ті 53,5 мс, що лишаються на майже порожній сцені:
## занадто багато навіть для Adreno 505, і треба знати, чи це заповнення, чи матеріали, чи
## сама ціна проходу Compatibility. Друга міряє СПРАВЖНІЙ РІВЕНЬ, бо продуктове рішення
## визначає він, а не меню з діорамою.
const MIN := ["water", "fog", "shadows", "decor", "glow", "adjust", "sky"]
## Розклад РІВНЯ (меню вже розібрано: траса 33 мс із 53, герой 0, інтерфейс 3, а порожній
## екран 16,8 мс — це вертикальна синхронізація 60 Гц, не наша вартість).
##
## На рівні тіні коштують 1 мс, а забудова 1,8 — тобто винна велика поверхня під ногами.
## Розбираємо саме її: канали (той самий шейдер води на 311 рядків, підбивка 40×6), береги,
## і вся траса разом.
## Уся траса коштує 108 мс зі 133 на рівні, і з них канали лише 8,5, береги нуль. Отже
## ~94 мс — саме ПОЛОТНО. Воно складене з двох шарів на ту саму площу: основа ряду й
## плитка, піднята над нею на сантиметр. Перевіряємо, чи це подвійне заповнення.
## Основа дороги й плитка виявились безкоштовними (по 0,2 мс), хоч уся траса коштує 108.
## Отже винне якесь інше «полотно»: узбіччя, обрив, шов, край або хмари.
## ЩО ВЖЕ ВІДПОВІДЖЕНО ЦИМ ІНСТРУМЕНТОМ (не переміряти без потреби):
## - ціна декору — це фонова ЗАБУДОВА (159 зі 190 показника), придорожня дрібниця 18;
## - ціна забудови лінійна за ГЕОМЕТРІЄЮ, а не за матеріалами: половина екземплярів знімає
##   половину ціни (9,1 з 17,4), а половина шарів — лише 3,4 при більшій кількості знятих
##   викликів малювання. Отже потрібні дешеві моделі, а не спільний матеріал;
## - жоден профіль із живою забудовою не бере 30 к/с: навіть 0.5 без усієї забудови — 37,5 мс;
## - масштаб і полегшення сцени працюють лише РАЗОМ (тінь декору дає 2 мс на 1.0 і 9 на 0.45).
## ТЕСТОВА ТРАСА, ДОДАВАЛЬНА. Починаємо з порожнечі й додаємо по одній системі.
##
## Чому саме так, а не «прибирати з повної сцени». Коли прибираєш річ із важкої сцени, інші
## її маскують: заповнення перекрите, тіні лягають одна на одну, і різниця виходить меншою
## за справжню. Коли ДОДАЄШ до порожньої — міряєш саме її, без сусідів.
##
## Кожен крок = попередній плюс одна система. Число в дужках у звіті — це вже не «скільки
## коштує прибрати», а «скільки коштує ДОДАТИ».
const OFF_ALL := ["shadows", "fog", "glow", "adjust", "sky", "particles", "water", "banks",
	"decor", "roadbase", "roadtiles", "mm_side", "mm_cliff", "mm_seam", "mm_edge", "mm_clouds"]


## Прибирає зі списку вимкненого те, що на цьому кроці ВМИКАЄМО.
static func _on(names: Array) -> Array:
	var out: Array = []
	for f in OFF_ALL:
		if not names.has(f):
			out.append(f)
	return out


## СЕРІЯ НА ОДНІЙ ТРАСІ. Зерно прибите, рівень той самий, порядок кроків незмінний —
## лише так числа сусідніх кроків можна віднімати одне від одного.
##
## «Тільки герой» повторюється ЧОТИРИ рази як контроль: серія довга, а телефон дроселює,
## тож без проміжних контролів не відрізнити «додали систему» від «телефон нагрівся».
const STEPS := [
	{"назва": "прогрів (не рахується)", "flags": [], "level": true, "warm": true},
	{"назва": "К тільки герой", "flags": OFF_ALL + ["noobstacles"]},
	{"назва": "W1 вода як є", "flags": ["shadows", "fog", "glow", "adjust", "sky", "particles", "decor", "noobstacles"]},
	{"назва": "W5 вода БЕЗ ОСВІТЛЕННЯ", "flags": ["shadows", "fog", "glow", "adjust", "sky", "particles", "decor", "noobstacles", "waterunlit"]},
	{"назва": "W6 вода без світла й хвилі", "flags": ["shadows", "fog", "glow", "adjust", "sky", "particles", "decor", "noobstacles", "waterunlit", "waterflat"]},
	{"назва": "контроль: вода як є", "flags": ["shadows", "fog", "glow", "adjust", "sky", "particles", "decor", "noobstacles"]},
]



var run: Node

var _step := -1
var _t := 0.0
var _measuring := false
var _frames := 0
var _sum := 0.0
## Кожен кадр окремо, а не лише сума: середнє тягне за собою і поодинокі викиди від
## планувальника та дроселювання, і саме через нього дві однакові сцени дають різні числа.
## Медіана каже, як воно насправді, p95 — наскільки погано буває.
var _ticks := PackedFloat32Array()
## Те саме, але часом самої відеокарти — число, якого синхронізація не торкається.
var _gpu := PackedFloat32Array()
var _cpu := PackedFloat32Array()
var _vp_rid: RID
var _rows: Array = []
## Звіт пишемо ще й у файл. На Android досить logcat, а на iOS вивід Godot у консоль
## devicectl не потрапляє взагалі (він іде в системний журнал, який `log stream` у свіжих
## macOS з пристрою вже не читає). Файл із контейнера застосунку забирається однаково на
## обох: `adb pull` і `devicectl device copy from --domain-type appDataContainer`.
const REPORT := "user://strip_report.txt"
## ПОВНИЙ ЖУРНАЛ, по рядку на КОЖНУ сходинку масштабу кожного варіанта. Текстовий звіт добрий
## для читання очима, але для аналітики потрібні всі показники поруч і в машинному вигляді.
const TSV := "user://strip_log.tsv"
const TSV_HEAD := ["варіант", "масштаб", "мед_мс", "p95_мс", "мін_мс", "кс",
	"виклики", "примітиви", "обєкти", "відео_мб", "текстури_мб", "буфери_мб",
	"цп_рендера_мс", "пам_статична_мб", "обєктів_усього", "вузлів", "ресурсів",
	"безхазяйних", "фіз_процес_мс", "процес_мс"]
var _log: PackedStringArray = []
var _tsv: PackedStringArray = []
var _rung := 0
var _rungs: Array = []
var _share := 0.0
var _p95 := 0.0
var _gpu_med := 0.0
var _cpu_med := 0.0


func _ready() -> void:
	# ВЕРТИКАЛЬНА СИНХРОНІЗАЦІЯ ОБОВ'ЯЗКОВО ГЕТЬ. Без цього кадр квантується по 16,67 мс, і
	# вимір бреше найгіршим способом — мовчки. Сім прогонів поспіль давали 133,1…133,6 мс на
	# геть різних сценах (251 і 187 викликів, 292 і 144 тисячі примітивів) — це рівно вісім
	# інтервалів 60 Гц, а не «зміна нічого не дала». Будь-яка правка, що не перескакує через
	# межу кванта, показується як нуль, а та, що перескакує, — як цілий квант.
	# Вимкнути синхронізацію з рантайму на Android із GLES НЕ ВИХОДИТЬ: DisplayServer приймає
	# виклик і мовчки нічого не робить (перевірено — медіани лишились рівно 8/7/6 квантів).
	# Тому міряємо не годинник, а САМ КАДР НА ВІДЕОКАРТІ: viewport_set_measure_render_time
	# дає час, який синхронізація не чіпає взагалі. Годинник лишаємо поруч — як контроль.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	_say("СТРИП-ПРОГІН: %d варіантів по %.0f с, синхронізація=%d" % [
		STEPS.size(), SETTLE_SEC + MEASURE_SEC,
		DisplayServer.window_get_vsync_mode()])
	_next_step()


func _next_step() -> void:
	if _step >= 0:
		_record()
	_rung = 0
	_rungs = []
	_step += 1
	if _step >= STEPS.size():
		_report()
		queue_free()
		return
	# Перехід у справжній рівень — один раз, на кроці, позначеному "level".
	if bool((STEPS[_step] as Dictionary).get("level", false)):
		# ПРИБИТЕ ЗЕРНО. Траса складається випадково, і без цього два прогони порівнюють
		# різні світи: різна забудова, різні перешкоди, різна площа на екрані. Для
		# додавального досліду це фатально — там кожен крок відрізняється від сусіднього на
		# одну систему, і шум від іншої траси перекриє різницю.
		seed(20260923)
		run.get("menu").call("hide_menu")
		run.call("_start_level", 1)
	_apply()


## Масштаб подаємо ТИМ САМИМ шляхом, що й решту прапорців, а не прямо у viewport: власний
## таймер у run3d щосекунди застосовує прапорці наново (шари декору заводяться ліниво) і
## затер би пряме встановлення на кожному сьомому кадрі.
## Сходи цього кроку: або спільні RAMP, або одна сходинка з власним масштабом.
func _ramp() -> Array:
	var fixed := String((STEPS[_step] as Dictionary).get("scale", ""))
	return RAMP if fixed.is_empty() else [fixed]


func _measure_sec() -> float:
	return MEASURE_SEC if String((STEPS[_step] as Dictionary).get("scale", "")).is_empty() \
		else MEASURE_FIXED_SEC


func _apply() -> void:
	var flags := PackedStringArray()
	for f in (STEPS[_step]["flags"] as Array):
		flags.append(String(f))
	flags.append("scale" + String(_ramp()[_rung]))
	run.call("debug_strip", flags)
	_t = 0.0
	_measuring = false
	_frames = 0
	_sum = 0.0
	_ticks = PackedFloat32Array()
	_gpu = PackedFloat32Array()
	_cpu = PackedFloat32Array()


func _process(delta: float) -> void:
	_t += delta
	if not _measuring:
		if _t >= SETTLE_SEC:
			_measuring = true
			_t = 0.0
		return
	_frames += 1
	_sum += delta
	_ticks.append(delta)
	# На Android у Compatibility обидва числа — нулі (бекенд не реалізує часомір). На iOS
	# рушій іде через Metal, і там вони мають бути справжні: це прямий час кадру на
	# відеокарті, якого вертикальна синхронізація не торкається взагалі. Якщо він ненульовий,
	# сходи масштабу більше не потрібні — міряти можна просто.
	_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid))
	_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid))
	if _t < _measure_sec():
		return
	# Сходинка добігла: ховаємо її медіану й беремо наступну. Коли сходи скінчились —
	# наступний варіант.
	var t := _ticks.duplicate()
	t.sort()
	# Для фіксованого масштабу ховаємо ще й частку кадрів, що вклались у ціль: саме вона,
	# а не середнє, каже, чи профіль ТРИМАЄ 30 к/с, чи лише інколи їх торкається.
	var ok := 0
	for v in t:
		if 1000.0 * v <= TARGET_MS:
			ok += 1
	_share = 100.0 * float(ok) / float(maxi(1, t.size()))
	_p95 = _percentile(t, 0.95)
	var g := _gpu.duplicate()
	g.sort()
	var c := _cpu.duplicate()
	c.sort()
	_gpu_med = _percentile(g, 0.5) / 1000.0
	_cpu_med = _percentile(c, 0.5) / 1000.0
	_log_row(String(STEPS[_step]["назва"]), String(_ramp()[_rung]),
		_percentile(t, 0.5), _percentile(t, 0.95), _percentile(t, 0.0))
	_rungs.append(snappedf(_percentile(t, 0.5), 0.1))
	_rung += 1
	if _rung >= _ramp().size():
		_next_step()
	else:
		_apply()


## Друкує І зберігає. Переписуємо файл щоразу, щоб звіт лишився навіть якщо прогін урвався.
func _say(line: String) -> void:
	print(line)
	_log.append(line)
	var f := FileAccess.open(REPORT, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_log) + "\n")
		f.close()


## Один рядок журналу — усе, що рушій уміє віддати, на цій сходинці.
func _log_row(name: String, scale: String, med: float, p95: float, lo: float) -> void:
	var mb := 1048576.0
	var row := [name, scale, "%.1f" % med, "%.1f" % p95, "%.1f" % lo,
		"%.1f" % (1000.0 / maxf(0.001, med)),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"%.1f" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / mb),
		"%.1f" % (Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / mb),
		"%.1f" % (Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / mb),
		"%.2f" % (RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid)),
		"%.1f" % (Performance.get_monitor(Performance.MEMORY_STATIC) / mb),
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"%.2f" % (1000.0 * Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)),
		"%.2f" % (1000.0 * Performance.get_monitor(Performance.TIME_PROCESS)),
	]
	var line := ""
	for v in row:
		line += str(v) + "\t"
	# Друкуємо ЩЕ Й У ЛОГ: user:// на Android лежить у внутрішній пам'яті застосунку, а
	# `run-as` на релізній збірці не працює, тож файл звідти не забрати. Лог — єдиний
	# надійний канал назовні.
	_tsv.append(line.strip_edges())
	print("ТСВ\t" + line.strip_edges())
	if _tsv.size() == 1:
		var head := ""
		for h in TSV_HEAD:
			head += h + "\t"
		print("ТСВ\t" + head.strip_edges())
	var f := FileAccess.open(TSV, FileAccess.WRITE)
	if f != null:
		var head2 := ""
		for h in TSV_HEAD:
			head2 += h + "\t"
		f.store_string(head2.strip_edges() + "\n" + "\n".join(_tsv) + "\n")
		f.close()


func _percentile(sorted_ms: PackedFloat32Array, q: float) -> float:
	if sorted_ms.is_empty():
		return 0.0
	var i := clampi(int(floor(q * float(sorted_ms.size() - 1))), 0, sorted_ms.size() - 1)
	return 1000.0 * sorted_ms[i]


## Підсумок варіанта — СУМА медіан по сходах масштабу. Одне число, яке не падає на квант:
## навіть коли на одному масштабі різниці не видно, на іншому вона перетинає межу.
func _record() -> void:
	# Крок "прогрів" не записуємо. Старт рівня тягне за собою читання цеглинки, прогрів
	# пропсів і заведення шарів декору, і перший варіант через це виходив на 26 мс гіршим
	# за той самий контроль у кінці — тобто «база», з якою порівнювали решту, була брехнею.
	if bool((STEPS[_step] as Dictionary).get("warm", false)):
		return
	var total := 0.0
	for v in _rungs:
		total += float(v)
	_rows.append({
		"назва": STEPS[_step]["назва"],
		"сума": snappedf(total, 0.1),
		"сходи": _rungs.duplicate(),
		"виклики": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"примітиви": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
	})
	var d: Dictionary = _rows[-1]
	if not String((STEPS[_step] as Dictionary).get("scale", "")).is_empty():
		d["ціль"] = snappedf(_share, 1.0)
		d["p95"] = snappedf(_p95, 0.1)
		d["гпу"] = snappedf(_gpu_med, 0.1)
		d["цпу"] = snappedf(_cpu_med, 0.1)
		_say("СТРИП %-26s мед %6.1f  p95 %6.1f  у цілі %3d%%  ЦПУ %5.1f  викл %4d  прим %7d" % [
			d["назва"], float(d["сходи"][0]), float(d["p95"]), int(d["ціль"]),
			float(d["цпу"]), d["виклики"], d["примітиви"]])
		return
	d["гпу"] = snappedf(_gpu_med, 0.1)
	_say("СТРИП %-26s показник %7.1f  сходи %s  ГПУ %5.1f  викл %4d  прим %7d" % [
		d["назва"], d["сума"], str(d["сходи"]), float(d["гпу"]),
		d["виклики"], d["примітиви"]])


func _report() -> void:
	_say("СТРИП-ПІДСУМОК ==========================================")
	for r in (run.get("track").call("decor_report") as Array):
		var d: Dictionary = r
		if int(d["разом"]) == 0:
			continue
		_say("СТРИПШАР №%2d %-24s екз %4d  верш %6d  тінь %d  %s" % [
			int(d["№"]), d["шар"], int(d["екз"]), int(d["верш"]),
			1 if d["тінь"] else 0, d["мат"]])
	var base := float((_rows[0] as Dictionary)["сума"]) if not _rows.is_empty() else 0.0
	for r in _rows:
		var d: Dictionary = r
		if d.has("ціль"):
			_say("СТРИП %-26s мед %6.1f  p95 %6.1f  у цілі %3d%%  ЦПУ %5.1f  викл %4d  прим %7d" % [
				d["назва"], float(d["сходи"][0]), float(d["p95"]), int(d["ціль"]),
				float(d["цпу"]), int(d["виклики"]), int(d["примітиви"])])
			continue
		var gain := base - float(d["сума"])
		_say("СТРИП %-26s показник %7.1f (%+7.1f)  сходи %s  викл %4d  прим %7d" % [
			d["назва"], float(d["сума"]), -gain, str(d["сходи"]),
			int(d["виклики"]), int(d["примітиви"])])
	_say("СТРИП-ПІДСУМОК ==========================================")
