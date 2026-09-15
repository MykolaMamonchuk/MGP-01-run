## Знімок ТРАСИ зі світом і декором — щоб приймати декор, який тягнеться вздовж дороги,
## очима, а не здогадом. У грі не використовується.
##
## Навіщо. prop_shot показує пропс сам по собі: чи він правильного розміру й чи не лежить
## боком. Але декор на кшталт поручнів уздовж берега має ще одну вимогу, якої на окремому
## пропсі не видно взагалі — ЛАНКИ МУСЯТЬ СТИКУВАТИСЬ. Щілина в 5 см між секціями на знімку
## одного пропса невидима, а на трасі перетворює огорожу на пунктир.
##
## Запуск:
##     WORLD=meadow OUT=/tmp/track.png godot res://src/debug/track_shot.tscn
##     WORLD=meadow VIEW=bank OUT=…    # камера збоку впритул до берега (стики поручнів)
##     WORLD=meadow VIEW=top OUT=…     # згори: вода, береги, забудова — де що лежить
##     WORLD=meadow ADVANCE=17 OUT=…   # проїхати N метрів перед знімком
extends Node3D

const SIZE := 900

var _track: Track
var _frames := 0
var _done := false


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.53, 0.72, 0.87)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.75
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46.0, 150.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)

	_track = Track.new()
	add_child(_track)

	var name := OS.get_environment("WORLD")
	if name.is_empty():
		name = "meadow"
	var f := FileAccess.open("res://data/worlds/%s.json" % name, FileAccess.READ)
	if f == null:
		push_error("track_shot: нема res://data/worlds/%s.json" % name)
		get_tree().quit()
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	_track.rebuild(parsed if typeof(parsed) == TYPE_DICTIONARY else {}, false)

	# проїхати трохи: перший ряд щойно викладено, а стики видно на вже перевкладених
	var adv := OS.get_environment("ADVANCE")
	for i in int(adv) if adv != "" else 6:
		_track.advance(1.0)

	var cam := Camera3D.new()
	if OS.get_environment("VIEW") == "top":
		# згори: одразу видно, що де лежить — вода, береги, забудова
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 16.0
		cam.position = Vector3(0.0, 12.0, -4.0)
		cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	elif OS.get_environment("VIEW") == "bank":
		# впритул до берега й уздовж нього — саме так видно щілини між ланками
		cam.position = Vector3(-4.6, 0.55, -6.0)
		cam.rotation_degrees = Vector3(-6.0, -152.0, 0.0)
		cam.fov = 55.0
	else:
		cam.position = Vector3(0.0, 3.4, 4.2)
		cam.rotation_degrees = Vector3(-20.0, 0.0, 0.0)
		cam.fov = 62.0
	add_child(cam)
	cam.current = true


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 16 or _done:
		return
	_done = true
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("OUT")
	if out != "":
		var img := get_viewport().get_texture().get_image()
		var side: int = mini(img.get_width(), img.get_height())
		img = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
		img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		img.save_png(out)
		print("знімок: ", out)
	get_tree().quit()
