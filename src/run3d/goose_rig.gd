## Скелетна гуска: процедурна анімація для перешкоди-тварини.
##
## Нові гуски (docs/refs/incoming/goose, почищені копії в assets/props/_exp/goose) мають
## автоматичний риг UniRig: 46-55 кісток з іменами Bone_000…Bone_055 і БЕЗ жодної
## анімації. Імена нічого не кажуть і в трьох моделях різні, тож кістки розкладаються
## за ГЕОМЕТРІЄЮ спокою, як у HeroRig: найвища — голова, її предки вище середини — шия,
## ланцюги, що з грудей розходяться вбік, — крила, що з таза йдуть униз, — лапи, що
## тягнуться назад, — хвіст.
##
## Стани (`state`): stand — стоїть і озирається; walk — перевальцем іде; bite — замах і
## кидок шиєю вперед; hiss — розправила крила, шия низько, шипить; fly — махає крилами,
## лапи підібгані, тіло піднімається.
##
## Усі оберти задаються в осях МОДЕЛІ (вгору, вперед до дзьоба, вбік) і перекладаються в
## локальні осі кістки. Знак оберту не вгадується, а рахується: кістку крутимо в той бік,
## куди має піти її кінчик (див. _toward). Так та сама поза працює на кожній із трьох
## моделей, хоч їхні кістки лежать по-різному.
class_name GooseRig
extends RefCounted

const STATES := ["stand", "walk", "bite", "hiss", "fly"]

var skel: Skeleton3D
var state := "stand"

## Ролі кісток: індекси.
var head := -1
var neck: Array[int] = []
var wings: Array[int] = []   # КОРЕНІ крил
var legs: Array[int] = []    # КОРЕНІ лап
var tail := -1
var root := -1

## Осі моделі в просторі скелета.
var up := Vector3.UP
var fwd := Vector3.BACK
var height := 1.0

var _rest_global: Array[Transform3D] = []
var _end_cache: Dictionary = {}
var _rest_root_pos := Vector3.ZERO


## Знайти скелет у екземплярі моделі й розкласти кістки. false — скелета нема.
func build(model: Node) -> bool:
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return false
	skel = found[0] as Skeleton3D
	var n := skel.get_bone_count()
	_rest_global.clear()
	_end_cache.clear()
	for i in range(n):
		_rest_global.append(skel.get_bone_global_rest(i))
	# Повторний build() (інша модель чи та сама вдруге) не має дописувати ролі до старих.
	head = -1
	neck.clear()
	wings.clear()
	legs.clear()
	tail = -1
	root = -1
	_classify()
	return head >= 0


func _pos(i: int) -> Vector3:
	return _rest_global[i].origin


## Кінчик кістки — середнє її дітей, а в листка — продовження від батька.
func _tip(i: int) -> Vector3:
	var kids := skel.get_bone_children(i)
	if kids.is_empty():
		var p := skel.get_bone_parent(i)
		return _pos(i) + (_pos(i) - _pos(p)) if p >= 0 else _pos(i)
	var s := Vector3.ZERO
	for k in kids:
		s += _pos(k)
	return s / float(kids.size())


func _classify() -> void:
	var n := skel.get_bone_count()
	var lo := INF
	var hi := -INF
	for i in range(n):
		hi = maxf(hi, _pos(i).y)
		lo = minf(lo, _pos(i).y)
		if head < 0 or _pos(i).y > _pos(head).y:
			head = i
	height = maxf(hi - lo, 0.001)
	# Найвища кістка — не завжди голова: у двох моделях це чубчик. Спускаємось від неї, поки
	# предок ще вище 85% найвищої точки, — останній такий і є голова (у неї сидять дзьоб,
	# очі й чубчик).
	var top := _pos(head).y - lo
	while skel.get_bone_parent(head) >= 0 and _pos(skel.get_bone_parent(head)).y - lo > 0.85 * top:
		head = skel.get_bone_parent(head)
	for i in range(n):
		if skel.get_bone_parent(i) < 0:
			root = i
	_rest_root_pos = skel.get_bone_rest(root).origin
	# Вперед — від таза до голови в горизонталі. glTF з Blender дає дзьоб у +Z, але не
	# покладаємось: модель могли розвернути.
	var d := _pos(head) - _pos(root)
	d.y = 0.0
	fwd = Vector3(0, 0, signf(d.z) if absf(d.z) > absf(d.x) else 0.0)
	if fwd == Vector3.ZERO:
		fwd = Vector3(signf(d.x), 0, 0)
	# Шия: предки голови, поки вони вище середини тіла. Корінь шиї — останній такий.
	var b := skel.get_bone_parent(head)
	while b >= 0 and _pos(b).y - lo > 0.55 * height:
		neck.push_front(b)
		b = skel.get_bone_parent(b)
	var side := up.cross(fwd).normalized()
	for i in range(n):
		var p := skel.get_bone_parent(i)
		if p < 0 or i == head or neck.has(i):
			continue
		var pp := _pos(p)
		var ip := _pos(i)
		var tp := _tip(i)
		var par_center := absf(pp.dot(side)) < 0.08 * height
		# Крило: від центру грудей (вище 40% зросту) кістка йде далеко вбік і не опускається
		# до землі. Корінь крила може вже стояти збоку (гуски 2 і 3) — важить батько.
		if par_center and pp.y - lo > 0.4 * height and absf(tp.dot(side)) > 0.12 * height \
				and tp.y - lo > 0.3 * height and not _has_ancestor_in(i, neck):
			wings.append(i)
		# Лапа: від центру таза кістка вже збоку й іде вниз.
		elif par_center and absf(ip.dot(side)) > 0.06 * height and ip.y - lo < 0.5 * height \
				and tp.y < ip.y - 0.05 * height and not _has_ancestor_in(i, legs):
			legs.append(i)
	# Лишити лише КОРЕНІ: дочірня кістка крила теж може сидіти поруч із центром.
	wings = wings.filter(func(i): return not _has_ancestor_in(i, wings))
	legs = legs.filter(func(i): return not _has_ancestor_in(i, legs))
	# Хвіст: найдальша назад кістка, чий батько не позаду (тобто корінь хвостового ланцюга).
	var back := INF
	var tail_tip := -1
	for i in range(n):
		var z := _pos(i).dot(fwd)
		if z < back and not _in_chains(i):
			back = z
			tail_tip = i
	b = tail_tip
	while b >= 0 and skel.get_bone_parent(b) >= 0 \
			and _pos(skel.get_bone_parent(b)).dot(fwd) < _pos(root).dot(fwd) - 0.05 * height:
		b = skel.get_bone_parent(b)
	# Хвіст, що збігся з коренем, анімувати не можна: фінальний оберт тіла його затирає.
	tail = b if b != root else -1


func _has_ancestor_in(i: int, arr: Array[int]) -> bool:
	var p := skel.get_bone_parent(i)
	while p >= 0:
		if arr.has(p):
			return true
		p = skel.get_bone_parent(p)
	return false


func _in_chains(i: int) -> bool:
	return wings.has(i) or legs.has(i) or _has_ancestor_in(i, wings) \
		or _has_ancestor_in(i, legs)


## Оберт кістки на `angle` навколо осі МОДЕЛІ. Поза множиться справа від спокою, а вісь
## перекладається в локальні координати кістки — тоді в просторі скелета це чистий оберт
## навколо модельної осі в голові кістки. Кілька осей — одним викликом, бо поза щоразу
## рахується від спокою.
func _rot(i: int, turns: Array) -> void:
	if i < 0:
		return
	var inv := _rest_global[i].basis.orthonormalized().inverse()
	var q := skel.get_bone_rest(i).basis.get_rotation_quaternion()
	for t in turns:
		var ax: Vector3 = t[0]
		var ang: float = t[1]
		if absf(ang) > 0.0005:
			q = q * Quaternion((inv * ax).normalized(), ang)
	skel.set_bone_pose_rotation(i, q)


## Знак, з яким треба крутити кістку навколо `axis`, щоб КІНЕЦЬ ЇЇ ЛАНЦЮГА пішов у бік
## `target`. Саме ланцюга, а не самої кістки: у гуски 3 перша кістка крила дивиться вперед,
## а все крило тягнеться назад, і знак за першою кісткою заводив крило всередину тулуба.
func _toward(i: int, axis: Vector3, target: Vector3) -> float:
	if i < 0:
		return 1.0
	var v := _chain_end(i) - _pos(i)
	var s := signf(axis.cross(v).dot(target))
	return s if s != 0.0 else 1.0


## Найдальша від кістки точка серед її нащадків — кінець ланцюга (кінчик крила, пальці лапи).
func _chain_end(i: int) -> Vector3:
	if _end_cache.has(i):
		return _end_cache[i] as Vector3
	var best := _tip(i)
	var stack: Array[int] = [i]
	while not stack.is_empty():
		var b: int = stack.pop_back()
		var t := _tip(b)
		if t.distance_to(_pos(i)) > best.distance_to(_pos(i)):
			best = t
		for k in skel.get_bone_children(b):
			stack.append(k)
	_end_cache[i] = best
	return best


func _side_of(i: int) -> Vector3:
	var side := up.cross(fwd).normalized()
	return side * signf((_chain_end(i) - _pos(i)).dot(side))


## Один кадр. `t` — час у секундах; повертає зсув усієї моделі вгору (для польоту), м.
func pose(t: float) -> float:
	skel.reset_bone_poses()
	var side := up.cross(fwd).normalized()
	var lift := 0.0
	var body_roll := 0.0
	var body_pitch := 0.0
	match state:
		"stand":
			# Озирається: голова повільно вліво-вправо, шия ледь хитається.
			var look := sin(t * 0.9) * 0.5 * smoothstep(0.2, 0.8, absf(sin(t * 0.45)))
			for k in range(neck.size()):
				_rot(neck[k], [[up, look / float(neck.size())],
					[side, sin(t * 2.2) * 0.03 * _toward(neck[k], side, fwd)]])
			_rot(tail, [[up, sin(t * 3.0) * 0.12]])
		"walk":
			var ph := t * 6.0
			body_roll = sin(ph) * 0.14
			lift = absf(sin(ph)) * 0.03 * height
			for l in legs:
				var s := signf((_pos(l)).dot(side))
				_rot(l, [[side, sin(ph + (0.0 if s > 0 else PI)) * 0.7 * _toward(l, side, fwd)]])
			for k in neck:
				_rot(k, [[side, (0.1 + sin(ph * 2.0) * 0.08) * _toward(k, side, fwd)]])
			_rot(tail, [[up, sin(ph) * 0.25]])
		"bite":
			# Цикл 1,4 с: замах назад (0-0,5), кидок уперед і вниз (0,5-0,65), тримає, вертається.
			var c := fmod(t, 1.4) / 1.4
			var a := 0.0
			if c < 0.35:
				a = -0.25 * smoothstep(0.0, 0.35, c)
			elif c < 0.47:
				a = lerpf(-0.25, 0.75, smoothstep(0.35, 0.47, c))
			elif c < 0.7:
				a = 0.75
			else:
				a = lerpf(0.75, 0.0, smoothstep(0.7, 1.0, c))
			body_pitch = a * 0.25
			for k in neck:
				_rot(k, [[side, a / float(maxi(neck.size(), 1)) * 1.6 * _toward(k, side, fwd)]])
			_rot(head, [[side, -a * 0.4 * _toward(head, side, fwd)]])
			for w in wings:
				_rot(w, [[up, 0.25 * clampf(a, 0.0, 1.0) * _toward(w, up, _side_of(w))]])
		"hiss":
			# Крила розправлені й тремтять, шия низько й уперед, голова задерта.
			var shake := sin(t * 40.0) * 0.04
			for k in neck:
				_rot(k, [[side, (1.1 / float(maxi(neck.size(), 1)) + shake) * _toward(k, side, fwd)]])
			_rot(head, [[side, -0.5 * _toward(head, side, fwd)]])
			for w in wings:
				var out := _side_of(w)
				_rot(w, [[fwd, (0.5 + shake) * _toward(w, fwd, up)],
					[up, 1.0 * _toward(w, up, out)]])
			body_pitch = 0.18
			_rot(tail, [[side, 0.3 * _toward(tail, side, up)]])
		"fly":
			var flap := sin(t * 9.0)
			lift = 0.35 * height + sin(t * 9.0 - 1.0) * 0.04 * height
			for w in wings:
				var out := _side_of(w)
				_rot(w, [[fwd, (0.4 + flap * 0.7) * _toward(w, fwd, up)],
					[up, 1.35 * _toward(w, up, out)]])
			for l in legs:
				_rot(l, [[side, 1.0 * _toward(l, side, -fwd)]])
			for k in neck:
				_rot(k, [[side, 0.9 / float(maxi(neck.size(), 1)) * _toward(k, side, fwd)]])
			body_pitch = 0.35
	# Тіло: корінь нахиляється й хитається, а в польоті ще й піднімається.
	_rot(root, [[fwd, body_roll], [side, body_pitch * _toward(neck[0] if not neck.is_empty() else head, side, fwd)]])
	skel.set_bone_pose_position(root, _rest_root_pos)
	return lift
