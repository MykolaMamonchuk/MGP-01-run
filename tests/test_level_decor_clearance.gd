## Бічний декор мусить стояти ЗА краєм дороги — на кожному рівні.
##
## Вада, яку це стереже, прожила непоміченою на дванадцяти рівнях із сімнадцяти. Маркери
## декору розставлені з фіксованими |x| = 1,9 / 2,1 / 2,3 м НА ВСІХ рівнях. Для трисмугової
## дороги це правильно: край у неї на ±1,60 м, тож декор стоїть на 0,3–0,7 м далі. Але
## п'ятисмугова дорога має край ±2,60, а семисмугова ±3,60 — і ті самі 1,9–2,3 опиняються
## просто на біговій смузі. Заміряно перед правкою: 776 маркерів на рівнях 6–17, тобто ВЕСЬ
## бічний декор цих рівнів. Дерева, пальми, парасолі, хмари — у смузі, якою біжить герой.
##
## Помітити це оком майже неможливо: знімальний інструмент малює трасу з типовою шириною, а
## не з тією, що задана рівнем, тож на знімках усе виглядало правильно. Видно було б лише
## у справжній грі на п'яти- й семисмугових рівнях.
extends GutTest

## Точно як у грі: Track.road_width() = lanes * Hero3D.LANE_W + 0.2.
const LANE_W := 1.0
const ROAD_PAD := 0.2


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _edge(lanes: int) -> float:
	return (float(lanes) * LANE_W + ROAD_PAD) * 0.5


## Рівні, що РОЗШИРЮЮТЬСЯ посеред себе, сюди не входять: у них два краї — до точки
## розширення дорога ще вузька, і декор на |x| = 1,9 там стоїть правильно. Перевірка за
## найширшим краєм оголосила б це вадою, якою воно не є. Ті три рівні (4, 11, 16) стереже
## окремий, позиційний тест у tests/test_level_widening.gd.


## Бічні маркери декору, що опинились ближче до центру, ніж край дороги. Маркери по центру
## (|x| < 0.3) пропускаємо — це орієнтири-арки, вони над дорогою за задумом.
func _decor_on_the_road(num: int, edge: float) -> Array:
	var out := []
	var dir := DirAccess.open("res://levels/level_%02d" % num)
	if dir == null:
		return out
	for name in dir.get_files():
		if not name.ends_with(".tscn"):
			continue
		var f := FileAccess.open("res://levels/level_%02d/%s" % [num, name], FileAccess.READ)
		for block in f.get_as_text().split("[node "):
			if not block.contains("role = \"decor\""):
				continue
			var tr := block.find("Transform3D(")
			if tr < 0:
				continue
			var args := block.substr(tr + 12).split(")")[0].split(",")
			if args.size() < 12:
				continue
			var x := float(args[9])
			if absf(x) > 0.3 and absf(x) < edge:
				var at := block.find("kind = \"")
				out.append("%s на x=%.1f" % [block.substr(at + 8).split("\"")[0] if at >= 0 else "?", x])
	return out


func test_no_side_decor_stands_on_the_running_road() -> void:
	var levels: Array = _json("res://data/levels.json").get("levels", [])
	assert_eq(levels.size(), 17, "рівнів сімнадцять")
	for l in levels:
		var level: Dictionary = l
		var num := int(level["id"])
		if level.has("lanes_to"):
			continue
		var edge := _edge(int(level.get("lanes", 3)))
		var bad := _decor_on_the_road(num, edge)
		assert_true(bad.is_empty(),
			("рівень %d: дорога сягає ±%.2f м, а на ній стоїть декор (%d шт.): %s")
			% [num, edge, bad.size(), bad.slice(0, 5)])
