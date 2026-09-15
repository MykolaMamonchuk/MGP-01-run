## Знімок УСІЄЇ морди героя анфас — щоб бачити очі, рот і намальований на текстурі носик
## разом, в одному кадрі, і порівнювати з референсом числами, а не «на око».
##
## Запуск:  OUT=/шлях/face.png HERO=lys godot res://src/debug/face_shot.tscn
## Кадр зберігає сам движок (не скріншот вікна) — розмір і кадрування однакові щоразу.
extends Node3D

const SIZE := 660

var _hero: Hero3D
var _cam: Camera3D
var _frames := 0
var _done := false


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	# тло — колір хутра героя, а не темрява: у кропі ока порожнеча за головою інакше
	# читалась би скриптом порівняння як «зіниця» і псувала всі числа
	e.background_color = Palette.of(Hero3D.defs().get(OS.get_environment("HERO") if OS.get_environment("HERO") != "" else "lys", {}).get("color"), Palette.HERO_DEFAULT)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.85
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 160, 0)
	sun.light_energy = 1.1
	add_child(sun)

	var id := OS.get_environment("HERO")
	if id.is_empty():
		id = "lys"
	# RIG=<ім'я моделі> — приміряти іншу модель на цього героя (див. hero_lab)
	var tried := RigTry.apply(id)
	if tried != "":
		print("модель підмінено: ", tried)

	var def := Hero3D.resolve_def(Hero3D.defs(), id)
	_hero = Hero3D.new()
	add_child(_hero)
	_hero.set_hero(id, Palette.of(def.get("color"), Palette.HERO_DEFAULT),
		String(def.get("feature", "fox")))
	# ANIM — стан анімації для знімка (RUN, SPRINT, DANCE…); без нього спокій
	# Частина станів вмикається НЕ полем anim_state, а власним методом (він заводить свій
	# таймер/бленд). Через set_anim_state вони виглядають як спокій — на цьому вже
	# помилились, вирішивши, що привітання зламане.
	var anim := OS.get_environment("ANIM")
	match anim:
		"WAVE": _hero.wave_hello()
		"HIT": _hero.hit_reaction(0)
		"DANCE": _hero.dance()
		"JUMP": _hero.jump()
		"LANE":
			_hero.set_anim_state(Hero3D.Anim.RUN)
			_hero.change_lane(1)
		"": pass
		_:
			if Hero3D.Anim.has(anim):
				_hero.set_anim_state(Hero3D.Anim[anim])

	# морда дивиться в −Z, тож камера стоїть перед нею й трохи вище рівня очей
	_cam = Camera3D.new()
	var cam := _cam
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	# кадрування — зі середовища, бо голова в кожного героя на своїй висоті
	cam.size = float(OS.get_environment("CAM_SIZE")) if OS.get_environment("CAM_SIZE") != "" else 0.62
	var cam_y := float(OS.get_environment("CAM_Y")) if OS.get_environment("CAM_Y") != "" else 0.66
	# CAM_YAW — кут довкола героя: 0 — анфас, 90 — збоку (видно лапи, яких спереду не видно)
	var yaw: float = float(OS.get_environment("CAM_YAW")) if OS.get_environment("CAM_YAW") != "" else 0.0
	var a := deg_to_rad(yaw)
	cam.position = Vector3(sin(a) * 2.0, cam_y, -cos(a) * 2.0)
	cam.rotation_degrees = Vector3(0.0, 180.0 - yaw, 0.0)
	add_child(cam)
	cam.current = true



## POSE зі середовища — щоб знімати не лише спокійну морду: "left"/"right" — погляд убік,
## "happy" — радість (сплюснуті очі + усмішка). Без нього морда просто дивиться прямо.
func _apply_pose() -> void:
	var pose := OS.get_environment("POSE")
	if pose == "":
		return
	# Hero3D._process щокадру сам веде погляд і повіки — для знімка пози його треба спинити,
	# інакше наступний же кадр поверне очі «прямо» й знімок покаже не те, що просили.
	_hero.set_process(false)
	match pose:
		"left":
			for e in _hero._eyes:
				_hero.call("_eye_gaze", e, Vector2(-1.0, 0.0))
		"right":
			for e in _hero._eyes:
				_hero.call("_eye_gaze", e, Vector2(1.0, 0.0))
		"happy":
			_hero.call("_set_eyes_squash", Hero3D.HAPPY_EYE_SQUASH)
			_hero._mouth3d.smile()
			_hero._mouth3d._active_tween.custom_step(0.3)


func _process(_delta: float) -> void:
	# кілька кадрів на те, щоб модель доплила з диска й обличчя зібралось
	_frames += 1
	# WAIT — скільки секунд дати сцені пожити перед знімком (дрейф погляду повільний,
	# на 12-му кадрі його ще не видно)
	var wait_f := 12
	if OS.get_environment("WAIT") != "":
		wait_f = int(float(OS.get_environment("WAIT")) * 60.0)
	if _frames < wait_f or _done:
		return
	_done = true          # далі всередині є await — без прапорця _process зайшов би вдруге
	_apply_pose()
	var out := OS.get_environment("OUT")
	if out.is_empty():
		out = "user://face.png"
	# вікно в проєкті розгортається на весь екран (window/size/mode=2), тож ріжемо
	# центральний квадрат і зводимо до сталого розміру — інакше кадр «плаває» між запусками
	# поза щойно змінила сцену, а у вьюпорті ще намальований ПОПЕРЕДНІЙ кадр — без цього
	# чекання знімок показував би морду до пози (на цьому вже один раз обманулись)
	await RenderingServer.frame_post_draw
	if OS.get_environment("DUMP") != "":
		var e0 := _hero._eyes[0] as Node3D
		var e1 := _hero._eyes[1] as Node3D
		print("голова=%s  обличчя=%s  око0=%s  око1=%s  центр очей x=%.3f" % [
			_hero._head.global_position, _hero._face.global_position,
			e0.global_position, e1.global_position,
			(e0.global_position.x + e1.global_position.x) * 0.5])
		if _hero._mouth3d != null:
			print("рот=%s  масштаб=%s" % [_hero._mouth3d.global_position, _hero._mouth3d.global_transform.basis.get_scale()])
	var img := get_viewport().get_texture().get_image()
	var side: int = mini(img.get_width(), img.get_height())
	img = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
	img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	img.save_png(out)
	await _save_eye_crop(out)
	get_tree().quit()


## Окремо кладемо поруч тісний кроп ОДНОГО ока — у тому ж кадруванні, що й референсний кроп
## із текстури, щоб tools/eye_similarity.py порівняв їх числами.
##
## Кадр знімає ОКРЕМА камера просто перед оком у власному SubViewport. Пробували рахувати
## кроп проєкцією позиції ока на головний кадр (unproject_position) — кадр «плавав»; так само
## пробували шукати око як найбільшу пляму на знімку — чіплялось вухо. Друга камера точна за
## побудовою: вона дивиться саме туди, куди треба, і кадрування не залежить ні від чого.
func _save_eye_crop(out: String) -> void:
	if _hero._eyes.is_empty():
		return
	var eye := _hero._eyes[0] as Node3D
	var sv := SubViewport.new()
	sv.size = Vector2i(SIZE, SIZE)
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	# око дивиться в −Z разом із мордою; камера стає перед ним і бере трохи хутра довкола
	cam.size = eye.scale.y * 1.22          # тісно: ніс і писок у кадр потрапляти не мають
	cam.position = eye.global_position + Vector3(0.0, 0.0, -1.5)
	cam.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	sv.add_child(cam)
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(out.get_basename() + "_eye.png")
	print("кроп ока: камера size=%.3f у %s" % [cam.size, eye.global_position])
