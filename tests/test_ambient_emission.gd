## НАВКОЛИШНЄ СВІТЛО ДЕКОРУ ВИПРОМІНЕННЯМ — див. Quality.AMBIENT_EMIS.
##
## Заміряно на лузі (Redmi 8A, рівень 1, контроль 0,0%): гілка навколишнього світла коштує
## 8,3 мс із 58,3, і це майже вся ціна освітлення декору — відблиск дає нуль. Просто
## вимкнути її не можна, бо затінені грані падають у чорне. Тому віддаємо її випроміненню:
## навколишнє світло в нас рівне (`albedo * колір * енергія`), а це рівно те, що вміє
## випромінення з множенням, — і воно гілки освітлення не вмикає. Вийшло -7,7 мс при тому
## самому вигляді (яскравість смуги забудови 156,6 проти 158,8).
##
## Тут стережемо не мілісекунди, а те, що робить цю правку правильною:
##   - у «Плавно» вмикається, у «Гарно» ЗНИМАЄТЬСЯ (інакше правка стала б незворотною);
##   - числа беруться з навколишнього світла СВІТУ, а не прибиті;
##   - жоден пропс не має ВЛАСНОГО випромінення, яке ми б мовчки затерли;
##   - і головне — пастка зі спільними матеріалами та лінивими шарами: шар, заведений уже
##     ПІСЛЯ перемикання, мусить дістати той самий стан, а не збережений «оригінал».
extends GutTest

const AMB := Color(0.8, 0.9, 1.0)
const ENERGY := 0.5

var _track: Track


func _world(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/worlds/%s.json" % name, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func before_each() -> void:
	_track = Track.new()
	add_child_autofree(_track)
	await wait_process_frames(2)
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)


func after_each() -> void:
	Quality.unpin()


## Усі матеріали декору, що зараз є в трасі. Якщо їх нема — сторож перевіряє порожнечу, і
## всі перевірки нижче мовчки зелені; саме так уже двічі ховались вади.
func _decor_mats() -> Array:
	var out: Array = []
	for mi in _track._decor_mm:
		var mesh := (mi as MultiMeshInstance3D).multimesh.mesh
		if mesh == null:
			continue
		for si in range(mesh.get_surface_count()):
			var bm := mesh.surface_get_material(si) as BaseMaterial3D
			if bm != null:
				out.append(bm)
	return out


func test_u_plavno_vmykaietsia_u_garno_znymaietsia() -> void:
	Quality.apply_state(Quality.SMOOTH)
	_track.set_ambient_light(AMB, ENERGY)
	var mats := _decor_mats()
	assert_gt(mats.size(), 0, "шари декору мають бути, інакше сторож перевіряє порожнечу")
	for bm in mats:
		assert_true((bm as BaseMaterial3D).disable_ambient_light,
			"у «Плавно» гілку навколишнього світла знято")
		assert_true((bm as BaseMaterial3D).emission_enabled,
			"а те саме світло дає випромінення")
	Quality.apply_state(Quality.PRETTY)
	_track.apply_decor_shading()
	for bm in _decor_mats():
		assert_false((bm as BaseMaterial3D).disable_ambient_light,
			"у «Гарно» навколишнє світло вертається")
		assert_false((bm as BaseMaterial3D).emission_enabled,
			"і випромінення знімається, інакше світло полічиться ДВІЧІ")


## Числа мусять збігатись із навколишнім світлом світу, інакше декор носитиме чуже світло.
func test_chysla_berutsia_zi_svitla_svitu() -> void:
	Quality.apply_state(Quality.SMOOTH)
	_track.set_ambient_light(AMB, ENERGY)
	var mats := _decor_mats()
	assert_gt(mats.size(), 0, "шари декору є")
	for m in mats:
		var bm := m as BaseMaterial3D
		assert_almost_eq(bm.emission_energy_multiplier,
			Track.emission_energy_for(ENERGY, RenderingServer.get_current_rendering_method()), 0.001,
			"енергія випромінення — це енергія навколишнього світла")
		assert_eq(bm.emission_texture, bm.albedo_texture,
			"на ту саму текстуру кольору, інакше візерунок у тіні зникне")
		var ac := bm.albedo_color
		assert_almost_eq(bm.emission.r, AMB.r * ac.r, 0.001, "червоний збігається")
		assert_almost_eq(bm.emission.g, AMB.g * ac.g, 0.001, "зелений збігається")
		assert_almost_eq(bm.emission.b, AMB.b * ac.b, 0.001, "синій збігається")


## Зміна світла світу мусить доїжджати до декору. Без цього вечірній рівень носив би
## навколишнє світло полудня, і це виглядало б не як збій, а як «щось із кольором не так».
func test_zmina_svitla_svitu_doyizhdzhaie() -> void:
	Quality.apply_state(Quality.SMOOTH)
	_track.set_ambient_light(AMB, ENERGY)
	var first: Color = (_decor_mats()[0] as BaseMaterial3D).emission
	_track.set_ambient_light(Color(1.0, 0.5, 0.2), 0.9)
	var second: Color = (_decor_mats()[0] as BaseMaterial3D).emission
	assert_ne(first, second, "нове світло світу міняє випромінення декору")


## ГОЛОВНА ВАДА ПЕРШОЇ РЕДАКЦІЇ, якої не побачили ні 787 тестів, ні знімок.
##
## Семплер випромінення в Godot оголошений «типово ЧОРНИЙ». Тому множення БЕЗ текстури
## кольору дає `emission * 0 = 0`, і грань, відвернута від сонця, чорніє повністю — тобто
## рівно те, чого ми уникали, не вимикаючи навколишнє світло наосліп.
##
## Заміряно рендером (сонце вбік, навколишнє 0,35), яскравість пікселя:
##   без текстури: навколишнє 127,0 | ДОДАВАННЯ 127,0 | множення 0,0
##   з текстурою:  навколишнє  60,0 | додавання 146,0 | МНОЖЕННЯ 60,0
##
## Чому знімок мовчав: на лузі з 101 матеріалу декору текстуру мають 16, і це house_terra —
## єдина велика запечена будівля, що й займає більшу частину кадру. Середня яскравість
## лишилась 156,6 при 158,8, хоч 85 матеріалів осліпли б.
func test_operator_zalezhyt_vid_naiavnosti_tekstury() -> void:
	Quality.apply_state(Quality.SMOOTH)
	_track.set_ambient_light(AMB, ENERGY)
	var with_tex := 0
	var without := 0
	for m in _decor_mats():
		var bm := m as BaseMaterial3D
		if bm.albedo_texture != null:
			with_tex += 1
			assert_eq(bm.emission_operator, BaseMaterial3D.EMISSION_OP_MULTIPLY,
				"з текстурою — множення, інакше колір поверхні полічиться двічі")
		else:
			without += 1
			assert_eq(bm.emission_operator, BaseMaterial3D.EMISSION_OP_ADD,
				"БЕЗ текстури — додавання, інакше грань у тіні стане чорною")
	# Обидва випадки мусять справді траплятись, інакше половина сторожа порожня.
	assert_gt(with_tex, 0, "у трасі є матеріали З текстурою")
	assert_gt(without, 0, "і БЕЗ неї — саме вони й чорніли")


## ПАСТКА, НА ЯКІЙ УЖЕ ГОРІЛИ. Матеріали декору СПІЛЬНІ між шарами, а шари заводяться
## ЛІНИВО, у міру того як їде траса. Кеш «як було» тут отруюється: шар, створений уже після
## перемикання, запам'ятовує вже змінений матеріал як оригінал. Тому перевіряємо саме ту
## послідовність, що ламалась: перемкнути -> завести НОВІ шари -> перемкнути назад.
func test_liniviy_shar_pislia_peremykannia() -> void:
	Quality.apply_state(Quality.SMOOTH)
	_track.set_ambient_light(AMB, ENERGY)
	# Новий світ — нові шари декору, заведені вже ПІСЛЯ перемикання.
	_track.rebuild(_world("forest"), false)
	await wait_process_frames(2)
	var mats := _decor_mats()
	assert_gt(mats.size(), 0, "у лісі теж є декор")
	for bm in mats:
		assert_true((bm as BaseMaterial3D).emission_enabled,
			"шар, заведений після перемикання, теж має випромінення")
	Quality.apply_state(Quality.PRETTY)
	_track.apply_decor_shading()
	for bm in _decor_mats():
		assert_false((bm as BaseMaterial3D).emission_enabled,
			"і назад знімається — жоден матеріал не лишається зіпсованим")


## ПЕРЕДУМОВА ПРАВКИ. Ми затираємо випромінення матеріалів декору. Це безпечно лише доти,
## доки жоден декоративний пропс не світиться сам. Перевірено кодом на 215 матеріалах: власне
## випромінення має рівно один — єдиноріг, шкурка героя, і він не декор. Якщо колись
## з'явиться світний ліхтар, цей тест впаде ДО того, як художник побачить згасле світіння.
func test_zhoden_dekor_ne_svititsia_sam() -> void:
	var lit: Array[String] = []
	var f := FileAccess.open("res://data/props.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	assert_eq(typeof(parsed), TYPE_DICTIONARY, "data/props.json читається")
	var props := parsed as Dictionary
	var looked := 0
	# Запис буває ТРЬОХ видів, і третій — простий РЯДОК-шлях — найчисленніший: із 60 записів
	# таких 49, і серед них уся забудова (house_red, house_terra, city_house_*). Перша
	# редакція тесту їх пропускала, тобто сторож дивився на меншість; сторож `looked > 0`
	# цього не ловив, бо десяток списків лишався.
	var paths: Array[String] = []
	for key in props.keys():
		var entry = props[key]
		if typeof(entry) == TYPE_ARRAY:
			for x in (entry as Array):
				paths.append(str(x))
		elif typeof(entry) == TYPE_DICTIONARY:
			paths.append(str((entry as Dictionary).get("path", "")))
		elif typeof(entry) == TYPE_STRING:
			paths.append(str(entry))
	for path in paths:
		if path == "" or not ResourceLoader.exists(path):
			continue
		looked += 1
		# ПОВЗ КЕШ, і це не дрібниця. `load()` віддав би той самий об'єкт, який траса вже
		# змінила цією ж правкою (матеріали спільні між PropLibrary й сценою), і тест
		# побачив би ВЛАСНЕ випромінення замість авторського. Саме так він і впав уперше.
		var scene := ResourceLoader.load(path, "PackedScene",
			ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		if scene == null:
			continue
		var inst := scene.instantiate()
		_collect_lit(inst, path, lit)
		inst.free()
	assert_gt(looked, 40,
		"оглянути треба ВСІ пропси, а не лише записані списком: із 60 записів 49 — простий "
		+ "рядок-шлях, і саме там уся забудова (оглянуто %d)" % looked)
	assert_eq(lit.size(), 0,
		"пропс із власним випроміненням затреться правкою навколишнього світла: %s"
		% ", ".join(lit))


func _collect_lit(n: Node, path: String, out: Array[String]) -> void:
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null:
		for si in range(mi.mesh.get_surface_count()):
			var bm := mi.mesh.surface_get_material(si) as BaseMaterial3D
			if bm != null and bm.emission_enabled:
				out.append(path)
	for c in n.get_children():
		_collect_lit(c, path, out)


## ПОКИ ТРИВАЄ ДОСЛІД, ТРАСА ВІДСТУПАЄ. Без цього траса й проба пишуть у ті самі спільні
## матеріали, і перемагає траса: `apply_decor_shading` кличеться зі зміни світла світу,
## тобто фактично щокадру, а прапорці повторюються раз на секунду. Наслідок був такий, що
## всі варіанти серії закінчували в ОДНАКОВОМУ стані, і проба міряла шум.
func test_pid_chas_doslidu_trasa_ne_pyshe() -> void:
	Quality.apply_state(Quality.SMOOTH)
	_track.set_ambient_light(AMB, ENERGY)
	var bm := _decor_mats()[0] as BaseMaterial3D
	# Проба «написала своє».
	_track.strip_owns_decor_mats = true
	bm.emission_enabled = false
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_track.apply_decor_shading()
	assert_false(bm.emission_enabled, "траса не перебиває дослід")
	assert_eq(bm.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED,
		"і режим затінення теж лишає пробі")
	# Дослід скінчився — керування вертається трасі.
	_track.strip_owns_decor_mats = false
	_track.apply_decor_shading()
	assert_true(bm.emission_enabled, "після досліду траса розставляє все наново")


## Важіль, яким проба знімає САМУ оптимізацію. Прапорці досліду вміють лише забирати
## намальоване, тож зняти оптимізацію ними не можна — без цього важеля довести її ціну
## нічим (див. `force_decor_cull`, зроблений із тієї самої причини).
func test_vazhil_znimaie_samu_optymizatsiiu() -> void:
	Quality.apply_state(Quality.SMOOTH)
	_track.set_ambient_light(AMB, ENERGY)
	var bm := _decor_mats()[0] as BaseMaterial3D
	assert_true(bm.emission_enabled, "у «Плавно» правка діє")
	_track.force_ambient_emis = 0
	_track.apply_decor_shading()
	assert_false(bm.emission_enabled, "важіль знімає правку")
	assert_false(bm.disable_ambient_light, "і вертає гілку навколишнього світла")
	_track.force_ambient_emis = -1
	_track.apply_decor_shading()
	assert_true(bm.emission_enabled, "-1 означає «за станом якості»")


## До першого set_ambient_light випромінення не ставиться взагалі: інакше довелось би
## прибити початкові числа, і вони стали б ЧЕТВЕРТОЮ копією тих самих значень (run3d.tscn,
## AMBIENT_ENERGY, _light_k), яка розійшлась би мовчки.
func test_do_pershoho_svitla_vyprominennia_nema() -> void:
	Quality.apply_state(Quality.SMOOTH)
	var fresh := Track.new()
	add_child_autofree(fresh)
	await wait_process_frames(2)
	fresh.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	var mats: Array = []
	for mi in fresh._decor_mm:
		var mesh := (mi as MultiMeshInstance3D).multimesh.mesh
		if mesh == null:
			continue
		for si in range(mesh.get_surface_count()):
			var bm := mesh.surface_get_material(si) as BaseMaterial3D
			if bm != null:
				mats.append(bm)
	assert_gt(mats.size(), 0, "шари декору є")
	for bm in mats:
		assert_false((bm as BaseMaterial3D).emission_enabled,
			"поки світло світу не сказали, випромінення не ставимо")


## ДУБЛЬОВАНІ ЧИСЛА. Навколишнє світло живе у ДВОХ місцях: у сцені `run3d.tscn` (щоб воно
## було ще до першого кадру) і в коді як `AMBIENT_COLOR`/`AMBIENT_ENERGY` (щоб декор міг
## відтворити його випроміненням). Поки декор брав світло з рушія, розходження нічого не
## значило; тепер воно означало б, що декор світиться інакше, ніж світиться все решта, —
## і це видно не як збій, а як «щось із кольором не так», тобто найдовше.
func test_chysla_navkolyshnioho_svitla_ne_rozijshlys() -> void:
	var scene := load("res://src/run3d/run3d.tscn") as PackedScene
	var inst := scene.instantiate()
	var we: WorldEnvironment = null
	for c in inst.get_children():
		if c is WorldEnvironment:
			we = c as WorldEnvironment
			break
	assert_not_null(we, "у сцені є WorldEnvironment")
	var run := load("res://src/run3d/run3d.gd")
	assert_eq(we.environment.ambient_light_color, run.AMBIENT_COLOR,
		"колір навколишнього світла у сцені й у коді — одне число")
	assert_almost_eq(we.environment.ambient_light_energy, run.AMBIENT_ENERGY, 0.0001,
		"і енергія теж")
	inst.free()


## СТОРОЖ, ЯКИЙ НЕ СПРАЦЬОВУВАВ ЖОДНОГО РАЗУ — і це коштувало хибного висновку.
##
## `_set_sky` рахує колір неба від `session_t / session_total` і кличеться ЩОКАДРУ, тож
## навколишнє світло повзе щокадру на мікроскопічну величину. Перша редакція порівнювала
## на точну рівність, тому прохід по всіх шарах ішов кожен кадр — а заморожена проба цього
## не бачила, бо вона гру зупиняє. Через це два прогони дали протилежні відповіді про
## місто: заморожена точка +3,1 мс, жива розгортка −4,1.
##
## Тут відтворюємо саме той рух: десять секунд по 60 кадрів із кроком, яким світло повзе
## за сеанс, і вимагаємо, щоб перерахунків були одиниці, а не шістсот.
func test_povzuche_svitlo_ne_pererahovuie_shchokadru() -> void:
	Quality.apply_state(Quality.SMOOTH)
	_track.set_ambient_light(Color(0.5, 0.5, 0.5), 0.35)
	var before: int = _track._amb_applies
	# Третина діапазону за сеанс ~ 600 с; за 10 с (600 кадрів) — 1/180 діапазону.
	var step := (1.0 / 3.0) / 600.0 / 60.0
	for i in range(600):
		var v := 0.5 + step * float(i)
		_track.set_ambient_light(Color(v, v, v), 0.35)
	var applies: int = _track._amb_applies - before
	assert_lt(applies, 20,
		"за 600 кадрів повзучого світла перерахунків має бути кілька, а не кожен кадр "
		+ "(було %d)" % applies)
	assert_gt(applies, 0, "і не нуль: світло таки змінилось, декор мусить це наздогнати")



## ОСВІТЛЕННЯ ПОЛОТНА ДОРОГИ — НА ВЕРШИНУ. Плитка це коробка, у грані стала нормаль, світло
## напрямлене, тіні в «Плавно» вимкнено — отже на вершину й на піксель дають те саме число.
## Перевірено рендером: різниця 1-2 з 255. Заміряно: -2,55 мс на лузі, -3,90 на хмаринках.
func test_polotno_svititsia_za_stanom_yakosti() -> void:
	var t := _track
	var mats: Array = []
	for key in ["_mm_surface", "_mm_edge"]:
		var mi = t.get(key)
		assert_not_null(mi, "шар %s існує, інакше сторож перевіряє порожнечу" % key)
		var bm = (mi as MultiMeshInstance3D).material_override as BaseMaterial3D
		assert_not_null(bm, "у шару %s є матеріал" % key)
		mats.append(bm)
	# ОДРАЗУ ПІСЛЯ СТВОРЕННЯ, без жодного перемикання якості: рівно на цьому спіймали канали.
	var want := BaseMaterial3D.SHADING_MODE_PER_VERTEX \
		if Quality.vertex_lit_of(Quality.effective()) \
		else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	for bm in mats:
		assert_eq((bm as BaseMaterial3D).shading_mode, want,
			"полотно бере режим зі стану якості вже при створенні")
	# І слідує за станом в обидва боки.
	#
	# Стан ПРИБИВАЄМО НАПРЯМУ, а не через `apply_state`. Той крім прибивання ще й застосовує
	# стан до в'юпорта — міняє масштаб рендера, — а це будить `resized` у Control'ів, серед
	# яких трапляється звільнений попереднім тестом. Тест падав не через дорогу, а через це:
	# поодинці був зелений, у наборі ні. Предмет цього сторожа — як ТРАСА ЧИТАЄ стан якості;
	# застосування стану до в'юпорта стереже test_quality_shadows.
	Quality._pinned = Quality.PRETTY
	t.apply_decor_shading()
	for bm in mats:
		assert_eq((bm as BaseMaterial3D).shading_mode, BaseMaterial3D.SHADING_MODE_PER_PIXEL,
			"у «Гарно» полотно вертається на піксель")
	Quality._pinned = Quality.SMOOTH
	t.apply_decor_shading()
	for bm in mats:
		assert_eq((bm as BaseMaterial3D).shading_mode, BaseMaterial3D.SHADING_MODE_PER_VERTEX,
			"у «Плавно» — на вершину")
	Quality.unpin()


## І ОКРЕМО: полотно правильне ВЖЕ ПРИ СТВОРЕННІ траси, без жодної перебудови світу.
##
## Сторож вище цього не ловить: `before_each` робить `rebuild()`, а той заводить шари декору
## й тим самим кличе `apply_decor_shading()` — режим доїжджає обхідним шляхом. Тут беремо
## голу трасу, якої ніхто не перебудовував: якщо виставлення при створенні прибрати,
## світ без жодного шару декору лишив би дорогу на пікселі. Рівно цим схибили канали.
func test_polotno_pravylne_vzhe_pry_stvorenni() -> void:
	var fresh := Track.new()
	add_child_autofree(fresh)
	await wait_process_frames(2)
	var want := BaseMaterial3D.SHADING_MODE_PER_VERTEX \
		if Quality.vertex_lit_of(Quality.effective()) \
		else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	var seen := 0
	for key in ["_mm_surface", "_mm_edge"]:
		var mi = fresh.get(key)
		assert_not_null(mi, "шар %s існує" % key)
		var bm = (mi as MultiMeshInstance3D).material_override as BaseMaterial3D
		assert_not_null(bm, "у шару %s є матеріал" % key)
		seen += 1
		assert_eq((bm as BaseMaterial3D).shading_mode, want,
			"%s: режим виставлено при створенні, без rebuild()" % key)
	assert_eq(seen, 2, "обидва шари полотна оглянуто")


## ГАММА COMPATIBILITY. У `mobile` випромінення й навколишнє світло збігаються один в один —
## і саме там я перевіряв правку на Маку, бо це рушій проєкту за замовчуванням. Але телефон і
## веб працюють у `gl_compatibility`, і там випромінення світило ВДВІЧІ слабше: замовник
## побачив «темні, тьмяні» будинки. Навколишнє світло там проходить sRGB-перетворення, а
## випромінення ні, тож потрібна енергія — `енергія ^ (1 / 2,2)`.
##
## Числа нижче — заміряний рендером множник, при якому випромінення дає ту саму яскравість
## затіненої грані, що й навколишнє світло. Сторож стереже, щоб формула лягала на них.
func test_hamma_compatibility() -> void:
	for pair in [[0.20, 2.35], [0.35, 1.72], [0.60, 1.30]]:
		var e: float = pair[0]
		var measured: float = pair[1]
		var k := Track.emission_energy_for(e, "gl_compatibility") / e
		assert_almost_eq(k, measured, 0.1,
			"енергія %.2f: формула дає множник %.2f, заміряно %.2f" % [e, k, measured])
	# У mobile і forward_plus поправки немає: там вони збігались і без неї.
	for m in ["mobile", "forward_plus"]:
		assert_almost_eq(Track.emission_energy_for(0.35, m), 0.35, 0.0001,
			"%s: випромінення дорівнює навколишньому світлу без поправки" % m)

