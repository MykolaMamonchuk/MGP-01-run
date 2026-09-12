## Звірята-герої v1.5 (GDD §5): чисті функції Hero3D і дані heroes.json + вокселі частин.
extends GutTest

const PART_KEYS := ["body", "head", "leg", "tail", "ear"]
const HEX_RE := "^#[0-9A-Fa-f]{6}$"
## Ключі палітри, які Hero3D підміняє на всіх частинах.
const PALETTE_KEYS := ["o", "d", "c", "k", "i", "t", "m"]

var _heroes: Dictionary


func before_each() -> void:
	_heroes = HeroSelect.load_heroes()


func _animals() -> Array:
	var out := []
	for k in _heroes.keys():
		var key := String(k)
		if key.begins_with("_") or key == "growth":
			continue
		var def = _heroes[k]
		if typeof(def) == TYPE_DICTIONARY and not Hero3D.is_legacy(def):
			out.append(key)
	return out


func _voxel(name: String) -> Dictionary:
	return VoxelBuilder.load_def("res://data/voxels/%s.json" % name)


## Розмір одного вокселя частини, м. Він же — допуск: контракт із Hero3D заданий У МЕТРАХ,
## а не в кількості вокселів, тож частина має право «промахнутись» на один воксель
## (голова 0,45 м — це 6 вокселів по 0,075 або 11 по 0,04, обидва варіанти правильні).
func _size(name: String) -> float:
	var def := _voxel(name)
	return float(def.get("size", 0.1)) if not def.is_empty() else 0.1


## Габарит частини в метрах: Vector3(ширина, висота, глибина).
func _dims_m(name: String) -> Vector3:
	var def := _voxel(name)
	if def.is_empty():
		return Vector3.ZERO
	var d: Vector3i = VoxelBuilder.parse(def)["size"]
	return Vector3(d) * float(def.get("size", 0.1))


## Висота вокселя в метрах (кількість шарів × розмір вокселя).
func _height(name: String) -> float:
	return _dims_m(name).y


# ---------- чисті функції Hero3D ----------

func test_is_legacy() -> void:
	assert_true(Hero3D.is_legacy({"legacy": true}), "legacy: true — старий пухнастик")
	assert_false(Hero3D.is_legacy({}), "без поля — новий герой")
	assert_false(Hero3D.is_legacy({"legacy": false}))


func test_part_names_defaults_and_override() -> void:
	var d := Hero3D.part_names({})
	for k in PART_KEYS:
		assert_true(d.has(k), "без parts — усі п'ять частин за замовчуванням (%s)" % k)
	assert_eq(String(d["body"]), "hero_body")
	var mixed := Hero3D.part_names({"parts": {"tail": "hero_tail_cat", "ear": ""}})
	assert_eq(String(mixed["tail"]), "hero_tail_cat", "задана частина береться з даних")
	assert_eq(String(mixed["ear"]), String(Hero3D.DEFAULT_PARTS["ear"]), "порожня назва — дефолт")
	assert_eq(String(mixed["head"]), String(Hero3D.DEFAULT_PARTS["head"]))


func test_first_animal_id_skips_legacy() -> void:
	var all := {
		"_note": "x",
		"growth": {},
		"old": {"legacy": true, "order": 0},
		"b": {"order": 5},
		"a": {"order": 2},
	}
	assert_eq(Hero3D.first_animal_id(all), "a", "перший не-legacy за order")
	assert_eq(Hero3D.first_animal_id({"old": {"legacy": true, "order": 0}}), "", "самі legacy — порожньо")


func test_resolve_def_falls_back_from_legacy() -> void:
	var all := {
		"old": {"legacy": true, "order": 0, "color": "#FFFFFF"},
		"nu": {"order": 1, "color": "#F08A3C"},
	}
	assert_eq(String(Hero3D.resolve_def(all, "old").get("color", "")), "#F08A3C", "старе збереження → перший новий герой")
	assert_eq(String(Hero3D.resolve_def(all, "nu").get("color", "")), "#F08A3C")
	assert_true(Hero3D.resolve_def(all, "friend").is_empty(), "незнайомий id (друг) — частини за замовчуванням")


func test_real_data_resolves() -> void:
	var all := Hero3D.defs()
	assert_false(all.is_empty(), "data/heroes.json читається")
	assert_eq(Hero3D.first_animal_id(all), "lys", "перший герой каруселі — лисеня")
	var from_old := Hero3D.resolve_def(all, "puf")
	assert_false(Hero3D.is_legacy(from_old), "збереження з Пуфом не падає — показуємо звірятко")


# ---------- дані героїв ----------

func test_six_animals_in_carousel() -> void:
	var ids := HeroSelect.order_ids(_heroes)
	assert_eq(ids.size(), 9, "у каруселі дев'ять звірят (+ дельфін, черепаха)")
	assert_eq(String(ids[6]), "odn", "Єдиноріг — сьомий (order 6), далі дельфін і черепаха")
	assert_eq(String(ids[0]), "lys", "стартовий герой — лисеня")
	for legacy_id in ["puf", "vushko", "sonia"]:
		assert_false(ids.has(legacy_id), "%s — legacy, у каруселі його нема" % legacy_id)
		assert_true(_heroes.has(legacy_id), "%s лишився в даних заради збережень" % legacy_id)


func test_each_animal_has_all_parts_and_files() -> void:
	var re := RegEx.new()
	re.compile(HEX_RE)
	var ids := _animals()
	assert_eq(ids.size(), 9, "дев'ять не-legacy героїв")
	for id in ids:
		var def: Dictionary = _heroes[id]
		var parts = def.get("parts", {})
		assert_true(typeof(parts) == TYPE_DICTIONARY, "%s: є parts" % id)
		for k in PART_KEYS:
			var name := String((parts as Dictionary).get(k, ""))
			assert_ne(name, "", "%s: задана частина %s" % [id, k])
			assert_false(_voxel(name).is_empty(), "%s: воксель %s.json існує" % [id, name])
		assert_not_null(re.search(String(def.get("color", ""))), "%s: color — #RRGGBB" % id)
		assert_not_null(re.search(String(def.get("accent", ""))), "%s: accent — #RRGGBB" % id)
		assert_true(def.has("name_uk") and String(def["name_uk"]).length() > 0, "%s: є name_uk" % id)
		assert_true(def.has("stats"), "%s: є stats" % id)


## Зріст звірятка ≈ 1 м: лапка + тулуб + голова, як у константах Hero3D.
## Допуск — один воксель самої частини: контракт у метрах, а не в кількості вокселів,
## тож дрібна сітка згенерованих частин (0,04 м) така сама правильна, як ручні 0,075 м.
func test_assembled_height_fits_camera_and_hitbox() -> void:
	for id in _animals():
		var parts: Dictionary = _heroes[id]["parts"]
		var leg := String(parts["leg"])
		var head := String(parts["head"])
		var body := String(parts["body"])
		assert_almost_eq(_height(leg), Hero3D.LEG_H, _size(leg), "%s: лапка = LEG_H ± воксель" % id)
		var head_h := _height(head)
		assert_almost_eq(head_h, Hero3D.HEAD_H, _size(head), "%s: голова = HEAD_H ± воксель" % id)
		assert_almost_eq(Hero3D.TORSO_Y + _height(body), Hero3D.TORSO_TOP, _size(body),
			"%s: тулуб лежить на лапках" % id)
		# глибина голови: обличчя Hero3D (_build_face) сидить на FACE_Z = −HEAD_HALF_D − 0,01,
		# тож передня грань вокселя має бути саме на −HEAD_HALF_D, інакше очі потонуть у голові
		assert_almost_eq(_dims_m(head).z, Hero3D.HEAD_HALF_D * 2.0, _size(head),
			"%s: глибина голови = 2 × HEAD_HALF_D ± воксель" % id)
		var total := Hero3D.NECK_Y + head_h
		assert_almost_eq(total, Hero3D.HEAD_TOP, _size(head), "%s: маківка = HEAD_TOP ± воксель" % id)
		assert_lt(total, 1.05, "%s: зріст ≤ 1,05 м — камера й габарит зіткнення не змінились" % id)
		assert_between(head_h / total, 0.4, 0.5, "%s: голова ≈ 45 %% зросту" % id)


## Частини, згенеровані tools/voxelize.py (суфікс `_ai`), тримають контракт v2:
## хвіст завдовжки рівно TAIL_LEN (Hero3D зсуває меш на пів довжини), вухо не вище за 0,22 м.
func test_generated_parts_contract() -> void:
	var checked := 0
	for id in _animals():
		var parts: Dictionary = _heroes[id]["parts"]
		var tail := String(parts["tail"])
		if tail.ends_with("_ai"):
			assert_almost_eq(_dims_m(tail).z, Hero3D.TAIL_LEN, _size(tail),
				"%s: хвіст = TAIL_LEN ± воксель" % id)
			checked += 1
		var ear := String(parts["ear"])
		if ear.ends_with("_ai"):
			# стеля лише для згенерованих: ручне довге вухо зайчика (0,33 м) — навмисне
			assert_lt(_dims_m(ear).y, 0.23, "%s: згенероване вухо не вище за 0,22 м" % id)
			checked += 1
	assert_gt(checked, -1, "перевірка не падає, коли згенерованих частин ще нема")


## Габарит зіткнення лишився таким самим, як у пухнастика v1.4 (0,56 × 1,1 × 0,56) — спавнер не міняли.
func test_hit_box_unchanged() -> void:
	var h := autofree(Hero3D.new()) as Hero3D
	# hit_box() рахує з position/ground_y, вузол у дерево не додаємо — потрібні лише числа
	var box := h.hit_box()
	assert_almost_eq(box.size.x, 0.56, 0.001)
	assert_almost_eq(box.size.y, 1.1, 0.001)
	assert_almost_eq(box.size.z, 0.56, 0.001)


# ---------- вокселі частин ----------

func test_part_voxels_are_well_formed() -> void:
	var seen := {}
	for id in _animals():
		var parts: Dictionary = _heroes[id]["parts"]
		for k in PART_KEYS:
			seen[String(parts[k])] = true
	assert_gt(seen.size(), 5, "частин щонайменше кілька різних")
	for name in seen.keys():
		var def := _voxel(String(name))
		var palette: Dictionary = def.get("palette", {})
		assert_false(palette.is_empty(), "%s: є палітра-заготовка" % name)
		for key in palette.keys():
			assert_true(PALETTE_KEYS.has(String(key)), "%s: ключ '%s' Hero3D уміє підмінювати" % [name, key])
		var width := -1
		for layer in def.get("layers", []):
			for row in (layer as Array):
				var s := String(row)
				if width < 0:
					width = s.length()
				assert_eq(s.length(), width, "%s: усі рядки однакової довжини" % name)
				for i in range(s.length()):
					var ch := s[i]
					assert_true(ch == "." or palette.has(ch), "%s: символ '%s' є в палітрі" % [name, ch])
		# частини не мають бути завеликими: жодна не більша за голову
		var dims: Vector3i = VoxelBuilder.parse(def)["size"]
		var sz := float(def.get("size", 0.1))
		assert_lt(float(dims.x) * sz, 0.6, "%s: не ширше за габарит героя" % name)
		assert_lt(float(dims.y) * sz, 0.6, "%s: не вище за голову" % name)
