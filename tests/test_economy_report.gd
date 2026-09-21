## Звіт про економіку мусить рахувати ТИМИ САМИМИ числами, що й гра.
##
## tools/economy/report.gd дублює три константи швидкості (SPEED_RAMP, SPRINT_FROM,
## SPRINT_MULT) — і дублює навмисно: звіт не має тягнути за собою Run3D, який є вузлом сцени
## з автозавантаженнями. Але дубль без сторожа — це майбутня тиха брехня: хтось підправить
## розгін у грі, звіт лишиться зі старим числом, і таблиця бюджетів поїде на десятки метрів
## на рівень, нікого не попередивши.
##
## Тут же стережемо й те, звідки звіт бере базову швидкість: profiles.json, ключ speed.
extends GutTest

const REPORT := "res://tools/economy/report.gd"
## Run3D не має class_name — це скрипт сцени, тож константи читаємо так само, як у звіту.
const RUN3D := "res://src/run3d/run3d.gd"


func _const_of(script_path: String, name: String) -> Variant:
	var gd := load(script_path) as GDScript
	assert_not_null(gd, "скрипт %s читається" % script_path)
	return gd.get_script_constant_map().get(name)


func test_rozhin_u_zviti_toi_samyi_shcho_v_hri() -> void:
	assert_eq(_const_of(REPORT, "SPEED_RAMP"), _const_of(RUN3D, "SPEED_RAMP"),
		"розгін швидкості у звіті розійшовся з run3d.gd:SPEED_RAMP")


func test_sprynt_u_zviti_toi_samyi_shcho_v_hri() -> void:
	assert_eq(_const_of(REPORT, "SPRINT_FROM"), _const_of(RUN3D, "SPRINT_FROM"),
		"початок спринту у звіті розійшовся з run3d.gd:SPRINT_FROM")
	assert_eq(_const_of(REPORT, "SPRINT_MULT"), _const_of(RUN3D, "SPRINT_MULT"),
		"множник спринту у звіті розійшовся з run3d.gd:SPRINT_MULT")


## Модель EDD у звіті — це ЦІЛЬ, з якою звіряють дані. Вона мусить покривати всі рівні, що є
## в data/levels.json: пропущений рівень мовчки дав би нуль золота й нікого б не збентежив.
func test_model_EDD_pokryvaie_vsi_rivni() -> void:
	var edd: Dictionary = _const_of(REPORT, "EDD_NOMINAL")
	var f := FileAccess.open("res://data/levels.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	var levels: Array = (parsed as Dictionary).get("levels", [])
	assert_gt(levels.size(), 0, "рівні прочитались")
	var missing := []
	for lv in levels:
		if not edd.has(int((lv as Dictionary)["id"])):
			missing.append(int((lv as Dictionary)["id"]))
	assert_eq(missing, [], "у моделі EDD немає рівнів: %s" % [missing])


## Базова швидкість профілю mid — те, на чому тримається вся таблиця метрів. Перевірка, що
## ключ узагалі на місці: перейменують його в даних — звіт мовчки візьме дефолт 3.5 і буде
## правий випадково.
func test_profil_mid_maie_bazovu_shvydkist() -> void:
	var f := FileAccess.open("res://data/profiles.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	var mid: Dictionary = (parsed as Dictionary).get("mid", {})
	assert_true(mid.has("speed"), "у профілю mid є ключ speed")
	assert_gt(float(mid["speed"]), 0.0)
