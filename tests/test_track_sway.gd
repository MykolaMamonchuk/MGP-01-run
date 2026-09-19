## «Дихання» декору: хто ворушиться, а хто ні.
##
## Декор у грі ледь помітно гойдається — ±2% по висоті й ±2° нахилу (Track._sync_decor).
## На траві й у кроні це дає життя, але на ДАХУ проти неба та сама гойдалка ворушить пряму
## межу геометрії, і на цілком нерухомій камері це читається як миготіння. Заміряно: після
## виключення забудови з гойдалки різниця між двома сусідніми кадрами одного запуску впала
## з 573 «сильних» пікселів до 201, і 86% тих, що зникли, лежали на контурах дахів.
##
## Пастка, заради якої цей файл існує: вимикати гойдалку ЗА НАЗВОЮ ВИДУ не можна. Дев'ять
## видів у грі бувають і стіною, і придорожнім декором — bush, mushroom, palm, rock,
## lantern_post, mill, cloud, shell, star, — причому в city й forest кущ є тим і тим
## ОДНОЧАСНО. Шари живуть до кінця сеансу, тож позначка за назвою заморозила б і придорожні
## кущі, і то по-різному залежно від того, які світи гравець устиг відвідати.
extends GutTest

var _track: Track


func _world(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/worlds/%s.json" % name, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func before_each() -> void:
	_track = Track.new()
	add_child_autofree(_track)
	await wait_process_frames(2)


## Шари виду: [скільки «живих», скільки нерухомих].
func _layers_of(kind: String) -> Array:
	var live := 0
	var still := 0
	for key in _track._decor_layer_of.keys():
		if String(key).split("|")[0].split("#")[0] != kind:
			continue
		var idx := int(_track._decor_layer_of[key])
		if idx < _track._decor_no_sway.size() and _track._decor_no_sway[idx]:
			still += 1
		else:
			live += 1
	return [live, still]


## Забудова другого плану в meadow (млин, будинки) стоїть у шарах без гойдалки.
func test_buildings_get_a_still_layer() -> void:
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	var still := 0
	for v in _track._decor_no_sway:
		if v:
			still += 1
	assert_gt(still, 0, "у meadow є хоч один нерухомий шар — це забудова")


## Головна регресія. У city кущ є і стіною, і придорожнім декором: мусить бути ДВА шари,
## один живий, один нерухомий. Один-єдиний шар означав би, що рішення знову ухвалюють за
## назвою виду, і придорожні кущі завмерли разом зі стіною.
func test_a_kind_used_as_both_wall_and_decor_gets_two_layers() -> void:
	_track.rebuild(_world("city"), false)
	await wait_process_frames(2)
	var pair := _layers_of("bush")
	assert_gt(int(pair[0]), 0, "придорожній кущ у city лишається живим")
	assert_gt(int(pair[1]), 0, "той самий кущ у стіні світу — нерухомий")


## Порядок відвідин світів не мусить нічого міняти: раніше позначка накопичувалась між
## rebuild(), і гриб у meadow завмирав назавжди, щойно гравець побував у forest.
func test_visiting_another_world_does_not_freeze_decor_here() -> void:
	_track.rebuild(_world("forest"), false)   # тут mushroom — стіна
	await wait_process_frames(2)
	_track.rebuild(_world("meadow"), false)   # а тут лише придорожній декор
	await wait_process_frames(2)
	var pair := _layers_of("mushroom")
	assert_gt(int(pair[0]), 0, "гриб у meadow ворушиться попри відвідини forest")


## Хмари не кидають тіні на дорогу. Хмара висить за 5–8 м над трасою, і її тінь лягає
## великою м'якою плямою просто на бігове покриття; місце хмари жеребкує ГЛОБАЛЬНИЙ randf(),
## тож пляма з'являється не щоразу — і рівень виглядає по-різному в різних запусках.
func test_clouds_do_not_cast_shadows_on_the_road() -> void:
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_gt(_track._clouds.size(), 0, "хмари в небі є")
	for c in _track._clouds:
		for puff in (c as Node3D).get_children():
			var gi := puff as GeometryInstance3D
			if gi == null:
				continue
			assert_eq(gi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"клубок хмари не кидає тіні на доріжку")
