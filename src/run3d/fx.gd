## Фабрика частинок (GPUParticles3D, квадратики-білборди). Усе процедурне, без текстур.
class_name FX
extends RefCounted

static var _mats: Dictionary = {}


static func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_rgba32()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


static func _make(amount: int, lifetime: float, one_shot: bool, size: float, color: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.randomness = 0.4
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _mat(color)
	p.draw_pass_1 = q
	p.process_material = ParticleProcessMaterial.new()
	return p


static func _ramp(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in range(colors.size()):
		offs.append(float(i) / float(maxi(1, colors.size() - 1)))
		cols.append(Color(String(colors[i])))
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _auto_free(p: GPUParticles3D) -> void:
	p.finished.connect(p.queue_free)
	p.emitting = true


## Вибух зірочки при зборі.
static func burst(parent: Node, pos: Vector3, color: Color = Color("#FFD54F")) -> void:
	var p := _make(14, 0.5, true, 0.1, color)
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, -4, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.color_initial_ramp = _ramp(["#FFFFFF", color.to_html(false), "#FFB300"])
	p.position = pos
	parent.add_child(p)
	_auto_free(p)


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
	var p := _make(amount, 2.4, true, 0.12, Color.WHITE)
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
	pm.color_initial_ramp = _ramp(["#FF5252", "#FFD740", "#69F0AE", "#40C4FF", "#E040FB", "#FF9E80"])
	p.position = pos
	parent.add_child(p)
	_auto_free(p)


## Бризки води (калюжа, Хвиля).
static func splash(parent: Node, pos: Vector3, color: Color = Color("#90CAF9")) -> void:
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
	var p := _make(amount, 1.0, false, 0.06, Color("#FFF59D"))
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
	pm.color_initial_ramp = _ramp(["#FFFFFF", "#FFF59D", "#FFD54F"])
	p.position.y = 0.7
	p.emitting = true
	parent.add_child(p)
	return p


## Сердечка (погладили / радість): рожеві ромбики летять угору з легким розльотом.
static func hearts(parent: Node, pos: Vector3, amount: int = 6) -> void:
	var p := _make(amount, 1.0, true, 0.14, Color("#FF80AB"))
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
	pm.color_initial_ramp = _ramp(["#FF80AB", "#F8BBD0"])
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
	pm.color_initial_ramp = _ramp(["#FFFFFF", color.to_html(false), color.darkened(0.2).to_html(false)])
	p.emitting = true
	parent.add_child(p)
	return p


## Атмосфера світу/сезону: "petals" (Лужок), "leaves" (Ліс), "glints" (Пляж), "snow" (зима), "fireflies" (вечір).
static func ambient(parent: Node, kind: String) -> GPUParticles3D:
	var color := Color.WHITE
	var size := 0.1
	var gravity := Vector3(0, -0.4, 0)
	var ramp: Array = []
	var amount := 60
	var lifetime := 9.0
	match kind:
		"petals":
			ramp = ["#F8BBD0", "#FFFFFF", "#F06292"]
			gravity = Vector3(0.4, -0.35, 0)
		"leaves":
			ramp = ["#FF8F00", "#D84315", "#FDD835"]
			size = 0.13
			gravity = Vector3(0.6, -0.5, 0)
		"snow":
			ramp = ["#FFFFFF", "#E3F2FD"]
			size = 0.08
			amount = 120
			gravity = Vector3(0.2, -0.7, 0)
		"glints":
			ramp = ["#FFFFFF", "#B3E5FC"]
			size = 0.06
			amount = 40
			lifetime = 1.6
			gravity = Vector3.ZERO
		"fireflies":
			ramp = ["#FFF59D", "#C6FF00"]
			size = 0.07
			amount = 30
			lifetime = 4.0
			gravity = Vector3.ZERO
		"rain":
			ramp = ["#B3E5FC", "#E1F5FE"]
			size = 0.05
			amount = 200
			lifetime = 1.4
			gravity = Vector3(0.3, -9.0, 0)
		"stars":
			ramp = ["#FFFFFF", "#FFF59D", "#B39DDB"]
			size = 0.06
			amount = 80
			lifetime = 6.0
			gravity = Vector3(0, -0.15, 0)
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
