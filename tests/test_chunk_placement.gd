## Чи не стоїть маркер цеглинки на дорозі або у воді.
##
## Навіщо. `x` у маркері АБСОЛЮТНИЙ — скільки метрів від осі траси. А край дороги залежить від
## кількості смуг, і канал відраховується від КРАЮ, тобто теж їде разом із ним: у Лужку на трьох
## смугах вода лежить на 3.1…6.1 м, а на п'яти — вже на 4.1…7.1. Отже ті самі 2.1 м, правильні
## для трисмугової цеглинки, на п'ятисмуговій опиняються на біговій смузі, а 3.4 — у воді.
##
## Оком цього не видно взагалі: у грі до широкої ділянки треба добігти, а в редакторі автор
## бачить путівник однієї ширини. Тому — числами, і по всіх ширинах, які цеглинка сама заявила.
##
## Цеглинка-перехід (3 → 5) перевіряється на ОБИДВІ ширини: усередині неї дорога й розширюється,
## тож маркер мусить бути безпечним і до, і після. Саме це тут і зловилось першого ж разу —
## декор meadow_widen стояв на 3.2 і 3.4 м, тобто у воді, доки дорога ще вузька.
extends GutTest

const LANE_W := 1.0
const ROAD_PAD := 0.2
## Маркери ближче за це до осі — орієнтири-арки над дорогою, вони там за задумом
## (те саме правило, що в tests/test_level_decor_clearance.gd).
const CENTRE_SKIP := 0.3
## Запас, щоб «рівно на краю» не читалось як помилка через похибку float.
const EPS := 0.01

## Ролі, які стоять ОБАБІЧ дороги. Перешкоди й пікапи сюди не входять — вони живуть у смугах,
## і їхній x завжди нуль (місце задає `lane`).
const SIDE_ROLES := ["decor", "landmark", "wall_near", "building"]
## Ці мусять стояти ще й ЗА каналом — так само, як процедурна забудова (Track.FAR_MIN і
## c_offset + c_width у _decorate()).
const BEYOND_CANAL := ["wall_near", "building"]


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _half_road(lanes: int) -> float:
	return (float(lanes) * LANE_W + ROAD_PAD) * 0.5


## Усі ширини, крізь які цеглинка проходить: від входу до виходу включно.
func _widths(desc: Dictionary) -> Array:
	var lo := int(desc.get("entry_lanes", 3))
	var hi := int(desc.get("exit_lanes", lo))
	var out := []
	for n in [3, 5, 7]:
		if n >= mini(lo, hi) and n <= maxi(lo, hi):
			out.append(n)
	return out


## Бічні маркери сцени: [{role, kind, x}].
func _side_markers(scene_path: String) -> Array:
	var out := []
	var f := FileAccess.open(scene_path, FileAccess.READ)
	if f == null:
		return out
	for block in f.get_as_text().split("[node "):
		if not block.contains("script = ExtResource"):
			continue
		var tr := block.find("Transform3D(")
		if tr < 0:
			continue
		var role := "decor"
		var role_at := block.find("role = \"")
		if role_at >= 0:
			role = block.substr(role_at + 8).split("\"")[0]
		if not SIDE_ROLES.has(role):
			continue
		var args := block.substr(tr + 12).split(")")[0].split(",")
		if args.size() < 12:
			continue
		var kind := "?"
		var kind_at := block.find("kind = \"")
		if kind_at >= 0:
			kind = block.substr(kind_at + 8).split("\"")[0]
		out.append({"role": role, "kind": kind, "x": float(args[9])})
	return out


func _scenes_of(entry: Dictionary) -> Array:
	var out := [String(entry["scene"])]
	for raw in (entry["desc"] as Dictionary).get("layouts", []):
		if typeof(raw) == TYPE_DICTIONARY:
			out.append("%s/%s" % [String(entry["dir"]), String((raw as Dictionary).get("file", ""))])
	return out


func test_no_side_marker_stands_on_the_road_or_in_the_water() -> void:
	var library := ChunkLibrary.scan()
	assert_gt(library.size(), 0, "бібліотека цеглинок не порожня")
	var checked := 0
	for id in library.keys():
		var entry: Dictionary = library[id]
		var desc: Dictionary = entry["desc"]
		for w in (desc.get("worlds", []) as Array):
			var world := _json("res://data/worlds/%s.json" % String(w))
			if world.is_empty():
				continue
			var canal: Dictionary = world.get("canal", {}) if typeof(world.get("canal")) == TYPE_DICTIONARY else {}
			var sides: Array = Track.canal_sides(canal)
			var c_offset := float(canal.get("offset", 0.0))
			var c_width := float(canal.get("width", 0.0))
			for lanes in _widths(desc):
				var edge := _half_road(lanes)
				var water_lo := edge + c_offset
				var water_hi := water_lo + c_width
				for scene_path in _scenes_of(entry):
					for m in _side_markers(String(scene_path)):
						var x := float(m["x"])
						if absf(x) < CENTRE_SKIP:
							continue          # орієнтир над дорогою — так і задумано
						checked += 1
						var where := "цеглинка «%s», %s, %s «%s» на x=%.1f (світ %s, %d смуг)" % [
							id, String(scene_path).get_file(), m["role"], m["kind"], x, w, lanes]
						assert_gt(absf(x), edge + EPS,
							"%s: дорога сягає ±%.2f — маркер стоїть на біговій смузі" % [where, edge])
						var on_canal_side := sides.has(signf(x))
						if on_canal_side and c_width > 0.0:
							assert_false(absf(x) > water_lo - EPS and absf(x) < water_hi + EPS,
								"%s: канал тут на %.2f…%.2f — маркер у воді" % [where, water_lo, water_hi])
							if BEYOND_CANAL.has(String(m["role"])):
								assert_gt(absf(x), water_hi - EPS,
									"%s: забудова мусить стояти ЗА каналом (далі за %.2f)"
									% [where, water_hi])
	assert_gt(checked, 0, "бічні маркери знайшлись — інакше сторож стереже порожнечу")
