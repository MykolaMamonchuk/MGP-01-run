## Пікап-помічник (GDD v1.3 §4): равлик, сердечко, магніт, щит, ракета, ×2. Дані — data/pickups.json.
## Дитина Spawner3D: їде зі світом, сяє (emission) і пульсує, іскри навколо; збір — як у зірочки.
class_name Pickup3D
extends Node3D

const PATH := "res://data/pickups.json"

static var _defs: Dictionary = {}
static var _loaded := false

var kind := ""
var def: Dictionary = {}
var collected := false

var _mesh: MeshInstance3D
var _t := randf() * TAU


## Увесь файл pickups.json (kinds, per_minute, snail_fast_boost). Кеш; {} якщо файлу нема.
static func load_all() -> Dictionary:
	if _loaded:
		return _defs
	_loaded = true
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return _defs
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_defs = parsed
	return _defs


## Опис виду (voxel, seconds, color…).
static func def_of(k: String) -> Dictionary:
	var kinds: Dictionary = load_all().get("kinds", {})
	return kinds.get(k, {})


## Чиста функція: зважений вибір виду за профілем. speed_ratio — швидкість / базова профілю (>1.5 — равлик частіший).
## exclude — види, які зараз не потрібні (сердечко при повних серцях). "" — нічого підходящого.
static func pick_kind(data: Dictionary, profile_name: String, speed_ratio: float, exclude: Array, rng: RandomNumberGenerator) -> String:
	var rates: Dictionary = (data.get("per_minute", {}) as Dictionary).get(profile_name, {})
	var boost := float(data.get("snail_fast_boost", 2.0))
	var pool := []
	var total := 0.0
	for k in rates.keys():
		if exclude.has(k):
			continue
		var w := float(rates[k])
		if k == "snail" and speed_ratio > 1.5:
			w *= boost
		if w <= 0.0:
			continue
		pool.append([k, w])
		total += w
	if pool.is_empty():
		return ""
	var r := rng.randf() * total
	for item in pool:
		r -= float(item[1])
		if r <= 0.0:
			return String(item[0])
	return String(pool[-1][0])


## Сумарна частота пікапів на хвилину для профілю (для інтервалу між спавнами).
static func per_minute_total(data: Dictionary, profile_name: String) -> float:
	var rates: Dictionary = (data.get("per_minute", {}) as Dictionary).get(profile_name, {})
	var total := 0.0
	for k in rates.keys():
		total += float(rates[k])
	return total


func setup(k: String) -> void:
	kind = k
	def = def_of(k)
	var color := Color(String(def.get("color", "#FFFFFF")))
	_mesh = VoxelBuilder.instance(String(def.get("voxel", k)))
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.5
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.1
	_mesh.material_override = m
	_mesh.position.y = 0.45
	add_child(_mesh)
	var sp := FX.sparkles(self, 0.45, 12)
	sp.position.y = 0.7
	# поява з пружиною
	scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Крутиться й пульсує; true — герой торкнувся (та сама зона, що й у зірочки).
func tick(delta: float, hero: Node3D) -> bool:
	_t += delta
	_mesh.rotation.y += delta * 2.2
	var p := 1.0 + sin(_t * 4.0) * 0.08
	_mesh.scale = Vector3(p, p, p)
	_mesh.position.y = 0.45 + sin(_t * 2.5) * 0.08
	var hero_pos := Vector3(hero.position.x, hero.position.y + 0.5, 0.0)
	var d := position.distance_to(hero_pos)
	return d < 0.7 and absf(position.x - hero_pos.x) < 0.6


func collect() -> void:
	collected = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 1.6, 0.12)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.15)
	tw.finished.connect(queue_free)
