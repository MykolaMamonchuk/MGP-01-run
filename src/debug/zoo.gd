## Звіринець: УСІ герої в ряд, живі, з однаковими клавішами. У грі не використовується.
##
## Навіщо. Досі, щоб глянути на звірят, треба було або відкривати hero_lab і перемикати їх
## по одному випадайкою, або просити знімки. Коли правка стосується ВСІХ (анімація, кліпання,
## танець), зручніше бачити їх поруч: одразу видно, у кого щось поїхало.
##
## Запуск:
##     godot res://src/debug/zoo.tscn                 # усі, хто має модель
##     ZOO=all godot res://src/debug/zoo.tscn         # ще й воксельні
##     ZOO=lys,olen godot res://src/debug/zoo.tscn    # лише ці
##     OUT=/tmp/zoo.png godot res://src/debug/zoo.tscn # знімок і вихід (для звіту/порівняння)
##
## Клавіші — ті самі, що в hero_lab, але діють НА ВСІХ одразу:
##   1..9 — стани (7 танець і 8 привітання йдуть як у грі, зі своїм виразом обличчя)
##   B кліпнути · N підморгнути · J по черзі · G погляд убік · H щасливий
##   M рот · C жувати · L облизнутись · E з'їсти · U удар
##   Мишею тягнути — обертати, колесо — наблизити, Esc — вийти
extends Node3D

const SPACING := 1.35          ## відстань між звірятами, м
const ORBIT_SPEED := 0.007
const ZOOM_MIN := 2.0
const ZOOM_MAX := 14.0

var _heroes: Array[Hero3D] = []
var _cam: Camera3D
var _pivot: Node3D
## Стартовий ракурс — МОРДА. Герой дивиться в −Z, тож камера має стояти з боку −Z (yaw = PI):
## з нуля сцена відкривалась потилицею, і першим рухом щоразу був розворот.
## Нахил трохи згори: строго горизонтальна камера дивиться підлозі в ребро, і звірята
## виглядають підвішеними в небі.
var _orbit := Vector2(PI, 0.20)
var _dist := 6.0
var _dragging := false
var _status: Label
var _mouth_open := false
var _gaze_side := 0.0
var _frames := 0
var _shot_done := false


func _ready() -> void:
	_build_world()
	_spawn_heroes()
	_build_camera()
	_build_ui()


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.44, 0.63, 0.78)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.75
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 150.0, 0.0)
	sun.light_energy = 1.15
	add_child(sun)

	# підлога, щоб звірята не висіли в порожнечі й було видно тіні
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	floor_mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.53, 0.70, 0.45)
	mat.roughness = 1.0
	floor_mi.material_override = mat
	add_child(floor_mi)


## Кого показувати: типово всі, хто має .glb (воксельних видно й так у voxel_preview).
func _wanted_ids() -> Array:
	var want := OS.get_environment("ZOO")
	var defs := Hero3D.defs()
	var ids := HeroSelect.order_ids(defs)
	if want != "" and want != "all":
		var out: Array = []
		for part in want.split(","):
			var id := part.strip_edges()
			if defs.has(id):
				out.append(id)
		return out
	var kept: Array = []
	for id in ids:
		var def: Dictionary = defs.get(id, {})
		var rig := String(def.get("rig", ""))
		var has_model := rig != "" and ResourceLoader.exists("res://assets/models/%s.glb" % rig)
		if want == "all" or has_model:
			kept.append(id)
	return kept


func _spawn_heroes() -> void:
	var ids := _wanted_ids()
	var n := ids.size()
	for i in n:
		var id := String(ids[i])
		var def := Hero3D.resolve_def(Hero3D.defs(), id)
		var h := Hero3D.new()
		add_child(h)
		h.set_hero(id, Palette.of(def.get("color"), Palette.HERO_DEFAULT),
			String(def.get("feature", "fox")))
		h.ground_y = 0.0
		# рівно в ряд: середина ряду — в нулі, щоб камера дивилась у центр
		h.position = Vector3((float(i) - float(n - 1) * 0.5) * SPACING, 0.0, 0.0)
		h.x_target = h.position.x        # інакше герой поїде до нуля й ряд злипнеться
		_heroes.append(h)
		_add_name_plate(h, String(def.get("name_uk", id)))


## Підпис під кожним — інакше на п'ятьох звірятах легко забути, хто є хто.
func _add_name_plate(h: Hero3D, text: String) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 96
	lbl.pixel_size = 0.0018
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.modulate = Color(1, 1, 1)
	lbl.outline_size = 28
	lbl.outline_modulate = Color(0, 0, 0, 0.75)
	lbl.position = Vector3(0.0, -0.18, 0.0)
	h.add_child(lbl)


func _build_camera() -> void:
	_pivot = Node3D.new()
	_pivot.position = Vector3(0.0, 0.48, 0.0)
	add_child(_pivot)
	_cam = Camera3D.new()
	_cam.fov = 48.0
	_pivot.add_child(_cam)
	# Кадр має вмістити шеренгу і ВШИР, і ВВИСЬ. Спершу рахувалась лише ширина — на одному
	# звіряті виходило 1,1 м, і голову зрізало верхнім краєм.
	var by_width := 1.1 + float(maxi(_heroes.size() - 1, 0)) * SPACING * 0.62
	_dist = clampf(maxf(2.4, by_width), ZOOM_MIN, ZOOM_MAX)
	_apply_camera()
	_cam.current = true


func _apply_camera() -> void:
	var yaw := _orbit.x
	var pitch := clampf(_orbit.y, -0.5, 1.0)
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * _dist
	_cam.position = off
	_cam.look_at_from_position(off, Vector3.ZERO, Vector3.UP)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(14, 10)
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 6)
	_status.text = "%d звірят · 1..9 стани · B кліп · N підморгнути · J по черзі · G погляд · H радість · M/C/L/E рот · U удар" % _heroes.size()
	layer.add_child(_status)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist = clampf(_dist - 0.4, ZOOM_MIN, ZOOM_MAX)
			_apply_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist = clampf(_dist + 0.4, ZOOM_MIN, ZOOM_MAX)
			_apply_camera()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_orbit.x -= mm.relative.x * ORBIT_SPEED
		_orbit.y += mm.relative.y * ORBIT_SPEED
		_apply_camera()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		_key((event as InputEventKey).keycode)


func _key(code: int) -> void:
	if code == KEY_ESCAPE:
		get_tree().quit()
		return
	if code >= KEY_1 and code <= KEY_9:
		var picked: Hero3D.Anim = ([Hero3D.Anim.IDLE, Hero3D.Anim.RUN, Hero3D.Anim.SPRINT,
			Hero3D.Anim.LIMP, Hero3D.Anim.ROCKET, Hero3D.Anim.CHARGE, Hero3D.Anim.DANCE,
			Hero3D.Anim.WAVE, Hero3D.Anim.HIT] as Array)[code - KEY_1]
		for h in _heroes:
			# танець і привітання — власними методами: у них свій таймер і свій вираз
			# обличчя, а через preview_pose() Hero3D вважає це «лише позою» й радість гасить
			if picked == Hero3D.Anim.DANCE:
				h.dance()
			elif picked == Hero3D.Anim.WAVE:
				h.wave_hello()
			else:
				h.preview_pose(picked)
		_say("стан %d" % (code - KEY_1 + 1))
		return

	match code:
		KEY_B:
			_each(func(h: Hero3D) -> void: h.call("_blink"))
			_say("кліпання")
		KEY_N:
			_each(func(h: Hero3D) -> void: h.call("_blink", Hero3D.BlinkKind.WINK, 1.0))
			_say("підморгування")
		KEY_J:
			_each(func(h: Hero3D) -> void: h.call("_blink", Hero3D.BlinkKind.SEQUENCE, 1.0))
			_say("кліпання по черзі")
		KEY_G:
			_gaze_side = -1.0 if _gaze_side >= 0.0 else 1.0
			# погляд просимо не напряму, а як у грі: герой переїжджає, і очі йдуть за рухом
			for h in _heroes:
				h.x_target = h.position.x + _gaze_side * 0.6
			_say("погляд %s" % ("ліворуч" if _gaze_side < 0.0 else "праворуч"))
		KEY_H:
			_each(func(h: Hero3D) -> void: h.call("_happy", 1.5))
			_say("радість")
		KEY_M:
			_mouth_open = not _mouth_open
			var opening := _mouth_open
			_each(func(h: Hero3D) -> void:
				if h._mouth3d != null:
					if opening:
						h._mouth3d.open()
					else:
						h._mouth3d.close())
			_say("рот %s" % ("відкритий" if _mouth_open else "закритий"))
		KEY_C:
			_each(func(h: Hero3D) -> void:
				if h._mouth3d != null:
					h._mouth3d.chew())
			_say("жування")
		KEY_L:
			_each(func(h: Hero3D) -> void:
				if h._mouth3d != null:
					h._mouth3d.lick())
			_say("облизування")
		KEY_E:
			_each(func(h: Hero3D) -> void:
				if h._mouth3d != null:
					h._mouth3d.eat())
			_say("їсть")
		KEY_U:
			_each(func(h: Hero3D) -> void: h.hit_reaction(0))
			_say("удар")


func _each(fn: Callable) -> void:
	for h in _heroes:
		if is_instance_valid(h):
			fn.call(h)


func _say(what: String) -> void:
	if _status != null:
		_status.text = "%d звірят · %s" % [_heroes.size(), what]


## OUT=<шлях> — зняти шеренгу й вийти. Знімок робить сам движок, тож картинка однакова
## при кожному запуску (вікно проєкту розгортається на весь екран, тож ріжемо центр).
func _process(_delta: float) -> void:
	if OS.get_environment("OUT") == "" or _shot_done:
		return
	_frames += 1
	if _frames < 20:          # кілька кадрів на те, щоб моделі доїхали з диска
		return
	_shot_done = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OS.get_environment("OUT"))
	print("знімок: ", OS.get_environment("OUT"))
	get_tree().quit()
