extends Node3D

## КАРТКИ ДЛЯ ДАЛЕКИХ ХАТ: кожну house_terra* знімаємо ОДИН раз під тим кутом, під яким
## ігрова камера бачить її в далекій смузі, і в грі ставимо плоску картку замість 3D.
##
## Чому під фіксованим кутом, а не спрайт, що обертається. Раннер: камера дивиться на далеку
## хату майже з того самого боку весь час, поки вона в кадрі. Хата ліворуч за ~12 м від осі
## дороги видна з 30-10 м попереду — тобто під 70°->40° від фасаду, з боку, звідки набігає
## камера. Картку, зняту під 55°, камера бачить з відхиленням лише ±15° — і та не читається
## картоном, а перемикання кадрів, як у спрайта з 8 боків, немає зовсім.
##
## Лише ЛІВИЙ бік: там усі 249 далеких хат лугу стоять під одним поворотом, 90°. Праворуч
## повороти розкидані, і одна картка на вид там не лягає.
##
## Знімаємо В ГРІ й у Compatibility (як телефон), з тими самими матеріалами й світлом, що й
## гра: картка малюється без освітлення, тож світло має бути вмальоване правильне.
##   /Applications/Godot.app/Contents/MacOS/Godot --rendering-method gl_compatibility \
##       res://src/debug/far_card_capture.tscn

const KINDS := ["house_terra", "house_terra_1", "house_terra_2", "house_terra_3",
	"house_terra_4", "house_terra_5", "house_terra_6", "house_terra_7", "house_terra_9"]
## Поворот хати в далекій лівій смузі (з цеглинок лугу).
const HOUSE_YAW_DEG := 90.0
## Кут між фасадом і напрямком на камеру, під яким знімаємо.
const VIEW_FROM_FACADE_DEG := 55.0
## Наскільки камера вище за хату: у грі ~5° донизу.
const PITCH_DEG := 5.0
const SIZE_PX := 256
const OUT_DIR := "res://assets/props/_exp/cards"

var _vp: SubViewport
var _cam: Camera3D


func _ready() -> void:
	var method := RenderingServer.get_current_rendering_method()
	var k: float = load("res://src/run3d/run3d.gd").light_scale_for(method)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 0.96, 0.88)
	e.ambient_light_energy = 0.35 * k
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis(Vector3(0.87758255, 0, -0.47942555),
		Vector3(-0.37554693, 0.62161, -0.687434), Vector3(0.2980157, 0.7833269, 0.54551405)),
		Vector3(0, 8, 0))
	sun.light_energy = 0.9 * k
	add_child(sun)
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE_PX, SIZE_PX)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)
	var meta := {}
	var comp: Script = load("res://src/debug/house_compare.gd")
	for kind in KINDS:
		var holder := Node3D.new()
		add_child(holder)
		holder.rotation_degrees.y = HOUSE_YAW_DEG
		var mi := MeshInstance3D.new()
		# Та сама обробка матеріалів, що й у грі — беремо її зі сцени порівняння, щоб не
		# розходилась із нею.
		var helper: Node3D = comp.new()
		mi.mesh = helper._mesh_of("res://assets/props/%s.glb" % kind, e.ambient_light_color,
			e.ambient_light_energy, method)
		helper.free()
		holder.add_child(mi)
		await get_tree().process_frame
		var aabb := holder.global_transform * mi.mesh.get_aabb()
		var span: float = maxf(maxf(aabb.size.x, aabb.size.y), aabb.size.z) * 1.12
		var ctr := aabb.position + aabb.size * 0.5
		# Напрямок від хати на камеру. Хата ліворуч, фасад дивиться на дорогу (+X), камера
		# набігає ззаду (+Z): відхиляємо від фасаду до +Z на VIEW_FROM_FACADE_DEG.
		var a := deg_to_rad(VIEW_FROM_FACADE_DEG)
		var p := deg_to_rad(PITCH_DEG)
		var d := Vector3(cos(a) * cos(p), sin(p), sin(a) * cos(p))
		_cam.size = span
		_cam.look_at_from_position(ctr + d * 30.0, ctr, Vector3.UP)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png(ProjectSettings.globalize_path("%s/%s_L.png" % [OUT_DIR, kind]))
		meta[kind] = {"span_m": span, "center_y_m": ctr.y,
			"card_yaw_deg": rad_to_deg(atan2(d.x, d.z))}
		print("КАРТКА ", kind, "  проліт %.2f м, центр %.2f м" % [span, ctr.y])
		holder.queue_free()
		await get_tree().process_frame
	var f := FileAccess.open("%s/cards.json" % OUT_DIR, FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	get_tree().quit()
