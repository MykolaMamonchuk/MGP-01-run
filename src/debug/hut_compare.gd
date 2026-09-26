@tool
extends Node3D

## ПОРІВНЯННЯ ХАТИНКИ ЗА МАЛЮНКОМ: три варіанти геометрії × три розміри текстури — як їх малює
## ГРА (без карт нормалей, світло на вершину, навколишнє світло випроміненням; див.
## awning_compare.gd). Модель і текстури будує tools/make_hut.py.
##
## Ряди — геометрія: повна (~4800 вершин), ~3000 і ~1500. Стовпчики — текстура 1024/512/256.
## Під кожною хатинкою: вершини й трикутники так, як їх рахує Godot, і скільки текстура займає
## у ВІДЕОПАМ'ЯТІ (стиснена, з mipmap-рівнями — саме це важить на телефоні) і на диску.
## Ліворуч — малюнок замовника (docs/refs/incoming/hut/hut_test_draw.jpg, не в git; нема
## файла — нема й картинки, решта сцени працює).
##
## Відкрити в редакторі й обертати камеру, або запустити (F6). Точно як на телефоні:
##   /Applications/Godot.app/Contents/MacOS/Godot --rendering-method gl_compatibility \
##       res://src/debug/hut_compare.tscn
const DIR := "res://assets/props/_exp/hut/"
const DETAILS := [["ПОВНА", "high"], ["~3000 ВЕРШИН", "mid"], ["~1500 ВЕРШИН", "low"]]
const SIZES := [1024, 512, 256]
const REF := "res://docs/refs/incoming/hut/hut_test_draw.jpg"

const COL_GAP := 2.6
const ROW_GAP := 3.4


func _ready() -> void:
	_build()


func _build() -> void:
	for c in get_children():
		if String(c.name).begins_with("Х_"):
			remove_child(c)
			c.queue_free()
	($Камера as Camera3D).look_at_from_position(Vector3(-1.2, 9.0, 9.5), Vector3(-1.2, 0.2, -3.0))
	($Камера as Camera3D).fov = 42.0
	var method := RenderingServer.get_current_rendering_method()
	var k: float = load("res://src/run3d/run3d.gd").light_scale_for(method)
	var env := ($Світ as WorldEnvironment).environment
	env.ambient_light_energy = 0.35 * k
	($Сонце as DirectionalLight3D).light_energy = 0.9 * k
	var amb := env.ambient_light_color
	var amb_e := env.ambient_light_energy
	for ci in range(SIZES.size()):
		var t := _label("ТЕКСТУРА %d" % SIZES[ci], Color(1.0, 0.95, 0.6), 44)
		t.name = "Х_стовп%d" % ci
		t.position = Vector3(_x(ci), 0.1, 2.2)
		add_child(t)
	for ri in range(DETAILS.size()):
		var z := -float(ri) * ROW_GAP
		var path := DIR + "hut_%s.glb" % DETAILS[ri][1]
		var title := _label(String(DETAILS[ri][0]), Color(1, 1, 1), 40)
		title.name = "Х_ряд%d" % ri
		title.position = Vector3(_x(0) - 2.0, 0.6, z)
		add_child(title)
		for ci in range(SIZES.size()):
			var tex_path := DIR + "hut_%s_%d.jpg" % [DETAILS[ri][1], SIZES[ci]]
			var mesh := _mesh_of(path, tex_path, amb, amb_e, method)
			if mesh == null:
				continue
			var mi := MeshInstance3D.new()
			mi.name = "Х_%d_%d" % [ri, ci]
			mi.mesh = mesh
			mi.position = Vector3(_x(ci), -mesh.get_aabb().position.y, z)
			add_child(mi)
			var lb := _label(_stats(mesh, tex_path), Color(1, 1, 1), 26)
			lb.name = "Х_підпис_%d_%d" % [ri, ci]
			lb.position = Vector3(_x(ci), 0.05, z + 1.0)
			add_child(lb)
	# Малюнок замовника — поруч, на дощечці, щоб порівнювати в тому самому світлі кадру.
	# docs/ рушій не імпортує (.gdignore), тож картинку читаємо просто з диска.
	var ref_img := Image.load_from_file(ProjectSettings.globalize_path(REF))
	if ref_img != null and not ref_img.is_empty():
		var q := MeshInstance3D.new()
		q.name = "Х_малюнок"
		var qm := QuadMesh.new()
		qm.size = Vector2(3.0, 3.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = ImageTexture.create_from_image(ref_img)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.material = mat
		q.mesh = qm
		q.position = Vector3(_x(0) - 4.4, 1.2, -ROW_GAP)
		add_child(q)


func _x(ci: int) -> float:
	return (float(ci) - 1.0) * COL_GAP


func _label(text: String, col: Color, size: int) -> Label3D:
	var lb := Label3D.new()
	lb.text = text
	lb.pixel_size = 0.004
	lb.font_size = size
	lb.outline_size = 10
	lb.modulate = col
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return lb


## Вершини й трикутники — як їх рахує Godot (шви розгортки розщеплюють вершини); текстура —
## скільки займає у відеопам'яті стиснена з mipmap-рівнями, і скільки на диску.
func _stats(mesh: Mesh, tex_path: String) -> String:
	var verts := 0
	var tris := 0
	for si in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(si)
		verts += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var idx = a[Mesh.ARRAY_INDEX]
		tris += (idx.size() if idx != null else 0) / 3
	var vram := 0
	var tex := load(tex_path) as Texture2D
	if tex != null:
		vram = tex.get_image().get_data().size()
	var disk := 0
	var f := FileAccess.open(tex_path, FileAccess.READ)
	if f != null:
		disk = f.get_length()
	return "%d верш · %d тр\nтекстура: %d КБ у пам'яті\n%d КБ на диску" % [verts, tris, vram / 1024, disk / 1024]


## Сітка з файлу — КОПІЯ з матеріалом, як у грі (awning_compare.gd), і з обраною текстурою.
func _mesh_of(path: String, tex_path: String, amb: Color, amb_e: float, method: String) -> Mesh:
	if not ResourceLoader.exists(path):
		push_warning("немає моделі: %s" % path)
		return null
	var root := (load(path) as PackedScene).instantiate()
	var found: Mesh = null
	for n in root.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).mesh != null:
			found = (n as MeshInstance3D).mesh
			break
	root.free()
	if found == null:
		return null
	var m := found.duplicate(true) as Mesh
	var tex: Texture2D = load(tex_path) if ResourceLoader.exists(tex_path) else null
	for si in range(m.get_surface_count()):
		var bm := m.surface_get_material(si) as BaseMaterial3D
		if bm == null:
			continue
		bm = bm.duplicate(true)
		m.surface_set_material(si, bm)
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
	return m
