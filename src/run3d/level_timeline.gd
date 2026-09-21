## Чиста екстракція авторського рівня (Phase 1 «level-authoring plumbing»): проходить по дереву
## сцени res://levels/level_XX.tscn (уже інстанційованої кимось іншим — цей модуль ресурсів
## не завантажує й автолодів не чіпає, тож юніт-тест збирає дерево вручну без .tscn узагалі),
## збирає всі LevelMarker3D і повертає їх дані як прості Dictionary, по одному масиву на роль.
##
## Знак z_m: маркер стоїть у сцені вздовж -Z — той самий напрямок, що й «попереду героя»
## в рушії (SPAWN_Z := -34.0 у Spawner3D означає «за 34 м попереду»). Авторська сцена — це,
## по суті, знімок усього рівня в момент, коли Track.distance_m/Spawner3D.distance_m ще 0:
## тоді z-координата в живій грі об'єкта з абсолютною відстанню z_m дорівнює саме -z_m
## (Track._decorate(): _row_distance_m[i] = distance_m - row.position.z; Spawner3D._advance_authored():
## спавн при distance_m == z_m - abs(SPAWN_Z), тобто position.z на той момент = 0). Тому тут —
## z_m = -position.z, без додаткових зсувів/масштабів.
class_name LevelTimeline
extends RefCounted

## role маркера → ключ результату (множина; wall_near → walls_near).
const ROLE_KEYS := {
	"decor": "decor",
	"obstacle": "obstacles",
	"pickup": "pickups",
	"gold": "gold",
	"building": "buildings",
	"landmark": "landmarks",
	"wall_near": "walls_near",
}


## layout_root — корінь інстанційованої авторської сцени (наприклад LevelLayout). Повертає
## {"decor":[...], "obstacles":[...], "pickups":[...], "buildings":[...], "landmarks":[...], "walls_near":[...]},
## кожен масив відсортований за зростанням z_m.
## Долити записи в уже впорядкований за z_m список — спільне для Track і Spawner3D.
##
## Чому не просто sort_custom на все разом. Цеглинки приходять по порядку, тож майже завжди
## новий шматок цілком лежить ПРАВОРУЧ від старого, а самі маркери в цеглинці здебільшого
## теж по порядку. sort_custom із лямбдою — це виклик GDScript на КОЖНЕ порівняння: на межі
## чанка (779 нових записів поверх кількох сотень старих) чотири такі сортування разом із
## рештою збирання давали 24 мс в одному кадрі — видиме заїкання рівно на межі цеглинки,
## і те саме на телефоні втричі довше. Тепер сортуємо лише коли справді треба.
static func merge_by_z(old_recs: Array, add: Array) -> Array:
	if add.is_empty():
		return old_recs
	if not sorted_by_z(add):
		add = add.duplicate()
		add.sort_custom(_by_z)
	if old_recs.is_empty():
		return add
	# Найдешевший випадок: новий шматок цілком праворуч від старого — просто дописати.
	if float((old_recs[-1] as Dictionary).get("z_m", 0.0)) \
			<= float((add[0] as Dictionary).get("z_m", 0.0)):
		old_recs.append_array(add)
		return old_recs
	# Шматки ЧЕРГУЮТЬСЯ. Це не рідкість і не вада даних: цеглинка — це ДВІ сцени на одному
	# зсуві (геометрія та розкладка перешкод), і друга починається з нуля там, де перша вже
	# дійшла до півтораста метрів. Заміряно 21.09.2026: стик не сходився ЖОДНОГО разу, тобто
	# тут щоразу йшло повне sort_custom на 1600 записів — 7,1 мс, найдорожчий крок усього
	# збирання цеглинки.
	#
	# Обидві половини вже впорядковані, тож сортувати нема чого: досить пройти їх пліч-о-пліч.
	# Це O(n+m) порівнянь float замість O(n log n) ВИКЛИКІВ GDScript-лямбди — саме виклики й
	# коштували, а не порівняння.
	if not sorted_by_z(old_recs):
		old_recs.append_array(add)      # інваріант порушено кимось іншим — чесно пересортувати
		old_recs.sort_custom(_by_z)
		return old_recs
	var out: Array = []
	out.resize(old_recs.size() + add.size())
	var i := 0
	var j := 0
	var k := 0
	while i < old_recs.size() and j < add.size():
		if float((old_recs[i] as Dictionary).get("z_m", 0.0)) \
				<= float((add[j] as Dictionary).get("z_m", 0.0)):
			out[k] = old_recs[i]
			i += 1
		else:
			out[k] = add[j]
			j += 1
		k += 1
	while i < old_recs.size():
		out[k] = old_recs[i]
		i += 1
		k += 1
	while j < add.size():
		out[k] = add[j]
		j += 1
		k += 1
	return out


## Чи лежать записи за неспадним z_m. Один прохід порівнянь float проти тисяч викликів лямбди.
static func sorted_by_z(recs: Array) -> bool:
	var prev := -INF
	for r in recs:
		var z := float((r as Dictionary).get("z_m", 0.0))
		if z < prev:
			return false
		prev = z
	return true


static func _by_z(a, b) -> bool:
	return float(a.get("z_m", 0.0)) < float(b.get("z_m", 0.0))


## Розбір цеглинки за один раз. Лишається для всіх, кому ніколи чекати кадрів: старт рівня
## (екран завантаження й так стоїть), плаский рівень, тести та інструменти. У БІГУ ж цим
## ходить LevelChunkLoader покроково — begin_out/markers/append_marker/finish, — бо ті самі
## 2,6 мс розбору разом із рештою збирання давали видимий смик на межі цеглинки.
static func extract(layout_root: Node, offset_m: float = 0.0) -> Dictionary:
	var out := begin_out()
	for m in markers(layout_root):
		append_marker(m as LevelMarker3D, out)
	finish(out, offset_m)
	return out


## Порожній розбір: по масиву на кожну роль. Окремо, щоб покроковий розбір мав куди складати
## з першого ж кроку.
static func begin_out() -> Dictionary:
	var out: Dictionary = {}
	for key in ROLE_KEYS.values():
		out[key] = []
	return out


## УСІ маркери піддерева одним плоским списком. Потрібно, щоб розбір можна було різати на
## шматки: рекурсію посеред кадру не спинити, а прохід по готовому списку — скільки завгодно.
## Сам обхід дешевий (вузли вже в пам'яті), тож його не ріжемо.
static func markers(layout_root: Node) -> Array:
	var out: Array = []
	if layout_root != null:
		_flatten_markers(layout_root, out)
	return out


static func _flatten_markers(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is LevelMarker3D:
			out.append(child)
		_flatten_markers(child, out)


## Додати один маркер до розбору. Зсув тут НЕ застосовується — його накладає finish(), один
## раз на всі записи, бо інакше довелось би тягнути його через кожен крок.
static func append_marker(marker: LevelMarker3D, out: Dictionary) -> void:
	_append(marker, out)


## Завершити розбір: накласти зсув цеглинки й упорядкувати кожну роль за z_m.
##
## Маркери чанка лежать у ЛОКАЛЬНИХ метрах — від початку самого чанка. Зсув передає той,
## ХТО СТАВИТЬ чанк, а не сам чанк: цеглинку треба вміти поставити на 150-му метрі одного
## рівня й на 900-му іншого. Раніше зсув лежав у самій сцені (LevelLayout.z_offset_m) і саме
## це прив'язувало чанк до одного місця в одному рівні.
static func finish(out: Dictionary, offset_m: float) -> void:
	if not is_zero_approx(offset_m):
		for key in out.keys():
			for rec in (out[key] as Array):
				rec["z_m"] = float(rec["z_m"]) + offset_m
	for key in out.keys():
		var recs: Array = out[key]
		if not sorted_by_z(recs):
			recs.sort_custom(_by_z)


## Рекурсивний обхід — навмисно не find_children(): так певно працює для будь-якого способу
## реєстрації класу (тест будує дерево з чистих LevelMarker3D.new(), без .tscn і без ресурсів).
static func _collect(node: Node, out: Dictionary) -> void:
	for child in node.get_children():
		if child is LevelMarker3D:
			_append(child as LevelMarker3D, out)
		_collect(child, out)


static func _append(marker: LevelMarker3D, out: Dictionary) -> void:
	var key: String = ROLE_KEYS.get(marker.role, "decor")
	var pos: Vector3 = marker.position
	(out[key] as Array).append({
		"z_m": -pos.z,
		"x_m": pos.x,
		"y_m": pos.y,
		"kind": marker.kind,
		# Дія поруч із видом, а не замість нього: порожній kind + заданий action означає
		# «вид добере світ» (Spawner3D._kind_for_action). Обидва порожні — запис як був.
		"action": marker.action,
		# Вісь РУХУ поруч із дією: «тут треба обійти» і «воно котиться на тебе» — різні речі,
		# і фраза має вміти попросити саме друге.
		"motion": marker.motion,
		"lane": marker.lane,
		"override": marker.override,
		"yaw_deg": marker.yaw_deg,
		"scale": marker.scale_mul,
	})
