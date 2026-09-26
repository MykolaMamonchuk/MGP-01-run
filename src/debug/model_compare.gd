@tool
extends Node3D

## ПОРІВНЯННЯ МОДЕЛЕЙ «ЗА МАЛЮНКОМ» (tools/modelkit): як їх малює ГРА — без карт нормалей,
## світло на вершину, навколишнє світло випроміненням (див. awning_compare.gd).
##
## Два режими (поле `all_models` в інспекторі):
##   • одна модель (`model`) — сітка 3×3: ряди — геометрія (повна / ~3000 / ~1500 вершин),
##     стовпчики — текстура 1024 / 512 / 256; ліворуч — малюнок замовника;
##   • усі моделі — рядок на модель, стовпчики — план якості замовника (26.09): СИЛЬНІ (повна +
##     1024), СЕРЕДНІ (~3000 + 512), СЛАБКІ (~3000 + 256) і для порівняння НАЙПРОСТІША (~1500 + 256).
## Під кожною — вершини й трикутники так, як їх рахує Godot, і скільки текстура займає у
## відеопам'яті (стиснена, з mipmap) і на диску.
##
## Живе: крила млина крутяться (вузол «sails»), сосна гойдається на вітрі (кістки скелета).
##   /Applications/Godot.app/Contents/MacOS/Godot --rendering-method gl_compatibility \
##       res://src/debug/model_compare.tscn
const ROOT := "res://assets/props/_exp/models/"
const MODELS := ["hut", "hut_2", "hut_3", "kiosk_1", "mill_1", "pine_3_2"]
const REFS := "res://docs/refs/incoming/test_models/%s_test_draw"

@export_enum("hut", "hut_2", "hut_3", "kiosk_1", "mill_1", "pine_3_2") var model := "hut":
	set(v):
		model = v
		if is_inside_tree(): _build()
@export var all_models := false:
	set(v):
		all_models = v
		if is_inside_tree(): _build()

var _sails: Array[Node3D] = []
var _rigs: Array[Skeleton3D] = []
var _t := 0.0


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	_t += delta
	for s in _sails:
		if is_instance_valid(s):
			s.rotation.z = -_t * 1.4          # крила — навколо осі до камери
	for sk in _rigs:
		if not is_instance_valid(sk):
			continue
		# Вітер: кожна кістка вище — трохи більше, з запізненням, як справжнє дерево.
		for i in sk.get_bone_count():
			var a := sin(_t * 1.7 - float(i) * 0.5) * 0.035 * float(i)
			var rest := sk.get_bone_rest(i).basis.get_rotation_quaternion()
			sk.set_bone_pose_rotation(i, rest * Quaternion(Vector3(0, 0, 1), a) * Quaternion(Vector3(1, 0, 0), a * 0.5))


func _build() -> void:
	_sails.clear()
	_rigs.clear()
	for c in get_children():
		if String(c.name).begins_with("М_"):
			remove_child(c)
			c.queue_free()
	var method := RenderingServer.get_current_rendering_method()
	var k: float = load("res://src/run3d/run3d.gd").light_scale_for(method)
	var env := ($Світ as WorldEnvironment).environment
	env.ambient_light_energy = 0.35 * k
	($Сонце as DirectionalLight3D).light_energy = 0.9 * k
	var cells: Array = []   # [ряд, стовпчик, модель, деталізація, текстура, підпис ряду]
	var cols: Array
	if all_models:
		cols = [["СИЛЬНІ\nповна + 1024", "high", 1024], ["СЕРЕДНІ\n~3000 + 512", "mid", 512],
			["СЛАБКІ\n~3000 + 256", "mid", 256], ["НАЙПРОСТІША\n~1500 + 256", "low", 256]]
		for ri in MODELS.size():
			for ci in cols.size():
				cells.append([ri, ci, MODELS[ri], cols[ci][1], cols[ci][2], MODELS[ri]])
	else:
		cols = [["ТЕКСТУРА 1024", "", 1024], ["ТЕКСТУРА 512", "", 512], ["ТЕКСТУРА 256", "", 256]]
		var rows := [["ПОВНА", "high"], ["~3000 ВЕРШИН", "mid"], ["~1500 ВЕРШИН", "low"]]
		for ri in rows.size():
			for ci in cols.size():
				cells.append([ri, ci, model, rows[ri][1], cols[ci][2], rows[ri][0]])
	var col_gap := 2.8
	var row_gap := 3.2
	var n_rows := MODELS.size() if all_models else 3
	var cam := $Камера as Camera3D
	cam.fov = 42.0
	var mid_z := -float(n_rows - 1) * row_gap * 0.5
	cam.look_at_from_position(Vector3(-1.0, 3.0 + float(n_rows) * 1.25, 4.0 + float(n_rows) * 1.5),
		Vector3(-1.0, 0.3, mid_z))
	for ci in cols.size():
		var t := _label(String(cols[ci][0]), Color(1.0, 0.95, 0.6), 40)
		t.name = "М_стовп%d" % ci
		t.position = Vector3(_x(ci, cols.size(), col_gap), 0.1, 2.0)
		add_child(t)
	var seen_rows := {}
	for c in cells:
		var ri: int = c[0]
		var ci: int = c[1]
		var z := -float(ri) * row_gap
		if not seen_rows.has(ri):
			seen_rows[ri] = true
			var title := _label(String(c[5]).to_upper(), Color(1, 1, 1), 40)
			title.name = "М_ряд%d" % ri
			title.position = Vector3(_x(0, cols.size(), col_gap) - 2.2, 0.6, z)
			add_child(title)
		var base := ROOT + "%s/%s_%s" % [c[2], c[2], c[3]]
		var inst := _instance(base + ".glb", base + "_%d.jpg" % c[4])
		if inst == null:
			continue
		inst.name = "М_%d_%d" % [ri, ci]
		inst.position = Vector3(_x(ci, cols.size(), col_gap), 0, z)
		add_child(inst)
		var lb := _label(_stats(inst, base + "_%d.jpg" % c[4]), Color(1, 1, 1), 24)
		lb.name = "М_підпис_%d_%d" % [ri, ci]
		lb.position = Vector3(_x(ci, cols.size(), col_gap), 0.05, z + 1.1)
		add_child(lb)
	if not all_models:
		_add_ref(model, Vector3(_x(0, cols.size(), col_gap) - 4.6, 1.3, -row_gap))


func _x(ci: int, n: int, gap: float) -> float:
	return (float(ci) - float(n - 1) * 0.5) * gap


func _label(text: String, col: Color, size: int) -> Label3D:
	var lb := Label3D.new()
	lb.text = text
	lb.pixel_size = 0.004
	lb.font_size = size
	lb.outline_size = 10
	lb.modulate = col
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return lb


## Малюнок замовника поруч (docs/ рушій не імпортує — читаємо з диска; нема — нема картинки).
func _add_ref(name: String, pos: Vector3) -> void:
	var img: Image = null
	for ext in [".jpg", ".png"]:
		var p := ProjectSettings.globalize_path(REFS % name + ext)
		if FileAccess.file_exists(p):
			img = Image.load_from_file(p)
			break
	if img == null or img.is_empty():
		return
	var q := MeshInstance3D.new()
	q.name = "М_малюнок"
	var qm := QuadMesh.new()
	qm.size = Vector2(3.0, 3.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	qm.material = mat
	q.mesh = qm
	q.position = pos
	add_child(q)


## Ціла сцена моделі (з рухомими частинами й скелетом), матеріали — як у грі, обрана текстура.
func _instance(path: String, tex_path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("немає моделі: %s" % path)
		return null
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	var method := RenderingServer.get_current_rendering_method()
	var env := ($Світ as WorldEnvironment).environment
	var amb := env.ambient_light_color
	var amb_e := env.ambient_light_energy
	var tex: Texture2D = load(tex_path) if ResourceLoader.exists(tex_path) else null
	var lo := INF
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		lo = minf(lo, (m.transform * m.mesh.get_aabb()).position.y)
		for si in m.mesh.get_surface_count():
			var bm := (m.mesh.surface_get_material(si) as BaseMaterial3D)
			if bm == null:
				continue
			bm = bm.duplicate(true)
			if tex != null:
				bm.albedo_texture = tex
			bm.normal_enabled = false
			bm.cull_mode = BaseMaterial3D.CULL_BACK
			bm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
			bm.disable_ambient_light = true
			bm.emission_enabled = true
			bm.emission_texture = bm.albedo_texture
			bm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			var ac := bm.albedo_color
			bm.emission = Color(amb.r * ac.r, amb.g * ac.g, amb.b * ac.b)
			bm.emission_energy_multiplier = Track.emission_energy_for(amb_e, method)
			m.set_surface_override_material(si, bm)
	var sails := inst.find_child("sails", true, false) as Node3D
	if sails != null:
		_sails.append(sails)
	for sk in inst.find_children("*", "Skeleton3D", true, false):
		_rigs.append(sk as Skeleton3D)
	return inst


## Вершини й трикутники (усі меші моделі разом) і вага текстури в пам'яті та на диску.
func _stats(inst: Node3D, tex_path: String) -> String:
	var verts := 0
	var tris := 0
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for si in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(si)
			verts += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var idx = a[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else 0) / 3
	var vram := 0
	var tex := load(tex_path) as Texture2D if ResourceLoader.exists(tex_path) else null
	if tex != null:
		vram = tex.get_image().get_data().size()
	var disk := 0
	var f := FileAccess.open(tex_path, FileAccess.READ)
	if f != null:
		disk = f.get_length()
	return "%d верш · %d тр\n%d КБ у пам'яті · %d КБ диск" % [verts, tris, vram / 1024, disk / 1024]
