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
const OUT := "res://assets/art/water_layer_%d.png"

## ЧОТИРИ ВАРІАНТИ ВІЗЕРУНКА. Море й кожен канал беруть свій, інакше вся вода в грі має
## однаковий малюнок. Перетворення зберігають плитковість: зсув, дзеркалення й ЦІЛЕ
## масштабування — так, поворот — ні (на стиках плиток був би шов).
const VARIANTS := [
	{"offset": Vector2(0.00, 0.00), "flip": Vector2( 1.0,  1.0), "scale": 1.0},
	{"offset": Vector2(0.37, 0.12), "flip": Vector2(-1.0,  1.0), "scale": 1.0},
	{"offset": Vector2(0.61, 0.73), "flip": Vector2( 1.0,  1.0), "scale": 2.0},
	{"offset": Vector2(0.19, 0.44), "flip": Vector2( 1.0, -1.0), "scale": 1.0},
]


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
	for i in range(VARIANTS.size()):
		var v: Dictionary = VARIANTS[i]
		m.set_shader_parameter("uv_offset", v["offset"])
		m.set_shader_parameter("uv_flip", v["flip"])
		m.set_shader_parameter("uv_scale", v["scale"])
		# Двох кадрів досить: перший створює ціль рендера, другий її малює.
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var out := OUT % i
		var err := img.save_png(ProjectSettings.globalize_path(out))
		if err != OK:
			push_error("не збереглось %s: %d" % [out, err])
			continue
		# Проба на порожнечу: якщо шейдер не скомпілювався, ColorRect віддасть рівний колір,
		# і файл буде правдоподібним, але марним. Рахуємо, скільки проб НЕ схожі на сусідні.
		var uniq := {}
		for y in range(0, SIZE, 16):
			for x in range(0, SIZE, 16):
				uniq[snappedf(img.get_pixel(x, y).r, 0.02)] = true
		print("запечено %s, різних значень %d" % [out, uniq.size()])
	get_tree().quit()
