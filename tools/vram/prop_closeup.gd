## Знімок пропса ЗБЛИЗЬКА — щоб порівняти налаштування ІМПОРТУ, а не моделі.
##
##   OUT=/tmp/a PROPS=cart_market_1,house_terra /Applications/Godot.app/Contents/MacOS/Godot \
##     --path . --fixed-fps 60 res://tools/vram/prop_closeup.tscn
##
## Навіщо окремо від `tools/prop_render.py`. Той знімає Blender'ом із вихідного `.glb`, тобто
## бачить текстуру такою, як її поклав автор. Питання «чи псує вигляд `process/size_limit=512`
## у `.import`» він не бачить ЗОВСІМ: обмеження живе в Godot і застосовується при імпорті.
## Тому знімати треба рушієм.
##
## Камера підганяється під габарит моделі, тож різні за розміром пропси лягають у кадр
## однаково — і різниця між знімками є різницею між налаштуваннями, а не кадруванням.
## БЕЗ `--headless`: у headless 3D не малюється.
extends Node3D

const SIZE := 512


func _ready() -> void:
	var out: String = OS.get_environment("OUT") if OS.has_environment("OUT") else "user://closeup"
	DirAccess.make_dir_recursive_absolute(out)
	var names: PackedStringArray = (OS.get_environment("PROPS") if OS.has_environment("PROPS")
		else "cart_market_1").split(",")

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	light.light_energy = 1.2
	add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.5, 0.55, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.environment.ambient_light_energy = 0.8
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)

	for name in names:
		var scene: PackedScene = load("res://assets/props/%s.glb" % name)
		if scene == null:
			push_warning("нема моделі %s" % name)
			continue
		var node: Node3D = scene.instantiate()
		add_child(node)
		await get_tree().process_frame
		var box := _aabb(node)
		# камера строго по габариту: 3/4 з боку, відстань від найбільшої сторони
		var r: float = maxf(box.size.length(), 0.01)
		cam.global_position = box.get_center() + Vector3(0.62, 0.45, 0.78).normalized() * r * 1.15
		cam.look_at(box.get_center())
		for i in range(6):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
		print("знято %s, габарит %.2f x %.2f x %.2f м" % [name, box.size.x, box.size.y, box.size.z])
		node.queue_free()
		await get_tree().process_frame

	get_tree().quit()


## Габарит у СВІТОВИХ координатах: у `.glb` меш часто лежить під власним трансформом, і
## локальний AABB дав би камері не ту відстань.
func _aabb(root: Node) -> AABB:
	var box := AABB()
	var first := true
	for m in _meshes(root):
		var world := m.global_transform * m.get_aabb()
		if first:
			box = world
			first = false
		else:
			box = box.merge(world)
	return box


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_meshes(child))
	return found
