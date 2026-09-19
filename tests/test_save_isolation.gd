## Прогін тестів не чіпає збереження дитини.
##
## Знайдено збоку, під час розбору «не можу купити рівень»: збереження на машині розробника
## за пів години виросло з 628 зірочок до 1491. Винні були не проби й не гра, а САМ набір
## тестів — він ганяє справжній автолоад SaveService зі справжнім save_game(). Заміряно
## 19.09.2026: один повний прогін додавав дитині +278 зірочок і +2 чекпоінти.
##
## Це не дрібниця: прогрес дитини тихо ріс від кожного запуску тестів, а будь-яке порівняння
## «до/після» в грі ставало ні з чим порівнювати — стан щоразу інший.
extends GutTest


func test_tests_write_to_their_own_file() -> void:
	assert_eq(SaveService.save_path(), SaveService.SAVE_PATH_TEST,
		"під GUT збереження йде в тестовий файл")
	assert_ne(SaveService.save_path(), SaveService.SAVE_PATH,
		"і це НЕ файл дитини")


## Той самий шлях бачить і читання, і запис — інакше тест читав би одне, а писав в інше.
func test_write_then_read_round_trip() -> void:
	var was := SaveService.stars()
	SaveService.add_stars(7)
	SaveService.save_game()
	SaveService.load_game()
	assert_eq(SaveService.stars(), was + 7, "записане читається назад із того самого файлу")
	SaveService.add_stars(-7)
	SaveService.save_game()


## Файл дитини існує лише в грі; у тестах його не має бути навіть створено.
func test_players_file_is_left_alone() -> void:
	var before := FileAccess.get_modified_time(SaveService.SAVE_PATH)
	SaveService.save_game()
	assert_eq(FileAccess.get_modified_time(SaveService.SAVE_PATH), before,
		"save_game() у тестах не торкається save.json гравця")
