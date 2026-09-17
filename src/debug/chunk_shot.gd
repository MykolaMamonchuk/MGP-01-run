## Знімок одного чанка рівня — щоб бачити карту, не відкриваючи редактор.
##
##   OUT=/tmp/chunk.png LEVEL=1 CHUNK=1 \
##     /Applications/Godot.app/Contents/MacOS/Godot --path . res://src/debug/chunk_shot.tscn
##
## Показує те саме, що й редактор: дорогу-орієнтир LevelLayout і прев'ю кожного маркера
## (справжня модель, інакше воксель, інакше кольорова заглушка за роллю). Потрібен саме для
## приймання розкладки: «порожній чанк» тепер видно як порожній, а не як недомальований.
##
## Запускати БЕЗ --headless: у headless Godot не малює взагалі.
##
## VIEW=top — вид зверху, дорога лежить УПОПЕРЕК кадру (інакше 150 м у висоту нечитабельні);
##             FROM=0 SPAN=50 — з якого метра чанка й скільки метрів показати;
## VIEW=run (типово) — з-за спини героя, приблизно як у грі; FROM задає, звідки дивитись.
extends Node

var _out: String = OS.get_environment("OUT") if OS.has_environment("OUT") else "chunk.png"
var _level: int = int(OS.get_environment("LEVEL")) if OS.has_environment("LEVEL") else 1
var _chunk: int = int(OS.get_environment("CHUNK")) if OS.has_environment("CHUNK") else 0


func _ready() -> void:
	var path := "res://levels/level_%02d/chunk_%02d.tscn" % [_level, _chunk]
	if not ResourceLoader.exists(path):
		push_error("нема такого чанка: %s" % path)
		get_tree().quit(1)
		return
	var layout := (load(path) as PackedScene).instantiate()
	add_child(layout)
	# Поза редактором прев'ю саме не будується (і не повинно — у грі його не існує), тож
	# тут будуємо його руками: інструмент для того й потрібен, щоб ПОБАЧИТИ розкладку.
	_build_previews(layout)
	if layout is LevelLayout:
		(layout as LevelLayout)._rebuild_guide_forced()

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.72, 0.85)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.75, 0.8)
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)

	var from := float(OS.get_environment("FROM")) if OS.has_environment("FROM") else 0.0
	var span := float(OS.get_environment("SPAN")) if OS.has_environment("SPAN") else 50.0
	var cam := Camera3D.new()
	if OS.get_environment("VIEW") == "top":
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		# size типово означає ВИСОТУ кадру; нам треба, щоб SPAN лягав по ширині — інакше
		# у кадр влазить удвічі більше дороги, ніж просили, і вона з'їжджає вбік.
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.size = span
		# Поворот на 90° навколо вертикалі кладе дорогу вздовж ШИРОКОГО боку кадру: 50 м
		# уміщаються по горизонталі, а по вертикалі лишається ~27 м — дорога плюс узбіччя.
		cam.position = Vector3(0, 60, -(from + span * 0.5))
		cam.rotation_degrees = Vector3(-90, -90, 0)
	else:
		cam.position = Vector3(0, 3.0, 8.0 - from)
		cam.rotation_degrees = Vector3(-10, 0, 0)
	cam.far = 400.0
	add_child(cam)
	cam.make_current()

	for i in range(4):
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out)
	print("знімок чанка %d рівня %d → %s" % [_chunk, _level, _out])
	get_tree().quit()


func _build_previews(node: Node) -> void:
	for child in node.get_children():
		if child is LevelMarker3D:
			var marker := child as LevelMarker3D
			var preview := marker._preview_node()
			if preview != null:
				preview.rotation.y = deg_to_rad(marker.yaw_deg)
				preview.scale = Vector3.ONE * marker.scale_mul
				if marker.role == "obstacle" or marker.role == "pickup":
					preview.position.x = float(marker.lane) * LevelMarker3D.LANE_W
				marker.add_child(preview)
		_build_previews(child)
