## Друзки: предмет розлітається на шматки, які летять, крутяться, падають і підстрибують.
##
## Навіщо. Досі розбита перешкода просто стискалась і зникала («пшик» + спалах часток). Для
## дитини удар — найсмачніша мить, і вона мусить лишати слід: ящик має РОЗЛЕТІТИСЯ.
##
## Чому MultiMesh, а не вузол на шматок. Малюнок коштує рівно ОДИН виклик на весь вибух,
## скільки б не було шматків. Гра вже впирається в draw calls (242 при цілі GDD ≤ 150,
## docs/optimisation/2026-09-07-render-budget.md), тож десяток вузлів на кожен удар — це
## десяток викликів у найгарячішу мить кадру. Стан шматків лежить у пласкому масиві, як
## і декор траси в Track — та сама механіка, той самий стиль.
##
## Чому не GPUParticles3D, як решта FX. Частинки тут — білборди-плями, вони читаються як
## дим і бризки. Шматок дошки мусить бути об'ємним і перевертатися в польоті; це не пляма.
##
## Світ їде на героя, тож вузол додається В СПАВНЕР: його `advance()` зсуває всіх своїх дітей
## разом із дорогою, а `KILL_Z` прибирає те, що поїхало за спину. Інакше друзки зависли б у
## повітрі, доки дорога тікає з-під них.
class_name Debris
extends MultiMeshInstance3D

## Скільки живуть шматки, секунд. Далі вузол прибирає себе сам.
const LIFE_SEC := 1.1
## Останню чверть життя шматки стискаються в нуль — щоб не зникали стрибком.
const FADE_FROM := 0.75
const GRAVITY := -14.0
## Скільки швидкості лишається після удару об землю.
const BOUNCE := 0.35
## Скільки шматків типово.
const PIECES := 10
## Один шматок у пласкому масиві: позиція, швидкість, вісь обертання, кут, швидкість обертання.
const STRIDE := 11

var _data := PackedFloat32Array()
var _t := 0.0
var _ground_y := 0.0
var _piece := Vector3.ONE

static var _mat: StandardMaterial3D = null
static var _color_cache: Dictionary = {}


## Розсипати предмет. at — центр предмета у координатах parent; size — його габарити (шматки
## розлітаються зсередини цього об'єму); color — базовий колір, кожен шматок дістає свій
## відтінок. Повертає вузол (для тестів; у грі він прибирає себе сам).
static func burst(parent: Node, at: Vector3, color: Color, size: Vector3,
		amount: int = PIECES) -> Debris:
	var d := Debris.new()
	d.position = at
	# Земля в МІСЦЕВИХ координатах вузла: сам вузол стоїть на висоті центра предмета.
	d._ground_y = -at.y
	d._build(color, size, maxi(1, amount))
	parent.add_child(d)
	return d


## Колір предмета для друзок. Три джерела по черзі, бо моделі в грі різні:
##   1. вершинні кольори — так фарбовані вокселі;
##   2. середній колір текстури — так фарбовані справжні .glb (у них вершинних кольорів нема,
##      і саме через це перші друзки пенька вийшли кремовими замість коричневих);
##   3. albedo матеріалу — для простих однокольорових мешів.
## Результат кешується: усереднення картинки коштує дорого, а видів у грі десятки.
static func color_of(mesh: Mesh, fallback: Color) -> Color:
	if mesh == null:
		return fallback
	var key := str(mesh.get_rid().get_id())
	if _color_cache.has(key):
		return _color_cache[key]
	var out := fallback
	if mesh.get_surface_count() > 0:
		var arrays := mesh.surface_get_arrays(0)
		var cols = arrays[Mesh.ARRAY_COLOR] if arrays.size() > Mesh.ARRAY_COLOR else null
		if cols is PackedColorArray and (cols as PackedColorArray).size() > 0:
			out = (cols as PackedColorArray)[0]
		else:
			var mat := mesh.surface_get_material(0)
			var std := mat as StandardMaterial3D
			if std != null:
				var tex := std.albedo_texture
				if tex != null:
					var img := tex.get_image()
					if img != null:
						if img.is_compressed():
							img.decompress()
						img.resize(1, 1, Image.INTERPOLATE_LANCZOS)
						out = img.get_pixel(0, 0)
				else:
					out = std.albedo_color
	_color_cache[key] = out
	return out


## Де шматок за t секунд: балістика з одним відскоком від землі. Винесено окремо й БЕЗ дерева
## навмисно — рух можна перевірити числами, не запускаючи сцену (у проєкті вже коштувало
## помилок те, що формула жила всередині вузла й перевірялась лише оком).
static func piece_at(p0: Vector3, v0: Vector3, t: float, ground_y: float) -> Vector3:
	var p := p0 + v0 * t + Vector3(0.0, 0.5 * GRAVITY * t * t, 0.0)
	if p.y >= ground_y:
		return p
	# час удару об землю — корінь рівняння p0.y + v0.y*t + g*t²/2 = ground_y
	var a := 0.5 * GRAVITY
	var b := v0.y
	var c := p0.y - ground_y
	var disc := b * b - 4.0 * a * c
	if disc <= 0.0:
		return Vector3(p.x, ground_y, p.z)
	var t_hit := (-b - sqrt(disc)) / (2.0 * a)
	if t_hit <= 0.0 or t_hit >= t:
		return Vector3(p.x, ground_y, p.z)
	var v_hit := b + GRAVITY * t_hit
	var rest := t - t_hit
	var hx := p0.x + v0.x * t_hit
	var hz := p0.z + v0.z * t_hit
	# після відскоку горизонтальна швидкість гальмується так само, як і вертикальна
	var vy2 := -v_hit * BOUNCE
	var y2 := ground_y + vy2 * rest + 0.5 * GRAVITY * rest * rest
	return Vector3(hx + v0.x * BOUNCE * rest, maxf(y2, ground_y), hz + v0.z * BOUNCE * rest)


func _build(color: Color, size: Vector3, amount: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Шматок — кубик приблизно в п'яту частину найменшого виміру предмета. Перша спроба дала
	# третину, і на знімку шматки читались як ДРУГИЙ предмет поруч, а не як друзки.
	var s: float = clampf(minf(size.x, minf(size.y, size.z)) * 0.20, 0.04, 0.13)
	_piece = Vector3(s, s, s)
	var bm := BoxMesh.new()
	bm.size = _piece
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = bm
	mm.instance_count = amount
	multimesh = mm
	material_override = _material()
	cast_shadow = SHADOW_CASTING_SETTING_OFF   # шматок живе секунду, тінь від нього не читається

	_data.resize(amount * STRIDE)
	for i in range(amount):
		var o := i * STRIDE
		# старт — випадкова точка всередині предмета
		_data[o + 0] = rng.randf_range(-0.5, 0.5) * size.x
		_data[o + 1] = rng.randf_range(-0.5, 0.5) * size.y
		_data[o + 2] = rng.randf_range(-0.5, 0.5) * size.z
		# летить назовні від центра, вгору й ТРОХИ вперед: удар прийшов спереду
		var dir := Vector3(_data[o + 0], 0.0, _data[o + 2])
		dir = dir.normalized() if dir.length() > 0.001 else Vector3(rng.randf_range(-1.0, 1.0), 0.0, 0.0).normalized()
		# Швидкість підібрана так, щоб шматки лишались У КАДРІ: перша спроба (до 3,4 м/с убік
		# і 4,6 вгору) розкидала їх за межі екрана за чверть секунди, і розбиття читалось як
		# «предмет зник», а не «розлетівся».
		var speed := rng.randf_range(0.8, 1.9)
		_data[o + 3] = dir.x * speed
		_data[o + 4] = rng.randf_range(1.3, 2.7)
		_data[o + 5] = dir.z * speed + rng.randf_range(0.2, 0.9)
		var axis := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)).normalized()
		_data[o + 6] = axis.x
		_data[o + 7] = axis.y
		_data[o + 8] = axis.z
		_data[o + 9] = rng.randf_range(0.0, TAU)
		_data[o + 10] = rng.randf_range(-9.0, 9.0)
		# відтінок на шматок: суцільний однаковий колір читається як одна пляма
		var k := rng.randf_range(-0.12, 0.12)
		mm.set_instance_color(i, color.lightened(k) if k > 0.0 else color.darkened(-k))
	_sync()


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE_SEC:
		queue_free()
		return
	_sync()


## Де шматок i у момент t. Окремим методом, бо перевірити через сам MultiMesh НЕ МОЖНА:
## у headless рендер-сервер — заглушка, і get_instance_transform() віддає нулі, хоч запис
## пройшов. Тест, який читав би буфер, мовчки перевіряв би порожнечу.
func piece_position(i: int, t: float) -> Vector3:
	var o := i * STRIDE
	return piece_at(Vector3(_data[o + 0], _data[o + 1], _data[o + 2]),
		Vector3(_data[o + 3], _data[o + 4], _data[o + 5]), t, _ground_y)


## Скільки від шматка лишилось: останню чверть життя він стискається в нуль.
func piece_scale(t: float) -> float:
	if t <= LIFE_SEC * FADE_FROM:
		return 1.0
	return clampf(1.0 - (t - LIFE_SEC * FADE_FROM) / (LIFE_SEC * (1.0 - FADE_FROM)), 0.0, 1.0)


func _sync() -> void:
	var mm := multimesh
	if mm == null:
		return
	var shrink := piece_scale(_t)
	for i in range(mm.instance_count):
		var o := i * STRIDE
		var basis := Basis(Vector3(_data[o + 6], _data[o + 7], _data[o + 8]),
			_data[o + 9] + _data[o + 10] * _t)
		mm.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * shrink),
			piece_position(i, _t)))


## Матеріал один на всі вибухи: колір бере з інстанса, не з матеріалу, тож різні предмети
## розсипаються по-своєму без зайвих матеріалів.
static func _material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Palette.WHITE
		_mat.roughness = 1.0
		_mat.vertex_color_use_as_albedo = true
	return _mat
