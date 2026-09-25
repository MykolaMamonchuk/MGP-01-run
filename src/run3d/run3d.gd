## Головна сцена (3D). Стани (GDD v1.4 §10): MENU → HOME (дім-діорама) → COUNTDOWN → RUN → FINISH → HOME …;
## HEROES і MAP — з меню; PAUSED — кругла кнопка паузи; SLEEP по таймеру.
## Гра без програшу: серця не перезапускають рівень (стан RESTART прибрано) — на нулі сердець прилітає
## сорока й краде половину злитків рівня, далі кожен удар коштує −10%; зірки фінішу = серця, що лишились.
## Оркеструє рівні (LevelManager), біом і його режим руху (v1.3: усі світи біжать), жести (свайпи/стрілки/джойстик),
## туторіал, міні-події, пікапи, мінізавдання, живе небо/сезон, ефекти. Герой стоїть у (0,0,0), світ їде на нього.
extends Node3D

enum State { MENU, HOME, MAP, HEROES, COUNTDOWN, RUN, FINISH, PAUSED, SLEEP }

const WORLD_SWITCH_SEC := 0.9
const MENU_SPEED := 1.1
const STICK_REARM_PX := 26.0
const TUTORIAL_LEAD_SEC := 1.7
const TUTORIAL_SLOW := 0.6
const FINISH_AUTO_NEXT_SEC := 7.0
## Швидкість: v = base × level.speed_mult × (1 + 0.35 × прогрес); останні 20% рівня — спринт ×1.15;
## ворота фінішу з'являються за 6 с до кінця.
const SPEED_RAMP := 0.35
const SPRINT_FROM := 0.8
const SPRINT_MULT := 1.15
const GATE_BEFORE_SEC := 6.0
## Туман по глибині: до FOG_NEAR_M його нема зовсім, на FOG_FAR_M він суцільний.
## FOG_FAR_M трохи ближче за найдальший ряд траси (Track.BEHIND + Track.ROWS = 42,6 м від
## камери), щоб кінець дороги ховався ЩЕ до того, як його видно.
const FOG_NEAR_M := 20.0
const FOG_FAR_M := 40.0
const FOG_CURVE := 1.0
const DEFAULT_FOG := 0.012
## Межі, у які вкладається початок туману: ближче за 6 м світ став би молочним під ногами,
## далі за 30 м кінець дороги не встиг би розчинитись.
const FOG_BEGIN_RANGE := [6.0, 30.0]
## Блум (GDD v1.5 §3) — саме «м'який»: поріг ВИЩЕ за білий, мала інтенсивність.
## v2: блум був головною причиною «вицвілого» меню — світлі шерстинки героя цвіли
## й з'їдали насиченість. Тепер цвіте лише те, що яскравіше за 1.1.
const GLOW_INTENSITY := 0.18
const GLOW_BLOOM := 0.1
const GLOW_THRESHOLD := 1.1
## Кольорокорекція (v2): трохи насиченості й контрасту — воксельні кольори звучать як в арт-базі.
const ADJ_SATURATION := 1.15
const ADJ_CONTRAST := 1.05
## Сонце 1.1 (run3d.tscn) + амбієнт 0.55: разом середні тони не перевищують 1.0 і не пересвічуються.
const AMBIENT_ENERGY := 0.35
## Тепле навколишнє світло до того, як світ скаже своє. Те саме число, що в run3d.tscn;
## тримаємо його ТУТ, бо декор відтворює навколишнє світло випроміненням і мусить брати
## його з одного джерела — інакше копії розійдуться мовчки, і це буде видно не як збій, а
## як «щось із кольором не так».
const AMBIENT_COLOR := Color(1, 0.96, 0.88)
## Compatibility (тобто ВЕБ-ЗБІРКА) на тих самих числах світить помітно яскравіше за
## мобільний рушій, і світлі поверхні обрізаються в чистий білий. Заміряно 20.09.2026 на
## рівні 2: чисто білих пікселів 0,19% на мобільному проти 3,66% у Compatibility — у
## дев'ятнадцять разів більше. На клiпінгу зникає колір і будь-яка дрібна нерівність
## текстури читається як брудна смуга; замовник це й прислав («тіні дивно мигають»).
##
## Це та сама вада, яку вже лікували числами 1.1/0.55 → 0.9/0.35 (див. коментар у _set_sky),
## тільки підбирали її на мобільному рушії. Множник підібрано тим самим способом — заміром,
## а не на око: шукали найменшу різницю з мобільним кадром за однакового зерна.
## Заміряно на рівні 2 з тим самим зерном (RESET=1 PROFILE=older GAME_SEED=7):
##
##     множник   середня яскравість   чисто білих
##     1.00            171.7             3.66%
##     0.85            163.1             1.61%
##     0.70            152.9             0.53%
##     0.55            140.1             0.23%     ← взято
##     мобільний       138.9             0.19%
##
## 0,55 сходиться з мобільним і за яскравістю (різниця 0,9%), і за клiпінгом. Менше робити
## нема сенсу: кадр почне темніти нижче за еталон.
const COMPAT_LIGHT := 0.55
## Сорока (GDD v1.4 §3): скидає X-ящик кожні 12–20 с, починаючи з 3-го рівня.
const MAGPIE_FROM_LEVEL := 3
const MAGPIE_DROP_INTERVAL := [12.0, 20.0]
## Скін антагоніста за світом, поки ключа "antagonist" нема в data/worlds: Місто — голуб, Хмаринки — кометка з очима.
const ANTAGONIST_BY_WORLD := {"city": "pigeon", "clouds": "comet"}
## Скільки триває «стікання» лічильника злитків, коли сорока вкрала.
const STEAL_TALLY_SEC := 1.0
## Скільки секунд після удару герой кульгає (GDD v1.6 §5, анімація limp).
const LIMP_AFTER_HIT_SEC := 3.0
## ─── суперсила героя (GDD v1.6 §3c) ───
## Стеля внеску ОДНОГО злитка в заряд суперсили (EDD §2): великий злиток не має
## заряджати кнопку сам по собі — сила є нагородою за гру, а не за одну монету.
const POWER_CHARGE_PER_PICKUP := 20
## «Хитрий стрибок»: у скільки разів вищий стрибок і множник злитків у повітрі / на ярусі.
const FOX_JUMP_SCALE := 1.45
const FOX_COIN_MULT := 2.0
## «Нюх-магніт»: у скільки разів більший радіус магніта.
const DOG_MAGNET := 3.0
## «Дев'ять життів»: стеля сердець на рівні.
const CAT_MAX_HEARTS := 5
## «Ведмежі обійми»: скільки ударів поглинає і на скільки множить злитки.
const BEAR_ABSORB := 2
const BEAR_COIN_MULT := 1.5
## «Райдужний міст»: скільки летять злитки й скільки триває невразливість.
const RAINBOW_PULL_SEC := 0.6
const RAINBOW_INVULN_SEC := 3.0
## «Хвиля-серфінг» (дельфін): злитки летять до героя, як у єдинорога, але БЕЗ невразливості
## й сліду — водний друг притягує монети, а не захищається (GDD v1.7 §5: «злитки з води»).
const DOLPHIN_PULL_SEC := 0.6
## «Панцир-щит» (черепаха): чисто оборонна сила — та сама механіка поглинання, що в ведмежати,
## але без множника злитків (GDD v1.7 §5: «Панцир-щит», повільна й захисна, не про золото).
const TURTLE_ABSORB := 2
## Скільки смуг у веселковому сліді (беремо кожен другий колір Palette.RAINBOW — на Mobile
## шість систем частинок задорого).
const RAINBOW_TRAIL_STEP := 2

@onready var hero: Hero3D = $Hero
@onready var track: Track = $Track
@onready var spawner: Spawner3D = $Spawner
@onready var actors: Node3D = $Actors
@onready var camera_rig: CameraRig = $CameraRig
## Туман завісами — дешева заміна Environment.fog (див. src/run3d/haze.gd).
var haze: Haze = null
@onready var hud: CanvasLayer = $HUD
@onready var env: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var events_spawner: EventSpawner = $EventSpawner
@onready var menu: MenuLayer = $Menu
@onready var hero_select: HeroSelect = $HeroSelect
@onready var map_screen: MapScreen = $Map
@onready var controls: ControlsLayer = $Controls
@onready var wheel: WheelLayer = $Wheel
@onready var ambient_root: Node3D = $Ambient
## Дім-діорама (інший агент, res://src/run3d/diorama.gd). Може бути відсутня — усі виклики під вартою.
@onready var diorama: Node3D = get_node_or_null("Diorama")

var state: State = State.MENU
var profiles: Dictionary = {}
var profile: Dictionary = {}
var worlds: Dictionary = {}
var world: Dictionary = {}
var world_id := ""
var mode: ModeBase
var season: Dictionary = {}
var heroes: Dictionary = {}
var lm := LevelManager.new()
var level: Dictionary = {}
var level_num := 1
var lanes := 3

var base_speed := 4.0
var speed := 4.0
var level_t := 0.0
var level_duration := 90.0
## Скільки метрів проїхала дорога від старту поточного рівня — єдине джерело правди для
## Track.distance_m/Spawner3D.distance_m (Phase 1 level-authoring plumbing): рахуємо тут один
## раз і передаємо той самий підсумок в обидва advance(), щоб лічильники не розійшлись.
var level_distance_m := 0.0
## Стрімить авторський рівень по чанках (levels/level_XX/chunk_NN.tscn) замість того, щоб
## вантажити весь level_XX.tscn одразу — див. LevelChunkLoader.
var _chunk_loader := LevelChunkLoader.new()
var session_t := 0.0
var session_total := 600.0
var switching := false
var quests := Quests.new()

## Множник світла цього рушія (див. COMPAT_LIGHT). Рахуємо раз: рушій посеред гри не
## міняється, а _set_sky кличеться щокадру.
var _light_k := 1.0
var _debug: DebugOverlay
var _ambient: GPUParticles3D
var _weather: GPUParticles3D
var _fireflies: GPUParticles3D
var _countdown_tw: Tween
var _lanes_changed := false
var _slow := 1.0
var _slow_t := 0.0
var _finish_auto_t := 0.0
var _pending_finish: Dictionary = {}
var _sprint_announced := false
var _gate_spawned := false
## Зірочки, зібрані на цьому рівні: у SaveService потрапляють лише на фініші (перезапуск їх не зберігає).
var level_coins := 0
## Активні пікапи: вид → секунд лишилось; равлик множить швидкість.
var _effects: Dictionary = {}
var _pickup_speed := 1.0
## Супернапій (пікап "potion"): окремий множник, щоб не сваритися з равликом.
var _potion_speed := 1.0
## Скільки ще кульгати після удару (GDD v1.6 §5).
var _limp_t := 0.0
## Множники героя (GDD v1.3 §5, stats.speed / stats.magnet) — виставляються на старті рівня.
var _hero_speed := 1.0
var _hero_magnet := 1.0
## ─── суперсила героя (GDD v1.6 §3c) ───
## Заряд 0..power_needed(); росте на кожен зібраний злиток, обнуляється на старті рівня й після сили.
var power_charge := 0
## Опис сили поточного героя з data/heroes.json ({} — герой без сили).
var power_def: Dictionary = {}
## id сили, що ДІЄ зараз ("" — жодна), скільки їй лишилось і скільки всього тривала.
var _power_id := ""
var _power_t := 0.0
var _power_dur := 0.0
## jump_scale, який стояв до сили (у Хмаринках режим ставить свій — не затираємо його).
var _power_jump_scale := 1.0
## Веселковий слід «Райдужного мосту» — знімається в кінці сили.
var _power_trails: Array[GPUParticles3D] = []
# v1.4: множник злитків, сорока, пауза
## Скільки перешкод пройдено без удару (ламається на кожному зіткненні).
var streak_no_hit := 0
## Показаний множник (з ×2) і «чистий» (без ×2) — злитки вже приходять помножені на coin_mult.
var _mult := 1
var _mult_base := 1
var magpie: Magpie3D
var _magpie_t := 0.0
## Світ, який зараз показує діорама. Окремо від world_id: той описує біом на ДОРОЗІ
## (за ним _start_level вирішує, чи перебудовувати трасу), і стрілки в домі його не чіпають.
var _home_world := ""
## Сорока вже вкрала на цьому рівні (далі удари коштують −10%).
var _stolen := false
## Стан, з якого поставили на паузу.
var _state_before_pause: State = State.RUN

# туторіал
var _learned: Dictionary = {}
var _tutorial_action := ""
var _tutorial_count: Dictionary = {}

# жести одного пальця
var _pressed := false
var _press_time := -1.0
var _press_pos := Vector2.ZERO
var _cur_pos := Vector2.ZERO
var _swiped := false
var _stick_used := false     # після першого відхилення джойстика відпускання/утримання вже не тап/присід
var _holding := false
var _idle_t := 0.0


## ДІАГНОСТИКА НА ПРИСТРОЇ: вимикати частини сцени прямо командним рядком.
##
## Навіщо саме так. На телефоні кадр 133 мс, і з них лише 18 — ЦП рендера; решта десь у
## конвеєрі, і з'ясувати це можна тільки дослідом «прибрали шматок — подивились». Кожен
## такий дослід через перезбірку APK коштує п'ять хвилин, а їх треба шість. Через командний
## рядок — секунди, і жодна збірка не відрізняється від іншої, тобто числа порівнянні.
##
##   adb shell am start -n <пакет>/com.godot.game.GodotAppLauncher \
##     --esa command_line_params "--strip=decor,shadows"
##
## Прапорці: decor (уся дрібниця й забудова), buildings (лише забудова), props (лише
## дрібниця), half (половина шарів забудови), shadows (прохід тіней), particles.
## Порожньо — нічого не чіпаємо, тобто звичайна гра.
## ДІАГНОСТИКА НА ПРИСТРОЇ: вимикати частини сцени й дивитись, що коштує кадр.
##
## Навіщо. На Redmi 8A кадр 133 мс, і з них лише 18 — ЦП рендера; решта десь у конвеєрі.
## З'ясувати це можна тільки дослідом «прибрали шматок — подивились», а кожен дослід через
## перезбірку APK коштує п'ять хвилин. Тому сцена розбирається НА ЛЬОТУ, а прогін по
## варіантах веде src/ui/strip_probe.gd — він сам міняє прапорці й сам друкує числа.
##
## Прапорці: decor (уся дрібниця й забудова), buildings (лише забудова), props (лише
## дрібниця), half (кожен другий шар забудови), shadows (прохід тіней), particles.
## Порожній список ПОВЕРТАЄ все на місце — без цього другий дослід міряв би наслідки першого.
var _strip_flags := PackedStringArray()
## Початковий стан ефектів — щоб повертати саме його, а не «увімкнено».
var _strip_orig := {}
## Спрайт хати для досліду `terramesh_sprite` — один на всі шари, див. _reapply_strip.
var _terra_sprite: Mesh = null
## Картки далеких хат для досліду `farcards`, за видом. Див. _far_card_mesh.
var _far_cards := {}
var _far_card_meta := {}


## Плоска картка далекої хати. Знімок покриває квадрат span_m, центр на висоті center_y_m;
## картку повертаємо на (card_yaw − 90°) ВСЕРЕДИНІ сітки, бо шар і далі ставить екземпляр
## під поворотом хати (90°), — тож разом виходить рівно той кут, під яким хату знімали.
func _far_card_mesh(kind: String) -> Mesh:
	if _far_cards.has(kind):
		return _far_cards[kind]
	if _far_card_meta.is_empty():
		var f := FileAccess.open("res://assets/props/_exp/cards/cards.json", FileAccess.READ)
		if f == null:
			return null
		_far_card_meta = JSON.parse_string(f.get_as_text())
	var m: Dictionary = _far_card_meta.get(kind, {})
	var tex := load("res://assets/props/_exp/cards/%s_L.png" % kind) as Texture2D
	if m.is_empty() or tex == null:
		_far_cards[kind] = null
		return null
	var span := float(m["span_m"])
	var q := QuadMesh.new()
	q.size = Vector2(span, span)
	q.center_offset = Vector3(0, float(m["center_y_m"]), 0)
	var arr := q.get_mesh_arrays()
	var rot := Basis(Vector3.UP, deg_to_rad(float(m["card_yaw_deg"]) - 90.0))
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for i in range(vs.size()):
		vs[i] = rot * vs[i]
		ns[i] = rot * ns[i]
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	arr[Mesh.ARRAY_TANGENT] = null
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://src/run3d/far_card.gdshader")
	sm.set_shader_parameter("tex", tex)
	am.surface_set_material(0, sm)
	_far_cards[kind] = am
	return am
## Таймер повтору досліду. Стоїть, поки досліду нема — див. debug_strip().
var _strip_timer: Timer = null
var _shared_mats := {}


## Ключі кеша досліду, що стосуються МАТЕРІАЛІВ декору (див. debug_strip).
##
## Префікси навмисно без двокрапки там, де ключ її не має: маркери звуться `nrm12` і
## `orm12_0` — за номером ШАРУ, а не матеріалу. З двокрапкою вони б не підпали під чистку,
## і цикл відновлення крутився б щосекунди ще довго ПІСЛЯ досліду, знову й знову знімаючи
## «оригінал» із уже виставленого трасою стану.
const _STRIP_MAT_KEYS := ["nrm", "shade:", "tf:", "cull:", "alb:", "spec:", "emis:", "orm"]

## Прапорці, якими дослід пише в матеріали декору САМ. Лише на них траса відступає; решта
## (зокрема `noemis`, який просто знімає оптимізацію) лишає керування трасі — інакше та
## перестала б стежити за лінивими шарами саме тоді, коли це найпотрібніше.
const _STRIP_MAT_FLAGS := ["unshaded", "pervertex", "unwalls", "nonormal", "nometal",
	"norough", "noao", "onemat", "onetex", "flat", "cullback", "nofilter", "nomip",
	"nospec", "noambient", "ambemis", "roadunlit", "roadvertex", "roadnoamb",
	"terrapixel", "allpixel"]


## ПОКИ ТРИВАЄ ДОСЛІД, МАТЕРІАЛАМИ ДЕКОРУ КЕРУЄ ВІН, а не траса. Інакше обидва пишуть у ті
## самі СПІЛЬНІ матеріали, і перемагає траса: `apply_decor_shading` кличеться зі зміни
## світла світу, тобто фактично щокадру, а дослід повторюється раз на секунду. Рецензія
## показала наслідок: усі варіанти серії закінчували в ОДНАКОВОМУ стані матеріалів, тобто
## проба міряла шум замість прапорців, і заодно поламались старі `unshaded` / `pervertex` /
## `unwalls`.
##
## І навпаки, коли дослід скінчився, вертати матеріали мусить НЕ кеш «як було», а стан
## якості. Кеш тут отруєний за побудовою: типовий стан — «Плавно», тож на момент його зняття
## траса вже поставила своє, і саме це запам'яталось як «оригінал». Це та сама пастка з
## memory bank, лише з іншого боку. Тому ключі матеріалів викидаємо — і просимо трасу
## розставити все наново.
func debug_strip(flags: PackedStringArray) -> void:
	_strip_flags = flags
	if track != null:
		# Чистка мусить іти ДО того, як траса розставлятиме: інакше цикл відновлення
		# перепише щойно виставлене отруєними значеннями.
		if flags.is_empty():
			for k in _strip_orig.keys():
				for pref in _STRIP_MAT_KEYS:
					if String(k).begins_with(pref):
						_strip_orig.erase(k)
						break
		var owns := false
		for f in flags:
			if _STRIP_MAT_FLAGS.has(String(f)):
				owns = true
				break
		track.set("strip_owns_decor_mats", owns)
		# `noemis` знімає САМУ оптимізацію — прапорці вміють лише забирати намальоване,
		# тож без окремого важеля її ціну не довести.
		track.set("force_ambient_emis", 0 if flags.has("noemis") else -1)
		track.apply_decor_shading()
	# Повтор потрібен, лише поки є що чіпати: під час досліду або поки вертаємо все на місце.
	if _strip_timer != null:
		if flags.is_empty() and _strip_orig.is_empty():
			_strip_timer.stop()
		else:
			_strip_timer.start()
	_reapply_strip()


## Шари декору заводяться ЛІНИВО, у міру того як дорога їде, тож застосовувати доводиться
## повторно: інакше сховане повернеться саме собою через секунду.
## Спільний матеріал для досліду «шість матеріалів на об'єкт проти одного». Створюється раз.
## Два спільні матеріали, щоб РОЗДІЛИТИ матеріальний стан і вибірку з текстури. Перший
## без текстури взагалі, другий — з однією спільною (беремо наявну текстуру паркану, вона
## є в кожній збірці). Якщо обидва дають те саме, винен стан; якщо текстурний помітно
## дорожчий — частина виграшу була просто від зниклої вибірки.
func _one_material(textured: bool) -> StandardMaterial3D:
	var key := 1 if textured else 0
	if _shared_mats.has(key):
		return _shared_mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.72, 0.62)
	m.roughness = 1.0
	if textured:
		var t := load("res://assets/props/cart_market_cart_market_3.png") as Texture2D
		if t != null:
			m.albedo_texture = t
			m.albedo_color = Color.WHITE
	_shared_mats[key] = m
	return m


## Усі випромінювачі в піддереві — обох видів, бо в грі є і ті, й ті.
func _all_particles(n: Node) -> Array:
	var out: Array = []
	if n is GPUParticles3D or n is CPUParticles3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_particles(c))
	return out


## СХОВАТИ вузол на час досліду — і тільки сховати.
##
## Дослід не має права ПОКАЗАТИ те, що світ навмисно сховав. Раніше тут скрізь стояло
## `visible = not прапорець`, і при порожньому списку це вмикало шар назад. Через це на
## морському світі проба «вмикала» плитку дороги й полотно, і кадр із БУДЬ-ЯКИМ прапорцем
## показував пісок замість моря — я встиг зробити з цього хибний висновок, що зникнення
## основи ламає пляж. Те саме колись дало неправдиве «вода коштує 37 мс».
##
## Тому запам'ятовуємо видимість, яку вузол мав ДО першого дотику, і повертаємо саме її.
## Запам'ятоване живе рівно доти, доки прапорець увімкнений. Інакше кеш застаріває: світ
## міняється посеред рівня (_enter_world -> _paint_road), і збережене «було видно» знову
## показало б те, що новий світ сховав.
func _strip_hide(n: Node, flag: String) -> void:
	var sp3 := n as Node3D
	if sp3 == null:
		return
	var key := "vis:%d" % sp3.get_instance_id()
	if _strip_flags.has(flag):
		if not _strip_orig.has(key):
			_strip_orig[key] = sp3.visible
		sp3.visible = false
	elif _strip_orig.has(key):
		sp3.visible = bool(_strip_orig[key])
		_strip_orig.erase(key)


## Підмінити параметр шейдера на час досліду — і повернути САМЕ той, що був.
## `amplitude` раніше ставився в нуль і не вертався ніколи: після одного варіанта «вода без
## хвилі» решта серії міряла плоску воду. `depth_ok` навпаки ЗАВЖДИ ставився в true, тобто
## дослід нав'язував стан, якого міг і не бути.
func _strip_param(sm: ShaderMaterial, name: String, off_value: Variant, flag: String) -> void:
	var k := "sp:%d:%s" % [sm.get_instance_id(), name]
	if _strip_flags.has(flag):
		if not _strip_orig.has(k):
			_strip_orig[k] = sm.get_shader_parameter(name)
		sm.set_shader_parameter(name, off_value)
	elif _strip_orig.has(k):
		sm.set_shader_parameter(name, _strip_orig[k])
		_strip_orig.erase(k)


## Завіси живуть під камерою й повторюють межі та колір туману, який заміняють.
func _setup_haze() -> void:
	haze = Haze.new()
	haze.name = "Haze"
	add_child(haze)
	haze.setup(camera_rig.get_node_or_null("Camera3D") as Camera3D)
	_sync_haze()


## Межі й колір завіс — з того самого тумана, який вони заміняють. І тут же вибір, що саме
## малювати: у стані «Плавно» туман коштує чверть кадру, тож там ідуть завіси.
func _sync_haze() -> void:
	if haze == null or env == null or env.environment == null:
		return
	var e := env.environment
	haze.configure(e.fog_depth_begin, e.fog_depth_end, e.fog_light_color)
	var real := Quality.real_fog_of(Quality.effective())
	e.fog_enabled = real
	haze.set_enabled(not real)


func _reapply_strip() -> void:
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		# Дослід може лише ЗАБРАТИ тінь, а не повернути її всупереч вибору дорослого:
		# базове значення беремо з якості, прапорець "shadows" гасить її додатково.
		sun.shadow_enabled = Quality.shadows_of(Quality.effective()) \
			and not _strip_flags.has("shadows")
	# РОЗДІЛЬНІСТЬ КАРТИ ТІНЕЙ. Каскад тут уже один (directional_shadow_mode=0), а дальність
	# 22 м — тобто «різати каскади» й «обмежити дальність» у цій грі вже зроблено. Лишається
	# сама карта: 2048x2048 на пристрої, де прохід тіней коштує близько 18 мс і НЕ залежить
	# від роздільності екрана — рівно ознака проходу власного розміру.
	# Дальність тіні: головна ручка тіней, бо прохід малює лише те, що в неї потрапило.
	for f in _strip_flags:
		var fs := String(f)
		if fs.begins_with("shadowdist") and sun != null:
			sun.directional_shadow_max_distance = float(fs.substr(10))
	for f in _strip_flags:
		var fs := String(f)
		if fs.begins_with("shadowmap"):
			ProjectSettings.set_setting(
				"rendering/lights_and_shadows/directional_shadow/size", int(fs.substr(9)))
			RenderingServer.directional_shadow_atlas_set_size(int(fs.substr(9)), true)
	# Повноекранні ефекти й великі поверхні — головні підозрювані в тому, що лишається,
	# коли декору вже нема: вони коштують за ПІКСЕЛЬ, а не за об'єкт.
	#
	# Початкові значення запам'ятовуємо ОДИН раз і повертаємо саме їх. Перша редакція цього
	# коду вмикала все підряд (`= not прапорець`), тобто сама вмикала те, що в грі могло
	# бути вимкненим, — і два прогони дали 94 та 130 мс на однаковій сцені з однаковими
	# викликами. Діагностика, яка міняє те, що міряє, гірша за відсутню.
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		var e := we.environment
		if not _strip_orig.has("glow"):
			_strip_orig["glow"] = e.glow_enabled
			_strip_orig["adjust"] = e.adjustment_enabled
			_strip_orig["fog"] = e.fog_enabled
			_strip_orig["bg"] = e.background_mode
			_strip_orig["aerial"] = e.fog_aerial_perspective
			_strip_orig["fcurve"] = e.fog_depth_curve
			_strip_orig["skyaff"] = e.fog_sky_affect
			print("СТРИП: початково glow=%s adjust=%s fog=%s bg=%d" % [
				e.glow_enabled, e.adjustment_enabled, e.fog_enabled, e.background_mode])
		e.glow_enabled = bool(_strip_orig["glow"]) and not _strip_flags.has("glow")
		e.adjustment_enabled = bool(_strip_orig["adjust"]) and not _strip_flags.has("adjust")
		e.fog_enabled = Quality.real_fog_of(Quality.effective()) \
			and not _strip_flags.has("fog")
		e.background_mode = Environment.BG_COLOR if _strip_flags.has("sky") \
			else int(_strip_orig["bg"]) as Environment.BGMode
		# РОЗКЛАД САМОГО ТУМАНУ. Режим у нас FOG_MODE_DEPTH, і в ньому піксельний шейдер
		# робить три різні речі. Міряємо їх нарізно, бо дві з трьох знімаються одним рядком:
		#   aerial — «повітряна перспектива»: домішує до туману колір НЕБА, тобто на кожен
		#            піксель бере ще одну вибірку з панорами. Найдорожчий підозрюваний;
		#   fcurve — крива глибини: pow() на піксель. 1.0 — це лінійно, без pow;
		#   skyaff — вплив туману на саме небо (у нас уже 0, тримаємо як контроль осмислення).
		# ЗАВІСИ. Ними керує стан якості (_sync_haze), а прапорець лише ДОДАЄ їх для заміру
		# «скільки вони коштують понад те, що вже є». Попередній стан запам'ятовуємо й
		# повертаємо — див. правило в docs/MEMORY.md.
		if haze != null:
			if _strip_flags.has("haze"):
				if not _strip_orig.has("haze"):
					_strip_orig["haze"] = haze.is_enabled()
				haze.set_enabled(true)
			elif _strip_orig.has("haze"):
				haze.set_enabled(bool(_strip_orig["haze"]))
				_strip_orig.erase("haze")
		# ВІДСІКАННЯ ДРІБНИЦІ для заміру: dcull20 = 2,0% висоти екрана, dcull0 = вимкнено.
		if track != null and track.has_method("force_decor_cull"):
			var dc := -1.0
			for f in _strip_flags:
				var fd := String(f)
				if fd.begins_with("dcull"):
					dc = float(fd.substr(5)) / 1000.0
			track.call("force_decor_cull", dc)
		e.fog_aerial_perspective = 0.0 if _strip_flags.has("nofogaerial") \
			else float(_strip_orig["aerial"])
		e.fog_depth_curve = 1.0 if _strip_flags.has("nofogcurve") \
			else float(_strip_orig["fcurve"])
		e.fog_sky_affect = 0.0 if _strip_flags.has("nofogsky") \
			else float(_strip_orig["skyaff"])
	# Масштаб рендера — головна ручка проти заповнення, і її теж треба міряти В ТОМУ САМОМУ
	# прогоні: окремою збіркою числа вже не порівняти через тротлінг.
	var vp := get_viewport()
	if vp != null:
		# База — з налаштування якості, а не одиниця: інакше дослід нав'язував би повну
		# роздільність там, де дорослий обрав «Плавно». Прапорець scaleNN лише перекриває.
		var sc := Quality.scale_of(Quality.effective())
		for f in _strip_flags:
			if String(f).begins_with("scale"):
				# Цифри після "scale" — десяткові розряди: "5" це 0.5, "45" це 0.45.
				# Одна цифра — десяті (історичне "scale5" = 0.5), дві й більше — соті:
				# "45" це 0.45, "100" це 1.0. Інакше сходи масштабу не записати.
				var rest := String(f).substr(5)
				if rest.length() == 1:
					sc = float(rest) / 10.0
				elif rest.length() > 1:
					sc = float(rest) / 100.0
		# Стеля 2.0, а не 1.0: на потужному пристрої гра впирається у власну синхронізацію
		# (iPhone 11 дає рівно 16,7 мс на ВСІХ варіантах, від 92 до 171 виклику), і різниці
		# не видно взагалі. Щоб дістати сигнал, навантаження піднімають ВИЩЕ стелі —
		# надлишкова вибірка 2.0 це вчетверо більше пікселів.
		vp.scaling_3d_scale = clampf(sc, 0.3, 2.0)
	# Розбір «підлоги»: що лишається, коли декору вже нема. Вимикаємо цілими вузлами —
	# траса (дорога, береги, вода), герой, увесь інтерфейс. Разом із мінімумом це дає
	# абсолютну підлогу: скільки коштує просто очистити екран і показати його.
	var tr := get_node_or_null("Track") as Node3D
	if tr != null:
		_strip_hide(tr, "track")
	# ЧАСТИНКИ. Прапорець згадувався в коментарі як доступний, але реалізації НЕ МАВ — тобто
	# в усіх наборах «мінімум» і «стеля» частинки лишались увімкненими, а рядок «світіння +
	# кольорокорекція + небо + частинки = 8 одиниць» насправді був без частинок. Тепер
	# вимикається все, що випромінює: і навколишні (світлячки, погода, пелюстки з FX), і
	# розліт від героя та перешкод.
	if _strip_flags.has("particles") or _strip_orig.has("part"):
		_strip_orig["part"] = true
		for p in _all_particles(self):
			p.emitting = false
			_strip_hide(p, "particles")
	var hr := get_node_or_null("Hero") as Node3D
	if hr != null:
		_strip_hide(hr, "hero")
	if _strip_flags.has("ui"):
		for c in get_children():
			if c is CanvasLayer:
				(c as CanvasLayer).visible = false
	# ВОДА — це не один меш. Крім головної площини (`_water`, море й пляж) є ще КАНАЛИ
	# обабіч дороги (`_canal_water`), і на них той самий шейдер на 311 рядків із вершинною
	# хвилею й підбивкою 40×6. Перша редакція ховала лише `_water`, тож «вода коштує нуль»
	# було неправдою: канали лишались на місці. Тепер прапорець «water» знімає обидва.
	var water = track.get("_water")
	if water != null:
		if not _strip_orig.has("water"):
			_strip_orig["water"] = (water as MeshInstance3D).visible
		(water as MeshInstance3D).visible = bool(_strip_orig["water"]) \
			and not _strip_flags.has("water")
	for mi in (track.get("_canal_water") as Array):
		_strip_hide(mi, "water")
		_strip_hide(mi, "canal")
	# КАНАЛИ ОКРЕМО ВІД МОРЯ. `water` знімає обидва, `canal` — лише канали; а `canalopaque`
	# робить непрозорими САМЕ їх. Розділення не примха: непрозора вода дає 2,8 мс, але
	# забирає прибережну піну навколо перешкод — а в каналах перешкод немає жодної, тож там
	# ця ціна не платиться взагалі. Міряємо, чи виграш той самий.
	if track.has_method("force_canal_shader"):
		track.force_canal_shader(3 if _strip_flags.has("canalopaque") else Track.CANAL_AS_SEA)
	# ОСВІТЛЕННЯ ПОЛОТНА ДОРОГИ. Розклад чотирьох світів (25.09) дав дорозі 13-15,5 мс на
	# лузі, хмаринках і пляжі — найбільше, що лишилось, і це ЗАПОВНЕННЯ, а не геометрія:
	# примітиви падають до 8-30 тис., а кадр — на п'ятнадцять мілісекунд.
	#
	# Гіпотеза, яку тут міряємо. Полотно пласке, видно з нього майже лише ВЕРХНЮ грань, а в
	# неї нормаль завжди вгору. Тіні в «Плавно» вимкнено. Отже освітлення на кожному пікселі
	# дороги рахує ОДНЕ Й ТЕ САМЕ число — марна робота на майже весь екран.
	#   roadunlit — стеля: скільки коштує освітлення дороги взагалі;
	#   roadnoamb — скільки з того коштує сама гілка навколишнього світла (на декорі це було
	#               86% усієї ціни, і саме її вдалось віддати випроміненню без втрат).
	for key in ["_mm_surface", "_mm_edge"]:
		var mi = track.get(key)
		if mi == null:
			continue
		var bm := (mi as MultiMeshInstance3D).material_override as BaseMaterial3D
		if bm == null:
			continue
		var rk := "road:%d" % bm.get_instance_id()
		if not _strip_orig.has(rk):
			_strip_orig[rk] = [bm.shading_mode, bm.disable_ambient_light]
		if _strip_flags.has("roadunlit"):
			bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		elif _strip_flags.has("roadvertex"):
			bm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		else:
			bm.shading_mode = int((_strip_orig[rk] as Array)[0]) as BaseMaterial3D.ShadingMode
		bm.disable_ambient_light = _strip_flags.has("roadnoamb") \
			or bool((_strip_orig[rk] as Array)[1])
	# РОЗКЛАД САМОЇ ВОДИ. Вона виявилась найдорожчою системою (+32,5 мс), маючи 73 виклики
	# й 36 тисяч примітивів — отже вся ціна в піксельному шейдері. Три підозри, і кожна
	# міряється окремо:
	#   waterdepth — вибірка DEPTH_TEXTURE для піни на межі. На плиткових GPU вона змушує
	#                зливати буфер, і це зазвичай найдорожче з усього.
	#   waterflat  — вершинна хвиля. Має бути дешевою (рахується на вершину), перевіряємо.
	#   watersimple — прозорий прохід цілком: замість шейдера простий НЕПРОЗОРИЙ матеріал.
	#                Вода зараз blend_mix + depth_draw_never, тобто не пише глибину, і все
	#                за нею теж малюється.
	var wmats: Array = []
	if track.get("_water_mat") != null:
		wmats.append(track.get("_water_mat"))
	wmats.append_array(track.get("_canal_mats") as Array)
	for m in wmats:
		var sm := m as ShaderMaterial
		if sm == null:
			continue
		_strip_param(sm, "depth_ok", false, "waterdepth")
		_strip_param(sm, "amplitude", 0.0, "waterflat")
	var simple_water: StandardMaterial3D = null
	if _strip_flags.has("watersimple") or _strip_flags.has("waterunlit"):
		if not _strip_orig.has("wsimple"):
			var sw := StandardMaterial3D.new()
			# Колір беремо З СВІТУ, а не прибитий: інакше порівняння вигляду нечесне —
			# на пляжі прибитий блакитний виглядав блідою плівкою замість моря.
			sw.albedo_color = Palette.of(world.get("water"), Color(0.31, 0.76, 0.97))
			sw.roughness = 1.0
			# ПЕРША РЕДАКЦІЯ ЦЬОГО ТЕСТУ БУЛА ХИБНА: матеріал лишався освітленим на піксель,
			# як і шейдер води (diffuse_burley), тож замір порівнював освітлену воду з
			# освітленою водою й давав нуль. Ціна води — не в її шейдері, а в тому, що вона
			# освітлюється на кожен піксель, як і будинки.
			_strip_orig["wsimple"] = sw
		if _strip_flags.has("waterunlit"):
			if not _strip_orig.has("wunlit"):
				var su := StandardMaterial3D.new()
				su.albedo_color = Palette.of(world.get("water"), Color(0.31, 0.76, 0.97))
				su.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_strip_orig["wunlit"] = su
		simple_water = _strip_orig["wunlit"] if _strip_flags.has("waterunlit") \
			else _strip_orig["wsimple"]
	var wnodes: Array = [track.get("_water")]
	wnodes.append_array(track.get("_canal_water") as Array)
	for n in wnodes:
		var mi2 := n as MeshInstance3D
		if mi2 == null:
			continue
		# РАНІШЕ ТУТ БУЛО `mi2.material_override = simple_water` БЕЗ УМОВИ. Коли жодного
		# водяного прапорця нема, simple_water лишається null — і рядок СТИРАВ шейдер води
		# у будь-якому досліді. Через це канали сіріли від прапорця `fog` так само, як від
		# `roadbase`, і я двічі мало не зробив із цього висновок про чужу систему.
		var k := "wov:%d" % mi2.get_instance_id()
		if simple_water != null:
			if not _strip_orig.has(k):
				_strip_orig[k] = mi2.material_override
			mi2.material_override = simple_water
		elif _strip_orig.has(k):
			mi2.material_override = _strip_orig[k]
			_strip_orig.erase(k)
	# ПОЛОТНО ДОРОГИ — два шари, що вкривають ту саму площу екрана: основа (_mm_center,
	# коробки на всю ширину ряду) і ПЛИТКА поверх неї (_mm_surface, піднята на TILE_LIFT).
	# Якщо плитка ховає основу повністю, основа — це зайвий екран заповнення щокадру.
	for mm in (track.get("_mm_center") as Array):
		if mm != null:
			_strip_hide(mm, "roadbase")
	var surf = track.get("_mm_surface")
	if surf != null:
		_strip_hide(surf, "roadtiles")
		# ЗАЗОР МІЖ ПЛИТКАМИ. Плитка менша за клітинку на TILE_GAP з обох боків, і саме
		# крізь ці шви видно основу — тому основу не можна просто прибрати. Два прапорці
		# міряють, чи зазор узагалі потрібен:
		#   tilez  — прибрати зазор ПОПЕРЕК траси (по z). Уздовж лишається, але його й так
		#            накриває шов між доріжками (_mm_seam, 0,025 проти зазору 0,02);
		#   tilexz — прибрати зазор зовсім.
		var bm := ((surf as MultiMeshInstance3D).multimesh as MultiMesh).mesh as BoxMesh
		if bm != null:
			# ЧІПАЄМО ЛИШЕ ЗА СВОЇМ ПРАПОРЦЕМ. У `bm.size` тепер є законний власник —
			# Track._apply_road_style, який ставить зазор під стиль полотна. Раніше цей блок
			# запам'ятовував розмір при ПЕРШОМУ дотику незалежно від прапорців і потім
			# щосекунди повертав його: досить було раз увімкнути будь-який дослід, і стиль
			# «base» мовчки малювався без зазору. Той самий взірець, за який уже платили тричі.
			var want_x := _strip_flags.has("tilexz")
			var want_z := _strip_flags.has("tilez")
			if want_x or want_z:
				if not _strip_orig.has("tilesize"):
					_strip_orig["tilesize"] = bm.size
				var base_size: Vector3 = _strip_orig["tilesize"]
				bm.size = Vector3(
					base_size.x + (Track.TILE_GAP if want_x else 0.0), base_size.y,
					base_size.z + Track.TILE_GAP)
			elif _strip_orig.has("tilesize"):
				bm.size = _strip_orig["tilesize"]
				_strip_orig.erase("tilesize")
	# Решта «полотен» траси: узбіччя, обрив, шов, край, хмари. Кожне вкриває помітну частку
	# екрана, а перевірені досі основа й плитка виявились безкоштовними — отже дивимось усі.
	for name in ["side", "cliff"]:
		for mm in (track.get("_mm_" + name) as Array):
			if mm != null:
				_strip_hide(mm, "mm_" + name)
	for name in ["seam", "edge", "clouds"]:
		var one = track.get("_mm_" + name)
		if one != null:
			_strip_hide(one, "mm_" + name)
	# Береги каналу — окремо: три тонкі смужки на борт зі своїм шейдером.
	for mi in (track.get("_canal_banks") as Array):
		_strip_hide(mi, "banks")
	track.set("strip_nosway", _strip_flags.has("nosway"))
	track.set("strip_freeze", _strip_flags.has("freeze"))
	var keep := 0
	for f in _strip_flags:
		if String(f).begins_with("keep"):
			keep = int(String(f).substr(4))
	track.set("strip_keep", keep)
	var near := 0.0
	for f in _strip_flags:
		if String(f).begins_with("near"):
			near = float(String(f).substr(4))
	track.set("strip_near", near)
	track.set("strip_skip_authored", _strip_flags.has("noauthored"))
	track.set("strip_skip_walls", _strip_flags.has("nowalls"))
	# Перешкоди — діти вузла Spawner, тож ховаються цілим піддеревом.
	var sp := get_node_or_null("Spawner") as Node3D
	if sp != null:
		_strip_hide(sp, "noobstacles")
	var layers: Array = track.get("_decor_mm")
	var by_key: Dictionary = track.get("_decor_layer_of")
	var swapped_mesh := false
	var n := 0
	var p := 0
	for key in by_key:
		var idx := int(by_key[key])
		if idx < 0 or idx >= layers.size():
			continue
		# Забудова відрізняється від дрібниці ключем шару: стіни мають суфікс "#wall"
		# (Track._decor_layer), бо не гойдаються. Інше — придорожній декор.
		var is_wall := String(key).ends_with("#wall")
		# Бісекція: "bandA_B" ховає шари з номерами [A, B). Ціна декору зосереджена в
		# кількох шарах (кожен другий дав 0,3 мс, усі разом — 33), і знайти їх можна лише
		# поділом навпіл.
		var band := false
		for f in _strip_flags:
			var fs := String(f)
			if not fs.begins_with("band"):
				continue
			var ab := fs.substr(4).split("_")
			if ab.size() == 2 and idx >= int(ab[0]) and idx < int(ab[1]):
				band = true
		var kill := band or _strip_flags.has("decor") \
			or (is_wall and _strip_flags.has("buildings")) \
			or (not is_wall and _strip_flags.has("props")) \
			or (is_wall and _strip_flags.has("half") and n % 2 == 0) \
			or (not is_wall and _strip_flags.has("halfprops") and p % 2 == 0)
		if is_wall:
			n += 1
		else:
			p += 1
		var mi := layers[idx] as MultiMeshInstance3D
		mi.visible = not kill
		# Тінь декору окремо від самого декору: карта тіней має ВЛАСНУ роздільність, тож
		# її ціна не падає від масштабу рендера — а саме так поводиться ціна декору.
		# ОДИН МАТЕРІАЛ НА ВЕСЬ ДЕКОР. Геометрія, положення, кількість об'єктів і кількість
		# ПОВЕРХОНЬ лишаються ті самі — міняється лише матеріальний стан: замість
		# п'яти-шести різних матеріалів на будинок усі поверхні малюються одним спільним.
		# Це ізолює рівно те, чого не розділили попередні досліди: прапорець keepN прибирав
		# екземпляри РАЗОМ із їхніми поверхнями, тож «ціна за об'єкт» і «ціна за матеріал»
		# досі злиті.
		#
		# Застереження до читання числа: спільний матеріал прибирає й вибірку з різних
		# текстур. Тож великий виграш означатиме «матеріальний стан АБО вибірка текстур», і
		# це доведеться розділяти окремо. Малий виграш — однозначний: ні те, ні те не винне.
		var om: StandardMaterial3D = null
		if _strip_flags.has("onemat"):
			om = _one_material(false)      # спільний матеріал без текстури
		elif _strip_flags.has("onetex"):
			om = _one_material(true)       # спільний матеріал З текстурою
		mi.material_override = om
		# СПЛОЩЕНІ ПРОПСИ: та сама модель і той самий вигляд, але одна поверхня й один
		# спільний матеріал замість двох-семи однотонних (колір переїхав у вершини).
		# На відміну від material_override це не підміна матеріалу поверх старих поверхонь,
		# а справжнє злиття — саме те, що дав би конвеєр.
		if _strip_flags.has("flat"):
			var fk := "flat%d" % idx
			if not _strip_orig.has(fk):
				_strip_orig[fk] = mi.multimesh.mesh
			var base := String(key).split("#")[0].split("|")[0]
			var vari := 0
			var tail := String(key).split("#")
			if tail.size() > 1 and tail[1].is_valid_int():
				vari = int(tail[1])
			var fm := PropLibrary.flat_mesh(base, vari)
			if fm != null and mi.multimesh.mesh != fm:
				mi.multimesh.mesh = fm
		elif _strip_orig.has("flat%d" % idx):
			mi.multimesh.mesh = _strip_orig["flat%d" % idx]
		# КАРТКИ ДАЛЕКИХ ХАТ (дослід 25.09). Далекі хати лівого боку лежать в окремих шарах
		# «…#farL#wall» (Track.far_card_tag). `farcards` підміняє в них сітку на плоску
		# картку, зняту під кутом ігрової камери; `nofar` ховає їх зовсім — стеля виграшу.
		if String(key).contains("#farL"):
			_strip_hide(mi, "nofar")
			var fk := "farcard%d" % idx
			if _strip_flags.has("farcards"):
				if not _strip_orig.has(fk):
					_strip_orig[fk] = mi.multimesh.mesh
				# Вид — до першого «#» і до «|» особливих налаштувань (kind|{json}#farL#wall).
				var cm := _far_card_mesh(String(key).split("#")[0].split("|")[0])
				if cm != null and mi.multimesh.mesh != cm:
					mi.multimesh.mesh = cm
			elif _strip_orig.has(fk):
				mi.multimesh.mesh = _strip_orig[fk]
				_strip_orig.erase(fk)
		# ПІДМІНА СІТКИ ХАТ (дослід 25.09). `terramesh_<варіант>` ставить ОДНУ модель замість
		# УСІХ шарів house_terra*: одна хата — це 3 екземпляри з ~22, тобто ефект нижчий за
		# поріг вимірювання, а всі разом — уже помітна частка ціни забудови. Опорою служить
		# `terramesh_orig`: та сама house_terra_6, тільки оригінальна, щоб порівнювати сітку з
		# сіткою, а не суміш хат із однією.
		#   proxy1200 / proxy600 — нова оболонка із запеченим виглядом оригіналу;
		#   facadeA / facadeB    — оригінал без граней, яких не видно з дороги.
		if String(key).begins_with("house_terra"):
			var tm := ""
			for f in _strip_flags:
				if String(f).begins_with("terramesh_"):
					tm = String(f).substr(10)
			var tk := "terramesh%d" % idx
			if tm != "":
				if not _strip_orig.has(tk):
					_strip_orig[tk] = mi.multimesh.mesh
				var nm: Mesh = null
				if tm == "sprite":
					# Спрайт із 8 боків — будуємо ОДИН раз і тримаємо: дослід повторюється
					# щосекунди, і нова дощечка щоразу вважалась би новою сіткою.
					if _terra_sprite == null:
						_terra_sprite = PropLibrary._sprite_mesh({
							"sprite": "res://assets/props/_exp/house_terra_6_sprite8.png",
							"height": 2.268, "frames": 8})
					nm = _terra_sprite
				else:
					var path := "res://assets/props/house_terra_6.glb" if tm == "orig" \
						else "res://assets/props/_exp/house_terra_6_%s.glb" % tm
					nm = PropLibrary.mesh_at(path)
				if nm != null and mi.multimesh.mesh != nm:
					mi.multimesh.mesh = nm
					swapped_mesh = true
			elif _strip_orig.has(tk):
				mi.multimesh.mesh = _strip_orig[tk]
				_strip_orig.erase(tk)
				swapped_mesh = true
		# КАРТИ НОРМАЛЕЙ. Сплощення пропсів зрізало виклики малювання з 262 до 145 і дало
		# лише 13,7 одиниць, а спільний матеріал поверх УСІХ шарів — 56,3 при тих самих
		# 252 викликах. Різниця між ними в тому, що другий накривав ще й 32 ТЕКСТУРНІ
		# пропси, замінюючи їхні матеріали з картами нормалей на простий. Отже перевіряємо
		# саме карти: лишаємо матеріал, текстуру кольору й усе інше, прибираємо лише нормаль.
		if _strip_flags.has("nonormal") or _strip_flags.has("nometal") \
				or _strip_flags.has("norough") or _strip_flags.has("noao") \
				or _strip_flags.has("unshaded") or _strip_flags.has("pervertex") \
				or _strip_flags.has("unwalls") or _strip_flags.has("cullback") \
				or _strip_flags.has("nofilter") or _strip_flags.has("nomip") \
				or _strip_flags.has("nospec") or _strip_flags.has("noambient") \
				or _strip_flags.has("ambemis") \
				or _strip_flags.has("terrapixel") or _strip_flags.has("allpixel") \
				or _strip_orig.has("nrm%d" % idx):
			var mm := mi.multimesh
			if mm != null and mm.mesh != null:
				for si in range(mm.mesh.get_surface_count()):
					var bm := mm.mesh.surface_get_material(si) as BaseMaterial3D
					if bm == null:
						continue
					# КЛЮЧ — ЗА САМИМ МАТЕРІАЛОМ, а не за номером шару. Матеріали в декору
					# СПІЛЬНІ: PropLibrary віддає один і той самий об'єкт кільком шарам. А
					# шари заводяться ЛІНИВО, у міру того як їде траса. Тому шар, створений
					# уже під час досліду, запам'ятовував «оригінал» зміненого матеріалу — і
					# після досліду повертав його в змінений стан.
					#
					# Заміряно наслідок: після послідовності unshaded -> onemat -> onetex ->
					# порожньо чотири шари з сорока п'яти лишались непідсвіченими, і це були
					# шари стін, тобто велика частка екрана. Контроль у пробі падав зі 175,7
					# до 133,1 — двадцять чотири відсотки, і замір ішов у смітник.
					var mid := bm.get_instance_id()
					var nk := "nrm:%d" % mid
					if not _strip_orig.has(nk):
						_strip_orig[nk] = bm.normal_texture
						_strip_orig["nrm%d" % idx] = true
					# БЕЗ ОСВІТЛЕННЯ. Стенд показав: освітлення на піксель — 61% ціни сцени,
					# а вибірка кольору з текстури коштує НУЛЬ. Наші пропси мають запечений
					# колір (baked_color із Meshy), тобто світло в них уже намальоване, і
					# рушій рахує його вдруге. Міняємо ЛИШЕ режим затінення: текстура,
					# колір, прозорість і все інше лишаються як були.
					var sk := "shade:%d" % mid
					if not _strip_orig.has(sk):
						_strip_orig[sk] = bm.shading_mode
					# Три режими: як є (на піксель), НА ВЕРШИНУ і без освітлення зовсім.
					# Середній тут головний кандидат: форма зберігається, бо світло все ще
					# рахується, але платимо за вершини — а їх у low-poly мало, на відміну
					# від пікселів.
					# ВИБІРКОВЕ вимкнення. Критерій не «будинок», а чи несе ТЕКСТУРА об'єм:
					# шар іде в непідсвічений клас, якщо це стіна світу (#wall) І в
					# матеріалі є текстура кольору. Бо будинки в нас двох видів:
					# house_terra має запечену текстуру 1024x1024, а house_red і barn — це
					# 5-6 ОДНОТОННИХ матеріалів без текстури, і без світла вони стануть
					# пласкими так само, як тюк сіна.
					# ВІДСІКАННЯ ЗАДНІХ ГРАНЕЙ. Усі 160 поверхонь наших пропсів приїхали
					# ДВОСТОРОННІМИ (cull_mode = CULL_DISABLED), тобто кожен закритий об'єкт
					# малює і лицьову, і зворотну сторону. Половина цієї роботи ніколи не
					# видна, а платимо ми за неї на кожен піксель — тобто саме тією статтею,
					# яка тут найдорожча.
					# ФІЛЬТРАЦІЯ ТЕКСТУР. Перевірено кодом: усі 160 поверхонь мають
					# LINEAR_WITH_MIPMAPS, анізотропного фільтра НЕМАЄ ЖОДНОГО, тож
					# налаштування anisotropic_filtering_level=3 у project.godot мертве.
					# Тут міряємо іншу річ: чи коштує сама лінійна фільтрація з рівнями
					# деталізації. Luanti на цьому ж телефоні тримає 60 к/с із вимкненою
					# фільтрацією взагалі, тож варто знати ціну.
					var tk := "tf:%d" % mid
					if not _strip_orig.has(tk):
						_strip_orig[tk] = bm.texture_filter
					if _strip_flags.has("nofilter"):
						bm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
					elif _strip_flags.has("nomip"):
						bm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
					else:
						bm.texture_filter = int(_strip_orig[tk]) as BaseMaterial3D.TextureFilter
					# ВІДБЛИСК І НАВКОЛИШНЄ СВІТЛО — дешевша половина того ж питання. Зняти
					# освітлення зі стін цілком коштує виглядом: пласкішають дахи, яскравішає
					# все містечко. Тому спершу міряємо, скільки коштують ОКРЕМІ доданки
					# освітлення, які форму НЕ несуть: відблиск (Schlick-GGX у фрагменті) і
					# навколишнє світло. Якщо ціна там — вигляд лишається як є.
					var pk := "spec:%d" % mid
					if not _strip_orig.has(pk):
						_strip_orig[pk] = [bm.specular_mode, bm.disable_ambient_light]
					bm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED \
						if _strip_flags.has("nospec") \
						else int((_strip_orig[pk] as Array)[0]) as BaseMaterial3D.SpecularMode
					bm.disable_ambient_light = _strip_flags.has("noambient") \
						or _strip_flags.has("ambemis") \
						or bool((_strip_orig[pk] as Array)[1])
					# НАВКОЛИШНЄ СВІТЛО ВИПРОМІНЕННЯМ. Замір: гілка навколишнього світла
					# коштує 8,3 мс, але просто вимкнути її не можна — затінені грані падають
					# у чорне (знімок 24.09). Проте навколишнє світло в нас РІВНЕ:
					# `albedo * ambient_color * energy`, без жодної залежності від нормалі й
					# напрямку. Такий самий сталий доданок дає випромінення з множенням на
					# ту саму текстуру кольору — а воно гілки освітлення не вмикає взагалі.
					# Тобто картинка та сама, а варіант шейдера коротший.
					var ek := "emis:%d" % mid
					if not _strip_orig.has(ek):
						_strip_orig[ek] = [bm.emission_enabled, bm.emission,
							bm.emission_texture, bm.emission_operator,
							bm.emission_energy_multiplier]
					if _strip_flags.has("ambemis") and env != null and env.environment != null:
						var amb := env.environment.ambient_light_color
						var ac := bm.albedo_color
						bm.emission_enabled = true
						bm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
						bm.emission_texture = bm.albedo_texture
						bm.emission = Color(amb.r * ac.r, amb.g * ac.g, amb.b * ac.b)
						bm.emission_energy_multiplier = env.environment.ambient_light_energy
					else:
						var eo := _strip_orig[ek] as Array
						bm.emission_enabled = bool(eo[0])
						bm.emission = eo[1] as Color
						bm.emission_texture = eo[2] as Texture2D
						bm.emission_operator = int(eo[3]) as BaseMaterial3D.EmissionOperator
						bm.emission_energy_multiplier = float(eo[4])
					var kk := "cull:%d" % mid
					if not _strip_orig.has(kk):
						_strip_orig[kk] = bm.cull_mode
					bm.cull_mode = BaseMaterial3D.CULL_BACK if _strip_flags.has("cullback") \
						else int(_strip_orig[kk]) as BaseMaterial3D.CullMode
					var paintable := is_wall and bm.albedo_texture != null
					var ak := "alb:%d" % mid
					if not _strip_orig.has(ak):
						_strip_orig[ak] = bm.albedo_color
					var mul := 1.0
					for f2 in _strip_flags:
						var fs2 := String(f2)
						if fs2.begins_with("dim"):
							mul = float(fs2.substr(3)) / 100.0
					if _strip_flags.has("unshaded"):
						bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					elif _strip_flags.has("unwalls") and paintable:
						bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
						var c0 := _strip_orig[ak] as Color
						bm.albedo_color = Color(c0.r * mul, c0.g * mul, c0.b * mul, c0.a)
					# ОСВІТЛЕННЯ НА ПІКСЕЛЬ ДЛЯ НАДЩІЛЬНИХ СІТОК. 22.09 доведено тестом
					# із силуетом: у house_terra_6 зрізали 94% вершин — і НУЛЬ. Але тоді світло
					# рахувалось на ПІКСЕЛЬ, і вершини не важили. Відтоді ми самі перевели
					# декор на вершину — і тепер світло рахується на кожну з ~213 тисяч вершин
					# двадцяти чотирьох хат `house_terra_*` (8-11 тисяч вершин кожна, проти
					# 258-498 у міських будинків). Тобто правка, що дала -5…-8 мс глобально,
					# могла зробити вершини дорогими саме на кількох надщільних моделях.
					#   terrapixel — лише house_terra_* назад на піксель, решта на вершині;
					#   allpixel   — увесь декор на піксель (перевірка, чи вершина ще виграє).
					elif _strip_flags.has("allpixel") or (_strip_flags.has("terrapixel")
							and String(key).begins_with("house_terra")):
						bm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
						bm.albedo_color = _strip_orig[ak] as Color
					elif _strip_flags.has("pervertex"):
						bm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
					else:
						bm.shading_mode = int(_strip_orig[sk]) as BaseMaterial3D.ShadingMode
						bm.albedo_color = _strip_orig[ak] as Color
					var ok := "orm%d_%d" % [idx, si]
					if not _strip_orig.has(ok):
						_strip_orig[ok] = [bm.roughness_texture, bm.metallic_texture,
							bm.roughness, bm.metallic, bm.ao_texture, bm.ao_enabled]
					if _strip_flags.has("nonormal"):
						bm.normal_enabled = false
						bm.normal_texture = null
					else:
						var nt := _strip_orig[nk] as Texture2D
						bm.normal_texture = nt
						bm.normal_enabled = nt != null
					# Метал і шорсткість у glTF лежать в ОДНІЙ картинці (metallic_roughness),
					# але в Godot це два окремі входи з різних каналів. Розділяємо їх, щоб
					# побачити, чи винна сама вибірка, чи конкретний канал.
					var was := _strip_orig[ok] as Array
					if _strip_flags.has("nometal"):
						bm.metallic_texture = null
						bm.metallic = 0.0
					else:
						bm.metallic_texture = was[1]
						bm.metallic = was[3]
					if _strip_flags.has("norough"):
						bm.roughness_texture = null
						bm.roughness = 1.0
					else:
						bm.roughness_texture = was[0]
						bm.roughness = was[2]
					if _strip_flags.has("noao"):
						bm.ao_texture = null
						bm.ao_enabled = false
					else:
						bm.ao_texture = was[4]
						bm.ao_enabled = was[5]
		var ck := "cast%d" % idx
		if not _strip_orig.has(ck):
			_strip_orig[ck] = mi.cast_shadow
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			if _strip_flags.has("decorshadow") \
			else int(_strip_orig[ck]) as GeometryInstance3D.ShadowCastingSetting
	# Підмінена сітка приїхала зі СВОЇМИ матеріалами — на піксель і з гілкою навколишнього
	# світла. Без цього рядка порівняння було б нечесним: нова модель платила б за освітлення,
	# якого решта гри вже не платить. Траса розставляє їм те саме, що й усім шарам декору.
	if swapped_mesh and track.has_method("apply_decor_shading"):
		track.apply_decor_shading()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Відтворюваний запуск на вимогу (GAME_SEED): крім власних генераторів підсистем,
	# траса й спавнер беруть ще й ГЛОБАЛЬНИЙ randf()/randi(), тож сідаємо і на нього.
	# Без цього два прогони гри розходяться на 37% пікселів уже до 600-го кадру —
	# заміряно, і саме через це весь день не вдавалося порівняти «до і після».
	if RngSeed.fixed():
		seed(RngSeed.value())

	# Дебаг-накладка (к/с, виклики, стан гри). Показується сама лише там, де вона потрібна:
	# у збірці з прапорцем "debug_hud" (веб-збірка для випробувань, див. export_presets.cfg)
	# і в запуску з редактора. У звичайній збірці для дитини вона мовчить, але лишається —
	# F3 дістає її й там, і це навмисно: коли щось піде не так на чужому телефоні, числа
	# мають бути за одну клавішу, а не за перезбірку.
	_light_k = light_scale_for(RenderingServer.get_current_rendering_method())
	if OS.has_environment("LIGHT_K"):
		_light_k = float(OS.get_environment("LIGHT_K"))   # ручка для добору заміром

	_debug = DebugOverlay.new()
	add_child(_debug)
	_debug.setup(self)
	# DEBUG_HUD=0 ховає накладку примусово — щоб знімки ВИГЛЯДУ (tools/probe/) не
	# розглядали половину кадру крізь панель із числами.
	if OS.get_environment("DEBUG_HUD") == "0" \
			or not (OS.has_feature("debug_hud") or OS.is_debug_build()):
		_debug.mode = DebugOverlay.Mode.HIDDEN
		_debug._panel.visible = false

	profiles = AgeAdapt.load_profiles()
	worlds = load_worlds()
	heroes = HeroSelect.load_heroes()
	season = Seasons.current()
	var l = SaveService.child().get("learned", {})
	_learned = l if typeof(l) == TYPE_DICTIONARY else {}
	_setup_sky()
	_setup_haze()
	# ЯКІСТЬ ЗАСТОСОВУЄМО ТУТ, а не покладаємось на автозавантаження. Quality._ready() кличе
	# apply() ще ДО того, як існує ця сцена: автозавантаження готові раніше за головну сцену.
	# Для згладжування це працювало (властивість в'юпорта, він уже є), а для тіней — ні:
	# вони властивість СВІТЛА, і сонця в той момент ще немає. Через це стан «Плавно» не
	# вимикав тіні, хоч у налаштуваннях так і було задано.
	#
	# І САМЕ ТУТ, ПЕРЕД debug_strip: збірки-стелі (minfps/heroonly) нижче гасять тінь
	# прапорцем, і якби якість застосовувалась після них, у стані «Середнє»/«Гарно» тінь
	# верталась би на першу секунду — до наступного спрацювання таймера досліду.
	Quality.apply()
	# Шари декору заводяться ЛІНИВО, у міру того як дорога їде, тож одного виклику мало:
	# повторюємо щосекунди, поки триває дослід.
	#
	# ТАЙМЕР СТОЇТЬ, ПОКИ ДОСЛІДУ НЕМА. Раніше він мав autostart і в ЗВИЧАЙНІЙ грі щосекунди
	# кликав _reapply_strip, а той писав сонцю `shadow_enabled = not flags.has("shadows")` —
	# тобто при порожньому списку ВМИКАВ тінь назад. Через це стан якості «Плавно» чесно
	# гасив тінь на старті, а за секунду риштування для замірів її повертало, і на телефоні
	# було видно «якість smooth · тінь так». Заміри теж брехали: кожна збірка мала тінь
	# незалежно від налаштувань. Вмикає й гасить таймер тепер сам debug_strip().
	_strip_timer = Timer.new()
	_strip_timer.wait_time = 1.0
	_strip_timer.timeout.connect(_reapply_strip)
	add_child(_strip_timer)
	# Прогін по варіантах — лише у збірці з прапорцем "strip_probe" (ставиться в пресеті
	# ТИМЧАСОВО, на час замірів). У звичайній грі цього вузла не існує.
	# ЗБІРКА-СТЕЛЯ. Прапорець "minfps" вимикає все, що коштує кадру, і НЕ вертає назад: у неї
	# заходять, щоб побачити й відчути межу пристрою, а не щоб грати. Дорога, герой і
	# інтерфейс лишаються — інакше це вже не гра, а порожній екран.
	#
	# Заміряно: із цим набором кадр на масштабі 1.0 — близько 19-22 мс, тобто 45-52 к/с,
	# причому РІВНО на всіх масштабах рендера (роздільність перестає важити зовсім).
	if OS.has_feature("minfps"):
		debug_strip(PackedStringArray([
			"shadows", "fog", "glow", "adjust", "sky", "particles",
			"water", "banks", "decor",
			"mm_side", "mm_cliff", "mm_seam", "mm_clouds",
		]))
	# АБСОЛЮТНИЙ НУЛЬ: лишається тільки герой і накладка з числами. Прапорець "heroonly"
	# ховає ще й УСЮ трасу — дорогу, узбіччя, обриви, все. Це не гра, а вимір: скільки
	# коштує сам рушій із героєм, нижче вже нікуди.
	if OS.has_feature("heroonly"):
		debug_strip(PackedStringArray([
			"shadows", "fog", "glow", "adjust", "sky", "particles",
			"water", "banks", "decor", "track",
		]))
	# STRIP=roadbase,mm_seam — застосувати прапорці досліду з середовища. Потрібно, щоб
	# ДИВИТИСЬ на наслідок у справжньому вікні на Маку (tools/probe), не збираючи APK: ціну
	# міряє телефон, а що при цьому зникло з екрана — видно й тут. Порожнє значення нічого
	# не вмикає, і, як усюди в досліді, прапорець може лише ЗАБРАТИ, а не додати.
	# `--strip=` у командному рядку робить те саме на ТЕЛЕФОНІ, де змінних середовища не
	# передати: збірки для живого заміру різняться лише рядком у пресеті експорту (як
	# `--level=` і `--scale=`). Так розгортка 17 рівнів може йти з прапорцем і без нього.
	var raw := OS.get_environment("STRIP").strip_edges() if OS.has_environment("STRIP") else ""
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if String(a).begins_with("--strip="):
			raw = String(a).substr(8).strip_edges()
	# Шари далеких хат ділимо лише тоді, коли їх справді міряють (див. Track.far_cards_split).
	Track.far_cards_split = OS.has_feature("strip_probe") or raw.contains("farcards") \
		or raw.contains("nofar")
	if raw != "":
		debug_strip(PackedStringArray(raw.split(",", false)))
	# ПРОГІН УСІХ РІВНІВ — окрема проба, вмикається прапорцем збірки `sweep`.
	if OS.has_feature("sweep") and ResourceLoader.exists("res://src/ui/sweep_probe.gd"):
		var sw: Node = load("res://src/ui/sweep_probe.gd").new()
		sw.run = self
		add_child(sw)
	if OS.has_feature("strip_probe") and ResourceLoader.exists("res://src/ui/strip_probe.gd"):
		var probe: Node = load("res://src/ui/strip_probe.gd").new()
		probe.run = self
		add_child(probe)

	# МЕТОДОМ, А НЕ ЛЯМБДОЮ. Лямбда, що захоплює цю сцену, лишається на автозавантаженні
	# `Quality` НАЗАВЖДИ: Godot не роз'єднує її, коли вузол звільнено, бо прив'язки до
	# об'єкта немає. У грі сцена одна, тож це не було видно; у тестах кожна наступна зміна
	# якості падала з «Lambda capture at index 0 was freed». Зв'язок із МЕТОДОМ рушій знімає
	# сам разом із вузлом.
	Quality.applied.connect(_on_quality_applied)

	Events.profile_changed.connect(_apply_profile)
	Events.session_warning.connect(_on_session_warning)
	Events.session_finished.connect(_on_session_finished)
	Events.star_collected.connect(_on_star_collected)
	Events.quest_completed.connect(_on_quest_completed)
	Events.hearts_changed.connect(_on_hearts_changed)
	Events.obstacle_passed.connect(_on_obstacle_passed)
	Events.hero_tumbled.connect(_on_hero_tumbled)
	hero.landed.connect(func(): AudioMgr.sfx("land"))
	menu.play_pressed.connect(_on_play)
	menu.heroes_pressed.connect(_on_heroes)
	menu.map_pressed.connect(_on_menu_map)
	menu.settings_pressed.connect(func():
		if state == State.MENU:
			hud._request_parents())
	hero_select.chosen.connect(_on_hero_chosen)
	hero_select.closed.connect(_on_heroes_closed)
	map_screen.level_chosen.connect(_start_level)
	map_screen.closed.connect(_on_map_closed)
	controls.action.connect(_on_control_action)
	wheel.finished.connect(_on_wheel_finished)
	# HUD типізований як CanvasLayer — сигнали чіпляємо за іменем (як і решта звернень до нього)
	hud.connect("pause_pressed", Callable(self, "_on_pause_pressed"))
	hud.connect("resume_pressed", Callable(self, "_on_resume_pressed"))
	hud.connect("menu_pressed", Callable(self, "_on_pause_menu_pressed"))
	hud.connect("power_pressed", Callable(self, "activate_power"))
	_wire_diorama()
	_make_magpie()

	# Лічильник кадрів для замірів (PERF=1) живе в `src/debug/`, а ця тека ВИКЛЮЧЕНА з
	# експорту. Без запитання до ResourceLoader кожен запуск веб-збірки починався з двох
	# червоних рядків у консолі про ненайдений скрипт — знайдено headless-браузером на
	# першій же зібраній сторінці. У самій грі числа показує DebugOverlay, він у src/ui/.
	if ResourceLoader.exists("res://src/debug/perf_overlay.gd"):
		var perf := load("res://src/debug/perf_overlay.gd")
		if perf != null:
			perf.attach(self)

	_apply_profile(AgeAdapt.current)
	_apply_hero(String(SaveService.child().get("hero", "puf")))
	level_num = lm.current()
	level = lm.get_level(level_num)
	_enter_world(String(level.get("world", "meadow")), true)
	_enter_menu(true)
	_demo_jump()


## Швидкий вхід для показу й тестування: одразу в потрібний рівень потрібним героєм, без
## меню, вибору героя й мапи.
##
## Навіщо. Щоб подивитись на один рівень, доводилось щоразу проходити три екрани. Коли
## правку треба перевірити двадцять разів поспіль, це з'їдає більше часу, ніж сама правка,
## і — гірше — спокушає перевіряти рідше, ніж треба.
##
##     LEVEL=1 godot res://src/run3d/run3d.tscn
##     LEVEL=1 HERO=lys godot res://src/run3d/run3d.tscn
##
## Рівень відкривається навіть якщо не куплений: це вхід для показу, а не обхід прогресу
## в самій грі — без змінної оточення все лишається як було.
func _demo_jump() -> void:
	var who := OS.get_environment("HERO")
	if who != "" and heroes.has(who):
		_apply_hero(who)
	var lvl := OS.get_environment("LEVEL")
	if lvl == "":
		# НА ANDROID ЗМІННІ ОТОЧЕННЯ НЕ ДОХОДЯТЬ: процес запускає система, а не оболонка.
		# Тому там те саме передають аргументом наміру:
		#   adb shell am start -n <пакет>/com.godot.game.GodotApp \
		#     --es command_line_params "--level=12"
		# Без цього кожен замір чужого світу вимагав би або окремої збірки, або зміни
		# збереження на телефоні замовника.
		for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
			var arg := String(a)
			if arg.begins_with("--level="):
				lvl = arg.substr(8)
				break
	if lvl == "":
		return
	var num := clampi(int(lvl), 1, maxi(lm.count(), 1))
	_demo_any_level = true
	print("демо: одразу рівень ", num, " героєм ", hero.hero_id)
	_start_level(num)


# ---------- дані ----------

static func load_worlds() -> Dictionary:
	var out := {}
	var dir := DirAccess.open("res://data/worlds")
	if dir == null:
		return out
	for fname in dir.get_files():
		if not fname.ends_with(".json"):
			continue
		var f := FileAccess.open("res://data/worlds/%s" % fname, FileAccess.READ)
		if f == null:
			continue
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("id"):
			out[String(parsed["id"])] = parsed
	return out


## Чиста функція (сумісність із тестами): двері вибору світу.
static func fork_ids(allowed: Array, current: String, n: int, rng: RandomNumberGenerator) -> Array:
	var others := allowed.filter(func(w): return String(w) != current)
	for i in range(others.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = others[i]
		others[i] = others[j]
		others[j] = tmp
	var out := others.slice(0, mini(n, others.size()))
	if out.size() < n and allowed.has(current):
		out.append(current)
	if out.is_empty():
		out.append(current)
	return out


## Звідки починається туман для світу з такою густиною. Густина лишилась у даних світів
## (Ліс 0,03 — густий і темний, Лужок 0,012 — прозорий), але в режимі глибини вона керує не
## силою, а ВІДСТАННЮ: що густіший світ, то ближче туман береться. Чиста функція.
static func fog_begin_for(density: float) -> float:
	if density <= 0.0:
		return float(FOG_BEGIN_RANGE[1])
	return clampf(FOG_NEAR_M * DEFAULT_FOG / density,
		float(FOG_BEGIN_RANGE[0]), float(FOG_BEGIN_RANGE[1]))


## Множник світла для цього рушія. Чиста функція окремо від RenderingServer — щоб рішення
## можна було перевірити тестом: самого рушія в тестах не переключиш.
static func light_scale_for(method: String) -> float:
	return COMPAT_LIGHT if method == "gl_compatibility" else 1.0


## Камера під ширину дороги: 7 доріжок — вище й далі, ортографічна — ширша.
## GDD v1.5: ×1,12 на кожен крок ширини (3→5→7), щоб ракурс 3/4 не «розвалювався» на широкій дорозі.
static func camera_for_lanes(preset: Dictionary, n_lanes: int) -> Dictionary:
	var k := pow(1.12, float(n_lanes - 3) * 0.5)
	var out := preset.duplicate(true)
	var p: Array = out.get("pos", [0.0, 3.8, 4.6])
	out["pos"] = [float(p[0]) * k, float(p[1]) * k, float(p[2]) * k]
	if bool(out.get("ortho", false)):
		out["size"] = float(out.get("size", 9.0)) * k
	return out


func _apply_profile(profile_name: String) -> void:
	profile = profiles.get(profile_name, profiles.get("young", {}))
	base_speed = float(profile.get("speed", 4.0))
	speed = base_speed
	hero.jump_velocity = float(profile.get("jump_velocity", 7.5))
	# камера рухається тим спокійніше, чим менша дитина (див. CameraRig.intensity)
	camera_rig.intensity = float(profile.get("camera_life", 1.0))
	if mode:
		mode.profile = profile
		spawner.profile = profile
		spawner.magnet = float(profile.get("star_magnet", 1.0)) * _hero_magnet
		events_spawner.profile = profile
	hud.set_profile(profile_name)
	controls.set_arrows_visible(state == State.RUN and _arrows_on())


func _arrows_on() -> bool:
	return bool(SaveService.setting("arrows", AgeAdapt.current == "young"))


func _joystick_on() -> bool:
	return bool(SaveService.setting("joystick", true))


func _apply_hero(id: String) -> void:
	# невідомий id у збереженні — беремо першого звірятка (старі legacy-id лишаються, Hero3D їх сам розв'язує)
	if not heroes.has(id):
		var first := Hero3D.first_animal_id(heroes)
		id = first if first != "" else "puf"
	var h: Dictionary = heroes.get(id, {})
	hero.set_hero(id, Palette.of(h.get("color"), Palette.HERO_DEFAULT), String(h.get("feature", "tuft")))
	Shop.apply_to(hero)
	_apply_power_def(id)


## v1.3: усі світи — біг. "hop"/"float" (HopMode/FloatMode) застаріли й не створюються; "slide" лишився як код на майбутнє.
func _make_mode(kind: String) -> ModeBase:
	match kind:
		"surf": return SurfMode.new()
		"scooter": return ScooterMode.new()
		"float_run": return FloatRunMode.new()
		"slide": return SlideMode.new()
		_: return RunMode.new()


## rebuild_track false — той самий біом, дорогу не перебудовуємо (лише доріжки, якщо змінились); режим/спавнери — завжди.
## Стан якості змінився: перерахувати те, що від нього залежить.
func _on_quality_applied(_st: String) -> void:
	_sync_haze()
	if track != null and track.has_method("reapply_water_shader"):
		track.reapply_water_shader()
	if track != null and track.has_method("apply_decor_shading"):
		track.apply_decor_shading()


func _enter_world(id: String, instant: bool, rebuild_track: bool = true) -> void:
	if not worlds.has(id):
		id = String(worlds.keys()[0])
	world = worlds[id]
	world_id = id
	# КЕШ ВИДИМОСТІ ДОСЛІДУ ПРИВ'ЯЗАНИЙ ДО СВІТУ, і без цього рядка він бреше.
	#
	# `_strip_orig["water"]` і ключі `vis:` запам'ятовують «як було» ПРИ ПЕРШОМУ проході
	# досліду. А перший прохід стається в меню, на лузі, де МОРЯ НЕМАЄ ЗОВСІМ — отже
	# запам'ятовувалось «невидиме», і далі море не з'являлось уже ніде. Знімок пляжу через
	# це показав рівне зелене поле замість води, і я мало не записав це в регресію правки,
	# якої там не було.
	#
	# Новий світ — новий «як було». Прапорці лишаються активними, бо `_reapply_strip`
	# повторюється щосекунди й зніме стан заново, уже з правильного світу.
	for k in _strip_orig.keys():
		var ks := String(k)
		if ks == "water" or ks.begins_with("vis:"):
			_strip_orig.erase(k)
	if mode:
		mode.exit()
	mode = _make_mode(String(world.get("mode", "run")))
	mode.setup(self, hero, world, profile)
	mode.speed = speed
	mode.enter()
	hero.lane = 0
	hero.x_target = 0.0
	hero.run_speed_factor = 1.0
	hero.set_running(state != State.MENU)
	if rebuild_track:
		track.rebuild(world, not instant, season, lanes)
	elif track.lanes != lanes:
		track.set_lanes(lanes, false)
	hero.set_lanes(lanes)
	if state == State.RUN:
		# зміна біому посеред бігу (дебаг) — камеру переїжджаємо тут; на старті рівня це робить _start_level
		camera_rig.apply(camera_for_lanes(world.get("camera", {}), lanes), 0.8)
	# туман світу (Ліс густіший і темніший, Пляж — морська імла)
	if env.environment:
		env.environment.fog_depth_begin = fog_begin_for(
			float(world.get("fog_density", DEFAULT_FOG)))
		_sync_haze()
	_set_sky(clampf(session_t / session_total, 0.0, 1.0))
	_set_ambient()
	spawner.configure(profile, world, hero, mode, self)
	events_spawner.configure(self, hero, spawner, actors, profile, mode.mode_id())
	hud.set_world(String(world.get("name_uk", id)))
	AudioMgr.music(String(world.get("music", "")))
	Events.world_changed.emit(id)


# ---------- небо, сезон, атмосфера ----------

func _setup_sky() -> void:
	if env.environment == null:
		env.environment = Environment.new()
	var e := env.environment
	# суцільний колір неба (надійно на Mobile) + м'який туман: далекий план тане, стає затишно
	e.background_mode = Environment.BG_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_energy = AMBIENT_ENERGY
	e.ambient_light_color = AMBIENT_COLOR
	# Декор відтворює навколишнє світло випроміненням, тож мусить знати його з ПЕРШОГО ж
	# кадру. Без цього шари, заведені до першого _set_sky (а `rebuild()` в `_enter_world`
	# іде саме до нього), лишались би без нього зовсім.
	if track != null and track.has_method("set_ambient_light"):
		track.set_ambient_light(e.ambient_light_color, e.ambient_light_energy)
	e.fog_enabled = true
	# Туман по ГЛИБИНІ, а не показниковий. Показниковий нівечить усе однаково: щоб сховати
	# кінець дороги на 42 м, треба така густина, що й бочка за три кроки блякне. Тут ближче
	# за FOG_NEAR_M нема туману зовсім (референс різкий під ногами), а на FOG_FAR_M —
	# суцільний колір неба. FOG_FAR_M береться від самої траси: вона 44 ряди по 1 м, тобто
	# найдальший ряд на 42,6 м від камери. Замовник бачив саме це: «не має далі дороги і
	# видно, що вона підгружається».
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_depth_begin = fog_begin_for(DEFAULT_FOG)
	e.fog_depth_end = FOG_FAR_M
	e.fog_depth_curve = FOG_CURVE
	# У режимі глибини `fog_density` — це МНОЖНИК готового туману, а не густина на метр.
	# Зі старими 0,012 туману не було видно взагалі (перевірено кадром), тому тут одиниця,
	# а різницю між світами дає fog_begin_for().
	e.fog_density = 1.0
	e.fog_sky_affect = 0.0
	e.fog_aerial_perspective = 0.4
	e.fog_light_color = Palette.W_SKY
	e.background_color = Palette.W_SKY
	# м'який блум (GDD v1.5 §3): світлі плити й злитки ледь світяться, без «пересвіту»
	e.glow_intensity = GLOW_INTENSITY
	e.glow_bloom = GLOW_BLOOM
	e.glow_hdr_threshold = GLOW_THRESHOLD
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# кольорокорекція: без неї воксельні кольори в меню й каруселі виглядали вицвілими
	e.adjustment_enabled = true
	e.adjustment_saturation = ADJ_SATURATION
	e.adjustment_contrast = ADJ_CONTRAST
	e.adjustment_brightness = 1.0
	set_fx_blur(bool(SaveService.setting("fx_blur", true)))


## Налаштування «fx_blur» (типово увімкнене): блум + розмиття планів разом.
## Рядок-перемикач у батьківській панелі — за hud.gd; сюди можна прийти викликом ззовні.
func set_fx_blur(on: bool) -> void:
	if env.environment:
		env.environment.glow_enabled = on
	if camera_rig:
		camera_rig.set_dof(on)


## Живе небо: день → вечір протягом сесії (t 0..1); сезон і фішка рівня (ніч/вечір) підфарбовують.
func _set_sky(t: float) -> void:
	var day := Palette.of(world.get("sky"), Palette.SKY_DAY)
	var evening := Palette.of(world.get("sky_evening"), Palette.SKY_EVENING)
	if not season.is_empty():
		day = day * Palette.of(season.get("sky_tint"), Palette.GROUND_TINT_NONE)
	if bool(level.get("evening", false)):
		t = maxf(t, 0.8)
	var c := day.lerp(evening, t)
	# Сонце 0.9 + амбієнт 0.35. Раніше стояло 1.1 і 0.55, і в коментарі тут писало, що
	# «разом середні тони не виходять за 1.0» — вимірювання це спростувало: піщана плитка
	# дороги #E9CF8A множилась на 1.65 і обрізалась у БІЛИЙ. Через це вся картина виглядала
	# вицвілою, а найяскравіші поверхні втрачали колір повністю.
	var energy := lerpf(0.9, 0.6, t)
	if bool(level.get("night", false)):
		c = c.darkened(0.55).lerp(Palette.SKY_NIGHT, 0.5)
		energy = 0.45
	if env.environment:
		env.environment.background_color = c
		env.environment.ambient_light_color = c.lightened(0.35).lerp(Palette.WHITE, 0.45)
		env.environment.fog_light_color = c.lightened(0.2)
		env.environment.ambient_light_energy = AMBIENT_ENERGY * _light_k
		# Декор відтворює навколишнє світло випроміненням (Quality.AMBIENT_EMIS), тож після
		# КОЖНОЇ зміни освітлення світу треба віддати йому нові числа. Інакше вечірній рівень
		# носив би навколишнє світло полудня — і помилку було б видно не як збій, а як
		# «щось із кольором не так», тобто найдовше.
		if track != null and track.has_method("set_ambient_light"):
			track.set_ambient_light(env.environment.ambient_light_color,
				env.environment.ambient_light_energy)
	sun.light_energy = energy * _light_k
	sun.light_color = Palette.WHITE.lerp(Palette.SUN_EVENING, t)
	var want_fireflies := t > 0.6 or bool(level.get("night", false))
	if want_fireflies and _fireflies == null:
		_fireflies = FX.ambient(ambient_root, "fireflies")
	elif not want_fireflies and _fireflies != null:
		_fireflies.queue_free()
		_fireflies = null


func _set_ambient() -> void:
	if _ambient:
		_ambient.queue_free()
		_ambient = null
	if _weather:
		_weather.queue_free()
		_weather = null
	var kind := String(season.get("particles", ""))
	if kind == "":
		kind = "petals"
	if world_id == "clouds":
		kind = "stars"
	elif world_id == "beach":
		kind = "glints"   # відблиски моря
	elif world_id == "forest" and String(season.get("particles", "")) == "":
		kind = "leaves"
	if kind != "":
		_ambient = FX.ambient(ambient_root, kind)
	if bool(level.get("rain", false)):
		_weather = FX.ambient(ambient_root, "rain")


# ---------- стани ----------

func _enter_menu(instant: bool) -> void:
	state = State.MENU
	get_tree().paused = false
	if _countdown_tw:
		_countdown_tw.kill()
		_countdown_tw = null
	hud.hide_finish()
	hud.hide_station()
	hud.hide_pause()
	_close_diorama()
	_hide_magpie()
	controls.set_arrows_visible(false)
	controls.stick_hide()
	spawner.spawning = false
	spawner.clear()
	events_spawner.events_enabled = false
	_end_all_pickups()
	hero.stand()
	hero.set_ground(0.0)
	hero.set_running(false)
	hero.visible = true
	hero.face_camera(true, 0.0 if instant else 0.5)
	hud.set_gameplay_visible(false)
	camera_rig.apply(CameraRig.PRESET_MENU, 0.0 if instant else 0.8)
	menu.show_menu()
	AudioMgr.music("menu")
	get_tree().create_timer(0.6).timeout.connect(func():
		if state == State.MENU:
			hero.wave_hello()
			_daily_gift())


## Подарунок дня: +30 зірочок при першому запуску за день, без таймерів «повернись» (GDD §7).
func _daily_gift() -> void:
	var today := Time.get_date_string_from_system()
	if String(SaveService.child().get("last_gift_day", "")) == today:
		return
	SaveService.child()["last_gift_day"] = today
	Events.star_collected.emit(30)
	SaveService.save_game()
	hud.flash("+30 подарунок дня!", 1.8, Palette.FLASH_REWARD)
	FX.confetti(self, Vector3(0, 1.2, 0), 70)
	hero.cheer()
	AudioMgr.sfx("confetti")
	AudioMgr.voice("gift")


## «Біжимо!» веде не на мапу, а додому — у дім-діораму світу (GDD v1.4 §10).
## Якщо діорами ще нема (інший агент), падаємо назад на стару поведінку.
func _on_play() -> void:
	if state != State.MENU:
		return
	menu.hide_menu()
	if _has_diorama():
		_enter_home()
	elif bool(profile.get("skip_map", false)):
		_start_level(lm.current())
	else:
		_open_map()


## Кнопка «Мапа» в меню — єдиний вхід на мапу.
func _on_menu_map() -> void:
	if state != State.MENU:
		return
	menu.hide_menu()
	_open_map()


# ---------- дім-діорама (GDD v1.4 §10) ----------

## Контракт діорами (src/run3d/diorama.gd, клас Diorama):
##   open(world_id: String, lm: LevelManager) · close()
##   сигнали play_level(num: int) · world_selected(world_id: String) · closed()
func _has_diorama() -> bool:
	return is_instance_valid(diorama) and diorama.has_method("open") and diorama.has_method("close")


func _wire_diorama() -> void:
	if not is_instance_valid(diorama):
		return
	if diorama.has_signal("play_level"):
		diorama.connect("play_level", Callable(self, "_start_level"))
	if diorama.has_signal("world_selected"):
		diorama.connect("world_selected", Callable(self, "_on_diorama_world"))
	if diorama.has_signal("closed"):
		diorama.connect("closed", Callable(self, "_on_diorama_closed"))


## Дім: діорама показує світ і рівні, у неї власний герой — нашого ховаємо.
func _enter_home() -> void:
	if not _has_diorama():
		_open_map()
		return
	state = State.HOME
	get_tree().paused = false
	if _countdown_tw:
		_countdown_tw.kill()
		_countdown_tw = null
	hud.hide_finish()
	hud.hide_pause()
	hud.set_gameplay_visible(false)
	menu.hide_menu()
	controls.set_arrows_visible(false)
	controls.stick_hide()
	spawner.spawning = false
	spawner.clear()
	events_spawner.events_enabled = false
	_end_all_pickups()
	_hide_magpie()
	hero.set_running(false)
	hero.visible = false
	# дім відкриваємо на біомі поточного рівня; далі стрілки крутять лише _home_world
	_home_world = world_id
	diorama.call("open", _home_world, lm)


func _close_diorama() -> void:
	if _has_diorama():
		diorama.call("close")


## Стрілки в домі гортають світи діорами. world_id НЕ чіпаємо: він каже, який біом уже стоїть
## на трасі, і _start_level за ним вирішує, чи перебудовувати дорогу (інакше рівень Пляжу побіг би Лужком).
func _on_diorama_world(id: String) -> void:
	if worlds.has(id):
		_home_world = id


func _on_diorama_closed() -> void:
	if state == State.HOME:
		_enter_menu(false)


func _open_map() -> void:
	state = State.MAP
	get_tree().paused = false
	hud.hide_finish()
	hud.hide_pause()
	_close_diorama()
	_hide_magpie()
	hero.visible = true
	hud.set_gameplay_visible(false)
	controls.set_arrows_visible(false)
	spawner.spawning = false
	events_spawner.events_enabled = false
	map_screen.open(lm, worlds, hero.color)


func _on_map_closed() -> void:
	if state == State.MAP:
		_enter_menu(false)


## Старт рівня num: біом, доріжки, складність, туторіал → відлік.
## Показовий вхід пускає в будь-який рівень. Прапорець, а не правка прогресу: збереження
## дитини лишається недоторканим, і без змінної оточення гра поводиться рівно як раніше.
var _demo_any_level := false
var _perf_power_t := 0.0


func _start_level(num: int) -> void:
	if not _demo_any_level and not lm.get_level(num).is_empty() and not lm.is_open(num):
		# рівень не куплений / попередній не пройдено (GDD v1.3 §3a) — на мапу, там купують за зірочки
		_open_map()
		return
	# Меню ховаємо ТУТ, а не в _on_play(). Інваріант простий: коли рівень почався, меню не
	# на екрані — хай яким шляхом ми сюди прийшли. Раніше hide_menu() кликав лише _on_play(),
	# тож усі інші входи лишали меню поверх гри: демо-вхід через LEVEL=n, перехід на
	# наступний рівень після фінішу й налагоджувальна клавіша L. Найдорожче це коштувало
	# під час першого огляду рівнів 2–17: напис «Біжимо!/Герої/Мапа» висів посеред кожного
	# знімка, і центр кадру подивитись було неможливо.
	if menu != null:
		menu.hide_menu()
	lm.set_current(num)
	level_num = num
	level = lm.get_level(num)
	if level.is_empty():
		level = lm.get_level(1)
		level_num = 1
	state = State.COUNTDOWN
	get_tree().paused = false
	hud.hide_finish()
	hud.hide_pause()
	_close_diorama()
	hud.set_gameplay_visible(true)
	lanes = LevelManager.lanes_for(level, profile, 0.0)
	_lanes_changed = false
	level_t = 0.0
	level_distance_m = 0.0
	level_duration = float(level.get("duration_sec", 90))
	_slow = 1.0
	_sprint_announced = false
	_gate_spawned = false
	_tutorial_action = ""
	# v1.3: серця, зірочки рівня, пікапи — з нуля; v1.6 §3c: заряд суперсили теж
	_end_all_pickups()
	level_coins = 0
	hud.set_tally(0)
	power_charge = 0
	hud.set_power(power_id(), hero.color)
	hud.set_power_interactive(not _power_auto())
	_update_power_hud()
	# v1.4: множник, серія без ударів, сорока
	streak_no_hit = 0
	_stolen = false
	_mult = 0        # 0 — щоб _update_multiplier() гарантовано оновив HUD
	_mult_base = 1
	_update_multiplier()
	hero.stand()
	hero.set_ground(0.0)
	# характеристики героя (GDD v1.3 §5): серця й швидкість — тут, магніт — після _enter_world (configure скидає його)
	var st := HeroSelect.stats_of(heroes, hero.hero_id)
	hero.max_hearts = int(st.hearts)
	hud.set_max_hearts(hero.max_hearts)   # ряд сердець під героя (3 або 4)
	_hero_speed = float(st.speed)
	_hero_magnet = float(st.magnet)
	hero.reset_hearts()
	Events.hearts_changed.emit(hero.hearts)
	hud.set_speed(0.0)
	var learned = SaveService.child().get("learned", {})   # батьки могли скинути підказки
	_learned = learned if typeof(learned) == TYPE_DICTIONARY else {}
	var wid := String(level.get("world", "meadow"))
	# той самий біом і та сама ширина — дорогу не перебудовуємо (без «перескоку» декору)
	_enter_world(wid, wid == world_id, not (wid == world_id and lanes == track.lanes))
	spawner.magnet = float(profile.get("star_magnet", 1.0)) * _hero_magnet
	# TODO(v1.3 §5): st.luck — частота пікапів живе у Spawner3D._schedule_pickup (Pickup3D.per_minute_total), множника ще нема
	spawner.set_level(level.get("obstacle_types", []), float(level.get("density", 1.0)), lanes, bool(level.get("tutorial", false)))
	_chunk_loader = LevelChunkLoader.new()
	# Рівень, розставлений У СЦЕНІ: процедурний декор вимкнено, усе кладуть маркери.
	# Поверхні траси (дорога, узбіччя, канал, вода) лишаються процедурними завжди —
	# див. docs/tasks/authored-levels.md.
	track.authored_only = bool(level.get("authored", false))
	_chunk_loader.start(level_num, track, spawner, level)
	spawner.spawning = false
	events_spawner.allowed_ids = level.get("events", [])
	events_spawner.events_enabled = false
	_setup_magpie()
	quests.start_segment(AgeAdapt.current)
	hud.set_quest(quests.icon_kind(), 0, quests.target())
	hud.set_world("%d · %s" % [level_num, String(level.get("name_uk", ""))])
	camera_rig.apply(camera_for_lanes(world.get("camera", {}), lanes), 0.8)
	hero.visible = true
	hero.cheer()
	hero.face_camera(false, 0.6)
	get_tree().create_timer(0.6).timeout.connect(func():
		if state == State.COUNTDOWN or state == State.RUN:
			hero.set_running(true))
	AudioMgr.voice("level_%d" % level_num)
	# Прогрів шейдерів частинок саме тут: відлік триває 2,6 с, герой уже в кадрі, гри ще
	# нема. Без цього перший пил з-під лап коштував 34 мс замість 5 — і це було видно як
	# заїкання на самому початку рівня (виміряно: tools/perf/fx_bench.tscn).
	FX.preheat(self, hero.position + Vector3(0.0, 0.4, 0.0))
	if _countdown_tw:
		_countdown_tw.kill()
	_countdown_tw = create_tween()
	_countdown_tw.tween_interval(0.5)
	for i in range(3):
		_countdown_tw.tween_callback(hud.flash.bind(str(3 - i), 0.7, Palette.FLASH_COUNT))
		_countdown_tw.tween_callback(AudioMgr.sfx.bind("count"))
		_countdown_tw.tween_interval(0.7)
	_countdown_tw.tween_callback(_start_run)




func _start_run() -> void:
	state = State.RUN
	hud.flash("Біжимо!", 0.9, Palette.FLASH_GO)
	AudioMgr.voice("go")
	spawner.spawning = true
	events_spawner.events_enabled = true
	controls.set_arrows_visible(_arrows_on())
	_idle_t = 0.0
	if not SessionTimer.running:
		var minutes := float(SaveService.setting("session_minutes", 10))
		session_total = maxf(60.0, minutes * 60.0)
		SessionTimer.start(minutes)
	AudioMgr.music(String(world.get("music", "")))


func _on_heroes() -> void:
	if state != State.MENU:
		return
	state = State.HEROES
	menu.hide_menu()
	hero.visible = false
	camera_rig.apply(CameraRig.PRESET_HEROES, 0.7)
	hero_select.open(camera_rig.cam, hero.hero_id)


func _on_hero_chosen(id: String) -> void:
	_apply_hero(id)


func _on_heroes_closed() -> void:
	if state == State.HEROES:
		Shop.apply_to(hero)   # аксесуари могли одягнути без вибору героя
		_enter_menu(false)


# ---------- фініш рівня ----------

func _finish() -> void:
	state = State.FINISH
	get_tree().paused = true
	controls.set_arrows_visible(false)
	controls.stick_hide()
	hero.set_duck(false)
	hero.set_running(false)
	events_spawner.reset()
	_end_all_pickups()
	_hide_magpie()
	# злитки рівня стають справжніми лише тут
	SaveService.add_stars(level_coins)
	level_coins = 0
	hud.set_tally(0)
	# GDD v1.4 §3: зірки рівня = серця, що лишились (3/2/1, мінімум 1) — LevelManager.stars_for
	# лишився чистою функцією для тестів, але у грі більше не використовується
	var stars := Rules.stars_from_hearts(hero.hearts)
	var record := lm.complete(level_num, stars)
	SaveService.add_stars(Rules.finish_bonus(level_num, stars))
	SaveService.child()["checkpoints"] = int(SaveService.child().get("checkpoints", 0)) + 1
	SaveService.save_game()
	Stats.inc("levels_finished")
	Stats.inc("level_%d_stars_%d" % [level_num, stars])
	Stats.flush()
	AudioMgr.sfx("station")
	AudioMgr.voice("level_done" if stars < 3 else "three_stars")
	FX.confetti(self, Vector3(0, 1.2, 0), 60 + 30 * stars)
	Events.checkpoint_reached.emit(level_num)   # AgeAdapt приймає рішення між рівнями
	_finish_auto_t = -20.0   # авто-«Далі» лише після колеса
	if stars >= 3:
		# три зірочки — герой розвертається до камери й танцює (GDD v1.6 §5),
		# ще до каскаду нагород: колесо крутиться через 1,2 с
		hero.face_camera(true, 0.5)
		hero.dance()
	if record and stars == 3:
		hud.flash("Три зірочки!", 1.4, Palette.FLASH_REWARD)
	# колесо станції → потім панель із зірками
	_pending_finish = {"stars": stars}
	get_tree().create_timer(1.2).timeout.connect(func():
		if state == State.FINISH:
			wheel.spin())


func _on_wheel_finished(reward: Dictionary) -> void:
	if state != State.FINISH:
		return
	var stars_won := int(reward.get("stars", 0))
	var hat := String(reward.get("hat", ""))
	if stars_won > 0:
		Events.star_collected.emit(stars_won)
	if hat != "":
		Hats.grant(hat)
		Hats.equip(hat)
		Shop.apply_to(hero)
		FX.confetti(self, Vector3(0, 1.2, 0), 60)
	SaveService.save_game()
	_finish_auto_t = 0.0
	hud.show_finish(level_num, int(_pending_finish.get("stars", 1)), _on_finish_next, _open_map, not bool(profile.get("skip_map", false)))


## Кінець каскаду нагород (GDD v1.4 §10): усі — і малята — повертаються додому, у діораму.
## Наступний рівень малятам купується сам, щоб дім одразу пропонував його.
func _on_finish_next() -> void:
	if state != State.FINISH:
		return
	get_tree().paused = false
	hud.hide_finish()
	var next := mini(level_num + 1, lm.count())
	if level_num < lm.count() and bool(profile.get("skip_map", false)):
		if not lm.is_open(next) and lm.can_buy(next) and SaveService.stars() >= lm.price_of(next):
			lm.buy(next)
			hud.flash("Новий рівень!", 1.2, Palette.FLASH_REWARD)
	if _has_diorama():
		_enter_home()
		return
	# діорами ще нема — стара поведінка: далі рівень або мапа
	if level_num >= lm.count() or not lm.is_open(next):
		_open_map()
		return
	_start_level(next)


# ---------- цикл ----------

func _process(delta: float) -> void:
	if _parents_open():
		return
	match state:
		State.SLEEP, State.PAUSED, State.HOME:
			return
		State.MENU, State.HEROES, State.MAP, State.COUNTDOWN:
			# дорога повільно їде під меню / відліком
			var d := MENU_SPEED * delta
			level_distance_m += d
			track.advance(d, level_distance_m)
			spawner.advance(d, level_distance_m)
			_chunk_loader.update(level_distance_m)
			return
		State.FINISH:
			# малюк не тисне «Далі» — гра йде далі сама
			_finish_auto_t += delta
			if _finish_auto_t > FINISH_AUTO_NEXT_SEC and bool(profile.get("skip_map", false)):
				_on_finish_next()
			return
	if switching:
		return
	level_t += delta
	session_t += delta
	var progress := clampf(level_t / level_duration, 0.0, 1.0)
	# розширення дороги посеред рівня — «фішка»
	if not _lanes_changed and level.has("lanes_to") and progress >= float(level.get("lanes_at", 0.5)):
		_lanes_changed = true
		_change_lanes(LevelManager.lanes_for(level, profile, progress))
	# складність: профіль × рівень × розгін до фінішу (+35%) × спринт × сповільнення туторіалу × равлик
	if _slow < 1.0:
		_slow_t -= delta
		if _slow_t <= 0.0:
			_slow = 1.0
	var sprint := 1.0
	if progress >= SPRINT_FROM:
		sprint = SPRINT_MULT
		if not _sprint_announced:
			_sprint_announced = true
			hud.flash("Фініш близько!", 1.0, Palette.FLASH_RETRY)
			AudioMgr.voice("finish_soon")
	speed = base_speed * _hero_speed * float(level.get("speed_mult", 1.0)) * (1.0 + SPEED_RAMP * progress) * sprint * _slow * _pickup_speed * _potion_speed
	mode.speed = speed
	# анімація героя (GDD v1.6 §5): спринт — супернапій або фінішний ривок; кульгає —
	# останнє серце чи перші 3 с після удару. Пріоритет станів вирішує сам Hero3D
	# (HIT > ROCKET > CHARGE > SPRINT > LIMP > RUN).
	if _limp_t > 0.0:
		_limp_t = maxf(0.0, _limp_t - delta)
	hero.set_sprint(_effects.has("potion") or progress >= SPRINT_FROM)
	hero.set_limp(hero.hearts <= 1 or _limp_t > 0.0)
	spawner.set_speed(speed)
	# ЧАСТОТА ходи від швидкості НЕ залежить (фіксовані каденції, GDD v1.7 — 4+ Гц виглядали
	# неприродно): звідси герой бере лише ±10 % розмаху кроку (Hero3D.speed_amp_k)
	hero.set_speed_mps(speed)
	hud.set_speed(speed)
	_tick_pickups(delta)
	_tick_power(delta)
	_update_multiplier()
	_tick_magpie(delta)
	# ворота фінішу — за 6 с до кінця, один раз
	if not _gate_spawned and level_duration - level_t <= GATE_BEFORE_SEC:
		_gate_spawned = true
		spawner.spawn_finish_gate()
	if _pressed and Gestures.hold_started(_held_sec(), _swiped or _stick_used, _holding):
		_holding = true
		mode.gesture("hold_start", _cur_pos)
	mode.steer(_pressed and not _swiped, _cur_pos)
	var dist := mode.tick(delta)
	if absf(dist) > 0.0:
		level_distance_m += dist
		track.advance(dist, level_distance_m)
		spawner.advance(dist, level_distance_m)
		_chunk_loader.update(level_distance_m)
	# камера живе разом із героєм: кладеться в поворот, відстає на маневрі, провисає під
	# стрибком. Сигнал один — скільки героєві лишилось до своєї доріжки (див. CameraRig.drive)
	camera_rig.drive(delta, hero.position.x, hero.x_target - hero.position.x,
		hero.vy(), Hero3D.LANE_W)
	# Автозапуск суперсили для замірів: натиснути кнопку зі скрипта неможливо, а саме в цю
	# мить гра й завмирала. PERF_POWER=1 стріляє нею раз на 5 секунд, і perf_overlay ловить
	# найдовший кадр — тобто затримку видно числом, а не на відчуття.
	if OS.get_environment("PERF_POWER") != "":
		_perf_power_t += delta
		if _perf_power_t > 5.0:
			_perf_power_t = 0.0
			power_charge = 9999
			activate_power()
	spawner.check(delta)
	events_spawner.tick(delta)
	_hint(delta)
	_quest_tick()
	_set_sky(clampf(session_t / session_total, 0.0, 1.0))
	if level_t >= level_duration:
		_finish()


func _change_lanes(n: int) -> void:
	if n == lanes:
		return
	var wider := n > lanes
	lanes = n
	track.set_lanes(n, true)
	hero.set_lanes(n)
	spawner.lanes = n
	camera_rig.apply(camera_for_lanes(world.get("camera", {}), n), 0.9)
	hud.flash("Ширше!" if wider else "Вужче!", 1.0, Palette.FLASH_WIDTH)
	AudioMgr.voice("wider")


func _held_sec() -> float:
	return (Time.get_ticks_msec() - _press_time) / 1000.0 if _press_time >= 0.0 else 0.0


func _parents_open() -> bool:
	return is_instance_valid(hud) and bool(hud.get("parents_open"))


func _hero_screen_hit(pos: Vector2) -> bool:
	var sp := camera_rig.cam.unproject_position(hero.global_position + Vector3(0, 0.6, 0))
	return sp.distance_to(pos) < 130.0


# ---------- керування ----------

## Дебаг (лише debug-збірка): 1..5 — біом на льоту, L — наступний рівень, S — фініш зараз,
## F — веселка, R — друг, Q — завдання, M — мапа, E — суперсила героя негайно,
## D — присід (ковзання) вмикається/вимикається.
## D БІЛЬШЕ НЕ КЛИЧЕ ДРУГА: на playtest 09.09 Nick тиснув D, чекаючи присід, і за хвилину
## на дорозі стояла колона друзів. Дебаг-клавіша не має ділити літеру з ігровою дією.
func _debug_key(event: InputEventKey) -> void:
	if not OS.is_debug_build() or not event.pressed or event.echo:
		return
	var world_keys := {KEY_1: "meadow", KEY_2: "forest", KEY_3: "beach", KEY_4: "city", KEY_5: "clouds"}
	if world_keys.has(event.keycode) and state == State.RUN and worlds.has(world_keys[event.keycode]):
		switching = true
		_enter_world(String(world_keys[event.keycode]), false)
		get_tree().create_timer(WORLD_SWITCH_SEC).timeout.connect(func(): switching = false)
	elif event.keycode == KEY_S and state == State.RUN:
		_finish()
	elif event.keycode == KEY_L and state == State.RUN:
		_start_level(mini(level_num + 1, lm.count()))
	elif event.keycode == KEY_M and state == State.RUN:
		_open_map()
	elif event.keycode == KEY_F and state == State.RUN:
		events_spawner.force("rainbow")
	elif event.keycode == KEY_R and state == State.RUN:
		events_spawner.force("friend")
	elif event.keycode == KEY_D and state == State.RUN:
		hero.set_duck(not hero.ducking)
	elif event.keycode == KEY_Q and state == State.RUN:
		Events.quest_completed.emit("debug", 10)
	elif event.keycode == KEY_W and state == State.RUN:
		_change_lanes(7 if lanes < 7 else 3)
	elif event.keycode == KEY_H and state == State.RUN:
		# дебаг: втратити серце (нуль сердець ловить _on_hearts_changed — прилітає сорока)
		if hero.lose_heart():
			Events.hearts_changed.emit(hero.hearts)
	elif event.keycode == KEY_E and state == State.RUN:
		# дебаг: заряджаємо силу до повної й одразу вмикаємо
		power_charge = power_needed()
		_update_power_hud()
		activate_power()
	elif event.keycode == KEY_P and state == State.RUN:
		# дебаг: випадковий пікап негайно
		var kinds: Array = (Pickup3D.load_all().get("kinds", {}) as Dictionary).keys()
		if not kinds.is_empty():
			var k := String(kinds[randi() % kinds.size()])
			on_pickup(k, Pickup3D.def_of(k))


## Жест від будь-якого джерела (свайп / стрілка / джойстик) — одна точка входу.
func _gesture(kind: String, pos: Vector2 = Vector2.ZERO) -> void:
	if state != State.RUN or switching:
		return
	mode.gesture(kind, pos)
	_idle_t = 0.0
	Events.gameplay_input.emit()
	_tutorial_register(kind)


func _on_control_action(kind: String) -> void:
	_gesture(kind, Vector2.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_debug_key(event)
		return
	if state == State.SLEEP or _parents_open():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_pressed = true
			_press_time = Time.get_ticks_msec()
			_press_pos = event.position
			_cur_pos = event.position
			_swiped = false
			_stick_used = false
			_holding = false
			_idle_t = 0.0
			Events.player_input.emit()
			match state:
				State.MENU:
					_pressed = false
					if _hero_screen_hit(event.position):
						hero.pet()
					return
				State.HEROES:
					_pressed = false
					hero_select.tap(event.position)
					return
				State.FINISH:
					_pressed = false
					hero.pet()
					return
				State.COUNTDOWN, State.MAP, State.HOME, State.PAUSED:
					_pressed = false
					return
			if _joystick_on():
				controls.stick_show(event.position)
		else:
			var g := Gestures.on_release(_held_sec(), _swiped or _stick_used)
			_pressed = false
			_press_time = -1.0
			_holding = false
			controls.stick_hide()
			if g != "":
				_gesture(g, event.position)
	elif event is InputEventScreenDrag and _pressed:
		_cur_pos = event.position
		var off := _cur_pos - _press_pos
		if _joystick_on() and state == State.RUN:
			controls.stick_update(off)
		if _swiped:
			# джойстик: повернув палець до центру — можна відхиляти ще раз
			if off.length() < STICK_REARM_PX:
				_swiped = false
				_press_time = Time.get_ticks_msec()
			return
		var d := Gestures.swipe_dir(_press_pos, _cur_pos)
		if d != "":
			_swiped = true
			_stick_used = true
			if state == State.HEROES:
				hero_select.move(1 if d == "swipe_left" else (-1 if d == "swipe_right" else 0))
				return
			if _holding:
				_holding = false
				mode.gesture("hold_end", _cur_pos)
			_gesture(d, _cur_pos)


func _release_assist_duck() -> void:
	if not _holding:
		hero.set_duck(false)


## Падіння героя — тряска камери.
func on_tumble() -> void:
	camera_rig.shake(0.1)
	camera_rig.punch(1.0)


## Злитки під час бігу йдуть у лічильник рівня (у SaveService — на фініші); поза бігом (подарунок, колесо) — одразу.
## Множник: n уже помножено спавнером на пікап «×2», тому тут домножуємо лише «чисту» частину.
func _on_star_collected(n: int) -> void:
	if state == State.RUN:
		var gain := n * _mult_base
		level_coins += gain
		hud.set_tally(level_coins)
		# суперсила заряджається від САМИХ злитків, без множника рівня — інакше на 10-му
		# рівні кнопка була б повна з першої лінії (GDD v1.6 §3c)
		_charge_power(mini(n, POWER_CHARGE_PER_PICKUP))
		var screen := camera_rig.cam.unproject_position(hero.global_position + Vector3(0, 0.8, 0))
		hud.fly_star(screen)
		# великий злиток «+100» — спливаючий напис біля героя (реф. §4)
		if n >= Spawner3D.BIG_VALUE:
			hud.pop_text(screen + Vector2(0, -70), "+%d×%d" % [n, _mult_base])
	else:
		SaveService.add_stars(n)


# ---------- множник злитків (GDD v1.4 §10) ----------

## mult = 1 + серія_без_удару / 10, стеля ×3, ×2 з пікапом «×2» (EDD §2; номер рівня не бере участі).
func _update_multiplier() -> void:
	var x2 := _effects.has("coin2")
	var base := Rules.multiplier(level_num, streak_no_hit, false)
	var shown := Rules.multiplier(level_num, streak_no_hit, x2)
	_mult_base = base
	if shown != _mult:
		_mult = shown
		hud.set_multiplier(shown)
		Events.multiplier_changed.emit(shown)


func _on_obstacle_passed(_kind: String) -> void:
	if state == State.RUN:
		streak_no_hit += 1


func _on_hero_tumbled(_kind: String) -> void:
	streak_no_hit = 0
	_limp_t = LIMP_AFTER_HIT_SEC     # 3 с кульгає (анімація limp, GDD v1.6 §5)


# ---------- життя: серця → зірки, сорока замість перезапуску (GDD v1.4 §3) ----------

## Серця змінились. Нуль — сорока краде 30 % злитків, але не більше 150 (один раз), далі −10% за удар.
## Сердечко-пікап повертає серце — і зірку фінішу разом із ним.
func _on_hearts_changed(hearts: int) -> void:
	if state != State.RUN:
		return
	if hearts > 0:
		_stolen = false
		return
	if not _stolen:
		_stolen = true
		_magpie_steal()
	else:
		_hit_penalty()


## Сорока пікірує й забирає 30 % злитків рівня (стеля 150); герой каже «ой!», біг триває.
func _magpie_steal() -> void:
	var amount := Rules.steal_amount(level_coins)
	level_coins = maxi(0, level_coins - amount)
	hud.tween_tally(level_coins, STEAL_TALLY_SEC)
	hud.flash("Ой! −%d" % amount, 1.2, Palette.FLASH_RETRY)
	AudioMgr.voice("oops_gold")
	Events.coins_stolen.emit(amount)
	Stats.inc("magpie_steals")
	if is_instance_valid(magpie):
		magpie.visible = true
		magpie.steal()


## Кожен наступний удар без сердець: −10% злитків рівня (не менше 0).
func _hit_penalty() -> void:
	var amount := Rules.hit_penalty(level_coins)
	if amount <= 0:
		return
	level_coins = maxi(0, level_coins - amount)
	hud.tween_tally(level_coins, 0.4)
	Events.coins_stolen.emit(amount)


# ---------- сорока-антагоніст (GDD v1.4 §3) ----------

func _make_magpie() -> void:
	magpie = Magpie3D.new()
	magpie.name = "Magpie"
	magpie.hero = hero
	magpie.visible = false
	magpie.box_ready.connect(_on_magpie_box)
	actors.add_child(magpie)


func _setup_magpie() -> void:
	if not is_instance_valid(magpie):
		return
	magpie.hero = hero
	magpie.lanes = lanes
	magpie.set_skin(String(world.get("antagonist", ANTAGONIST_BY_WORLD.get(world_id, "magpie"))))
	# ящики — з 3-го рівня: на перших двох сорока просто літає попереду
	magpie.drops_enabled = level_num >= MAGPIE_FROM_LEVEL
	magpie.position = Vector3(0.0, Magpie3D.FLY_Y, -Magpie3D.AHEAD_MAX)
	magpie.visible = true
	magpie.patrol()
	_magpie_t = randf_range(float(MAGPIE_DROP_INTERVAL[0]), float(MAGPIE_DROP_INTERVAL[1]))


func _hide_magpie() -> void:
	if is_instance_valid(magpie):
		magpie.visible = false
		magpie.drops_enabled = false


func _tick_magpie(delta: float) -> void:
	if not is_instance_valid(magpie) or not magpie.drops_enabled or spawner.finish_pending:
		return
	if magpie.phase != Magpie3D.Phase.PATROL:
		return
	_magpie_t -= delta
	if _magpie_t > 0.0:
		return
	_magpie_t = randf_range(float(MAGPIE_DROP_INTERVAL[0]), float(MAGPIE_DROP_INTERVAL[1]))
	magpie.lanes = lanes
	magpie.warn_drop(spawner.random_lane())


## Тінь виросла — ставимо X-ящик на цю доріжку (перешкода "xbox" є в кожному світі).
func _on_magpie_box(lane: int) -> void:
	if state != State.RUN or spawner.finish_pending:
		return
	var defs: Dictionary = world.get("obstacles", {})
	if not defs.has("xbox"):
		return
	if spawner.has_method("spawn_obstacle_kind"):
		spawner.call("spawn_obstacle_kind", "xbox", lane)
	elif spawner.has_method("_spawn_obstacle"):
		spawner.call("_spawn_obstacle", "xbox", defs["xbox"], lane)
	AudioMgr.sfx("tumble")


# ---------- пауза (GDD v1.4 §10) ----------

var paused_by_button: bool:
	get:
		return state == State.PAUSED


func _on_pause_pressed() -> void:
	# паузу вішаємо лише на біг: під відліком твін відліку не спиняється разом із деревом
	if state != State.RUN:
		return
	_state_before_pause = state
	state = State.PAUSED
	get_tree().paused = true
	controls.stick_hide()
	hud.show_pause()


func _on_resume_pressed() -> void:
	if state != State.PAUSED:
		return
	hud.hide_pause()
	get_tree().paused = false
	state = _state_before_pause


func _on_pause_menu_pressed() -> void:
	if state != State.PAUSED:
		return
	hud.hide_pause()
	_enter_menu(false)


# ---------- пікапи ----------

## Spawner3D: герой підібрав пікап. def — опис із data/pickups.json.
func on_pickup(kind: String, def: Dictionary) -> void:
	if state != State.RUN:
		return
	var sec := float(def.get("seconds", 0.0))
	match kind:
		"snail":
			_pickup_speed = float(def.get("speed_mult", 0.6))
		"potion":
			# супернапій: розганяє й вмикає анімацію спринту (див. _process)
			_potion_speed = float(def.get("speed_mult", 1.35))
		"heart":
			if hero.gain_heart():
				Events.hearts_changed.emit(hero.hearts)
		"magnet":
			spawner.magnet_wide = true
		"shield":
			hero.set_shield(true)
		"jetpack":
			hero.fly(sec)
			spawner.spawn_star_arc(Hero3D.FLY_HEIGHT + 0.4, 6, hero.lane)
		"coin2":
			spawner.coin_mult = int(def.get("coin_mult", 2))
	if sec > 0.0:
		_effects[kind] = sec
	# HUD показує пікап сам — він підписаний на Events.pickup_started(kind, seconds)
	Events.pickup_started.emit(kind, sec)
	hud.flash(String(def.get("name_uk", kind)), 0.8, Palette.of(def.get("color"), Palette.PICKUP_DEFAULT))
	hero.cheer()
	AudioMgr.voice("wow")


## Spawner3D: щит поглинув удар — ефект закінчується раніше часу.
func on_shield_used() -> void:
	_end_pickup("shield")


func _tick_pickups(delta: float) -> void:
	for k in _effects.keys().duplicate():
		_effects[k] = float(_effects[k]) - delta
		if float(_effects[k]) <= 0.0:
			_end_pickup(String(k))


func _end_pickup(kind: String) -> void:
	match kind:
		"snail": _pickup_speed = 1.0
		"potion": _potion_speed = 1.0
		"magnet": spawner.magnet_wide = false
		"shield": hero.set_shield(false)
		"jetpack": hero.stop_fly()
		"coin2": spawner.coin_mult = 1
	var was_active := _effects.has(kind)
	_effects.erase(kind)
	if was_active:
		Events.pickup_ended.emit(kind)
	# смужка HUD — для того, що ще діє (найдовшого)
	if _effects.is_empty():
		hud.hide_pickup()
	else:
		var best := ""
		var best_t := -1.0
		for k in _effects.keys():
			if float(_effects[k]) > best_t:
				best_t = float(_effects[k])
				best = String(k)
		hud.show_pickup(best, best_t)


func _end_all_pickups() -> void:
	for k in _effects.keys().duplicate():
		_end_pickup(String(k))
	_pickup_speed = 1.0
	_potion_speed = 1.0
	_limp_t = 0.0
	spawner.magnet_wide = false
	spawner.coin_mult = 1
	hero.set_shield(false)
	hero.stop_fly()
	hero.set_sprint(false)
	hero.set_limp(false)
	hud.hide_pickup()
	_end_power()
	power_charge = 0
	_update_power_hud()


# ---------- суперсила героя (GDD v1.6 §3c) ----------

## Опис сили героя id → поле й кнопка HUD. Legacy-героя Hero3D показує як першого нового,
## тож і силу беремо ту саму (resolve_def робить це за нас).
func _apply_power_def(id: String) -> void:
	var def := Hero3D.resolve_def(heroes, id)
	var p = def.get("power", {})
	power_def = p if typeof(p) == TYPE_DICTIONARY else {}
	power_charge = 0
	hud.set_power(power_id(), hero.color)
	hud.set_power_interactive(not _power_auto())
	_update_power_hud()


## id сили поточного героя ("" — герой без сили).
func power_id() -> String:
	return String(power_def.get("id", ""))


## Скільки злитків треба на силу: профіль головніший за дані героя (малятам 60).
func power_needed() -> int:
	return Rules.power_charge_needed(int(profile.get("power_charge", 0)), int(power_def.get("charge", 0)))


## Сила заряджена і зараз не діє.
func power_ready() -> bool:
	return power_id() != "" and _power_id == "" and power_charge >= power_needed()


## Малятам сила вмикається сама (кнопку видно, але тиснути не треба).
func _power_auto() -> bool:
	return bool(profile.get("power_auto", false))


func _update_power_hud() -> void:
	hud.set_power_progress(Rules.power_progress(power_charge, power_needed()))
	hud.power_ready(power_ready())


## Заряд від зібраних злитків (Events.star_collected під час бігу).
func _charge_power(amount: int) -> void:
	if power_id() == "" or _power_id != "" or amount <= 0:
		return
	power_charge = mini(power_needed(), power_charge + amount)
	_update_power_hud()
	if _power_auto() and power_ready():
		activate_power()


## Увімкнути суперсилу. Мовчки нічого не робить, якщо не в бігу, не заряджена або вже діє.
func activate_power() -> void:
	if state != State.RUN or not power_ready():
		return
	if OS.get_environment("PERF_LOG") != "":
		print("СИЛА %s на %.2f с" % [power_id(), Time.get_ticks_msec() / 1000.0])
	_power_id = power_id()
	_power_dur = maxf(0.5, float(power_def.get("duration", 6.0)))
	_power_t = _power_dur
	power_charge = 0
	_power_jump_scale = hero.jump_scale
	# поза розгону: спершу 0,35 с замаху (герой присідає), далі біг із профілем CHARGE;
	# родзинку героя (charge_accent) кличе сам Hero3D — у кінці замаху, рівно один раз
	hero.charge(_power_dur)
	AudioMgr.voice(String(power_def.get("voice", "power_%s" % _power_id)))
	AudioMgr.sfx("boost")
	# ОДИН спалах: кільце (меш, не частинки) плюс один невеликий бурст на 14 частинок.
	# Більше сюди не додаємо — playtest 09.09: «частинок купа, а анімації не видно»
	FX.ring(hero, Vector3(0.0, 0.12, 0.0), hero.color)
	FX.burst(hero, Vector3(0.0, 0.8, 0.0), hero.color)
	hud.power_fired()
	hud.set_power_active(1.0)
	hud.flash(String(power_def.get("name_uk", "")), 0.9, hero.color)
	Stats.inc("power_%s" % _power_id)
	match _power_id:
		"fox_leap":
			hero.jump_scale = _power_jump_scale * FOX_JUMP_SCALE
			spawner.power_coin_mult = FOX_COIN_MULT
			spawner.power_coin_air_only = true
		"deer_charge":
			spawner.break_obstacles = true
		"dog_sniff":
			spawner.magnet_wide = true
			spawner.magnet = _base_magnet() * DOG_MAGNET
		"bunny_double":
			hero.double_jump = true
			if is_instance_valid(magpie):
				magpie.drops_enabled = false   # поки зайчик стрибає, сорока не кидає ящиків
		"cat_lives":
			hero.max_hearts = mini(CAT_MAX_HEARTS, hero.max_hearts + 1)
			hud.set_max_hearts(hero.max_hearts)
			# ряд сердець уже перебудований під новий максимум — далі його наповнить сигнал
			var _got: bool = hero.gain_heart()
			Events.hearts_changed.emit(hero.hearts)
			spawner.absorb_hits = 1
		"bear_hug":
			spawner.absorb_hits = BEAR_ABSORB
			spawner.power_coin_mult = BEAR_COIN_MULT
			hero.set_shield(true)
		"unicorn_rainbow":
			spawner.pull_all_ingots(RAINBOW_PULL_SEC)
			hero.set_invulnerable(RAINBOW_INVULN_SEC)
			_rainbow_trail()   # іскри від рога вже насипав charge() через charge_accent()
		"dolphin_wave":
			spawner.pull_all_ingots(DOLPHIN_PULL_SEC)
		"turtle_shield":
			spawner.absorb_hits = TURTLE_ABSORB
			hero.set_shield(true)


## Веселковий слід єдинорога: кілька смуг кольорами Palette.RAINBOW, зсунутих по висоті.
## Кожна смуга РІДКА (8 частинок × 0,8 с ≈ 10 на секунду): три смуги разом дають стільки ж,
## скільки один звичайний слід, — інакше екран заливало частинками.
const RAINBOW_TRAIL_AMOUNT := 8


func _rainbow_trail() -> void:
	var i := 0
	while i < Palette.RAINBOW.size():
		var tr := FX.trail(hero, Palette.RAINBOW[i], RAINBOW_TRAIL_AMOUNT)
		tr.position = Vector3(0.0, 0.22 + 0.12 * float(i / RAINBOW_TRAIL_STEP), 0.3)
		_power_trails.append(tr)
		i += RAINBOW_TRAIL_STEP


## Базовий радіус магніта (профіль × характеристика героя) — без пікапів і сили.
func _base_magnet() -> float:
	return float(profile.get("star_magnet", 1.0)) * _hero_magnet


func _tick_power(delta: float) -> void:
	if _power_id == "":
		return
	_power_t -= delta
	hud.set_power_active(clampf(_power_t / maxf(0.01, _power_dur), 0.0, 1.0))
	if _power_t <= 0.0:
		_end_power()


## Кінець сили: усі прапорці й множники назад, заряд збирається наново.
func _end_power() -> void:
	for tr in _power_trails:
		if is_instance_valid(tr):
			tr.emitting = false
			tr.queue_free()
	_power_trails.clear()
	if _power_id == "":
		return
	var was := _power_id
	_power_id = ""
	_power_t = 0.0
	hero.jump_scale = _power_jump_scale
	hero.double_jump = false
	spawner.reset_power()
	# пікапи «магніт» і «щит» могли діяти паралельно — їхнє не знімаємо
	if not _effects.has("magnet"):
		spawner.magnet_wide = false
	spawner.magnet = _base_magnet()
	if (was == "bear_hug" or was == "turtle_shield") and not _effects.has("shield"):
		hero.set_shield(false)
	if is_instance_valid(magpie):
		magpie.drops_enabled = level_num >= MAGPIE_FROM_LEVEL and state == State.RUN
	power_charge = 0
	hud.power_reset()
	_update_power_hud()


## Spawner3D: суперсила поглинула удар (left — скільки ще лишилось).
func on_hit_absorbed(left: int) -> void:
	hud.flash("Тримаюсь!" if left > 0 else "Ух!", 0.7, Palette.FLASH_REWARD)
	hero.cheer()
	if left <= 0 and (_power_id == "bear_hug" or _power_id == "turtle_shield"):
		hero.pop_shield()


# ---------- туторіал і підказки ----------

const ACTION_HINT := {
	"jump": ["up", "Стрибни!", "hint_jump"],
	"duck": ["down", "Присядь!", "hint_duck"],
	"side": ["left", "Убік!", "hint_side"],
}


## Spawner повідомляє про перший спавн типу перешкоди на рівні з туторіалом.
func tutorial_obstacle(kind: String, action: String, free_lane: int = 99) -> void:
	if not ACTION_HINT.has(action) or _learned.has(action):
		return
	var eta := mode.seconds_to_hero(-Spawner3D.SPAWN_Z)
	get_tree().create_timer(maxf(0.1, eta - TUTORIAL_LEAD_SEC), false).timeout.connect(_tutorial_prompt.bind(action, free_lane))


func _tutorial_prompt(action: String, free_lane: int = 99) -> void:
	if state != State.RUN or _learned.has(action):
		return
	_tutorial_action = action
	var h: Array = ACTION_HINT[action]
	var gesture_kind := String(h[0])
	# «убік» — у бік вільної доріжки (якщо відома), інакше до центру
	if action == "side":
		if free_lane != 99 and free_lane != hero.lane:
			gesture_kind = "left" if free_lane < hero.lane else "right"
		else:
			gesture_kind = "left" if hero.lane > 0 else "right"
	hud.show_hint(gesture_kind, String(h[1]))
	AudioMgr.voice(String(h[2]))
	_slow = TUTORIAL_SLOW
	_slow_t = 2.0


## Дитина зробила дію сама: після 2 разів підказка для цієї дії більше не показується.
func _tutorial_register(kind: String) -> void:
	if _tutorial_action == "":
		return
	var ok := false
	match _tutorial_action:
		"jump": ok = kind in ["tap", "swipe_up"]
		"duck": ok = kind in ["swipe_down", "hold_start"]
		"side": ok = kind in ["swipe_left", "swipe_right"]
	if not ok:
		return
	_tutorial_count[_tutorial_action] = int(_tutorial_count.get(_tutorial_action, 0)) + 1
	if int(_tutorial_count[_tutorial_action]) >= 2:
		_learned[_tutorial_action] = true
		SaveService.child()["learned"] = _learned
		hero.cheer()
		AudioMgr.voice("praise")
	_tutorial_action = ""
	_slow = 1.0


## Підказка через N секунд бездіяльності — жест поточного режиму.
func _hint(delta: float) -> void:
	if not mode.wants_hint():
		return
	_idle_t += delta
	if _idle_t > float(profile.get("hint_after_sec", 5)):
		match mode.mode_id():
			"slide": hud.show_hint("hold", "Тримай збоку!")
			_: hud.show_hint("tap", "Тап — стрибок!")
		AudioMgr.voice("hint_tap")
		_idle_t = 0.0


func _quest_tick() -> void:
	if quests.current.is_empty():
		return
	var v := quests.progress(spawner.stars_collected_segment, spawner.passed_segment, events_spawner.events_seen_segment)
	if not quests.done:
		hud.set_quest(quests.icon_kind(), v, quests.target())


func _on_quest_completed(_id: String, reward: int) -> void:
	Events.star_collected.emit(reward)
	hud.show_quest_done(reward)
	hero.cheer()
	FX.confetti(hero, Vector3(0, 1.2, 0), 60)
	AudioMgr.sfx("confetti")
	AudioMgr.voice("praise")


## Сумісність із HUD (_run_is_busy).
func _leave_station() -> void:
	pass


var paused_at_station: bool:
	get:
		return state == State.FINISH

var sleeping: bool:
	get:
		return state == State.SLEEP


# ---------- сон ----------

func _on_session_warning(seconds_left: int) -> void:
	if state != State.RUN:
		return
	if seconds_left == 120:
		AudioMgr.voice("yawn")
		hud.show_yawn()
	elif seconds_left == 60:
		AudioMgr.voice("almost_sleep")


func _on_session_finished() -> void:
	if state == State.MENU or state == State.HEROES or state == State.MAP or state == State.HOME:
		return
	state = State.SLEEP
	get_tree().paused = true
	hud.hide_finish()
	controls.set_arrows_visible(false)
	controls.stick_hide()
	hero.set_duck(false)
	hero.set_running(false)
	SaveService.save_game()
	Stats.flush()
	AudioMgr.music("lullaby")
	AudioMgr.voice("goodnight")
	hud.show_sleep(_on_sleep_continue_pressed)


func _on_sleep_continue_pressed() -> void:
	ParentGate.request("settings", _resume_after_sleep)


func _resume_after_sleep() -> void:
	hud.hide_sleep()
	get_tree().paused = false
	session_t = 0.0
	_enter_menu(false)
