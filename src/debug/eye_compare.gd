## Порівняння "старого" ока (src/run3d/eye/, CartoonEye — геометрія з кульок) і "нового"
## вендорного (vendor/cartoon_eye/, ShaderEye — плаский квад+шейдер), пліч-о-пліч, на
## одному тлі й з однаковими кольорами. Нічого не міняє в Hero3D — суто для очей користувача.
##
## Запуск: godot res://src/debug/eye_compare.tscn
extends Node3D

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Palette.W_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1
	add_child(sun)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.0, 2.2)
	add_child(cam)
	cam.current = true

	# ЛІВОРУЧ: наше CartoonEye — той самий fox_eye пресет, що вже стоїть на лисі.
	# Масштабуємо вгору (fox_eye — розмір обличчя героя, ~0.24 в діаметрі) — інакше поруч
	# із квадом на весь метр воно губиться в кілька пікселів і порівняння нечесне.
	# Наше око "дивиться" в напрямку бігу героя (той самий бік, куди в грі спрямована
	# камера-переслідувач) — тобто ВІД глядача-переднього. hero_lab так само розвертає
	# героя на PI, щоб показати обличчя; робимо те саме тут.
	const OLD_SCALE := 2.6
	var old_l := (load("res://src/run3d/eye/fox_eye.tscn") as PackedScene).instantiate() as CartoonEye
	old_l.position = Vector3(-1.0, 0.1, 0.0)
	old_l.rotation.y = PI
	old_l.scale = Vector3.ONE * OLD_SCALE
	add_child(old_l)
	var old_r := (load("res://src/run3d/eye/fox_eye.tscn") as PackedScene).instantiate() as CartoonEye
	old_r.position = Vector3(-0.4, 0.1, 0.0)
	old_r.rotation.y = PI
	old_r.scale = Vector3.ONE * OLD_SCALE
	add_child(old_r)

	# ПРАВОРУЧ: вендорний ShaderEye — кольори підігнані під ту саму лисицю (Palette),
	# щоб порівняння було чесним (не про колір, а про форму/стиль)
	var new_l := (load("res://vendor/cartoon_eye/ShaderEye.tscn") as PackedScene).instantiate() as ShaderEye
	_tune_shader_eye(new_l)
	new_l.position = Vector3(0.4, 0.1, 0.0)
	new_l.scale = Vector3.ONE * 0.5
	add_child(new_l)
	var new_r := (load("res://vendor/cartoon_eye/ShaderEye.tscn") as PackedScene).instantiate() as ShaderEye
	_tune_shader_eye(new_r)
	new_r.position = Vector3(1.0, 0.1, 0.0)
	new_r.scale = Vector3.ONE * 0.5
	add_child(new_r)


func _tune_shader_eye(eye: ShaderEye) -> void:
	eye.sclera_color = Palette.H_CREAM
	eye.rim_color = Palette.HERO_IRIS.darkened(0.55)
	eye.iris_color = Palette.HERO_IRIS
	eye.pupil_color = Palette.HERO_EYE
	eye.iris_size = 0.66
	eye.pupil_size = 0.5
