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

## Оригінал нової моделі лежить у assets/props/_exp/_src/ — він 32 МБ (текстури 4096²), тож
## у git і в збірки не йде. На свіжій копії репозиторію його там немає, і сцена покаже решту.
##
## Два ряди. Ближній — нова модель house_terra_6_optimize і її спрощення; дальній — те,
## що вже було (house_terra_6, що стоїть у грі). Вершини підписано ТАК, ЯК ЇХ РАХУЄ GODOT:
## саме вершини, а не трикутники, визначають ціну хати (заміряно 25.09). Спрощення нової
## моделі експортовано з пласким затіненням граней, тож у них вершин утричі більше, ніж
## трикутників, — і 6000 виходить ВАЖЧИМ за нинішню хату, хоч трикутників у них порівну.
const ROWS := [
	["НОВА: house_terra_6_optimize", [
		["ОРИГІНАЛ\n26611 верш", "res://assets/props/_exp/_src/house_terra_6_optimize.glb"],
		["8000 тр\n23985 верш", "res://assets/props/_exp/house_terra_6_opt8000.glb"],
		["6000 тр\n17985 верш", "res://assets/props/_exp/house_terra_6_opt6000.glb"],
		["4000 тр\n11988 верш", "res://assets/props/_exp/house_terra_6_opt4000.glb"],
		["2000 тр\n5985 верш", "res://assets/props/_exp/house_terra_6_opt2000.glb"],
		["1200 тр\n3585 верш", "res://assets/props/_exp/house_terra_6_opt1200.glb"],
		["600 оболонка\n1800 верш", "res://assets/props/_exp/house_terra_6_optimize_proxy600.glb"],
	]],
	["У ГРІ ЗАРАЗ: house_terra_6", [
		["ОРИГІНАЛ\n8360 верш", "res://assets/props/house_terra_6.glb"],
		["ОБОЛОНКА 1200\n3600 верш · −2,1 мс", "res://assets/props/_exp/house_terra_6_proxy1200.glb"],
		["ОБОЛОНКА 600\n1800 верш · −3,9 мс", "res://assets/props/_exp/house_terra_6_proxy600.glb"],
		["СПРАЙТ 8 БОКІВ\n4 верш · −5,0 мс", "res://assets/props/_exp/house_terra_6_sprite8.png"],
	]],
]
## Відстань між рядами, м.
const ROW_GAP := 6.5

## Спрайт: скільки метрів покриває кадр атласу (з house_terra_6_sprite8.json, його пише
## src/debug/prop_sprite.gd) і на скільки хата в кадрі піднята над його нижнім краєм.
## Знімок центрує габарит моделі, а хата 2,1 м у квадраті 2,268 м — тож без поправки
## спрайт висів би над землею на 8 см.
const SPRITE_SPAN_M := 2.268
const SPRITE_LIFT_M := (2.268 - 2.1) * 0.5

## Відстань між хатами, м.
@export var spacing := 3.0:
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
	($Камера as Camera3D).look_at_from_position(Vector3(0.0, 5.8, 10.5), Vector3(0, 1.0, -3.0))
	var method := RenderingServer.get_current_rendering_method()
	var k: float = load("res://src/run3d/run3d.gd").light_scale_for(method)
	var env := ($Світ as WorldEnvironment).environment
	# Ті самі числа, що й у грі: сонце 0,9, навколишнє 0,35, обидва помножені на поправку рушія.
	env.ambient_light_energy = 0.35 * k
	($Сонце as DirectionalLight3D).light_energy = 0.9 * k
	var amb := env.ambient_light_color
	var amb_e := env.ambient_light_energy
	var idx := 0
	var widest := 0
	for row in ROWS:
		widest = maxi(widest, (row[1] as Array).size())
	for r in range(ROWS.size()):
		var items: Array = ROWS[r][1]
		var z := -float(r) * ROW_GAP
		var title := Label3D.new()
		title.name = "ХатаРяд%d" % r
		title.text = String(ROWS[r][0])
		# Назва ряду — над його центром, жовтим, щоб не плутати з підписами хат.
		title.position = Vector3(0, 3.5, z)
		title.pixel_size = 0.005; title.font_size = 48; title.outline_size = 12
		title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		title.modulate = Color(1.0, 0.95, 0.6)
		add_child(title)
		for i in range(items.size()):
			var holder := Node3D.new()
			holder.name = "Хата%d" % idx
			idx += 1
			holder.position = Vector3((float(i) - float(items.size() - 1) * 0.5) * spacing, 0, z)
			add_child(holder)
			var mi := MeshInstance3D.new()
			var path := String(items[i][1])
			if path.ends_with(".png"):
				# Спрайт будуємо ТИМ САМИМ шляхом, що й гра (PropLibrary._sprite_mesh).
				mi.mesh = PropLibrary._sprite_mesh({"sprite": path, "height": SPRITE_SPAN_M, "frames": 8})
				mi.position.y = -SPRITE_LIFT_M
			else:
				mi.mesh = _mesh_of(path, amb, amb_e, method)
				# СТАВИМО НА ЗЕМЛЮ за габаритом: у house_terra_6_optimize точка відліку в
				# ЦЕНТРІ моделі, а не біля основи, як у наших хат, — без поправки вона
				# загрузла б наполовину. Для гри таку модель треба буде переставити.
				if mi.mesh != null:
					mi.position.y = -mi.mesh.get_aabb().position.y
			holder.add_child(mi)
			var lb := Label3D.new()
			lb.text = String(items[i][0])
			lb.position = Vector3(0, 2.6, 0)
			lb.pixel_size = 0.0045
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
