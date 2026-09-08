## Дім-діорама (GDD v1.4 §10, реф. §7 «Tom Gold Run»): дім = біом, який дитина пробігає.
## Ізометричний воксельний острівець світу: трав'яне плато на трьох шарах теракотової «цегли»,
## бірюзова вода довкола, піщана стежка попереду, сітка 3×3 ділянок під будиночки (data/buildings.json).
## Куплене стоїть на ділянках, наступна ділянка показує напівпрозорий привид будівлі з ціною в злитках —
## тап по ньому питає «Купити?» і будує (злитки списуються з SaveService.child()["stars"]).
## Збереження: SaveService.child()["buildings"][world_id] — масив імен вокселів у порядку ділянок;
## той самий масив Track додає у пул ближніх стін світу, тож добудоване видно і на дорозі.
##
## Контракт із Run3D (він володіє станом HOME):
##   open(world_id, lm) · close() · сигнали play_level(num) · world_selected(world_id) · closed()
## Вузол завжди у дереві (process_mode ALWAYS) і мовчить, доки не покличуть open().
##
## Припущення про сцену: діорама живе НАД трасою (ORIGIN), щоб дорога не лізла в кадр;
## камера — той самий CameraRig із сусіднього вузла ("CameraRig" у батька), пресет через rig.apply().
## Чисті функції (worlds_order / plot_positions / can_afford / next_building) — для тестів.
class_name Diorama
extends Node3D

signal play_level(num: int)
signal world_selected(world_id: String)
signal closed

const DATA_PATH := "res://data/buildings.json"
const WORLDS_DIR := "res://data/worlds"
## Світи в порядку мапи (те саме, що й у levels.json).
const WORLDS := ["meadow", "forest", "beach", "city", "clouds"]

## Ділянки: сітка 3×3, клітинка 1,4 м.
const PLOTS := 9
const GRID_COLS := 3
const CELL := 1.4
## Сітку зсунуто назад — попереду лишається піщана стежка з героєм.
const GRID_Z := -0.7
const HERO_Z := 2.5

## Плато: верхня трав'яна плита (тайлами) + три шари «цегли» під нею, нижні темніші й вужчі.
const TILES := 6
const TILE := 1.1
const TOP_H := 0.3
const CLIFF_LAYERS := 3
const CLIFF_STEP := 0.4
const WATER_Y := -1.75

## Діорама стоїть високо над трасою: та лишається в сцені й нам не потрібна в кадрі.
const ORIGIN := Vector3(0.0, 60.0, 0.0)
## Камера діорами (локально до острова): піднята «ізометрична» 3/4.
const CAM_POS := Vector3(0.0, 5.5, 7.0)
const CAM_LOOK := Vector3(0.0, 0.6, 0.0)
const CAM_FOV := 45.0
const CAM_MOVE_SEC := 0.7

static var _defs_cache: Dictionary = {}
static var _worlds_cache: Dictionary = {}

var _world_id := "meadow"
var _lm: LevelManager
var _ui: DioramaUI
var _island: Node3D
var _hero: Hero3D
var _magpie: Node3D
## Ділянки: [{"pos": Vector3, "node": Node3D, "ghost": bool, "def": Dictionary}].
var _plots: Array = []
var _ghost_node: Node3D
var _pending: Dictionary = {}
var _is_open := false
var _t := 0.0
var _tweens: Array[Tween] = []


# ---------- чисті функції (тести) ----------

## Світи в порядку появи.
static func worlds_order() -> Array:
	return WORLDS.duplicate()


## Центри ділянок сітки (рядками, зліва направо) — порядок = порядок купівлі.
static func plot_positions(n: int, cell: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in range(maxi(0, n)):
		var col := i % GRID_COLS
		var row := int(floor(float(i) / float(GRID_COLS)))
		out.append(Vector3((float(col) - 1.0) * cell, 0.0, (float(row) - 1.0) * cell))
	return out


static func can_afford(price: int, stars: int) -> bool:
	return stars >= price


## Наступна будівля світу: перша з каталогу (ціни зростають), якої ще нема на острові.
## Порожній словник — усе вже збудовано.
static func next_building(defs: Array, owned: Array) -> Dictionary:
	for d in defs:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var def: Dictionary = d
		if not owned.has(String(def.get("voxel", ""))):
			return def
	return {}


# ---------- дані ----------

static func load_defs() -> Dictionary:
	if not _defs_cache.is_empty():
		return _defs_cache
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var w = (parsed as Dictionary).get("worlds", {})
	if typeof(w) != TYPE_DICTIONARY:
		return {}
	_defs_cache = w
	return _defs_cache


static func defs_for(world_id: String) -> Array:
	var a = load_defs().get(world_id, [])
	return a if typeof(a) == TYPE_ARRAY else []


## Світи з data/worlds (кольори плато й декору). Свій кеш — щоб не залежати від Run3D.
static func load_worlds() -> Dictionary:
	if not _worlds_cache.is_empty():
		return _worlds_cache
	var dir := DirAccess.open(WORLDS_DIR)
	if dir == null:
		return {}
	for fname in dir.get_files():
		if not fname.ends_with(".json"):
			continue
		var f := FileAccess.open(WORLDS_DIR.path_join(fname), FileAccess.READ)
		if f == null:
			continue
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			_worlds_cache[String((parsed as Dictionary).get("id", fname.get_basename()))] = parsed
	return _worlds_cache


## Що вже збудовано у світі (масив імен вокселів у порядку ділянок).
static func owned_of(world_id: String) -> Array:
	var b = SaveService.child().get("buildings", {})
	if typeof(b) != TYPE_DICTIONARY:
		return []
	var mine = (b as Dictionary).get(world_id, [])
	if typeof(mine) != TYPE_ARRAY:
		return []
	var out := []
	for v in (mine as Array):
		if typeof(v) == TYPE_STRING:
			out.append(String(v))
	return out


# ---------- життя вузла ----------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = ORIGIN
	visible = false
	set_process(false)
	set_process_unhandled_input(false)


## Контракт із Run3D: показати дім світу world_id.
func open(world_id: String, lm: LevelManager) -> void:
	_lm = lm
	_world_id = world_id if WORLDS.has(world_id) else String(WORLDS[0])
	_ensure_ui()
	visible = true
	_is_open = true
	set_process(true)
	set_process_unhandled_input(true)
	_build_world()
	_apply_camera(CAM_MOVE_SEC)
	_ui.open()
	_refresh_ui()
	world_selected.emit(_world_id)
	if _hero != null:
		_hero.face_camera(true, 0.0)
		_hero.wave_hello()
	AudioMgr.voice("home")


## Контракт із Run3D: сховати (меші лишаються — наступне відкриття миттєве).
func close() -> void:
	_is_open = false
	set_process(false)
	set_process_unhandled_input(false)
	if _hero != null and is_instance_valid(_hero):
		_hero.set_process(false)   # герой діорами не тратить кадри, поки її не видно
	_pending = {}
	for t in _tweens:
		if t != null and t.is_valid():
			t.kill()
	_tweens.clear()
	if _ui != null:
		_ui.close()
	visible = false


func _ensure_ui() -> void:
	if _ui != null and is_instance_valid(_ui):
		return
	_ui = DioramaUI.new()
	add_child(_ui)
	_ui.back_pressed.connect(func(): closed.emit())
	_ui.go_pressed.connect(_on_go)
	_ui.level_pressed.connect(_on_level)
	_ui.world_arrow.connect(_on_arrow)
	_ui.buy_confirmed.connect(_on_buy_confirmed)
	_ui.buy_cancelled.connect(func(): _pending = {})


# ---------- камера ----------

func _rig() -> Node:
	var p := get_parent()
	return p.get_node_or_null("CameraRig") if p != null else null


func _camera() -> Camera3D:
	var rig := _rig()
	return rig.get_node_or_null("Camera3D") as Camera3D if rig != null else null


## CameraRig приймає пресет {pos, look, fov} у світових координатах — додаємо зміщення острова.
func _apply_camera(duration: float) -> void:
	var rig := _rig()
	if rig == null or not rig.has_method("apply"):
		return
	var pos := ORIGIN + CAM_POS
	var look := ORIGIN + CAM_LOOK
	rig.call("apply", {
		"pos": [pos.x, pos.y, pos.z],
		"look": [look.x, look.y, look.z],
		"fov": CAM_FOV,
		"ortho": false,
	}, duration)


# ---------- острів ----------

func _world_data() -> Dictionary:
	var w = load_worlds().get(_world_id, {})
	return w if typeof(w) == TYPE_DICTIONARY else {}


func _build_world() -> void:
	if _island != null and is_instance_valid(_island):
		_island.queue_free()
	_island = Node3D.new()
	_island.name = "Island"
	add_child(_island)
	var w := _world_data()
	_build_ground(w)
	_build_props(w)
	_build_plots()
	_build_magpie()
	_ensure_hero()


## Плато: вода → три шари «цегли» → трав'яні плитки з варіацією → піщана стежка.
func _build_ground(w: Dictionary) -> void:
	var tint := Palette.of(Seasons.current().get("ground_tint"), Palette.GROUND_TINT_NONE)
	var grass := Palette.of(w.get("ground"), Palette.WORLD_GROUND) * tint
	var grass_dark := Palette.of(w.get("ground_dark"), Palette.WORLD_GROUND_DARK) * tint
	# стежка — пісочна (арт-біблія), колір світу тут не підходить: у Лужка «side» зелений
	var sand := Palette.of(w.get("path", w.get("sand")), Palette.SAND)
	var water := Palette.of(w.get("cliff_water", w.get("water")), Palette.WORLD_WATER)
	var cliff: Array = w.get("cliff", [])
	var cliff_fallback := [Palette.WOOD_LIGHT, Palette.WOOD, Palette.WOOD_DARK]

	# вода довкола острова
	var span := TILE * float(TILES) + 8.0
	var sea := Mats.box(Vector3(span, 0.3, span), water)
	sea.position = Vector3(0.0, WATER_Y, 0.0)
	_island.add_child(sea)

	# «цегла» обриву: нижні шари темніші й вужчі (штучне AO, арт-біблія)
	var w_top := TILE * float(TILES)
	for k in range(CLIFF_LAYERS):
		var col: Color = Palette.of(cliff[k] if k < cliff.size() else null, cliff_fallback[k] as Color)
		var side := w_top - 0.22 * float(k + 1)
		var block := Mats.box(Vector3(side, CLIFF_STEP, side), col)
		block.position = Vector3(0.0, -TOP_H - CLIFF_STEP * (float(k) + 0.5), 0.0)
		_island.add_child(block)

	# трав'яний верх плитками: колір гуляє між двома тонами світу
	for ix in range(TILES):
		for iz in range(TILES):
			var c := grass if (ix + iz) % 2 == 0 else grass_dark
			if (ix * 3 + iz) % 5 == 0:
				c = c.lightened(0.06)
			var t := Mats.box(Vector3(TILE, TOP_H, TILE), c)
			t.position = Vector3((float(ix) - float(TILES - 1) * 0.5) * TILE, -TOP_H * 0.5, (float(iz) - float(TILES - 1) * 0.5) * TILE)
			_island.add_child(t)

	# піщана стежка попереду: під героєм і до ділянок
	# (починається за передньою межею ділянок, щоб плити не «блимали» одна крізь одну)
	for i in range(3):
		var p := Mats.box(Vector3(1.7, 0.06, 0.7), sand.lightened(0.12))
		p.position = Vector3(0.0, 0.02, 1.6 + 0.75 * float(i))
		_island.add_child(p)


## Дрібний декор світу по кутах острова (вокселі, що вже є в data/voxels).
func _build_props(w: Dictionary) -> void:
	var pool: Array = w.get("decor_big", w.get("decor", []))
	if pool.is_empty():
		return
	var edge := TILE * float(TILES) * 0.5 - 0.6
	var spots := [
		Vector3(-edge, 0.0, -edge), Vector3(edge, 0.0, -edge),
		Vector3(-edge, 0.0, edge * 0.55), Vector3(edge, 0.0, edge * 0.55),
		Vector3(-edge * 0.35, 0.0, edge), Vector3(edge * 0.35, 0.0, edge),
	]
	for i in range(spots.size()):
		var vname := String(pool[i % pool.size()])
		if not FileAccess.file_exists("res://data/voxels/%s.json" % vname):
			continue
		var mi := VoxelBuilder.instance(vname)
		mi.position = spots[i]
		mi.rotation.y = float(i) * 0.7
		_island.add_child(mi)


## Сорока кружляє над островом (декор; та сама модель, що й антагоніст у бігу).
func _build_magpie() -> void:
	_magpie = null
	if not FileAccess.file_exists("res://data/voxels/magpie.json"):
		return
	var mi := VoxelBuilder.instance("magpie")
	_island.add_child(mi)
	_magpie = mi


# ---------- ділянки й будівлі ----------

func _build_plots() -> void:
	for p in _plots:
		var n = (p as Dictionary).get("node")
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	_plots.clear()
	_ghost_node = null
	var owned := owned_of(_world_id)
	var defs := defs_for(_world_id)
	var next := next_building(defs, owned)
	var positions := plot_positions(PLOTS, CELL)
	for i in range(PLOTS):
		var pos: Vector3 = positions[i] + Vector3(0.0, 0.0, GRID_Z)
		var holder := Node3D.new()
		holder.position = pos
		_island.add_child(holder)
		var is_ghost := false
		var def := {}
		if i < owned.size():
			var mi := VoxelBuilder.instance(String(owned[i]))
			holder.add_child(mi)
		else:
			_pad(holder)
			if i == owned.size() and not next.is_empty():
				is_ghost = true
				def = next
				_ghost(holder, next)
		_plots.append({"pos": pos, "node": holder, "ghost": is_ghost, "def": def})


## Порожня ділянка: пласка піщана «подушка» — видно, що сюди щось стане.
func _pad(holder: Node3D) -> void:
	var pad := Mats.box(Vector3(CELL * 0.8, 0.05, CELL * 0.8), Palette.SAND)
	pad.position = Vector3(0.0, 0.03, 0.0)
	holder.add_child(pad)


## Привид наступної будівлі: напівпрозора модель, пунктирна рамка й ціна (злиток + число).
func _ghost(holder: Node3D, def: Dictionary) -> void:
	var ghost := Node3D.new()
	holder.add_child(ghost)
	var mi := VoxelBuilder.instance(String(def.get("voxel", "")))
	mi.material_override = VoxelBuilder.material_alpha(0.4)
	ghost.add_child(mi)
	# пунктир рамки: по два штрихи на бік
	var half := CELL * 0.45
	for side in range(4):
		for k in [-1.0, 1.0]:
			var dash := Mats.box(Vector3(CELL * 0.22, 0.06, 0.09), Palette.CREAM)
			var off := float(k) * CELL * 0.22
			match side:
				0: dash.position = Vector3(off, 0.05, -half)
				1: dash.position = Vector3(off, 0.05, half)
				2:
					dash.position = Vector3(-half, 0.05, off)
					dash.rotation.y = PI * 0.5
				_:
					dash.position = Vector3(half, 0.05, off)
					dash.rotation.y = PI * 0.5
			ghost.add_child(dash)
	# ціна: злиток + число, обличчям до камери
	var price := int(def.get("price", 0))
	var ingot := VoxelBuilder.instance("ingot")
	ingot.position = Vector3(-0.28, 1.15, 0.0)
	ingot.scale = Vector3.ONE * 1.2
	ghost.add_child(ingot)
	var label := Label3D.new()
	label.text = str(price)
	label.font_size = 96
	label.pixel_size = 0.0035
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Palette.TEXT_TITLE
	label.outline_size = 20
	label.outline_modulate = Palette.TEXT_OUTLINE
	label.position = Vector3(0.22, 1.2, 0.0)
	var f := UIKit.font()
	if f != null:
		label.font = f
	ghost.add_child(label)
	_ghost_node = ghost


func _on_buy_confirmed() -> void:
	var def := _pending
	if def.is_empty():
		_ui.hide_confirm()
		return
	var price := int(def.get("price", 0))
	if not can_afford(price, SaveService.stars()):
		_ui.flash_not_enough()
		AudioMgr.sfx("locked")
		AudioMgr.voice("need_more")
		return
	_ui.hide_confirm()
	_pending = {}
	_spend(def, price)
	var index := owned_of(_world_id).size() - 1
	_build_plots()
	_celebrate(index)
	_refresh_ui()


## Списати злитки й дописати будівлю у збереження (той самий шлях, що й Shop.buy).
func _spend(def: Dictionary, price: int) -> void:
	SaveService.add_stars(-price)
	var child := SaveService.child()
	var b = child.get("buildings", {})
	if typeof(b) != TYPE_DICTIONARY:
		b = {}
	var mine = (b as Dictionary).get(_world_id, [])
	if typeof(mine) != TYPE_ARRAY:
		mine = []
	(mine as Array).append(String(def.get("voxel", "")))
	(b as Dictionary)[_world_id] = mine
	child["buildings"] = b
	SaveService.save_game()
	Events.star_collected.emit(0)   # HUD/лічильники перерахують злитки


## Нова будівля виростає з нуля, довкола — салют.
func _celebrate(index: int) -> void:
	if index < 0 or index >= _plots.size():
		return
	var holder = (_plots[index] as Dictionary).get("node")
	if holder == null or not is_instance_valid(holder):
		return
	var node: Node3D = holder
	node.scale = Vector3.ONE * 0.01
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tweens.append(tw)
	FX.burst(_island, node.position + Vector3(0.0, 0.5, 0.0), Palette.STAR)
	FX.confetti(_island, node.position + Vector3(0.0, 1.0, 0.0), 50)
	AudioMgr.sfx("confetti")
	AudioMgr.voice("new_hat")
	if _hero != null:
		_hero.cheer()


# ---------- герой ----------

func _ensure_hero() -> void:
	if _hero == null or not is_instance_valid(_hero):
		_hero = Hero3D.new()
		add_child(_hero)
	var heroes := HeroSelect.load_heroes()
	var id := String(SaveService.child().get("hero", "puf"))
	var h = heroes.get(id, {})
	var def: Dictionary = h if typeof(h) == TYPE_DICTIONARY else {}
	_hero.set_hero(id, Palette.of(def.get("color"), Palette.HERO_DEFAULT), String(def.get("feature", "tuft")))
	Shop.apply_to(_hero)      # капелюшки й аксесуари саме цього героя
	_hero.set_process(true)
	_hero.set_running(false)
	_hero.ground_y = 0.0
	_hero.position = Vector3(0.0, 0.0, HERO_Z)
	_hero.x_target = 0.0
	_hero.rotation.y = PI


# ---------- рівні світу ----------

func _world_levels() -> Array:
	var out := []
	if _lm == null:
		return out
	for n in range(1, _lm.count() + 1):
		if String(_lm.get_level(n).get("world", "")) == _world_id:
			out.append(n)
	return out


func _state_of(num: int) -> String:
	return _lm.open_state_of(num) if _lm != null else "locked"


func _world_has_open(id: String) -> bool:
	if _lm == null:
		return false
	for n in range(1, _lm.count() + 1):
		if String(_lm.get_level(n).get("world", "")) == id and _lm.open_state_of(n) == "open":
			return true
	return false


## Куди веде «Біжимо!»: перший відкритий непройдений рівень світу, інакше — останній відкритий.
func _go_level() -> int:
	var fresh := 0
	var last := 0
	for n in _world_levels():
		if _state_of(n) != "open":
			continue
		last = n
		if fresh == 0 and _lm.stars_of(n) == 0:
			fresh = n
	return fresh if fresh > 0 else last


func _refresh_ui() -> void:
	if _ui == null:
		return
	_ui.set_stars(SaveService.stars())
	var w := _world_data()
	var idx := WORLDS.find(_world_id)
	var prev_ok := idx > 0 and _world_has_open(String(WORLDS[idx - 1]))
	var next_ok := idx >= 0 and idx < WORLDS.size() - 1 and _world_has_open(String(WORLDS[idx + 1]))
	_ui.set_world(String(w.get("name_uk", _world_id)), prev_ok, next_ok)
	var accent := Palette.of(w.get("accent"), Palette.WORLD_ACCENT)
	var rows := []
	for n in _world_levels():
		rows.append({
			"num": n,
			"state": _state_of(n),
			"stars": _lm.stars_of(n) if _lm != null else 0,
			"price": _lm.price_of(n) if _lm != null else 0,
			"name_uk": String(_lm.get_level(n).get("name_uk", "")) if _lm != null else "",
			"color": accent,
		})
	_ui.set_levels(rows)


func _on_go() -> void:
	var num := _go_level()
	if num <= 0:
		_ui.shake_go()
		AudioMgr.sfx("locked")
		return
	play_level.emit(num)


func _on_level(num: int) -> void:
	play_level.emit(num)


func _on_arrow(dir: int) -> void:
	var idx := WORLDS.find(_world_id) + dir
	if idx < 0 or idx >= WORLDS.size():
		return
	_world_id = String(WORLDS[idx])
	_pending = {}
	_ui.hide_confirm()
	_build_world()
	_refresh_ui()
	world_selected.emit(_world_id)
	if _hero != null:
		_hero.face_camera(true, 0.0)
		_hero.pop_grow()


# ---------- тапи по ділянках ----------

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open or _ui == null or _ui.popup_open():
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_tap((event as InputEventScreenTouch).position)


## Промінь із камери в площину ділянок (y = 0 локально), без фізики — просто перетин із площиною.
func _tap(screen_pos: Vector2) -> void:
	var cam := _camera()
	if cam == null:
		return
	var o := cam.project_ray_origin(screen_pos)
	var d := cam.project_ray_normal(screen_pos)
	if absf(d.y) < 0.0001:
		return
	var t := (global_position.y - o.y) / d.y
	if t <= 0.0:
		return
	var local := to_local(o + d * t)
	for p in _plots:
		var plot: Dictionary = p
		if not bool(plot.get("ghost", false)):
			continue
		var c: Vector3 = plot.get("pos", Vector3.ZERO)
		if absf(local.x - c.x) > CELL * 0.5 or absf(local.z - c.z) > CELL * 0.5:
			continue
		var def: Dictionary = plot.get("def", {})
		if def.is_empty():
			return
		AudioMgr.sfx("ui_tap")
		_pending = def
		_ui.show_confirm(String(def.get("name_uk", "")), int(def.get("price", 0)), String(def.get("voxel", "")))
		return


# ---------- анімація ----------

func _process(delta: float) -> void:
	_t += delta
	if _ghost_node != null and is_instance_valid(_ghost_node):
		_ghost_node.position.y = 0.06 + sin(_t * 2.0) * 0.05
	if _magpie != null and is_instance_valid(_magpie):
		var a := _t * 0.6
		var r := 3.4
		_magpie.position = Vector3(cos(a) * r, 2.4 + sin(_t * 1.7) * 0.25, sin(a) * r)
		_magpie.rotation.y = -a + PI * 0.5
