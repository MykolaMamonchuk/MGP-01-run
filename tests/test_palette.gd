## Сторож централізованих кольорів: у src/ не має бути жодного літерала "#RRGGBB".
## Єдине місце для кольорів — src/ui/theme/palette.gd (Palette).
extends GutTest

const PALETTE_PATH := "res://src/ui/theme/palette.gd"
const SRC_ROOT := "res://src"
## Модуль addons/mgp_core автономний і має власні константи — сюди не входить.

var _hex := RegEx.new()


func before_all() -> void:
	_hex.compile('#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?')


func _gd_files(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			_gd_files(full, out)
		elif name.ends_with(".gd"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""


func test_no_hex_literals_outside_palette() -> void:
	var files: Array = []
	_gd_files(SRC_ROOT, files)
	assert_gt(files.size(), 20, "знайшли файли гри")
	var offenders: Array = []
	for path in files:
		if path == PALETTE_PATH:
			continue
		var line_no := 0
		for line in _read(path).split("\n"):
			line_no += 1
			var code := String(line).strip_edges()
			if code.begins_with("#"):
				continue   # коментар
			if _hex.search(code) != null:
				offenders.append("%s:%d  %s" % [path, line_no, code])
	assert_eq(offenders.size(), 0, "колір повинен приходити з Palette, а не бути в коді:\n" + "\n".join(offenders))


func test_palette_roles_point_at_scale() -> void:
	# ролі — не «сирі» кольори: змінюєш роль, а не шукаєш відтінок по коду
	assert_eq(Palette.BTN_PRIMARY, Palette.GREEN)
	assert_eq(Palette.TEXT_LIGHT, Palette.CREAM)
	assert_eq(Palette.STAR, Palette.GOLD)
	assert_eq(Palette.HERO_DEFAULT, Palette.APRICOT)


func test_of_reads_data_colors_with_fallback() -> void:
	assert_eq(Palette.of("#123456", Palette.GOLD), Color("#123456"), "рядок із JSON")
	assert_eq(Palette.of("#00000000", Palette.GOLD), Color(0, 0, 0, 0), "8 знаків — з прозорістю")
	assert_eq(Palette.of(null, Palette.GOLD), Palette.GOLD, "нема ключа — запасний")
	assert_eq(Palette.of("", Palette.GOLD), Palette.GOLD, "порожньо — запасний")
	assert_eq(Palette.of("не колір", Palette.GOLD), Palette.GOLD, "сміття з диска не має ронити гру")
	assert_eq(Palette.of(42, Palette.GOLD), Palette.GOLD, "не рядок — запасний")
	assert_eq(Palette.of(Palette.RED, Palette.GOLD), Palette.RED, "готовий Color проходить як є")


func test_ramp_sets_are_colors() -> void:
	assert_eq(Palette.RAINBOW.size(), 6)
	assert_eq(Palette.WHEEL_SECTORS.size(), WheelLayer.SECTORS.size(), "колір на кожен сектор колеса")
	assert_eq(Palette.TITLE_LETTERS.size(), MenuLayer.TITLE.length(), "колір на кожну літеру заголовка")
	for kind in ["petals", "leaves", "snow", "glints", "fireflies", "rain", "stars"]:
		assert_true(Palette.RAMP_AMBIENT.has(kind), "є градієнт для «%s»" % kind)
		assert_gt((Palette.RAMP_AMBIENT[kind] as Array).size(), 1, "%s: градієнт із двох і більше кольорів" % kind)
