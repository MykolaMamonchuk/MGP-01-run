## Кеш однотонних матеріалів — один на колір, щоб не плодити draw calls і алокації.
class_name Mats
extends RefCounted

static var _cache: Dictionary = {}


static func solid(color: Color) -> StandardMaterial3D:
	var key := color.to_rgba32()
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		_cache[key] = m
	return _cache[key]


static func box(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = solid(color)
	return mi


## Глянцевий кеш — окремий від solid() (roughness=1): для очей (арт-вектор glossy toy,
## вересень 2026) потрібен справжній catchlight, а не матовий колір.
static var _glossy_cache: Dictionary = {}


static func glossy(color: Color) -> StandardMaterial3D:
	var key := color.to_rgba32()
	if not _glossy_cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.15
		m.metallic = 0.0
		m.metallic_specular = 0.6
		_glossy_cache[key] = m
	return _glossy_cache[key]


static func box_glossy(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = glossy(color)
	return mi


## Куля, сплющена до `size` (як box(), але кругла) — для очей і бліків: референс-арт
## малює круглі "аніме"-очі, а не кутасті коробочки. Одна одинична сфера на всі розміри,
## масштаб вузла (не сама сітка) робить її овалом — дешево й без нового меша на виклик.
static var _eye_sphere: SphereMesh


static func dome(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if _eye_sphere == null:
		_eye_sphere = SphereMesh.new()
		_eye_sphere.radius = 0.5
		_eye_sphere.height = 1.0
		_eye_sphere.radial_segments = 20
		_eye_sphere.rings = 10
	mi.mesh = _eye_sphere
	mi.scale = size
	mi.material_override = solid(color)
	return mi


static func dome_glossy(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := dome(size, color)
	mi.material_override = glossy(color)
	return mi
