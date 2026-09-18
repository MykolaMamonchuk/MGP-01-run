## Корінь авторського чанка рівня — і єдине, що видно в редакторі, крім самих маркерів.
##
## Навіщо z_offset_m. Маркери довго лежали в АБСОЛЮТНИХ метрах рівня: chunk_01 починався на
## z = −150, chunk_05 — на −750. Відкритий у редакторі чанк через це виглядав порожнім: усе
## його добро стояло за сотні метрів від початку координат, куди камера не дивиться. Тепер
## маркер знає своє місце В ЧАНКУ, а чанк — своє місце в рівні; LevelTimeline.extract()
## складає одне з одним і віддає грі ту саму абсолютну відстань, що й раніше.
##
## Це ще й перший крок до бібліотеки чанків (docs/tasks/level-chunk-library.md): цеглинку з
## власною нумерацією можна поставити в будь-яке місце будь-якого рівня, просто змінивши
## z_offset_m.
##
## СВІТ-ОРІЄНТИР малюється ЛИШЕ в редакторі. Потрібен він тому, що в грі світу як об'єктів
## не існує: дорогу, узбіччя, канал, воду й дальню забудову будує Track під час гри з
## data/worlds/*.json. Тому чанк, відкритий у редакторі, і виглядав порожнім полем — правити
## розкладку «на око» не було відносно ЧОГО.
##
## Тут те саме малюється наближено й статично: смуги дороги за кількістю доріжок ЦЬОГО рівня,
## узбіччя, канал із водою на його справжній відстані від краю дороги, ПОРУЧНІ вздовж берега,
## МІСТКИ через канал і риски через 10 метрів.
## Номер рівня беремо зі шляху сцени (levels/level_07/chunk_02.tscn → рівень 7), решту — з
## data/levels.json і data/worlds/*.json, тобто з тих самих даних, що й гра.
##
## Нічого з цього не потрапляє ні в .tscn, ні в гру: прев'ю додається з owner = null, а
## LevelTimeline.extract() збирає тільки LevelMarker3D.
@tool
class_name LevelLayout
extends Node3D

## Ширина доріжки — та сама, що в Hero3D.LANE_W. Тут константа, бо редакторський вузол не
## має тягнути за собою пів гри заради одного числа.
const LANE_W := 1.0
## Півширина дороги для 3/5/7 доріжок: смуги × LANE_W + 0.2 бордюру, поділити навпіл.
const EDGES := [1.6, 2.6, 3.6]
## Скільки метрів малювати вперед. Збігається з LevelChunkLoader.CHUNK_LENGTH_M.
const GUIDE_LENGTH_M := 150.0
## Крок поперечних рисок — щоб на око читалась відстань.
const TICK_M := 10.0
## Поручні: одна ланка на метр траси, стоїть на RAIL_INSET ближче до дороги за край води.
## Числа ті самі, що в Track (RAIL_INSET, BRIDGE_MARGIN) — тут константи, бо редакторський
## вузол не має тягнути за собою пів гри заради трьох величин.
const RAIL_INSET := 0.10
const RAIL_LINK_M := 1.0
const RAIL_W := 0.08
## Висота стінки-поручня в орієнтирі. Лежача смужка на землі з ігрового ракурсу зникала
## зовсім — поручень мусить СТОЯТИ, як і в грі, інакше його не видно ні збоку, ні згори.
const RAIL_H := 0.45
const BRIDGE_DECK_MARGIN := 0.4
## Берег каналу: три шари по BANK_H, завширшки BANK_W, з обох бортів кожного каналу. Числа ті
## самі, що в Track. Саме на цій межі «вода — суша» живе мерехтіння, тож автор рівня мусить
## бачити, де вона проходить, а не здогадуватись.
const BANK_W := 0.18
const BANK_H := 0.14
const CLIFF_LAYERS := 3
const CANAL_DEPTH := 0.35

## Відстань від старту рівня до початку цього чанка, у метрах. Для нарізки по 150 м це
## просто номер чанка × 150.
@export var z_offset_m: float = 0.0:
	set(v):
		z_offset_m = v
		_rebuild_guide()

## Показувати дорогу-орієнтир. Вимикається, коли вона заважає дивитись на сам декор.
@export var show_guide: bool = true:
	set(v):
		show_guide = v
		_rebuild_guide()

var _guide: Node3D = null


## Зсув чанка, прочитаний просто з ТЕКСТУ .tscn. Потрібен тестам і інструментам, які
## розбирають сцени текстом, не вантажачи їх: після переходу на локальні координати z
## маркера сама по собі більше нічого не означає без цього числа.
static func offset_from_text(text: String) -> float:
	var i := text.find("z_offset_m = ")
	if i < 0:
		return 0.0
	return float(text.substr(i + 13).split("\n")[0])


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_guide()


func _exit_tree() -> void:
	if _guide != null and is_instance_valid(_guide):
		_guide.queue_free()
	_guide = null


## Те саме, але без перевірки «ми в редакторі» — для src/debug/chunk_shot.gd, який показує
## розкладку поза редактором. У грі цього ніхто не кличе.
func _rebuild_guide_forced() -> void:
	if not is_inside_tree():
		return
	_build_guide()


func _rebuild_guide() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_build_guide()


func _build_guide() -> void:
	if _guide != null and is_instance_valid(_guide):
		_guide.queue_free()
	_guide = null
	if not show_guide:
		return
	var w := _world_data()
	var root := Node3D.new()
	for band in _bands(w):
		root.add_child(band)
	root.add_child(_road(w))
	for part in _rails_and_bridges(w):
		root.add_child(part)
	root.add_child(_lines(w))
	add_child(root)
	root.owner = null
	_guide = root


## Дані рівня й світу — з тих самих файлів, що читає гра. Номер рівня беремо зі шляху сцени.
func _world_data() -> Dictionary:
	var out := {"lanes": 3, "ground": Color(0.66, 0.73, 0.33), "side": Color(0.36, 0.56, 0.28),
		"water": Color(0.29, 0.51, 0.66), "road": Color(0.93, 0.87, 0.70),
		"wood": Color(0.55, 0.36, 0.22), "bridges_every": 0, "level": 0,
		"canal_side": "", "canal_offset": 0.0, "canal_width": 0.0}
	var num := _level_number()
	if num <= 0:
		return out
	var levels: Array = _json("res://data/levels.json").get("levels", [])
	var level := {}
	for l in levels:
		if int((l as Dictionary).get("id", 0)) == num:
			level = l
			break
	if level.is_empty():
		return out
	out["lanes"] = int(level.get("lanes", 3))
	out["level"] = num
	var world := _json("res://data/worlds/%s.json" % String(level.get("world", "meadow")))
	if world.is_empty():
		return out
	out["ground"] = _color(world.get("ground", ""), out["ground"])
	out["side"] = _color(world.get("side", ""), out["side"])
	out["water"] = _color(world.get("water", ""), out["water"])
	out["road"] = _color(world.get("road_color", world.get("road_surface", "")), out["road"])
	out["bridges_every"] = int(world.get("bridges_every", 0))
	# Колір орієнтира беремо СВІЙ, а не зі світу: accent у Лужку рожевий, і поручні на знімку
	# читались як помилка. Тут потрібен спокійний дерев'яний, який не сперечається з декором.
	var canal = world.get("canal", null)
	if typeof(canal) == TYPE_DICTIONARY:
		out["canal_side"] = String((canal as Dictionary).get("side", ""))
		out["canal_offset"] = float((canal as Dictionary).get("offset", 0.0))
		out["canal_width"] = float((canal as Dictionary).get("width", 0.0))
	return out


## levels/level_07/chunk_02.tscn → 7. Нуль — шлях не той, малюємо типове.
func _level_number() -> int:
	var path := scene_file_path
	if path == "":
		path = get_scene_file_path()
	var at := path.find("level_")
	if at < 0:
		return 0
	return int(path.substr(at + 6, 2))


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _color(value, fallback: Color) -> Color:
	var s := String(value)
	return Color(s) if s.begins_with("#") else fallback


## Півширина дороги: доріжки × 1 м + 20 см бордюру, поділити навпіл. Та сама формула, що
## Track.road_width().
func half_road(lanes: int) -> float:
	return (float(lanes) * LANE_W + 0.2) * 0.5


func _plate(size: Vector2, at: Vector3, color: Color, alpha := 1.0) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position = at
	var m := StandardMaterial3D.new()
	color.a = alpha
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	return mi


## Смуги світу, що НЕ ПЕРЕКРИВАЮТЬСЯ. Перша версія клала суцільну плиту трави на всю ширину,
## а воду — плитою поверх неї, на сантиметр вище. Цього замало: на пологому куті погляду край
## двох майже копланарних площин починає зубчитись, і замовник упізнав це одразу — та сама
## вада, що колись була на березі каналу в самій грі («вони на одній x,y і грають»).
##
## Тому тут кожна смуга займає СВІЙ проміжок по x і ніде не лізе під сусідню: узбіччя від краю
## дороги до води, вода, далі знову трава. Перекриття нема — нема чому й битись.
func _bands(w: Dictionary) -> Array:
	var out: Array = []
	var half := half_road(int(w["lanes"]))
	var side := String(w["canal_side"])
	var offset: float = float(w["canal_offset"])
	var width: float = float(w["canal_width"])
	var far := 20.0
	for s in [-1.0, 1.0]:
		var sign := float(s)
		var has_canal := width > 0.0 and (side == "both"
			or (side == "left" and sign < 0.0) or (side == "right" and sign > 0.0))
		if not has_canal:
			out.append(_band(sign, half, far, w["side"]))
			continue
		var near: float = half + offset
		out.append(_band(sign, half, near, w["side"]))
		out.append(_band(sign, near, near + width, w["water"], -CANAL_DEPTH))
		out.append(_band(sign, near + width, far, w["side"]))
		# стінки берега — по обидва борти каналу, як у грі
		out.append_array(_bank(sign, near, 1.0))
		out.append_array(_bank(sign, near + width, -1.0))
	return out


## Одна смуга вздовж траси: від |x| = from до |x| = to по бік sign.
func _band(sign: float, from: float, to: float, color: Color, y := -0.02) -> MeshInstance3D:
	var w := maxf(to - from, 0.001)
	return _plate(Vector2(w, GUIDE_LENGTH_M),
		Vector3(sign * (from + w * 0.5), y, -GUIDE_LENGTH_M * 0.5), color)


## Полотно дороги за кількістю доріжок ЦЬОГО рівня.
func _road(w: Dictionary) -> MeshInstance3D:
	var half := half_road(int(w["lanes"]))
	return _plate(Vector2(half * 2.0, GUIDE_LENGTH_M),
		Vector3(0.0, -0.01, -GUIDE_LENGTH_M * 0.5), w["road"])


## Поручні вздовж берега й містки через канал. У грі їх ставить Track по рядах: поручень —
## одна ланка на кожен метр траси, місток — кожен `bridges_every`-й ряд, і на ряду з містком
## поручнів нема, інакше вони перегородили б прохід. Тут повторено ту саму арифметику, бо
## автор рівня має бачити, де вже зайнято: поставити дерево там, де буде місток, — типова
## помилка, яку інакше видно лише в грі.
func _rails_and_bridges(w: Dictionary) -> Array:
	var out: Array = []
	var side := String(w["canal_side"])
	if side == "" or float(w["canal_width"]) <= 0.0:
		return out
	var half := half_road(int(w["lanes"]))
	var offset: float = float(w["canal_offset"])
	var width: float = float(w["canal_width"])
	var every: int = int(w["bridges_every"])
	var signs: Array = []
	if side == "both":
		signs = [-1.0, 1.0]
	elif side == "left":
		signs = [-1.0]
	elif side == "right":
		signs = [1.0]
	for s in signs:
		var sign := float(s)
		var rail_x := sign * (half + offset - RAIL_INSET)
		var z := 0.0
		while z <= GUIDE_LENGTH_M:
			var is_bridge := every > 0 and posmod(int(round(z)), every) == 0
			if is_bridge:
				out.append(_plate(Vector2(width + BRIDGE_DECK_MARGIN, RAIL_LINK_M * 0.9),
					Vector3(sign * (half + offset + width * 0.5), 0.02, -z - 0.5), w["wood"]))
			else:
				out.append(_rail_link(rail_x, -z - 0.5, w["wood"]))
			z += RAIL_LINK_M
	return out


## Стінка берега на одному борті каналу: CLIFF_LAYERS шарів, кожен трохи глибше й трохи далі
## в бік води — так само, як їх ставить Track. inward = +1, якщо вода праворуч від цієї межі.
func _bank(sign: float, x: float, inward: float) -> Array:
	var out: Array = []
	var colors := [Color(0.79, 0.47, 0.31), Color(0.65, 0.36, 0.23), Color(0.48, 0.25, 0.16)]
	for k in range(CLIFF_LAYERS):
		var pm := PlaneMesh.new()
		pm.size = Vector2(GUIDE_LENGTH_M, BANK_H)
		pm.orientation = PlaneMesh.FACE_Z
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.position = Vector3(sign * (x - inward * 0.03 * float(k)),
			-BANK_H * (float(k) + 0.5), -GUIDE_LENGTH_M * 0.5)
		# площина FACE_Z дивиться вздовж Z; стінка берега мусить іти ВЗДОВЖ траси, тож
		# довертаємо на чверть оберту — інакше вона лягає впоперек на всю ширину світу
		mi.rotation.y = PI * 0.5
		var m := StandardMaterial3D.new()
		m.albedo_color = colors[k]
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		out.append(mi)
	return out


## Одна ланка поручня — СТОЯЧА стінка заввишки RAIL_H. Довжина трохи менша за метр, тож між
## ланками лишається видимий проміж: саме ці стики автор рівня і хотів бачити, бо по них
## читається, де закінчується одна ланка й починається наступна.
func _rail_link(x: float, z: float, color: Color) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(RAIL_LINK_M * 0.9, RAIL_H)
	pm.orientation = PlaneMesh.FACE_Z
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position = Vector3(x, RAIL_H * 0.5, z)
	mi.rotation.y = PI * 0.5
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi


## Лінії: межі доріжок, край дороги цього рівня (яскраво) і краї для інших смуг (тьмяно),
## плюс поперечні риски через TICK_M метрів.
func _lines(w: Dictionary) -> MeshInstance3D:
	var lanes := int(w["lanes"])
	var half := half_road(lanes)
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var lane_c := Color(1.0, 1.0, 1.0, 0.45)
	var tick_c := Color(0.1, 0.1, 0.1, 0.35)
	for i in range(-3, 4):
		var x := float(i) * LANE_W + LANE_W * 0.5
		if absf(x) >= half:
			continue
		_line(verts, colors, Vector3(x, 0.0, 0.0), Vector3(x, 0.0, -GUIDE_LENGTH_M), lane_c)
	for k in range(EDGES.size()):
		var e: float = EDGES[k]
		var c := Color(0.1, 0.9, 0.3) if is_equal_approx(e, half) else Color(0.5, 0.5, 0.5, 0.35)
		for s in [-1.0, 1.0]:
			_line(verts, colors, Vector3(e * s, 0.0, 0.0), Vector3(e * s, 0.0, -GUIDE_LENGTH_M), c)
	var z := 0.0
	while z <= GUIDE_LENGTH_M:
		var reach: float = half + 6.0 if fmod(z, 50.0) < 0.001 else half
		_line(verts, colors, Vector3(-reach, 0.0, -z), Vector3(reach, 0.0, -z), tick_c)
		z += TICK_M
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	return mi


func _line(verts: PackedVector3Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Color) -> void:
	verts.append(a)
	verts.append(b)
	colors.append(c)
	colors.append(c)
