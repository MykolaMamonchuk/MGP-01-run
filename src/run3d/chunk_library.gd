## Бібліотека чанків і збирач рівня з них.
##
## Навіщо. Досі рівень — це тека levels/level_XX/ із чанками по порядку, і кожен чанк належав
## рівно одному рівню. Бібліотека розриває цей зв'язок: цеглинка лежить окремо, а рівень —
## це СПИСОК її імен. Та сама цеглинка стоїть на 150-му метрі рівня 1 і на 900-му рівня 17.
##
## Збирач не вигадує нічого сам. Він лише:
##   1. знаходить кожен id у бібліотеці;
##   2. перевіряє, що стик сходиться (exit_lanes попереднього == entry_lanes наступного);
##   3. перевіряє, що чанк придатний до світу цього рівня;
##   4. накопичує зсув — саме тому чанк і не мусить знати, де він стоїть.
##
## Несумісна пара — ПОМИЛКА ЗБІРКИ, а не мовчазна вада: рівень, зібраний зі стиком «3 доріжки
## віддає, 5 чекає», виглядав би як обрив дороги посеред бігу, і шукали б його довго.
class_name ChunkLibrary
extends RefCounted

const ROOT := "res://levels/chunks"


## Усі цеглинки бібліотеки: id → {"dir": тека, "scene": шлях до .tscn, "desc": опис}.
## Порожній словник — бібліотеки ще немає, і це не помилка: рівні-теки працюють як раніше.
static func scan(root: String = ROOT) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for name in dir.get_directories():
		var desc_path := "%s/%s/chunk.json" % [root, name]
		var f := FileAccess.open(desc_path, FileAccess.READ)
		if f == null:
			continue
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var desc: Dictionary = parsed
		out[String(desc.get("id", name))] = {
			"dir": "%s/%s" % [root, name],
			"scene": "%s/%s/chunk.tscn" % [root, name],
			"desc": desc,
		}
	return out


## Зібрати рівень зі списку цеглинок.
##
## Повертає {"pieces": [...], "errors": [...]}. pieces — те, що потрібне завантажувачу:
## шлях сцени, зсув від старту рівня й довжина. errors — людською мовою, ЩО саме не зійшлось;
## якщо він не порожній, pieces брати не можна.
static func assemble(level: Dictionary, library: Dictionary) -> Dictionary:
	var ids: Array = level.get("chunks", [])
	var world := String(level.get("world", ""))
	var errors: Array = []
	var pieces: Array = []
	var offset := 0.0
	var prev_exit := int(level.get("lanes", 3))
	for i in range(ids.size()):
		var id := String(ids[i])
		if not library.has(id):
			errors.append("чанк «%s» (%d-й у списку) не знайдено в бібліотеці" % [id, i + 1])
			continue
		var entry: Dictionary = library[id]
		var desc: Dictionary = entry["desc"]
		var worlds: Array = desc.get("worlds", [])
		if not worlds.is_empty() and not worlds.has(world):
			errors.append("чанк «%s» не для світу «%s» — він для %s" % [id, world, worlds])
		var entry_lanes := int(desc.get("entry_lanes", prev_exit))
		if entry_lanes != prev_exit:
			# Саме та вада, заради якої збирач і пишеться: дорога обірвалась би посеред бігу.
			errors.append("стик не сходиться: перед «%s» дорога має %d доріжок, а він чекає %d"
				% [id, prev_exit, entry_lanes])
		var length := float(desc.get("length_m", 0.0))
		if length <= 0.0:
			errors.append("чанк «%s»: length_m мусить бути додатною" % id)
			length = 0.0
		pieces.append({
			"id": id,
			"path": String(entry["scene"]),
			"offset_m": offset,
			"length_m": length,
		})
		offset += length
		prev_exit = int(desc.get("exit_lanes", entry_lanes))
	return {"pieces": pieces, "errors": errors, "length_m": offset, "exit_lanes": prev_exit}
