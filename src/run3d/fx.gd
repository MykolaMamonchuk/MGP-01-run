## Фабрика частинок (GPUParticles3D, білборди). Усе процедурне, без файлів-текстур.
##
## Форма: КРУГЛА м'яка пляма. Спершу були суцільні квадрати — і поруч із гладкими моделями
## героїв вони читались як воксельні кубики з попередньої версії гри. Круг генерується в
## коді радіальним градієнтом, тож обіцянка «жодних файлів» лишається чинною.
## Конфеті — виняток: то паперові квадратики, їм квадратна форма й личить.
class_name FX
extends RefCounted

static var _mats: Dictionary = {}
static var _dot: GradientTexture2D = null

## Скільки тримати прогрівальні частинки в кадрі, перш ніж прибрати.
const PREHEAT_SEC := 0.35


## Прогріти шейдери частинок ЗАЗДАЛЕГІДЬ.
##
## Рушій компілює шейдер тоді, коли вперше його малює. Виміряно (tools/perf/fx_bench.tscn):
## перший пил коштує 33,9 мс проти 5,2 мс удруге, перший сплеск зірочок — 25,1 проти 3,1.
## При кадрі 16,7 мс це видимі заїкання, і йдуть вони саме на початку рівня, коли герой
## уперше стрибає й збирає зірочку.
##
## Тому один раз «стріляємо» кожним ефектом наперед — крихітними й У КАДРІ (поза кадром
## рушій їх не малює, а отже й не компілює), — і одразу прибираємо. Конфігурації беремо
## ТІ САМІ, справжніми викликами: варіант шейдера залежить від набору увімкнених
## властивостей, тож «схожий» ефект прогрів би не той шейдер.
static func preheat(host: Node3D, at: Vector3 = Vector3.ZERO) -> void:
	if host == null or not host.is_inside_tree():
		return
	var probe := Node3D.new()
	probe.name = "FXPreheat"
	probe.position = at
	probe.scale = Vector3.ONE * 0.002      # видимі рушієві, невидимі гравцеві
	host.add_child(probe)
	dust(probe, Vector3.ZERO)
	burst(probe, Vector3.ZERO, Palette.STAR)
	splash(probe, Vector3.ZERO, Palette.SPLASH_WATER)
	confetti(probe, Vector3.ZERO, 4)
	sparkles(probe, 0.1, 4)
	# Кільце теж: ним світить СУПЕРСИЛА, і це найгірше місце для компіляції шейдера —
	# дитина натискає кнопку, і гра завмирає рівно в мить, коли має бути найефектніше.
	ring(probe, Vector3.ZERO, Palette.STAR)
	var star := MeshInstance3D.new()
	star.mesh = star_mesh(Palette.STAR)
	probe.add_child(star)
	# Бульбашка щита (ведмежа/черепашки суперсила): єдиний ЛІТ-матеріал у всій родзинці
	# суперсил — прозорий, з емісією, БЕЗ shading_mode unshaded. Це інший, важчий шейдер,
	# ніж усі частинки вище (ті — unshaded), тож своє прогрівання йому не завадить: без
	# нього перше «щит!» у сесії компілювало б PBR-шейдер саме в мить активації сили.
	var shield := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.75
	sph.height = 1.5
	shield.mesh = sph
	shield.material_override = _shield_mat()
	probe.add_child(shield)
	host.get_tree().create_timer(PREHEAT_SEC).timeout.connect(
		func() -> void:
			if is_instance_valid(probe):
				probe.queue_free())


## М'яка кругла пляма: біле в центрі, прозоре по краю. Множиться на колір частинки.
static func _dot_texture() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 0.82, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1),
			Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.width = 64
		_dot.height = 64
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
	return _dot


static func _mat(color: Color, round_shape: bool = true) -> StandardMaterial3D:
	var key := "%d|%s" % [color.to_rgba32(), round_shape]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if round_shape:
			m.albedo_texture = _dot_texture()
		_mats[key] = m
	return _mats[key]


static func _make(amount: int, lifetime: float, one_shot: bool, size: float, color: Color,
		round_shape: bool = true) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.randomness = 0.4
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _mat(color, round_shape)
	p.draw_pass_1 = q
	p.process_material = ParticleProcessMaterial.new()
	return p


## Пласка п'ятикутна зірочка, зібрана в коді. Над приголомшеним героєм досі кружляли
## ВОКСЕЛЬНІ зірки — по кілька кубиків кожна, і поруч із гладкими моделями вони читались
## як уламки, а не як «в очах зірочки».
static func star_mesh(color: Color, points: int = 5, inner_k: float = 0.46) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim: Array[Vector3] = []
	for i in points * 2:
		var a := TAU * float(i) / float(points * 2) - PI * 0.5
		var r := 0.5 if i % 2 == 0 else 0.5 * inner_k
		rim.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
	for i in rim.size():
		var j := (i + 1) % rim.size()
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(rim[i])
		st.add_vertex(rim[j])
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, _flat_mat(color))
	return mesh


## Матеріал пласкої фігурки: без освітлення (щоб колір був той самий під будь-яким світлом)
## і білбордом — інакше зірочка з профілю зникала б у лінію.
static func _flat_mat(color: Color) -> StandardMaterial3D:
	var key := "flat|%d" % color.to_rgba32()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		# без цього білборд скидає базис разом із масштабом вузла — зірочка виходила
		# на пів екрана, хоч вузол і просив 0,26
		m.billboard_keep_scale = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


## Той самий набір властивостей, що й у Hero3D._shield (щит-бульбашка): лишаємо лит-освітлення
## (тут shading_mode НЕ unshaded — інакше прогрівся б не той шейдер), прозорість і емісію.
## Значення кольору й шорсткості для компіляції шейдера байдужі — важливий саме набір увімкнених
## властивостей, тож дублюємо його точно, а не «схоже».
static func _shield_mat() -> StandardMaterial3D:
	var key := "shield_warm"
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.4, 0.8, 1.0, 0.28)
		m.emission_enabled = true
		m.emission = Palette.HERO_SHIELD
		m.emission_energy_multiplier = 0.6
		m.roughness = 0.2
		_mats[key] = m
	return _mats[key]


static func _ramp(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in range(colors.size()):
		offs.append(float(i) / float(maxi(1, colors.size() - 1)))
		cols.append(colors[i] as Color)
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _auto_free(p: GPUParticles3D) -> void:
	p.finished.connect(p.queue_free)
	p.emitting = true


## Вибух зірочки при зборі.
static func burst(parent: Node, pos: Vector3, color: Color = Palette.STAR) -> void:
	var p := _make(14, 0.5, true, 0.1, color)
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, -4, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.color_initial_ramp = _ramp([Palette.WHITE, color, Palette.AMBER_DEEP])
	p.position = pos
	parent.add_child(p)
	_auto_free(p)


## Спалах-кільце (суперсила): пласке кільце розлітається від героя й гасне. Це НЕ частинки —
## один меш на 0,35 с, тож «видно подію», а не хмару крапок (playtest 09.09: частинок було
## занадто багато, а самої анімації не було видно).
static func ring(parent: Node, pos: Vector3, color: Color, seconds: float = 0.35) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	tm.rings = 24
	tm.ring_segments = 8
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, 0.85)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.4
	mi.material_override = m
	mi.position = pos
	mi.scale = Vector3(0.4, 0.4, 0.4)
	parent.add_child(mi)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(2.4, 0.6, 2.4), seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, seconds)
	tw.finished.connect(mi.queue_free)


## Пил при приземленні / кроці.
static func dust(parent: Node, pos: Vector3) -> void:
	var p := _make(10, 0.45, true, 0.12, Color(0.95, 0.93, 0.85, 0.8))
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 75.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0, -2, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	p.position = pos
	parent.add_child(p)
	_auto_free(p)


## Конфеті (станція, завдання, ріст).
static func confetti(parent: Node, pos: Vector3, amount: int = 80) -> void:
	var p := _make(amount, 2.4, true, 0.12, Palette.WHITE, false)   # конфеті — паперові квадратики
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 3.5
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -4.5, 0)
	pm.angular_velocity_min = -360.0
	pm.angular_velocity_max = 360.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.damping_min = 0.5
	pm.damping_max = 1.5
	pm.color_initial_ramp = _ramp(Palette.RAMP_CONFETTI)
	p.position = pos
	parent.add_child(p)
	_auto_free(p)


## Бризки води (калюжа, Хвиля).
static func splash(parent: Node, pos: Vector3, color: Color = Palette.SPLASH_WATER) -> void:
	var p := _make(16, 0.6, true, 0.09, color)
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 4.5
	pm.gravity = Vector3(0, -9, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	p.position = pos
	parent.add_child(p)
	_auto_free(p)


## Постійні іскри навколо героя (Іскринка) або антенки.
static func sparkles(parent: Node, radius: float = 0.5, amount: int = 12) -> GPUParticles3D:
	var p := _make(amount, 1.0, false, 0.06, Palette.LEMON_PALE)
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	pm.color_initial_ramp = _ramp(Palette.RAMP_SPARKLE)
	p.position.y = 0.7
	p.emitting = true
	parent.add_child(p)
	return p


## Сердечка (погладили / радість): рожеві ромбики летять угору з легким розльотом.
static func hearts(parent: Node, pos: Vector3, amount: int = 6) -> void:
	var p := _make(amount, 1.0, true, 0.14, Palette.PINK_BRIGHT)
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0, 1.2, 0)
	# квадратик під 45° читається як сердечко-ромбик
	pm.angle_min = 45.0
	pm.angle_max = 45.0
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	pm.color_initial_ramp = _ramp(Palette.RAMP_HEARTS)
	p.position = pos
	parent.add_child(p)
	_auto_free(p)


## Слід за героєм (аксесуар «слід»): постійні іскри заданого кольору; повертає емітер — власник його прибирає.
static func trail(parent: Node, color: Color, amount: int = 16) -> GPUParticles3D:
	var p := _make(amount, 0.8, false, 0.07, color)
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.15
	pm.direction = Vector3(0, 0.3, 1)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, -0.5, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	pm.color_initial_ramp = _ramp([Palette.WHITE, color, color.darkened(0.2)])
	p.emitting = true
	parent.add_child(p)
	return p


## Атмосфера світу/сезону: "petals" (Лужок), "leaves" (Ліс), "glints" (Пляж), "snow" (зима), "fireflies" (вечір).
static func ambient(parent: Node, kind: String) -> GPUParticles3D:
	var color := Palette.WHITE
	var size := 0.1
	var gravity := Vector3(0, -0.4, 0)
	# кольори — Palette.RAMP_AMBIENT[kind]; тут лише «фізика» кожного виду
	var amount := 60
	var lifetime := 9.0
	match kind:
		"petals":
			gravity = Vector3(0.4, -0.35, 0)
		"leaves":
			size = 0.13
			gravity = Vector3(0.6, -0.5, 0)
		"snow":
			size = 0.08
			amount = 120
			gravity = Vector3(0.2, -0.7, 0)
		"glints":
			size = 0.06
			amount = 40
			lifetime = 1.6
			gravity = Vector3.ZERO
		"fireflies":
			size = 0.07
			amount = 30
			lifetime = 4.0
			gravity = Vector3.ZERO
		"rain":
			size = 0.05
			amount = 200
			lifetime = 1.4
			gravity = Vector3(0.3, -9.0, 0)
		"stars":
			size = 0.06
			amount = 80
			lifetime = 6.0
			gravity = Vector3(0, -0.15, 0)
	var ramp: Array = Palette.RAMP_AMBIENT.get(kind, [])
	var p := _make(amount, lifetime, false, size, color)
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(7.0, 0.5 if kind == "glints" else 3.0, 22.0)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.5
	pm.gravity = gravity
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.color_initial_ramp = _ramp(ramp)
	p.position = Vector3(0.0, 0.4 if kind == "glints" else 5.0, -12.0)
	p.preprocess = 4.0
	p.emitting = true
	parent.add_child(p)
	return p
