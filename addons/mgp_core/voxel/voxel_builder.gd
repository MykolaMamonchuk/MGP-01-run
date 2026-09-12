## Збирає воксельний меш із JSON-опису. Жодних зовнішніх 3D-моделей — усе з даних.
##
## Формат (data/voxels/*.json):
## {
##   "size": 0.12,                       # розмір одного вокселя, м
##   "palette": {"o": "#FFB84D", "k": "#222222"},
##   "layers": [                         # знизу вгору (y)
##     ["oo", "oo"],                     # шар = рядки (z: від переду -Z до заду +Z), символи = x (зліва направо)
##     [".k", "k."]                      # "." — порожньо
##   ]
## }
## Меш центрується по x і z, стоїть на y = 0. Приховані грані (між сусідами) не генеруються.
class_name VoxelBuilder
extends RefCounted

const EMPTY := "."

## Грані: нормаль + 4 вершини куба [0..1] у порядку за годинниковою стрілкою (Godot: front face = CW).
const FACES := [
	{"n": Vector3(0, 1, 0),  "v": [Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)]},
	{"n": Vector3(0, -1, 0), "v": [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0)]},
	{"n": Vector3(1, 0, 0),  "v": [Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]},
	{"n": Vector3(-1, 0, 0), "v": [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)]},
	{"n": Vector3(0, 0, 1),  "v": [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1)]},
	{"n": Vector3(0, 0, -1), "v": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)]},
]

## Колір «моделі нема» — навмисно помітний.
## Модуль автономний (не знає про гру), тому колір тут, а не в Palette.
const MISSING_COLOR := "#FF4FA3"

static var _cache: Dictionary = {}
static var _material: Material
static var _material_alpha: ShaderMaterial
static var _material_glossy: Material

## Пілот "glossy toy" (Рівень 1, Лужок, вересень 2026): поки нема sculpted-моделей пропів
## (потрібна зовнішня генерація, якої в нас нема), пробуємо піднятись до нового арт-вектора
## лише інженерією — згладженими нормалями (замість жорсткої грані на кожен куб) і
## справжнім specular/roughness (hero_glossy.gdshader) на ІСНУЮЧИХ вокселях. Це не заміна
## sculpted-пропам, а найкраще, що можна зробити без нових асетів. Список — воксель-імена,
## які реально йдуть у level_01.tscn (data/worlds/meadow.json), не всі 164 вокселі гри.
const GLOSSY_KINDS := {
	"stump": true, "branch": true, "puddle": true, "bush": true, "fence": true,
	"beehive": true, "cow": true, "haycart": true, "xbox_red": true, "clothesline": true,
	"tree": true, "flower": true, "mushroom": true, "arch_terracotta": true,
}


static func load_def(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("VoxelBuilder: не знайдено %s" % path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Розбирає опис у словник {Vector3i: Color} + розміри. Чиста функція — для тестів.
static func parse(def: Dictionary, palette_override: Dictionary = {}) -> Dictionary:
	var cells: Dictionary = {}
	var palette: Dictionary = def.get("palette", {}).duplicate()
	for k in palette_override.keys():
		palette[k] = palette_override[k]
	var layers: Array = def.get("layers", [])
	var w := 0
	var d := 0
	for y in range(layers.size()):
		var rows: Array = layers[y]
		d = max(d, rows.size())
		for z in range(rows.size()):
			var row := String(rows[z])
			w = max(w, row.length())
			for x in range(row.length()):
				var ch := row[x]
				if ch == EMPTY or ch == " ":
					continue
				if not palette.has(ch):
					push_warning("VoxelBuilder: символ '%s' не в палітрі" % ch)
					continue
				cells[Vector3i(x, y, z)] = Color(String(palette[ch]))
	return {"cells": cells, "size": Vector3i(w, layers.size(), d)}


## Кількість видимих граней — для тестів детермінованості.
static func count_faces(cells: Dictionary) -> int:
	var n := 0
	for p in cells.keys():
		for face in FACES:
			if not cells.has(p + Vector3i(face["n"])):
				n += 1
	return n


static func build(def: Dictionary, palette_override: Dictionary = {}, smooth: bool = false) -> ArrayMesh:
	var parsed := parse(def, palette_override)
	var cells: Dictionary = parsed["cells"]
	var dims: Vector3i = parsed["size"]
	var s := float(def.get("size", 0.1))
	var origin := Vector3(-dims.x * s * 0.5, 0.0, -dims.z * s * 0.5)

	var positions := PackedVector3Array()
	var flat_normals := PackedVector3Array()
	var colors := PackedColorArray()
	for p in cells.keys():
		var col: Color = cells[p]
		var base := origin + Vector3(p) * s
		for face in FACES:
			if cells.has(p + Vector3i(face["n"])):
				continue
			var v: Array = face["v"]
			var q := [base + v[0] * s, base + v[1] * s, base + v[2] * s, base + v[3] * s]
			var n: Vector3 = face["n"]
			for idx in [0, 1, 2, 0, 2, 3]:
				positions.append(q[idx])
				flat_normals.append(n)
				colors.append(col)

	var normals := _smooth_normals(positions, flat_normals) if smooth else flat_normals
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(positions.size()):
		st.set_normal(normals[i])
		st.set_color(colors[i])
		st.add_vertex(positions[i])
	st.set_material(material_glossy() if smooth else material())
	var mesh := st.commit()
	return mesh


## Glossy toy (див. GLOSSY_KINDS): жорстка нормаль на грань → усереднена нормаль по всіх
## гранях, що сходяться в тій самій точці (по всьому мешу, не по одному кубику) — та сама
## ідея, що й у HeroRig._flat_arrays() для героїв: геометрія лишається кубічною, а
## освітлення читається м'яко-округлим, без гострих фасетів.
static func _smooth_normals(positions: PackedVector3Array, flat_normals: PackedVector3Array) -> PackedVector3Array:
	var sums: Dictionary = {}
	for i in range(positions.size()):
		var key := _pos_key(positions[i])
		sums[key] = (sums[key] as Vector3) + flat_normals[i] if sums.has(key) else flat_normals[i]
	var out := PackedVector3Array()
	out.resize(positions.size())
	for i in range(positions.size()):
		var acc: Vector3 = sums[_pos_key(positions[i])]
		out[i] = acc.normalized() if acc.length_squared() > 1e-8 else flat_normals[i]
	return out


static func _pos_key(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0))


## Один матеріал на всі вокселі — мінімум draw calls. Шейдер «пух» (rim); якщо його нема — простий StandardMaterial.
static func material() -> Material:
	if _material == null:
		var shader_path := "res://addons/mgp_core/voxel/voxel.gdshader"
		if ResourceLoader.exists(shader_path):
			var sm := ShaderMaterial.new()
			sm.shader = load(shader_path)
			_material = sm
		else:
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.roughness = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			_material = m
	return _material


## Glossy toy (GLOSSY_KINDS): той самий шейдер, що й у ригнутих героїв (справжній
## specular/roughness), а не «пух»-емісія voxel.gdshader.
static func material_glossy() -> Material:
	if _material_glossy == null:
		var shader_path := "res://src/run3d/hero_glossy.gdshader"
		if ResourceLoader.exists(shader_path):
			var sm := ShaderMaterial.new()
			sm.shader = load(shader_path)
			_material_glossy = sm
		else:
			_material_glossy = material()
	return _material_glossy


## Напівпрозорий матеріал (Хмаринка). Ставиться як material_override на конкретний MeshInstance3D.
static func material_alpha(alpha: float = 0.7) -> ShaderMaterial:
	if _material_alpha == null:
		_material_alpha = ShaderMaterial.new()
		_material_alpha.shader = load("res://addons/mgp_core/voxel/voxel_alpha.gdshader")
	var m := _material_alpha.duplicate() as ShaderMaterial
	m.set_shader_parameter("alpha", alpha)
	return m


## Меш за іменем файлу в data/voxels/, з кешем. palette_override — інші кольори того ж силуету (герої, друг).
static func mesh(name: String, palette_override: Dictionary = {}) -> ArrayMesh:
	var key := name
	if not palette_override.is_empty():
		key += ":" + JSON.stringify(palette_override)
	if _cache.has(key):
		return _cache[key]
	var def := load_def("res://data/voxels/%s.json" % name)
	var m := build(def, palette_override, GLOSSY_KINDS.has(name)) if not def.is_empty() else _fallback()
	_cache[key] = m
	return m


static func instance(name: String, palette_override: Dictionary = {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(name, palette_override)
	mi.name = name.capitalize().replace(" ", "")
	return mi


## Рожевий кубик, якщо файл не знайдено — видно одразу, гра не падає.
static func _fallback() -> ArrayMesh:
	return build({"size": 0.5, "palette": {"p": MISSING_COLOR}, "layers": [["p"]]})
