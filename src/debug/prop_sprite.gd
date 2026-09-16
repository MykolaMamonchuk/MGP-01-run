## Зрізати пропс у 2D: відрендерити модель у маленький спрайт із прозорістю.
##
## Навіщо. Пакет гри важить 296 МБ, і це майже цілком моделі з текстурами 2048×2048. Для
## вебу це непридатно, та й на телефоні з такою вагою нічого не вийде. Але пропс у раннері
## проїжджає повз за секунду й займає на екрані сотню пікселів — уся ця геометрія й
## текстури живуть заради кадру, який можна намалювати картинкою на кілька кілобайтів.
##
## Рендеримо САМЕ В ГРІ, а не в Blender: тоді спрайт гарантовано має те саме освітлення,
## матеріал і кут, що й модель, яку він заміняє. Знімок із чужого рушія довелось би
## підганяти на око.
##
## Запуск:
##     PROP=res://assets/props/barrel_1.glb OUT=/tmp/barrel.png SIZE=128 \
##         godot res://src/debug/prop_sprite.tscn
##     ANGLES=8 OUT=/tmp/barrel        # смуга з 8 боків: barrel.png шириною SIZE×8
extends Node3D

var _done := false
var _frames := 0


func _ready() -> void:
	get_viewport().transparent_bg = true
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS      # прозоре тло замість кольору
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.85
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 145.0, 0.0)
	sun.light_energy = 1.05
	add_child(sun)

	var path := OS.get_environment("PROP")
	var scene := load(path) as PackedScene if path != "" else null
	if scene == null:
		push_error("prop_sprite: задай PROP=res://…")
		get_tree().quit()
		return
	var inst := scene.instantiate() as Node3D
	add_child(inst)
	_subject = inst

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(cam)
	cam.current = true
	_cam = cam


var _subject: Node3D
var _cam: Camera3D


func _num(key: String, fallback: int) -> int:
	var v := OS.get_environment(key)
	return int(v) if v != "" else fallback


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 8 or _done:
		return
	_done = true
	var size := _num("SIZE", 128)
	var angles := _num("ANGLES", 1)
	# габарит моделі рахуємо з її AABB: спрайт має щільно облягати силует, інакше половина
	# пікселів піде на порожнечу, а саме вони й важать
	var aabb := _bounds(_subject)
	var span: float = maxf(maxf(aabb.size.x, aabb.size.y), aabb.size.z) * 1.08
	_cam.size = span
	var centre := aabb.position + aabb.size * 0.5
	var strip := Image.create(size * angles, size, false, Image.FORMAT_RGBA8)
	for i in angles:
		_subject.rotation.y = TAU * float(i) / float(angles)
		# Знімаємо СТРОГО ЗБОКУ, без нахилу. Це не дрібниця: дощечка в грі стоїть вертикально,
		# і ігрова камера сама дивиться на неї згори під 25°. Якщо зняти пропс уже під цим
		# кутом, скорочення накладеться ДВІЧІ — і бочка виходить приплюснутою. Ціна: на
		# спрайті не видно кришки, але пласка дощечка її й не показала б.
		_cam.position = centre + Vector3(0.0, 0.0, 1.0) * span * 3.0
		_cam.look_at(centre, Vector3.UP)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var side: int = mini(img.get_width(), img.get_height())
		img = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
		img.resize(size, size, Image.INTERPOLATE_LANCZOS)
		img.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(img, Rect2i(0, 0, size, size), Vector2i(size * i, 0))
	var out := OS.get_environment("OUT")
	if out != "":
		strip.save_png(out)
		# Скільки МЕТРІВ покриває картинка. Без цього числа розмір дощечки доводилось би
		# виводити з пропорцій обрізаного файлу, а це вже не той самий розмір, що в моделі:
		# для поручнів, які стикуються ланка в ланку, похибка в сантиметр дає щілину в кадрі.
		var meta := FileAccess.open(out.get_basename() + ".json", FileAccess.WRITE)
		if meta != null:
			meta.store_string(JSON.stringify({"span_m": span, "size_px": size}))
			meta.close()
		print("спрайт: ", out, "  ", strip.get_width(), "×", strip.get_height())
	get_tree().quit()


func _bounds(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for c in _all(node):
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		# AABB у СВІТОВИХ координатах: get_aabb() дає локальний, а імпорт glTF може лишити
		# на вузлах свій поворот. Через це габарит виходив на кілька відсотків меншим за
		# справжній, і поручні, яким треба рівно метр, отримували 1,046 — тобто щілину.
		var a := mi.global_transform * mi.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


func _all(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out += _all(c)
	return out
