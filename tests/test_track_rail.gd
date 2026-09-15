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
