## Поручні вздовж берега (fence_rail) — декор, що тягнеться СУЦІЛЬНО, а не стоїть окремими
## предметами. Тут стережемо саме те, що робить його суцільним і що легко зламати мовчки:
## ланка на кожен ряд, однаковий тип уздовж усієї стрічки, і розрив там, де місток.
extends GutTest

var _track: Track


func _world(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/worlds/%s.json" % name, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func before_each() -> void:
	PropLibrary.reload()
	_track = Track.new()
	add_child_autofree(_track)
	await wait_process_frames(2)


## Номери шарів, у яких лежить саме ця модель (у виду може бути кілька типів — кілька шарів).
func _rail_layers() -> Array:
	var out := []
	for key in _track._decor_layer_of.keys():
		if String(key).begins_with("fence_rail"):
			out.append(int(_track._decor_layer_of[key]))
	return out


func _rail_records() -> Array:
	var layers := _rail_layers()
	var out := []
	for r in _track._decor_ids.size():
		var ids: PackedInt32Array = _track._decor_ids[r]
		for j in ids.size():
			if layers.has(ids[j]):
				out.append({"row": r, "layer": ids[j]})
	return out


func test_rail_runs_along_both_banks() -> void:
	if not PropLibrary.has("fence_rail"):
		pass_test("моделі поручнів ще нема — крок пропущено")
		return
	_track.rebuild(_world("meadow"), false)          # канал з обох боків
	await wait_process_frames(2)
	var recs := _rail_records()
	assert_gt(recs.size(), Track.ROWS, "поручні є на обох берегах майже кожного ряду")


## Найважливіше. Типів моделі кілька, і вони РІЗНОЇ ВИСОТИ (0,26 проти 0,41 м): якби тип
## вибирався на кожну ланку, огорожа стрибала б уздовж берега вгору-вниз. Правило ширше за
## поручні — одна мапа тримає один тип КОЖНОГО виду (див. test_prop_library.gd).
func test_whole_run_uses_one_model_type() -> void:
	if PropLibrary.variants("fence_rail") < 2:
		pass_test("типів менше двох — перевіряти нічого")
		return
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	var seen := {}
	for r in _rail_records():
		seen[r["layer"]] = true
	assert_eq(seen.size(), 1, "уся стрічка з одного типу моделі")


## Світ без каналу поручнів не отримує: вони стоять по берегу, а берега нема.
func test_no_canal_no_rail() -> void:
	_track.rebuild(_world("forest"), false)          # canal.side == "none"
	await wait_process_frames(2)
	assert_eq(_rail_records().size(), 0, "без каналу поручнів нема")


## Проріз в узбіччі під канал. Досі канал існував тільки в даних: вода, береги й містки
## малювались, але плита узбіччя завтовшки 0,4 м накривала їх, і рівень «над річкою»
## виглядав як лужок. Тут стережемо саме геометрію прорізу, а не сам факт води.
func test_verge_opens_a_gap_for_the_canal() -> void:
	var w := _world("meadow")
	_track.rebuild(w, false)
	await wait_process_frames(2)
	# Числа беремо ЗІ СВІТУ, а не зашиваємо. Перевіряти тут треба формулу прорізу, а не
	# конкретні 2,0 і 1,2: зашиті значення перетворюють тест на замок, який не пускає
	# міняти сам світ — саме на це він одного разу й перетворився.
	var canal: Dictionary = w.get("canal", {})
	var offset := float(canal.get("offset", 2.0))
	var width := float(canal.get("width", 1.2))
	var parts := _track._side_strips(1.0, 1.5 + Track.SIDE_W * 0.5, Track.SIDE_W * 0.5)
	assert_eq(parts.size(), 2, "дві смуги")
	var inner: Dictionary = parts[0]
	var outer: Dictionary = parts[1]
	assert_almost_eq(float(inner["sx"]) * Track.SIDE_W, offset, 0.001, "внутрішня смуга = відступ каналу")
	var inner_far: float = float(inner["x"]) + float(inner["sx"]) * Track.SIDE_W * 0.5
	var outer_near: float = float(outer["x"]) - float(outer["sx"]) * Track.SIDE_W * 0.5
	assert_almost_eq(outer_near - inner_far, width, 0.001, "проріз завширшки з воду")


func test_no_canal_keeps_the_verge_solid() -> void:
	_track.rebuild(_world("forest"), false)          # canal.side == "none"
	await wait_process_frames(2)
	var parts := _track._side_strips(1.0, 1.5 + Track.SIDE_W * 0.5, Track.SIDE_W * 0.5)
	assert_almost_eq(float(parts[0]["sx"]) * Track.SIDE_W, Track.SIDE_W, 0.001, "узбіччя суцільне")
	assert_eq(float(parts[1]["sx"]), 0.0, "друга смуга не потрібна")


## Ланки поручнів НЕ мають ділити площину із сусідніми. Ряд траси — рівно 1,0 м; якщо ланка
## така сама або ширша, торцеві грані сусідів лягають одна в одну, а матеріали пропсів усі
## двобічні (doubleSided у .glb) — тобто рендер малює ОБИДВІ грані на тій самій глибині й не
## може вибрати. У русі це читається як миготіння кольору на поручнях, рівно щометра вздовж
## берега; саме такий крок і на знімках гравця.
##
## Історія, щоб не повторити: спершу було 1.0009 і 1.0002 м — сусіди заходили одна в одну на
## частку міліметра. Підігнав «рівно 1,0» — стало ГІРШЕ: торці збіглися точно, і z-fight пішов
## уже по всій площі торця, а не по міліметровій смужці. Правильно — лишити зазор.
const RAIL_GAP := 0.002          # 2 мм на стик: на екрані це десята пікселя, зазору не видно
const RAIL_GAP_TOL := 0.0005


func test_rail_links_leave_a_hairline_gap_and_never_overlap() -> void:
	var n := PropLibrary.variants("fence_rail")
	assert_gt(n, 0, "поручні взагалі є в props.json")
	for v in range(n):
		var mesh := PropLibrary.mesh("fence_rail", v)
		assert_not_null(mesh, "варіант %d має меш" % v)
		if mesh == null:
			continue
		# Ланку ставлять поперек ряду (поворот на 90°), тож уздовж траси лягає X моделі.
		var along := mesh.get_aabb().size.x * float(PropLibrary.tweak("fence_rail", v)["scale"])
		assert_almost_eq(along, 1.0 - RAIL_GAP, RAIL_GAP_TOL,
			"ланка %d коротша за ряд на волосину — не впритул і не з напуском" % v)
		assert_lt(along, 1.0, "ланка %d не досягає сусідньої" % v)


## ── Розрив під АВТОРСЬКИЙ місток ──────────────────────────────────────────────────────────
## Досі розрив у стрічці поручнів працював лише тому, що місток і поручні кладе одна й та сама
## процедура: вона сама знала, на якому ряду поставила настил (`bridge_row`). Коли містки
## переїжджають у маркери сцени (kind "bridge_plank" у levels/level_XX/chunk_NN.tscn), процедура
## про них не знає взагалі — і стрічка поручнів перегороджує прохід на місток, тобто автор
## поставив перехід, а пройти ним не можна.
##
## Тут стережемо саме це: авторський місток робить у поручнях такий самий розрив, як і
## процедурний, і робить його ЛИШЕ на своєму борті й ЛИШЕ на своєму ряду.
const AUTHORED_BRIDGE_Z := 12.0


## Лужок без процедурних містків: тоді єдиний розрив у суцільній стрічці може бути тільки від
## авторського маркера, і тест не залежить від того, куди цього разу впав випадковий проміжок.
func _meadow_without_procedural_bridges() -> Dictionary:
	var w := _world("meadow")
	w["bridges_every"] = 0
	return w


func _authored_bridge(z: float, x: float) -> Dictionary:
	return {"z_m": z, "x_m": x, "y_m": 0.0, "kind": "bridge_plank",
		"lane": 0, "override": {}, "yaw_deg": 0.0, "scale": 1.0}


## X усіх ланок поручнів у ряду, який зараз представляє відстань z (вікно ряду — те саме ±0,5 м,
## що і в Track._decorate_authored()).
func _rail_xs_near(z: float) -> Array:
	var layers := _rail_layers()
	var out := []
	for r in _track._decor_ids.size():
		var d: float = _track._row_distance_m[r]
		if z < d - 0.5 or z >= d + 0.5:
			continue
		var ids: PackedInt32Array = _track._decor_ids[r]
		var data: PackedFloat32Array = _track._decor_data[r]
		for j in ids.size():
			if layers.has(ids[j]):
				out.append(data[j * Track.DECOR_STRIDE])
	return out


func _rails_on(z: float, side: float) -> int:
	var n := 0
	for x in _rail_xs_near(z):
		if signf(float(x)) == side:
			n += 1
	return n


## Центр каналу на правому борті — саме там, де автор ставить настил.
func _bridge_x(side: float) -> float:
	var canal: Dictionary = _track.world.get("canal", {})
	return side * (_track.road_width() * 0.5
		+ float(canal.get("offset", 2.0)) + float(canal.get("width", 1.2)) * 0.5)


## Контроль. Без нього перевірка нижче нічого не стереже: якби поручнів на цьому ряду не було
## й так, «розрив» показався б і на зламаному коді.
func test_control_rail_runs_on_both_banks_when_no_bridge_is_authored() -> void:
	_track.rebuild(_meadow_without_procedural_bridges(), false)
	await wait_process_frames(2)
	assert_eq(_rails_on(AUTHORED_BRIDGE_Z, -1.0), 1, "контроль: ланка на лівому березі є")
	assert_eq(_rails_on(AUTHORED_BRIDGE_Z, 1.0), 1, "контроль: ланка на правому березі є")


func test_authored_bridge_opens_a_gap_in_the_rail() -> void:
	var w := _meadow_without_procedural_bridges()
	_track.rebuild(w, false)
	await wait_process_frames(2)
	var x := _bridge_x(1.0)
	_track.set_authored_timeline([_authored_bridge(AUTHORED_BRIDGE_Z, x)], [])
	_track.rebuild(w, false)
	await wait_process_frames(2)
	assert_eq(_rails_on(AUTHORED_BRIDGE_Z, 1.0), 0,
		"на ряду з авторським містком поручнів нема — інакше вони перегородили б прохід")


## Розрив рівно там, де місток: на другому борті стрічка суцільна (місток же на одному боці).
func test_authored_bridge_does_not_open_a_gap_on_the_other_bank() -> void:
	var w := _meadow_without_procedural_bridges()
	_track.rebuild(w, false)
	await wait_process_frames(2)
	_track.set_authored_timeline([_authored_bridge(AUTHORED_BRIDGE_Z, _bridge_x(1.0))], [])
	_track.rebuild(w, false)
	await wait_process_frames(2)
	assert_eq(_rails_on(AUTHORED_BRIDGE_Z, -1.0), 1, "протилежний берег місток не чіпає")


## І рівно один ряд: сусідні ряди лишаються з поручнями, інакше в стрічці зяяла б діра.
func test_authored_bridge_gap_is_exactly_one_row_wide() -> void:
	var w := _meadow_without_procedural_bridges()
	_track.rebuild(w, false)
	await wait_process_frames(2)
	_track.set_authored_timeline([_authored_bridge(AUTHORED_BRIDGE_Z, _bridge_x(1.0))], [])
	_track.rebuild(w, false)
	await wait_process_frames(2)
	assert_eq(_rails_on(AUTHORED_BRIDGE_Z - 1.0, 1.0), 1, "ряд перед містком з поручнями")
	assert_eq(_rails_on(AUTHORED_BRIDGE_Z + 1.0, 1.0), 1, "ряд за містком з поручнями")


## Авторський декор, який НЕ місток, стрічку не рве.
func test_other_authored_decor_leaves_the_rail_alone() -> void:
	var w := _meadow_without_procedural_bridges()
	_track.rebuild(w, false)
	await wait_process_frames(2)
	var rec := _authored_bridge(AUTHORED_BRIDGE_Z, _bridge_x(1.0))
	rec["kind"] = "signpost"
	_track.set_authored_timeline([rec], [])
	_track.rebuild(w, false)
	await wait_process_frames(2)
	assert_eq(_rails_on(AUTHORED_BRIDGE_Z, 1.0), 1, "не місток — не розрив")
