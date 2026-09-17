## Міст розробника не сміє поїхати у збірку гри.
##
## godot-mcp-enhanced має шар «міст до запущеної гри»: він кладе mcp_bridge.gd у КОРІНЬ
## проєкту й реєструє автозавантаження MCPBridge. Цим шаром зручно дивитися на живу гру
## покроково — але прочитано його код (4512 рядків) і перевірено: **захисту від релізної
## збірки там немає**. Єдина перевірка — Engine.is_editor_hint(), тобто «редактор чи гра»;
## у коментарі прямо написано, що в безголовому режимі міст запускається навмисно.
##
## Отже якщо міст лишиться встановленим у мить експорту, гра поїде в магазин із відкритим
## TCP-портом (9081–9090). Для дитячої гри це і саме по собі погано, і привід до відмови
## при розгляді в Apple та Google.
##
## Правило просте: ставити міст на час роботи, знімати одразу після. Забути легко — тому
## цей тест. У звичайному стані він зелений; щойно міст лишиться в проєкті, він червоніє
## ще до складання збірки.
extends GutTest

## Як саме воно себе реєструє (з коду пакета: core/bridge-client.ts).
const AUTOLOAD_KEYS := ["MCPBridge=", "autoload/MCPBridge="]
const BRIDGE_SCRIPT := "res://mcp_bridge.gd"


func test_bridge_autoload_is_not_registered() -> void:
	var f := FileAccess.open("res://project.godot", FileAccess.READ)
	assert_not_null(f, "project.godot читається")
	if f == null:
		return
	var text := f.get_as_text()
	for key in AUTOLOAD_KEYS:
		assert_false(text.contains(key),
			("у project.godot лишилось автозавантаження мосту («%s») — зніміть його "
			+ "(game_bridge_uninstall), інакше гра поїде з відкритим TCP-портом") % key)


func test_bridge_script_is_not_in_the_project() -> void:
	assert_false(FileAccess.file_exists(BRIDGE_SCRIPT),
		"%s лишився в корені проєкту — це інструмент розробника, а не частина гри" % BRIDGE_SCRIPT)


## Плагін РЕДАКТОРА — інша річ: він @tool, у грі не виконується й уже виключений з
## export_presets.cfg. Але саме те виключення й стережемо: без нього 504 КБ службового
## коду поїхали б у пакунок, який ми довго худили з 296 МБ до 28.
func test_editor_plugin_is_excluded_from_the_build() -> void:
	var f := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	if f == null:
		pass_test("export_presets.cfg нема — нічого стерегти")
		return
	var text := f.get_as_text()
	if not text.contains("exclude_filter"):
		pass_test("у наборі експорту нема exclude_filter")
		return
	assert_true(text.contains("addons/godot_mcp_server/*"),
		"плагін MCP виключено зі збірки гри")
