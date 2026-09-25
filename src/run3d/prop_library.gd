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
static var _scene_cache: Dictionary = {}
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
	# Розмір беремо В МЕТРАХ із самого запису, а не виводимо з пропорцій картинки: спрайт
	# обрізано по силуету, тож його пропорції вже не ті, що в моделі. Для поручнів, які
	# стикуються ланка в ланку, похибка в сантиметр — це щілина в кадрі.
	var h := float(e.get("height", 1.0))
	var w := float(e.get("width", 0.0))
	if w <= 0.0:
		var cells := maxi(int(e.get("frames", 1)), 1)
		w = h * (float(tex.get_width()) / float(cells)) / maxf(float(tex.get_height()), 1.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	# початок унизу, як і в моделей: пропс ставиться на землю, а не тоне в ній наполовину
	quad.center_offset = Vector3(0.0, h * 0.5, 0.0)
	# frames > 1 — спрайт знятий з КІЛЬКОХ боків (атлас у рядок). Тоді матеріал не звичайний,
	# а шейдерний: він довертає дощечку до камери й бере з атласу той бік, під яким на
	# предмет дивляться саме зараз. Звичайний білборд показував би одну й ту саму картинку
	# з усіх напрямків, і кущ «обертався» б разом з оком.
	var frames := int(e.get("frames", 1))
	if frames > 1:
		var sm := ShaderMaterial.new()
		sm.shader = load("res://src/run3d/impostor.gdshader")
		sm.set_shader_parameter("atlas", tex)
		sm.set_shader_parameter("frames", frames)
		quad.material = sm
		return quad

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
			"width": float(d.get("width", 0.0)),
			"billboard": bool(d.get("billboard", true)),
			"frames": int(d.get("frames", 1)),
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
	var found := _drop_normal_maps(_first_mesh(root))
	root.queue_free()
	_mesh_cache[key] = found
	return found


## ЦІЛА СЦЕНА моделі (зі скелетом) — для скелетних тварин (Obstacle3D, поле "rig"). Кешується,
## як і меш: без кешу кожна поява гуски читала б .glb з диска просто в кадрі бігу (рецензія
## 26.09: 0,35-0,5 мс на Маку на кожну, на телефоні — кілька). Прогріває Spawner3D.
static func scene(path: String) -> PackedScene:
	if _scene_cache.has(path):
		return _scene_cache[path]
	if path == "" or not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	_scene_cache[path] = ps
	return ps


## Меш із КОНКРЕТНОГО файлу, повз каталог видів. Потрібно лише заміру (tools/lod/decimate.py):
## підмінити модель шару на спрощену, не чіпаючи ні props.json, ні розкладок рівнів — інакше
## «той самий будинок, менше вершин» не поставити в те саме місце.
static func mesh_at(path: String) -> Mesh:
	if _mesh_cache.has(path):
		return _mesh_cache[path]
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate()
	var found := _drop_normal_maps(_first_mesh(root))
	root.queue_free()
	_mesh_cache[path] = found
	return found


## Меш СПЛОЩЕНОГО пропса (assets/flat/) — той самий вигляд, але одна поверхня й один
## спільний матеріал замість двох-семи однотонних. Робить tools/atlas/flatten.py; текстурні
## пропси там відсутні, для них повертається null і викликач лишає звичайний меш.
static func flat_mesh(kind: String, variant: int = 0) -> Mesh:
	if not has(kind, variant):
		return null
	var e := _entry(kind, variant)
	var orig := String(e.get("path", ""))
	if orig == "":
		return null
	var path := "res://assets/flat/" + orig.get_file()
	if not ResourceLoader.exists(path):
		return null
	return mesh_at(path)


## КАРТИ НОРМАЛЕЙ У ПРОПСАХ ОТОЧЕННЯ ВИМКНЕНО. Заміряно на Redmi 8A двічі, сходами масштабу
## рендера: 36 одиниць показника зі 194, тобто 19% усієї ціни декору. Для порівняння: карти
## шорсткості, металу й затінення коштують НУЛЬ, а зрізання 94% вершин із моделі — теж нуль.
##
## Чому це не псує вигляд. Стиль гри — стилізований low-poly з пласкими кольорами; 38 із 70
## пропсів узагалі не мають текстур, а решта дивиться на гравця з десяти-тридцяти метрів на
## екрані телефона. Знімки до/після: docs/optimisation/shots/2026-09-22-normals-on|off.png.
##
## Чому ЗАВЖДИ, а не за рівнем якості. Видимого внеску немає в жодному стані, тож розгалуження
## дало б різний вигляд на різних телефонах без жодної користі. Герой і персонажі сюди не
## потрапляють — вони йдуть повз цю бібліотеку.
##
## Побічний виграш: 37 карт нормалей важать 17 МБ із 51 МБ усіх текстур збірки. Прибрати їх
## із самих моделей (а не лише з матеріалів) — окрема робота, і вона зніме цю третину.
static func _drop_normal_maps(m: Mesh) -> Mesh:
	if m == null:
		return m
	for si in range(m.get_surface_count()):
		var bm := m.surface_get_material(si) as BaseMaterial3D
		if bm == null:
			continue
		if bm.normal_enabled:
			bm.normal_enabled = false
			bm.normal_texture = null
		# ВІДСІКАННЯ ЗАДНІХ ГРАНЕЙ. Усі 160 поверхонь бібліотеки приїхали ДВОСТОРОННІМИ
		# (cull_mode = CULL_DISABLED): кожен закритий об'єкт малював і лицьову, і зворотну
		# сторону, а зворотну ніколи не видно — її затуляє сам об'єкт. Платили ми за це на
		# кожен піксель, тобто найдорожчою статтею.
		#
		# Заміряно на Redmi 8A сходами масштабу: 29,1 одиниці зі 157 ціни декору (19%),
		# і 5,6 мс на рідній роздільності. Знімок до/після — світ цілий, пласкі пропси
		# (квіти, гриби) не постраждали: shots/2026-09-23-cull-*.png.
		#
		# Ефект НЕЗАЛЕЖНИЙ від вимкнення освітлення: 29,1 + 33,5 поодинці, 63,6 разом.
		if bm.cull_mode == BaseMaterial3D.CULL_DISABLED:
			bm.cull_mode = BaseMaterial3D.CULL_BACK
	return m


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
