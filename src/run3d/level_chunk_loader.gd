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
var _chunked := false          ## true — є папка levels/level_XX/, чанки вантажимо по одному
var _next_chunk_index := 0     ## індекс наступного НЕзавантаженого чанку
var _loaded_through_z := 0.0   ## до якої відстані рівень уже завантажено (межа останнього чанку)
## Найбільший номер чанку, який реально лежить у теці. Потрібен, бо чанк може бути ПРОПУЩЕНИЙ:
## розрізання не пише файл для відрізка, у якому не лишилось жодного маркера, та й автор карти
## може стерти середній чанк руками. Без цієї межі перший же відсутній номер читався б як
## «рівень скінчився», і решта рівня тихо не завантажувалась би взагалі.
var _last_chunk_index := -1
## Чанк, який ЗАРАЗ вантажиться у фоні (-1 — жодного) і його шлях.
## Навіщо фон. Заміряно 18.09.2026: чанк із 904 маркерами читається 46,8 мс, інстанціюється
## 5,9 і розбирається 17,2 — разом ~70 мс на Mac, отже 200–350 мс на телефоні. Синхронно це
## означало б підвисання ПОСЕРЕД БІГУ на кожній межі чанка, бо наступний тягнеться за 80 м до
## неї. Запас часу величезний: 80 м на 12 м/с — понад шість секунд, тож фонове читання
## встигає з великим лишком.
var _pending_index := -1
var _pending_path := ""
var _done := false             ## усі чанки рівня вже завантажені — update() більше не працює


## Почати стрімінг рівня num: визначає чанкований рівень це чи старий суцільний файл, вантажить
## перший чанк (або весь рівень) синхронно — так само, як і раніше, гравець стартує з готовими
## першими записами. track/spawner — куди зливати LevelTimeline.extract().
## Спавнер може бути null — так його передає знімальний інструмент src/debug/track_shot.gd,
## якому потрібен лише декор рівня, без перешкод. Раніше це валило виклик і знімок робився
## без половини даних, мовчки: помилка друкувалась у консоль, а картинка виглядала цілою.
func _clear_obstacles() -> void:
	if _spawner != null:
		_spawner.clear_authored_obstacles()


func start(num: int, track: Track, spawner: Spawner3D) -> void:
	_num = num
	_track = track
	_spawner = spawner
	_next_chunk_index = 0
	_loaded_through_z = 0.0
	_done = false
	_pending_index = -1
	_pending_path = ""
	_last_chunk_index = _scan_last_chunk_index()
	_chunked = _last_chunk_index >= 0
	if not _chunked and not ResourceLoader.exists(_flat_path()):
		track.clear_authored_timeline()
		_clear_obstacles()
		_done = true
		return
	track.clear_authored_timeline()
	_clear_obstacles()
	if _chunked:
		# Перший чанк — синхронно: гравець ще на екрані завантаження, підвисати нема де, а
		# стартувати без записів не можна.
		_load_first_chunk()
	else:
		_load_flat_level()


## Викликати щокадру одразу після track.advance()/spawner.advance() (той самий distance_m, що
## й вони отримали) — вантажить наступний чанк, щойно гравець підійшов на LOOKAHEAD_M до межі
## останнього завантаженого. Для нечанкованого рівня (весь файл уже завантажено в start()) —
## нічого не робить.
func update(distance_m: float) -> void:
	if _done or not _chunked:
		return
	# Чанк уже читається у фоні — просто перевіряємо, чи готовий. Нової заявки не подаємо,
	# доки не заберемо попередню: інакше два чанки поїхали б у Track одночасно й у різному
	# порядку.
	if _pending_index >= 0:
		_poll_pending()
		return
	if distance_m + LOOKAHEAD_M >= _loaded_through_z:
		_request_next_chunk()


## Дочекатись, доки фоновий чанк дочитається. Потрібно ТЕСТАМ і знімальним інструментам, яким
## нема куди подіти час між кадрами. У грі цього не кличе ніхто: там update() іде щокадру й
## забирає чанк тоді, коли потік закінчив, — у цьому вся суть.
func finish_pending() -> void:
	while _pending_index >= 0:
		_poll_pending()
		if _pending_index >= 0:
			OS.delay_msec(1)


## Забрати чанк, якщо він уже прочитався. Нічого не робить, доки потік не закінчив.
func _poll_pending() -> void:
	var status := ResourceLoader.load_threaded_get_status(_pending_path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var packed := ResourceLoader.load_threaded_get(_pending_path) as PackedScene
		if packed != null:
			_apply(packed, float(_pending_index) * CHUNK_LENGTH_M)
	else:
		push_warning("чанк не прочитався: %s" % _pending_path)
	_pending_index = -1
	_pending_path = ""


## Подати заявку на наступний чанк, ПЕРЕСТРИБУЮЧИ відсутні номери: порожній відрізок рівня —
## це просто відсутній файл, а не кінець рівня.
func _request_next_chunk() -> void:
	while _next_chunk_index <= _last_chunk_index:
		var path := _chunk_path(_next_chunk_index)
		var index := _next_chunk_index
		_next_chunk_index += 1
		_loaded_through_z = float(_next_chunk_index) * CHUNK_LENGTH_M
		if not ResourceLoader.exists(path):
			continue
		ResourceLoader.load_threaded_request(path)
		_pending_index = index
		_pending_path = path
		return
	_done = true              # дійшли до останнього чанку теки — рівень завантажено повністю


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


func _folder_path() -> String:
	return "res://levels/level_%02d" % _num


func _flat_path() -> String:
	return "res://levels/level_%02d.tscn" % _num


func _chunk_path(index: int) -> String:
	return "%s/chunk_%02d.tscn" % [_folder_path(), index]


## Пройти теку рівня один раз і запам'ятати найбільший номер чанку. Дивимось саме на список
## файлів, а не на послідовність номерів: у теці можуть бути діри.
func _scan_last_chunk_index() -> int:
	var dir := DirAccess.open(_folder_path())
	if dir == null:
		return -1
	var last := -1
	for name in dir.get_files():
		# .tscn у теці рівня імпортується в .remap на експорті — беремо ім'я до першої крапки
		var base := name.get_basename()
		if base.get_extension() == "tscn":
			base = base.get_basename()
		if not base.begins_with("chunk_"):
			continue
		last = maxi(last, int(base.substr(6)))
	return last


## Єдине місце, де чанк реально читається з диска — свідомо ізольоване від решти логіки: коли
## чанки нестимуть важкі ресурси (реальні .glb-будівлі "зовнішнього світу"), заміна на
## ResourceLoader.load_threaded_request()/load_threaded_get() торкнеться лише цієї функції.
func _load_chunk_resource(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


## Перший чанк рівня, синхронно.
func _load_first_chunk() -> void:
	while _next_chunk_index <= _last_chunk_index:
		var index := _next_chunk_index
		var packed := _load_chunk_resource(_chunk_path(index))
		_next_chunk_index += 1
		_loaded_through_z = float(_next_chunk_index) * CHUNK_LENGTH_M
		if packed != null:
			_apply(packed, float(index) * CHUNK_LENGTH_M)
			return
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
func _apply(packed: PackedScene, offset_m: float) -> void:
	var layout := packed.instantiate()
	var extracted := LevelTimeline.extract(layout, offset_m)
	# Саме free(), а не queue_free(). Вузол ніколи не потрапляв у дерево, і потрібен він рівно
	# на один рядок вище; queue_free() же відкладає звільнення до кінця кадру, тобто тримає
	# цілий LevelLayout з усіма маркерами живим доти, доки SceneTree не дійде до черги
	# видалення. На завантаженні рівня кадри саме й не крутяться — і чанки накопичуються.
	layout.free()
	# landmarks/walls_near ідуть тим самим шляхом _add_decor(), що й decor, — Track приймає лише
	# два масиви (decor, buildings), тож зливаємо їх тут, а не плодимо ширший API.
	var decor: Array = extracted.get("decor", []) + extracted.get("landmarks", []) + extracted.get("walls_near", [])
	_track.add_authored_timeline(decor, extracted.get("buildings", []))
	if _spawner != null:
		_spawner.add_authored_obstacles(extracted.get("obstacles", []))
