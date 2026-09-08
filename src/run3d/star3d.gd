## Зірочка. Крутиться, світиться (emission), притягується магнітом, зникає з «дзинь».
## value — скільки зірочок дає (2 — на платформі другого рівня).
## GDD v1.4: на дорозі зірочки замінили золоті злитки (Ingot3D з тим самим API) —
## цей клас лишився для подій/тестів і як запасний вигляд пікапа.
class_name Star3D
extends Node3D

## Радіус широкого магніта (пікап): 3 доріжки завширшки — 1,5 доріжки в кожен бік.
const WIDE_LANES := 3.0
const WIDE_REACH := 4.0

static var _glow_mat: StandardMaterial3D

var collected := false
var value := 1
var _mesh: MeshInstance3D
var _t := randf() * TAU


## Жовте сяйво для всіх зірочок — один матеріал на всі (вершинні кольори лишаються альбедо).
static func glow_material() -> StandardMaterial3D:
	if _glow_mat == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.6
		m.emission_enabled = true
		m.emission = Palette.STAR
		m.emission_energy_multiplier = 0.9
		_glow_mat = m
	return _glow_mat


func _ready() -> void:
	_mesh = VoxelBuilder.instance("star")
	_mesh.rotation.x = PI * 0.5   # плоска зірка стоїть вертикально
	_mesh.material_override = glow_material()
	if value > 1:
		# подвійна зірочка — більша й помітніша
		_mesh.scale = Vector3.ONE * 1.3
	add_child(_mesh)


## magnet — радіус із профілю (клітинок); wide — пікап «магніт»: тягне з сусідніх доріжок і з більшої відстані.
func tick(delta: float, hero: Node3D, magnet: float, wide: bool = false) -> bool:
	_t += delta
	_mesh.rotation.y += delta * 3.0
	_mesh.position.y = sin(_t * 3.0) * 0.06
	var hero_pos := Vector3(hero.position.x, hero.position.y + 0.5, 0.0)
	var d := position.distance_to(hero_pos)
	if wide:
		# широкий магніт: 3 доріжки завширшки, летить до героя швидко
		if absf(position.x - hero_pos.x) < WIDE_LANES * 0.5 * Hero3D.LANE_W + 0.3 and d < WIDE_REACH:
			position = position.lerp(hero_pos, minf(1.0, delta * 8.0))
	elif absf(position.x - hero_pos.x) < 0.55 and d < magnet * 1.2:
		# звичайний магніт тягне лише зі СВОЄЇ доріжки (|dx| < половини доріжки), але з більшої відстані по z/y
		position = position.lerp(hero_pos, minf(1.0, delta * 10.0))
	return d < 0.5 and absf(position.x - hero_pos.x) < 0.55


func collect() -> void:
	collected = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 1.8, 0.12)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.15)
	tw.finished.connect(queue_free)
