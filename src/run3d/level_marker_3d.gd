## Авторський маркер рівня (Phase 1 «level-authoring plumbing»): плейсхолдер у сцені
## res://levels/level_XX.tscn. LevelTimeline.extract() читає його дані, коли Run3D завантажує
## рівень; після екстракції авторська сцена звільняється й НЕ додається у живе дерево — дорогу/
## перешкоди все одно малюють Track/Spawner3D через свої MultiMesh-пачки й пул-вузли, як і
## раніше (docs/optimisation/2026-09-07-render-budget.md) — цей вузол сам по собі нічого не рендерить.
## В редакторі ж (Engine.is_editor_hint()) показує прев'ю СПРАВЖНЬОЇ моделі, щоб рівень було
## видно наживо під час розстановки; прев'ю не серіалізується (owner = null) і не існує в грі.
@tool
class_name LevelMarker3D
extends Node3D

## Куди піде запис при екстракції — LevelTimeline розкладає маркери по цих семи масивах.
##
## `pickup` — це ХЕЛПЕР із data/pickups.json (сердечко, магніт, щит), один предмет.
## `gold` — це ЗЛИТКИ, і не по одному, а ФІГУРОЮ: `kind` каже яка (line / climb / arc /
## cluster), `override` — скільки й куди. Інакше цеглинку довелося б засівати трьома
## десятками маркерів поштучно, і жодна людина цього б не редагувала.
##
## Навіщо золото взагалі авторське. Доти воно було єдиним, що лишалось випадковим: перешкоди
## розставляє автор, а монети сипались лінією з 5 у вільній доріжці за КОЖНОЮ групою
## (_spawn_authored_collectibles). Через це золото не могло ні вести дитину («монетки
## показують, куди стрибати»), ні платити за ризик, ні святкувати складний шматок — воно
## завжди лежало там, де й так безпечно, і рівно стільки, скільки груп перешкод. Заміряно
## 21.09.2026: 31 монета на 150 м у першому світі й 55 у восьмому, причому зростання ніхто
## не задумував — воно просто йшло за щільністю перешкод.
@export_enum("decor", "obstacle", "pickup", "gold", "building", "landmark", "wall_near") var role: String = "decor":
	set(v):
		role = v
		_rebuild_preview()

## Ім'я вокселя/пропса — той самий словник, що й world.decor/world.obstacles/world.walls_near
## у data/worlds/*.json (напр. "tree", "stump", "house_terra"; addons/mgp_core/voxel/voxel_builder.gd).
@export var kind: String = "":
	set(v):
		kind = v
		_rebuild_preview()

## ДІЯ замість виду: "jump" / "duck" / "side" — «тут треба перестрибнути», а конкретну модель
## добере СВІТ (Spawner3D._kind_for_action). Порожнє — маркер поводиться як раніше, вид задає
## kind. Навіщо: спільних ВИДІВ перешкод між світами майже нема (Лужок ∩ Ліс — лише xbox), а
## jump/duck/side є в кожному світі, тож чанк, написаний у діях, переживає будь-який біом.
@export var action: String = "":
	set(v):
		action = v
		_rebuild_preview()

## ЯК ПЕРЕШКОДА РУХАЄТЬСЯ — окрема вісь від дії, і саме її бракувало для «цікавих» патернів.
## Порожнє — байдуже (будь-яка, звичайно нерухома). "roll" — котиться НАЗУСТРІЧ героєві
## (anim "roll": бочка, колода, м'яч — Obstacle3D.ROLL_SPEED поверх руху світу). "cross" —
## перебігає доріжки впоперек (moves: їжачок, крабик, песик). "ride" — кузов, на дах якого
## можна заскочити й бігти по ньому (shape "vehicle": віз із сіном, човен, автобус).
##
## Навіщо саме вісь, а не назва виду: спільних ВИДІВ між світами майже нема, а «щось
## котиться» є тепер у кожному. Фраза, написана рухом, переживає будь-який біом — так само,
## як дія jump/duck/side переживає його вже зараз.
## Порожній рядок @export_enum першим елементом не приймає, тож звичайне поле: "", "roll",
## "cross", "ride". Сторож на відомі значення — tests/test_phrases.gd.
@export var motion: String = ""

## Доріжка для obstacle/pickup (як Spawner3D.lane: -max_lane()..max_lane()); decor/building
## ігнорують lane і кладуться за власною position (x_m/y_m — див. LevelTimeline).
@export var lane: int = 0:
	set(v):
		lane = v
		_rebuild_preview()

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


## Кольори-заглушки за роллю — щоб маркер із невідомим kind усе одно було ВИДНО. Раніше він
## був невидимий, і чанк у редакторі виглядав порожнім навіть там, де маркери стояли.
const ROLE_COLORS := {
	"decor": Color(0.35, 0.75, 0.35),
	"obstacle": Color(0.95, 0.35, 0.30),
	"pickup": Color(1.00, 0.85, 0.25),
	"gold": Color(1.00, 0.70, 0.10),
	"building": Color(0.60, 0.55, 0.85),
	"landmark": Color(0.30, 0.70, 0.95),
	"wall_near": Color(0.55, 0.45, 0.35),
}
## Ширина доріжки — та сама, що Hero3D.LANE_W.
const LANE_W := 1.0


## Перебудувати прев'ю. Джерело шукаємо в трьох місцях по черзі:
##   1. справжня модель із data/props.json (PropLibrary) — саме її й побачить гравець;
##   2. воксель data/voxels/<kind>.json — для видів, які ще не отримали моделі;
##   3. кольорова коробка за роллю — коли не знайшлось нічого.
## Третій крок принциповий: раніше маркер без вокселя не малював НІЧОГО, і автор рівня
## дивився в порожню сцену, не розуміючи, чи там щось є. Заглушка каже «тут маркер, і його
## kind невідомий» — це помилка, яку видно.
func _rebuild_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_clear_preview()
	var mi := _preview_node()
	if mi == null:
		return
	mi.rotation.y = deg_to_rad(yaw_deg)
	mi.scale = Vector3.ONE * scale_mul
	# Перешкоди й пікапи стоять на ДОРІЖЦІ, а не за власним x: саме так їх ставить Spawner3D.
	# Без цього зсуву в редакторі вони всі купчились би по осі дороги.
	if role == "obstacle" or role == "pickup" or role == "gold":
		mi.position.x = float(lane) * LANE_W
	add_child(mi)
	mi.owner = null   # прев'ю ніколи не йде в .tscn і не існує в запущеній грі
	_preview = mi


func _preview_node() -> Node3D:
	var name_ := model_kind(role, _preview_kind())
	if name_ == "":
		return _placeholder()
	if PropLibrary.has(name_):
		var node := PropLibrary.node_for(name_)
		if node != null:
			return node
	if FileAccess.file_exists("res://data/voxels/%s.json" % name_):
		return VoxelBuilder.instance(name_, override)
	return _placeholder()


## Ім'я МОДЕЛІ для цього маркера. Для декору воно збігається з kind, а перешкода зветься
## по-своєму («xbox», «wagon», «wind») і бере модель через поле "voxel" свого опису в
## data/worlds/*.json. Без цього кроку кожна перешкода малювалась би заглушкою, хоч модель
## у неї є — і автор рівня бачив би кольорові коробки замість рівня.
static func model_kind(role_: String, kind_: String) -> String:
	if kind_ == "":
		return ""
	if role_ != "obstacle":
		return kind_
	if _obstacle_models.is_empty():
		_load_obstacle_models()
	return String(_obstacle_models.get(kind_, kind_))


static var _obstacle_models: Dictionary = {}


static func _load_obstacle_models() -> void:
	var dir := DirAccess.open("res://data/worlds")
	if dir == null:
		return
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var f := FileAccess.open("res://data/worlds/%s" % file, FileAccess.READ)
		if f == null:
			continue
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var obstacles = (parsed as Dictionary).get("obstacles", {})
		if typeof(obstacles) != TYPE_DICTIONARY:
			continue
		for k in (obstacles as Dictionary).keys():
			var def = (obstacles as Dictionary)[k]
			if typeof(def) == TYPE_DICTIONARY and (def as Dictionary).has("voxel"):
				_obstacle_models[k] = (def as Dictionary)["voxel"]


## Що показувати в редакторі. Для маркера-дії (kind порожній, action заданий) беремо
## ПРЕДСТАВНИКА цієї дії з першого-ліпшого світу — справжню перешкоду з даних, а не заглушку.
## Чому саме так, а не кольорова табличка з написом: автор розставляє маркери оком, і йому
## треба бачити ГАБАРИТ і СИЛУЕТ дії — «перестрибнути» це низька колода, «ухилитись» —
## висока рама над головою. Будь-який представник дії має потрібний силует, бо саме силует
## і робить дію дією. Що в грі стане іншою моделлю того ж класу — нормально й очікувано.
func _preview_kind() -> String:
	if kind != "":
		return kind
	if role == "obstacle" and action != "":
		return sample_kind_for_action(action)
	return ""


## Перший-ліпший вид із заданою дією по всіх світах. Файли перебираємо ВІДСОРТОВАНИМИ, щоб
## прев'ю не стрибало між запусками редактора (DirAccess.get_files() порядку не обіцяє).
static func sample_kind_for_action(action_: String) -> String:
	if action_ == "":
		return ""
	if _action_samples.is_empty():
		_load_action_samples()
	return String(_action_samples.get(action_, ""))


static var _action_samples: Dictionary = {}


static func _load_action_samples() -> void:
	var dir := DirAccess.open("res://data/worlds")
	if dir == null:
		return
	var files := Array(dir.get_files())
	files.sort()
	for file in files:
		if not String(file).ends_with(".json"):
			continue
		var f := FileAccess.open("res://data/worlds/%s" % file, FileAccess.READ)
		if f == null:
			continue
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var obstacles = (parsed as Dictionary).get("obstacles", {})
		if typeof(obstacles) != TYPE_DICTIONARY:
			continue
		var kinds := Array((obstacles as Dictionary).keys())
		kinds.sort()
		for k in kinds:
			var def = (obstacles as Dictionary)[k]
			if typeof(def) != TYPE_DICTIONARY:
				continue
			# Ті самі два винятки, що й у Spawner3D._kind_for_action(): X-ящик кидає лише сорока,
			# а транспорт — не перешкода, а кузов із рампою. Показувати автору те, чого гра
			# за цим маркером не поставить, гірше за відсутність прев'ю.
			if String(k) == "xbox" or String((def as Dictionary).get("shape", "")) == "vehicle":
				continue
			var a := String((def as Dictionary).get("action", "any"))
			if not _action_samples.has(a):
				_action_samples[a] = String(k)


## Напівпрозорий кубик кольору ролі — «тут маркер, моделі нема».
func _placeholder() -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.5, 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.position.y = 0.25
	var m := StandardMaterial3D.new()
	m.albedo_color = ROLE_COLORS.get(role, Color.MAGENTA)
	m.albedo_color.a = 0.75
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	return mi
