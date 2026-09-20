## ПРОГРІВ: усе, що вимагатиме диска чи нового шару, має статись на завантаженні, а не в бігу.
##
## Звідки взявся. Проба з трасуванням сплесків (tools/probe/, поле "spikes") показала на рівні 1
## чотири пачки кадрів по 26–48 мс — на 2,9 / 21,6 / 37,1 / 46,4 метрах, щоразу на тих самих
## місцях. У контексті сплеску росло число шарів декору: кожен новий шар — це новий
## MultiMeshInstance3D, читання меша з PropLibrary і перше малювання його матеріалом. Окремо
## знайшлось, що перша поява кожного виду ПЕРЕШКОДИ читає GLB просто в кадрі бігу (17 мешів,
## 27,4 мс разом на Лузі).
##
## Обидва прогріви мовчазні: якщо котрийсь перестане працювати, гра гратиметься так само, а
## заїкання повернуться — і побачити це можна буде лише пробою на 1800 кадрів.
extends GutTest

var _track: Track


func before_each() -> void:
	_track = Track.new()
	add_child_autofree(_track)
	await wait_process_frames(2)


func _world(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/worlds/%s.json" % name, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _rec(z: float, kind: String) -> Dictionary:
	return {"z_m": z, "kind": kind}


## Головне: після дозавантаження цеглинки шари на всі її види ВЖЕ є, і декоруванню нема
## чого заводити посеред бігу.
func test_zapysy_tsehlynky_hriiut_svoi_shary() -> void:
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	_track.add_authored_timeline([_rec(10.0, "beehive"), _rec(20.0, "fence")], [])
	var warmed := _track._decor_mm.size()
	# Те саме ще раз: шарів не побільшало — ключ той самий, отже й шар той самий.
	_track.add_authored_timeline([_rec(30.0, "beehive"), _rec(40.0, "fence")], [])
	assert_eq(_track._decor_mm.size(), warmed,
		"той самий вид із тим самим ключем не заводить другого шару")


## Гойдалка входить у ключ шару: той самий вид як стіна і як придорожній декор — це ДВА шари,
## і прогріти треба обидва. Саме на цьому попередній прогрів і промахувався.
func test_stina_i_dekor_tse_dva_riznykh_shary() -> void:
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	_track.add_authored_timeline([_rec(10.0, "bush")], [])
	var only_decor := _track._decor_mm.size()
	_track.add_authored_timeline([], [_rec(20.0, "bush")])
	assert_gt(_track._decor_mm.size(), only_decor,
		"кущ-стіна дістає свій шар, а не ділить його з придорожнім")


## Невідомий вид не має ні падати, ні заводити шару — у рівнях трапляються назви моделей,
## яких ще нема (див. docs/tasks/props.md).
func test_nevidomyi_vyd_ne_zavodyt_sharu() -> void:
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	var before := _track._decor_mm.size()
	_track.add_authored_timeline([_rec(10.0, "такого_виду_нема")], [])
	assert_eq(_track._decor_mm.size(), before)


## Перезапуск рівня скидає кеш прогріву разом із таймлайном — інакше другий рівень поспіль
## вважав би прогрітим те, чого в його шарах немає.
func test_ochyshchennia_skydaie_kesh_prohrivu() -> void:
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	_track.add_authored_timeline([_rec(10.0, "beehive")], [])
	_track.clear_authored_timeline()
	assert_eq(_track._prewarmed.size(), 0, "кеш прогріву не переживає очищення таймлайну")


## Спавнер читає меші всіх перешкод світу наперед. Перевіряємо не час, а факт: після
## configure() кеш PropLibrary вже містить кожен вид зі списку світу.
func test_spavner_hriie_meshi_perechkod() -> void:
	var world := _world("meadow")
	PropLibrary.reload()          # чистий кеш: інакше його міг наповнити сусідній тест
	var spawner := Spawner3D.new()
	add_child_autofree(spawner)
	var hero := Hero3D.new()
	add_child_autofree(hero)
	await wait_process_frames(2)
	spawner.configure({}, world, hero, null, null)
	var cold := []
	for kind in (world.get("obstacles", {}) as Dictionary):
		var d: Dictionary = world["obstacles"][kind]
		var prop := String(d.get("prop", d.get("voxel", kind)))
		if PropLibrary.variants(prop) > 0 and not PropLibrary._mesh_cache.has("%s#0" % prop):
			cold.append(prop)
	assert_eq(cold, [], "після configure() жоден вид перешкоди не лишився нечитаним: %s" % [cold])
