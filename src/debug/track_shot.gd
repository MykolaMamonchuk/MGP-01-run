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
##     WORLD=meadow SEED=7 OUT=…       # інша розкладка декору (типово жереб сталий)
##     WORLD=meadow LEVEL=1 ADVANCE=40 OUT=…   # САМЕ те, що бачить гравець на рівні 1
extends Node3D

## Кадр як у гри: 16:9. Квадратна обрізка викидала б саме краї, а в референсі забудова
## стоїть саме там — і порівняння міряло б не те.
const OUT_W := 1152
const OUT_H := 648

var _track: Track
var _chunks: LevelChunkLoader
var _frames := 0
var _done := false


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Palette.W_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Світло РІВНО як у грі (run3d.tscn, Environment_1). Було 0,75 і чисто біле — на третину
	# яскравіше за справжнє, тож знімок виходив вицвілим, і я міряв схожість не з тим, що
	# бачить гравець.
	e.ambient_light_color = Color(1.0, 0.96, 0.88)
	e.ambient_light_energy = 0.35
	# Серпанок — РІВНО як у грі (run3d.gd _setup_sky). Без нього знімок показував далекі
	# предмети різкими, і я міряв появу декору на горизонті там, де в грі її ховає туман.
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	e.fog_density = 0.012
	e.fog_sky_affect = 0.0
	e.fog_aerial_perspective = 0.4
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	# той самий поворот сонця, що в run3d.tscn
	sun.transform.basis = Basis(Vector3(0.87758255, 0.0, -0.47942555),
		Vector3(-0.37554693, 0.62161, -0.687434),
		Vector3(0.2980157, 0.7833269, 0.54551405))
	sun.light_energy = 0.9
	# Тіні РІВНО як у грі: один каскад замість чотирьох (на 40 метрах ділити нема чого, а
	# межі каскадів дають повзучі шви) плюс зсув, без якого на великих площинах з'являється
	# «акне» — дрібні смуги, що ворушаться при русі.
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 22.0
	add_child(sun)

	_track = Track.new()
	add_child(_track)
	# ВІДТВОРЮВАНІСТЬ. Track робить _rng.randomize(), тож кожен прогін розставляв декор
	# інакше, і знімок гуляв сам по собі — на забудові до 7 відсоткових пунктів. Порівнювати
	# «до і після» на такому знімку неможливо: зміна тоне в перестановці кущів. Сідаємо на
	# сталий жереб (і глобальний теж — _decorate бере і randf(), і _rng).
	var s_env := OS.get_environment("SEED")
	var seed_v := int(s_env) if s_env != "" else 20260915
	seed(seed_v)
	_track._rng.seed = seed_v

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
	var w: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	# небо бере колір зі СВІТУ, а не зашите в знімок: інакше поле sky у world.json ніяк не
	# впливало б на те, чим ми міряємо схожість, і тюнити його було б неможливо
	e.background_color = Palette.of(w.get("sky"), Palette.W_SKY)
	_track.rebuild(w, false)

	# АВТОРСЬКИЙ РІВЕНЬ. Це не дрібниця, а різниця між тим, що я міряю, і тим, що бачить
	# гравець: коли в рівня є авторський декор, Track малює ТІЛЬКИ його, а процедурний
	# декоратор не виконується взагалі. Знімок без LEVEL показує процедурне узбіччя —
	# густе й гарне, — а в грі на його місці стоїть рівно те, що розставлено маркерами.
	var lvl := OS.get_environment("LEVEL")
	if lvl != "":
		_chunks = LevelChunkLoader.new()
		_chunks.start(int(lvl), _track, null)

	# проїхати трохи: перший ряд щойно викладено, а стики видно на вже перевкладених
	var adv := OS.get_environment("ADVANCE")
	var metres := int(adv) if adv != "" else 6
	for i in metres:
		_track.advance(1.0, float(i + 1))
		if _chunks != null:
			_chunks.update(float(i + 1))

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
		# рівно та сама камера, що в грі (src/run3d/run3d.tscn, CameraRig/Camera3D) —
		# інакше порівняння з референсом міряло б ракурс, а не рівень
		cam.position = Vector3(0.0, 3.4, 5.6)
		cam.rotation_degrees = Vector3(-25.2, 0.0, 0.0)
		cam.fov = 62.0
	add_child(cam)
	cam.current = true


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 16 or _done:
		return
	_done = true
	await RenderingServer.frame_post_draw
	if OS.get_environment("DUMP") != "":
		# скільки предметів кожного виду траса справді поклала в ряди — щоб черга на
		# генерування моделей будувалась за фактом, а не за відчуттям «це, мабуть, помітне»
		var per_layer := {}
		for ids in _track._decor_ids:
			for j in (ids as PackedInt32Array).size():
				var id := (ids as PackedInt32Array)[j]
				per_layer[id] = int(per_layer.get(id, 0)) + 1
		var rows := []
		for key in _track._decor_layer_of.keys():
			var n := int(per_layer.get(int(_track._decor_layer_of[key]), 0))
			if n > 0:
				rows.append([n, String(key).split("|")[0].split("#")[0]])
		rows.sort_custom(func(a, b): return a[0] > b[0])
		for r in rows:
			print("КІЛЬКІСТЬ %s %d" % [r[1], r[0]])

	var out := OS.get_environment("OUT")
	if out != "":
		var img := get_viewport().get_texture().get_image()
		# ріжемо по ширині до 16:9, а не до квадрата
		var w := img.get_width()
		var h: int = mini(img.get_height(), int(float(w) * float(OUT_H) / float(OUT_W)))
		img = img.get_region(Rect2i(0, (img.get_height() - h) / 2, w, h))
		img.resize(OUT_W, OUT_H, Image.INTERPOLATE_LANCZOS)
		img.save_png(out)
		print("знімок: ", out)
	get_tree().quit()
