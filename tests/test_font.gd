## Шрифт гри: чи він узагалі є і чи вміє українську.
##
## Вада, заради якої цей файл існує, прожила в проєкті непоміченою: UIKit.FONT_PATH указував
## на "res://assets/fonts/kenney_mini_square.ttf", а такого файлу в репозиторії НІКОЛИ не було.
## ResourceLoader.exists() чесно повертав false, font() віддавав null, і кожен виклик мовчки
## проминав add_theme_font_override — уся гра малювалась типовим шрифтом Godot. Жоден тест
## шрифту не торкався, тож помітити це можна було тільки оком, а на око типовий шрифт Godot
## теж має кирилицю й виглядає прийнятно. Найгірший різновид вади: тиха.
extends GutTest

## Повна українська абетка плюс знаки, які справді трапляються в написах гри.
const UKRAINIAN := "АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯабвгґдеєжзиіїйклмнопрстуфхцчшщьюя’×…"


func test_the_game_font_file_is_actually_there() -> void:
	assert_true(ResourceLoader.exists(UIKit.FONT_PATH),
		"файл шрифту на місці: %s" % UIKit.FONT_PATH)


func test_font_loads_and_is_not_null() -> void:
	UIKit._font = null   # не покладаємось на кеш від попередніх тестів
	var f := UIKit.font()
	assert_not_null(f, "UIKit.font() повертає шрифт, а не null")


## Головне: латиниця в шрифті буває завжди, а кирилиця — ні. Заміряно на кандидатах:
## Baloo 2 і Fredoka, які радили як «дитячі», не мають української АБЕТКИ ВЗАГАЛІ.
func test_font_covers_the_whole_ukrainian_alphabet() -> void:
	UIKit._font = null
	var f := UIKit.font() as FontFile
	assert_not_null(f, "шрифт читається як FontFile")
	if f == null:
		return
	var missing := ""
	for i in UKRAINIAN.length():
		if not f.has_char(UKRAINIAN.unicode_at(i)):
			missing += UKRAINIAN[i]
	assert_eq(missing, "", "у шрифті є вся українська абетка; бракує: «%s»" % missing)


## Ліцензія має лежати поруч зі шрифтом: OFL вимагає поширювати текст ліцензії разом із
## файлом, і без нього гра в магазині порушує умови.
func test_font_licence_ships_with_the_font() -> void:
	assert_true(FileAccess.file_exists("res://assets/fonts/OFL.txt"),
		"текст ліцензії OFL лежить поруч зі шрифтом")
