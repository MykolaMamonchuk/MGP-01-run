## Друг будується РАЗ на рівень, а не на кожну появу.
##
## Замовник бачив ривок саме тоді, коли друг вибігає. Заміряно годинником на Redmi 8A:
## створення друга коштувало 368 і 325 мс — шість-сім кадрів роботи в одному кадрі, і так
## ЩОРАЗУ, а не лише вперше. Це не компіляція шейдерів, а сама побудова тіла: Hero3D.new()
## плюс set_hero() будують вокселі, меші й матеріали.
extends GutTest

var _hero: Hero3D
var _fr: Friend3D


func before_each() -> void:
	_hero = Hero3D.new()
	add_child_autofree(_hero)
	_fr = Friend3D.new()
	add_child_autofree(_fr)
	await wait_frames(2)


func test_poyava_ne_buduie_tilo_znovu() -> void:
	_fr.prepare(_hero, Palette.FRIEND_DEFAULT)
	var puppet := _fr.get_child(0)
	assert_not_null(puppet, "тіло збудовано при підготовці")
	var built := puppet.get_child_count()
	assert_gt(built, 0, "тіло не порожнє")
	_fr.activate(3.0)
	assert_eq(_fr.get_child(0), puppet, "поява НЕ створює нове тіло")
	assert_eq(puppet.get_child_count(), built, "і не добудовує частин")


func test_povtorna_pidgotovka_ne_perebuduie() -> void:
	_fr.prepare(_hero, Palette.FRIEND_DEFAULT)
	var puppet := _fr.get_child(0)
	var parts := puppet.get_child_count()
	_fr.prepare(_hero, Palette.FRIEND_DEFAULT)
	assert_eq(_fr.get_child(0), puppet, "той самий колір — тіло не перебудовується")
	assert_eq(puppet.get_child_count(), parts, "і частин стільки ж")


## Після відбігання друг ХОВАЄТЬСЯ, а не звільняється: інакше наступна поява знову
## коштувала б третину секунди.
func test_vidbigannya_khovaie_a_ne_zvilniaie() -> void:
	_fr.prepare(_hero, Palette.FRIEND_DEFAULT)
	_fr.activate(0.01)
	assert_true(_fr.is_active(), "після появи друг активний")
	assert_true(_fr.visible, "і видимий")
	# доганяємо його до кінця шляху так само, як це робить _process
	_fr.set("_leaving", true)
	_fr.position.z = -31.0
	_fr._process(0.016)
	assert_false(_fr.is_active(), "відбіг — більше не активний")
	assert_false(_fr.visible, "і схований")
	assert_true(is_instance_valid(_fr), "але ЖИВИЙ: наступна поява має бути дешевою")
	assert_false(_fr.is_processing(), "схований друг не витрачає кадр")


## Друг переживає зміну рівня: його тіло коштує близько 300 мс, і якщо звільняти його
## разом з рештою акторів, кожен новий рівень платив би це знову на відліку.
func test_drug_perezhyvaie_zminu_rivnia() -> void:
	var actors := Node3D.new()
	add_child_autofree(actors)
	var sp := EventSpawner.new()
	add_child_autofree(sp)
	sp.configure(null, _hero, null, actors, {"event_interval": [20.0, 30.0]}, "run")
	await wait_frames(2)
	var friend = sp.get("_friend")
	assert_not_null(friend, "друга підготовлено на старті")
	var smittya := Node3D.new()
	actors.add_child(smittya)
	sp.reset()
	await wait_frames(2)
	assert_true(is_instance_valid(friend), "друг ЛИШИВСЯ живим після зміни рівня")
	assert_false(is_instance_valid(smittya), "а решта акторів прибрана")
	assert_false(friend.is_active(), "і схований")
