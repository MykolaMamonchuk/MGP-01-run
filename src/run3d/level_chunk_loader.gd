## Стрімінг авторського рівня по чанках: замість того, щоб вантажити ЦІЛИЙ res://levels/level_XX.tscn
## одним махом (як робив старий _load_authored_level()), рівень ділиться на фіксовані
## відрізки CHUNK_LENGTH_M метрів — res://levels/level_XX/chunk_00.tscn, chunk_01.tscn, … —
## і кожен вантажиться лише тоді, коли гравець наближається до його межі. Формат самих чанків
## (LevelLayout із дітьми LevelMarker3D) і LevelTimeline.extract() лишаються без змін — чанкування
## міняє ЛИШЕ коли й скільки вантажиться, а не сам формат даних.
##
## Нема папки levels/level_XX/ (рівень ще не розбитий) → тихо повертаємось до старої поведінки:
## один-єдиний файл levels/level_XX.tscn вантажиться цілком при start(), update() більше нічого
## не робить. Так усі рівні, які ще не пройшли міграцію (tools/split_level_chunks.py), працюють
## як і раніше.
class_name LevelChunkLoader
extends RefCounted

## Довжина одного чанку в метрах — той самий поділ, яким tools/split_level_chunks.py розкладає
## маркери по файлах (floori(z_m / CHUNK_LENGTH_M)).
const CHUNK_LENGTH_M := 150.0
## Наскільки заздалегідь (у метрах ДО межі останнього завантаженого чанку) вантажити наступний —
## із запасом понад Spawner3D.SPAWN_Z (34 м), щоб і сьогоднішній синхронний load(), і завтрашній
## асинхронний ResourceLoader.load_threaded_request() встигли до того, як записи знадобляться.
const LOOKAHEAD_M := 80.0

var _num := 0
var _track: Track
var _spawner: Spawner3D
var _chunked := false          ## true — рівень зібрано з чанків, а не з одного плаского файлу
## ПЛАН рівня: [{id, paths, offset_m, length_m}] у порядку проходження. Раніше тут було припущення
## «чанк №N лежить у теці рівня й займає рівно 150 м» — і саме воно не давало ставити ту саму
## цеглинку двічі. Тепер план будує або збирач зі списку імен (ChunkLibrary.assemble), або, для
## старих рівнів-тек, сканування теки; завантажувачу однаково, звідки він узявся.
var _plan: Array = []
## Той самий план, розгорнутий у ЧЕРГУ ОКРЕМИХ СЦЕН: [{path, offset_m}]. Цеглинка — це один
## або два файли (сам чанк і вибрана розкладка перешкод) на ОДНОМУ зсуві, а читається з диска
## все одно по одному, тож черга й є тим, чим оперує завантаження.
var _queue: Array = []
var _next := 0                 ## індекс наступної НЕзавантаженої сцени в черзі
## Чанк, який ЗАРАЗ вантажиться у фоні (-1 — жодного) і його шлях.
## Навіщо фон. Заміряно 18.09.2026: чанк із 904 маркерами читається 46,8 мс, інстанціюється
## 5,9 і розбирається 17,2 — разом ~70 мс на Mac, отже 200–350 мс на телефоні. Синхронно це
## означало б підвисання ПОСЕРЕД БІГУ на кожній межі чанка, бо наступний тягнеться за 80 м до
## неї. Запас часу величезний: 80 м на 12 м/с — понад шість секунд, тож фонове читання
## встигає з великим лишком.
var _pending_index := -1
var _pending_path := ""
var _done := false             ## усі чанки рівня вже завантажені — update() більше не працює
## Скільки часу на кадр дозволено збиранню цеглинки. 1,5 мс — десята частина кадру на 60 к/с:
## помітити це неможливо, а десять міліметрів роботи розходяться кадрів на сім, тобто за
## одну восьму секунди при запасі в шість.
const STREAM_BUDGET_MS := 1.5
## Скільки маркерів розбирати за одну скибку. 120 із 780 — шість скибок приблизно по 0,4 мс.
const MARKERS_PER_STEP := 120
## Ближче за стільки метрів до початку цеглинки бюджет уже не тримаємо: краще один смик, ніж
## шматок дороги без перешкод і декору.
const STREAM_HURRY_M := 12.0
## Стан покрокового збирання: 0 — нічого не збираємо, далі стадії за _step_apply().
var _job_stage := 0
var _job_packed: PackedScene = null
var _job_layout: Node = null
var _job_markers: Array = []
var _job_cursor := 0
var _job_out: Dictionary = {}
var _job_offset := 0.0
var _job_decor: Array = []


## Спавнер може бути null — так його передає знімальний інструмент src/debug/track_shot.gd,
## якому потрібен лише декор рівня, без перешкод. Раніше це валило виклик і знімок робився
## без половини даних, мовчки: помилка друкувалась у консоль, а картинка виглядала цілою.
func _clear_obstacles() -> void:
	if _spawner != null:
		_spawner.clear_authored_obstacles()
		_spawner.clear_authored_pickups()


## Почати стрімінг рівня num: визначає, з чого рівень зібрано, вантажить перший шматок (або весь
## рівень) синхронно — гравець стартує з готовими першими записами. track/spawner — куди зливати
## LevelTimeline.extract(). level — запис рівня з data/levels.json: якщо він має список "chunks",
## рівень збирається з бібліотеки цеглинок; інакше працює старий шлях — тека levels/level_XX/.
func start(num: int, track: Track, spawner: Spawner3D, level: Dictionary = {}) -> void:
	_num = num
	_track = track
	_spawner = spawner
	_next = 0
	_done = false
	_pending_index = -1
	_pending_path = ""
	# Рівень, який НАЗВАВ цеглинки, іншими шляхами не ходить узагалі. Список у levels.json
	# перебиває і стару теку levels/level_XX/, і плаский levels/level_XX.tscn: інакше рівень,
	# переведений на бібліотеку, мовчки вантажив би дві розкладки одночасно, а зі зламаним
	# стиком — показував би геть іншу замість помилки, яку вже надруковано.
	var declared: Array = level.get("chunks", [])
	_plan = plan_of(num, level)
	_queue = _flatten(_plan)
	_chunked = not _queue.is_empty()
	track.clear_authored_timeline()
	_clear_obstacles()
	if _chunked:
		# Перший шматок — синхронно: гравець ще на екрані завантаження, підвисати нема де, а
		# стартувати без записів не можна.
		_load_first_chunk()
	elif declared.is_empty():
		_load_flat_level()
	else:
		_done = true


## План рівня БЕЗ завантаження: [{id, path, offset_m, length_m}] у порядку проходження.
##
## Статична навмисно. Цим самим планом ходять сторожі-інваріанти (test_level_reach,
## test_level_widening, test_level_decor_clearance, test_level_obstacle_types), які читають
## сцени текстом і вузлів не створюють. Доти кожен із них сам сканував теку рівня й сам
## рахував зсув з імені файлу — чотири копії одного знання. Після збирача така копія стала б
## не просто дублем, а мовчазною дірою: рівень, зібраний зі списку цеглинок, теки не має, і
## сторож обходив би порожнечу, нічого не перевіряючи й не скаржачись.
##
## level — запис рівня з data/levels.json. Порожній словник = «дивись лише в теку».
static func plan_of(num: int, level: Dictionary = {}) -> Array:
	var declared: Array = level.get("chunks", [])
	if declared.is_empty():
		return _plan_from_folder(num)
	# Зламана збірка — це порожній план, а не «зібрати як вийде»: рівень зі стиком «3 доріжки
	# віддає, 5 чекає» виглядав би як обрив дороги посеред бігу.
	var built := ChunkLibrary.assemble(level, ChunkLibrary.scan())
	var errors: Array = built["errors"]
	if errors.is_empty():
		return built["pieces"]
	for e in errors:
		push_error("рівень %d: %s" % [num, e])
	return []


## Розгорнути цеглинки в чергу окремих сцен. Обидва шари цеглинки йдуть на ОДИН зсув: це не
## два місця траси, а геометрія й розкладка перешкод одного місця.
static func _flatten(plan: Array) -> Array:
	var out: Array = []
	for piece in plan:
		for path in (piece as Dictionary).get("paths", []):
			out.append({"path": String(path), "offset_m": float(piece["offset_m"])})
	return out


## Старий шлях: тека levels/level_XX/ із чанками chunk_NN.tscn по CHUNK_LENGTH_M метрів.
## Пропущений номер — це просто порожній відрізок рівня, а не кінець: зсув рахується від
## НОМЕРА, тож дірка лишається діркою й не з'їжджає.
static func _plan_from_folder(num: int) -> Array:
	var out: Array = []
	var folder := "res://levels/level_%02d" % num
	var dir := DirAccess.open(folder)
	if dir == null:
		return out
	var indices: Array = []
	for name in dir.get_files():
		var base := name.get_basename()
		if base.get_extension() == "tscn":
			base = base.get_basename()
		if base.begins_with("chunk_"):
			indices.append(int(base.substr(6)))
	indices.sort()
	for index in indices:
		out.append({
			"id": "chunk_%02d" % index,
			"paths": ["%s/chunk_%02d.tscn" % [folder, index]],
			"offset_m": float(index) * CHUNK_LENGTH_M,
			"length_m": CHUNK_LENGTH_M,
		})
	return out


func update(distance_m: float) -> void:
	if not _chunked:
		return
	# Цеглинка вже прочитана й ЗБИРАЄТЬСЯ — крутимо стільки, скільки дозволяє бюджет кадру.
	# Поки не зібрали, нової не чіпаємо: два розбори водночас поклали б у Track записи
	# упереміш.
	if _job_stage != 0:
		_drain_jobs(distance_m + STREAM_HURRY_M >= _job_offset)
		return
	if _done:
		return
	# Чанк уже читається у фоні — просто перевіряємо, чи готовий. Нової заявки не подаємо,
	# доки не заберемо попередню: інакше два чанки поїхали б у Track одночасно й у різному
	# порядку.
	if _pending_index >= 0:
		_poll_pending()
		return
	if _next >= _queue.size():
		_done = true
		return
	# Шматок замовляється до того, як гравець дійде до ЙОГО ПОЧАТКУ. Раніше порівнювали з
	# кінцем попереднього — те саме, поки всі чанки однакової довжини, але з бібліотекою
	# цеглинки різні, та й дірку в нумерації так було не перескочити чесно.
	if distance_m + LOOKAHEAD_M >= float(_queue[_next]["offset_m"]):
		_request_next_chunk()


## Дочекатись, доки фоновий чанк дочитається. Потрібно ТЕСТАМ і знімальним інструментам, яким
## нема куди подіти час між кадрами. У грі цього не кличе ніхто: там update() іде щокадру й
## забирає чанк тоді, коли потік закінчив, — у цьому вся суть.
func finish_pending() -> void:
	while _pending_index >= 0:
		_poll_pending()
		if _pending_index >= 0:
			OS.delay_msec(1)
	# І дозбирати те, що поклав _poll_pending(): для тих, хто кличе finish_pending(), «готово»
	# означає «записи вже в Track і Spawner3D», а не «сцену прочитано».
	_drain_jobs(true)


## Забрати чанк, якщо він уже прочитався. Нічого не робить, доки потік не закінчив.
func _poll_pending() -> void:
	var status := ResourceLoader.load_threaded_get_status(_pending_path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var packed := ResourceLoader.load_threaded_get(_pending_path) as PackedScene
		if packed != null:
			# У БІГУ не збираємо одразу: заводимо покрокову роботу, яку update() дотягне за
			# кілька кадрів по STREAM_BUDGET_MS. Саме тут і був смик на кожній межі цеглинки.
			_begin_apply(packed, float(_queue[_pending_index]["offset_m"]))
	else:
		push_warning("чанк не прочитався: %s" % _pending_path)
	_pending_index = -1
	_pending_path = ""


## Подати заявку на наступний чанк, ПЕРЕСТРИБУЮЧИ відсутні номери: порожній відрізок рівня —
## це просто відсутній файл, а не кінець рівня.
func _request_next_chunk() -> void:
	while _next < _queue.size():
		var piece: Dictionary = _queue[_next]
		var path := String(piece["path"])
		_pending_index = _next
		_next += 1
		if not ResourceLoader.exists(path):
			push_warning("чанк не знайдено: %s" % path)
			continue
		ResourceLoader.load_threaded_request(path)
		_pending_path = path
		return
	_pending_index = -1
	_done = true              # план вичерпано — рівень завантажено повністю


## Зсув чанка за його ІМ'ЯМ файлу ("chunk_03.tscn" → 450). Потрібен тестам і інструментам, які
## розбирають сцени текстом і не мають кому передати зсув. Поки рівень — це тека з чанками по
## порядку, номер і є місцем; коли з'явиться збирач зі списку цеглинок, ця функція лишиться
## для старих рівнів, а збирач рахуватиме зсув накопичувально.
static func offset_for(file_name: String) -> float:
	var base := file_name.get_file().get_basename()
	if base.get_extension() == "tscn":
		base = base.get_basename()
	if not base.begins_with("chunk_"):
		return 0.0
	return float(int(base.substr(6))) * CHUNK_LENGTH_M


func _flat_path() -> String:
	return "res://levels/level_%02d.tscn" % _num


## Єдине місце, де чанк реально читається з диска — свідомо ізольоване від решти логіки: коли
## чанки нестимуть важкі ресурси (реальні .glb-будівлі "зовнішнього світу"), заміна на
## ResourceLoader.load_threaded_request()/load_threaded_get() торкнеться лише цієї функції.
func _load_chunk_resource(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


## Перша цеглинка рівня — синхронно й ЦІЛКОМ, усіма своїми шарами. Саме цілком: якби чанк
## завантажився зараз, а його розкладка перешкод лишилась фоновому потоку, перші метри рівня
## були б без перешкод — рідко, недетерміновано й тим гірше для пошуку. Гравець на цьому місці
## ще дивиться на екран завантаження, тож підвисати нема де.
func _load_first_chunk() -> void:
	var loaded := false
	var offset := 0.0
	while _next < _queue.size():
		var piece: Dictionary = _queue[_next]
		var at := float(piece["offset_m"])
		if loaded and not is_equal_approx(at, offset):
			return                       # почалась наступна цеглинка — вона вже фонова
		_next += 1
		var packed := _load_chunk_resource(String(piece["path"]))
		if packed == null:
			continue
		_apply(packed, at)
		loaded = true
		offset = at
	if not loaded:
		_done = true


func _load_flat_level() -> void:
	var packed := _load_chunk_resource(_flat_path())
	if packed == null:
		_done = true
		return
	_apply(packed, 0.0)
	_done = true               # єдиний файл — увесь рівень уже в Track/Spawner3D


## offset_m — на якому метрі траси стоїть цей чанк. Передає ТОЙ, ХТО СТАВИТЬ, а не сама
## сцена: цеглинку треба вміти поставити на 150-му метрі одного рівня й на 900-му іншого.
## Поки рівень — це тека з чанками по порядку, зсув дорівнює номер × CHUNK_LENGTH_M; коли
## з'явиться збирач зі списку цеглинок (docs/tasks/reusable-chunks.md), він рахуватиме його
## накопичувально, і більше нічого міняти не доведеться.
##
## Інстанціювати чанк ЛИШЕ заради LevelTimeline.extract() і одразу звільнити — так само, як
## робив старий _load_authored_level(): нічого з авторської сцени не потрапляє в живе дерево.
## Зібрати цеглинку ОДРАЗУ, за один виклик. Лишається для тих, кому нема куди подіти кадри:
## старт рівня (екран завантаження й так стоїть), плаский рівень, тести та інструменти.
func _apply(packed: PackedScene, offset_m: float) -> void:
	_begin_apply(packed, offset_m)
	while _step_apply():
		pass


## Зібрати цеглинку ПОКРОКОВО, вкладаючись у STREAM_BUDGET_MS на кадр.
##
## Навіщо. Читання давно фонове, а от збирання — instantiate, розбір маркерів, злиття —
## лишалось на головному потоці одним шматком: 24 мс до оптимізацій і ~10 мс після, тобто
## пропущений кадр рівно на стику цеглинок, кожні 150 м, і втричі гірше на телефоні.
## Стискати цей шматок далі нема сенсу: роботи там рівно стільки, скільки її є. Зате часу
## вдосталь — цеглинка замовляється за LOOKAHEAD_M (80 м, понад шість секунд), — тож робота
## ріжеться на кроки, і кожен кадр їй дозволено лише трохи.
##
## Кроки (стадії) свідомо різного розміру: найдорожче — розбір маркерів, і саме він ріжеться
## на скибки по MARKERS_PER_STEP. Решта — окремі стадії, кожна сама по собі дешевша за бюджет.
func _begin_apply(packed: PackedScene, offset_m: float) -> void:
	_job_packed = packed
	_job_offset = offset_m
	_job_stage = 1
	_job_cursor = 0
	_job_markers = []
	_job_out = {}
	_job_layout = null


## Один крок збирання. true — роботи ще лишилось.
func _step_apply() -> bool:
	match _job_stage:
		1:
			# Інстанс — єдиний крок, який не ріжеться нічим: або сцена розгорнулась, або ні.
			_job_layout = _job_packed.instantiate()
			_job_packed = null
			_job_stage = 2
		2:
			# Плоский список маркерів: рекурсію посеред кадру не спинити, а прохід по
			# готовому списку — скільки завгодно разів по скибці.
			_job_markers = LevelTimeline.markers(_job_layout)
			_job_out = LevelTimeline.begin_out()
			_job_stage = 3
		3:
			var to: int = mini(_job_cursor + MARKERS_PER_STEP, _job_markers.size())
			while _job_cursor < to:
				LevelTimeline.append_marker(_job_markers[_job_cursor] as LevelMarker3D, _job_out)
				_job_cursor += 1
			if _job_cursor >= _job_markers.size():
				_job_stage = 4
		4:
			# Саме free(), а не queue_free(). Вузол ніколи не потрапляв у дерево, і потрібен
			# він рівно доти; queue_free() же відкладає звільнення до кінця кадру, тобто
			# тримає цілий LevelLayout з усіма маркерами живим доти, доки SceneTree не дійде
			# до черги видалення. На завантаженні рівня кадри саме й не крутяться — і чанки
			# накопичуються.
			_job_layout.free()
			_job_layout = null
			_job_markers = []
			LevelTimeline.finish(_job_out, _job_offset)
			_job_stage = 5
		5:
			# landmarks/walls_near ідуть тим самим шляхом _add_decor(), що й decor, — Track
			# приймає лише два масиви (decor, buildings), тож зливаємо їх тут, а не плодимо
			# ширший API. Своя стадія, бо `a + b + c` на трьох масивах по сотні словників —
			# не копійка: заміряно, разом із add_authored_timeline це був найдорожчий крок
			# усього збирання.
			_job_decor = []
			_job_decor.append_array(_job_out.get("decor", []))
			_job_decor.append_array(_job_out.get("landmarks", []))
			_job_decor.append_array(_job_out.get("walls_near", []))
			_job_stage = 6
		6:
			_track.add_authored_timeline(_job_decor, _job_out.get("buildings", []), false)
			_job_stage = 7
		7:
			# Прогрів шарів — свій крок: близько мілісекунди, тобто майже цілий бюджет кадру.
			_track.prewarm_authored(_job_decor, _job_out.get("buildings", []))
			_job_decor = []
			_job_stage = 8
		8:
			if _spawner != null:
				_spawner.add_authored_obstacles(_job_out.get("obstacles", []))
				# Пікапи цеглинки. Доти LevelTimeline їх діставав, а не брав ніхто:
				# маркер-зірочка зникав без жодного слова. Саме про них і йшлося в «своя
				# кількість золота на чанк».
				_spawner.add_authored_pickups(_job_out.get("pickups", []))
			_job_out = {}
			_job_stage = 0
		_:
			return false
	return _job_stage != 0


## Крутити збирання, поки не вичерпається бюджет кадру. hurry — гравець уже надто близько до
## цеглинки, дотягуємо без бюджету (краще один смик, ніж дорога без перешкод).
func _drain_jobs(hurry: bool) -> void:
	if _job_stage == 0:
		return
	var until := Time.get_ticks_usec() + int(STREAM_BUDGET_MS * 1000.0)
	while _job_stage != 0:
		if not _step_apply():
			break
		if not hurry and Time.get_ticks_usec() >= until:
			return
