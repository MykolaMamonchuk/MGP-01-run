## Бібліотека пропсів: підміняє ЗГЕНЕРОВАНИЙ воксель справжньою моделлю там, де вона вже є.
##
## Навіщо. Дерева, каміння, паркани й будівлі досі малюються вокселями — VoxelBuilder збирає
## меш із data/voxels/<kind>.json просто в грі. Це швидко й дешево, але виглядає як кубики.
## Коли для того самого `kind` з'являється справжня модель, її треба вміти підставити, НЕ
## переписуючи ні розкладку рівнів, ні розстановку декору: маркери в levels/ лишаються ті
## самі, `kind` лишається той самий — змінюється тільки те, звідки береться меш.
##
## Як користуватись:
##   1. покласти модель у res://assets/props/<ім'я>.glb;
##   2. дописати рядок у data/props.json;
##   3. усе — Track малює її в тих самих MultiMesh-пачках, Obstacle3D інстансує як вузол.
## Моделі нема або файл не знайдено — мовчки лишається воксель, нічого не ламається.
##
## Формат data/props.json:
##   {"tree": "res://assets/props/tree_oak.glb",
##    "rock": {"path": "res://assets/props/rock_a.glb", "scale": 1.2, "yaw_deg": 90.0},
##    "barrel": ["res://assets/props/barrel.glb", "res://assets/props/barrel_2.glb"]}
##
## Список під одним ключем — це РІЗНІ ТИПИ того самого виду: не бочка й та сама бочка, а
## три несхожі бочки. Розкладка рівнів про них не знає — у маркері як був `barrel`, так і
## лишається.
##
## ОДНА МАПА — ОДИН ТИП. Типи різняться не лише малюнком, а й пропорціями (поручні бувають
## 0,26 і 0,41 м заввишки), тож вибір на кожен екземпляр давав би огорожу, що стрибає
## вгору-вниз, і бочки різної висоти поруч. Різноманіття йде МІЖ рівнями, а не всередині
## одного: у містечку свої бочки, у лісі інші.
##
## Вибір рахуємо від назви мапи, а не тягнемо жеребкування в полі. Тоді він однаковий у
## перешкод і в декору, переживає перебудову світу посеред гри й не залежить від того, що
## намалювалось першим.
class_name PropLibrary
extends RefCounted

const PATH := "res://data/props.json"

static var _map: Dictionary = {}
static var _loaded := false
static var _mesh_cache: Dictionary = {}
static var _world_key := ""


## Підкласти свій набір замість файлу (у тестах). Окремою функцією, а не параметром зі
## значенням null: GDScript виводить тип параметра з дефолта, і `Variant = null` стає bool.
static func use(map: Dictionary) -> void:
	_mesh_cache.clear()
	_map = map.duplicate()
	_loaded = true


## Перечитати data/props.json.
static func reload() -> void:
	_mesh_cache.clear()
	_map = {}
	_loaded = true
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for k in (parsed as Dictionary).keys():
		if not String(k).begins_with("_"):        # _note тощо — коментарі, не пропси
			_map[String(k)] = (parsed as Dictionary)[k]


## Скільки типів у виду. 0 — моделі нема взагалі, малюється воксель.
static func variants(kind: String) -> int:
	if not _loaded:
		reload()
	if not _map.has(kind):
		return 0
	var v = _map[kind]
	if typeof(v) == TYPE_ARRAY:
		return (v as Array).size()
	return 1


## Яку мапу малюємо. Викликає Track.rebuild(); від цього залежить, який тип кожного виду
## піде в цей світ.
static func use_world(key: String) -> void:
	_world_key = key


## Тип моделі для цього виду на поточній мапі. Стале значення, не жеребкування: скільки
## разів не спитай — відповідь та сама, доки не змінилась мапа.
static func pick(kind: String) -> int:
	var n := variants(kind)
	if n <= 1:
		return 0
	return absi(hash(_world_key + "|" + kind)) % n


## СПРАЙТ замість моделі. Ціль — мобільний додаток, а пропс із текстурою 2048×2048 важить
## мегабайти заради кадру, де він займає сотню пікселів. Спрайт коштує 3–6 КБ і малюється
## тим самим MultiMesh, що й модель, тож ні розкладка рівнів, ні пакетне малювання не
## змінюються — міняється лише те, ЩО лежить у шарі.
##
## Формат у data/props.json:
##   "barrel": {"sprite": "res://assets/sprites/barrel_1.png", "height": 0.70}
##   "fence_rail": {"sprite": "…", "height": 0.41, "billboard": false}
##
## billboard (типово true) — дощечка довертається до камери навколо вертикалі. Це правильно
## для окремих предметів: бочка, ящик, кущ виглядають однаково з будь-якого боку. Для того,
## що ТЯГНЕТЬСЯ вздовж чогось (поручні, настил містка), довертання все зіпсує — там false.
static func _sprite_mesh(e: Dictionary) -> Mesh:
	var tex := load(String(e.get("sprite", ""))) as Texture2D
	if tex == null:
		return null
	var h := float(e.get("height", 1.0))
	var quad := QuadMesh.new()
	quad.size = Vector2(h * float(tex.get_width()) / maxf(float(tex.get_height()), 1.0), h)
	# початок унизу, як і в моделей: пропс ставиться на землю, а не тоне в ній наполовину
	quad.center_offset = Vector3(0.0, h * 0.5, 0.0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # світло вже вмальоване в спрайт
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5      # без сортування прозорості — на телефоні це дорого
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if bool(e.get("billboard", true)):
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		# БЕЗ цього Godot скидає масштаб інстанса, і всі пропси стають однакового розміру
		m.billboard_keep_scale = true
	quad.material = m
	return quad


static func _entry(kind: String, variant: int = 0) -> Dictionary:
	if not _loaded:
		reload()
	if not _map.has(kind):
		return {}
	var v = _map[kind]
	if typeof(v) == TYPE_ARRAY:
		var arr := v as Array
		if arr.is_empty():
			return {}
		# номер за межами списку — не помилка: тип міг зникнути з props.json між вибором
		# і малюванням (reload у редакторі). Краще перша модель, ніж порожній екран.
		v = arr[clampi(variant, 0, arr.size() - 1)]
	if typeof(v) == TYPE_STRING:
		return {"path": String(v), "scale": 1.0, "yaw_deg": 0.0}
	if typeof(v) == TYPE_DICTIONARY:
		var d := v as Dictionary
		return {"path": String(d.get("path", "")),
			"sprite": String(d.get("sprite", "")),
			"height": float(d.get("height", 1.0)),
			"billboard": bool(d.get("billboard", true)),
			"scale": float(d.get("scale", 1.0)),
			"yaw_deg": float(d.get("yaw_deg", 0.0))}
	return {}


## Чи є для цього виду справжня модель (і чи файл на місці).
static func has(kind: String, variant: int = 0) -> bool:
	var e := _entry(kind, variant)
	if e.is_empty():
		return false
	var spr := String(e.get("sprite", ""))
	if spr != "":
		return ResourceLoader.exists(spr)
	return String(e["path"]) != "" and ResourceLoader.exists(String(e["path"]))


## Масштаб/поворот, які треба домножити до тих, що вже задані маркером.
static func tweak(kind: String, variant: int = 0) -> Dictionary:
	var e := _entry(kind, variant)
	if e.is_empty():
		return {"scale": 1.0, "yaw_deg": 0.0}
	return {"scale": float(e["scale"]), "yaw_deg": float(e["yaw_deg"])}


## Меш моделі — для MultiMesh-пачок декору (Track._decor_layer). null — моделі нема.
##
## Беремо ПЕРШИЙ MeshInstance3D зі сцени: пропси з Meshy — це один меш з одним матеріалом.
## Матеріал лишається в самому меші, тож MultiMesh малює його без material_override.
static func mesh(kind: String, variant: int = 0) -> Mesh:
	var key := "%s#%d" % [kind, variant]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	if not has(kind, variant):
		return null
	var e := _entry(kind, variant)
	if String(e.get("sprite", "")) != "":
		var q := _sprite_mesh(e)
		_mesh_cache[key] = q
		return q
	var scene := load(String(e["path"])) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate()
	var found := _first_mesh(root)
	root.queue_free()
	_mesh_cache[key] = found
	return found


static func _first_mesh(node: Node) -> Mesh:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		return mi.mesh
	for c in node.get_children():
		var m := _first_mesh(c)
		if m != null:
			return m
	return null


## Готовий MeshInstance3D пропса — той самий вигляд, що й у VoxelBuilder.instance(), лише
## з мешем моделі замість вокселя. null — моделі нема, виклик бере VoxelBuilder.instance()
## сам (шаблон "є модель — беремо її, нема — воксель" повторювався б у десятку місць:
## Tier2Segment, Ingot3D, Critter3D, Star3D, Magpie3D, Dragonfly3D, Pickup3D, Diorama, Hero3D).
##
## palette_override тут нема: він перефарбовує лише воксель (VoxelBuilder.instance), моделі
## завжди йдуть у своєму кольорі — виклик, що передає override у фолбек, сам про це нагадує.
static func node_for(kind: String, variant: int = 0) -> MeshInstance3D:
	var m := mesh(kind, variant)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = m
	return mi
