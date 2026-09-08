## Дорога: пул рядів по 1 клітинці (3 доріжки + узбіччя + декор). Ряди їдуть на героя (+Z) і переставляються вперед.
## Полотно дороги — чотири MultiMesh на всю трасу (центр парних рядів, центр непарних, ліве узбіччя, праве)
## замість 132 окремих вузлів: 4 draw calls замість 132 (docs/optimisation OPT-01).
## Декор узбіч — теж MultiMesh, по одному шару на вид вокселя (OPT-02): дерева, паркан і квіти
## повторюються десятками разів, тож малюємо їх пачками. Живність (зайчики, крабики) лишається
## вузлами Critter3D — у неї власна анімація стрибків, її в пачку не звести.
## Ряд лишається вузлом, але тримає лише декор; його z, scale.y і значення з _row_* — джерело правди,
## яке _sync_road() щокадру переносить у буфери MultiMesh.
## Зміна світу — перефарбування рядів з «перебудовою кубиками» (стаггер по z).
## Занурення (GDD v1.3 §7): стіни світу з даних — walls_near (кожен ряд, впритул до дороги), walls_far (далі, більші),
## canopy (крона над дорогою кожен 3-й ряд), sea (море на всю ширину, дорога невидима).
## Плато (GDD v1.4 §3, арт-біблія): дорога лежить на верху блокового плато — під узбіччями три шари
## теракотової «цегли» (нижні темніші й вужчі, разом ≈ 1,2 м), під ними пласка бірюзова вода з обох боків.
## Між доріжками — тонкі темні шви, щоб плити читались окремо. Орієнтири (landmarks): арка/вежа/ворота
## кожні 28–30 рядів — точка сходу завжди зайнята.
class_name Track
extends Node3D

const ROWS := 44
const BEHIND := 5.0          # позаду камери — ряд переставляється вперед
const LANES_W := 3.2         # ширина для 3 доріжок (базовий меш; масштабується під N)
const SIDE_W := 8.0
## Море на всю видиму ширину.
const SEA_W := 60.0
const CANOPY_Y := 3.2
const CANOPY_SCALE := 2.5
## Один предмет декору: x, y, z (у межах ряду), поворот навколо y, масштаб, фаза «дихання».
const DECOR_STRIDE := 6
## Обрив плато: три шари «цегли» по 0,4 м під узбіччями (разом 1,2 м).
const CLIFF_LAYERS := 3
const CLIFF_STEP := 0.4
const CLIFF_BOTTOM := -0.4 - CLIFF_STEP * float(CLIFF_LAYERS)
## Шви між доріжками: тонкі темні бруски на межах плит (максимум — для 7 доріжок).
const SEAM_W := 0.04
const MAX_SEAMS := 6
## Орієнтир (арка/вежа/ворота) — раз на стільки рядів; ≤ 30, щоб він завжди був у полі зору.
const LANDMARK_MIN := 28
const LANDMARK_MAX := 30
## Ширина, під яку намальовані арки (3 доріжки); Track масштабує їх під поточну дорогу.
const ARCH_BASE_W := 3.2
## Ближній пояс стін — впритул до дороги (GDD v1.4 §3 «Стіни впритул»).
const NEAR_MIN := 0.4
const NEAR_MAX := 0.8

var world: Dictionary = {}
var lanes := 3
## Вузли рядів — тепер лише тримачі декору (полотно малює MultiMesh).
var _rows: Array[Node3D] = []
## Полотно: [парні ряди, непарні] і [ліве узбіччя, праве].
var _mm_center: Array[MultiMeshInstance3D] = []
var _mm_side: Array[MultiMeshInstance3D] = []
## Обрив плато: шар «цегли» на кожен рівень (по 2 інстанси на ряд — ліворуч і праворуч).
var _mm_cliff: Array[MultiMeshInstance3D] = []
## Шви між доріжками: MAX_SEAMS інстансів на ряд (зайві — з нульовим масштабом).
var _mm_seam: MultiMeshInstance3D
## Вода внизу з обох боків плато (окрема від «моря» _water).
var _side_water: Array[MeshInstance3D] = []
## Пул ближніх стін світу: walls_near + добудовані в діорамі будівлі дитини.
var _near_pool: Array = []
## Скільки рядів лишилось до наступного орієнтира.
var _landmark_left := 10
## Стан рядів, який анімується: масштаб центру по x і x узбіч (стаггер при зміні ширини).
var _row_sx := PackedFloat32Array()
var _row_lx := PackedFloat32Array()
var _row_rx := PackedFloat32Array()
## Масштаб узбіч по x: [ліве, праве]. Смужка піску з боку моря — спільна для всіх рядів, без стаггера.
var _side_sx := [1.0, 1.0]
## Декор: шар на вид вокселя. Ключ — "воксель" або "воксель|колір" (квіти різних кольорів — різні меші).
var _decor_layer_of: Dictionary = {}
var _decor_mm: Array[MultiMeshInstance3D] = []
## Предмети декору по рядах: у якому шарі кожен і його DECOR_STRIDE чисел.
var _decor_ids: Array[PackedInt32Array] = []
var _decor_data: Array[PackedFloat32Array] = []
## Спільний час «дихання» декору (фаза кожного предмета лежить у його даних).
var _decor_t := 0.0
var _water: MeshInstance3D
var _water_mat: ShaderMaterial
var _scroll := 0.0
var _far: Node3D
var _hills: Array[MeshInstance3D] = []
var _clouds: Array[Node3D] = []
## Декоративне море збоку дороги (Пляж): -1 — ліворуч, 1 — праворуч, 0 — нема (world "sea_side").
var _sea_side := 0
## Море на всю ширину (world "sea": true) — дорога під героєм невидима, герой на дошці.
var _sea := false


func _ready() -> void:
	var center_mesh := BoxMesh.new()
	center_mesh.size = Vector3(LANES_W, 0.4, 1.0)
	var side_mesh := BoxMesh.new()
	side_mesh.size = Vector3(SIDE_W, 0.4, 1.0)
	# центр смугастий: парні ряди одного кольору, непарні іншого — тому два MultiMesh
	_mm_center = [_make_canvas(center_mesh, (ROWS + 1) / 2), _make_canvas(center_mesh, ROWS / 2)]
	_mm_side = [_make_canvas(side_mesh, ROWS), _make_canvas(side_mesh, ROWS)]
	_mm_center[0].material_override = Mats.solid(Palette.WORLD_GROUND)
	_mm_center[1].material_override = Mats.solid(Palette.WORLD_GROUND_DARK)
	var side_mat := Mats.solid(Palette.WORLD_SIDE)
	_mm_side[0].material_override = side_mat
	_mm_side[1].material_override = side_mat
	# обрив плато: шар «цегли» на кожен рівень, по інстансу на бік ряду
	var cliff_mesh := BoxMesh.new()
	cliff_mesh.size = Vector3(SIDE_W, CLIFF_STEP, 1.0)
	for k in range(CLIFF_LAYERS):
		_mm_cliff.append(_make_canvas(cliff_mesh, ROWS * 2))
	# шви між доріжками
	var seam_mesh := BoxMesh.new()
	seam_mesh.size = Vector3(SEAM_W, 0.44, 1.0)
	_mm_seam = _make_canvas(seam_mesh, ROWS * MAX_SEAMS)

	_row_sx.resize(ROWS)
	_row_lx.resize(ROWS)
	_row_rx.resize(ROWS)
	_decor_ids.resize(ROWS)
	_decor_data.resize(ROWS)
	var side_x := LANES_W * 0.5 + SIDE_W * 0.5
	for i in range(ROWS):
		var row := Node3D.new()
		row.name = "Row%d" % i
		row.position.z = BEHIND - float(i)
		row.set_meta("i", i)   # індекс ряду — для крони кожен 3-й ряд
		add_child(row)
		_rows.append(row)
		_row_sx[i] = 1.0
		_row_lx[i] = -side_x
		_row_rx[i] = side_x
		_decor_ids[i] = PackedInt32Array()
		_decor_data[i] = PackedFloat32Array()
	_sync_road()
	# далекий план: пагорби по боках і хмарки, що пливуть
	_far = Node3D.new()
	_far.name = "Far"
	add_child(_far)
	for i in range(14):
		var side := -1.0 if i % 2 == 0 else 1.0
		var hill := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var rad := randf_range(3.0, 6.0)
		sm.radius = rad
		sm.height = rad * randf_range(0.7, 1.1)
		sm.radial_segments = 12
		sm.rings = 6
		hill.mesh = sm
		hill.position = Vector3(side * randf_range(9.0, 16.0), -rad * 0.55, BEHIND - float(i) * 3.4 - 6.0)
		hill.name = "Hill"
		_far.add_child(hill)
		_hills.append(hill)
	for i in range(8):
		var cloud := Node3D.new()
		for j in range(3):
			var puff := Mats.box(Vector3(randf_range(0.8, 1.6), 0.5, 0.7), Color(1, 1, 1, 1))
			puff.position = Vector3(float(j) * 0.7 - 0.7, randf_range(0.0, 0.25), 0.0)
			cloud.add_child(puff)
		cloud.position = Vector3(randf_range(-12.0, 12.0), randf_range(5.0, 8.0), BEHIND - float(i) * 5.5 - 4.0)
		_far.add_child(cloud)
		_clouds.append(cloud)
	# вода для Хвилі — одна площина з вершинним шейдером
	_water = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(LANES_W + 0.4, ROWS + 4.0)
	pm.subdivide_depth = 60
	pm.subdivide_width = 6
	_water.mesh = pm
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://src/run3d/water.gdshader")
	_water.material_override = _water_mat
	_water.position = Vector3(0.0, 0.02, BEHIND - ROWS * 0.5)
	_water.visible = false
	add_child(_water)
	# вода під плато: дві пласкі бірюзові площини обабіч дороги (арт-біблія)
	for i in range(2):
		var sw := MeshInstance3D.new()
		var spm := PlaneMesh.new()
		spm.size = Vector2(SEA_W * 0.5, float(ROWS) + 8.0)
		sw.mesh = spm
		sw.name = "SideWater%d" % i
		sw.position = Vector3(0.0, CLIFF_BOTTOM - 0.05, BEHIND - ROWS * 0.5)
		sw.material_override = Mats.solid(Palette.CYAN)
		sw.visible = false
		add_child(sw)
		_side_water.append(sw)


## Один шар полотна. AABB задаємо руками на всю трасу: інакше рушій перераховував би її
## щокадру по всіх інстансах, а на краю екрана дорога могла б зникнути через відсікання.
func _make_canvas(mesh: Mesh, count: int, height := 6.0) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var box := AABB(Vector3(-SEA_W * 0.5, -2.0, BEHIND - float(ROWS) - 2.0), Vector3(SEA_W, height, float(ROWS) + 8.0))
	mm.custom_aabb = box
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.custom_aabb = box
	add_child(mi)
	return mi


## Шар під конкретний вид вокселя; створюється при першій появі й лишається (порожній нічого не коштує).
## Матеріал уже вшитий у меш VoxelBuilder, тож material_override не потрібен.
func _decor_layer(kind: String, override: Dictionary) -> int:
	var key := kind if override.is_empty() else kind + "|" + JSON.stringify(override)
	if _decor_layer_of.has(key):
		return int(_decor_layer_of[key])
	# декор вищий за дорогу (крона на 3,2 м) і ширший — свій AABB
	var mi := _make_canvas(VoxelBuilder.mesh(kind, override), 0, 16.0)
	_decor_mm.append(mi)
	_decor_layer_of[key] = _decor_mm.size() - 1
	return _decor_mm.size() - 1


## Записати предмет у пачку ряду. z, поворот і фаза — випадкові, як було в кожного Critter3D.
## yaw ≥ 0 — фіксований поворот (орієнтири-арки мають дивитись на камеру, а не крутитись).
func _add_decor(ids: PackedInt32Array, data: PackedFloat32Array, kind: String, override: Dictionary, x: float, y: float, s: float, yaw: float = -1.0) -> void:
	ids.append(_decor_layer(kind, override))
	data.append(x)
	data.append(y)
	data.append(randf_range(-0.4, 0.4) if yaw < 0.0 else 0.0)
	data.append(randf() * TAU if yaw < 0.0 else yaw)
	data.append(s)
	# фазу зсуваємо на поточний час, щоб у мить появи вона була такою ж, як у старого Critter3D
	data.append(randf() * 10.0 - _decor_t)


## Переносить декор у буфери шарів. Те саме «дихання», що робив Critter3D._process:
## ледь помітний масштаб по y і нахил по z із фазою від власного часу й положення.
func _sync_decor(delta: float) -> void:
	_decor_t += delta
	var n := _decor_mm.size()
	if n == 0:
		return
	var counts := PackedInt32Array()
	counts.resize(n)
	counts.fill(0)
	for i in range(_rows.size()):
		for b in _decor_ids[i]:
			counts[b] += 1
	for b in range(n):
		var mm := _decor_mm[b].multimesh as MultiMesh
		if counts[b] > mm.instance_count:
			mm.instance_count = maxi(16, counts[b] * 2)   # з запасом, щоб не перевиділяти щоряду
	var used := PackedInt32Array()
	used.resize(n)
	used.fill(0)
	for i in range(_rows.size()):
		var row := _rows[i]
		var sy_row: float = row.scale.y      # «перебудова кубиками» піднімає й декор
		var z_row: float = row.position.z
		var ids := _decor_ids[i]
		var d := _decor_data[i]
		for j in range(ids.size()):
			var o := j * DECOR_STRIDE
			var x := d[o]
			var z := d[o + 2]
			var t := _decor_t + d[o + 5]
			var breathe := 1.0 + sin(t * 1.6 + x) * 0.02
			var tilt := sin(t * 1.2 + z) * 0.02
			var sc := d[o + 4]
			var basis := Basis(Vector3.UP, d[o + 3]).scaled(Vector3(sc, sc, sc)) * Basis(Vector3(0, 0, 1), tilt).scaled(Vector3(1.0, breathe, 1.0))
			basis = Basis.from_scale(Vector3(1.0, sy_row, 1.0)) * basis
			var b := ids[j]
			(_decor_mm[b].multimesh as MultiMesh).set_instance_transform(used[b], Transform3D(basis, Vector3(x, sy_row * d[o + 1], z_row + z)))
			used[b] += 1
	for b in range(n):
		(_decor_mm[b].multimesh as MultiMesh).visible_instance_count = used[b]


## Переносить стан рядів у буфери MultiMesh. Кілька сотень записів на кадр — дешевше,
## ніж рухати 132 вузли, кожен з яких тягне за собою перерахунок AABB і відсікання.
func _sync_road() -> void:
	var seams := seam_xs()
	var seam_mm := _mm_seam.multimesh as MultiMesh
	for i in range(_rows.size()):
		var row := _rows[i]
		var sy: float = row.scale.y            # «перебудова кубиками» при зміні світу
		var z: float = row.position.z
		var y := -0.2 * sy                     # локальний y полотна, помножений на масштаб ряду
		(_mm_center[i % 2].multimesh as MultiMesh).set_instance_transform(i / 2,
			Transform3D(Basis.from_scale(Vector3(_row_sx[i], sy, 1.0)), Vector3(0.0, y, z)))
		(_mm_side[0].multimesh as MultiMesh).set_instance_transform(i,
			Transform3D(Basis.from_scale(Vector3(float(_side_sx[0]), sy, 1.0)), Vector3(_row_lx[i], y, z)))
		(_mm_side[1].multimesh as MultiMesh).set_instance_transform(i,
			Transform3D(Basis.from_scale(Vector3(float(_side_sx[1]), sy, 1.0)), Vector3(_row_rx[i], y, z)))
		# обрив плато: кожен наступний шар «цегли» нижчий і трохи вужчий — східці, як в арт-біблії
		for k in range(CLIFF_LAYERS):
			var cy := (-0.4 - CLIFF_STEP * (float(k) + 0.5)) * sy
			var inset := 1.0 - 0.1 * float(k + 1)
			var cmm := _mm_cliff[k].multimesh as MultiMesh
			cmm.set_instance_transform(i * 2,
				Transform3D(Basis.from_scale(Vector3(float(_side_sx[0]) * inset, sy, 1.0)), Vector3(_row_lx[i], cy, z)))
			cmm.set_instance_transform(i * 2 + 1,
				Transform3D(Basis.from_scale(Vector3(float(_side_sx[1]) * inset, sy, 1.0)), Vector3(_row_rx[i], cy, z)))
		# шви між плитами доріжок; зайві інстанси ховаємо нульовим масштабом
		for k in range(MAX_SEAMS):
			var t := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
			if k < seams.size():
				t = Transform3D(Basis.from_scale(Vector3(1.0, sy, 1.0)), Vector3(seams[k], y, z))
			seam_mm.set_instance_transform(i * MAX_SEAMS + k, t)


## X-координати швів між доріжками (їх lanes − 1). Чиста функція — зручно для тестів.
func seam_xs() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var m := (lanes - 1) / 2
	for l in range(-m, m):
		out.append((float(l) + 0.5) * Hero3D.LANE_W)
	return out


var season: Dictionary = {}


func rebuild(w: Dictionary, animate: bool = true, s: Dictionary = {}, n_lanes: int = -1) -> void:
	world = w.duplicate()
	season = s
	# море на всю ширину (Серфінг): дорога невидима, герой на дошці; старий режим Хвиля — теж вода під дорогою
	_sea = bool(w.get("sea", false))
	var is_water := _sea or String(w.get("mode", "run")) == "slide"
	# море збоку (Пляж на піску) — узбіччя з того боку стає смужкою піску, тому знаємо це до розкладки рядів
	_sea_side = 0 if is_water else int(w.get("sea_side", 0))
	# ширина відома одразу — декор кладемо один раз під неї (і перекладаємо узбіччя під море/без моря)
	if n_lanes > 0:
		lanes = clampi(n_lanes, 3, 7)
	set_lanes(lanes, false)
	# сезон: підфарбовує землю й міняє квіти (сніг/осінь), нічого не додає до мешів
	if not s.is_empty():
		var tint := Palette.of(s.get("ground_tint"), Palette.GROUND_TINT_NONE)
		for key in ["ground", "ground_dark", "side"]:
			world[key] = (Palette.of(world.get(key), Palette.WORLD_GROUND) * tint).to_html(false)
		var dc: Array = s.get("decor_colors", [])
		if not dc.is_empty():
			world["decor_colors"] = dc
	_water.visible = is_water or _sea_side != 0
	if _water.visible:
		var wc := Palette.of(w.get("water"), Palette.WORLD_WATER)
		_water_mat.set_shader_parameter("color", wc)
		var light := wc if _sea or not is_water else Palette.of(w.get("ground_dark"), Palette.WORLD_WATER_DARK)
		_water_mat.set_shader_parameter("color_light", light.lightened(0.35))
	_layout_water()
	# ближні стіни: список світу + будівлі, добудовані дитиною в діорамі
	_near_pool = _near_wall_pool()
	# перший орієнтир — уже в дальній половині траси, щоб точка сходу не була порожня
	_landmark_left = randi_range(6, 12)
	# пагорби у колір далекого плану світу; на морі їх не видно
	var far_mat := Mats.solid(Palette.of(world.get("far", world.get("side")), Palette.WORLD_SIDE).lightened(0.15))
	for h in _hills:
		h.material_override = far_mat
		h.visible = not _sea
	_paint_road(is_water)
	for i in range(_rows.size()):
		var row := _rows[i]
		_decorate(row)
		if animate:
			row.scale.y = 0.01
			var tw := create_tween()
			tw.tween_interval(0.02 * float(i))
			tw.tween_property(row, "scale:y", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioMgr.sfx("rebuild")


## Кольори полотна: центр смугастий (парні/непарні ряди), узбіччя одноколірне.
## Видимість тепер на рівні шару: на воді нема центру, на морі нема й узбіч.
func _paint_road(is_water: bool) -> void:
	_mm_center[0].material_override = Mats.solid(Palette.of(world.get("ground"), Palette.WORLD_GROUND))
	_mm_center[1].material_override = Mats.solid(Palette.of(world.get("ground_dark"), Palette.WORLD_GROUND_DARK))
	var side := Mats.solid(Palette.of(world.get("side"), Palette.WORLD_SIDE))
	_mm_side[0].material_override = side
	_mm_side[1].material_override = side
	for mi in _mm_center:
		mi.visible = not is_water
	for mi in _mm_side:
		mi.visible = not _sea
	# обрив плато: три теракотові шари, кожен нижчий — темніший (штучне AO з арт-біблії)
	var cliff: Array = world.get("cliff", [])
	var fallbacks: Array[Color] = [Palette.CORAL_DEEP, Palette.EMBER, Palette.WOOD_DARK]
	for k in range(CLIFF_LAYERS):
		var raw = cliff[k] if k < cliff.size() else null
		_mm_cliff[k].material_override = Mats.solid(Palette.of(raw, fallbacks[k]))
		_mm_cliff[k].visible = not _sea and not is_water
	# шов між доріжками — темніша версія кольору землі, якщо світ не задав свій
	var seam_c := Palette.of(world.get("seam"), Palette.of(world.get("ground_dark"), Palette.WORLD_GROUND_DARK).darkened(0.35))
	_mm_seam.material_override = Mats.solid(seam_c)
	_mm_seam.visible = not is_water and not _sea
	# бірюзова вода внизу — з обох боків плато
	var low_water := Mats.solid(Palette.of(world.get("cliff_water"), Palette.CYAN))
	for sw in _side_water:
		sw.material_override = low_water
		sw.visible = not _sea and not is_water


## Узбіччя: стіни світу (walls_near впритул, walls_far далі й більші), ближній пояс — дрібне (квіти, гриби),
## дальній — велике (дерева, пальми), живність — зайчики; крона над дорогою кожен 3-й ряд.
## З боку моря (Пляж на піску) узбіччя — вода, декор туди не кладемо. На морі (sea) — лише буї/скелі у воді й гребені хвиль.
func _decorate(row: Node3D) -> void:
	for c in row.get_children():
		c.queue_free()      # у ряді лишається лише живність — решта декору тепер у пачках
	var i := int(row.get_meta("i", 0))
	var ids := PackedInt32Array()
	var data := PackedFloat32Array()
	var kinds: Array = world.get("decor", [])
	var big: Array = world.get("decor_big", [])
	var critters: Array = world.get("critters", [])
	var colors: Array = world.get("decor_colors", [])
	var walls_near: Array = _near_pool
	var walls_far: Array = world.get("walls_far", [])
	var far_scale: Array = world.get("walls_far_scale", [1.4, 2.0])
	var edge := road_width() * 0.5
	for side in [-1.0, 1.0]:
		if _sea_side != 0 and signf(float(side)) == signf(float(_sea_side)):
			continue
		# стіна далека — кожен ряд, більша (буї/скелі у воді на морі)
		if not walls_far.is_empty():
			_add_decor(ids, data, String(walls_far[randi() % walls_far.size()]), {},
				side * (edge + randf_range(3.0, 5.0)),
				-0.05 if _sea else 0.0,
				randf_range(float(far_scale[0]), float(far_scale[1])))
		if _sea:
			# гребені хвиль із піною — плавають довкола траси
			if randf() < 0.3:
				_add_decor(ids, data, "wave_crest", {}, side * (edge + randf_range(0.8, 6.0)), 0.0, 1.0)
			continue
		# стіна близька — КОЖЕН ряд, впритул до дороги (0,4–0,8 м), висоти чергуються: суцільний пояс без дірок
		if not walls_near.is_empty():
			var tall := (i + (1 if side > 0.0 else 0)) % 2 == 0
			_add_decor(ids, data, String(walls_near[randi() % walls_near.size()]), {},
				side * (edge + randf_range(NEAR_MIN, NEAR_MAX)), 0.0, 1.25 if tall else 0.85)
		# дрібне — часто
		if not kinds.is_empty() and randf() < 0.9:
			var kind := String(kinds[randi() % kinds.size()])
			var override := {}
			if kind == "flower" and not colors.is_empty():
				override = {"p": String(colors[randi() % colors.size()])}
			_add_decor(ids, data, kind, override, side * (edge + randf_range(0.5, 2.6)), 0.0, 1.0)
		# велике — рідше, далі
		if not big.is_empty() and randf() < 0.35:
			_add_decor(ids, data, String(big[randi() % big.size()]), {}, side * (edge + randf_range(2.8, 5.5)), 0.0, 1.0)
		# живність — зрідка; лишається вузлом, бо стрибає й озирається по-своєму
		if not critters.is_empty() and randf() < 0.12:
			var cr := Critter3D.new()
			cr.position = Vector3(side * (edge + randf_range(1.0, 3.0)), 0.0, randf_range(-0.4, 0.4))
			row.add_child(cr)
			cr.setup(String(critters[randi() % critters.size()]))
	# крона над дорогою — кожен 3-й ряд
	var canopy = world.get("canopy", false)
	var canopy_voxel := ""
	if typeof(canopy) == TYPE_STRING:
		canopy_voxel = String(canopy)
	elif typeof(canopy) == TYPE_BOOL and bool(canopy):
		canopy_voxel = "canopy_leaves"
	if canopy_voxel != "" and i % 3 == 0:
		_add_decor(ids, data, canopy_voxel, {}, randf_range(-1.0, 1.0), CANOPY_Y, CANOPY_SCALE)
	# орієнтир на точці сходу: арка на всю дорогу або вежа/ворота збоку — раз на 28–30 рядів
	var landmarks: Array = world.get("landmarks", [])
	if not landmarks.is_empty():
		_landmark_left -= 1
		if _landmark_left <= 0:
			_landmark_left = randi_range(LANDMARK_MIN, LANDMARK_MAX)
			var lk := String(landmarks[randi() % landmarks.size()])
			if lk.contains("arch"):
				_add_decor(ids, data, lk, {}, 0.0, 0.0, road_width() / ARCH_BASE_W, 0.0)
			else:
				var s := -1.0 if randf() < 0.5 else 1.0
				_add_decor(ids, data, lk, {}, s * (edge + 1.2), 0.0, 1.2, 0.0 if s > 0.0 else PI)
	_decor_ids[i] = ids
	_decor_data[i] = data


## Ближні стіни світу + будівлі, які дитина добудувала в діорамі
## (контракт з агентом діорами: SaveService.child()["buildings"][world_id] — масив імен вокселів).
func _near_wall_pool() -> Array:
	var pool: Array = (world.get("walls_near", []) as Array).duplicate()
	var child: Dictionary = SaveService.child() if SaveService != null else {}
	var saved = child.get("buildings", {})
	if typeof(saved) == TYPE_DICTIONARY:
		var mine = (saved as Dictionary).get(String(world.get("id", "")), [])
		if typeof(mine) == TYPE_ARRAY:
			for v in (mine as Array):
				if typeof(v) == TYPE_STRING and not pool.has(v):
					pool.append(v)
	return pool


## Пташка перелітає дорогу час від часу.
func _spawn_bird() -> void:
	var birds: Array = world.get("birds", [])
	if birds.is_empty():
		return
	var b := Critter3D.new()
	_far.add_child(b)
	b.setup(String(birds[randi() % birds.size()]))
	var from_left := b._dir > 0
	b.position = Vector3(-13.0 if from_left else 13.0, randf_range(2.5, 4.5), randf_range(-14.0, -4.0))


var _bird_t := 5.0


func _process(delta: float) -> void:
	# полотно синхронізуємо і тут: під час анімацій перебудови advance() не викликають
	_sync_road()
	_sync_decor(delta)
	_bird_t -= delta
	if _bird_t < 0.0:
		_bird_t = randf_range(6.0, 14.0)
		_spawn_bird()


## Поточна ширина дороги в метрах.
func road_width() -> float:
	return float(lanes) * Hero3D.LANE_W + 0.2


## Звузити/розширити дорогу: центр масштабується по x, узбіччя відʼїжджають; кубики «перебудовуються».
func set_lanes(n: int, animate: bool = true) -> void:
	lanes = clampi(n, 3, 7)
	var w := road_width()
	var sx := w / LANES_W
	var side_x := w * 0.5 + SIDE_W * 0.5
	# з боку моря узбіччя — вузька смужка піску (1 м), далі вода
	var beach_x := w * 0.5 + 0.5
	var beach_sx := 1.0 / SIDE_W
	_side_sx[0] = beach_sx if _sea_side < 0 else 1.0
	_side_sx[1] = beach_sx if _sea_side > 0 else 1.0
	var lx := -beach_x if _sea_side < 0 else -side_x
	var rx := beach_x if _sea_side > 0 else side_x
	for i in range(_rows.size()):
		if animate:
			_decorate(_rows[i])   # декор перекладається під нову ширину (при rebuild його кладе сам rebuild)
			var tw := create_tween()
			tw.tween_interval(0.012 * float(i))
			tw.tween_method(_set_row_sx.bind(i), _row_sx[i], sx, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_method(_set_row_lx.bind(i), _row_lx[i], lx, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_method(_set_row_rx.bind(i), _row_rx[i], rx, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_row_sx[i] = sx
			_row_lx[i] = lx
			_row_rx[i] = rx
	_sync_road()
	_layout_water()
	if animate:
		AudioMgr.sfx("rebuild")


# Цілі для tween_method: анімуємо числа ряду, бо вузлів-мешів більше нема.
func _set_row_sx(v: float, i: int) -> void:
	_row_sx[i] = v


func _set_row_lx(v: float, i: int) -> void:
	_row_lx[i] = v


func _set_row_rx(v: float, i: int) -> void:
	_row_rx[i] = v


## Вода: під дорогою (Хвиля) або збоку від неї (Пляж, sea_side) — ширина SIDE_W, за смужкою піску.
func _layout_water() -> void:
	if _water == null:
		return
	var w := road_width()
	# вода під плато: пласкі площини одразу за краєм узбіччя, з обох боків
	for i in range(_side_water.size()):
		var dir := -1.0 if i == 0 else 1.0
		_side_water[i].position.x = dir * (w * 0.5 + SEA_W * 0.25)
		_side_water[i].position.y = CLIFF_BOTTOM - 0.05
	if _sea:
		# море на всю видиму ширину, трохи нижче дороги (дошка сидить у воді)
		_water.scale.x = SEA_W / (LANES_W + 0.4)
		_water.position.x = 0.0
		_water.position.y = -0.05
	elif _sea_side != 0:
		_water.scale.x = SIDE_W / (LANES_W + 0.4)
		_water.position.x = float(_sea_side) * (w * 0.5 + SIDE_W * 0.5 + 1.0)
		_water.position.y = 0.02
	else:
		_water.scale.x = w / LANES_W
		_water.position.x = 0.0
		_water.position.y = 0.02


## Зсунути дорогу на dist клітинок (може бути відʼємним — відкат у Стрибках).
func advance(dist: float) -> void:
	for row in _rows:
		row.position.z += dist
		if row.position.z > BEHIND:
			row.position.z -= float(ROWS)
			_decorate(row)
		elif row.position.z < BEHIND - float(ROWS):
			row.position.z += float(ROWS)
	if _water.visible:
		_scroll += dist
		_water_mat.set_shader_parameter("scroll", _scroll)
	# далекий план рухається повільніше — паралакс
	for h in _hills:
		h.position.z += dist * 0.35
		if h.position.z > BEHIND + 8.0:
			h.position.z -= 48.0
	for c in _clouds:
		c.position.z += dist * 0.15
		c.position.x += 0.002
		if c.position.z > BEHIND + 6.0:
			c.position.z -= 46.0
			c.position.x = randf_range(-12.0, 12.0)
	# синхронізацію в пачки робить _process (батько Run3D обробляється раніше за Track — той самий кадр);
	# тут не дублюємо: подвійний _sync_* = ~900 зайвих set_instance_transform на кадр
