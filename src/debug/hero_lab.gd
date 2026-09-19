## Лабораторія обличчя: герой + повзунки, якими посадка обличчя підбирається НАЖИВО, і
## кнопка, що зберігає підібране назад у data/heroes.json. У грі не використовується.
##
## Навіщо. Обличчя (очі, щічки, ніс, рот) малюється кодом поверх Meshy-моделі, а її коробка
## голови в кожного героя перекошена по-своєму — тож числа посадки однаково доводиться
## підбирати вручну для кожного. Раніше це був цикл «правка в json → запуск → скріншот», по
## хвилині на кожен крок. Тут те саме робиться повзунком за секунду.
##
## Запуск: godot res://src/debug/hero_lab.tscn (або F6 у редакторі на цій сцені).
## RIG=<ім'я моделі> godot res://src/debug/hero_lab.tscn — приміряти ІНШУ модель на того
## самого героя (напр. RIG=fox_meshy_clear). У heroes.json підміна не потрапляє: кнопка
## «Зберегти» пише лише rig_face.
## Мишею тягнути — обертати, колесо — наблизити, P — заморозити анімацію, 1..9 — стани
## (7 — танець і 8 — привітання йдуть як у грі, зі своїм виразом обличчя, решта — застигла поза),
## B — кліпнути раз (вид і швидкість випадкові, як у грі), N — підморгнути одним оком,
## J — кліпнути по черзі, G — перевести погляд убік (видно, як зіниці й блики йдуть за ним),
## H — щасливий вираз (сплюснуті очі + усмішка) на 1.5 с.
## Рот (лише там, де є rig_face.mouth_scene): M — відкрити/закрити, C — жувати,
## L — облизнутись, E — з'їсти, U — реакція на удар (рот «О» + великі очі).
##
## Чому не @tool-сцена з Інспектором: Hero3D/HeroRig тягнуть за собою автозавантаження
## (звук, вік, крамниця), яких у редакторі просто нема, — довелось би позначати @tool пів
## проєкту й ловити побічні ефекти в самому редакторі. Запущена сцена дає ту саму миттєву
## картинку без цього ризику.
extends Node3D

const JSON_PATH := "res://data/heroes.json"
const EYE_DIR := "res://src/run3d/eye"
## Вендорні пресети ока (поза src/, свої правила кольору) — на пробі, окремим списком, щоб
## і не сканувати weird директорію, і щоб пікер не мовчки «губив» вибір, показуючи не те.
const VENDOR_EYES := [
	"res://vendor/cartoon_eye/ShaderEye.tscn",
	"res://vendor/cartoon_eye_3d/CartoonEye3D.tscn",
]

## Повзунки: ключ у rig_face → [підпис, мін, макс, крок]. eye_size — це список [x, y, z]
## у json, тож три його осі живуть тут окремими ключами (див. _read/_write).
const KNOBS := [
	["x", "обличчя ← →", -0.6, 0.6, 0.005],
	["y", "обличчя ↑ ↓ (коробка)", -1.0, 3.0, 0.01],
	["z", "обличчя вперед/вглиб", -1.0, 1.0, 0.01],
	["scale", "масштаб обличчя", 0.2, 2.0, 0.01],
	["eye_spread", "розліт очей", 0.5, 5.0, 0.01],
	["eye_y", "очі ↑ ↓", -0.6, 0.6, 0.002],
	["eye_z", "очі вглиб черепа", -0.5, 0.5, 0.005],
	["eye_yaw", "очі: розворот назовні°", -90.0, 90.0, 1.0],
	["eye_size_x", "око: ширина", 0.5, 4.0, 0.01],
	["eye_size_y", "око: висота", 0.5, 4.0, 0.01],
	["eye_size_z", "око: опуклість", 0.5, 4.0, 0.01],
	["iris", "райдужка", 0.3, 1.2, 0.01],
	["cheek_y", "щічки нижче очей", 0.0, 0.5, 0.005],
	["mouth_y", "рот ↑ ↓", -0.4, 0.4, 0.005],
	["mouth_z", "рот вперед/вглиб", -0.4, 0.2, 0.005],
	["mouth_size", "рот: розмір", 0.3, 3.0, 0.05],
]

var _hero: Hero3D
var _camera: Camera3D
var _ids: Array = []
var _id := ""
var _sliders := {}
var _status: Label
## Стартовий ракурс — МОРДА (камера перед героєм): лабораторія існує заради обличчя, а з
## PI вона відкривалась потилицею, і першим рухом щоразу був розворот.
var _orbit := Vector2(0.0, 0.0)
var _dist := 1.15
var _dragging := false
## Стан показу, який ПЕРЕЖИВАЄ перебудову: кожен рух повзунка збирає героя наново, і без
## цього кожна правка скидала б і заморозку, і вибраний стан анімації — картинка стрибала б,
## і порівняти «до/після» було б неможливо.
var _frozen := false
var _pose := -1
var _spins := {}
var _eye_picker: OptionButton
var _mouth_open := false
var _gaze_side := 0.0


func _ready() -> void:
	# сама лабораторія та її панель мають жити й на паузі (P морозить УСЕ дерево — див.
	# _apply_view_state), інакше після заморозки не працювали б ні повзунки, ні клавіші
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_world()
	_ids = HeroSelect.order_ids(Hero3D.defs())
	_id = String(_ids[0]) if not _ids.is_empty() else "lys"
	_build_ui()
	_spawn_hero()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.608, 0.867, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.93, 1.0)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, -0.6, 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 45.0
	add_child(_camera)
	_camera.current = true
	_place_camera()


## Камера дивиться на ГОЛОВУ (обличчя — те, що підбираємо), а не на всього героя.
func _place_camera() -> void:
	var target := Vector3(0.0, 0.62, 0.0)
	var dir := Vector3(
		sin(_orbit.y) * cos(_orbit.x),
		sin(_orbit.x),
		cos(_orbit.y) * cos(_orbit.x))
	_camera.position = target + dir * _dist
	_camera.look_at(target, Vector3.UP)


func _spawn_hero() -> void:
	if is_instance_valid(_hero):
		_hero.queue_free()
	_hero = Hero3D.new()
	# сама лабораторія — ALWAYS (щоб панель і клавіші жили на паузі), але герой має паузу
	# СЛУХАТИСЬ, інакше він успадкує ALWAYS від батька й морозитись не буде
	_hero.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_hero)
	var tried := RigTry.apply(_id)     # RIG=<модель> — приміряти чужу модель (див. rig_try.gd)
	var def := Hero3D.resolve_def(Hero3D.defs(), _id)
	_hero.set_hero(_id, Palette.of(def.get("color"), Palette.HERO_DEFAULT),
		String(def.get("feature", "fox")))
	if tried != "" and _status != null:
		_status.text = tried
	_hero.ground_y = 0.0
	_hero.x_target = 0.0
	_hero.set_running(true)
	_hero.rotation.y = PI
	_apply_view_state()


## Повертає героєві той самий вигляд, що був до перебудови (див. _frozen/_pose).
## Заморозка тут СИЛЬНІША за rig.frozen: та спиняє лише кістки, а тіло однаково погойдується
## (бобінг, твіни кліпання) — два кадри поспіль виходили різними. Тому морозимо ВСЕ дерево.
func _apply_view_state() -> void:
	if not is_instance_valid(_hero):
		return
	get_tree().paused = false
	if _pose >= 0:
		_hero.preview_pose(_pose as Hero3D.Anim)
	if _hero.rig() != null:
		_hero.rig().frozen = _frozen
	if not _frozen:
		return
	# Пара кадрів «усадки» потрібна: щойно зібраний риг стоїть у сирій позі прив'язки, поза
	# лягає лише наступним кадром. Але за ці кадри встигають зрушити годинники ходи — і ноги
	# виходили різними до і після правки повзунка. Тому обнуляємо їх (так, це внутрішні поля
	# Hero3D — лабораторії можна, вона й існує, щоб зазирати всередину).
	_hero._t = 0.0
	_hero._gait_phase = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_hero):
		_hero._t = 0.0
		_hero._gait_phase = 0.0
	get_tree().paused = true


## Значення ключа з rig_face поточного героя (з дефолтом, який використовує Hero3D).
func _read(key: String) -> float:
	var cfg: Dictionary = _face_cfg()
	match key:
		"eye_size_x", "eye_size_y", "eye_size_z":
			var es = cfg.get("eye_size", 1.0)
			var axis := ["eye_size_x", "eye_size_y", "eye_size_z"].find(key)
			if typeof(es) == TYPE_ARRAY and (es as Array).size() >= 3:
				return float(es[axis])
			return float(es)
		"scale": return float(cfg.get("scale", 1.0))
		"y": return float(cfg.get("y", 0.65))
		"iris": return float(cfg.get("iris", 1.0))
		"eye_spread": return float(cfg.get("eye_spread", 1.0))
		"eye_y": return float(cfg.get("eye_y", 0.225))
		"cheek_y": return float(cfg.get("cheek_y", 0.105))
		"mouth_size": return float(cfg.get("mouth_size", 1.0))
	return float(cfg.get(key, 0.0))


func _write(key: String, value: float) -> void:
	var cfg: Dictionary = _face_cfg()
	if key.begins_with("eye_size_"):
		var axis := ["eye_size_x", "eye_size_y", "eye_size_z"].find(key)
		var es = cfg.get("eye_size", 1.0)
		var arr := [1.0, 1.0, 1.0]
		if typeof(es) == TYPE_ARRAY and (es as Array).size() >= 3:
			arr = [float(es[0]), float(es[1]), float(es[2])]
		elif typeof(es) != TYPE_ARRAY:
			arr = [float(es), float(es), float(es)]
		arr[axis] = value
		cfg["eye_size"] = arr
	else:
		cfg[key] = value


## rig_face поточного героя ПРЯМО в кеші Hero3D.defs() — правки одразу видно на перебудові,
## у файл нічого не пишемо, поки не натиснуто «Зберегти».
func _face_cfg() -> Dictionary:
	var all := Hero3D.defs()
	var def: Dictionary = all.get(_id, {})
	var cfg = def.get("rig_face", {})
	if typeof(cfg) != TYPE_DICTIONARY:
		cfg = {}
	def["rig_face"] = cfg
	return cfg


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -560
	panel.offset_right = -12
	panel.offset_top = 12
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var picker := OptionButton.new()
	for id in _ids:
		picker.add_item(String(Hero3D.defs().get(id, {}).get("name_uk", id)))
	picker.item_selected.connect(func(i: int):
		_id = String(_ids[i])
		_spawn_hero()
		_refresh_sliders())
	box.add_child(picker)

	# пресет ока: та сама CartoonEye з іншими типовими значеннями — беремо найближчий і далі
	# доводимо повзунками (рівно той порядок, що й задумувався для нових звірят)
	var eyes := _eye_presets()
	var eye_picker := OptionButton.new()
	for path in eyes:
		eye_picker.add_item(path.get_file().get_basename())
	eye_picker.item_selected.connect(func(i: int):
		_face_cfg()["eye_scene"] = eyes[i]
		_spawn_hero())
	var current := String(_face_cfg().get("eye_scene", CartoonEye.BASE_SCENE))
	if eyes.has(current):
		eye_picker.select(eyes.find(current))
	box.add_child(eye_picker)
	_eye_picker = eye_picker

	for k in KNOBS:
		var key := String(k[0])
		var row := HBoxContainer.new()
		box.add_child(row)
		var name_label := Label.new()
		name_label.text = String(k[1])
		name_label.custom_minimum_size.x = 200
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = float(k[2])
		slider.max_value = float(k[3])
		slider.step = float(k[4])
		slider.custom_minimum_size.x = 170
		slider.value = _read(key)
		slider.value_changed.connect(func(v: float): _on_knob(key, v))
		row.add_child(slider)
		var spin := SpinBox.new()
		spin.min_value = float(k[2])
		spin.max_value = float(k[3])
		spin.step = float(k[4])
		spin.custom_minimum_size.x = 110
		spin.value = slider.value
		spin.value_changed.connect(func(v: float): _on_knob(key, v))
		row.add_child(spin)
		_sliders[key] = slider
		_spins[key] = spin

	var save := Button.new()
	save.text = "Зберегти в heroes.json"
	save.pressed.connect(_save)
	box.add_child(save)
	_status = Label.new()
	_status.text = "миша/колесо — огляд · P — стоп-кадр · 1..9 — стани · B блимнути · H щастя" \
		+ " · M рот · C жувати · L облизнутись · E їсти · U удар"
	box.add_child(_status)


## Усі сцени ока з src/run3d/eye — базова плюс пресети.
func _eye_presets() -> Array:
	var out := []
	var dir := DirAccess.open(EYE_DIR)
	if dir == null:
		out = [CartoonEye.BASE_SCENE]
	else:
		for f in dir.get_files():
			if f.ends_with(".tscn"):
				out.append("%s/%s" % [EYE_DIR, f])
		out.sort()
	# вендорні (поза src/, на пробі) — окремим блоком у кінці, щоб пікер не «губив» вибір і
	# не показував випадково перший зі свого списку (VENDOR_EYES — не CartoonEye, скидати
	# на них rig_face-множники в _build_face() не можна)
	for path in VENDOR_EYES:
		if ResourceLoader.exists(path):
			out.append(path)
	return out


func _refresh_sliders() -> void:
	for key in _sliders.keys():
		var v := _read(String(key))
		(_sliders[key] as HSlider).set_value_no_signal(v)
		(_spins[key] as SpinBox).set_value_no_signal(v)
	if _eye_picker != null:
		var eyes := _eye_presets()
		var cur := String(_face_cfg().get("eye_scene", CartoonEye.BASE_SCENE))
		if eyes.has(cur):
			_eye_picker.select(eyes.find(cur))


## Повзунок і поле з числом — два види на одне значення: те, що рухали, лишаємо як є, друге
## доганяємо БЕЗ сигналу (інакше вони будили б одне одного по колу).
func _on_knob(key: String, value: float) -> void:
	_write(key, value)
	(_sliders[key] as HSlider).set_value_no_signal(value)
	(_spins[key] as SpinBox).set_value_no_signal(value)
	_spawn_hero()


## Переписує РІВНО блок "rig_face" цього героя, не чіпаючи решту файлу: heroes.json
## вручну вирівняний і має пояснювальні "_note", а повний перезапис через JSON.stringify
## розсипав би це форматування.
func _save() -> void:
	var f := FileAccess.open(JSON_PATH, FileAccess.READ)
	if f == null:
		_status.text = "не вдалось прочитати heroes.json"
		return
	var text := f.get_as_text()
	f.close()
	var re := RegEx.new()
	re.compile('("%s"[\\s\\S]*?)"rig_face": \\{[^}]*\\}' % _id)
	var m := re.search(text)
	if m == null:
		_status.text = "у %s нема поля rig_face — додай його руками один раз" % _id
		return
	var parts := PackedStringArray()
	for key in _face_cfg().keys():
		var v = _face_cfg()[key]
		if typeof(v) == TYPE_ARRAY:
			var nums := PackedStringArray()
			for n in (v as Array):
				nums.append("%.3f" % float(n))
			parts.append('"%s": [%s]' % [key, ", ".join(nums)])
		elif typeof(v) == TYPE_STRING:
			parts.append('"%s": "%s"' % [key, v])
		else:
			parts.append('"%s": %.3f' % [key, float(v)])
	var block := '"rig_face": {%s}' % ", ".join(parts)
	text = text.substr(0, m.get_start()) + m.get_string(1) + block + text.substr(m.get_end())
	var w := FileAccess.open(JSON_PATH, FileAccess.WRITE)
	if w == null:
		_status.text = "heroes.json не відкрився на запис"
		return
	w.store_string(text)
	w.close()
	_status.text = "збережено: %s" % block


## Миша — тільки те, що НЕ з'їла панель (щоб тягання повзунка не крутило камеру).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(0.35, _dist - 0.06)
			_place_camera()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(4.0, _dist + 0.06)
			_place_camera()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_orbit.y -= mm.relative.x * 0.008
		_orbit.x = clampf(_orbit.x + mm.relative.y * 0.008, -1.3, 1.3)
		_place_camera()


## Клавіші ловимо в _input, а не в _unhandled_input: щойно клацнеш повзунок, фокус лишається
## на панелі, і до _unhandled_input клавіші вже не доходять — P і цифри мовчали б саме тоді,
## коли вони потрібні (одразу після правки). Поле з числом при цьому не чіпаємо: поки курсор
## у ньому, клавіші — це набір числа.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var k := event as InputEventKey
	if k.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif k.keycode == KEY_P:
		_frozen = not _frozen
		_apply_view_state()
		_status.text = "кістки %s" % ("заморожені" if _frozen else "анімуються")
	elif k.keycode >= KEY_1 and k.keycode <= KEY_9:
		var picked: Hero3D.Anim = ([Hero3D.Anim.IDLE, Hero3D.Anim.RUN, Hero3D.Anim.SPRINT,
			Hero3D.Anim.LIMP, Hero3D.Anim.ROCKET, Hero3D.Anim.CHARGE, Hero3D.Anim.DANCE,
			Hero3D.Anim.WAVE, Hero3D.Anim.HIT] as Array)[k.keycode - KEY_1]
		# Танець і привітання вмикаються НЕ станом, а власним методом: у них свій таймер і
		# свій вираз обличчя. Через preview_pose() Hero3D вважає це «лише позою» (_pose_only)
		# і навмисно пропускає радість — тіло виляло, а морда лишалась нейтральною, тобто
		# найцікавішого в лабораторії було не видно.
		if is_instance_valid(_hero) and picked == Hero3D.Anim.DANCE:
			_pose = -1
			_hero.dance()
			_status.text = "танець (зі щасливим обличчям, %.0f с)" % Hero3D.DANCE_SEC
		elif is_instance_valid(_hero) and picked == Hero3D.Anim.WAVE:
			_pose = -1
			_hero.wave_hello()
			_status.text = "привітання (стійка дибки)"
		else:
			_pose = picked
			_apply_view_state()
	elif k.keycode == KEY_B:
		# кліпання й так спрацьовує само (кожні 2.2–5с у Hero3D._process) — це для того, щоб
		# не чекати навмання, а побачити його ЗАРАЗ, на щойно підібраному оці
		if is_instance_valid(_hero):
			_hero.call("_blink")
	elif k.keycode == KEY_N:
		if is_instance_valid(_hero):
			_hero.call("_blink", Hero3D.BlinkKind.WINK, 1.0)
			_status.text = "підморгування"
	elif k.keycode == KEY_J:
		if is_instance_valid(_hero):
			_hero.call("_blink", Hero3D.BlinkKind.SEQUENCE, 1.0)
			_status.text = "кліпання по черзі"
	elif k.keycode == KEY_G:
		# погляд убік просимо не напряму, а так само, як у грі: герой переїжджає на іншу
		# доріжку, і Hero3D сам веде очі за рухом. Напряму виставлений погляд однаково
		# стерло б його ж _process наступного кадру.
		if is_instance_valid(_hero):
			_gaze_side = -1.0 if _gaze_side >= 0.0 else 1.0
			_hero.x_target = _gaze_side * 0.9
			_status.text = "погляд %s" % ("ліворуч" if _gaze_side < 0.0 else "праворуч")
	elif k.keycode == KEY_H:
		if is_instance_valid(_hero):
			_hero.call("_happy", 1.5)
	elif k.keycode == KEY_M:
		# рот: відкрити/закрити. Сам по собі він у грі відкривається лише на ударі, тож без
		# цієї клавіші перевірити посадку рота в лабораторії не було б чим
		if is_instance_valid(_hero) and _hero._mouth3d != null:
			_mouth_open = not _mouth_open
			if _mouth_open:
				_hero._mouth3d.open()
			else:
				_hero._mouth3d.close()
			_status.text = "рот %s" % ("відкритий" if _mouth_open else "закритий")
	elif k.keycode == KEY_C:
		if is_instance_valid(_hero) and _hero._mouth3d != null:
			_hero._mouth3d.chew()
	elif k.keycode == KEY_L:
		if is_instance_valid(_hero) and _hero._mouth3d != null:
			_hero._mouth3d.lick()
	elif k.keycode == KEY_E:
		if is_instance_valid(_hero) and _hero._mouth3d != null:
			_hero._mouth3d.eat()
	elif k.keycode == KEY_U:
		# удар — саме та реакція, де рот робить «О», а очі більшають
		if is_instance_valid(_hero):
			_hero.hit_reaction(0)

