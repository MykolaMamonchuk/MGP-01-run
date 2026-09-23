## Друг-пухнастик: біжить поруч, займає сусідню доріжку із запізненням, стрибає разом, потім тікає вперед.
## На дорозі він ЗАВЖДИ ОДИН і не частіше ніж раз на EventSpawner.FRIEND_COOLDOWN — сторожі там.
## Тіло друга — ДЕШЕВІ ВОКСЕЛІ, а не скелетна модель: id "friend" у heroes.json нема, тож
## Hero3D.resolve_def дає порожній опис → частини за замовчуванням (Hero3D.DEFAULT_PARTS)
## і жодного .glb. Не додавати "friend" у heroes.json з полем "rig": кожен друг тягнув би
## за собою цілу модель зі скелетом.
class_name Friend3D
extends Node3D

## ТІЛО БУДУЄТЬСЯ ОДИН РАЗ, а не на кожну появу.
##
## Замовник бачив ривок саме тоді, коли друг вибігає. Заміряно годинником на Redmi 8A:
## створення друга коштує 368 і 325 мс — тобто шість-сім кадрів роботи в ОДНОМУ кадрі, і
## так щоразу, а не лише вперше. Причина не в шейдерах, а в самій побудові: Hero3D.new()
## плюс set_hero() — це вокселі, меші й матеріали.
##
## Тому друг тепер живе весь рівень: після відбігання він ХОВАЄТЬСЯ, а не звільняється, і
## наступна поява — це показати й переставити. Будується він у EventSpawner.configure(),
## тобто на старті рівня, де ривок припадає на відлік, а не на біг.
var hero: Hero3D
var _puppet: Hero3D
var _target_x := 0.0
var _delay := 0.0
var _leaving := false
var _t := 0.0
var _left := 0.0                ## скільки секунд ще бігти поруч
var _active := false
var _built_color := Color(0, 0, 0, 0)
var _built_feat := ""


## Побудувати тіло. Дорого (сотні мілісекунд) — кличеться раз на рівень, поза бігом.
func prepare(h: Hero3D, friend_color: Color, feat: String = "ears") -> void:
	hero = h
	if _puppet == null:
		_puppet = Hero3D.new()
		add_child(_puppet)
	if friend_color != _built_color or feat != _built_feat:
		_puppet.set_hero("friend", friend_color, feat)
		_built_color = friend_color
		_built_feat = feat
	_puppet.scale = Vector3.ONE * 0.85
	if not hero.landed.is_connected(_on_hero_landed):
		hero.landed.connect(_on_hero_landed)
	_hide()


## Показати вже готового друга. Дешево: жодної геометрії тут не створюється.
func activate(seconds: float) -> void:
	_active = true
	_leaving = false
	_t = 0.0
	_delay = 0.0
	_left = seconds
	visible = true
	set_process(true)
	_puppet.set_running(true)
	position = Vector3(hero.position.x + (1.0 if hero.position.x <= 0.0 else -1.0), 0.0, -0.9)
	_target_x = position.x


func is_active() -> bool:
	return _active


func _hide() -> void:
	_active = false
	_leaving = false
	visible = false
	set_process(false)
	position = Vector3(0.0, 0.0, -0.9)


## Сумісність зі старим викликом: збудувати й одразу показати.
func setup(h: Hero3D, friend_color: Color, seconds: float, feat: String = "ears") -> void:
	prepare(h, friend_color, feat)
	activate(seconds)


func _on_hero_landed() -> void:
	if _active and is_instance_valid(_puppet) and not _leaving:
		get_tree().create_timer(0.15).timeout.connect(func():
			if is_instance_valid(_puppet):
				_puppet.jump(0.7))


func _process(delta: float) -> void:
	_t += delta
	_delay += delta
	# Час життя рахуємо тут, а не таймером сцени: таймер від ПОПЕРЕДНЬОЇ появи спрацював би
	# посеред наступної й відправив би друга тікати одразу після виходу.
	if not _leaving:
		_left -= delta
		if _left <= 0.0:
			_leaving = true
	if _delay > 0.3:
		_delay = 0.0
		var side := 1.0 if hero.position.x <= 0.0 else -1.0
		var lim := float(hero.max_lane()) * Hero3D.LANE_W
		_target_x = clampf(hero.position.x + side, -lim, lim)
	position.x = lerpf(position.x, _target_x, minf(1.0, delta * 8.0))
	if _leaving:
		position.z -= delta * 6.0
		if position.z < -30.0:
			# НЕ queue_free(): тіло лишається готовим до наступної появи. Зв'язок із героєм
			# теж лишається — його розриває лише вихід зі сцени.
			_hide()
