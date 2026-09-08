## Золотий злиток (GDD v1.4 §3 «Злитки») — те, що лежить на дорозі замість зірочок.
## Повільно крутиться, погойдується, притягується магнітом, зникає з «дзинь» і золотим вибухом.
## value — скільки монеток дає (2 — на даху транспорту / платформі, 100 — великий злиток «+100»).
## API навмисно такий самий, як у Star3D: Spawner3D працює з ними однаково.
class_name Ingot3D
extends Node3D

## Радіус широкого магніта (пікап): 3 доріжки завширшки — 1,5 доріжки в кожен бік.
const WIDE_LANES := 3.0
const WIDE_REACH := 4.0
## З якого значення злиток вважається «великим» (+100).
const BIG_VALUE := 100

static var _glow_mat: StandardMaterial3D

var collected := false
var value := 1
var _mesh: MeshInstance3D
var _t := randf() * TAU


## Золоте сяйво для всіх злитків — один матеріал на всі (вершинні кольори лишаються альбедо).
static func glow_material() -> StandardMaterial3D:
	if _glow_mat == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.5
		m.emission_enabled = true
		m.emission = Palette.STAR
		m.emission_energy_multiplier = 0.8
		_glow_mat = m
	return _glow_mat


## Чи це великий злиток «+100» — за значенням, щоб Spawner не мусив ставити зайвий прапорець.
func is_big() -> bool:
	return value >= BIG_VALUE


func _ready() -> void:
	_mesh = VoxelBuilder.instance("ingot_big" if is_big() else "ingot")
	_mesh.material_override = glow_material()
	if value == 2:
		_mesh.scale = Vector3.ONE * 1.25   # подвійний злиток на даху — помітніший
	add_child(_mesh)


## magnet — радіус із профілю (клітинок); wide — пікап «магніт»: тягне з сусідніх доріжок і з більшої відстані.
func tick(delta: float, hero: Node3D, magnet: float, wide: bool = false) -> bool:
	_t += delta
	_mesh.rotation.y += delta * 1.6        # повільніше за зірочку — злиток важкий
	_mesh.position.y = sin(_t * 2.6) * 0.05
	var hero_pos := Vector3(hero.position.x, hero.position.y + 0.5, 0.0)
	var d := position.distance_to(hero_pos)
	if wide:
		if absf(position.x - hero_pos.x) < WIDE_LANES * 0.5 * Hero3D.LANE_W + 0.3 and d < WIDE_REACH:
			position = position.lerp(hero_pos, minf(1.0, delta * 8.0))
	elif absf(position.x - hero_pos.x) < 0.55 and d < magnet * 1.2:
		position = position.lerp(hero_pos, minf(1.0, delta * 10.0))
	return d < 0.5 and absf(position.x - hero_pos.x) < 0.55


func collect() -> void:
	collected = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * (2.2 if is_big() else 1.8), 0.12)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.15)
	tw.finished.connect(queue_free)
