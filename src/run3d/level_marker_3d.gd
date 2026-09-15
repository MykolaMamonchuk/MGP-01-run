## Авторський маркер рівня (Phase 1 «level-authoring plumbing»): плейсхолдер у сцені
## res://levels/level_XX.tscn. LevelTimeline.extract() читає його дані, коли Run3D завантажує
## рівень; після екстракції авторська сцена звільняється й НЕ додається у живе дерево — дорогу/
## перешкоди все одно малюють Track/Spawner3D через свої MultiMesh-пачки й пул-вузли, як і
## раніше (docs/optimisation/2026-09-07-render-budget.md) — цей вузол сам по собі нічого не рендерить.
## В редакторі ж (Engine.is_editor_hint()) показує прев'ю вокселя, щоб рівень було видно наживо
## під час розстановки; прев'ю не серіалізується (owner = null) і не існує в грі.
@tool
class_name LevelMarker3D
extends Node3D

## Куди піде запис при екстракції — LevelTimeline розкладає маркери по цих шести масивах.
@export_enum("decor", "obstacle", "pickup", "building", "landmark", "wall_near") var role: String = "decor":
	set(v):
		role = v
		_rebuild_preview()

## Ім'я вокселя/пропса — той самий словник, що й world.decor/world.obstacles/world.walls_near
## у data/worlds/*.json (напр. "tree", "stump", "house_terra"; addons/mgp_core/voxel/voxel_builder.gd).
@export var kind: String = "":
	set(v):
		kind = v
		_rebuild_preview()

## Доріжка для obstacle/pickup (як Spawner3D.lane: -max_lane()..max_lane()); decor/building
## ігнорують lane і кладуться за власною position (x_m/y_m — див. LevelTimeline).
@export var lane: int = 0

## Параметри вокселя — те саме, що palette_override у VoxelBuilder.instance()/_decor_layer()
## (напр. {"p": "pink"} для кольору квітки).
@export var override: Dictionary = {}:
	set(v):
		override = v
		_rebuild_preview()

## Поворот навколо Y у градусах (в інспекторі зручніші градуси, ніж радіани рушія).
@export var yaw_deg: float = 0.0:
	set(v):
		yaw_deg = v
		_rebuild_preview()

## Масштаб прев'ю/декору. Назва не "scale" — Node3D уже має вбудований scale: Vector3,
## однойменне поле іншого типу конфліктувало б із ним.
@export var scale_mul: float = 1.0:
	set(v):
		scale_mul = v
		_rebuild_preview()

var _preview: Node3D = null


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_preview()


func _exit_tree() -> void:
	_clear_preview()


func _clear_preview() -> void:
	if _preview != null and is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null


## Перебудувати прев'ю: старе прибираємо, нове ставимо лише якщо воксель існує (інакше
## VoxelBuilder намалював би рожевий кубик-заглушку прямо в редакторі на кожному порожньому маркері).
func _rebuild_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_clear_preview()
	if kind == "" or not FileAccess.file_exists("res://data/voxels/%s.json" % kind):
		return
	var mi := VoxelBuilder.instance(kind, override)
	mi.rotation.y = deg_to_rad(yaw_deg)
	mi.scale = Vector3.ONE * scale_mul
	add_child(mi)
	mi.owner = null   # прев'ю ніколи не йде в .tscn і не існує в запущеній грі
	_preview = mi
