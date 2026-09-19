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
	"building": "buildings",
	"landmark": "landmarks",
	"wall_near": "walls_near",
}


## layout_root — корінь інстанційованої авторської сцени (наприклад LevelLayout). Повертає
## {"decor":[...], "obstacles":[...], "pickups":[...], "buildings":[...], "landmarks":[...], "walls_near":[...]},
## кожен масив відсортований за зростанням z_m.
static func extract(layout_root: Node, offset_m: float = 0.0) -> Dictionary:
	var out: Dictionary = {}
	for key in ROLE_KEYS.values():
		out[key] = []
	if layout_root != null:
		# Маркери чанка лежать у ЛОКАЛЬНИХ метрах — від початку самого чанка. Зсув передає той,
		# ХТО СТАВИТЬ чанк, а не сам чанк: цеглинку треба вміти поставити на 150-му метрі
		# одного рівня й на 900-му іншого. Раніше зсув лежав у самій сцені (LevelLayout.
		# z_offset_m) і саме це прив'язувало чанк до одного місця в одному рівні.
		var offset := offset_m
		_collect(layout_root, out)
		if not is_zero_approx(offset):
			for key in out.keys():
				for rec in (out[key] as Array):
					rec["z_m"] = float(rec["z_m"]) + offset
	for key in out.keys():
		(out[key] as Array).sort_custom(func(a, b): return float(a.get("z_m", 0.0)) < float(b.get("z_m", 0.0)))
	return out


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
		"lane": marker.lane,
		"override": marker.override,
		"yaw_deg": marker.yaw_deg,
		"scale": marker.scale_mul,
	})
