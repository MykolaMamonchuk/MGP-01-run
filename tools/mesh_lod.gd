## Спрощення сітки ЯКІСНИМ різаком — тим самим meshoptimizer, яким Godot робить LOD-и.
##
## Навіщо. Blender'івський Decimate шматує стилізовану черепицю: на 3000 граней дах будинку
## перетворюється на горби, і замовник це одразу побачив («особливо черепиця, коли герой
## стає ближче»). meshoptimizer зберігає силует і шви значно краще, бо рахує помилку по
## поверхні, а не жадібно схлопує ребра.
##
## Запуск (БЕЗ --headless не треба, тут нічого не малюється):
##   SRC=res://docs/refs/incoming/house_terra/house_terra_8.glb \
##   OUT=res://assets/props/house_terra.tscn TRIS=3000 \
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/mesh_lod.gd
##
## Пише .tscn з одним MeshInstance3D — PropLibrary.mesh() бере перший меш зі сцени, тож для
## гри це те саме, що й .glb.
extends SceneTree


func _init() -> void:
	var src := OS.get_environment("SRC")
	var out := OS.get_environment("OUT")
	var want := int(OS.get_environment("TRIS")) if OS.has_environment("TRIS") else 3000
	if src == "" or out == "":
		print("треба SRC= і OUT=")
		quit(1)
		return
	var packed := load(src) as PackedScene
	if packed == null:
		print("не вантажиться: ", src)
		quit(1)
		return
	var root := packed.instantiate()
	var mi := _first_mesh_instance(root)
	if mi == null:
		print("у сцені нема MeshInstance3D")
		quit(1)
		return
	var mesh := mi.mesh as ArrayMesh
	print("вихідна сітка: %d поверхонь" % mesh.get_surface_count())

	# ImporterMesh — той самий шлях, яким іде імпортер; generate_lods() кличе meshoptimizer.
	var im := ImporterMesh.new()
	for s in range(mesh.get_surface_count()):
		im.add_surface(mesh.surface_get_primitive_type(s), mesh.surface_get_arrays(s),
			[], {}, mesh.surface_get_material(s), "", mesh.surface_get_format(s))
	im.generate_lods(25.0, 60.0, [])

	var built := ArrayMesh.new()
	for s in range(im.get_surface_count()):
		var arrays := im.get_surface_arrays(s)
		var best := -1
		var best_tris := 0
		# LOD 0 — оригінал; далі кожен наступний удвічі грубіший. Беремо найдетальніший,
		# що вкладається в бюджет, а якщо жоден не вклався — найгрубіший, який є.
		for lod in range(im.get_surface_lod_count(s)):
			var tris := im.get_surface_lod_indices(s, lod).size() / 3
			print("  поверхня %d, LOD %d: %d трикутників" % [s, lod, tris])
			if tris <= want and (best < 0 or tris > best_tris):
				best = lod
				best_tris = tris
		if best >= 0:
			arrays[Mesh.ARRAY_INDEX] = im.get_surface_lod_indices(s, best)
			print("  → взято LOD %d (%d трикутників)" % [best, best_tris])
		else:
			print("  → жоден LOD не вклався в %d, лишаємо як є" % want)
		built.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays)
		built.surface_set_material(built.get_surface_count() - 1, mesh.surface_get_material(s))

	var node := MeshInstance3D.new()
	node.mesh = built
	node.name = "Prop"
	var scene := PackedScene.new()
	scene.pack(node)
	var err := ResourceSaver.save(scene, out)
	print("записано %s (помилка %d)" % [out, err])
	quit(0 if err == OK else 1)


func _first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _first_mesh_instance(child)
		if found != null:
			return found
	return null
