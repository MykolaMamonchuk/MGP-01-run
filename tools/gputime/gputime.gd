extends Node3D

## ПЕРЕВІРКА ЧАСОМІРА GPU. На Redmi 8A (Compatibility/GLES) і на iPhone 11 (Metal через
## MoltenVK) `viewport_get_measured_render_time_gpu()` повертав нулі, хоч увімкнення
## викликано й viewport правильний. Лишалось дві можливості: бекенди його не реалізують —
## або я щось роблю не так. Ця сцена відрізняє одне від іншого: той самий код на Маку, де
## той самий рушій і той самий API. Ненульові числа тут означають, що код правильний.
##
## Живе в tools/ — тека виключена з експорту.

var _n := 0


func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	print("ЧАСОМІР: рушій=%s" % RenderingServer.get_current_rendering_method())
	# Щось на екрані, щоб було що міряти.
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radial_segments = 256
	m.rings = 128
	mi.mesh = m
	add_child(mi)
	for i in range(60):
		var c := mi.duplicate() as MeshInstance3D
		c.position = Vector3(randf_range(-4, 4), randf_range(-3, 3), randf_range(-6, -2))
		add_child(c)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 4)
	add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)


func _process(_d: float) -> void:
	_n += 1
	if _n % 30 != 0:
		return
	var rid := get_viewport().get_viewport_rid()
	print("ЧАСОМІР кадр %3d: ГПУ %8.3f мс   ЦПУ %8.3f мс" % [
		_n,
		RenderingServer.viewport_get_measured_render_time_gpu(rid),
		RenderingServer.viewport_get_measured_render_time_cpu(rid)])
	if _n >= 180:
		get_tree().quit()
