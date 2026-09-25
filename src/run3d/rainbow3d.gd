## Веселка-портал на одній доріжці: пробіг крізь неї — політ і дуга зірочок; не хочеш — оминаєш.
## Їде зі світом (дитина Spawner3D), спрацьовує в Spawner3D.check().
##
## ЦІНА ПОЯВИ. Кільця — ЛІТ-матеріал з емісією, НЕПРОЗОРИЙ. Такого набору властивостей більше
## ніде в грі нема (щит FX._shield_mat прозорий — це інший варіант шейдера), тож першу веселку
## в сесії рушій зустрічав некомпільованим шейдером і компілював його просто в кадрі появи:
## заміряно на Маку в Compatibility 144–464 мс одним кадром (контроль без веселки — 19–24).
## Лікується прогрівом на відліку рівня (preheat нижче, кличе Run3D), а не спрощенням вигляду.
## Сталої ціни, поки веселка на екрані, нема: +0,5 мс, у межах шуму.
class_name Rainbow3D
extends Node3D

const COLORS := Palette.RAINBOW
const RADIUS := 1.15
## Скільки тримати прогрівальну веселку в кадрі. Та сама межа, що й у частинок: рушій
## компілює шейдер, коли вперше МАЛЮЄ, тож досить кількох кадрів.
const PREHEAT_SEC := FX.PREHEAT_SEC

## Матеріали й сітки кілець — спільні на всі веселки сесії. Раніше кожна веселка створювала
## шість нових матеріалів і шість торів; шейдер від цього не компілювався вдруге, але
## ресурси й завантаження в GPU — щоразу заново.
static var _mats: Array[StandardMaterial3D] = []
static var _meshes: Array[TorusMesh] = []

var lane := 0
var used := false


## Матеріал кільця i. Набір властивостей (літ + емісія, непрозорий) — саме той, що прогріває
## preheat(): інший набір дав би інший варіант шейдера, і прогрів грів би не те.
static func ring_material(i: int) -> StandardMaterial3D:
	if _mats.size() != COLORS.size():
		_mats.clear()
		for c in COLORS:
			var m := StandardMaterial3D.new()
			m.albedo_color = c
			m.roughness = 0.9
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 0.3
			_mats.append(m)
	return _mats[i]


static func ring_mesh(i: int) -> TorusMesh:
	if _meshes.size() != COLORS.size():
		_meshes.clear()
		var r := RADIUS
		for _k in range(COLORS.size()):
			var t := TorusMesh.new()
			t.inner_radius = r - 0.09
			t.outer_radius = r
			t.rings = 40
			t.ring_segments = 8
			_meshes.append(t)
			r -= 0.1
	return _meshes[i]


## Прогріти шейдер кілець ЗАЗДАЛЕГІДЬ — справжньою веселкою, крихітною й у кадрі (поза кадром
## рушій її не малює, а отже й не компілює). Прибирає себе сама за PREHEAT_SEC. Таймер
## під'єднано МЕТОДОМ самого вузла, а не лямбдою: звільнять вузол раніше — зв'язок зникне з ним.
static func preheat(host: Node3D, at: Vector3 = Vector3.ZERO) -> Node3D:
	if host == null or not host.is_inside_tree():
		return null
	var probe := Node3D.new()
	probe.name = "RainbowPreheat"
	probe.position = at
	probe.scale = Vector3.ONE * 0.002      # видимі рушієві, невидимі гравцеві
	host.add_child(probe)
	probe.add_child(Rainbow3D.new())
	host.get_tree().create_timer(PREHEAT_SEC).timeout.connect(probe.queue_free)
	return probe


func _ready() -> void:
	for i in range(COLORS.size()):
		var mi := MeshInstance3D.new()
		mi.mesh = ring_mesh(i)
		mi.material_override = ring_material(i)
		mi.rotation.x = PI * 0.5   # вертикальне кільце поперек дороги
		mi.position.y = RADIUS * 0.55
		add_child(mi)
	FX.sparkles(self, 0.9, 16).position.y = RADIUS * 0.55
	scale = Vector3(0.01, 0.01, 0.01)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	rotation.z += delta * 0.6   # повільно крутиться — «магічне» кільце
