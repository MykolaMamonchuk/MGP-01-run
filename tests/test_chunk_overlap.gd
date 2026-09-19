## Предмети не стоять один в одному.
##
## Скарга замовника дослівно: «щоб дерева не були в будинках, щоб тюки сіна не були один на
## одному». Причина була не в розкладці, а в тому, що предмети клали ДВА незалежні джерела:
## рукотворні маркери цеглинки й процедурний декоратор, який про них нічого не знав. Заміряно
## на заморожених цеглинках: 2627 накладок, майже всі виду «дерево в будинку» — mill +
## tree_round, house_terra + pine_3, house_small + tree_round.
##
## Полагоджено двома правками: заповнювач далекого плану тепер чекає, доки скінчиться
## попередня будівля (раніше чекали лише будівлі одна на одну), а заморожування відсіює
## оздоблення, що налазить на рукотворне. Стало 0.
##
## Правило тут — «ОДИН УСЕРЕДИНІ ІНШОГО», тобто центр одного предмета потрапив у слід другого.
## Саме це видно оком як ваду. Легкий дотик країв (квітка збоку від бочки) вадою не вважається
## і не перевіряється: у низькополігональній грі предмети й мусять стояти купками.
##
## Листя з листям не рахуємо взагалі: із цього складається лісова стіна, крони й кущі — вони
## МАЮТЬ перекриватися, інакше ліс читається як рідкий частокіл.
extends GutTest

## Види, яким налазити одне на одного дозволено. Усе інше — тверді речі.
const FOLIAGE := ["tree", "tree_round", "pine_3", "wall_tree_tall", "bush", "bush_cube",
	"bush_flower", "flower", "flower_pink", "flower_yellow", "mushroom", "mushroom_red",
	"mossrock", "rock", "rock_grey", "canopy_leaves", "garden", "branch"]
## Наскільки далеко по трасі має сенс шукати сусіда: найбільший предмет гри — стіна дерев
## 2,1 м завглибшки, плюс запас.
const NEAR_M := 4.0


func _sizes() -> Dictionary:
	var out := {}
	var f := FileAccess.open("res://data/props.json", FileAccess.READ)
	var props: Dictionary = JSON.parse_string(f.get_as_text())
	for kind in props.keys():
		if String(kind).begins_with("_"):
			continue
		var n := maxi(1, PropLibrary.variants(String(kind)))
		var big := Vector3.ZERO
		for v in n:
			var mesh := PropLibrary.mesh(String(kind), v)
			if mesh == null:
				continue
			var s := mesh.get_aabb().size
			if s.x * s.z > big.x * big.z:
				big = s
		if big != Vector3.ZERO:
			out[String(kind)] = big
	return out


## Маркери сцени, що займають місце обабіч дороги. Перешкоди й пікапи не рахуємо: вони живуть
## у смугах, туди оздоблення не кладеться, і їхнє місце задає `lane`, а не `x`.
func _markers(path: String, sizes: Dictionary) -> Array:
	var out := []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	for block in f.get_as_text().split("[node "):
		if not block.contains("script = ExtResource"):
			continue
		var role := "decor"
		var role_at := block.find("role = \"")
		if role_at >= 0:
			role = block.substr(role_at + 8).split("\"")[0]
		if role == "obstacle" or role == "pickup":
			continue
		var kind_at := block.find("kind = \"")
		if kind_at < 0:
			continue
		var kind := block.substr(kind_at + 8).split("\"")[0]
		if not sizes.has(kind):
			continue                      # вид без моделі — місця не займає
		var tr := block.find("Transform3D(")
		if tr < 0:
			continue
		var args := block.substr(tr + 12).split(")")[0].split(",")
		if args.size() < 12:
			continue
		var scale := 1.0
		var s_at := block.find("scale_mul = ")
		if s_at >= 0:
			scale = float(block.substr(s_at + 12).split("\n")[0])
		var yaw := 0.0
		var y_at := block.find("yaw_deg = ")
		if y_at >= 0:
			yaw = float(block.substr(y_at + 10).split("\n")[0])
		var size: Vector3 = sizes[kind]
		# Поворот на 90° міняє ширину з глибиною місцями. Без цього тераса будинків,
		# повернутих фасадом до води, читалася б як суцільна накладка.
		var turned := roundi(absf(yaw) / 90.0) % 2 == 1
		out.append({
			"kind": kind,
			"x": float(args[9]), "y": float(args[10]), "z": -float(args[11]),
			"w": (size.z if turned else size.x) * scale,
			"d": (size.x if turned else size.z) * scale,
			"h": size.y * scale,
		})
	return out


func _foliage(a: String, b: String) -> bool:
	return FOLIAGE.has(a) and FOLIAGE.has(b)


## Чи центр b потрапив усередину сліду a — і чи вони взагалі на одній висоті.
func _inside(a: Dictionary, b: Dictionary) -> bool:
	if absf(float(b["x"]) - float(a["x"])) >= float(a["w"]) * 0.5:
		return false
	if absf(float(b["z"]) - float(a["z"])) >= float(a["d"]) * 0.5:
		return false
	return not (float(a["y"]) > float(b["y"]) + float(b["h"])
		or float(b["y"]) > float(a["y"]) + float(a["h"]))


func test_nothing_stands_inside_anything_else() -> void:
	var sizes := _sizes()
	assert_gt(sizes.size(), 0, "габарити моделей знайшлись")
	var library := ChunkLibrary.scan()
	assert_gt(library.size(), 0, "бібліотека цеглинок не порожня")
	var bad := []
	var checked := 0
	for id in library.keys():
		var entry: Dictionary = library[id]
		for w in ((entry["desc"] as Dictionary).get("worlds", []) as Array):
			var all := _markers("%s/chunk.tscn" % String(entry["dir"]), sizes)
			all.append_array(_markers("%s/dress_%s.tscn" % [String(entry["dir"]), String(w)], sizes))
			all.sort_custom(func(p, q): return float(p["z"]) < float(q["z"]))
			for i in all.size():
				var a: Dictionary = all[i]
				for j in range(i + 1, all.size()):
					var b: Dictionary = all[j]
					if float(b["z"]) - float(a["z"]) > NEAR_M:
						break
					if _foliage(String(a["kind"]), String(b["kind"])):
						continue
					checked += 1
					if _inside(a, b) or _inside(b, a):
						bad.append("%s/%s: %s і %s на z=%.0f, x=%.1f"
							% [id, w, a["kind"], b["kind"], a["z"], a["x"]])
	assert_gt(checked, 0, "пари для перевірки знайшлись — інакше сторож стереже порожнечу")
	assert_eq(bad.size(), 0,
		"предмети стоять один в одному (%d): %s" % [bad.size(), bad.slice(0, 6)])


## Ніщо не висить у повітрі. Виняток один і названий: НАВІС Лісу — листя крони на 4,6 м, під
## яким дитина пробігає. Місток лежить на 0,02 м, тобто на землі, і це теж перевіряється тут:
## саме «місток у повітрі» замовник називав серед вад.
const OVERHEAD := ["canopy_leaves"]
const GROUND_EPS := 0.06


func test_nothing_hangs_in_the_air() -> void:
	var sizes := _sizes()
	var hanging := []
	var checked := 0
	for id in ChunkLibrary.scan().keys():
		var entry: Dictionary = ChunkLibrary.scan()[id]
		for w in ((entry["desc"] as Dictionary).get("worlds", []) as Array):
			var all := _markers("%s/chunk.tscn" % String(entry["dir"]), sizes)
			all.append_array(_markers("%s/dress_%s.tscn" % [String(entry["dir"]), String(w)], sizes))
			for m in all:
				checked += 1
				if OVERHEAD.has(String(m["kind"])):
					continue
				# Нижче нуля теж буває законно: каміння в каналі навмисно занурене.
				if float(m["y"]) > GROUND_EPS:
					hanging.append("%s/%s: %s на висоті %.2f м"
						% [id, w, m["kind"], m["y"]])
	assert_gt(checked, 0, "маркери знайшлись")
	assert_eq(hanging.size(), 0,
		"предмети висять у повітрі (%d): %s" % [hanging.size(), hanging.slice(0, 6)])
