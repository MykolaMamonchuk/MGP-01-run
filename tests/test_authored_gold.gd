## ЗОЛОТО СТАЄ АВТОРСЬКИМ — і це передумова всієї економіки, а не косметика.
##
## Як було. Перешкоди на рівнях 1–8 розставляє автор цеглинки (5–6 маркерів на 150 м), а
## золото лишалось єдиним випадковим: `_spawn_authored_collectibles()` сипав лінію з 5 у
## ВІЛЬНІЙ доріжці за КОЖНОЮ групою перешкод. Наслідків два, і обидва заміряні 21.09.2026
## пробою (`coins_spawned` у probe.json):
##
##   1. Золото не могло нічого сказати. Воно завжди лежало там, де й так безпечно, тож ним
##      не можна ні повести дитину («монетки показують, куди стрибати»), ні заплатити за
##      ризик, ні відсвяткувати складний шматок.
##   2. Його кількість ніхто не задумував. Монет на 150 м: 31 у першому світі, 40 у п'ятому,
##      55 у восьмому — бо золото прив'язане до кількості груп перешкод, а та росте зі
##      щільністю. Тобто складність тягла за собою дохід, хоч це різні осі.
##
## Тепер цеглинка може поставити золото сама — маркером із роллю `gold`, ФІГУРОЮ.
extends GutTest

var _spawner: Spawner3D
var _hero: Hero3D


func before_each() -> void:
	_hero = Hero3D.new()
	add_child_autofree(_hero)
	_spawner = Spawner3D.new()
	add_child_autofree(_spawner)
	_spawner.hero = _hero
	await wait_process_frames(1)


func _gold(z: float, kind: String, lane: int, ov: Dictionary) -> Dictionary:
	return {"z_m": z, "kind": kind, "lane": lane, "override": ov, "y_m": 0.0}


func _ingots() -> Array:
	var out := []
	for c in _spawner.get_children():
		if c is Ingot3D:
			out.append(c)
	return out


## Роль `gold` доїжджає до розбору окремим списком, а не змішується з пікапами-хелперами.
func test_rol_gold_rozbyraietsia_okremo() -> void:
	var layout := Node3D.new()
	add_child_autofree(layout)
	var m := LevelMarker3D.new()
	m.role = "gold"
	m.kind = "line"
	m.position = Vector3(0.0, 0.0, -42.0)
	layout.add_child(m)
	var out := LevelTimeline.extract(layout, 0.0)
	assert_eq((out.get("gold", []) as Array).size(), 1, "запис поїхав у «gold»")
	assert_eq((out.get("pickups", []) as Array).size(), 0, "і НЕ поїхав у пікапи-хелпери")


## Фігура — це багато монет із одного маркера. Інакше цеглинку довелося б засівати трьома
## десятками маркерів поштучно, і редагувати це було б неможливо.
func test_odyn_marker_daie_tsilu_figuru() -> void:
	_spawner.set_authored_gold([_gold(10.0, "line", 0, {"n": 7})])
	_spawner.distance_m = 10.0
	_spawner._advance_authored_gold()
	assert_eq(_ingots().size(), 7, "лінія з семи монет із одного маркера")


## «Перейди в сусідню доріжку» — монети мусять справді ВЕСТИ, тобто змінювати x.
func test_climb_vede_z_dorizhky_v_dorizhku() -> void:
	_spawner.set_authored_gold([_gold(10.0, "climb", -1, {"n": 5, "to_lane": 1})])
	_spawner.distance_m = 10.0
	_spawner._advance_authored_gold()
	var xs := []
	for i in _ingots():
		xs.append((i as Ingot3D).position.x)
	assert_eq(xs.size(), 5)
	xs.sort()
	assert_almost_eq(xs[0], -Hero3D.LANE_W, 0.01, "починається в лівій доріжці")
	assert_almost_eq(xs[-1], Hero3D.LANE_W, 0.01, "кінчається в правій")


## Номінал — окрема ручка від кількості. Балансувати дохід, не чіпаючи картинки: дитина
## бачить ту саму купку, а коштує вона вдвічі більше.
func test_nominal_okremo_vid_kilkosti() -> void:
	_spawner.set_authored_gold([_gold(10.0, "line", 0, {"n": 3, "value": 5})])
	_spawner.distance_m = 10.0
	_spawner._advance_authored_gold()
	var total := 0
	for i in _ingots():
		total += int((i as Ingot3D).value)
	assert_eq(_ingots().size(), 3, "монет три")
	assert_eq(total, 15, "а номіналу п'ятнадцять")


## ГОЛОВНЕ. Поставила цеглинка золото сама — випадкова лінія за групою більше не сипле.
## Інакше автор просив би одне, рівень давав би це плюс випадкове зверху, і жоден бюджет
## не сходився б.
func test_avtorske_zoloto_vymykaie_vypadkovu_liniiu() -> void:
	assert_false(_spawner.has_authored_gold(), "поки маркерів нема — старий шлях")
	_spawner.set_authored_gold([_gold(10.0, "line", 0, {"n": 3})])
	assert_true(_spawner.has_authored_gold())
	var before := _ingots().size()
	_spawner._spawn_authored_collectibles(0)
	assert_eq(_ingots().size(), before, "випадкова лінія за групою не додалась")


## І навпаки: поки цеглинки золота не ставлять, усе працює як раніше. Рівні 9–17 ще не
## переведені на цеглинки взагалі, і зламати їх цією зміною не можна.
func test_bez_markeriv_staryi_shliakh_tsilyi() -> void:
	_spawner.clear_authored_gold()
	_spawner._spawn_authored_collectibles(0)
	assert_gt(_ingots().size(), 0, "лінія з 5 за групою на місці")


## ── Знайдено рецензією, полагоджено; далі — сторожі саме на це ──────────────────

## Дуга мусить лягати ТАМ, де маркер, а не «просто перед героєм». spawn_star_arc() писалась
## для події «герой летить ПРЯМО ЗАРАЗ» і мала зашите z = -3.0; авторський маркер стоїть на
## SPAWN_Z, за 34 м попереду, тож дуга спалахувала б у кадрі за 26 м не там.
func test_duha_laiaie_de_marker_a_ne_pered_heroiem() -> void:
	_spawner.set_authored_gold([_gold(10.0, "arc", 0, {"n": 6})])
	_spawner.distance_m = 10.0
	_spawner._advance_authored_gold()
	var zs := []
	for i in _ingots():
		zs.append((i as Ingot3D).position.z)
	assert_eq(zs.size(), 6)
	zs.sort()
	assert_lt(zs[-1], Spawner3D.SPAWN_Z + 0.01, "уся дуга не ближче за лінію спавну")


## Номінал у дузі теж мусить діяти: доти spawn_star_arc() такого параметра не мала взагалі,
## і всі монети дуги були по одиниці, хоч документація обіцяла протилежне.
func test_duha_shanuie_nominal() -> void:
	_spawner.set_authored_gold([_gold(10.0, "arc", 0, {"n": 4, "value": 3})])
	_spawner.distance_m = 10.0
	_spawner._advance_authored_gold()
	var total := 0
	for i in _ingots():
		total += int((i as Ingot3D).value)
	assert_eq(total, 12, "чотири монети по три")


## Купка біля краю дороги не має складатись. Доти кожна колонка затискалась окремо, тож на
## трьох доріжках w=3 і lane=1 давали колонки 0,1,1 — дві монети в одній точці: дитина
## бачить одну, а лічильник рахує дві.
func test_kupka_bilia_kraiu_ne_skladaietsia() -> void:
	_spawner.set_authored_gold([_gold(10.0, "cluster", 1, {"n": 6, "w": 3})])
	_spawner.distance_m = 10.0
	_spawner._advance_authored_gold()
	var seen := {}
	var dupes := 0
	for i in _ingots():
		var p: Vector3 = (i as Ingot3D).position
		var key := "%.2f|%.2f" % [p.x, p.z]
		if seen.has(key):
			dupes += 1
		seen[key] = true
	assert_eq(_ingots().size(), 6, "усі шість монет на місці")
	assert_eq(dupes, 0, "жодні дві не лежать в одній точці")


## ВЕЛИКИЙ ЗЛИТОК не має зникати. Доти він жив усередині випадкової лінії, а та вимикається
## авторським золотом — і `_big_due` лишався піднятим назавжди (бо _tick_big() виходить
## одразу, поки він true). У моделі EDD це 64–104 номіналу за рівень, до чверті доходу.
func test_velykyi_zlytok_zhyvyi_i_z_avtorskym_zolotom() -> void:
	_spawner.set_authored_gold([_gold(10.0, "line", 0, {"n": 3})])
	_spawner._big_due = true
	_spawner.distance_m = 0.0
	_spawner._spawn_authored_collectibles(0)
	var big := 0
	for i in _ingots():
		if (i as Ingot3D).is_big():
			big += 1
	assert_eq(big, 1, "великий злиток з'явився попри авторське золото")
	assert_false(_spawner._big_due, "і таймер знову пішов, а не завис назавжди")


## Перемикач діє на ВІДРІЗОК, а не на рівень. Рівень збирається зі спільної бібліотеки, тож
## змішаний склад — частина цеглинок переведена, частина ні — це нормальний стан міграції.
## З прапорцем на рівень перша ж цеглинка із золотом лишала всі наступні геть без монет.
func test_perkemykach_diie_na_vidrizok_a_ne_na_riven() -> void:
	# Цеглинка 0–150 м ставить золото сама, далі — непереведена.
	_spawner.add_authored_gold([_gold(50.0, "line", 0, {"n": 5})], 0.0, 150.0)
	assert_true(_spawner.has_authored_gold_at(50.0), "усередині переведеної цеглинки")
	assert_false(_spawner.has_authored_gold_at(200.0), "а далі — старий шлях")
	# І на практиці: на 200-му метрі випадкова лінія мусить сипатись як раніше.
	_spawner.distance_m = 200.0 - absf(Spawner3D.SPAWN_Z)
	var before := _ingots().size()
	_spawner._spawn_authored_collectibles(0)
	assert_gt(_ingots().size(), before, "на непереведеній ділянці монети є")
