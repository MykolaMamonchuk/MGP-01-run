## Знімок РОЗБИТТЯ предмета: серія кадрів одразу після удару.
##
##   OUT=/tmp/shatter KIND=stump WORLD=meadow FRAMES=14 \
##     /Applications/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 res://src/debug/shatter_shot.tscn
##
## `--fixed-fps 60` ОБОВ'ЯЗКОВИЙ. Кожен кадр тут зберігається у PNG, а це сотні мілісекунд,
## тож без фіксованої дельти ефект старіє на цілу секунду за вісім кадрів і на знімках видно
## лише його кінець. Наступив на це 18.09.2026: здавалось, що друзки зникають миттєво.
##
## Навіщо окрема сцена, а не проба живої гри. Розбиття вмикає суперсила «Роги напролом», яка
## випадає рідко, і спіймати її знімком у справжньому забігу — довго й ненадійно (перевірено:
## перешкода не встигає під'їхати за задане число кадрів, а чекати «поки під'їде» всередині
## проби вішає її). Тут той САМИЙ код: справжній Obstacle3D із опису світу, справжній
## shatter(). Міняється лише те, що навколо нього нема рівня.
##
## Запускати БЕЗ --headless: у headless нічого не малюється.
extends Node

var _out: String = OS.get_environment("OUT") if OS.has_environment("OUT") else "shatter"
var _kind: String = OS.get_environment("KIND") if OS.has_environment("KIND") else "stump"
var _world: String = OS.get_environment("WORLD") if OS.has_environment("WORLD") else "meadow"
var _frames: int = int(OS.get_environment("FRAMES")) if OS.has_environment("FRAMES") else 14


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var f := FileAccess.open("res://data/worlds/%s.json" % _world, FileAccess.READ)
	if f == null:
		push_error("нема світу %s" % _world)
		get_tree().quit(1)
		return
	var world: Dictionary = JSON.parse_string(f.get_as_text())
	var defs: Dictionary = world.get("obstacles", {})
	if not defs.has(_kind):
		push_error("у світі %s нема перешкоди %s" % [_world, _kind])
		get_tree().quit(1)
		return

	# земля — щоб було видно, як шматки на неї падають
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Palette.WORLD_GROUND
	gm.roughness = 1.0
	ground.material_override = gm
	add_child(ground)

	var host := Node3D.new()
	add_child(host)
	var ob := Obstacle3D.new()
	host.add_child(ob)
	ob.setup(_kind, defs[_kind], 0, false)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.3
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Palette.SKY_DAY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Palette.WHITE
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.1, 2.6)
	cam.rotation_degrees = Vector3(-14, 0, 0)
	add_child(cam)
	cam.make_current()

	await _wait(6)                      # дати моделі стати на місце
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/before.png" % _out)
	ob.shatter()
	for i in range(_frames):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/f_%02d.png" % [_out, i])
	print("розбиття %s → %s (%d кадрів)" % [_kind, _out, _frames])
	get_tree().quit()


func _wait(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
