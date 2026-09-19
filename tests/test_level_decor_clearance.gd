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
## З якої висоти предмет вважається НАВІСОМ, а не перепоною. Герой має близько метра зросту;
## 2,5 м — удвічі з гаком, туди він не дістає навіть у стрибку.
const OVERHEAD_Y := 2.5


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
## seen — скільки маркерів декору взагалі переглянуто. Сам тест перевіряє ПОРОЖНЕЧУ («на дорозі
## нікого»), тож без цього числа він лишався б зеленим і на порожньому плані.
var _seen_decor := 0


func _decor_on_the_road(level: Dictionary, edge: float) -> Array:
	var out := []
	_seen_decor = 0
	# Сцени рівня беремо ПЛАНОМ, а не скануванням теки: рівень уже може бути зібраний зі
	# списку цеглинок, і теки levels/level_XX/ у нього просто нема. Сканування тоді обходило б
	# порожнечу — сторож лишався б зеленим, нічого не стережучи.
	for piece in LevelChunkLoader.plan_of(int(level["id"]), level):
		# Сцен у цеглинки одна або дві: сам чанк і вибрана під складність розкладка перешкод.
		# Обидві треба переглянути — маркери лежать і там, і там.
		# z маркера ЛОКАЛЬНА (від початку цеглинки) — зсув призначає той, хто її ставить.
		var offset := float(piece["offset_m"])
		for scene_path in (piece as Dictionary)["paths"]:
			var f := FileAccess.open(String(scene_path), FileAccess.READ)
			if f == null:
				continue
			for block in f.get_as_text().split("[node "):
				# Godot НЕ пише властивість, що дорівнює типовій, тож у маркера декору рядка role
				# може не бути зовсім (так виглядає чанк, перезбережений редактором). Шукати
				# «role = "decor"» означає тихо пропустити половину маркерів — тобто сторож
				# лишився б зеленим, нічого не стережучи.
				if block.contains("role = \"") and not block.contains("role = \"decor\""):
					continue
				if not block.contains("script = ExtResource"):
					continue
				var tr := block.find("Transform3D(")
				if tr < 0:
					continue
				var args := block.substr(tr + 12).split(")")[0].split(",")
				if args.size() < 12:
					continue
				_seen_decor += 1
				# НАВІС не стоїть на дорозі — він над нею. У Лісі листя крони висить на 4.6 м, тобто
				# вчетверо вище за героя, і дитина під ним пробігає. Те саме правило, що й для
				# арок-орієнтирів по центру, лише за іншою ознакою: там |x|, тут висота.
				if float(args[10]) >= OVERHEAD_Y:
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
		var bad := _decor_on_the_road(level, edge)
		assert_gt(_seen_decor, 0, "рівень %d: маркери декору знайдено" % num)
		assert_true(bad.is_empty(),
			("рівень %d: дорога сягає ±%.2f м, а на ній стоїть декор (%d шт.): %s")
			% [num, edge, bad.size(), bad.slice(0, 5)])
