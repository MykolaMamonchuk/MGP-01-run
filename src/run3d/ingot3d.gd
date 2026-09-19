## Золотий злиток (GDD v1.4 §3 «Злитки») — те, що лежить на дорозі замість зірочок.
##
## МАЛЮЄ ЙОГО НЕ ВІН САМ. Злиток лишається вузлом із власним місцем, магнітом, збиранням і
## лічильниками — але меша в нього нема: усі злитки кадру малює один MultiMesh у Spawner3D
## (_refresh_ingot_meshes). Кожен окремий MeshInstance3D коштував свого draw call, і на екрані
## їх під шістдесят — заміряно 244 → 298 draw calls рівно тоді, коли злитки вперше з'явились
## на авторському рівні. Логіку це не чіпає зовсім: спавнер бере transform вузла й домальовує
## до нього обертання й погойдування, які раніше жили на дитині-меші.
## Повільно крутиться, погойдується, притягується магнітом, зникає з «дзинь» і золотим вибухом.
## value — скільки монеток дає (2 — на даху транспорту / платформі, 20 — великий злиток «+20»).
## API навмисно такий самий, як у Star3D: Spawner3D працює з ними однаково.
class_name Ingot3D
extends Node3D

## Радіус широкого магніта (пікап): 3 доріжки завширшки — 1,5 доріжки в кожен бік.
const WIDE_LANES := 3.0
const WIDE_REACH := 4.0
## З якого значення злиток вважається «великим» (EDD §2: номінал зрізано 100 → 20,
## тримаємо однаковим зі Spawner3D.BIG_VALUE, інакше великий злиток намалюється дрібним).
const BIG_VALUE := 20

static var _glow_mat: StandardMaterial3D

var collected := false
var value := 1
## Обертання й погойдування — ВЛАСНІ, а не в трансформі вузла: position вузла міряє відстань
## до героя, і хитати його означало б хитати й дальність збирання.
var spin := 0.0
var bob := 0.0
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


## Меш злитка (один на всі однакові) — його бере Spawner3D для свого MultiMesh.
static func mesh_for(big: bool) -> Mesh:
	var kind := "ingot_big" if big else "ingot"
	var m := PropLibrary.mesh(kind)
	if m != null:
		return m
	# нема моделі — воксель, як і раніше; беремо саме меш, вузол тут ні до чого
	var mi := VoxelBuilder.instance(kind)
	return mi.mesh if mi != null else null


## Куди й як намалювати цей злиток: місце вузла плюс власне обертання, погойдування й масштаб.
## Подвійний злиток на даху транспорту — помітніший, як і був.
func visual_transform() -> Transform3D:
	var t := Transform3D.IDENTITY.rotated(Vector3.UP, spin)
	t = t.scaled(scale * (1.25 if value == 2 else 1.0))
	t.origin = position + Vector3(0.0, bob, 0.0)
	return t


## magnet — радіус із профілю (клітинок); wide — пікап «магніт»: тягне з сусідніх доріжок і з більшої відстані.
func tick(delta: float, hero: Node3D, magnet: float, wide: bool = false) -> bool:
	_t += delta
	spin += delta * 1.6                    # повільніше за зірочку — злиток важкий
	bob = sin(_t * 2.6) * 0.05
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
