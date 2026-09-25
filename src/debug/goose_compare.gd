@tool
extends Node3D

## ПОРІВНЯННЯ ГУСОК: стара (assets/props/_exp/goose/goose_old.glb) і три нові з ригом, що тепер у грі (assets/props/goose_1..3.glb) — у п'яти станах.
##
## Нові — з docs/refs/incoming/goose, почищені від зайвої Icosphere (копії в
## assets/props/_exp/goose). Анімації в моделях немає, рух процедурний: src/run3d/goose_rig.gd.
## Матеріали оброблено так, як їх малює гра (без карт нормалей, світло на вершину,
## навколишнє світло випроміненням) — інакше порівнював би не те, що побачить дитина.
##
## Ряди — моделі, стовпчики — стани: стоїть / іде / кусає / шипить / летить. Відкрити в
## редакторі (анімація йде й там) або запустити в Compatibility, як на телефоні:
##   /Applications/Godot.app/Contents/MacOS/Godot --rendering-method gl_compatibility \
##       res://src/debug/goose_compare.tscn
## Стара гуска — ОСТАННІЙ ряд: вона лише для порівняння й у всіх стовпчиках однакова, а на
## широкому екрані телефона ближній ряд найбільший.
const MODELS := [
	["ГУСКА 1", "res://assets/props/goose_1.glb"],
	["ГУСКА 2", "res://assets/props/goose_2.glb"],
	["ГУСКА 3", "res://assets/props/goose_3.glb"],
	["БУЛО", "res://assets/props/_exp/goose/goose_old.glb"],
]
const STATE_NAMES := {"stand": "стоїть", "walk": "іде", "bite": "кусає", "hiss": "шипить", "fly": "летить"}

## Зріст гуски у грі, м: коробка перешкоди goose у data/worlds/meadow.json має висоту 0,6.
const HEIGHT_M := 0.6
const COL_GAP := 1.05
const ROW_GAP := 1.1

var _rigs: Array = []   # [GooseRig, Node3D-модель, база_y]
var _t := 0.0


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	_t += delta
	for r in _rigs:
		var lift: float = (r[0] as GooseRig).pose(_t)
		(r[1] as Node3D).position.y = float(r[2]) + lift * float(r[3])


func _build() -> void:
	_rigs.clear()
	for c in get_children():
		if String(c.name).begins_with("Г_"):
			remove_child(c)
			c.queue_free()
	var cols: Array = GooseRig.STATES
	($Камера as Camera3D).look_at_from_position(Vector3(-0.3, 5.2, 4.6), Vector3(-0.3, 0.25, -1.55))
	($Камера as Camera3D).fov = 32.0
	var method := RenderingServer.get_current_rendering_method()
	var k: float = load("res://src/run3d/run3d.gd").light_scale_for(method)
	var env := ($Світ as WorldEnvironment).environment
	env.ambient_light_energy = 0.35 * k
	($Сонце as DirectionalLight3D).light_energy = 0.9 * k
	var amb := env.ambient_light_color
	var amb_e := env.ambient_light_energy
	for ci in range(cols.size()):
		var lb := _label(String(STATE_NAMES[cols[ci]]), Color(1.0, 0.95, 0.6))
		lb.name = "Г_стан%d" % ci
		lb.position = Vector3(_col_x(ci, cols.size()), 0.95, -float(MODELS.size()) * ROW_GAP + 0.2)
		add_child(lb)
	for ri in range(MODELS.size()):
		var z := -float(ri) * ROW_GAP
		var title := _label(String(MODELS[ri][0]), Color(1, 1, 1))
		title.name = "Г_ряд%d" % ri
		title.position = Vector3(_col_x(0, cols.size()) - 0.85, 0.3, z)
		add_child(title)
		var scene := load(String(MODELS[ri][1])) as PackedScene
		if scene == null:
			continue
		# Стара гуска без скелета — лише один екземпляр у першому стовпчику.
		var n := cols.size() if ri < MODELS.size() - 1 else 1
		for ci in range(n):
			var holder := Node3D.new()
			holder.name = "Г_%d_%d" % [ri, ci]
			holder.position = Vector3(_col_x(ci, cols.size()), 0, z)
			add_child(holder)
			var model := scene.instantiate() as Node3D
			holder.add_child(model)
			_game_materials(model, amb, amb_e, method)
			var box := _aabb(model)
			var s := HEIGHT_M / maxf(box.size.y, 0.001)
			model.scale = Vector3.ONE * s
			model.position.y = -box.position.y * s
			# Дзьобом до камери (+Z). Нові моделі з Blender і так дивляться в +Z.
			var rig := GooseRig.new()
			if rig.build(model):
				rig.state = String(cols[ci])
				_rigs.append([rig, model, model.position.y, s])


func _col_x(ci: int, n: int) -> float:
	return (float(ci) - float(n - 1) * 0.5) * COL_GAP


func _label(text: String, col: Color) -> Label3D:
	var lb := Label3D.new()
	lb.text = text
	lb.pixel_size = 0.004
	lb.font_size = 40
	lb.outline_size = 10
	lb.modulate = col
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return lb


## Габарит усіх мешів моделі в її власних координатах (у спокої).
func _aabb(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b: AABB = model.global_transform.affine_inverse() * m.global_transform * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Рівно те, що робить гра з матеріалами декору (як у awning_compare.gd).
func _game_materials(model: Node, amb: Color, amb_e: float, method: String) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for si in range(m.mesh.get_surface_count()):
			var bm := m.mesh.surface_get_material(si) as BaseMaterial3D
			if bm == null:
				continue
			bm = bm.duplicate(true)
			bm.normal_enabled = false
			bm.normal_texture = null
			bm.metallic = 0.0
			bm.metallic_texture = null
			bm.cull_mode = BaseMaterial3D.CULL_BACK
			bm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
			bm.disable_ambient_light = true
			bm.emission_enabled = true
			var tex := bm.albedo_texture
			bm.emission_texture = tex
			bm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY if tex != null \
				else BaseMaterial3D.EMISSION_OP_ADD
			var ac := bm.albedo_color
			bm.emission = Color(amb.r * ac.r, amb.g * ac.g, amb.b * ac.b)
			bm.emission_energy_multiplier = Track.emission_energy_for(amb_e, method)
			m.set_surface_override_material(si, bm)
