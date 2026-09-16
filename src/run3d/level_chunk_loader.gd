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
	_chunked = DirAccess.dir_exists_absolute(_folder_path())
	if not _chunked and not ResourceLoader.exists(_flat_path()):
		track.clear_authored_timeline()
		_clear_obstacles()
		_done = true
		return
	track.clear_authored_timeline()
	_clear_obstacles()
	if _chunked:
		_load_next_chunk()
	else:
		_load_flat_level()


## Викликати щокадру одразу після track.advance()/spawner.advance() (той самий distance_m, що
## й вони отримали) — вантажить наступний чанк, щойно гравець підійшов на LOOKAHEAD_M до межі
## останнього завантаженого. Для нечанкованого рівня (весь файл уже завантажено в start()) —
## нічого не робить.
func update(distance_m: float) -> void:
	if _done or not _chunked:
		return
	if distance_m + LOOKAHEAD_M >= _loaded_through_z:
		_load_next_chunk()


func _folder_path() -> String:
	return "res://levels/level_%02d" % _num


func _flat_path() -> String:
	return "res://levels/level_%02d.tscn" % _num


func _chunk_path(index: int) -> String:
	return "%s/chunk_%02d.tscn" % [_folder_path(), index]


## Єдине місце, де чанк реально читається з диска — свідомо ізольоване від решти логіки: коли
## чанки нестимуть важкі ресурси (реальні .glb-будівлі "зовнішнього світу"), заміна на
## ResourceLoader.load_threaded_request()/load_threaded_get() торкнеться лише цієї функції.
func _load_chunk_resource(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


func _load_next_chunk() -> void:
	var packed := _load_chunk_resource(_chunk_path(_next_chunk_index))
	if packed == null:
		_done = true          # чанків більше нема — рівень повністю завантажено
		return
	_apply(packed)
	_next_chunk_index += 1
	_loaded_through_z = float(_next_chunk_index) * CHUNK_LENGTH_M


func _load_flat_level() -> void:
	var packed := _load_chunk_resource(_flat_path())
	if packed == null:
		_done = true
		return
	_apply(packed)
	_done = true               # єдиний файл — увесь рівень уже в Track/Spawner3D


## Інстанціювати чанк ЛИШЕ заради LevelTimeline.extract() і одразу звільнити — так само, як
## робив старий _load_authored_level(): нічого з авторської сцени не потрапляє в живе дерево.
func _apply(packed: PackedScene) -> void:
	var layout := packed.instantiate()
	var extracted := LevelTimeline.extract(layout)
	layout.queue_free()
	# landmarks/walls_near ідуть тим самим шляхом _add_decor(), що й decor, — Track приймає лише
	# два масиви (decor, buildings), тож зливаємо їх тут, а не плодимо ширший API.
	var decor: Array = extracted.get("decor", []) + extracted.get("landmarks", []) + extracted.get("walls_near", [])
	_track.add_authored_timeline(decor, extracted.get("buildings", []))
	if _spawner != null:
		_spawner.add_authored_obstacles(extracted.get("obstacles", []))
