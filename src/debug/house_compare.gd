@tool
extends Node3D

## ПОРІВНЯННЯ ХАТИ: оригінал, запечена оболонка 1200 і 600 — так, як їх малює ГРА.
##
## Відкрити в редакторі й обертати камеру. Або запустити (F6), щоб побачити з ігрової камери.
##
## Навіщо окрема сцена, а не просто три .glb поряд. Сирі .glb у редакторі мають карти
## нормалей, світло на піксель і звичайне навколишнє світло — а гра все це міняє: карти
## нормалей знімає, світло рахує на вершину, навколишнє світло віддає випроміненню. Без цієї
## обробки ти порівнював би не те, що побачить дитина.
##
## РУШІЙ. Телефон і веб працюють у Compatibility, а редактор — у рушії проєкту (Mobile). Сцена
## підлаштовує світло під той рушій, яким її відкрито (як і гра), тож виглядає правильно в
## обох. Щоб побачити ТОЧНО як на телефоні — перемкни рушій редактора на Compatibility
## (праворуч угорі, перезапуск редактора) або запусти:
##   /Applications/Godot.app/Contents/MacOS/Godot --rendering-method gl_compatibility \
##       res://src/debug/house_compare.tscn

const VARIANTS := [
	["ОРИГІНАЛ\n5998 тр · 8360 верш",
		"res://assets/props/house_terra_6.glb"],
	["ОБОЛОНКА 1200\n3600 верш · −2,1 мс",
		"res://assets/props/_exp/house_terra_6_proxy1200.glb"],
	["ОБОЛОНКА 600\n1800 верш · −3,1 мс",
		"res://assets/props/_exp/house_terra_6_proxy600.glb"],
	["СПРАЙТ З 8 БОКІВ\n4 верш · обертай камеру",
		"res://assets/props/_exp/house_terra_6_sprite8.png"],
]

## Спрайт: скільки метрів покриває кадр атласу (з house_terra_6_sprite8.json, його пише
## src/debug/prop_sprite.gd) і на скільки хата в кадрі піднята над його нижнім краєм.
## Знімок центрує габарит моделі, а хата 2,1 м у квадраті 2,268 м — тож без поправки
## спрайт висів би над землею на 8 см.
const SPRITE_SPAN_M := 2.268
const SPRITE_LIFT_M := (2.268 - 2.1) * 0.5

## Відстань між хатами, м.
@export var spacing := 3.4:
	set(v):
		spacing = v
		if is_inside_tree(): _build()
## Обробка матеріалів як у грі. Вимкни — побачиш сирі моделі.
@export var as_in_game := true:
	set(v):
		as_in_game = v
		if is_inside_tree(): _build()


func _ready() -> void:
	_build()


func _build() -> void:
	for c in get_children():
		if String(c.name).begins_with("Хата"):
			remove_child(c)
			c.queue_free()
	# Камера — як у грі: трохи збоку й згори, фасади до неї.
	($Камера as Camera3D).look_at_from_position(Vector3(2.0, 2.4, 7.8), Vector3(0, 1.1, 0))
	var method := RenderingServer.get_current_rendering_method()
	var k: float = load("res://src/run3d/run3d.gd").light_scale_for(method)
	var env := ($Світ as WorldEnvironment).environment
	# Ті самі числа, що й у грі: сонце 0,9, навколишнє 0,35, обидва помножені на поправку рушія.
	env.ambient_light_energy = 0.35 * k
	($Сонце as DirectionalLight3D).light_energy = 0.9 * k
	var amb := env.ambient_light_color
	var amb_e := env.ambient_light_energy
	for i in range(VARIANTS.size()):
		var holder := Node3D.new()
		holder.name = "Хата%d" % i
		holder.position = Vector3((float(i) - float(VARIANTS.size() - 1) * 0.5) * spacing, 0, 0)
		add_child(holder)
		var mi := MeshInstance3D.new()
		var path := String(VARIANTS[i][1])
		if path.ends_with(".png"):
			# Спрайт будуємо ТИМ САМИМ шляхом, що й гра (PropLibrary._sprite_mesh): дощечка з
			# шейдером, що довертає її до камери й бере з атласу потрібний бік. Світло
			# вже вмальоване в картинку, тож обробка матеріалів тут не потрібна.
			mi.mesh = PropLibrary._sprite_mesh({"sprite": path, "height": SPRITE_SPAN_M, "frames": 8})
			mi.position.y = -SPRITE_LIFT_M
		else:
			mi.mesh = _mesh_of(path, amb, amb_e, method)
		holder.add_child(mi)
		var lb := Label3D.new()
		lb.text = String(VARIANTS[i][0])
		lb.position = Vector3(0, 2.7, 0)
		lb.pixel_size = 0.0035
		lb.font_size = 44
		lb.outline_size = 10
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		holder.add_child(lb)


## Сітка з файлу — КОПІЯ, щоб правки матеріалів не потрапили в імпортований ресурс.
func _mesh_of(path: String, amb: Color, amb_e: float, method: String) -> Mesh:
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("немає моделі: %s" % path)
		return null
	var root := scene.instantiate()
	var found: Mesh = null
	var stack: Array = [root]
	while not stack.is_empty() and found == null:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			found = (n as MeshInstance3D).mesh
		stack.append_array(n.get_children())
	root.free()
	if found == null:
		return null
	var m := found.duplicate(true) as Mesh
	if not as_in_game:
		return m
	for si in range(m.get_surface_count()):
		var bm := m.surface_get_material(si) as BaseMaterial3D
		if bm == null:
			continue
		bm = bm.duplicate(true)
		m.surface_set_material(si, bm)
		# Рівно те, що робить гра (PropLibrary._drop_normal_maps і Track.apply_decor_shading).
		bm.normal_enabled = false
		bm.normal_texture = null
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
	return m
