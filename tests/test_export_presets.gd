## Що НЕ сміє потрапити у збірку для гравця.
##
## `docs/MCP.md` каже прямо: міст MCP не має сторожа релізної збірки, тож його треба прибрати
## перед експортом. Прибирає його лише рядок `exclude_filter` у `export_presets.cfg` — файлі,
## який редагують мишею в діалозі експорту й у якому легко загубити кому. Помилка тут не
## падає й нічого не друкує: збірка просто виходить із мостом усередині.
##
## Міст відкриває виконання GDScript ззовні. У грі для дитини цьому місця немає.
##
## Сюди ж — тести, GUT та інструменти: вони нічого не ламають, але це десятки мегабайтів у
## збірці, яку дитина качає по телефонній мережі.
extends GutTest

const PRESETS := "res://export_presets.cfg"
## Має бути виключено з КОЖНОГО пресета. Перше — про безпеку, решта — про вагу.
const MUST_EXCLUDE := ["addons/godot_mcp_server/*", "addons/gut/*", "tests/*", "tools/*",
	"src/debug/*", "docs/*"]


## Пресети як [{name, exclude}]. Читаємо текстом: у грі цей файл не потрібен, тож тягти
## заради нього ConfigFile з редакторськими особливостями сенсу немає.
func _presets() -> Array:
	var f := FileAccess.open(PRESETS, FileAccess.READ)
	if f == null:
		return []
	var out := []
	var name := ""
	for line in f.get_as_text().split("\n"):
		var s := String(line).strip_edges()
		if s.begins_with("name=\""):
			name = s.substr(6).split("\"")[0]
		elif s.begins_with("exclude_filter=\"") and name != "":
			out.append({"name": name, "exclude": s.substr(16).split("\"")[0]})
			name = ""
	return out


func test_presets_are_readable() -> void:
	assert_true(FileAccess.file_exists(PRESETS), "export_presets.cfg на місці")
	assert_gt(_presets().size(), 0, "пресети прочитались — інакше сторож стереже порожнечу")


func test_no_preset_ships_the_mcp_bridge() -> void:
	var bad := []
	for p in _presets():
		for rule in MUST_EXCLUDE:
			if not String((p as Dictionary)["exclude"]).contains(String(rule)):
				bad.append("%s: нема правила %s" % [(p as Dictionary)["name"], rule])
	assert_eq(bad.size(), 0, "у пресетах експорту бракує виключень: %s" % [bad])


## І навпаки: дебаг-накладку у збірці для дитини не показуємо самі — вона вмикається лише за
## прапорцем `debug_hud`. Тут стережемо, що прапорець не розповзся: інакше дитина отримає
## екран цифр замість гри.
##
## Хто має право його носити — ВИПРОБУВАЛЬНІ збірки, і лише вони:
##   Web     — гра на телефоні по Wi-Fi, без магазинів і кабелю (docs/web.md);
##   Android — збірка для замірів на СПРАВЖНЬОМУ пристрої. Заради неї вона й заведена:
##             числа Compatibility у браузері не кажуть нічого про те, як гра йде на
##             мобільному рушії, а складання цеглинки, тіні й час кадру треба міряти там.
##
## Коли Android стане збіркою ДЛЯ ДИТИНИ, прапорець із неї має зникнути, а випробувальна —
## жити окремим пресетом. Саме тому список тут явний, а не «будь-який пресет, крім macOS».
## iOS доданий 22.09.2026: iPhone 11 потрібен не як цільовий пристрій (він утричі
## потужніший за найслабший Android), а як ДРУГИЙ драйвер. Ціна фонової забудови на
## Adreno 505 виявилась геометричною; чи це правда й на Metal — перевіряється лише так.
const DEBUG_HUD_PRESETS := ["Web", "Android", "iOS"]
func test_debug_hud_flag_only_where_intended() -> void:
	var f := FileAccess.open(PRESETS, FileAccess.READ)
	assert_not_null(f, "export_presets.cfg читається")
	var name := ""
	var flagged := []
	for line in f.get_as_text().split("\n"):
		var s := String(line).strip_edges()
		if s.begins_with("name=\""):
			name = s.substr(6).split("\"")[0]
		elif s.begins_with("custom_features=\"") and s.contains("debug_hud"):
			flagged.append(name)
	assert_eq(flagged, DEBUG_HUD_PRESETS,
		"прапорець debug_hud має стояти лише у випробувальних збірках, а стоїть у: %s"
		% [flagged])


## Ручки досліду з командного рядка (`--strip=`, `--scale=`, `--level=`) не мають лишитись у
## пресеті. Збірки для заміру якраз і різняться рядком `command_line/extra_args`, і якщо його
## забути повернути, реліз мовчки поїде з досліднім станом: `nofar` ховає хати, `--scale=`
## міняє роздільність, `--level=` кидає одразу в рівень. Рецензія 25.09.
func test_no_experiment_knobs_in_extra_args() -> void:
	var f := FileAccess.open(PRESETS, FileAccess.READ)
	for line in f.get_as_text().split("\n"):
		if not line.begins_with("command_line/extra_args"):
			continue
		for knob in ["--strip=", "--scale=", "--level="]:
			assert_false(line.contains(knob), "у пресеті лишилась ручка досліду %s: %s" % [knob, line])


## Тестові моделі «за малюнком» (assets/props/_exp/models) гра не використовує, а важать ~20 МБ
## у збірці. Кожен пресет виключає їх — або саме цю теку, або весь _exp (Web). Сторож потрібен,
## бо пресет правлять мишею в редакторі, і рядок легко випадає непомітно (рецензія 26.09).
func test_test_models_not_shipped() -> void:
	var presets := _presets()
	assert_gt(presets.size(), 0, "пресети знайдено")
	for p in presets:
		var ex: String = p["exclude"]
		assert_true(ex.contains("assets/props/_exp/models/*") or ex.contains("assets/props/_exp/*"),
			"пресет %s тягне тестові моделі в збірку" % p["name"])
