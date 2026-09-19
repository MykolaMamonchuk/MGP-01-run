## Скільки відеопам'яті коштує КОЖНА текстура гри — числом, а не на око.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless -s tools/vram/vram_audit.gd
##
## Чому не рахувати сторони з файлу: у `.import` є `process/size_limit` і `compress/mode`,
## тож картинка 2048×2048 може лягти в пам'ять як 512×512 ETC2. Питаємо саме рушій:
## `Image.get_format()` після імпорту каже правду про формат у пам'яті.
@tool
extends SceneTree

## Байтів на піксель за форматом. Блокові формати рахуємо як розмір блока / 16 пікселів.
const BPP := {
	Image.FORMAT_RGBA8: 4.0, Image.FORMAT_RGB8: 3.0, Image.FORMAT_RGBAF: 16.0,
	Image.FORMAT_L8: 1.0, Image.FORMAT_LA8: 2.0, Image.FORMAT_RG8: 2.0,
	Image.FORMAT_DXT1: 0.5, Image.FORMAT_DXT3: 1.0, Image.FORMAT_DXT5: 1.0,
	Image.FORMAT_RGTC_R: 0.5, Image.FORMAT_RGTC_RG: 1.0,
	Image.FORMAT_BPTC_RGBA: 1.0, Image.FORMAT_BPTC_RGBF: 1.0, Image.FORMAT_BPTC_RGBFU: 1.0,
	Image.FORMAT_ETC: 0.5, Image.FORMAT_ETC2_R11: 0.5, Image.FORMAT_ETC2_RG11: 1.0,
	Image.FORMAT_ETC2_RGB8: 0.5, Image.FORMAT_ETC2_RGBA8: 1.0, Image.FORMAT_ETC2_RGB8A1: 0.5,
	Image.FORMAT_ASTC_4x4: 1.0, Image.FORMAT_ASTC_8x8: 0.25,
}


func _init() -> void:
	var rows: Array = []
	var total := 0.0
	for folder in ["res://assets/props", "res://assets/models", "res://assets/props/3d"]:
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		for file in dir.get_files():
			if not (file.ends_with(".jpg") or file.ends_with(".png")):
				continue
			var tex: Texture2D = load(folder + "/" + file)
			if tex == null:
				continue
			var img := tex.get_image()
			if img == null:
				continue
			var fmt := img.get_format()
			var bpp: float = BPP.get(fmt, 4.0)
			# мипмапи додають рівно третину
			var mips := 1.3333 if img.has_mipmaps() else 1.0
			var mb := img.get_width() * img.get_height() * bpp * mips / 1048576.0
			total += mb
			rows.append([mb, file, img.get_width(), img.get_height(), fmt, img.has_mipmaps()])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("--- ПОЧАТОК ЗВІТУ ---")
	for r in rows:
		print("%-52s %5dx%-5d fmt=%-3d mips=%s %7.2f" % [r[1], r[2], r[3], r[4], r[5], r[0]])
	print("текстур: %d, разом у відеопам'яті: %.1f МБ" % [rows.size(), total])
	quit()
