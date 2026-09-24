extends Node2D

## Запікає візерунок води у файл. Разовий інструмент, не частина гри.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --path . res://tools/bake_water/bake.tscn
##
## БЕЗ --headless: у headless 2D не малюється, і вийде порожня картинка (це вже записано в
## memory bank). Вікно відкриється на секунду й закриється саме.
##
## Навіщо файл, а не запікання на старті гри. Запікання в рантаймі вимагає кадру рендера,
## тобто не працює в headless-тестах і додає крихкості туди, де її можна не мати. Файл
## детермінований, важить ~40 КБ і перезапікається цією ж командою, якщо змінити візерунок
## у water_bake.gdshader.
const SIZE := 512
const OUT := "res://assets/art/water_layer.png"


func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var rect := ColorRect.new()
	rect.size = Vector2(SIZE, SIZE)
	var m := ShaderMaterial.new()
	m.shader = load("res://src/run3d/water_bake.gdshader")
	rect.material = m
	vp.add_child(rect)
	add_child(vp)
	# Двох кадрів досить: перший створює ціль рендера, другий її малює.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT)
	var err := img.save_png(path)
	if err != OK:
		push_error("не збереглось: %d" % err)
	else:
		var non_zero := 0
		for y in range(0, SIZE, 16):
			for x in range(0, SIZE, 16):
				if img.get_pixel(x, y).r > 0.01:
					non_zero += 1
		print("запечено %s, ненульових проб %d із %d" % [OUT, non_zero, (SIZE / 16) * (SIZE / 16)])
	get_tree().quit()
