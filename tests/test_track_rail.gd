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


## Ланки поручнів стикуються ВПРИТУЛ: один ряд = 1,0 м, і модель має бути такою ж. Якщо
## ланка бодай на частку міліметра ширша, сусідні заходять одна в одну, їхні бічні грані
## стають співплощинними — і на КОЖНОМУ стику, тобто рівно щометра вздовж берега, з'являється
## z-fight: у русі це читається як миготіння кольору на поручнях. Саме так і було до
## 17.09.2026: fence_rail_2 мав 1.0009 м, fence_rail_3 — 1.0002 м (заміряно по AABB у .glb),
## і це видно на знімках гравця регулярним кроком уздовж берега. Лікується scale у props.json.
func test_every_rail_link_is_exactly_one_metre_after_tweaks() -> void:
	var n := PropLibrary.variants("fence_rail")
	assert_gt(n, 0, "поручні взагалі є в props.json")
	for v in range(n):
		var mesh := PropLibrary.mesh("fence_rail", v)
		assert_not_null(mesh, "варіант %d має меш" % v)
		if mesh == null:
			continue
		var tw := PropLibrary.tweak("fence_rail", v)
		# Ланку ставлять поперек ряду (поворот на 90°), тож уздовж траси лягає X моделі.
		var along := mesh.get_aabb().size.x * float(tw["scale"])
		assert_almost_eq(along, 1.0, 0.0002,
			"ланка %d завширшки рівно з ряд — інакше стики z-fight'ять щометра" % v)
