## Знімок ОДНОГО ока в тому ж кадруванні, що й референсний кроп із оригінальної текстури —
## щоб tools/eye_similarity.py міг порівняти їх числами, а не «на око».
##
## Запуск:  OUT=/шлях/ours.png godot res://src/debug/eye_shot.tscn
## Кадр зберігається САМИМ движком (не скріншотом вікна) — тож розмір і кадрування
## однакові при кожному запуску, і порівняння з референсом чесне.
extends Node3D

const EYE := "res://src/run3d/eye/fox_eye_3d.tscn"

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	# тло — руде хутро лиса: скрипт порівняння саме за ним відрізняє око від «не ока»
	e.background_color = Palette.of(Hero3D.defs().get("lys", {}).get("color"), Palette.HERO_DEFAULT)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 1.0
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)   # світло згори-зліва, як на референсі
	sun.light_energy = 1.0
	add_child(sun)

	var eye := (load(EYE) as PackedScene).instantiate() as CartoonEye3D
	# як у грі: Hero3D фарбує сокет кольором шерсті героя, інакше він тут читався б
	# темним кільцем навколо ока й порівняння з референсом було б нечесним
	eye.socket_color = Palette.of(Hero3D.defs().get("lys", {}).get("color"), Palette.HERO_DEFAULT)
	# компонент будується вперед у +Z, тож камера стоїть з боку +Z і дивиться на нього
	add_child(eye)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.25              # око (діаметр 1.0) займає ~80% кадру, як у кропі
	cam.position = Vector3(0.0, 0.0, 2.0)
	add_child(cam)
	cam.current = true

	# два кадри на усадку, далі — знімок вьюпорта у файл і вихід
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("OUT")
	if out != "":
		var img := get_viewport().get_texture().get_image()
		var side: int = mini(img.get_width(), img.get_height())
		var x0 := (img.get_width() - side) / 2
		var y0 := (img.get_height() - side) / 2
		img = img.get_region(Rect2i(x0, y0, side, side))
		img.resize(660, 660, Image.INTERPOLATE_LANCZOS)
		img.save_png(out)
		print("saved ", out)
	get_tree().quit()
