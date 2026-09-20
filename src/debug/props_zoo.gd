## Звіринець пропсів: УСІ моделі гри поруч, сіткою на землі, з підписами. У грі не вживається.
##
## Навіщо саме СЦЕНА, а не аркуш-знімок. Моделі й так видно в редакторі поштучно — у панелі
## FileSystem подвійний клік показує будь-який `.glb`. Чого не було — подивитись на всі разом і
## обійти їх камерою: чи тримаються одного стилю, чи не приїхала якась удвічі більшою за
## сусідів, чи не порожня в неї спина. Знімок на це відповідає гірше за живу сцену, яку можна
## покрутити.
##
## `@tool` тут не для краси: сітка будується ПРЯМО В РЕДАКТОРІ, щойно сцену відкрито. Без цього
## у вкладці був би порожній вузол, і дивитись довелось би лише через запуск.
##
##     відкрити src/debug/props_zoo.tscn у редакторі — і крутити мишею
##     godot res://src/debug/props_zoo.tscn                  запустити
##     OUT=/tmp/zoo.png godot res://src/debug/props_zoo.tscn знімок і вихід
##
## Щоб дивитись НЕ ВСЕ, а одну родину: поле `only` в інспекторі («house_terra») або
## ZOO=house_terra у командному рядку. Тоді сітка коротка, а камера стоїть близько — саме те,
## що треба, коли оцінюєш якість після перепікання.
##
## Бере САМЕ ТЕ, що бачить гра: список із data/props.json через PropLibrary, з усіма
## варіантами. Модель, якої нема на диску, показується червоним кубиком — так одразу видно
## биті записи, а не мовчазну порожнечу.
@tool
extends Node3D

## Показати лише ті види, у назві яких є цей рядок. Порожньо — усі.
##
## Навіщо. Сітка з усіх моделей добра, щоб ловити «щось приїхало вдвічі більшим», але щоб
## ОЦІНИТИ ЯКІСТЬ однієї родини (наприклад дев'яти будинків після перепікання), решта
## шістдесят заважає: вони розганяють сітку, і камера стоїть далеко.
##
## Поле редаговане просто в інспекторі — вписав «house_terra», і сцена перебудувалась.
@export var only: String = "":
	set(value):
		only = value
		if is_inside_tree():
			_build()

## Крок сітки в метрах і скільки моделей у рядку. Крок навмисно більший за найбільшу модель
## (будинок ~2.3 м), щоб сусіди не налазили одне на одного.
const STEP := 3.0
const COLS := 8
## Підпис висить трохи вище за найвищу модель.
const LABEL_Y := 2.8


func _ready() -> void:
	_build()


func _build() -> void:
	for c in get_children():
		c.free()
	var kinds := _kinds()
	var i := 0
	for entry in kinds:
		var kind: String = entry["kind"]
		var variant: int = entry["variant"]
		var cols := _cols(kinds.size())
		var col := i % cols
		var row := i / cols
		var at := Vector3((float(col) - float(cols - 1) * 0.5) * STEP, 0.0, -float(row) * STEP)
		_place(kind, variant, at, entry["label"])
		i += 1
	_ground(kinds.size())
	_light()
	# Камера потрібна лише ЗАПУЩЕНІЙ сцені: у редакторі дивляться своєю, і зайва камера там
	# тільки б заважала рамкою в кутку.
	if not Engine.is_editor_hint():
		_camera(kinds.size())
		if OS.has_environment("OUT"):
			_shoot(OS.get_environment("OUT"))


## Усі види з data/props.json разом з варіантами: список означає кілька РІЗНИХ моделей одного
## виду, і дивитись треба на кожну.
func _kinds() -> Array:
	var out: Array = []
	var f := FileAccess.open("res://data/props.json", FileAccess.READ)
	if f == null:
		return out
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	var names: Array = []
	for key in (parsed as Dictionary).keys():
		if not String(key).begins_with("_"):     # ключі з підкресленням — коментарі, не пропси
			names.append(String(key))
	names.sort()
	# ZOO=house_terra — те саме, що поле `only`, але для знімка з командного рядка.
	var want := only
	if want == "" and OS.has_environment("ZOO"):
		want = OS.get_environment("ZOO")
	if want != "":
		var kept: Array = []
		for kind in names:
			if String(kind).contains(want):
				kept.append(kind)
		names = kept
	for kind in names:
		var n := maxi(1, PropLibrary.variants(String(kind)))
		for v in n:
			out.append({
				"kind": String(kind), "variant": v,
				"label": String(kind) if n == 1 else "%s · %d" % [kind, v + 1],
			})
	return out


func _place(kind: String, variant: int, at: Vector3, label: String) -> void:
	var holder := Node3D.new()
	holder.name = label.replace(" · ", "_")
	holder.position = at
	add_child(holder)
	var mi := PropLibrary.node_for(kind, variant)
	if mi == null:
		# Не мовчати: порожнє місце в сітці читалось би як «моделі просто нема в списку».
		mi = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.4, 0.4, 0.4)
		mi.mesh = box
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.15, 0.15)
		mi.material_override = m
		mi.position.y = 0.2
	holder.add_child(mi)
	var text := Label3D.new()
	text.text = label
	text.position = Vector3(0.0, LABEL_Y, 0.0)
	text.pixel_size = 0.0075
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.modulate = Color(0.1, 0.1, 0.1)
	holder.add_child(text)


## Скільки стовпців сітка ЗАЙМАЄ насправді. Коли фільтр лишив три моделі, тримати вісім
## стовпців означає малювати п'ять порожніх — і камера тоді відлітає так, що моделей не
## роздивитись. Саме через це фільтр був би марний.
func _cols(count: int) -> int:
	return maxi(1, mini(COLS, count))


func _ground(count: int) -> void:
	var cols := _cols(count)
	var rows := int(ceil(float(count) / float(cols)))
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(float(cols + 1) * STEP, float(rows + 1) * STEP)
	mi.mesh = plane
	mi.position = Vector3(0.0, -0.01, -float(rows - 1) * STEP * 0.5)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.74, 0.45)
	mi.material_override = m
	add_child(mi)


func _light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.72, 0.85)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.77, 0.82)
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)


## Кадр мусить умістити сітку ЦІЛКОМ — інакше знімок бреше про те, скільки в грі моделей.
## Кут крутий (−58°) навмисно: чим положистіша камера, тим сильніше підписи налазять на ряд
## позаду, і читати їх стає нічим.
const CAM_PITCH := -58.0


func _camera(count: int) -> void:
	var cols := _cols(count)
	var rows := int(ceil(float(count) / float(cols)))
	var centre := -float(rows - 1) * STEP * 0.5
	var wide := float(cols + 1) * STEP
	# Глибина сітки в кадрі стискається косинусом нахилу, плюс місце під підписи.
	var deep := float(rows + 1) * STEP * cos(deg_to_rad(CAM_PITCH)) + LABEL_Y * 2.0
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = maxf(deep, wide * 9.0 / 16.0) * 1.12   # запас, щоб крайні ряди не зрізало
	cam.position = Vector3(0.0, 40.0, centre + 26.0)
	cam.rotation_degrees = Vector3(CAM_PITCH, 0.0, 0.0)
	cam.far = 300.0
	add_child(cam)
	cam.make_current()


func _shoot(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("знімок звіринця: %s" % path)
	get_tree().quit()
