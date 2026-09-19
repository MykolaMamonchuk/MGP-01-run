## Знімок ОДНОГО пропса з кількох боків — щоб приймати моделі числами й очима, а не «на око
## з прев'ю генератора». У грі не використовується.
##
## Навіщо. Модель приходить без контексту: невідомо, якого вона розміру проти героя, чи не
## лежить боком, чи не розмазана текстура ззаду. Тут вона стоїть на землі поруч із коробкою
## розміром з героя, і всі чотири боки видно одразу.
##
## Запуск:
##     PROP=res://assets/props/barrel.glb OUT=/tmp/barrel.png godot res://src/debug/prop_shot.tscn
##     PROP=… SCALE=1.3 YAW=90 OUT=…      # приміряти доведення з data/props.json
##     PROP=… BOX=0.70x0.70x0.50 OUT=…    # намалювати ще й бокс зіткнення зі світу
extends Node3D

const SIZE := 660
## Кадр підганяється під розмір моделі: будинок 2,1 м у кадрі на 3,4 м не вміщався й обрізався
## згори й з боків, а саме по цьому знімку моделі й приймають. ZOOM= більший — ширший кадр.
var CAM_SIZE: float = float(OS.get_environment("ZOOM")) if OS.has_environment("ZOOM") else 3.4
var SPREAD: float = CAM_SIZE / 3.4 * 1.05
const ANGLES := [0.0, 90.0, 180.0, 270.0]

var _done := false
var _frames := 0


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.46, 0.64, 0.78)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 145.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.55, 0.71, 0.46)
	gm.roughness = 1.0
	ground.material_override = gm
	add_child(ground)

	var path := OS.get_environment("PROP")
	if path.is_empty():
		push_error("prop_shot: задай PROP=res://… або шлях до .glb")
		get_tree().quit()
		return
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("prop_shot: не читається %s" % path)
		get_tree().quit()
		return

	# чотири копії по колу — щоб усі боки були в одному кадрі, а не в чотирьох запусках
	for i in ANGLES.size():
		var inst := scene.instantiate() as Node3D
		inst.position = Vector3((float(i) - 1.5) * SPREAD, 0.0, 0.0)
		inst.rotation_degrees.y = float(ANGLES[i]) + _num("YAW", 0.0)
		var s := _num("SCALE", 1.0)
		inst.scale = Vector3.ONE * s
		add_child(inst)

	# коробка зростом з героя поруч: без неї «великий чи малий» не читається взагалі
	var ref := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.35, 0.98, 0.35)   # зріст героя
	ref.mesh = bm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.9, 0.9, 0.95, 0.55)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ref.material_override = rm
	ref.position = Vector3(-2.5, bm.size.y * 0.5, 0.0)
	add_child(ref)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CAM_SIZE
	cam.position = Vector3(0.0, CAM_SIZE * 0.25, 5.0)
	cam.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	add_child(cam)
	cam.current = true


func _num(key: String, fallback: float) -> float:
	var v := OS.get_environment(key)
	return float(v) if v != "" else fallback


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 14 or _done:
		return
	_done = true
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("OUT")
	if out != "":
		var img := get_viewport().get_texture().get_image()
		# вікно проєкту розгортається на весь екран — ріжемо центр і зводимо до сталого розміру
		var side: int = mini(img.get_width(), img.get_height())
		img = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2,
			side, side))
		img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		img.save_png(out)
		print("знімок: ", out)
	get_tree().quit()
