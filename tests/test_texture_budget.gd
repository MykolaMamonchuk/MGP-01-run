## Стеля текстур у ВІДЕОПАМ'ЯТІ. Сторож саме тут, а не в скрипті, бо налаштування імпорту
## губляться ТИХО: Godot переписує `.import`, коли переімпортовує `.glb`, і текстура мовчки
## повертається в RGBA8 — без жодної помилки в консолі, лише вчетверо більше пам'яті.
## Так 19.09.2026 і знайшлися шість карт ринкових возів, нестиснених від коміту 817d021.
##
## Числа заходу 19.09.2026 (`docs/optimisation/2026-09-19-texture-vram.md`):
## бюджет текстур гри 62,3 → 36,7 МБ.
extends GutTest

## Формати, у яких текстура має право лежати в пам'яті, і скільки БАЙТІВ НА ПІКСЕЛЬ вона
## там займає. Усе це блокові формати; розпакована RGBA8 (4 байти) сюди не входить навмисно.
const BLOCK_BPP := {
	Image.FORMAT_DXT1: 0.5, Image.FORMAT_DXT3: 1.0, Image.FORMAT_DXT5: 1.0,
	Image.FORMAT_RGTC_R: 0.5, Image.FORMAT_RGTC_RG: 1.0,
	Image.FORMAT_BPTC_RGBA: 1.0,
	Image.FORMAT_ETC2_RGB8: 0.5, Image.FORMAT_ETC2_RGBA8: 1.0, Image.FORMAT_ETC2_RGB8A1: 0.5,
	Image.FORMAT_ETC2_R11: 0.5, Image.FORMAT_ETC2_RG11: 1.0,
	Image.FORMAT_ASTC_4x4: 1.0, Image.FORMAT_ASTC_8x8: 0.25,
}

## Формати, якими має бути взята КАРТА НОРМАЛЕЙ. У неї два значущі канали, і кольорові
## формати (DXT1 — це 565 без альфи) роблять з неї кашу на освітленні. `compress/normal_map`
## у `.import` — перелік «Detect, Enable, Disabled», тож потрібна ОДИНИЦЯ; двійка вимикає
## розклад, і саме вона там стояла до 19.09.2026 у десяти карт.
const NORMAL_FORMATS := [
	Image.FORMAT_RGTC_RG, Image.FORMAT_ETC2_RG11, Image.FORMAT_ASTC_4x4, Image.FORMAT_BPTC_RGBA,
	Image.FORMAT_DXT5,
]

## Стеля сторони. Пропси метрові, і 512 дає їм 500–700 пікселів текстури на метр — більше,
## ніж у будинка на 1024 (497 пк/м). Виняток — те, що більше за півтора метра.
const PROP_SIDE := 512
const MODEL_SIDE := 1024
const KEEP_FULL_SIZE := ["house_terra"]

## Весь бюджет текстур гри. Стеля з запасом над заміряними 36,7 МБ: вона ловить не «на
## мегабайт більше», а новий асет, що приїхав нестисненим або в 2048.
const MAX_TOTAL_MB := 45.0


func _textures(folder: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return out
	for name in dir.get_files():
		if name.get_extension() in ["jpg", "png"]:
			out.append("%s/%s" % [folder, name])
	out.sort()
	return out


func _all_textures() -> Array:
	var out: Array = []
	for folder in ["res://assets/props", "res://assets/models"]:
		out.append_array(_textures(folder))
	return out


func _image(path: String) -> Image:
	var tex := load(path) as Texture2D
	return null if tex == null else tex.get_image()


func test_every_model_texture_is_vram_compressed() -> void:
	var files := _all_textures()
	assert_gt(files.size(), 0, "текстури моделей узагалі знайшлись")
	for path in files:
		var img := _image(path)
		if img == null:
			continue
		assert_true(BLOCK_BPP.has(img.get_format()),
			"%s лежить у пам'яті форматом %d — не стиснений у VRAM; прогнати tools/textures_vram.py"
				% [path.get_file(), img.get_format()])


func test_normal_maps_keep_their_two_channel_format() -> void:
	for path in _all_textures():
		if not path.get_file().contains("_normal."):
			continue
		var img := _image(path)
		if img == null:
			continue
		assert_true(NORMAL_FORMATS.has(img.get_format()),
			"карта нормалей %s узята форматом %d — для неї потрібен двоканальний RGTC/EAC, а не кольоровий"
				% [path.get_file(), img.get_format()])


func test_no_texture_is_larger_than_its_side_limit() -> void:
	for path in _all_textures():
		var img := _image(path)
		if img == null:
			continue
		var limit := MODEL_SIDE if path.contains("/models/") else PROP_SIDE
		for big in KEEP_FULL_SIZE:
			if path.get_file().begins_with(big):
				limit = MODEL_SIDE
		assert_lte(maxi(img.get_width(), img.get_height()), limit,
			"%s має сторону %dx%d при стелі %d" % [path.get_file(), img.get_width(), img.get_height(), limit])


## Головне число заходу: скільки вся графіка гри займає у відеопам'яті. Рахуємо так само,
## як `tools/vram/vram_audit.gd` — мипмапи додають рівно третину.
func test_all_textures_together_fit_the_vram_budget() -> void:
	var total := 0.0
	for path in _all_textures():
		var img := _image(path)
		if img == null:
			continue
		var bpp: float = BLOCK_BPP.get(img.get_format(), 4.0)
		var mips := 1.3333 if img.has_mipmaps() else 1.0
		total += img.get_width() * img.get_height() * bpp * mips / 1048576.0
	assert_lt(total, MAX_TOTAL_MB,
		"текстури гри займають %.1f МБ відеопам'яті при стелі %.1f" % [total, MAX_TOTAL_MB])
	gut.p("текстури гри у відеопам'яті: %.1f МБ" % total)
