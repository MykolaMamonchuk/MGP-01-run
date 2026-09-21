## Опис чанка (`chunk.json` поруч зі сценою) — читання й ПЕРЕВІРКА.
##
## Навіщо. Цеглинка бібліотеки несе свої обмеження в описі: довжина, скільки доріжок на вході
## й виході, для яких світів придатна, які layout'и й на яку складність (формат — крок 1 у
## docs/tasks/reusable-chunks.md). Помилка в такому описі не падає й нічого не ламає одразу —
## вона стає МОВЧАЗНОЮ вадою: чанк, який на певній складності не має що показати; перешкода,
## якої в цьому світі не існує; довжина, за якої завантажувач не встигає. Тому опис перевіряємо
## до того, як він поїде в гру.
##
## ЧОМУ ЛОГІКА ТУТ, А НЕ В PYTHON. Перевірка сумісності потрібна ЗБИРАЧУ рівня, а він працює
## всередині гри — з python він її взяти не зможе. Щоб не мати двох джерел правди, правила
## живуть тут, у чистих статичних функціях над словниками, а `tools/validate_chunks.py` —
## тонка обгортка, яка лише запускає цей самий файл як CLI (`-s`) і віддає його вихід і код.
## Тест `tests/test_chunk_descriptors.gd` кличе ті самі функції напряму, на синтетичних описах
## у пам'яті — без жодного файлу на диску.
##
## Запуск як CLI (це й робить обгортка):
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s src/run3d/chunk_descriptor.gd
class_name ChunkDescriptor
extends SceneTree

## Поля опису. Усе, чого тут нема, — помилка (друкарська помилка в назві поля інакше читалась
## би як «поля нема» або взагалі мовчки ігнорувалась). Ключі з `_` — коментарі автора, як
## `_note` у data/worlds/*.json.
const REQUIRED := ["id", "length_m", "entry_lanes", "exit_lanes", "worlds", "layouts"]
const KNOWN := ["id", "length_m", "entry_lanes", "exit_lanes", "worlds", "layouts"]
## Поля layout'а. `actions` і `obstacles` не обов'язкові поодинці, але хоча б одне з них
## мусить бути: layout, який не каже ні дії, ні виду, не описує нічого.
##
## `points` і `gold` — БЮДЖЕТИ цієї розкладки: скільки неминучих дій вона має вимагати й
## скільки номіналу золота дати. Необов'язкові, бо 51 наявна розкладка розставлена рукою й
## бюджетів не має; збирач фраз (PhraseBook) без них бере типові. Але щойно розкладка
## згенерована — бюджети в ній мусять бути, інакше перескладання дасть іншу цеглинку й
## ніхто не дізнається, якою вона була задумана.
const LAYOUT_REQUIRED := ["file", "difficulty"]
const LAYOUT_KNOWN := ["file", "difficulty", "actions", "obstacles", "points", "gold"]
## Стеля бюджету очок на цеглинку. Заміряно 21.09.2026 збирачем із нескінченним бюджетом:
## 5–7 неминучих дій на 150 м на ВСІХ рівнях, і вона не росте зі швидкістю — швидший рівень
## має довші вдихи в метрах, і це з'їдає виграш від важчих фраз. Число прибите тут, щоб
## ніхто не прописав у цеглинку 12 очок, вважаючи, що їх хтось поставить.
const POINTS_MAX := 8
## Скільки номіналу золота розумно чекати з цеглинки. Модель EDD §2.2, перерахована на
## 150 м: 58 (пляж, без другого ярусу) — 87 (ліс, із ним). Межі з запасом.
const GOLD_MIN := 30
const GOLD_MAX := 140

## Дії, які вміє гра (поле `action` у перешкодах data/worlds/*.json). Саме ДІЮ пінить layout:
## `jump`, `duck` і `side` має кожен світ без винятку, а спільних ВИДІВ між світами майже нема
## (docs/tasks/reusable-chunks.md, крок 2½).
const ACTIONS_ALLOWED := ["jump", "duck", "side", "any", "boost", "rail", "wind"]

## Скільки доріжок буває на трасі. Те саме, що стереже Difficulty.LANES_MIN/MAX.
const LANES_ALLOWED := [3, 5, 7]

## Де шукати описи: і поруч зі сценами рівнів, і в бібліотеці levels/chunks/.
const LEVELS_DIR := "res://levels"
const WORLDS_DIR := "res://data/worlds"
const DESCRIPTOR_NAME := "chunk.json"
const LEVELS_JSON := "res://data/levels.json"

## Допуск на краях діапазонів складності — той самий, яким Difficulty.fits() вирішує стик.
const EPS := Difficulty.EDGE_EPS


# --- перевірка одного опису ---------------------------------------------------------------

## Усі помилки одного опису людською мовою. `desc` — розібраний chunk.json, `ctx` — те, з чим
## його звіряти, щоб функція лишалась чистою (тест підсовує синтетику, CLI — справжній диск):
##   ctx.worlds — {ім'я світу: {"obstacles": [види], "actions": [дії, які світ уміє]}}
##   ctx.files  — імена файлів, які реально лежать поруч із описом
##   ctx.dir    — ім'я теки (щоб id не розійшовся з нею); "" — не перевіряти
##   ctx.source — як називати файл у повідомленнях; "" — без префікса
static func errors(desc: Dictionary, ctx: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var where := String(ctx.get("source", ""))
	var worlds: Dictionary = ctx.get("worlds", {})
	var files: Array = ctx.get("files", [])
	var dir_name := String(ctx.get("dir", ""))

	for key in desc.keys():
		var name := String(key)
		if name.begins_with("_"):
			continue
		if not KNOWN.has(name):
			out.append("невідоме поле «%s» — друкарська помилка? відомі: %s"
				% [name, ", ".join(KNOWN)])
	for key in REQUIRED:
		if not desc.has(key):
			out.append("немає обов'язкового поля «%s»" % key)

	# id
	if desc.has("id"):
		if typeof(desc["id"]) != TYPE_STRING:
			out.append("«id» має бути рядком, а не %s" % type_string(typeof(desc["id"])))
		elif String(desc["id"]).is_empty():
			out.append("«id» порожній — саме ним рівень називає цеглинку")
		elif dir_name != "" and String(desc["id"]) != dir_name:
			out.append("«id» = «%s», а тека зветься «%s» — рівень шукатиме чанк за id і не знайде"
				% [desc["id"], dir_name])

	# length_m
	if desc.has("length_m"):
		if not _is_number(desc["length_m"]):
			out.append("«length_m» має бути числом, а не %s" % type_string(typeof(desc["length_m"])))
		else:
			var length := float(desc["length_m"])
			if length <= 0.0:
				out.append("«length_m» = %s — довжина має бути додатною" % _len(length))
			elif not _multiple_of(length, LevelChunkLoader.CHUNK_LENGTH_M) \
					and length < LevelChunkLoader.LOOKAHEAD_M:
				out.append(("«length_m» = %s: коротший за LOOKAHEAD_M = %s м і не кратний кроку "
					+ "%s м — за один update() наступний чанк не встигне завантажитись")
					% [_len(length), _len(LevelChunkLoader.LOOKAHEAD_M),
						_len(LevelChunkLoader.CHUNK_LENGTH_M)])

	# доріжки на вході й виході
	for gate in ["entry_lanes", "exit_lanes"]:
		if not desc.has(gate):
			continue
		if not _is_number(desc[gate]):
			out.append("«%s» має бути числом, а не %s" % [gate, type_string(typeof(desc[gate]))])
		elif not LANES_ALLOWED.has(int(desc[gate])):
			out.append("«%s» = %s — доріжок буває 3, 5 або 7" % [gate, _len(float(desc[gate]))])

	# світи
	if desc.has("worlds"):
		if typeof(desc["worlds"]) != TYPE_ARRAY:
			out.append("«worlds» має бути списком, а не %s" % type_string(typeof(desc["worlds"])))
		else:
			var list: Array = desc["worlds"]
			if list.is_empty():
				out.append("«worlds» порожній — чанк не придатний для жодного світу")
			for w in list:
				if typeof(w) != TYPE_STRING:
					out.append("«worlds»: %s — ім'я світу має бути рядком" % str(w))
				elif not worlds.has(String(w)):
					out.append("«worlds»: світу «%s» немає в data/worlds/ (є: %s)"
						% [w, ", ".join(_sorted_names(worlds.keys()))])

	# layout'и
	if desc.has("layouts"):
		if typeof(desc["layouts"]) != TYPE_ARRAY:
			out.append("«layouts» має бути списком, а не %s" % type_string(typeof(desc["layouts"])))
		else:
			var layouts: Array = desc["layouts"]
			if layouts.is_empty():
				out.append("«layouts» порожній — чанку нічого показати на жодній складності")
			var ranges: Array = []
			for i in range(layouts.size()):
				out.append_array(_layout_errors(layouts[i], i, desc, worlds, files, ranges))
			out.append_array(_coverage_errors(ranges))

	if where == "":
		return out
	var prefixed := PackedStringArray()
	for e in out:
		prefixed.append("%s: %s" % [where, e])
	return prefixed


## Помилки одного layout'а. Валідні діапазони дописуються в `ranges` — з них потім рахується
## покриття 0..1.
static func _layout_errors(raw: Variant, index: int, desc: Dictionary, worlds: Dictionary,
		files: Array, ranges: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var tag := "layouts[%d]" % index
	if typeof(raw) != TYPE_DICTIONARY:
		out.append("%s має бути словником, а не %s" % [tag, type_string(typeof(raw))])
		return out
	var layout: Dictionary = raw
	if layout.has("file") and typeof(layout["file"]) == TYPE_STRING:
		tag = "layout «%s»" % layout["file"]

	for key in layout.keys():
		var name := String(key)
		if name.begins_with("_"):
			continue
		if not LAYOUT_KNOWN.has(name):
			out.append("%s: невідоме поле «%s» — відомі: %s" % [tag, name, ", ".join(LAYOUT_KNOWN)])
	# Бюджети: не обов'язкові, але якщо є — мусять бути числами в розумних межах. Бюджет,
	# якого ніхто не може виконати, гірший за його відсутність: збирач мовчки недобере, і
	# цеглинка вийде легшою за задум, а причина лишиться в JSON нікому не видною.
	if layout.has("points"):
		var pts: Variant = layout["points"]
		if typeof(pts) != TYPE_FLOAT and typeof(pts) != TYPE_INT:
			out.append("%s: points має бути числом" % tag)
		elif int(pts) < 0 or int(pts) > POINTS_MAX:
			out.append("%s: points = %d, а межі 0..%d (стеля цеглинки заміряна збирачем)"
				% [tag, int(pts), POINTS_MAX])
	if layout.has("gold"):
		var gold: Variant = layout["gold"]
		if typeof(gold) != TYPE_FLOAT and typeof(gold) != TYPE_INT:
			out.append("%s: gold має бути числом" % tag)
		elif int(gold) < GOLD_MIN or int(gold) > GOLD_MAX:
			out.append("%s: gold = %d, а модель EDD на 150 м дає %d..%d"
				% [tag, int(gold), GOLD_MIN, GOLD_MAX])
	for key in LAYOUT_REQUIRED:
		if not layout.has(key):
			out.append("%s: немає поля «%s»" % [tag, key])

	# файл сцени
	if layout.has("file"):
		if typeof(layout["file"]) != TYPE_STRING:
			out.append("%s: «file» має бути рядком" % tag)
		elif String(layout["file"]).is_empty():
			out.append("%s: «file» порожній" % tag)
		elif not files.has(String(layout["file"])):
			out.append("%s: файлу немає поруч з описом" % tag)

	# діапазон складності
	if layout.has("difficulty"):
		var d: Variant = layout["difficulty"]
		if typeof(d) != TYPE_ARRAY or (d as Array).size() != 2:
			out.append("%s: «difficulty» — це пара [від, до]" % tag)
		elif not _is_number((d as Array)[0]) or not _is_number((d as Array)[1]):
			out.append("%s: «difficulty» — обидва краї мають бути числами" % tag)
		else:
			var lo := float((d as Array)[0])
			var hi := float((d as Array)[1])
			var bad := false
			if lo < 0.0 or lo > 1.0 or hi < 0.0 or hi > 1.0:
				out.append("%s: складність [%s, %s] виходить за межі 0..1" % [tag, _num(lo), _num(hi)])
				bad = true
			if lo > hi:
				out.append("%s: складність [%s, %s] перевернута — від більшого до меншого"
					% [tag, _num(lo), _num(hi)])
				bad = true
			if not bad:
				ranges.append([lo, hi])

	# дії — головний спосіб описати layout: маркер каже «тут перестрибнути», а модель добирає світ
	if layout.has("actions"):
		if typeof(layout["actions"]) != TYPE_ARRAY:
			out.append("%s: «actions» має бути списком" % tag)
		else:
			for action in (layout["actions"] as Array):
				if typeof(action) != TYPE_STRING:
					out.append("%s: дія %s — має бути рядком" % [tag, str(action)])
					continue
				if not ACTIONS_ALLOWED.has(String(action)):
					out.append("%s: дії «%s» гра не знає — є: %s"
						% [tag, action, ", ".join(ACTIONS_ALLOWED)])
					continue
				for w in _declared_worlds(desc, worlds):
					if not _world_list(worlds, w, "actions").has(String(action)):
						out.append("%s: у світі «%s» немає жодної перешкоди з дією «%s»"
							% [tag, w, action])

	# види — виняток для чанка на ОДИН світ, і тому перевіряються строго: спільних видів між
	# світами майже нема (Лужок ∩ Ліс — лише xbox), тож багатосвітовий чанк має жити на діях.
	if layout.has("obstacles"):
		if typeof(layout["obstacles"]) != TYPE_ARRAY:
			out.append("%s: «obstacles» має бути списком" % tag)
		else:
			for kind in (layout["obstacles"] as Array):
				if typeof(kind) != TYPE_STRING:
					out.append("%s: перешкода %s — має бути рядком" % [tag, str(kind)])
					continue
				var declared := _declared_worlds(desc, worlds)
				for w in declared:
					if _world_list(worlds, w, "obstacles").has(String(kind)):
						continue
					# Підказку про дії даємо лише багатосвітовому чанку: для чанка на один світ
					# пін виду законний, і радити йому «вживай actions» було б неправдою.
					var hint := ""
					if declared.size() > 1:
						hint = (" — «obstacles» пінить конкретний вид і годиться лише для чанка на "
							+ "один світ; для кількох світів вживай «actions», дії є в кожному")
					out.append("%s: перешкоди «%s» немає у світі «%s»%s" % [tag, kind, w, hint])

	# layout, який не каже ні дії, ні виду, не описує нічого
	if not _has_items(layout, "actions") and not _has_items(layout, "obstacles"):
		out.append(("%s: немає ні «actions», ні «obstacles» — layout нічого не описує "
			+ "(дія для будь-якого світу, вид — лише для чанка на один світ)") % tag)
	return out


## Чи є в layout'і непорожній список під таким ключем.
static func _has_items(layout: Dictionary, key: String) -> bool:
	if not layout.has(key) or typeof(layout[key]) != TYPE_ARRAY:
		return false
	return not (layout[key] as Array).is_empty()


## Список «види» або «дії» одного світу з каталогу.
static func _world_list(worlds: Dictionary, world: String, key: String) -> Array:
	var entry: Variant = worlds.get(world, {})
	if typeof(entry) != TYPE_DICTIONARY:
		return []
	var list: Variant = (entry as Dictionary).get(key, [])
	if typeof(list) != TYPE_ARRAY:
		return []
	return list


## Діапазони складності мусять покривати ВЕСЬ 0..1 без дірок: інакше на якійсь складності чанк
## не матиме що показати, і збирач мовчки поставить порожню ділянку.
static func _coverage_errors(ranges: Array) -> PackedStringArray:
	var out := PackedStringArray()
	if ranges.is_empty():
		return out
	var sorted := ranges.duplicate()
	sorted.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var covered := 0.0
	for r in sorted:
		var lo := float(r[0])
		var hi := float(r[1])
		if lo > covered + EPS:
			out.append("складність %s–%s не покрита жодним layout'ом" % [_num(covered), _num(lo)])
		covered = maxf(covered, hi)
	if covered < 1.0 - EPS:
		out.append("складність %s–1.00 не покрита жодним layout'ом" % _num(covered))
	return out


static func _declared_worlds(desc: Dictionary, worlds: Dictionary) -> Array:
	var out: Array = []
	if typeof(desc.get("worlds", null)) != TYPE_ARRAY:
		return out
	for w in (desc["worlds"] as Array):
		if typeof(w) == TYPE_STRING and worlds.has(String(w)):
			out.append(String(w))
	return out


# --- сумісність послідовності -------------------------------------------------------------

## Чи стикуються чанки в послідовності: вихід кожного мусить збігатися зі входом наступного.
## Єдина вісь — доріжки: бік каналу це властивість СВІТУ, а світ усередині рівня не міняється
## (docs/tasks/reusable-chunks.md, «вісь сумісності лише ОДНА»).
##
## Окрема функція навмисно: її кличе і валідатор (CLI), і згодом збирач рівня — щоб несумісна
## пара була помилкою збірки, а не мовчазною вадою.
## `ids` — послідовність імен, `by_id` — {id: опис}.
static func sequence_errors(ids: Array, by_id: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for id in ids:
		if not by_id.has(String(id)):
			out.append("у бібліотеці немає чанка «%s»" % str(id))
	for i in range(ids.size() - 1):
		var a := String(ids[i])
		var b := String(ids[i + 1])
		if not by_id.has(a) or not by_id.has(b):
			continue
		var out_lanes := exit_lanes(by_id[a])
		var in_lanes := entry_lanes(by_id[b])
		if out_lanes != in_lanes:
			out.append("«%s» віддає %d доріжок, а «%s» чекає %d — стик не сходиться"
				% [a, out_lanes, b, in_lanes])
	return out


static func entry_lanes(desc: Dictionary) -> int:
	return int(desc.get("entry_lanes", 0))


static func exit_lanes(desc: Dictionary) -> int:
	return int(desc.get("exit_lanes", 0))


# --- вибір layout'а -------------------------------------------------------------------------

## Який із рукотворних layout'ів чанка показати. Чанк НЕ знає, на якому він рівні: рівень дає
## лише складність (число 0..1 з Difficulty.of) і список дозволених видів перешкод
## (`obstacle_types` рівня), а чанк за цим вибирає сам (docs/tasks/reusable-chunks.md, крок 3).
## Функція чиста: ні вузлів, ні диска — тому перевіряється числами, без сцени.
##
## `allowed_obstacles` ПОРОЖНІЙ означає «рівень не обмежує», а не «нічого не можна»: у
## data/levels.json порожній `obstacle_types` — це «всі типи біому» (рівні 4, 8, 11, 14, 17), і
## так само його читає Difficulty.obstacle_variety(), яка дає за порожній список МАКСИМУМ.
##
## Не підійшов жоден — повертається ПОРОЖНІЙ словник, і це навмисно. Покриття всього 0..1
## вимагає валідатор (_coverage_errors), тож порожнеча може означати лише одне: рівень просить
## види, яких цей чанк не пропонує. Хай той, хто кличе, побачить порожнечу й поскаржиться —
## підсунутий «хоч якийсь» layout поставив би дитині перешкоду, заборонену рівнем, і вада була б
## мовчазною.
static func pick_layout(desc: Dictionary, difficulty: float, allowed_obstacles: Array) -> Dictionary:
	var raw_layouts: Variant = desc.get("layouts", [])
	if typeof(raw_layouts) != TYPE_ARRAY:
		return {}
	var best: Dictionary = {}
	## Ширина діапазону в найкращого поки що; INF — ще нічого не знайшли.
	var best_width := INF
	for raw in (raw_layouts as Array):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var layout: Dictionary = raw
		var span := _layout_span(layout)
		if span.is_empty():
			continue
		# Краї включні — ТА САМА семантика, що в Difficulty.fits() і в перевірці покриття.
		# Третього трактування країв тут не заводимо: розійшовшись, вибір і валідатор почали б
		# сперечатися про той самий layout (перевернутий діапазон Difficulty.fits теж відкидає).
		if not Difficulty.fits(float(span[0]), float(span[1]), difficulty):
			continue
		if not _kinds_allowed(layout, allowed_obstacles):
			continue
		# ВУЖЧИЙ виграє. Діапазон 0..1 — це «запасний»: він написаний, щоб чанк мав що показати
		# будь-де, і сам по собі нічого не каже про цю складність. Вузький [0.4, 0.5] автор
		# зробив НАВМИСНО під неї — отже, він і точніший. За однакової ширини виграє ПЕРШИЙ у
		# списку: порядок у файлі — воля автора, і на стику діапазонів вона вже вирішує
		# (docs/tasks/reusable-chunks.md, крок 3). Тому порівняння строге й із тим самим
		# допуском EPS: 0.5 і 0.50000001 — це одна ширина, а не дві.
		var width := float(span[1]) - float(span[0])
		if width < best_width - EPS:
			best = layout
			best_width = width
	return best


## [від, до] layout'а, якщо діапазон узагалі читається; інакше порожній масив. Зіпсований опис
## тут мовчки пропускається, а не «виправляється»: кричати про нього — робота errors().
static func _layout_span(layout: Dictionary) -> Array:
	var d: Variant = layout.get("difficulty", null)
	if typeof(d) != TYPE_ARRAY or (d as Array).size() != 2:
		return []
	var pair: Array = d
	if not _is_number(pair[0]) or not _is_number(pair[1]):
		return []
	return [float(pair[0]), float(pair[1])]


## Чи дозволяє рівень усе, що цей layout пінить ВИДОМ. Пін виду — обіцянка поставити саме цю
## модель, і рівень мусить уміти її виконати: бракує хоч одного виду — layout не годиться.
## Layout на ДІЯХ під це не підпадає взагалі: маркер каже «тут перестрибнути», а конкретну
## модель добере світ, уже з оглядом на obstacle_types рівня (крок 2½). Тому дивимось лише на
## `obstacles`; відсутній або не-список — нема чого й забороняти.
static func _kinds_allowed(layout: Dictionary, allowed: Array) -> bool:
	if allowed.is_empty():
		return true
	if typeof(layout.get("obstacles", null)) != TYPE_ARRAY:
		return true
	for kind in (layout["obstacles"] as Array):
		var found := false
		for a in allowed:
			if String(a) == String(kind):
				found = true
				break
		if not found:
			return false
	return true


# --- читання з диска ----------------------------------------------------------------------

## {ім'я світу: {"obstacles": [види], "actions": [дії]}} з data/worlds/*.json — єдине джерело
## правди про те, що в якому світі взагалі існує. Дія береться з поля `action` самої перешкоди.
static func world_catalog(dir_path := WORLDS_DIR) -> Dictionary:
	var out := {}
	for name in _files_in(dir_path):
		if not name.ends_with(".json"):
			continue
		var world: Variant = _read_json(dir_path.path_join(name))
		if typeof(world) != TYPE_DICTIONARY:
			continue
		var id := String((world as Dictionary).get("id", name.get_basename()))
		var obstacles: Variant = (world as Dictionary).get("obstacles", {})
		var kinds: Array = []
		var actions: Array = []
		if typeof(obstacles) == TYPE_DICTIONARY:
			for kind in (obstacles as Dictionary).keys():
				kinds.append(String(kind))
				var entry: Variant = (obstacles as Dictionary)[kind]
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				var action := String((entry as Dictionary).get("action", ""))
				if action != "" and not actions.has(action):
					actions.append(action)
		elif typeof(obstacles) == TYPE_ARRAY:
			kinds = obstacles
		out[id] = {"obstacles": kinds, "actions": actions}
	return out


## Усі chunk.json під levels/ — і поруч зі сценами, і в бібліотеці levels/chunks/.
static func find_descriptors(root := LEVELS_DIR) -> PackedStringArray:
	var out := PackedStringArray()
	_walk(root, out)
	out.sort()
	return out


static func _walk(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for name in _files_in(dir_path):
		if name == DESCRIPTOR_NAME:
			out.append(dir_path.path_join(name))
	for name in dir.get_directories():
		_walk(dir_path.path_join(name), out)


## Розібрані описи бібліотеки: {шлях: опис}. Нечитабельний JSON потрапляє в `bad`.
static func library(root := LEVELS_DIR) -> Dictionary:
	var by_path := {}
	var bad := PackedStringArray()
	for path in find_descriptors(root):
		var parsed: Variant = _read_json(path)
		if typeof(parsed) != TYPE_DICTIONARY:
			bad.append("%s: не читається як JSON-словник" % path)
			continue
		by_path[path] = parsed
	return {"by_path": by_path, "bad": bad}


## Усе, що не так із бібліотекою описів, людською мовою. Порожній масив — усе гаразд
## (у тому числі коли описів ще нема: перевіряти нічого — не помилка).
## `levels_path` — де взяти послідовності чанків рівнів (`"chunks"` у записі рівня); "" — не
## перевіряти послідовності взагалі (так робить перевірка на чужій теці).
static func report(root := LEVELS_DIR, worlds_dir := WORLDS_DIR,
		levels_path := LEVELS_JSON) -> PackedStringArray:
	var out := PackedStringArray()
	var lib := library(root)
	out.append_array(lib["bad"])
	var worlds := world_catalog(worlds_dir)
	var by_path: Dictionary = lib["by_path"]
	var seen := {}   ## id → перший шлях, де він трапився
	for path in _sorted_names(by_path.keys()):
		var dir_path := String(path).get_base_dir()
		var desc: Dictionary = by_path[path]
		out.append_array(errors(desc, {
			"worlds": worlds,
			"files": _files_in(dir_path),
			"dir": dir_path.get_file(),
			"source": path,
		}))
		var id := String(desc.get("id", ""))
		if id == "":
			continue
		if seen.has(id):
			out.append("%s: id «%s» уже зайнятий (%s) — послідовність рівня стане двозначною"
				% [path, id, seen[id]])
		else:
			seen[id] = path

	if levels_path != "":
		var by_id := {}
		for path in by_path.keys():
			var desc: Dictionary = by_path[path]
			var id := String(desc.get("id", ""))
			if id != "" and not by_id.has(id):
				by_id[id] = desc
		out.append_array(_levels_sequence_errors(levels_path, by_id))
	return out


## Послідовності чанків, виписані в рівнях (`"chunks"` у data/levels.json), перевіряються тією
## самою функцією, якою це робитиме збирач: несумісна пара має бути помилкою, а не мовчазною
## вадою. Поки жоден рівень такого списку не має — перевіряти нічого.
static func _levels_sequence_errors(levels_path: String, by_id: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var parsed: Variant = _read_json(levels_path)
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	var levels: Variant = (parsed as Dictionary).get("levels", [])
	if typeof(levels) != TYPE_ARRAY:
		return out
	for raw in (levels as Array):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var level: Dictionary = raw
		var ids: Variant = level.get("chunks", [])
		if typeof(ids) != TYPE_ARRAY or (ids as Array).is_empty():
			continue
		for e in sequence_errors(ids, by_id):
			out.append("рівень %s: %s" % [str(level.get("id", "?")), e])
	return out


static func _files_in(dir_path: String) -> Array:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return []
	var out: Array = []
	for name in dir.get_files():
		# .import/.remap — службові сліди імпорту, автор їх не писав.
		out.append(String(name).trim_suffix(".remap"))
	return out


static func _read_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	return JSON.parse_string(text)


# --- дрібниці -----------------------------------------------------------------------------

static func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func _multiple_of(value: float, step: float) -> bool:
	if step <= 0.0:
		return false
	return absf(fmod(value, step)) < 0.001 or absf(fmod(value, step) - step) < 0.001


## Складність друкуємо завжди з двома знаками (0.40, 1.00) — так видно, що це саме шкала 0..1.
static func _num(v: float) -> String:
	return "%.2f" % v


## Метри й доріжки — без зайвих нулів: 150, а не 150.00.
static func _len(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return "%d" % int(roundf(v))
	return String.num(v, 2)


static func _sorted_names(names: Array) -> Array:
	var out := names.duplicate()
	out.sort()
	return out


# --- CLI ----------------------------------------------------------------------------------

## Запускається лише тоді, коли цей скрипт узятий за головний цикл (`-s`). Статичні виклики
## з гри й тестів сюди не заходять.
func _initialize() -> void:
	print("--- перевірка описів чанків ---")
	# CHUNKS_ROOT — інша тека замість res://levels. Потрібна рівно для того, щоб перевірити сам
	# валідатор на завідомо зіпсованому описі, не кладучи такий опис у рівні гри.
	var root := LEVELS_DIR
	if OS.get_environment("CHUNKS_ROOT") != "":
		root = OS.get_environment("CHUNKS_ROOT")
	var found := find_descriptors(root)
	# На чужій теці послідовності рівнів не перевіряємо: там своя бібліотека й чужі id.
	var levels_path := LEVELS_JSON if root == LEVELS_DIR else ""
	var problems := report(root, WORLDS_DIR, levels_path)
	if found.is_empty():
		print("описів chunk.json ще немає — перевіряти нічого")
	else:
		print("описів знайдено: %d" % found.size())
	for line in problems:
		print(line)
	if problems.is_empty():
		print("помилок немає")
		quit(0)
		return
	print("помилок: %d" % problems.size())
	quit(1)
