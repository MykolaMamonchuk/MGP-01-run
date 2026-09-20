## Гравець не бачить порожнечі: забудова йде суцільно вздовж дороги і в ДВА ряди.
##
## Скарга замовника: «світ пустий, гравець не має бачити пустоти, має бути все засіяно
## будинками». Тоді забудова стояла ОДНИМ рядом у смузі far_min..far_max, і в прогалини між
## будинками було видно порожнє поле аж до обрію. Плюс із дев'яти видів забудови Лужка лише
## один був справжньою моделлю.
##
## Тут стережемо саме те, що видно оком:
##   — уздовж траси немає довгої діри без жодної будівлі на борті;
##   — будівлі стоять у ДВОХ смугах по x, а не в одній (другий ряд і затуляє прогалини).
##
## Міряємо на заморожених цеглинках, бо саме вони й потрапляють у гру.
extends GutTest

## Види, які рахуємо за забудову (дерева й дрібниця — не забудова: крізь них видно поле).
const BUILD := ["house_terra", "house_terra_1", "house_terra_2", "house_terra_3",
	"house_terra_4", "house_terra_5", "house_terra_6", "house_terra_7", "house_terra_9",
	"house_red", "house_small", "house_straw", "house_teal", "city_house_a", "city_house_b",
	"hut", "mill", "well", "barn", "kiosk", "tower_terracotta"]
## Найдовша діра без будівлі, яку ще терпимо. Заміряно 19.09.2026 після другого ряду:
## найгірша діра 8,2 м, медіана найгіршого по цеглинках 4,8 м. Десять — це запас на одну
## велику будівлю, яка «з'їла» сусідні місця своєю глибиною, і не більше.
const MAX_GAP_M := 10.0
## Глибина забудови по x, за якою видно, що рядів справді два. Числом, а не межею в метрах:
## маркер `x` абсолютний від ЦЕНТРУ дороги, а край дороги їде з кількістю доріжок (3/5/7),
## тож прибита межа брехала б на широких цеглинках. Один ряд займав смугу far_min..far_max,
## тобто розкид ~4 м; із другим рядом заміряно 6,7–13,6 м, тобто ~7. Шість — між ними.
const MIN_DEPTH_M := 6.0
## І скільки забудови має стояти в ДАЛЬНІЙ третині цієї глибини — інакше «другий ряд» міг би
## виявитись двома випадковими будинками. Заміряно: 26–39%.
const FAR_THIRD_SHARE := 0.15


## Будівлі цеглинки: [{x, z, side}]. Читаємо текст сцени, а не інстанціюємо — так само,
## як tests/test_chunk_overlap.gd.
func _buildings(path: String) -> Array:
	var out := []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	for block in f.get_as_text().split("[node "):
		var kind_at := block.find("kind = \"")
		if kind_at < 0:
			continue
		var kind := block.substr(kind_at + 8).split("\"")[0]
		if not BUILD.has(kind):
			continue
		var tr := block.find("Transform3D(")
		if tr < 0:
			continue
		var args := block.substr(tr + 12).split(")")[0].split(",")
		if args.size() < 12:
			continue
		out.append({"kind": kind, "x": float(args[9]), "z": -float(args[11])})
	return out


func _meadow_chunks() -> Array:
	var out := []
	var library := ChunkLibrary.scan()
	for id in library.keys():
		var entry: Dictionary = library[id]
		if not ((entry["desc"] as Dictionary).get("worlds", []) as Array).has("meadow"):
			continue
		var path := "%s/dress_meadow.tscn" % String(entry["dir"])
		if FileAccess.file_exists(path):
			out.append([String(id), path])
	return out


func test_no_long_stretch_without_a_building() -> void:
	var chunks := _meadow_chunks()
	assert_gt(chunks.size(), 0, "цеглинки Лужка знайшлись — інакше сторож стереже порожнечу")
	var bad := []
	var checked := 0
	for pair in chunks:
		var all := _buildings(String(pair[1]))
		for side in [-1.0, 1.0]:
			var zs := []
			for b in all:
				if signf(float(b["x"])) == side:
					zs.append(float(b["z"]))
			zs.sort()
			if zs.size() < 2:
				bad.append("%s: на борті %s узагалі немає забудови" % [pair[0], side])
				continue
			checked += 1
			for i in range(zs.size() - 1):
				var gap: float = float(zs[i + 1]) - float(zs[i])
				if gap > MAX_GAP_M:
					bad.append("%s, борт %s: діра %.1f м на z=%.0f"
						% [pair[0], "прав" if side > 0.0 else "лів", gap, zs[i]])
	assert_gt(checked, 0, "борти для перевірки знайшлись")
	assert_eq(bad.size(), 0, "у забудові є діри: %s" % [bad.slice(0, 6)])


## Другий ряд — це не прикраса, а те, чим закрито прогалини. Якщо він зникне, сторож
## має впасти, а не мовчки пропустити «одну вулицю з полем позаду».
func test_buildings_stand_in_two_rows() -> void:
	var chunks := _meadow_chunks()
	assert_gt(chunks.size(), 0, "цеглинки Лужка знайшлись")
	var thin := []
	for pair in chunks:
		var xs := []
		for b in _buildings(String(pair[1])):
			xs.append(absf(float(b["x"])))
		xs.sort()
		if xs.size() < 20:
			thin.append("%s: забудови майже нема (%d)" % [pair[0], xs.size()])
			continue
		var lo: float = xs[0]
		var hi: float = xs[-1]
		var depth := hi - lo
		var edge := lo + depth * 2.0 / 3.0
		var outer := 0
		for x in xs:
			if float(x) >= edge:
				outer += 1
		var share := float(outer) / float(xs.size())
		if depth < MIN_DEPTH_M or share < FAR_THIRD_SHARE:
			thin.append("%s: глибина %.1f м, у дальній третині %.0f%%"
				% [pair[0], depth, share * 100.0])
	assert_eq(thin.size(), 0, "забудова не в два ряди: %s" % [thin])


## І те, з чого все почалось: у списку забудови світу мають переважати СПРАВЖНІ моделі, а не
## саморобні коробки на 128–248 граней. Межу беремо низько (1000 граней) — це не вимога
## деталізації, а ознака «модель прийшла з incoming, а не з генератора в tools/».
func test_most_meadow_buildings_are_real_models() -> void:
	var f := FileAccess.open("res://data/worlds/meadow.json", FileAccess.READ)
	assert_not_null(f, "світ Лужка читається")
	var world: Dictionary = JSON.parse_string(f.get_as_text())
	var list: Array = world.get("buildings_far", [])
	assert_gt(list.size(), 0, "у Лужка є список забудови")
	var real := 0
	for kind in list:
		var mesh := PropLibrary.mesh(String(kind))
		if mesh != null and mesh.get_faces().size() / 3 >= 1000:
			real += 1
	assert_gte(real, list.size() / 2,
		"справжніх моделей %d із %d — саморобні коробки не мають переважати" % [real, list.size()])


## ЩІЛЬНІСТЬ ПЕРШОЇ ЛІНІЇ. Сторож із іншого боку: тест вище стежить, щоб не було ДОВГОЇ діри,
## і 10 м його влаштовують; цей стежить за буденним проміжком між сусідами.
##
## Замовник просив «поставити щільніше першу лінію, щоб не було так пусто і щоб ми не бачили
## заднього фону». Виявилось, що будинків для цього не бракує — бракує щільності: між
## сусідами лишалось 2,76 м медіаною, і крізь ці щілини по діагоналі було видно поле й небо.
## Полагоджено звуженням смуги глибини (Track.FAR_MIN/FAR_MAX 2,5–4,5 → 2,2–3,2) і зазору
## між сусідами (Track.FAR_GAP_MIN 0,3 → 0,1).
##
## Заміряно 20.09.2026, по всіх цеглинках Лужка:
##
##     проміжок у першій лінії   медіана 2,76 → 2,01 м, будинків у ній 1091 → 1125
##     небо + гола трава у смузі обрію на кадрі рівня 1:   10,82% → 6,18%
##     ціна: draw calls ті самі 206, примітивів 235k → 260k, кадр не зрушив
##
## Число, а не око, бо зламати це можна мовчки: досить перезаморозити цеглинки зі старими
## константами (`python3 tools/freeze_chunk.py --all`), і гра гратиметься так само.
const MAX_LINE_GAP_M := 2.4


func test_persha_liniia_stoit_shchilno() -> void:
	var chunks := _meadow_chunks()
	assert_gt(chunks.size(), 0, "цеглинки Лужка знайшлись")
	var gaps := []
	var in_line := 0
	for pair in chunks:
		var all := _buildings(String(pair[1]))
		var abs_xs := []
		for b in all:
			abs_xs.append(absf(float(b["x"])))
		abs_xs.sort()
		if abs_xs.size() < 16:
			continue
		# Перша лінія — ближча половина глибини забудови. Межу беремо з самих даних, а не
		# в метрах: край дороги їде з кількістю доріжок, і прибите число брехало б на
		# широких цеглинках (див. MIN_DEPTH_M вище).
		var mid: float = float(abs_xs[0]) + (float(abs_xs[-1]) - float(abs_xs[0])) * 0.5
		for side in [-1.0, 1.0]:
			var zs := []
			for b in all:
				if signf(float(b["x"])) == side and absf(float(b["x"])) <= mid:
					zs.append(float(b["z"]))
			if zs.size() < 8:
				continue
			zs.sort()
			in_line += zs.size()
			for i in range(zs.size() - 1):
				gaps.append(float(zs[i + 1]) - float(zs[i]))
	assert_gt(in_line, 900, "перша лінія не порідшала: %d будинків" % in_line)
	gaps.sort()
	# Медіана, а не середнє: одна діра на 12 м (а такі є — на її місці стоїть рукотворна
	# брама чи місток) не має вирішувати за всю бібліотеку.
	var median: float = float(gaps[gaps.size() / 2])
	assert_lt(median, MAX_LINE_GAP_M,
		"перша лінія стоїть щільно: медіанний проміжок %.2f м" % median)
