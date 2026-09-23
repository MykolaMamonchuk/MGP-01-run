## Питання до живої гри — числами й справжнім кадром. Не частина гри.
##
##   OUT=/tmp/probe STAGE=level LEVEL=1 FRAMES=300 \
##     /Applications/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 res://tools/probe/probe.tscn
##
## Ручки: STAGE (menu | level | map), LEVEL, FRAMES, RESET, PROFILE, RESIZE, BURST, PAUSE, NUDGE,
## SHADOWS=0 (зняти кадр без проходу тіней — щоб заміряти його ціну),
## STRIP=roadbase,mm_seam (прапорці досліду — ДИВИТИСЬ, що зникає з кадру; ціну міряє телефон),
## DEBUG_HUD=0 (сховати дебаг-накладку: для знімків ВИГЛЯДУ вона затуляє чверть кадру),
##
## Щоб побачити те, що бачить БРАУЗЕР, додай прапорець рушія самому Godot:
##   --rendering-method gl_compatibility
## Веб-збірка йде саме на ньому (Vulkan у браузері немає), і частина речей там інакша —
## глибинної текстури нема зовсім. Так знайшлась біла вода; подробиці в docs/web.md.
## QUALITY=smooth|middle|pretty (якість зображення — згладжування), PARENTS=1 (екран батьків).
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


## [середнє, 1% low, найгірший, к/с] за останнім вікном — рахується в _frames_passed.
var _wall := [0.0, 0.0, 0.0, 0.0]
var _wall_ms: Array = []
## Кадри, довші за SPIKE_MS, разом із тим, що діялось у грі саме тоді. Середній кадр і
## навіть 1% low про смики не кажуть нічого: 38 мс серед 16,7 — це один кадр із тисячі, але
## саме він відчувається пальцем. Питання не «скільки», а «ДЕ і чому».
const SPIKE_MS := 25.0
var _spikes: Array = []
var _frame_no := 0


func _ready() -> void:
	seed(SEED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	DirAccess.make_dir_recursive_absolute(_out)
	# RESET=1 — міряти з чистого аркуша. Без цього проба бачить ВАШ прогрес, і той самий
	# STAGE дає різні екрани на різних машинах, тобто порівнювати «до/після» нічим.
	if OS.get_environment("RESET") == "1":
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
		# Видалити файл мало: SaveService прочитав його ЩЕ ДО старту проби, і в пам'яті
		# лишається стан попереднього прогону (а він же й запишеться назад). Через це два
		# прогони поспіль ішли з різних станів: заміряно 19.09.2026 — кадр одного прогону
		# показував 5 монет і одне серце, наступного 63 монети й три серця, тобто
		# порівнювати їх було нічим. Перечитуємо явно: файлу нема — буде чистий дефолт.
		SaveService.load_game()
	# QUALITY=smooth|middle|pretty — стан налаштування «Якість зображення» (автолоад Quality).
	# Без цієї ручки проба міряла б у тому стані, який лишився у ВАШОМУ збереженні: RESET
	# видаляє файл, але SaveService прочитав його ще до старту проби, тож у пам'яті лишається
	# старе значення. Застосовуємо ДО першого кадру й НЕ пишемо в збереження.
	if OS.has_environment("QUALITY"):
		Quality.apply_state(OS.get_environment("QUALITY"))
	_run = load("res://src/run3d/run3d.tscn").instantiate()
	add_child(_run)
	await _frames_passed(30)

	if _stage == "map":
		# Мапа рівнів. Без цієї гілки перевірити «чому не тапається вузол» можна було лише
		# оком: усі кнопки мапи будуються кодом, тож у звіт вони потрапляють лише тоді,
		# коли екран справді відкрито.
		_run.menu.hide_menu()
		_run._open_map()
		await _frames_passed(_frames)
	elif _stage == "level":
		# Профіль задає швидкість бігу, а швидкість прямо впливає на мерехтіння — без
		# фіксації два прогони порівнювати НЕ МОЖНА (наступив 17.09.2026: «до» вийшло
		# older на 42 км/год, «після» young на 28, і різниця в числах була від швидкості).
		AgeAdapt.set_profile(OS.get_environment("PROFILE") if OS.has_environment("PROFILE") else "older")
		_run.menu.hide_menu()
		_run._start_level(_level)
		await _frames_passed(_frames)
	else:
		await _frames_passed(_frames)

	# PARENTS=1 — відкрити екран батьків перед знімком. Панель налаштувань будується кодом
	# і росте від кожного нового рядка, тож перевіряти її треба геометрією (вона потрапляє
	# в "controls" звіту) і кадром, а не вірою.
	# SHADOWS=0 — вимкнути прохід тіней і зняти кадр без нього. Потрібно, щоб ЗАМІРЯТИ, у
	# скільки draw calls він обходиться саме зараз: число залежить від того, скільки в кадрі
	# тінекидачів, а забудова росте. Вимикаємо ПІСЛЯ прогону, щоб гра йшла однаково.
	# SHADOW_DIST=14 — дальність проходу тіней (directional_shadow_max_distance). Тінь від
	# другого ряду забудови лягає туди, куди гравець і так майже не дивиться, а коштує вона
	# стільки ж, скільки від першого. Ручка — щоб підібрати межу заміром, а не на око.
	if OS.has_environment("SHADOW_DIST"):
		var sun_d := _run.get_node_or_null("Sun") as DirectionalLight3D
		if sun_d != null:
			sun_d.directional_shadow_max_distance = float(OS.get_environment("SHADOW_DIST"))
			await _frames_passed(5)

	# ENV_GLOW=0 / ENV_ADJ=0 — вимкнути блум і кольорокорекцію, щоб з'ясувати, ЩО САМЕ
	# пересвічує кадр. Питання постало на Compatibility: там чисто білих пікселів у
	# дев'ятнадцять разів більше, ніж на мобільному рушії.
	# ENV_GLOW=0 / ENV_ADJ=0 — вимкнути блум і кольорокорекцію, щоб з'ясувати, ЩО САМЕ
	# пересвічує кадр. Кадри після зміни чекаємо ЛИШЕ тоді, коли щось справді змінили:
	# безумовний `await` тут зсував знімок на три кадри в КОЖНОМУ прогоні, і два однакові
	# заміри «до/після» розходились на третину пікселів ні через що.
	var touched := false
	var e := (_run.get_node_or_null("WorldEnvironment") as WorldEnvironment)
	if e != null and e.environment != null:
		if OS.get_environment("ENV_GLOW") == "0":
			e.environment.glow_enabled = false
			touched = true
		if OS.get_environment("ENV_ADJ") == "0":
			e.environment.adjustment_enabled = false
			touched = true
	if touched:
		await _frames_passed(3)

	# SHADOW_LIST=1 — перепис УСІХ тінекидачів кадру: хто саме кидає тінь і скільки
	# екземплярів у нього видно. Прохід тіней коштує по одному draw call на кожен такий
	# вузол, тож цей список і є відповіддю на питання «кому тінь лишити».
	if OS.get_environment("SHADOW_LIST") == "1":
		var rows: Array = []
		var stack: Array = [_run]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for ch in node.get_children():
				stack.append(ch)
			if node is GeometryInstance3D:
				var gi := node as GeometryInstance3D
				if gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					continue
				if not gi.visible:
					continue
				var n := 1
				var kind := node.name
				if node is MultiMeshInstance3D:
					var mm := (node as MultiMeshInstance3D).multimesh
					n = mm.visible_instance_count if mm != null else 0
					if n == 0:
						continue
				# Назва вузла службова, тож вид шукаємо в самій трасі: _decor_layer_of
				# зіставляє ключ шару з його номером у _decor_mm.
				var tr := _run.get_node_or_null("Track")
				if tr != null and node is MultiMeshInstance3D:
					var arr: Array = tr.get("_decor_mm")
					var at := arr.find(node)
					if at >= 0:
						for key in (tr.get("_decor_layer_of") as Dictionary).keys():
							if int((tr.get("_decor_layer_of") as Dictionary)[key]) == at:
								kind = String(key)
								break
				rows.append({"вид": kind, "видно": n, "тип": node.get_class()})
		var f := FileAccess.open("%s/shadows.json" % _out, FileAccess.WRITE)
		f.store_string(JSON.stringify(rows, "\t"))
		f.close()
		print("тінекидачів: %d" % rows.size())

	if OS.get_environment("SHADOWS") == "0":
		var sun := _run.get_node_or_null("Sun") as DirectionalLight3D
		if sun != null:
			sun.shadow_enabled = false
			await _frames_passed(5)

	if OS.get_environment("PARENTS") == "1":
		var hud := _run.get_node_or_null("HUD")
		if hud != null:
			hud._open_parents()
			await _frames_passed(5)

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/frame.png" % _out)

	# QUALITY_LIVE=smooth|middle|pretty — перемкнути якість НА ХОДУ, як це робить кнопка на
	# екрані батьків, і зняти другий кадр (frame_live.png). Гру спиняємо паузою, щоб між
	# двома знімками змінилось РІВНО згладжування, а не ще й положення героя. Порівняння
	# frame_live.png із кадром прогону, що СТАРТУВАВ у цьому стані, і є доказ, що
	# застосування працює без перезапуску.
	if OS.has_environment("QUALITY_LIVE"):
		get_tree().paused = true
		await _frames_passed(2)
		Quality.set_current(OS.get_environment("QUALITY_LIVE"))
		await _frames_passed(3)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/frame_live.png" % _out)
		get_tree().paused = false

	# BURST=N — N кадрів ПОСПІЛЬ, без пропусків. Для пошуку миготіння: воно має підпис
	# «змінилось і повернулось», а рух камери такого не дає — там піксель їде далі.
	# PAUSE=1 спиняє дерево перед серією: що мигає й на СТОЯЧІЙ картинці — то справжнє
	# миготіння, а що зникає — то мерехтіння від руху (недосемплена дрібна деталь).
	if OS.get_environment("PAUSE") == "1":
		get_tree().paused = true
		await _frames_passed(5)
	# NUDGE=0.004 — на ПАУЗІ зсувати камеру на частку пікселя між кадрами. Часового шуму
	# тоді немає взагалі (гра стоїть, анімації стоять), і лишається чиста чутливість
	# картинки до піврухів камери: z-fight від такого зсуву мав би стрибати стрибком, а
	# нормальна геометрія — плавно повзти. Задум такий; ЧЕСНО ПРО МЕЖІ: на калібруванні
	# (EDGE_LIFT=0, де коментар у track.gd обіцяє «гарантований z-fight») прилад НЕ показав
	# різниці з HEAD. Камера при цьому справді рухається — 3 см зсуву міняють 22% пікселів.
	# Отже або та копланарність не конфліктує насправді, або чутливості все одно бракує.
	# Довіряти цьому показнику наосліп не можна, поки він не розрізнить завідомий випадок.
	var nudge := float(OS.get_environment("NUDGE")) if OS.has_environment("NUDGE") else 0.0
	var cam := get_viewport().get_camera_3d()
	var burst := int(OS.get_environment("BURST")) if OS.has_environment("BURST") else 0
	for i in range(burst):
		if nudge != 0.0 and cam != null:
			cam.global_position += cam.global_transform.basis.x * nudge
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

	# Хто саме їсть кадр. Декор малюється шарами MultiMesh — один шар на вид моделі, — і
	# ціна шару це «трикутники моделі × скільки копій ВИДНО зараз». Без цієї розкладки
	# «важка модель» лишається здогадкою: у файлі модель може важити 100 тисяч граней і не
	# коштувати нічого, бо в грі замість неї малюється спрайт (так із bush_flower).
	var decor := _decor_cost()

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
			# Трикутники кадру. Без цього числа «важка модель чи ні» лишається відчуттям:
			# декор малюється через MultiMesh, а там LOD НЕ працює — кожен інстанс коштує
			# повну сітку, тож ціна моделі множиться на кількість будинків у кадрі.
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			"texture_mem_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
			# Економіка: скільки злитків НАРАХОВАНО за пробіг і скільки метрів пройдено. Модель
			# доходу в EDD рахувалась на процедурних групах; на авторських цеглинках груп інша
			# кількість, тож перевіряти її треба заміром, а не арифметикою.
			"level_coins": int(_run.get("level_coins")) if _run != null else 0,
			"coins_spawned": int(_run.get("spawner").get("stars_spawned_segment")) if _run != null and _run.get("spawner") != null else 0,
			"coins_taken": int(_run.get("spawner").get("stars_collected_segment")) if _run != null and _run.get("spawner") != null else 0,
			"level_distance_m": snappedf(float(_run.get("level_distance_m")) if _run != null else 0.0, 0.1),
			# ЧАС КАДРУ ГОДИННИКОМ, а не з delta й не з TIME_PROCESS. TIME_PROCESS міряє
			# лише скрипти (0,3 мс), delta під --fixed-fps синтетична (завжди 16,7), і обидва
			# показували «60 к/с» там, де вікно насправді йшло по 30. Ці чотири числа беруться
			# з того самого вікна, тож найгірший ≥ 1% low ≥ середнє завжди.
			"wall_avg_ms": _wall[0], "wall_low1_ms": _wall[1],
			"wall_worst_ms": _wall[2], "wall_fps": _wall[3],
			"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(
				get_viewport().get_viewport_rid()),
			"render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(
				get_viewport().get_viewport_rid()),
		},
		# Усі кадри, довші за SPIKE_MS, із контекстом. Найдовші — першими.
		"spikes": _spikes_sorted(),
		"controls": _controls(_run),
		"decor_cost": decor,
	}
	var f := FileAccess.open("%s/probe.json" % _out, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("PROBE ok → %s (контролів: %d)" % [_out, (report["controls"] as Array).size()])
	get_tree().quit()


## [{kind, instances, tris_each, tris_total}] за спаданням ціни. Читає приватні поля Track
## навмисно: це вимірювальний інструмент, а не частина гри, і окремий API заради нього в
## гарячому класі заводити не варто.
func _decor_cost() -> Array:
	var out: Array = []
	var track = _run.get("track") if _run != null else null
	if track == null:
		return out
	var layer_of: Dictionary = track.get("_decor_layer_of")
	var names := {}
	for key in layer_of.keys():
		names[int(layer_of[key])] = String(key)
	var mms: Array = track.get("_decor_mm")
	for i in range(mms.size()):
		var mi: MultiMeshInstance3D = mms[i]
		var mm := mi.multimesh as MultiMesh
		if mm == null or mm.mesh == null or mm.visible_instance_count <= 0:
			continue
		var tris := mm.mesh.get_faces().size() / 3
		out.append({
			"kind": names.get(i, "?"),
			"instances": mm.visible_instance_count,
			"tris_each": tris,
			"tris_total": tris * mm.visible_instance_count,
		})
	out.sort_custom(func(a, b): return int(a["tris_total"]) > int(b["tris_total"]))
	return out


func _frames_passed(n: int) -> void:
	for i in range(n):
		var t0 := Time.get_ticks_usec()
		await get_tree().process_frame
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		_frame_no += 1
		_wall_ms.append(ms)
		if ms > SPIKE_MS:
			_spikes.append(_spike_context(ms))
		# тримаємо останні 8 секунд при 60 к/с — те саме вікно, що й у накладці
		if _wall_ms.size() > 480:
			_wall_ms.remove_at(0)
	_wall = _wall_stats()


## Що діялось у грі в мить смику. Знімаємо ВСЕ, що може бути причиною, і вже потім
## дивимось, чи сплески збігаються по місцю: якщо так — це підвантаження, спавн, перша
## компіляція шейдера, розігрів часточок; якщо ні — шукати треба поза грою.
func _spike_context(ms: float) -> Dictionary:
	var vp := get_viewport().get_viewport_rid()
	var out := {
		"кадр": _frame_no,
		"мс": snappedf(ms, 0.1),
		# Де саме згаяно: у скриптах гри, у рушії на боці CPU, чи на боці GPU. Без цього
		# поділу «38 мс» не каже нічого, і лікувати можна не те: прогрів мешів прибрав
		# сплеск на 2,9 м, а сусідній на 37,1 не зрушив ні на міліметр.
		"скрипти_мс": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1),
		"рендер_cpu_мс": snappedf(RenderingServer.viewport_get_measured_render_time_cpu(vp), 0.1),
		"рендер_gpu_мс": snappedf(RenderingServer.viewport_get_measured_render_time_gpu(vp), 0.1),
		"виклики": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"примітиви": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"вузлів": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"тіл_фізики": int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
		"озп_мб": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"відео_мб": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
	}
	if _run != null:
		out["метрів"] = snappedf(float(_run.get("level_distance_m")), 0.1)
		out["монет"] = int(_run.get("level_coins"))
		out["стан"] = int(_run.get("state"))
		var hero = _run.get("hero")
		if hero != null:
			out["доріжка"] = int(hero.get("lane"))
		var sp = _run.get("spawner")
		if sp != null:
			out["курсор_перешкод"] = int(sp.get("_authored_cursor"))
		# Скільки ШАРІВ декору вже заведено. Кожен новий шар — це створення
		# MultiMeshInstance3D, завантаження меша з PropLibrary і ПЕРШЕ малювання цим
		# матеріалом, тобто компіляція шейдера. Якщо число стрибає рівно на смику — причина
		# знайдена, і лікується вона прогрівом, а не оптимізацією.
		var tr = _run.get("track")
		if tr != null:
			out["шарів"] = (tr.get("_decor_mm") as Array).size()
		# Чанк рівня читається у ФОНІ, але збирається (instantiate + extract, заміряно ~23 мс)
		# на головному потоці — тож межа чанка сама по собі підозрюваний. Число росте рівно
		# тоді, коли черговий шматок забрали з потоку.
		var cl = _run.get("_chunk_loader")
		if cl != null:
			out["чанків_взято"] = int(cl.get("_next"))
	return out


## [середнє, 1% low, найгірший, к/с]. 1% low — поріг, гірший за 99% кадрів вікна.
func _spikes_sorted() -> Array:
	var v := _spikes.duplicate()
	v.sort_custom(func(a, b): return float(a["мс"]) > float(b["мс"]))
	return v


func _wall_stats() -> Array:
	if _wall_ms.is_empty():
		return [0.0, 0.0, 0.0, 0.0]
	var v: Array = _wall_ms.duplicate()
	v.sort()
	var total := 0.0
	for x in v:
		total += float(x)
	var avg := total / float(v.size())
	var at := mini(v.size() - 1, int(float(v.size()) * 0.99))
	return [avg, float(v[at]), float(v[-1]), 1000.0 / maxf(avg, 0.001)]


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
