## Другий рівень висоти (GDD v1.3 §6): пандус угору → піднята платформа з перилами → пандус униз.
## Дитина Spawner3D: їде зі світом. Початок координат — ДАЛЬНІЙ кінець (найменший z), щоб KILL_Z спрацьовував,
## коли весь сегмент уже позаду. Локальний z: [0, RAMP] — пандус униз, [RAMP, RAMP+length] — платформа,
## [RAMP+length, total] — пандус угору (герой дістається його першим).
class_name Tier2Segment
extends Node3D

const H := 1.2
const RAMP := 2.0
const PLATFORM_COLOR := Palette.TIER2_PLATFORM
const EDGE_COLOR := Palette.TIER2_EDGE
const RAIL_COLOR := Palette.TIER2_RAIL

var lanes_used: Array = []
var length := 12.0
## Авто-стрибок на пандусі вже зроблено.
var boosted := false


func total_length() -> float:
	return length + 2.0 * RAMP


func setup(lanes_arr: Array, len_cells: float) -> void:
	lanes_used = lanes_arr.duplicate()
	length = clampf(len_cells, 10.0, 16.0)
	if lanes_used.is_empty():
		lanes_used = [0]
	var cx := 0.0
	for l in lanes_used:
		cx += float(l) * Hero3D.LANE_W
	cx /= float(lanes_used.size())
	var width := float(lanes_used.size()) * Hero3D.LANE_W - 0.1
	var total := total_length()
	# платформа
	var plat := Mats.box(Vector3(width, 0.25, length), PLATFORM_COLOR)
	plat.position = Vector3(cx, H - 0.125, RAMP + length * 0.5)
	add_child(plat)
	# перила по краях
	for side in [-1.0, 1.0]:
		var rail := Mats.box(Vector3(0.07, 0.06, length), RAIL_COLOR)
		rail.position = Vector3(cx + side * (width * 0.5 - 0.04), H + 0.32, RAMP + length * 0.5)
		add_child(rail)
		var n_posts := int(length / 2.0) + 1
		for i in range(n_posts):
			var post := Mats.box(Vector3(0.07, 0.34, 0.07), EDGE_COLOR)
			post.position = Vector3(cx + side * (width * 0.5 - 0.04), H + 0.17, RAMP + float(i) * 2.0)
			add_child(post)
	# опори під платформою
	var n_sup := int(length / 3.0) + 1
	for i in range(n_sup):
		var sup := Mats.box(Vector3(0.18, H - 0.25, 0.18), EDGE_COLOR)
		sup.position = Vector3(cx, (H - 0.25) * 0.5, RAMP + 0.5 + float(i) * 3.0)
		add_child(sup)
	# пандуси: похилі дошки
	var hyp := sqrt(RAMP * RAMP + H * H)
	var ang := atan(H / RAMP)
	var down := Mats.box(Vector3(width, 0.16, hyp), PLATFORM_COLOR)
	down.position = Vector3(cx, H * 0.5, RAMP * 0.5)
	down.rotation.x = -ang    # дальній кінець нижче
	add_child(down)
	var up := Mats.box(Vector3(width, 0.16, hyp), PLATFORM_COLOR)
	up.position = Vector3(cx, H * 0.5, total - RAMP * 0.5)
	up.rotation.x = ang       # ближній кінець нижче
	add_child(up)
	# смугастий «стоп-кадр» на початку пандуса, щоб дитина бачила вхід
	var mark := Mats.box(Vector3(width, 0.03, 0.3), RAIL_COLOR)
	mark.position = Vector3(cx, 0.02, total - 0.15)
	add_child(mark)


## Чи доріжка героя належить платформі.
func has_lane(lane: int) -> bool:
	return lanes_used.has(lane)


## Локальний z героя (герой у світовому z = 0).
func hero_local_z() -> float:
	return -position.z


## Висота поверхні під героєм (0 — поза сегментом або не в його доріжці).
func surface_height(lane: int) -> float:
	if not has_lane(lane):
		return 0.0
	var zl := hero_local_z()
	var total := total_length()
	if zl < 0.0 or zl > total:
		return 0.0
	if zl < RAMP:
		return H * zl / RAMP                   # пандус униз (дальній)
	if zl > total - RAMP:
		return H * (total - zl) / RAMP         # пандус угору (ближній)
	return H


## Герой саме в’їжджає на пандус угору (перші 0,6 клітинки).
func at_ramp_up() -> bool:
	var zl := hero_local_z()
	var total := total_length()
	return zl > total - RAMP and zl <= total and zl > total - 0.6


## Світовий z, з якого починається платформа (для розкладки зірочок).
func platform_z0() -> float:
	return position.z + RAMP
