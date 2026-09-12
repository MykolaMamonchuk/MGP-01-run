## Герой у 3D — чотирилапе звірятко (GDD v1.5 §5). Стоїть у початку координат, світ рухається на нього (+Z).
## Тіло збирається з вокселів-частин (data/heroes.json → parts): тулуб, голова, чотири лапки, хвіст, двоє вух.
## Голова ≈ 45 % зросту, кубічна морда з кремовим передом і темним носиком — у вокселі голови;
## зіниці з бліком, щічки й рот — окремі меші, тому герой кліпає, дивиться в бік повороту й усміхається.
## Уся анімація процедурна (Tween + sin): 4-тактний крок (задня ліва → передня ліва →
## задня права → передня права, див. gait_phase), боб тіла,
## контр-боб голови, вуха з інерцією, хвіст махає.
## Старі пухнастики v1.4 лишились у heroes.json із "legacy": true — збереження з ними не падають:
## Hero3D показує першого нового героя (див. resolve_def).
##
## СКЕЛЕТНИЙ РЕЖИМ: якщо в героя є поле "rig" (напр. "fox_no_voxel"), тіло малюється не
## вокселями, а справжньою моделлю `res://assets/models/<rig>.glb` зі скелетом — див.
## src/run3d/hero_rig.gd. Це КОМПОНЕНТ усередині Hero3D, а не окремий клас героя, тому
## публічний API (методи, сигнали, поля) і всі виклики з run3d/hero_select/diorama/spawner
## лишаються ті самі. Обличчя (очі, зіниці, щічки, рот) у скелетному режимі теж наше —
## воно висить на кістці голови через BoneAttachment3D, тож кліпання, погляд убік і
## комічна реакція на удар працюють без змін. Нема файлу моделі → тихо малюємо вокселі.
class_name Hero3D
extends Node3D

signal landed
signal tumble_finished

const LANE_W := 1.0
const GRAVITY := 22.0
const HOP_VELOCITY := 4.6
const FLY_HEIGHT := 1.9
const X_FREE_LIMIT := 1.3

## Геометрія звірятка (світові метри, герой стоїть на y = 0).
## Контракт із вокселями — У МЕТРАХ, а не в кількості вокселів (див. tools/voxelize.py):
## лапка 0,225 заввишки, тулуб 0,375 лежить на лапках, голова 0,45 (45 % від 0,98) з глибиною
## 2 × HEAD_HALF_D сидить попереду-вгорі. Скільки вокселів у цих метрах — байдуже
## (0,075 м у ручних моделей, 0,04 м у згенерованих `*_ai`); тест дає допуск в один воксель.
## Частини ставляться ЗА ЦИМИ КОНСТАНТАМИ — габарити мешів ніде не читаються.
const LEG_H := 0.225              ## довжина лапки = висота стегна/плеча
const TORSO_Y := 0.225            ## низ тулуба
const TORSO_Z := 0.05             ## тулуб трохи зсунутий назад — попереду місце під голову
const TORSO_TOP := 0.60
const NECK_Y := 0.53              ## шарнір голови (шия)
const NECK_Z := -0.20
const HEAD_H := 0.45
const HEAD_HALF_D := 0.225
const HEAD_TOP := 0.98            ## маківка (капелюшок) — і майже повний зріст героя
const FACE_Z := -0.425            ## передня грань голови (морда, окуляри)
const HIP_X := 0.15
const HIP_Z_FRONT := -0.14
const HIP_Z_BACK := 0.26
const TAIL_Y := 0.44
const TAIL_Z := 0.34
## Довжина слота хвоста від шарніра назад. Згенерований воксель (`*_ai`) має рівно цю глибину
## (voxelize.py добиває коротший хвіст порожніми рядами), тож меш, який VoxelBuilder центрує
## по z, зсуваємо на пів довжини — і хвіст росте назад від шарніра, а не тоне в тулубі.
const TAIL_LEN := 0.35
const GALLOP_SWING := 0.6         ## розмах лапок на бігу, рад
## ХОДА. Чотири лапки йдуть НЕ риссю, а природним 4-тактним кроком: задня ліва →
## передня ліва → задня права → передня права, рівними чвертями циклу. Таблиця зсувів і
## сама математика живуть у HeroRig (там же вона потрібна кісткам) — тут лише псевдоніми,
## щоб обидва тіла крокували з ОДНОГО джерела.
const GAIT_LOWER_BEND := HeroRig.GAIT_LOWER_BEND   ## згин нижньої ланки лапки в махові, рад (риг)
const GAIT_PAW_LIFT := HeroRig.GAIT_PAW_LIFT       ## підйом воксельної лапки в махові, м
const GAIT_HIP_ROLL := HeroRig.GAIT_HIP_ROLL       ## крен корпусу на частоті кроку, рад
const GAIT_SPINE_FLEX := HeroRig.GAIT_SPINE_FLEX   ## хвиля хребта на подвоєній частоті, рад
const GAIT_TAIL_YAW := HeroRig.GAIT_TAIL_YAW       ## відмах хвоста проти крену, рад
## Комічне зіткнення (GDD v1.4 §2): очі ×1,4, зіниці ×0,6, зсув на пів доріжки,
## оберт ±0,5 рад із поверненням за 0,5 с, 3 зірочки над головою 1,2 с, невразливість 1,5 с.
const HIT_EYE_SCALE := 1.4
const HIT_PUPIL_SCALE := 0.6
const HIT_SIDE_LANES := 0.5
const HIT_SPIN := 0.5
const HIT_STARS := 3
const HIT_STARS_SEC := 1.2
const HIT_INVULN_SEC := 1.5

## ─────────────── словник анімацій (GDD v1.6 §5) ───────────────
## Ті самі стани для вокселя й для скелетного рига. `fly`, `glide`, `hop` — зарезервовані:
## профіль у них є, окремої логіки ще нема.
enum Anim {IDLE, RUN, SPRINT, LIMP, DUCK, JUMP, ROCKET, CHARGE, DANCE, WAVE, HIT, FLY, GLIDE, HOP}
const ANIM_NAMES := ["idle", "run", "sprint", "limp", "duck", "jump", "rocket",
	"charge", "dance", "wave", "hit", "fly", "glide", "hop"]
## Ключі МОТОРНОГО ПРОФІЛЮ — одного словника, який керує обома тілами (вокселем і ригом):
##   leg_amp (рад) · leg_freq (ГЦ — фіксована каденція кроку, НЕ множник швидкості світу) ·
##   bob_amp (× бобу) · body_pitch (рад, + = ніс униз)
##   body_y (м) · head_pitch (рад, + = голова вниз) · ears ("up"/"back"/"down"/"free")
##   tail ("wag"/"up"/"straight"/"wag_up") · limp_leg (індекс лапки або −1) · shake (0..1 тремтіння)
##   spin_y (рад, АМПЛІТУДА виляння навколо вертикалі — не швидкість: кут завжди
##          повертається в нуль, тож стан не лишає героя розвернутим) ·
##   hop (0..1 підскоки) · leg_spread (м, лапки ширше)
const PROFILE_KEYS := ["leg_amp", "leg_freq", "bob_amp", "body_pitch", "body_y", "head_pitch",
	"ears", "tail", "limp_leg", "shake", "spin_y", "hop", "leg_spread"]
const HIT_ANIM_SEC := 0.5         ## скільки триває поза удару
const WAVE_ANIM_SEC := 1.6
## Привітання (ті самі числа й у HeroRig): герой ЗВОДИТЬСЯ ДИБКИ на задні лапки.
## ВСЕ ТІЛО обертається навколо ЗАДНІХ ЛАПОК НА ЗЕМЛІ (WAVE_PIVOT) на WAVE_PITCH; задні
## лапки отримують КОНТР-оберт −WAVE_PITCH і лишаються вертикальними й на місці; передні
## звисають уздовж піднятого тіла: ліва підібгана, права махає вгору-вниз і навколо
## вертикалі 3 рази на секунду. Голова доверстує контр-нахилом, щоб морда дивилась у камеру.
## Скелетний герой робить рівно те саме, тільки обертає вузол моделі (HeroRig._place_root) —
## жодних «кісток тазу», бо ієрархія в кожного ригу своя (див. docs/MEMORY.md).
## У НАШИХ ЗНАКАХ: + оберт лапки — мах УПЕРЕД, + WAVE_PITCH — перед УГОРУ, + head_pitch — морда ВНИЗ.
const WAVE_LIFT := -1.2           ## передня права («привіт») — середина розмаху, рад
const WAVE_LIFT_SWING := 0.2      ## розмах помаху вгору-вниз: WAVE_LIFT ± це (−1,4 … −1,0)
const WAVE_LIFT_TUCK := -0.6      ## передня ліва просто підібгана, рад
const WAVE_PITCH := HeroRig.WAVE_PITCH   ## на скільки задирається перед, рад (≈50°)
## Навколо ЧОГО крутиться дибка (координати тіла): ЗАДНІ ЛАПКИ НА ЗЕМЛІ (y = 0). Раніше
## шарнір стояв на висоті стегна (LEG_H), і копитця все одно від'їжджали від землі —
## герой «висів» на нахилі. Тепер точка обертання рівно там, де лапка торкається дороги.
const WAVE_PIVOT := Vector3(0.0, 0.0, HIP_Z_BACK)
const WAVE_HEAD_PITCH := 0.6      ## контр-нахил голови, рад (морда дивиться в камеру)
const WAVE_EASE := 0.3            ## вхід у позу дибки й вихід із неї, с
const WAVE_OUT := 0.25            ## відворот лапки назовні, рад
const WAVE_YAW := 0.25            ## розмах помаху навколо вертикалі, рад
const WAVE_HZ := 3.0              ## частота помаху, Гц
const WAVE_HEAD_ROLL := -0.15     ## крен голови до піднятої (правої) лапки, рад
## Ракета: лапки НЕ теліпаються навколо нуля, а звисають ВНИЗ-НАЗАД, як у оленів Санти —
## фіксована поза плюс ледь помітне повільне похитування (амплітуда — leg_amp профілю).
## Задні звисають ПРЯМІШЕ (0,35 замість 0,55): з великим кутом герой висів «сидячи».
const ROCKET_LEG_BACK := 0.35     ## задні лапки: назад від вертикалі, рад
const ROCKET_LEG_BACK_FRONT := 0.65   ## передні трохи більше — щоб не стирчали під тулубом
const ROCKET_LEG_SWAY := 0.08     ## розмах похитування, рад
const ROCKET_SWAY_HZ := 1.0       ## частота похитування, Гц
## Хвіст у ракеті ЗВИСАЄ ВНИЗ (режим профілю "down") і повільно похитується: задертий
## догори хвіст на висоті читався як «злякався», а не «летить».
const ROCKET_TAIL_DOWN := -0.8    ## підйом хвоста, рад (мінус = вниз)
const ROCKET_TAIL_HZ := 0.7       ## частота похитування, Гц
const ROCKET_TAIL_SWAY := 0.1     ## розмах похитування, рад
## ПРИСІД — ЦЕ КОВЗАННЯ НА ЖИВОТІ (ідея Nick): не навпочіпки, а животом по землі —
## тіло опускається, корпус рівний, усі чотири лапки РОЗКИДАНІ ВБОКИ (оберт навколо осі Z),
## корпус ледь похитує з боку в бік, хвіст витягнутий назад, вуха прищулені,
## з-під боків раз на SLIDE_DUST_SEC вилітає пилюка.
## Прапорець `ducking` і коробка зіткнень (hit_box) не змінились — це та сама дія «присісти».
## Наскільки опускається тіло в ковзанні. Числа РІЗНІ для двох тіл: у воксельного героя
## тулуб починається на TORSO_Y = 0,225 м, у скелетного живіт нижчий і ширший, тож −0,30
## заганяли рига під дорогу (playtest 09.09, Місто). Глибше за живіт не опускаємось ніколи —
## решту стереже підйом «нічого не тоне» (див. ground_lift).
const SLIDE_BODY_Y := -0.22       ## воксельне тіло на землю, м
const SLIDE_BODY_Y_RIG := -0.16   ## скелетне тіло (риг) — вище: інакше голова під дорогою
const SLIDE_SPLAY := 1.1          ## розкид лапок убік, рад
const SLIDE_ROLL := 0.05          ## похитування корпусу, рад
const SLIDE_ROLL_HZ := 6.0        ## частота похитування, Гц
const SLIDE_HEAD_PITCH := 0.1     ## морда ледь донизу (вздовж землі), рад
const SLIDE_DUST_SEC := 0.3       ## пилюка з боків, с
const SLIDE_DUST_X := 0.28        ## наскільки вбік від центру сипле пилюка, м
## Копитця на підлозі: коли поза (спринт, дибки, підскоки) заганяє найнижчу лапку під землю,
## піднімаємо тіло рівно на різницю — але не більше ніж на GROUND_LIFT_MAX.
## У повітрі не працює (герой висить навмисно), а в КОВЗАННІ працює — просто міряє не самі
## копитця, а найнижчу точку ТУЛУБА Й ЛАПОК: живіт лягає на дорогу, але не крізь неї.
const GROUND_EPS := 0.005
const GROUND_LIFT_MAX := 0.15
## У ковзанні підйом більший: він має вміти скасувати всю глибину SLIDE_BODY_Y.
const GROUND_LIFT_MAX_SLIDE := 0.30
## ТЕМП ХОДИ — ФІКСОВАНИЙ (рішення Nick, тюнінг GDD v1.7). Частота кроку більше НЕ
## залежить від швидкості світу: на розгоні виходило 4+ Гц, і лапки зливались у мерехтіння.
## Тепер каденцій дві — спокійний біг і спринт (розгін бере ту саму, що спринт), плюс
## окремі для кульгання й спокою. Відчуття «швидко» дає СВІТ (дорога, узбіччя, NPC),
## а не частота ніг. Числа живуть у HeroRig — там вони потрібні кісткам (одне джерело).
const RUN_CADENCE_HZ := HeroRig.RUN_CADENCE_HZ         ## біг, Гц
const SPRINT_CADENCE_HZ := HeroRig.SPRINT_CADENCE_HZ   ## спринт і розгін, Гц
const LIMP_CADENCE_HZ := HeroRig.LIMP_CADENCE_HZ       ## кульгає, Гц
const IDLE_CADENCE_HZ := HeroRig.IDLE_CADENCE_HZ       ## тупцяє на місці, Гц
const FLY_CADENCE_HZ := 1.0       ## політ — лапки ліниво перебирають
const GLIDE_CADENCE_HZ := 0.5     ## планування — майже завмерли
## Скільки лишилось швидкості світу: ±10 % РОЗМАХУ кроку (амплітуда, не частота).
const SPEED_AMP_K := HeroRig.SPEED_AMP_K
## STRIDE_M / GAIT_HZ_* лишились ЛИШЕ для чистих помічників gait_hz/gait_freq (їх ще читають
## тести й діагностика «а яка була б хода під швидкість»). ФАЗУ ходи вони більше не крутять.
const STRIDE_M := 0.9
const GAIT_HZ_MIN := 0.8
const GAIT_HZ_MAX := 5.0
const DEFAULT_SPEED_MPS := 4.0    ## поки світ не сказав своєї швидкості (меню, прев'ю, тести)
## РОЗГІН (суперсила): перед самим ефектом герой на CHARGE_WINDUP присідає («замах»),
## і лише потім біжить із профілем CHARGE — інакше сила вмикалась «без анімації».
const CHARGE_WINDUP := 0.35       ## тривалість замаху, с
const CHARGE_WINDUP_DIP := -0.09  ## наскільки присідає в замаху, м
## ТАНЕЦЬ. Рухи ЗГЛАДЖЕНІ: підскок — не |sin| (гострий розворот на кожному нулі), а
## додатна половина синуса крізь smoothstep (HeroRig.dance_bounce), а передні лапки не
## клацають на біт, а ПЕРЕКОЧУЮТЬ вагу за DANCE_LEG_EASE (HeroRig.dance_leg_weight).
const DANCE_SEC := 3.0
const DANCE_BPS := 1.5            ## бітів на секунду (танець)
const DANCE_LEG_EASE := HeroRig.DANCE_LEG_EASE   ## перекочування ваги між передніми лапками, с
const DANCE_HOP := 0.04           ## висота підскоку на біт, м (було 0,06 — лапки відривались)
## У ПІДЙОМІ підскоку задні лапки довертаються вниз-назад, щоб дістати землі.
const DANCE_HIND_EXT := 0.2       ## доворот задніх лапок у підйомі підскоку, рад
## Танець виляє на ±90° (ліворуч — назад — праворуч — назад, разом DANCE_SEC),
## а не крутить повний оберт: 360° читались як «героя перекрутило».
const DANCE_YAW := PI * 0.5
## Хвіст у танці (режим "wag_up"): тримається ВГОРІ й швидко виляє ліворуч-праворуч
## НАВКОЛО ВЕРТИКАЛІ. Старий "spin" крутив хвіст навколо не тієї осі, і той тонув у тулубі.
const DANCE_TAIL_LIFT := 0.9      ## підйом хвоста вгору, рад (ніколи не нижче горизонталі)
const DANCE_TAIL_WAG := 0.5       ## розмах виляння, рад
const DANCE_TAIL_HZ := 4.0        ## частота виляння, Гц
## Хвіст живий У БУДЬ-ЯКОМУ стані: поверх режиму профілю завжди йде тихе виляння
## ±TAIL_IDLE на TAIL_IDLE_HZ (ті самі числа є в HeroRig для кісткового хвоста).
const TAIL_IDLE := 0.12           ## розмах базового виляння, рад
const TAIL_IDLE_HZ := 1.2         ## частота базового виляння, Гц
const CHARGE_DUST_SEC := 0.25     ## пилюка з-під лап на розгоні
const SHAKE_HZ := 20.0            ## частота тремтіння (ракета)
const SHAKE_AMP := 0.02           ## амплітуда тремтіння, м
const LIMP_LEG := 0               ## кульгає передня ліва
## Другий стрибок у повітрі («Подвійний стрибок») — трохи слабший за перший.
const DOUBLE_JUMP_K := 0.85
## Скільки світиться носик песика на суперсилі «Нюх-магніт», с.
const NOSE_GLOW_SEC := 1.2

## Частини за замовчуванням (герой без parts у даних, друг Friend3D, старе збереження).
const DEFAULT_PARTS := {
	"body": "hero_body",
	"head": "hero_head",
	"leg": "hero_leg",
	"tail": "hero_tail_fox",
	"ear": "hero_ear_fox",
}
const PART_KEYS := ["body", "head", "leg", "tail", "ear"]

var lane := 0
var x_target := 0.0
var free_x := false
var wave_offset := 0.0
var jump_velocity := 7.5
var tumbling := false
var ducking := false
var flying := false
var running := false           # біг-боб увімкнено (Біг/Хвиля/Стрибки), вимкнено в меню
## Темп бігу-боба: 1.0 — Біг, 0.6 — покрокові режими (Стрибки/Невагомість), де світ лише дрейфує.
var run_speed_factor := 1.0
## Швидкість СВІТУ під героєм, м/с (Run3D кличе set_speed_mps щоразу, коли її перерахував).
## На ЧАСТОТУ ходи не впливає (та фіксована, див. RUN_CADENCE_HZ) — лише на розмах кроку ±10 %.
var speed_mps := DEFAULT_SPEED_MPS
## Рівень землі під героєм (подіум у каруселі, платформа другого рівня) — тінь лягає на нього.
var ground_y := 0.0
## Життя (GDD v1.3): 3 серця; після удару — невразливість і миготіння.
var hearts := 3
var max_hearts := 3
var invulnerable_t := 0.0
## Щит (пікап): поглинає один удар — бульбашка навколо героя.
var shield_on := false
## Сидить після втрати всіх сердець («Ще раз!») — біг-боб і нахил тіла вимкнені.
var sitting := false
## Множник стрибка режиму (невагомість ×0.8), поверх jump_velocity профілю.
## Суперсила «Хитрий стрибок» теж піднімає його — і повертає назад те саме значення,
## яке було до неї (у Хмаринках режим уже поставив своє).
var jump_scale := 1.0
## Суперсила «Подвійний стрибок» (GDD v1.6 §3c): один додатковий стрибок у повітрі за політ.
var double_jump := false
var _double_used := false
var hero_id := "lys"
var feature := "fox"
var color := Palette.HERO_DEFAULT
## Колір кінчика хвоста і плямок/смужок — із даних героя (accent / mark).
var accent := Palette.H_CREAM
var mark := Palette.H_DARK

## Поточний стан анімації (GDD v1.6 §5). Присід — НЕ стан, а накладка (`ducking` + `_duck_blend`).
var anim_state: Anim = Anim.IDLE
var _anim_hold_t := 0.0            ## тимчасовий стан (удар/привітання/розгін/танець) — секунд лишилось
var _anim_return: Anim = Anim.IDLE ## куди повернутись, коли тимчасовий стан скінчиться
var _sprint := false               ## прапорці, з яких збирається базовий стан (див. resolve_anim)
var _limp := false
var _rocket := false
var _shake_t := 0.0
var _shake_off := Vector2.ZERO
var _charge_dust_t := 0.0
## Замах перед розгоном: скільки секунд його ще лишилось (0 — уже біжить із профілем CHARGE).
var _charge_wind_t := 0.0
## Слід-родзинка розгону (один на весь розгін): щоб пилюка кожні 0,25 с не плодила нові емітери.
var _accent_node: GPUParticles3D
## ФАЗА КРОКУ (рад) — накопичується, а не рахується як t × частота: інакше кожна зміна
## швидкості світу перекидала б лапки в іншу точку циклу.
var _gait_phase := 0.0
var _slide_dust_t := 0.0           ## пилюка з боків під час ковзання (присід)
var _dance_t := 0.0                ## секунд від початку танцю (з нього виляння ±DANCE_YAW)
var _sprint_trail: GPUParticles3D  ## слід спринту (лише якщо в слоті "trail" нічого нема)
## Поза «лише для показу» (debug-прев'ю): профіль стану застосований, а геймплейних наслідків
## нема — не летимо, не радіємо, не сиплемо пилюку (див. preview_pose).
var _pose_only := false
var _pose_hover := 0.0             ## на скільки метрів підняти героя в позі-прев'ю (ракета)

var _vy := 0.0
var _y := 0.0
var _tilt := 0.0
var _t := 0.0
var _blink_t := 0.0
var _next_blink := 3.0
var _look_t := 0.0
var _yawn_t := 0.0
var _twitch_t := 0.0

var _body: Node3D
## Скелетний риг (герой із полем "rig"). null — звичайне воксельне тіло з частин.
var _rig: HeroRig
## Стиль розмальовки рига з `rig_style` ("unicorn") або "" — від нього залежить і родзинка
## на розгоні (див. charge_accent).
var _rig_style := ""
var _mesh: MeshInstance3D            # тулуб (лишив старе ім'я: на ньому «привид» у каруселі)
var _meshes: Array[MeshInstance3D] = []   # усі воксельні частини — для матеріалів
var _head: Node3D                    # шарнір голови (шия)
## Куди чіпляти обличчя й окуляри. null — просто на голову (воксельне тіло); у скелетного
## героя це вузол рига, стиснутий під ширину справжньої морди (див. HeroRig.face_anchor).
var _face_root: Node3D
var _face: Node3D
var _eyes: Array[Node3D] = []
var _pupils: Array[MeshInstance3D] = []
var _mouth: MeshInstance3D
var _parts: Array[Node3D] = []      # рухомі частини: вуха + хвіст
var _ears: Array[Node3D] = []
var _ear_base: Array[Vector3] = []  # базовий поворот вуха (розхил / звисання)
var _tail: Node3D
var _tail_base_x := 0.0
var _tail_yaw := 0.0               ## виляння хвоста РЕЖИМУ (без базового TAIL_IDLE зверху)
var _legs: Array[Node3D] = []       # 0 — передня ліва, 1 — передня права, 2 — задня ліва, 3 — задня права
var _leg_base_x: Array[float] = []  # базовий x кожної лапки (розгін розставляє їх ширше)
var _shadow: MeshInstance3D
var _vehicle: MeshInstance3D
var _sparkles: GPUParticles3D
var _tumble_tween: Tween
var _eye_scale_y := 1.0
var _duck_blend := 0.0          # 0 — стоїть, 1 — присів (плавний перехід 20/с)
var _mouth_y := 0.05            # базова висота рота у координатах голови (усмішка піднімає на +0.02)
var _blink_vis_t := 0.0         # таймер миготіння тіла під час невразливості
var _wave_t := 0.0              # поки махає лапкою — _process її не чіпає
## Наскільки герой уже звівся дибки для привітання (0…1). Окремо від _wave_t, бо в позу
## треба входити й ВИХОДИТИ плавно, за WAVE_EASE, — інакше тіло смикається на початку й у кінці.
var _wave_blend := 0.0
## Обличчя «замкнене» (привітання): очі повністю розплющені, зіниці прямо, кліпання вимкнене.
var _face_lock_t := 0.0
var _blink_tween: Tween         # щоб «замкнене» обличчя могло обірвати кліпання на півдорозі
var _shield: MeshInstance3D
var _shield_popping := false    # бульбашка лопається — set_shield(false) її не ховає раніше часу


# ---------- дані героїв ----------

static var _defs_cache: Dictionary = {}
static var _defs_loaded := false


## Усі герої з data/heroes.json (з кешем). Разом зі старими (legacy) — щоб збереження не падали.
static func defs() -> Dictionary:
	if _defs_loaded:
		return _defs_cache
	_defs_loaded = true
	var f := FileAccess.open("res://data/heroes.json", FileAccess.READ)
	if f == null:
		return _defs_cache
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_defs_cache = parsed
	return _defs_cache


## Чиста функція: чи це старий пухнастик v1.4 (у каруселі його нема).
static func is_legacy(def: Dictionary) -> bool:
	return bool(def.get("legacy", false))


## Чиста функція: назви вокселів частин героя з дефолтами (body/head/leg/tail/ear).
static func part_names(def: Dictionary) -> Dictionary:
	var out := DEFAULT_PARTS.duplicate()
	var p = def.get("parts", {})
	if typeof(p) == TYPE_DICTIONARY:
		for k in PART_KEYS:
			var v := String((p as Dictionary).get(k, ""))
			if v != "":
				out[k] = v
	return out


## Чиста функція: id першого нового (не legacy) героя за order — на нього падаємо зі старого збереження.
static func first_animal_id(all: Dictionary) -> String:
	var best := ""
	var best_order := 1 << 30
	for k in all.keys():
		var key := String(k)
		if key.begins_with("_") or key == "growth":
			continue
		var def = all[k]
		if typeof(def) != TYPE_DICTIONARY or is_legacy(def):
			continue
		var o := int((def as Dictionary).get("order", 99))
		if o < best_order:
			best_order = o
			best = key
	return best


## Чиста функція: опис, за яким малюємо героя id. Старий (legacy) герой → перший новий;
## незнайомий id (напр. "friend") → порожній опис, тобто частини за замовчуванням і переданий колір.
static func resolve_def(all: Dictionary, id: String) -> Dictionary:
	var def = all.get(id, {})
	if typeof(def) != TYPE_DICTIONARY:
		return {}
	if (def as Dictionary).is_empty():
		return {}
	if not is_legacy(def):
		return def
	var fid := first_animal_id(all)
	var fallback = all.get(fid, {})
	return fallback if typeof(fallback) == TYPE_DICTIONARY else {}


func _ready() -> void:
	# бульбашка щита — напівпрозора сфера, видима лише з пікапом
	_shield = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.75
	sph.height = 1.5
	sph.radial_segments = 24
	sph.rings = 12
	_shield.mesh = sph
	var shm := StandardMaterial3D.new()
	shm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shm.albedo_color = Color(0.4, 0.8, 1.0, 0.28)
	shm.emission_enabled = true
	shm.emission = Palette.HERO_SHIELD
	shm.emission_energy_multiplier = 0.6
	shm.roughness = 0.2
	_shield.material_override = shm
	_shield.position.y = 0.62
	_shield.visible = false
	add_child(_shield)

	# тінь звірятка — витягнутий уздовж тіла овал
	_shadow = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.32
	cm.bottom_radius = 0.32
	cm.height = 0.02
	_shadow.mesh = cm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0, 0, 0.1, 0.32)
	_shadow.material_override = sm
	_shadow.scale = Vector3(0.95, 1.0, 1.5)
	add_child(_shadow)

	_vehicle = VoxelBuilder.instance("shell")
	_vehicle.position.y = -0.05
	_vehicle.visible = false
	add_child(_vehicle)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	set_hero(hero_id, color, feature)


## Перебудувати героя: тулуб + голова (з обличчям і вухами) + чотири лапки + хвіст.
func set_hero(id: String, hero_color: Color, feat: String = "fox") -> void:
	hero_id = id
	feature = feat
	color = hero_color
	for c in _body.get_children():
		c.queue_free()
	if _rig != null:
		_rig.dispose()
		_rig = null
	_meshes.clear()
	_eyes.clear()
	_pupils.clear()
	_parts.clear()
	_ears.clear()
	_ear_base.clear()
	_legs.clear()
	_leg_base_x.clear()
	_head = null
	_face_root = null
	_tail = null
	_sparkles = null

	var def := resolve_def(defs(), id)
	# старого пухнастика показуємо як першого нового героя — разом із його кольорами
	if not def.is_empty() and def.get("color") != null and is_legacy(defs().get(id, {})):
		color = Palette.of(def.get("color"), hero_color)
	_rig_style = String(def.get("rig_style", ""))
	accent = Palette.of(def.get("accent"), Palette.H_CREAM)
	mark = Palette.of(def.get("mark"), color.darkened(0.3))
	var parts := part_names(def)
	var pal := _voxel_palette()

	if not _build_rig(def):
		_mesh = _part_mesh(String(parts["body"]), pal)
		_mesh.name = "Torso"
		_mesh.position = Vector3(0.0, TORSO_Y, TORSO_Z)
		_body.add_child(_mesh)

		_build_head(String(parts["head"]), String(parts["ear"]), pal)
		_build_legs(String(parts["leg"]), pal)
		_build_tail(String(parts["tail"]), pal)
	if feature == "cloud":
		for m in _meshes:
			m.material_override = VoxelBuilder.material_alpha(0.72)
	elif feature == "sparkle":
		_sparkles = FX.sparkles(_body, 0.55, 14)

	_body.scale = Vector3.ONE
	_body.rotation = Vector3.ZERO
	_body.position = Vector3.ZERO
	_duck_blend = 0.0
	# аксесуари жили на старому тілі — одягаємо знову (set_accessory сам прибирає старий вузол)
	var snapshot := _slot_voxels.duplicate()
	var opts_snapshot := _slot_opts.duplicate()
	for slot in snapshot.keys():
		var o: Dictionary = opts_snapshot.get(slot, {})
		set_accessory(String(slot), String(snapshot[slot]), o)
	if not _slots.has("hat"):
		_hat = null
		_hat_spin = false


## Скелетний риг героя або null (звичайне воксельне тіло) — для debug-прев'ю й тестів.
func rig() -> HeroRig:
	return _rig


## Кольори зон героя: o — основний, d — темніший (животик), c — крем (морда),
## k — темне (носик/копитця), i — рожева серединка вуха, e — зовнішній бік вуха (ще темніший
## за d), t — кінчик хвоста/чубчик, u — ОСНОВА чубчика (темніше золото: обідок черепа між
## вухами, інакше під жовтим чубчиком світиться помаранчева щілина), m — плямки/смужки/торбинка.
## Ті самі символи використовують і вокселі (палітра-підміна), і скелетний риг (вершинні кольори).
func _hero_colors() -> Dictionary:
	return {
		"o": color,
		"d": color.darkened(0.22),
		"c": Palette.H_CREAM,
		"k": Palette.H_DARK,
		"i": Palette.H_ACC_PINK,
		"e": color.darkened(0.35),
		"t": accent,
		"u": accent.darkened(0.15),
		"m": mark,
	}


## Те саме, але рядками «RRGGBB» — саме такий формат чекає VoxelBuilder.
func _voxel_palette() -> Dictionary:
	var src := _hero_colors()
	var out := {}
	for k in src.keys():
		out[k] = (src[k] as Color).to_html(false)
	return out


## Спроба зібрати скелетне тіло (герой із полем "rig" у heroes.json).
## false — рига в даних нема, файл моделі не доїхав або в ньому нема скелета:
## викликач малює звичайні воксельні частини.
func _build_rig(def: Dictionary) -> bool:
	if String(def.get("rig", "")) == "":
		return false
	var r := HeroRig.new()
	if not r.build(_body, def, _hero_colors()):
		return false
	_rig = r
	for m in r.mesh_instances():
		_meshes.append(m)
	if not _meshes.is_empty():
		_mesh = _meshes[0]            # «привид» у каруселі й напівпрозорість шукають саме його
	# обличчя живе в тій самій системі координат, що й воксельна голова
	# (низ голови по центру, висота HEAD_H, передня грань на −HEAD_HALF_D),
	# але висить на кістці голови — тож кліпає й дивиться вбік як завжди
	_head = r.head_anchor()
	_face_root = r.face_anchor()
	if _head == null:
		# кістку голови не знайшли (див. rig_bones у docs/tasks/rig.md) — обличчя все одно
		# має бути, інакше герой без очей: вішаємо його на шию, як у воксельного тіла
		_head = Node3D.new()
		_head.name = "Head"
		_head.position = Vector3(0.0, NECK_Y, NECK_Z)
		_body.add_child(_head)
	_build_face()
	return true


func _part_mesh(voxel: String, pal: Dictionary) -> MeshInstance3D:
	var mi := VoxelBuilder.instance(voxel, pal)
	_meshes.append(mi)
	return mi


# ---------- складання ----------

## Голова: шарнір на шиї, у ньому меш голови, обличчя, вуха й точки кріплення капелюшка/окулярів.
func _build_head(head_voxel: String, ear_voxel: String, pal: Dictionary) -> void:
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0.0, NECK_Y, NECK_Z)
	_body.add_child(_head)
	var m := _part_mesh(head_voxel, pal)
	m.name = "HeadMesh"
	_head.add_child(m)
	_build_face()
	_build_ears(ear_voxel, pal)


## Чотири лапки на шарнірах (плече/стегно), меш звисає вниз — на бігу вони махають галопом.
func _build_legs(leg_voxel: String, pal: Dictionary) -> void:
	var spots := [
		Vector3(-HIP_X, LEG_H, HIP_Z_FRONT),
		Vector3(HIP_X, LEG_H, HIP_Z_FRONT),
		Vector3(-HIP_X, LEG_H, HIP_Z_BACK),
		Vector3(HIP_X, LEG_H, HIP_Z_BACK),
	]
	var names := ["LegFL", "LegFR", "LegBL", "LegBR"]
	for i in range(spots.size()):
		var leg := Node3D.new()
		leg.name = String(names[i])
		leg.position = spots[i]
		var m := _part_mesh(leg_voxel, pal)
		m.position.y = -LEG_H
		leg.add_child(m)
		_body.add_child(leg)
		_legs.append(leg)
		_leg_base_x.append(leg.position.x)


## Вуха на маківці: розхилені, дзеркальні; висячі (песик) відхилені вниз.
func _build_ears(ear_voxel: String, pal: Dictionary) -> void:
	var floppy := ear_voxel == "hero_ear_flop"
	var long_ear := ear_voxel == "hero_ear_long"
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var ear := Node3D.new()
		ear.name = "EarL" if i == 0 else "EarR"
		# у координатах голови: маківка — y = HEAD_H, трохи ближче до потилиці;
		# висяче вухо сидить нижче й ближче до скроні
		var ear_y := HEAD_H - 0.05 if floppy else HEAD_H - 0.02
		var ear_x := side * (0.24 if floppy else 0.15)
		ear.position = Vector3(ear_x, ear_y, 0.02)
		var base := Vector3.ZERO
		if floppy:
			base = Vector3(0.0, 0.0, side * 2.3)     # звисає вниз уздовж щоки
		elif long_ear:
			base = Vector3(0.22, 0.0, side * 0.12)   # довге вухо трохи відхилене назад
		else:
			base = Vector3(0.0, 0.0, side * 0.2)
		ear.rotation = base
		var m := _part_mesh(ear_voxel, pal)
		m.scale.x = side                              # друге вухо — дзеркальне
		ear.add_child(m)
		_head.add_child(ear)
		_ears.append(ear)
		_ear_base.append(base)
		_parts.append(ear)


## Хвіст на шарнірі ззаду-вгорі тулуба. Вертикальні хвости (песик, котик) відхиляємо назад.
func _build_tail(tail_voxel: String, pal: Dictionary) -> void:
	_tail = Node3D.new()
	_tail.name = "Tail"
	_tail.position = Vector3(0.0, TAIL_Y, TAIL_Z)
	var m := _part_mesh(tail_voxel, pal)
	match tail_voxel:
		"hero_tail_dog":
			_tail_base_x = 0.5
			m.position.y = 0.0
		"hero_tail_cat":
			_tail_base_x = 0.9
			m.position.y = 0.0
		"hero_tail_fox":
			_tail_base_x = -0.25
			m.position = Vector3(0.0, -0.09, 0.14)
		_:
			if tail_voxel.ends_with("_ai"):
				# згенерований хвіст завдовжки рівно TAIL_LEN — ставимо його «від шарніра назад»
				_tail_base_x = -0.2
				m.position = Vector3(0.0, -0.04, TAIL_LEN * 0.5)
			else:
				_tail_base_x = 0.0
				m.position = Vector3(0.0, -0.05, 0.05)
	_tail.rotation.x = _tail_base_x
	_tail.add_child(m)
	_body.add_child(_tail)
	_parts.append(_tail)


# ---------- капелюшок і аксесуари ----------

var hat_id := "none"
var _hat: Node3D
var _hat_spin := false
## Слоти аксесуарів: "hat", "face", "neck", "back", "trail" → один вузол на слот.
var _slots: Dictionary = {}
var _slot_voxels: Dictionary = {}
var _slot_opts: Dictionary = {}
## Лишилось від пухнастиків v1.4 (чубчика під капелюшком у звірят уже нема).
const NO_TUFT_FEATURES := ["ears", "tail", "antenna", "stripes", "sparkle", "cloud", "sleepy"]


## Одягнути капелюшок із data/hats.json (id "none" — зняти). Кріпиться до маківки, гойдається з головою.
func set_hat(id: String) -> void:
	hat_id = id
	var def := Hats.find(Hats.load_all(), id)
	var voxel := String(def.get("voxel", ""))
	if def.is_empty() or voxel == "":
		set_accessory("hat", "")
		return
	set_accessory("hat", voxel, {"y": float(def.get("y", 0.0)), "spin": bool(def.get("spin", false))})


## Аксесуар у слот. voxel — назва з data/voxels ("" — зняти). opts:
##   hat:   {"y": float, "spin": bool}
##   trail: {"color": "#hex"} — слід-іскри за героєм (voxel не потрібен; без color — зняти)
## Слоти: "hat" (маківка) і "face" (окуляри) живуть на голові, тож рухаються з нею;
## "neck" (шарфик, гойдається) і "back" (крильця/рюкзачок, махають) — на тулубі; "trail" — за героєм.
func set_accessory(slot: String, voxel: String, opts: Dictionary = {}) -> void:
	_remove_slot(slot)
	if slot == "trail":
		var col := String(opts.get("color", ""))
		if col == "":
			return
		# слід — дитина self, а не тіла, щоб сквош/присід його не тягнули
		var tr := FX.trail(self, Color(col))
		tr.position = Vector3(0.0, 0.3, 0.3)
		_slots[slot] = tr
		_slot_voxels[slot] = voxel
		_slot_opts[slot] = opts
		return
	if voxel == "":
		return
	var node := Node3D.new()
	node.name = "Acc_%s" % slot
	node.add_child(VoxelBuilder.instance(voxel))
	var parent := _body
	match slot:
		"hat":
			# у координатах голови: на маківці
			parent = _head if _head != null else _body
			node.position = Vector3(0.0, HEAD_H - 0.02 + float(opts.get("y", 0.0)), 0.0)
		"face":
			# окуляри на очах, трохи перед мордою (у скелетного героя — у вузлі обличчя,
			# щоб зменшитись разом із очима)
			parent = _face_root if _face_root != null else (_head if _head != null else _body)
			node.position = Vector3(0.0, 0.24, -HEAD_HALF_D - 0.03)
		"neck":
			node.position = Vector3(0.0, 0.50, -0.10)
		"back":
			node.position = Vector3(0.0, TORSO_TOP - 0.02, 0.06)
		_:
			node.position = Vector3(0.0, 0.50, 0.0)
	# скелетний герой: шарфик і рюкзачок їдуть на кістках шиї та хребта, а не на тулубі
	# (капелюшок і окуляри вже на голові — _head сам висить на кістці)
	if _rig != null and slot in ["neck", "back"]:
		var bone_anchor := _rig.anchor(slot)
		if bone_anchor != null:
			parent = bone_anchor
			node.position = Vector3(0.0, 0.0, -0.04 if slot == "neck" else 0.06)
	parent.add_child(node)
	_slots[slot] = node
	_slot_voxels[slot] = voxel
	_slot_opts[slot] = opts
	if slot == "hat":
		_hat = node
		_hat_spin = bool(opts.get("spin", false))
		_squash(Vector3(1.1, 0.9, 1.1), 0.12)
	else:
		_squash(Vector3(1.06, 0.94, 1.06), 0.1)


## Зняти все (капелюшок теж).
func clear_accessories() -> void:
	for slot in _slots.keys().duplicate():
		set_accessory(String(slot), "")
	hat_id = "none"


func _remove_slot(slot: String) -> void:
	var node = _slots.get(slot)
	if node != null and is_instance_valid(node):
		if node == _hat:
			_hat = null
			_hat_spin = false
		node.queue_free()
	_slots.erase(slot)
	_slot_voxels.erase(slot)
	_slot_opts.erase(slot)


func _box(size: Vector3, c: Color, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := Mats.box(size, c)
	mi.position = pos
	parent.add_child(mi)
	return mi


## Той самий блок, але глянцевий (арт-вектор glossy toy) — для очей: справжній catchlight
## замість плоского кольору, решта (розмір/позиція/калібрування rig_face) не зачіпається.
func _box_glossy(size: Vector3, c: Color, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := Mats.box_glossy(size, c)
	mi.position = pos
	parent.add_child(mi)
	return mi


## Обличчя живе на голові (координати голови): великі очі з бліком у темних западинах вокселя,
## щічки й рот на кремовій морді.
func _build_face() -> void:
	_face = Node3D.new()
	_face.name = "Face"
	# у скелетного героя обличчя сідає у власний вузол рига (стиснутий під морду), у решти — на голову
	var face_parent := _face_root if _face_root != null and is_instance_valid(_face_root) else _head
	face_parent.add_child(_face)
	var eye_pale := Palette.H_CREAM
	var pupil := Palette.HERO_EYE
	var face_z := -HEAD_HALF_D - 0.01
	# кінь (і будь-яка довга морда) дивиться БОКАМИ голови, а не передньою гранню:
	# `rig_face.layout: "side"` у heroes.json → очі на боках черепа, розвернуті назовні.
	# Зіниці, блики, кліпання й окуляри — діти цих же вузлів, тож працюють як завжди.
	# (потрібен саме вузол обличчя рига: без нього координати голови — заглушка, і бічні
	# очі поїхали б у порожнечу)
	var side_eyes := _rig != null and _face_root != null and _rig.face_layout() == "side"
	var spot: Dictionary = _rig.face_side_spot() if side_eyes else {}
	var side_w := float(spot.get("half_w", 0.0))
	var side_z := float(spot.get("z", face_z))
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		if side_eyes:
			eye.position = Vector3(side * side_w, 0.225, side_z)
			eye.rotation.y = -side * PI * 0.5      # локальний «перед» ока дивиться назовні
		else:
			eye.position = Vector3(side * 0.15, 0.225, face_z)
		_face.add_child(eye)
		_box_glossy(Vector3(0.105, 0.185, 0.02), eye_pale, Vector3.ZERO, eye)
		var p := _box_glossy(Vector3(0.075, 0.15, 0.02), pupil, Vector3(0.0, 0.0, -0.015), eye)
		_box(Vector3(0.028, 0.028, 0.01), Color.WHITE, Vector3(0.02, 0.04, -0.014), p)  # блик
		_eyes.append(eye)
		_pupils.append(p)
		var cheek := _box(Vector3(0.07, 0.05, 0.02), Palette.HERO_CHEEK, Vector3.ZERO, _face)
		if side_eyes:
			# щічка — теж на боці голови, трохи нижче й ближче до морди
			cheek.position = Vector3(side * side_w, 0.12, side_z - 0.07)
			cheek.rotation.y = -side * PI * 0.5
		else:
			cheek.position = Vector3(side * 0.2, 0.12, face_z + 0.01)
	# рот лишається на ПЕРЕДНІЙ грані морди, нижче — і при бічних очах теж
	_mouth = _box(Vector3(0.1, 0.03, 0.02), Palette.HERO_MOUTH, Vector3(0.0, _mouth_y, face_z), _face)
	_eye_scale_y = 0.55 if feature == "sleepy" else 1.0
	for e in _eyes:
		e.scale.y = _eye_scale_y


# ---------- словник анімацій (GDD v1.6 §5) ----------

## Чиста функція: моторний профіль стану. Один словник керує ОБОМА тілами —
## воксельним (Hero3D._process) і скелетним (HeroRig.animate). Ключі — PROFILE_KEYS.
static func profile_for(a: Anim) -> Dictionary:
	var p := {
		"leg_amp": 0.05, "leg_freq": IDLE_CADENCE_HZ, "bob_amp": 0.0, "body_pitch": 0.0,
		"body_y": 0.0, "head_pitch": 0.0, "ears": "free", "tail": "wag",
		"limp_leg": -1, "shake": 0.0, "spin_y": 0.0, "hop": 0.0, "leg_spread": 0.0,
	}
	match a:
		Anim.RUN:
			p.merge({"leg_amp": GALLOP_SWING, "leg_freq": RUN_CADENCE_HZ, "bob_amp": 1.0}, true)
		Anim.SPRINT:
			p.merge({"leg_amp": 0.9, "leg_freq": SPRINT_CADENCE_HZ, "bob_amp": 0.7, "body_pitch": 0.18,
				"body_y": -0.04, "ears": "back", "tail": "straight"}, true)
		Anim.LIMP:
			p.merge({"leg_amp": 0.45, "leg_freq": LIMP_CADENCE_HZ, "bob_amp": 0.8, "body_pitch": 0.1,
				"head_pitch": 0.35, "ears": "down", "tail": "straight", "limp_leg": LIMP_LEG}, true)
		Anim.DUCK:
			# КОВЗАННЯ НА ЖИВОТІ, а не навпочіпки: корпус РІВНИЙ (body_pitch 0) і лежить
			# на землі, лапки розкидані вбоки (SLIDE_SPLAY — не з профілю, бо це оберт
			# навколо іншої осі), вуха прищулені, хвіст витягнутий назад
			p.merge({"leg_amp": 0.0, "leg_freq": 0.0, "body_pitch": 0.0,
				# body_y тут — ВОКСЕЛЬНА глибина; у грі присід накладається блендом і бере
				# свою для кожного тіла (slide_body_y), профіль потрібен лише прев'ю
				"body_y": SLIDE_BODY_Y, "head_pitch": SLIDE_HEAD_PITCH,
				"ears": "back", "tail": "straight"}, true)
		Anim.JUMP:
			p.merge({"leg_amp": 0.9, "leg_freq": 0.0, "ears": "up", "tail": "up"}, true)
		Anim.ROCKET:
			# leg_amp тут — це РОЗМАХ ПОХИТУВАННЯ біля фіксованої пози «вниз-назад»
			# (ROCKET_LEG_BACK), а не мах галопу; частота своя (ROCKET_SWAY_HZ), не від бігу
			p.merge({"leg_amp": ROCKET_LEG_SWAY, "leg_freq": 0.0, "bob_amp": 0.6,
				"body_y": 0.05, "shake": 0.6, "ears": "up", "tail": "down"}, true)
		Anim.CHARGE:
			# розгін бере ТУ САМУ каденцію, що спринт: більше — і лапки мерехтять
			p.merge({"leg_amp": 0.75, "leg_freq": SPRINT_CADENCE_HZ, "bob_amp": 1.0, "body_pitch": 0.25,
				"head_pitch": 0.4, "ears": "back", "tail": "straight", "leg_spread": 0.04}, true)
		Anim.DANCE:
			p.merge({"leg_amp": 0.9, "leg_freq": 0.0, "ears": "up", "tail": "wag_up",
				"spin_y": DANCE_YAW, "hop": 1.0}, true)
		Anim.WAVE:
			# стійка дибки: голова контр-нахилом дивиться в камеру, вуха вгору, хвіст донизу.
			# САМ НАХИЛ у профілі НЕ живе: це оберт УСЬОГО тіла навколо задніх лапок
			# (WAVE_PITCH + WAVE_PIVOT, у ригу — HeroRig._place_root), і йде він через
			# бленд _wave_blend, а не через `body_pitch`/`body_y` — інакше нахил лічився б
			# двічі (у вокселів на тілі, у рига ще й на хребті).
			# leg_amp — РОЗМАХ лапки-«привіт» (сам знак у WAVE_LIFT); вхід/вихід — WAVE_EASE
			p.merge({"leg_amp": absf(WAVE_LIFT), "leg_freq": 0.0,
				"head_pitch": WAVE_HEAD_PITCH, "ears": "up", "tail": "down"}, true)
		Anim.HIT:
			p.merge({"leg_amp": 0.0, "leg_freq": 0.0, "ears": "back", "tail": "straight"}, true)
		Anim.FLY:
			p.merge({"leg_amp": 0.25, "leg_freq": FLY_CADENCE_HZ, "bob_amp": 0.4,
				"ears": "up", "tail": "up"}, true)
		Anim.GLIDE:
			p.merge({"leg_amp": 0.1, "leg_freq": GLIDE_CADENCE_HZ, "body_pitch": -0.1,
				"ears": "back", "tail": "straight"}, true)
		Anim.HOP:
			p.merge({"leg_amp": 0.7, "leg_freq": RUN_CADENCE_HZ, "bob_amp": 1.2, "hop": 0.5,
				"ears": "up", "tail": "up"}, true)
	return p


## Чиста функція: зсув фази лапки в циклі кроку (0…1) — задня ліва 0, передня ліва 0,25,
## задня права 0,5, передня права 0,75. Індекси лапок ті самі, що в `_legs` і
## `HeroRig.LEG_ROLES`: 0 передня ліва · 1 передня права · 2 задня ліва · 3 задня права.
## Одне джерело на обидва тіла — таблиця живе в HeroRig (там вона потрібна кісткам).
static func gait_phase(leg_index: int) -> float:
	return HeroRig.gait_phase(leg_index)


## Чиста функція: підйом копитця (0…1) у махові — лапка йде ВПЕРЕД, поки cos φ > 0.
static func gait_lift(phi: float) -> float:
	return HeroRig.gait_lift(phi)


## Чиста функція-ПОМІЧНИК: яка була б частота кроку, якби хода йшла під швидкість світу
## (Гц = швидкість / довжина кроку). ХОДУ ВОНА БІЛЬШЕ НЕ КРУТИТЬ (рішення Nick, GDD v1.7):
## частота фіксована — RUN_CADENCE_HZ / SPRINT_CADENCE_HZ, див. cadence_hz. Лишилась для
## діагностики й тестів («скільки б це було»), і щоб не ламати старі виклики.
static func gait_hz(speed_mps_v: float, stride: float = STRIDE_M) -> float:
	return clampf(absf(speed_mps_v) / maxf(0.05, stride), GAIT_HZ_MIN, GAIT_HZ_MAX)


## Те саме в рад/с. Теж лише помічник — фазу крутить cadence_hz профілю.
static func gait_freq(speed_mps_v: float, stride: float = STRIDE_M) -> float:
	return TAU * gait_hz(speed_mps_v, stride)


## Чиста функція: ФАКТИЧНА каденція кроку стану, Гц — просто `leg_freq` профілю.
## Швидкість світу сюди не входить НІКОЛИ: у цьому вся суть рішення «лапки не мерехтять».
static func cadence_hz(a: Anim) -> float:
	return float(profile_for(a).get("leg_freq", RUN_CADENCE_HZ))


## Чиста функція: єдине, що лишилось швидкості світу — ±SPEED_AMP_K (10 %) РОЗМАХУ кроку.
## Швидше біжимо — крок ледь ширший; частота при цьому не змінюється ні на герц.
static func speed_amp_k(speed_mps_v: float) -> float:
	var k := absf(speed_mps_v) / maxf(0.05, DEFAULT_SPEED_MPS)
	return clampf(k, 1.0 - SPEED_AMP_K, 1.0 + SPEED_AMP_K)


## Чиста функція: наскільки підняти тіло, щоб найнижча його точка не тонула в дорозі.
## `lowest` — та точка у метрах (мінус = під землею), ВЖЕ з урахуванням зсуву пози;
## `cap` — стеля підйому, щоб помилка в кістках не підкинула героя в небо.
## Дрібниця в межах GROUND_EPS — не привід смикати тіло.
static func ground_lift(lowest: float, cap: float) -> float:
	if lowest >= -GROUND_EPS:
		return 0.0
	return clampf(-lowest, 0.0, maxf(0.0, cap))


## Чиста функція: глибина ковзання для тіла героя (у рига живіт нижчий — опускаємо менше).
static func slide_body_y(is_rig: bool) -> float:
	return SLIDE_BODY_Y_RIG if is_rig else SLIDE_BODY_Y


## Чиста функція: присід «замаху» перед розгоном, 0…1. `left` — скільки секунд замаху
## лишилось. Крива полога з обох боків (sin): герой м'яко сідає й м'яко вистрілює.
static func charge_crouch(left: float, total: float = CHARGE_WINDUP) -> float:
	if left <= 0.0 or total <= 0.0:
		return 0.0
	var u := clampf(1.0 - left / total, 0.0, 1.0)
	return sin(PI * u)


## Чиста функція: компенсація зсуву, коли нахил тіла має крутитись НАВКОЛО ЗАДАНОЇ ТОЧКИ,
## а не навколо початку координат тіла (стійка дибки крутиться навколо стегна задніх лапок,
## щоб задні копитця лишились на місці). Повертаємо ту саму точку й дивимось, куди вона
## поїхала: на стільки ж і зсуваємо тіло назад.
static func pivot_offset(pitch: float, pivot: Vector3) -> Vector3:
	return pivot - Basis(Vector3.RIGHT, pitch) * pivot


## Чиста функція: хто перемагає, коли підходить кілька станів.
## Пріоритет HIT > ROCKET > CHARGE > SPRINT > LIMP > RUN > IDLE.
static func resolve_anim(flags: Dictionary) -> Anim:
	if bool(flags.get("hit", false)):
		return Anim.HIT
	if bool(flags.get("rocket", false)):
		return Anim.ROCKET
	if bool(flags.get("charge", false)):
		return Anim.CHARGE
	if bool(flags.get("sprint", false)):
		return Anim.SPRINT
	if bool(flags.get("limp", false)):
		return Anim.LIMP
	if bool(flags.get("running", false)):
		return Anim.RUN
	return Anim.IDLE


## Ім'я стану для прев'ю, HUD і тестів. Присід — накладка, тому його показуємо окремо.
func anim_name() -> String:
	if ducking:
		return "duck"
	return ANIM_NAMES[int(anim_state)]


## Каденція кроку ПОТОЧНОГО стану, Гц (прев'ю, HUD, тести): фіксоване число з профілю.
func cadence() -> float:
	return cadence_hz(anim_state)


## Профіль поточного стану (присід накладається окремо — це блендом, не станом).
func _profile() -> Dictionary:
	return profile_for(anim_state)


## Базовий стан із прапорців (без тимчасових поз — удару, привітання, розгону, танцю).
func _base_anim() -> Anim:
	return resolve_anim({
		"rocket": _rocket, "sprint": _sprint, "limp": _limp,
		"running": running and not sitting,
	})


## Перерахувати стан після зміни прапорців. Тимчасову позу не перебиваємо —
## лише переписуємо, куди вона повернеться.
func _refresh_anim() -> void:
	_pose_only = false
	_pose_hover = 0.0
	if _anim_hold_t > 0.0:
		_anim_return = _base_anim()
		return
	if anim_state == Anim.JUMP and is_airborne():
		return
	set_anim_state(_base_anim())


## Перемкнути стан (з входом/виходом там, де він потрібен).
func set_anim_state(a: Anim) -> void:
	if a == anim_state:
		return
	_exit_anim(anim_state)
	anim_state = a
	_enter_anim(a)


func _enter_anim(a: Anim) -> void:
	match a:
		Anim.SPRINT:
			# іскри за героєм — лише якщо слід із крамниці не вдягнений
			if _sprint_trail == null and not _slots.has("trail"):
				_sprint_trail = FX.trail(self, accent)
				_sprint_trail.position = Vector3(0.0, 0.3, 0.3)
			if not _pose_only:
				_squash(Vector3(0.94, 1.08, 0.94), 0.1)
		Anim.CHARGE:
			_charge_dust_t = 0.0
			# спершу ЗАМАХ (герой присідає, вуха назад), і лише в його кінці — родзинка героя:
			# так суперсилу видно як РУХ, а не як хмару частинок на рівному місці
			_charge_wind_t = CHARGE_WINDUP
			if not _pose_only:
				_squash(Vector3(1.06, 0.9, 1.06), CHARGE_WINDUP * 0.5)
		Anim.DANCE:
			_dance_t = 0.0
			if not _pose_only:
				_happy(DANCE_SEC)
		Anim.ROCKET:
			_shake_t = 0.0


func _exit_anim(a: Anim) -> void:
	match a:
		Anim.CHARGE:
			_charge_wind_t = 0.0
		Anim.SPRINT:
			if _sprint_trail != null and is_instance_valid(_sprint_trail):
				_sprint_trail.emitting = false
				_sprint_trail.queue_free()
			_sprint_trail = null
		Anim.DANCE:
			var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(_body, "rotation:y", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
		Anim.ROCKET:
			_shake_off = Vector2.ZERO


## Наскільки герой висить над землею в позі-прев'ю ракети (у грі це FLY_HEIGHT = 1,9 м,
## але в прев'ю така висота виносить його за кадр).
const PREVIEW_HOVER := 0.25


## Показати ПОЗУ стану без геймплейних наслідків (debug-прев'ю, клавіші 3…7).
## Профіль застосовується як завжди (лапки, боб, вуха, хвіст, тремтіння, виляння),
## але герой не злітає на FLY_HEIGHT, не радіє й не пилить: ракету просто піднімаємо
## на PREVIEW_HOVER із тим самим тремтінням і теліпанням лапок.
## Стан тримається, поки не покличуть звичайний API (біг/спринт/удар/стрибок).
func preview_pose(a: Anim) -> void:
	_anim_hold_t = 0.0
	_pose_only = true
	_pose_hover = PREVIEW_HOVER if a == Anim.ROCKET or a == Anim.FLY else 0.0
	if a == anim_state:
		return
	_exit_anim(anim_state)
	anim_state = a
	_enter_anim(a)


## Тимчасова поза на sec секунд — далі назад у базовий стан.
func _hold_anim(a: Anim, sec: float) -> void:
	_pose_only = false
	_pose_hover = 0.0
	_anim_return = _base_anim()
	_anim_hold_t = maxf(0.05, sec)
	set_anim_state(a)


## Спринт (кінець рівня або супернапій) — вмикається ззовні, як і кульгання.
func set_sprint(on: bool) -> void:
	if _sprint == on:
		return
	_sprint = on
	_refresh_anim()


## Кульгає (мало сердець / щойно отримав удар).
func set_limp(on: bool) -> void:
	if _limp == on:
		return
	_limp = on
	_refresh_anim()


## Розгін (присідає й розганяється) на sec секунд.
func charge(sec: float) -> void:
	_hold_anim(Anim.CHARGE, sec)


## Танець (три зірочки, дім): один повний оберт і підскоки, далі — назад у попередній стан.
func dance(sec: float = DANCE_SEC) -> void:
	_hold_anim(Anim.DANCE, sec)


## Фірмова родзинка героя на розгоні (стан CHARGE, а з v1.6 §3c — ще й суперсила).
## У кожного своя й НАВМИСНО крихітна: одна частинка-подія, без нових станів анімації.
##   лисеня  — іскри-слід за спиною          ведмежа  — бульбашка щита
##   оленя   — пилюка з-під копит            котик    — блискітки навколо
##   песик   — світиться носик               єдиноріг — іскри від рога + веселковий слід
##   зайчик  — нічого (його сила — сам стрибок)
func charge_accent() -> void:
	match hero_id:
		"lys":
			_accent_trail(accent, 0.9)
		"olen":
			FX.dust(self, Vector3(0.0, 0.05, 0.0))
		"pes":
			_nose_glow()
		"kit":
			FX.burst(self, Vector3(0.0, HEAD_TOP, 0.0), Palette.LEMON_PALE)
			_timed_sparkles(1.2)
		"med":
			set_shield(true)
		"odn":
			_horn_sparks()
			_accent_trail(Palette.RAINBOW[0], 1.4)
		"dolphin":
			FX.splash(self, Vector3(0.0, 0.1, 0.3))
			_accent_trail(Palette.SPLASH_WATER, 1.0)
		"turtle":
			set_shield(true)
		_:
			pass


## Короткий слід-іскри за героєм (сам зникає). Слід із крамниці не чіпаємо: він у слоті "trail".
## Емітер РІВНО ОДИН на розгін: раніше родзинка викликалась ще й із пилюки кожні 0,25 с,
## і за секунду за героєм тягнулось чотири сліди — це й були «занадто багато частинок».
func _accent_trail(col: Color, seconds: float) -> void:
	if _accent_node != null and is_instance_valid(_accent_node):
		return
	var tr := FX.trail(self, col)          # 16 частинок × 0,8 с ≈ 20 частинок/с
	tr.position = Vector3(0.0, 0.3, 0.3)
	_accent_node = tr
	get_tree().create_timer(maxf(0.1, seconds)).timeout.connect(func():
		if is_instance_valid(tr):
			tr.emitting = false
			tr.queue_free()
		if _accent_node == tr:
			_accent_node = null)


## Блискітки навколо героя на seconds (котик). Постійні блискітки «Іскринки» — це _sparkles,
## їх не чіпаємо: цей вузол свій і сам іде геть.
func _timed_sparkles(seconds: float) -> void:
	var sp := FX.sparkles(self, 0.6, 12)
	get_tree().create_timer(maxf(0.1, seconds)).timeout.connect(func():
		if is_instance_valid(sp):
			sp.emitting = false
			sp.queue_free())


## Іскри від рога єдинорога. Точка — «капелюшкова» кістка голови (у рига вона на маківці).
func _horn_sparks() -> void:
	var horn := _rig.anchor("hat") if _rig != null else null
	if horn == null:
		# воксельне тіло: сиплемо з маківки
		FX.burst(self, Vector3(0.0, HEAD_TOP, 0.0), Palette.H_ACC_PINK)
		return
	# вузол «hat» живе в координатах воксельної голови: низ голови по центру, висота HEAD_H
	FX.burst(horn, Vector3(0.0, HEAD_H, 0.0), Palette.H_ACC_PINK)


## Носик песика світиться NOSE_GLOW_SEC — маленька куля-емісія в точці обличчя.
func _nose_glow() -> void:
	var anchor := _face if is_instance_valid(_face) else _head
	if anchor == null or not is_instance_valid(anchor):
		return
	var glow := MeshInstance3D.new()
	glow.name = "NoseGlow"
	var sph := SphereMesh.new()
	sph.radius = 0.05
	sph.height = 0.1
	sph.radial_segments = 10
	sph.rings = 6
	glow.mesh = sph
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Palette.H_ACC_PINK
	m.emission_enabled = true
	m.emission = Palette.H_ACC_PINK
	m.emission_energy_multiplier = 2.0
	glow.material_override = m
	glow.position = Vector3(0.0, 0.09, -HEAD_HALF_D - 0.04)
	anchor.add_child(glow)
	var tw := create_tween()
	tw.tween_property(glow, "scale", Vector3.ONE * 1.6, NOSE_GLOW_SEC * 0.5)
	tw.tween_property(glow, "scale", Vector3.ZERO, NOSE_GLOW_SEC * 0.5)
	tw.finished.connect(glow.queue_free)


func is_airborne() -> bool:
	return _y > 0.02 or flying


## Стрибок. scale < 1 — нижчий (підскок на хвилі). Повертає false, якщо стрибнути не можна.
## У повітрі стрибок можливий лише з суперсилою «Подвійний стрибок» — і лише один раз за політ.
func jump(k: float = 1.0) -> bool:
	if tumbling or sitting:
		return false
	if is_airborne():
		if not double_jump or _double_used or flying:
			return false
		_double_used = true
		_vy = jump_velocity * k * jump_scale * DOUBLE_JUMP_K
		_squash(Vector3(0.9, 1.18, 0.9), 0.12)
		_flap(1.0)
		FX.dust(self, Vector3(0.0, 0.2, 0.0))
		return true
	_double_used = false
	_vy = jump_velocity * k * jump_scale
	ducking = false
	_squash(Vector3(0.9, 1.18, 0.9), 0.12)
	_flap(1.0)
	if _anim_hold_t <= 0.0:
		set_anim_state(Anim.JUMP)
	return true


## Короткий підскок у режимі Стрибки.
func hop() -> void:
	if _y < 0.15:
		# у присіді крок нижчий — щоб пролізти під павутинкою
		_vy = HOP_VELOCITY * (0.7 if ducking else 1.0)
		_squash(Vector3(0.94, 1.1, 0.94), 0.1)
		_flap(0.6)


## Кількість доріжок на дорозі (3/5/7) — з рівня.
var lanes := 3


func max_lane() -> int:
	return (lanes - 1) / 2


func x_limit() -> float:
	return float(max_lane()) * LANE_W + 0.3


## Дорога звузилась/розширилась: герой лишається на найближчій доріжці.
func set_lanes(n: int) -> void:
	lanes = clampi(n, 3, 7)
	if lanes % 2 == 0:
		lanes += 1
	lane = clampi(lane, -max_lane(), max_lane())
	x_target = clampf(x_target, -x_limit(), x_limit())
	if not free_x:
		x_target = float(lane) * LANE_W


func change_lane(dir: int) -> bool:
	var next := clampi(lane + dir, -max_lane(), max_lane())
	if next == lane:
		return false
	lane = next
	x_target = float(lane) * LANE_W
	return true


func snap_to_lane() -> void:
	lane = clampi(int(round(x_target / LANE_W)), -max_lane(), max_lane())
	x_target = float(lane) * LANE_W


func nudge_x(d: float) -> void:
	x_target = clampf(x_target + d * 0.8, -x_limit(), x_limit())


func set_duck(on: bool) -> void:
	var next := on and not tumbling
	# присів — хмаринка пилу під ногами
	if next and not ducking:
		FX.dust(self, Vector3(0, 0.03, 0))
	ducking = next


func tilt(v: float) -> void:
	_tilt = v


## Транспорт: дошка (Серфінг), мушля (Хвиля) або самокат (Місто). kind — назва вокселя.
## ЧОТИРИЛАПІ ЗВІРЯТА НЕ ЇЗДЯТЬ: меш транспорту не показуємо НІКОЛИ (playtest 09.09 —
## «незрозуміла синя штука під героєм» у Місті це був самокат під лапками рига).
## Режими лишились як були (ScooterMode — «біг + трампліни й рейки», швидший на 15 %),
## тож прапорець `_vehicle_on` живе далі: від нього залежить гойдання на хвилі (wave_offset).
var _vehicle_kind := "shell"
var _vehicle_on := false
## Невагомість (Хмаринки): 0.4 — герой падає повільно.
var gravity_scale := 1.0


func set_vehicle(on: bool, kind: String = "shell") -> void:
	_vehicle_on = on
	_vehicle_kind = kind if on else _vehicle_kind
	# меш лишається в дереві (API й тести ті самі), але не показується жодному героєві
	_vehicle.visible = false


# ---------- життя, щит, платформа ----------

## Скинути серця на початку рівня.
func reset_hearts() -> void:
	hearts = max_hearts
	invulnerable_t = 0.0
	_body.visible = true


## Втратити серце. Повертає false, якщо герой невразливий (удар не зараховано).
func lose_heart() -> bool:
	if invulnerable_t > 0.0:
		return false
	hearts = maxi(0, hearts - 1)
	set_invulnerable(1.5)
	return true


## +1 серце (пікап). false — уже повні.
func gain_heart() -> bool:
	if hearts >= max_hearts:
		return false
	hearts += 1
	_squash(Vector3(1.15, 0.85, 1.15), 0.12)
	FX.hearts(self, Vector3(0, 1.3, 0), 8)
	return true


## Невразливість на seconds: тіло миготить (видиме/невидиме кожні 0,1 с).
func set_invulnerable(seconds: float) -> void:
	invulnerable_t = maxf(invulnerable_t, seconds)
	_blink_vis_t = 0.0


## Щит-бульбашка (пікап): один удар поглинається.
func set_shield(on: bool) -> void:
	shield_on = on
	if on:
		_shield_popping = false
		_shield.visible = true
		_shield.scale = Vector3.ONE * 0.1
		var tw := create_tween()
		tw.tween_property(_shield, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif not _shield_popping:
		# лопання ще триває — сховає pop_shield у кінці твіну
		_shield.visible = false


## Щит лопнув — бризки й «пшик»; бульбашка ховається в кінці анімації.
func pop_shield() -> void:
	shield_on = false
	_shield_popping = true
	FX.burst(self, Vector3(0, 0.7, 0), Palette.HERO_SHIELD)
	var tw := create_tween()
	tw.tween_property(_shield, "scale", Vector3.ONE * 1.4, 0.12)
	tw.tween_callback(func():
		_shield_popping = false
		# якщо за цей час щит не підібрали знову — ховаємо
		if not shield_on:
			_shield.visible = false)


## Сісти («Ще раз!»): задні лапки підібгані, ніс донизу, очі заплющені на 0,5 с, біг вимкнено.
func sit() -> void:
	if _tumble_tween:
		_tumble_tween.kill()
		_tumble_tween = null
	tumbling = false
	ducking = false
	sitting = true
	running = false
	_body.position.y = -0.06
	_body.rotation.x = 0.3
	_body.visible = true
	invulnerable_t = 0.0
	_anim_hold_t = 0.0
	set_anim_state(Anim.IDLE)
	_set_eyes_closed(true)
	get_tree().create_timer(0.5).timeout.connect(func():
		if sitting and is_instance_valid(self):
			_set_eyes_closed(false))


## Встати після сидіння (новий старт рівня).
func stand() -> void:
	sitting = false
	_body.rotation.x = 0.0
	_body.position.y = 0.0
	_set_eyes_closed(false)
	_refresh_anim()


## Рівень землі під героєм (платформа другого рівня). Позиція у світі не стрибає:
## коли земля піднімається — висота стрибка перераховується; невеликий спуск (пандус) — герой тримається поверхні,
## великий (зійшов із платформи вбік) — падає.
func set_ground(h: float) -> void:
	var dy := h - ground_y
	if absf(dy) < 0.0005:
		return
	ground_y = h
	if dy > 0.0:
		if _y > 0.02:
			_y = maxf(0.0, _y - dy)
			if _y <= 0.0:
				_vy = 0.0
				landed.emit()
				_squash(Vector3(1.15, 0.85, 1.15), 0.09)
		else:
			# був на землі, а земля підскочила (зайшов на платформу збоку) — підскок разом із нею
			_y = 0.0
			_vy = 0.0
			if dy > 0.6:
				_squash(Vector3(0.9, 1.15, 0.9), 0.1)
	elif dy < -0.5:
		# зійшов із платформи — падає з висоти
		if _y <= 0.02:
			_y = -dy
			_vy = 0.0
	# малий спуск (пандус вниз) — лишаємось на поверхні: _y не чіпаємо


## Швидкість світу, м/с (Run3D кличе щокадру). ЧАСТОТУ ходи вона більше НЕ задає
## (та фіксована — RUN_CADENCE_HZ / SPRINT_CADENCE_HZ): від неї лишилась лише ±10 %
## модуляція РОЗМАХУ кроку (speed_amp_k). Метод лишається — його кличе Run3D, і швидкість
## читають інші системи.
func set_speed_mps(v: float) -> void:
	speed_mps = maxf(0.0, v)


## Швидкість, з якої рахується РОЗМАХ кроку: покрокові режими (Стрибки) дрейфують повільніше.
func _gait_speed() -> float:
	var v := speed_mps if speed_mps > 0.01 else DEFAULT_SPEED_MPS
	return v * run_speed_factor


func set_running(on: bool) -> void:
	running = on
	_refresh_anim()


## Комічне зіткнення (GDD v1.4 §2, реф. §3): великі очі, рот «О», відкинуло вбік на пів доріжки
## з обертом ±0,5 рад, три зірочки крутяться над головою 1,2 с, невразливість 1,5 с.
## Спавнер кличе tumble() — тому старе ім'я лишилось, а вигляд новий.
func tumble() -> void:
	# бік удару невідомий: відкидає навмання, але з краю дороги — до центру
	var dir := 1 if randf() < 0.5 else -1
	if absf(x_target) > (float(max_lane()) - 0.5) * LANE_W:
		dir = -1 if x_target > 0.0 else 1
	hit_reaction(dir)


## Комічна реакція на удар. dir — куди відкидає (−1 ліворуч, +1 праворуч, 0 — без зсуву).
func hit_reaction(dir: int = 0) -> void:
	if tumbling:
		return
	tumbling = true
	ducking = false
	_hold_anim(Anim.HIT, HIT_ANIM_SEC)
	# очі великі, зіниці меншають, рот «О»
	for e in _eyes:
		e.scale = Vector3(HIT_EYE_SCALE, HIT_EYE_SCALE, 1.0)
	for p in _pupils:
		p.scale = Vector3(HIT_PUPIL_SCALE, HIT_PUPIL_SCALE, 1.0)
	_mouth.scale = Vector3(1.6, 2.4, 1.0)
	_mouth.position.y = _mouth_y - 0.01
	# відкинуло вбік на пів доріжки (у межах дороги)
	if dir != 0:
		x_target = clampf(x_target + float(dir) * LANE_W * HIT_SIDE_LANES, -x_limit(), x_limit())
		lane = clampi(int(round(x_target / LANE_W)), -max_lane(), max_lane())
	_hit_stars()
	FX.burst(self, Vector3(0, HEAD_TOP, 0), Palette.STAR)
	FX.dust(self, Vector3(0, 0.05, 0))
	# невразливість ставимо відкладено: Spawner після tumble() кличе lose_heart(),
	# який мовчки нічого не робить, поки герой невразливий
	call_deferred("set_invulnerable", HIT_INVULN_SEC)
	if _tumble_tween:
		_tumble_tween.kill()
	var spin := float(dir if dir != 0 else 1) * HIT_SPIN
	_tumble_tween = create_tween()
	_tumble_tween.tween_property(_body, "rotation:y", spin, 0.18).set_trans(Tween.TRANS_BACK)
	_tumble_tween.parallel().tween_property(_body, "position:y", 0.22, 0.18)
	_tumble_tween.tween_property(_body, "rotation:y", 0.0, 0.32).set_trans(Tween.TRANS_ELASTIC)
	_tumble_tween.parallel().tween_property(_body, "position:y", 0.0, 0.32)
	_tumble_tween.finished.connect(_end_tumble)


## Три маленькі зірочки кружляють над головою 1,2 с.
func _hit_stars() -> void:
	var ring := Node3D.new()
	ring.name = "HitStars"
	ring.position = Vector3(0.0, HEAD_TOP + 0.22, 0.0)
	add_child(ring)
	for i in range(HIT_STARS):
		var s := VoxelBuilder.instance("star")
		s.scale = Vector3.ONE * 0.4
		var a := TAU * float(i) / float(HIT_STARS)
		s.position = Vector3(cos(a) * 0.32, sin(a * 2.0) * 0.05, sin(a) * 0.32)
		ring.add_child(s)
	var tw := create_tween()
	tw.tween_property(ring, "rotation:y", TAU * 2.0, HIT_STARS_SEC).from(0.0)
	tw.finished.connect(ring.queue_free)


func _end_tumble() -> void:
	_body.rotation.y = 0.0
	_body.position.y = 0.0
	tumbling = false
	# обличчя назад: очі, зіниці, рот
	for e in _eyes:
		e.scale = Vector3(1.0, _eye_scale_y, 1.0)
	for p in _pupils:
		p.scale = Vector3.ONE
	if is_instance_valid(_mouth):
		_mouth.scale = Vector3.ONE
		_mouth.position.y = _mouth_y
	# після відкидання герой стоїть на найближчій доріжці
	snap_to_lane()
	tumble_finished.emit()


## Політ (веселка): герой парить на висоті FLY_HEIGHT задані секунди.
func fly(seconds: float) -> void:
	flying = true
	_rocket = true
	_vy = 0.0
	_flap(1.0)
	_refresh_anim()
	get_tree().create_timer(seconds).timeout.connect(_end_fly)


func _end_fly() -> void:
	flying = false
	_rocket = false
	_refresh_anim()


## Зупинити політ негайно (ракета скінчилась/скинута): герой падає з поточної висоти.
func stop_fly() -> void:
	flying = false
	_rocket = false
	_vy = 0.0
	_refresh_anim()


func wave_bump() -> void:
	if not tumbling:
		_vy = 6.0
		_flap(1.0)


## Погладили: підскок, сквош, очі-щілинки від задоволення, усмішка, сердечка.
func pet() -> void:
	if not is_airborne() and not tumbling:
		_vy = 3.5
	_squash(Vector3(1.2, 0.8, 1.2), 0.15)
	_happy(0.7)
	_flap(0.8)
	FX.hearts(self, Vector3(0, 1.3, 0))
	AudioMgr.sfx("giggle")


## Радість (зірочки, станція): підскок, сквош, усмішка, сердечка.
func cheer() -> void:
	if not is_airborne() and not tumbling:
		_vy = 3.5
	_squash(Vector3(1.15, 0.85, 1.15), 0.12)
	_happy(0.6)
	_flap(1.0)
	FX.hearts(self, Vector3(0, 1.3, 0))


## Привітання: піднімає передню праву лапку ВПЕРЕД-угору й махає нею, широко всміхається.
## Очі при цьому лишаються великими й розплющеними: примружені повіки, підморгування чи
## погляд убік на морді звірятка читаються як сердитий примружений погляд, тому на весь
## час привітання обличчя «замкнене» (_face_lock_t) — ні кліпання, ні косування.
func wave_hello() -> void:
	if _legs.size() < 2 and _rig == null:
		return
	# тримається рівно стільки, скільки живе стан WAVE: інакше тіло вже опустилось би
	# з дибків, а лапка ще махала б
	_wave_t = WAVE_ANIM_SEC           # поки махає — _process цю лапку не чіпає
	_face_lock_t = _wave_t            # і не чіпає повіки з зіницями
	_hold_anim(Anim.WAVE, WAVE_ANIM_SEC)
	# лапку піднімає й гойдає сам _process (за _wave_blend) — однаково в кістках і у
	# вокселях. Окремого твіна більше нема: два джерела правди розходились у числах
	# очі розплющені й дивляться прямо, рот — усмішка (без замружування).
	# Кліпання, що вже почалось, обриваємо — інакше воно тримало б повіки напівзаплющеними
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = null
	_blink_t = 0.0
	_set_eyes_closed(false)
	for p in _pupils:
		p.position.x = 0.0
	_smile(_wave_t)
	AudioMgr.voice("hello")


## Повернутись обличчям до камери (меню/карусель) або вперед по дорозі.
func face_camera(on: bool, duration: float = 0.5) -> void:
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(self, "rotation:y", PI if on else 0.0, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## «Пух!» росту.
func pop_grow() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 1.35, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC)
	FX.confetti(self, Vector3(0, 1.0, 0), 40)


## Сірий «ще не відкритий» вигляд (карусель героїв) — на всіх частинах звірятка.
func set_locked_look(locked: bool) -> void:
	if feature == "cloud":
		return
	if not locked:
		for m in _meshes:
			if is_instance_valid(m):
				m.material_override = null
		if _face != null:
			_face.visible = true
		return
	var m0 := VoxelBuilder.material()
	if m0 is ShaderMaterial:
		var d := (m0 as ShaderMaterial).duplicate() as ShaderMaterial
		d.set_shader_parameter("tint_strength", 0.7)
		d.set_shader_parameter("tint", Palette.HERO_GHOST)
		for m in _meshes:
			if is_instance_valid(m):
				m.material_override = d
	if _face != null:
		_face.visible = false


## Габарит для перевірки зіткнень (світові координати; герой завжди в z = 0). На платформі — вище за землю.
## Лишився таким самим, як у пухнастика v1.4, щоб перешкоди й спавнер працювали як раніше.
func hit_box() -> AABB:
	var h := 0.5 if ducking else 1.1
	return AABB(Vector3(position.x - 0.28, ground_y + _y, -0.28), Vector3(0.56, h, 0.56))


# ---------- анімація ----------

func _squash(to: Vector3, dur: float) -> void:
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_body, "scale", to, dur)
	tw.tween_property(_body, "scale", Vector3.ONE, dur * 1.5).set_trans(Tween.TRANS_ELASTIC)


## Вуха підскакують (rotation.z від базового розхилу), хвіст смикається (rotation.x),
## крильця/рюкзачок на спині махають. Осі різні з тими, що крутить _process, — не перетираються.
func _flap(strength: float) -> void:
	for i in range(_ears.size()):
		var e := _ears[i]
		if not is_instance_valid(e):
			continue
		var base: Vector3 = _ear_base[i]
		var side := -1.0 if i == 0 else 1.0
		var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(e, "rotation:z", base.z + side * 0.5 * strength, 0.12)
		tw.tween_property(e, "rotation:z", base.z, 0.4).set_trans(Tween.TRANS_ELASTIC)
	if _tail != null and is_instance_valid(_tail):
		var tw_tail := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_tail.tween_property(_tail, "rotation:x", _tail_base_x - 0.4 * strength, 0.12)
		tw_tail.tween_property(_tail, "rotation:x", _tail_base_x, 0.4).set_trans(Tween.TRANS_ELASTIC)
	var back = _slots.get("back")
	if back != null and is_instance_valid(back):
		var tw_back := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_back.tween_property(back, "rotation:x", -0.5 * strength, 0.12)
		tw_back.tween_property(back, "rotation:x", 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC)


## Широка усмішка, піднята вгору — не сумна. Очі не чіпаємо (див. _happy).
func _smile(seconds: float) -> void:
	if not is_instance_valid(_mouth):
		return
	_mouth.scale = Vector3(1.8, 2.5, 1.0)
	_mouth.position.y = _mouth_y + 0.02
	get_tree().create_timer(seconds).timeout.connect(func():
		if not is_instance_valid(_mouth):
			return
		_mouth.scale = Vector3.ONE
		_mouth.position.y = _mouth_y)


## Щасливе обличчя: очі-щілинки (замружився від задоволення) і усмішка.
## Для привітання НЕ годиться — там примружені очі читаються як сердиті, тому wave_hello()
## кличе саму лише _smile().
func _happy(seconds: float) -> void:
	_set_eyes_closed(true)
	_smile(seconds)
	get_tree().create_timer(seconds).timeout.connect(func():
		if is_instance_valid(self):
			_set_eyes_closed(false))


func _set_eyes_closed(closed: bool) -> void:
	for e in _eyes:
		e.scale.y = 0.12 if closed else _eye_scale_y


func _process(delta: float) -> void:
	_t += delta
	# x — до цілі
	position.x = lerpf(position.x, x_target, minf(1.0, delta * 12.0))
	# y — гравітація або політ
	var was_air := _y > 0.02
	if flying:
		_y = lerpf(_y, FLY_HEIGHT + sin(_t * 4.0) * 0.15, minf(1.0, delta * 4.0))
	elif _pose_only and _pose_hover > 0.0:
		# поза-прев'ю ракети: висить невисоко над землею, гравітації для неї нема
		_y = lerpf(_y, _pose_hover + sin(_t * 4.0) * 0.05, minf(1.0, delta * 4.0))
		_vy = 0.0
	else:
		_vy -= GRAVITY * gravity_scale * delta
		_y += _vy * delta
		if _y <= 0.0:
			_y = 0.0
			_vy = 0.0
			_double_used = false     # на землі другий стрибок знову доступний
			if was_air:
				landed.emit()
				_squash(Vector3(1.12, 0.86, 1.12), 0.09)
				_flap(-0.6)
				FX.dust(self, Vector3(0, 0.03, 0))
				if anim_state == Anim.JUMP and _anim_hold_t <= 0.0:
					set_anim_state(_base_anim())
	var bob := 0.0
	if feature == "cloud":
		bob = 0.12 + sin(_t * 2.2) * 0.06
	position.y = ground_y + _y + bob + (wave_offset if _vehicle_on else 0.0)
	# невразливість: тіло миготить кожні 0,1 с
	if invulnerable_t > 0.0:
		invulnerable_t -= delta
		_blink_vis_t += delta
		if _blink_vis_t >= 0.1:
			_blink_vis_t = 0.0
			_body.visible = not _body.visible
		if invulnerable_t <= 0.0:
			_body.visible = true
	# щит дихає
	if shield_on and _shield.visible:
		var sp := 1.0 + sin(_t * 5.0) * 0.04
		_shield.scale = Vector3(sp, sp, sp)
	# тінь лишається на землі (або подіумі), витягнута вздовж тіла, і меншає в польоті
	_shadow.position.y = -(position.y - ground_y) + 0.015
	var k := clampf((position.y - ground_y) / 2.5, 0.0, 1.0)
	_shadow.scale = Vector3(0.95 * (1.0 - k * 0.5), 1.0, 1.5 * (1.0 - k * 0.5))
	(_shadow.material_override as StandardMaterial3D).albedo_color.a = 0.32 * (1.0 - k * 0.7)
	# нахил: кермо + лін при зміні доріжки
	var lean := -(x_target - position.x) * 0.45
	rotation.z = lerpf(rotation.z, _tilt + lean, minf(1.0, delta * 10.0))
	# обличчя «замкнене» (привітання): великі розплющені очі, погляд прямо, без кліпання
	if _face_lock_t > 0.0:
		_face_lock_t -= delta
		if tumbling:
			_face_lock_t = 0.0          # удар сильніший за привітання: очі-блюдця лишаються
		else:
			for e in _eyes:
				e.scale.y = _eye_scale_y
	# очі дивляться в бік повороту (у замкненому обличчі — строго прямо)
	var look_x := 0.0 if _face_lock_t > 0.0 else clampf((x_target - position.x) * 0.12, -0.035, 0.035)
	for p in _pupils:
		p.position.x = lerpf(p.position.x, look_x, minf(1.0, delta * 8.0))
	# кліпання
	_blink_t += delta
	if _blink_t > _next_blink and _face_lock_t <= 0.0:
		_blink_t = 0.0
		_next_blink = randf_range(2.2, 5.0)
		_blink()
	# Соня зіває
	if feature == "sleepy":
		_yawn_t += delta
		if _yawn_t > 7.0:
			_yawn_t = 0.0
			_mouth.scale = Vector3(1.2, 3.5, 1.0)
			get_tree().create_timer(0.7).timeout.connect(func(): _mouth.scale = Vector3.ONE)
	if _wave_t > 0.0:
		_wave_t -= delta
	# стійка дибки привітання: вхід і вихід за WAVE_EASE (лінійно, без стрибків)
	_wave_blend = move_toward(_wave_blend, 1.0 if _wave_t > 0.0 else 0.0, delta / WAVE_EASE)
	# танець рахує власний час — від нього виляння ±DANCE_YAW із поверненням у нуль
	if anim_state == Anim.DANCE:
		_dance_t += delta
	# тимчасова поза (удар / привітання / розгін / танець) добігла кінця
	if _anim_hold_t > 0.0:
		_anim_hold_t -= delta
		if _anim_hold_t <= 0.0:
			_anim_hold_t = 0.0
			set_anim_state(_anim_return)
	# присід: плавний перехід 20/с
	_duck_blend = lerpf(_duck_blend, 1.0 if ducking else 0.0, minf(1.0, delta * 20.0))
	# ЗАМАХ перед розгоном: герой присідає, і рівно в кінці замаху вилітає родзинка героя
	if _charge_wind_t > 0.0:
		_charge_wind_t = maxf(0.0, _charge_wind_t - delta)
		if _charge_wind_t <= 0.0 and anim_state == Anim.CHARGE and not _pose_only:
			charge_accent()
			_squash(Vector3(0.9, 1.14, 0.9), 0.12)      # вистрілив із присіду
	# моторний профіль стану — з нього живуть і лапки, і тіло, і голова, і вуха, і хвіст
	var prof := _profile()
	# ЗАМАХ правимо просто в профілі — тоді обидва тіла (вокселі й кістки) сідають однаково
	var crouch := charge_crouch(_charge_wind_t)
	if crouch > 0.0:
		prof["body_y"] = float(prof["body_y"]) + CHARGE_WINDUP_DIP * crouch
		prof["leg_amp"] = float(prof["leg_amp"]) * (1.0 - crouch)   # у замаху лапки завмирають
	# ЧАСТОТА ХОДИ — ФІКСОВАНА КАДЕНЦІЯ СТАНУ (Гц), а не швидкість світу: 4+ Гц на розгоні
	# читались як мерехтіння (рішення Nick, тюнінг GDD v1.7). Фаза все одно НАКОПИЧУЄТЬСЯ —
	# перемикання стану (біг ↔ спринт) не перекидає лапки в іншу точку циклу.
	var leg_f := TAU * float(prof["leg_freq"])          # рад/с
	# «біговою» частотою для рига лишається каденція бігу — її ще читають старі виклики
	var run_f := TAU * RUN_CADENCE_HZ
	_gait_phase = fmod(_gait_phase + leg_f * delta, TAU)
	var phase := _gait_phase
	var galloping := running and not is_airborne() and not ducking and not sitting
	# швидкість світу керує тільки РОЗМАХОМ кроку, і то ледь — ±10 % (див. speed_amp_k)
	var speed_k := speed_amp_k(_gait_speed())
	var step_amp := float(prof["leg_amp"]) * speed_k
	var limp_leg := int(prof["limp_leg"])
	# КОВЗАННЯ опускає ВСЕ тіло (і воксельне, і скелетне) — глибина своя для кожного,
	# і риг про неї має знати, щоб підняти себе рівно настільки, щоб нічого не тонуло
	var slide_y := slide_body_y(_rig != null) * _duck_blend
	# ковзання на животі пилить З БОКІВ кожні SLIDE_DUST_SEC (поки герой на землі)
	if ducking and not is_airborne() and not tumbling:
		_slide_dust_t += delta
		if _slide_dust_t >= SLIDE_DUST_SEC:
			_slide_dust_t = 0.0
			FX.dust(self, Vector3(-SLIDE_DUST_X, 0.03, 0.1))
			FX.dust(self, Vector3(SLIDE_DUST_X, 0.03, 0.1))
	else:
		_slide_dust_t = SLIDE_DUST_SEC          # почав ковзати — пилюка одразу, без затримки
	# розгін пилить з-під лап кожні 0,25 с. РОДЗИНКУ героя звідси НЕ кличемо: вона
	# спрацьовує один раз, у кінці замаху (інакше за секунду набігало чотири сліди)
	if anim_state == Anim.CHARGE and _charge_wind_t <= 0.0:
		_charge_dust_t += delta
		if _charge_dust_t >= CHARGE_DUST_SEC:
			_charge_dust_t = 0.0
			FX.dust(self, Vector3(0, 0.03, 0))
	# лапки: природний 4-ТАКТНИЙ КРОК (не рись!) — копитця ставляться по черзі
	# задня ліва → передня ліва → задня права → передня права (Hero3D.gait_phase;
	# _legs: 0 FL, 1 FR, 2 BL, 3 BR). У махові лапка ще й ПІДНІМАЄТЬСЯ на GAIT_PAW_LIFT:
	# воксельна лапка — один меш без коліна, тож «згин» емулюємо зсувом угору
	# (у кістках те саме робить згин нижньої ланки, HeroRig.GAIT_LOWER_BEND).
	# Стрибок — підібгані (пари «перед/зад»), ракета — звисають униз-назад (оленята Санти),
	# танець — передні перекочують вагу, привітання — дибки, ковзання — розкидані ВБОКИ
	if not tumbling:
		for i in range(_legs.size()):
			var front := i < 2
			var amp := float(prof["leg_amp"])
			var a := 0.0
			var lift := 0.0                     # 0…1, підйом копитця в махові
			if anim_state == Anim.ROCKET:
				# лапки звисають ВНИЗ-НАЗАД (оленята Санти), а не теліпаються навколо нуля:
				# фіксований кут назад (мінус = назад) плюс повільне похитування ±leg_amp
				var back := ROCKET_LEG_BACK_FRONT if front else ROCKET_LEG_BACK
				a = -back + sin(_t * TAU * ROCKET_SWAY_HZ) * amp
			elif is_airborne():
				a = -amp if front else amp      # у стрибку лапки підібгані під себе
			elif anim_state == Anim.DANCE:
				if front:
					# перекочування ваги з лапки на лапку за DANCE_LEG_EASE — без клацання
					var w := HeroRig.dance_leg_weight(_t, i, DANCE_BPS, DANCE_LEG_EASE)
					a = lerpf(-0.1, -amp, w)
				else:
					# у підйомі підскоку задні лапки витягуються — тіло йде вгору,
					# а копитця лишаються на землі
					a = 0.15 + DANCE_HIND_EXT * HeroRig.dance_bounce(_t, DANCE_BPS)
			elif galloping:
				var phi := phase + TAU * gait_phase(i)
				a = sin(phi) * step_amp
				lift = gait_lift(phi)
			else:
				a = sin(_t * 1.4 + (0.0 if i % 2 == 0 else 1.1)) * 0.05
			if i == limp_leg:
				a *= 0.3                        # кульгає: хвора лапка ледь працює
				lift *= 0.3
			var wave_yaw := 0.0
			if _wave_blend > 0.001:
				# привітання: герой стає дибки — передня ліва підібгана, права махає
				# вгору-вниз і навколо вертикалі, а задні КОНТР-обертаються на −WAVE_PITCH,
				# щоб лишитись вертикальними під нахиленим тілом і не з'їхати з дороги
				var target := -WAVE_PITCH
				if i == 1:
					target = WAVE_LIFT + sin(_t * TAU * WAVE_HZ) * WAVE_LIFT_SWING
					wave_yaw = (-WAVE_OUT + sin(_t * TAU * WAVE_HZ) * WAVE_YAW) * _wave_blend
				elif front:
					target = WAVE_LIFT_TUCK
				a = lerpf(a, target, _wave_blend)
				lift = lerpf(lift, 0.0, _wave_blend)
			# ковзання на животі: лапки не підібгані під себе, а випрямлені (кут по x → 0)
			# і РОЗКИДАНІ ВБОКИ — це вже оберт навколо z, нижче
			if _duck_blend > 0.01:
				a = lerpf(a, 0.0, _duck_blend)
				lift = lerpf(lift, 0.0, _duck_blend)
			_legs[i].rotation.x = lerpf(_legs[i].rotation.x, a, minf(1.0, delta * 18.0))
			_legs[i].rotation.y = lerpf(_legs[i].rotation.y, wave_yaw, minf(1.0, delta * 18.0))
			var leg_side := -1.0 if i % 2 == 0 else 1.0     # 0/2 — ліві, 1/3 — праві
			# +z-оберт веде кінчик лапки в +x, тож ліва йде назовні від'ємним кутом
			_legs[i].rotation.z = lerpf(_legs[i].rotation.z,
				leg_side * SLIDE_SPLAY * _duck_blend, minf(1.0, delta * 18.0))
			# підйом копитця в махові (шарнір лапки їде вгору, сам меш не розтягується)
			_legs[i].position.y = lerpf(_legs[i].position.y, LEG_H + lift * GAIT_PAW_LIFT,
				minf(1.0, delta * 18.0))
			if i < _leg_base_x.size():
				# розгін ставить лапки ширше
				var bx: float = _leg_base_x[i] + leg_side * float(prof["leg_spread"])
				_legs[i].position.x = lerpf(_legs[i].position.x, bx, minf(1.0, delta * 10.0))
	# скелетний герой: усе тіло (лапки, таз, хребет, шия, вуха, хвіст) крутять кістки.
	# Обличчя, аксесуари, тінь, щит, нахил, сквош і hit_reaction лишаються спільними —
	# вони живуть на self/_body, а риг висить усередині _body.
	if _rig != null:
		_rig.animate(delta, {
			"t": _t, "run_f": run_f, "speed_k": speed_k, "galloping": galloping,
			"running": running, "airborne": is_airborne(), "ducking": ducking,
			"duck_blend": _duck_blend, "sitting": sitting, "tumbling": tumbling,
			"wave": _wave_t, "wave_blend": _wave_blend,
			# на скільки Hero3D опустив УСЕ тіло (ковзання) — риг це компенсує підйомом
			"body_offset": slide_y,
			# словник анімацій (GDD v1.6 §5): риг живе з того самого профілю, що й вокселі
			"prof": prof, "leg_f": leg_f, "phase": phase, "dance_t": _dance_t,
			"anim": int(anim_state), "anim_name": anim_name(),
			"rocket": anim_state == Anim.ROCKET, "dance": anim_state == Anim.DANCE,
		})
	# голова: контр-боб до тіла, у присіді витягується вперед-униз
	# (у скелетному режимі _head — це точка на кістці голови, її позицію чіпати не можна)
	if _head != null and _rig == null and not tumbling:
		var head_y := NECK_Y
		var head_z := NECK_Z
		var head_pitch := float(prof["head_pitch"])
		if galloping:
			head_y += -sin(phase) * 0.02
			head_pitch += -sin(phase + 1.2) * 0.06
		elif not running and not sitting:
			head_y += sin(_t * 3.0) * 0.008
		if _duck_blend > 0.01:
			# ковзання: голова витягнута вперед і ледь донизу — вздовж землі, а не «під раму»
			head_y = lerpf(head_y, NECK_Y - 0.04, _duck_blend)
			head_z = lerpf(head_z, NECK_Z - 0.08, _duck_blend)
			head_pitch = lerpf(head_pitch, SLIDE_HEAD_PITCH, _duck_blend)
		# привітання: тіло стало дибки (ніс угору), тож голова доверстує РІВНО стільки ж назад —
		# морда лишається горизонтальною й дивиться в камеру; плюс крен до піднятої лапки
		if _wave_blend > 0.001:
			head_pitch = WAVE_HEAD_PITCH * _wave_blend
		_head.position.y = lerpf(_head.position.y, head_y, minf(1.0, delta * 14.0))
		_head.position.z = lerpf(_head.position.z, head_z, minf(1.0, delta * 14.0))
		_head.rotation.x = lerpf(_head.rotation.x, head_pitch, minf(1.0, delta * 12.0))
		_head.rotation.z = lerpf(_head.rotation.z, WAVE_HEAD_ROLL * _wave_blend,
			minf(1.0, delta * 8.0))
	# вуха: поза з профілю (нашорошені / прищулені / звислі), інерція на бігу, сіпання у спокої
	var ear_mode := String(prof["ears"])
	var ear_pose := 0.0
	match ear_mode:
		"up": ear_pose = -0.25
		"back": ear_pose = 0.35
		"down": ear_pose = 0.8
	if _duck_blend > 0.01:
		ear_pose = lerpf(ear_pose, 0.35, _duck_blend)      # ковзання: вуха прищулені назад
	var ear_lag := -sin(phase - 0.9) * 0.26 if galloping else 0.0
	for i in range(_ears.size()):
		var e := _ears[i]
		if not is_instance_valid(e):
			continue
		var idle := sin(_t * 1.3 + float(i)) * 0.03 if ear_mode == "free" else 0.0
		e.rotation.x = lerpf(e.rotation.x, _ear_base[i].x + ear_pose + ear_lag + idle,
			minf(1.0, delta * 10.0))
	if not running and not _ears.is_empty():
		_twitch_t += delta
		if _twitch_t > 4.5:
			_twitch_t = randf_range(-1.5, 0.0)
			_ear_twitch()
	# хвіст: махає (швидше на бігу), стирчить угору, витягнутий струною
	# або тримається вгорі й швидко виляє — "wag_up" (танець)
	if _tail != null and is_instance_valid(_tail) and not tumbling:
		# виляння режиму тримаємо ОКРЕМО від базового (_tail_yaw), інакше лерпи режимів
		# «наздоганяли» б власне ж базове виляння й воно затухало
		# у ковзанні хвіст витягнутий назад незалежно від режиму профілю
		match ("straight" if _duck_blend > 0.5 else String(prof["tail"])):
			"up":
				_tail.rotation.x = lerpf(_tail.rotation.x, _tail_base_x - 0.6, minf(1.0, delta * 8.0))
				_tail_yaw = sin(_t * 4.0) * 0.12
			"down":
				# ракета: хвіст звисає ВНИЗ (плюс по x — вниз) і повільно похитується
				_tail.rotation.x = lerpf(_tail.rotation.x, _tail_base_x - ROCKET_TAIL_DOWN,
					minf(1.0, delta * 8.0))
				_tail_yaw = sin(_t * TAU * ROCKET_TAIL_HZ) * ROCKET_TAIL_SWAY
			"straight":
				_tail.rotation.x = lerpf(_tail.rotation.x, _tail_base_x, minf(1.0, delta * 8.0))
				_tail_yaw = lerpf(_tail_yaw, 0.0, minf(1.0, delta * 8.0))
			"wag_up":
				# танець: хвіст ТРИМАЄТЬСЯ ВГОРІ (мінус по x — угору, як у режимі "up")
				# і швидко виляє ліворуч-праворуч навколо ВЕРТИКАЛІ (y), а не крутиться
				_tail.rotation.x = lerpf(_tail.rotation.x, _tail_base_x - DANCE_TAIL_LIFT,
					minf(1.0, delta * 8.0))
				_tail_yaw = sin(_t * TAU * DANCE_TAIL_HZ) * DANCE_TAIL_WAG
			_:
				# звичайне махання: хвіст повертається у свій базовий нахил (після "up"/"wag_up")
				_tail.rotation.x = lerpf(_tail.rotation.x, _tail_base_x, minf(1.0, delta * 8.0))
				_tail_yaw = sin(_t * (7.0 if galloping else 3.0)) * (0.45 if galloping else 0.25)
		# базове тихе виляння — у КОЖНОМУ режимі: хвіст ніколи не стоїть кілком,
		# а на кроці він іще й ВРІВНОВАЖУЄ корпус — відмахує ПРОТИ крену тіла
		_tail.rotation.y = _tail_yaw + sin(_t * TAU * TAIL_IDLE_HZ) * TAIL_IDLE \
			+ (-sin(phase) * GAIT_TAIL_YAW if galloping else 0.0)
	# шарфик гойдається
	var neck = _slots.get("neck")
	if neck != null and is_instance_valid(neck):
		neck.rotation.z = sin(_t * 3.0) * 0.12
		neck.rotation.x = sin(_t * 2.3 + 1.0) * 0.06
	if _hat_spin and is_instance_valid(_hat):
		_hat.rotation.y += delta * 7.0
	# біг-боб / дихання / присід — на тілі, щоб не ламати перекид; сидить — тіло не чіпаємо
	if not tumbling and not sitting:
		var target_scale := Vector3.ONE
		var body_y := float(prof["body_y"])
		var body_z := 0.0
		var lean_x := float(prof["body_pitch"])
		# привітання: ті самі числа, що в профілі WAVE, але через бленд — так у стійку
		# дибки входимо й виходимо за WAVE_EASE, а не стрибком на зміні стану
		if _wave_blend > 0.001:
			if _rig != null:
				# у скелетного героя дибки робить оберт УСЬОГО вузла моделі навколо задніх
				# копит (HeroRig._place_root) — обгортку не чіпаємо, інакше нахил лічився б двічі
				body_y = 0.0
				lean_x = 0.0
			else:
				# + = перед УГОРУ (той самий знак, що й «мах лапки вперед»); посадки тіла
				# більше нема — герой не сідає, а саме зводиться дибки
				body_y = 0.0
				lean_x = WAVE_PITCH * _wave_blend
				# нахил крутиться НАВКОЛО ЗАДНІХ ЛАПОК НА ЗЕМЛІ, а не навколо початку
				# тіла — інакше зад іде під підлогу. Компенсуємо зсув тієї самої точки
				var comp := pivot_offset(lean_x, WAVE_PIVOT)
				body_y += comp.y
				body_z = comp.z
		var rate := 14.0
		if ducking:
			# КОВЗАННЯ НА ЖИВОТІ: тіло лягає на землю (SLIDE_BODY_Y), корпус лишається
			# рівним (лапки розкидані вбоки — див. вище), сквош мінімальний: сплющувати
			# героя не треба, він і так унизу
			target_scale = Vector3(1.03, 0.95, 1.03) if _rig != null else Vector3(1.08, 0.9, 1.08)
			rate = 20.0
		elif galloping:
			var step_bob := absf(sin(phase))
			if limp_leg >= 0:
				# кульгає — боб нерівний: другий гармонік робить «хворий» крок нижчим
				step_bob = absf(sin(phase)) * 0.7 + absf(sin(phase * 2.0 + 0.6)) * 0.3
			body_y += step_bob * 0.05 * run_speed_factor * float(prof["bob_amp"])
			# хвиля корпусу на ПОДВОЄНІЙ частоті кроку (те саме робить хребет рига)
			lean_x += -0.05 + sin(phase * 2.0) * GAIT_SPINE_FLEX
			target_scale = Vector3(1.0, 1.0 + sin(phase * 2.0) * 0.025, 1.0)
		elif anim_state == Anim.ROCKET:
			body_y += sin(_t * 3.0) * 0.05 * float(prof["bob_amp"])
		else:
			var breath := sin(_t * 4.0) * 0.02
			target_scale = Vector3(1.0 + breath, 1.0 - breath, 1.0 + breath)
		# танець: м'який підскок на кожен біт (smoothstep, без гострих розворотів синуса)
		if float(prof["hop"]) > 0.0:
			body_y += HeroRig.dance_bounce(_t, DANCE_BPS) * DANCE_HOP * float(prof["hop"])
		# СКЕЛЕТНИЙ ГЕРОЙ: усе вертикальне й нахил корпусу вже зробили кістки (таз і хребет
		# у HeroRig.animate читають ТОЙ САМИЙ профіль). Вузол-обгортку ними не рухаємо —
		# інакше боб, спринт і ракета лічились би ДВІЧІ, і герой на спринті сідав під дорогу
		if _rig != null:
			body_y = 0.0
			lean_x = 0.0
		if _duck_blend > 0.01:
			rate = 20.0
			# ковзання: усе тіло лягає на землю (своя глибина для рига й для вокселів),
			# корпус РІВНИЙ (нахилу нема — герой не навпочіпки)
			body_y = lerpf(body_y, slide_body_y(_rig != null), _duck_blend)
			lean_x = lerpf(lean_x, 0.0, _duck_blend)
		# після присіду відстань до цілі велика — пускаємо лерп і тоді (сквош-твін не заважає: він короткий)
		if _body.scale.distance_to(target_scale) < 0.3 or _duck_blend > 0.01:
			_body.scale = _body.scale.lerp(target_scale, minf(1.0, delta * rate))
		_body.rotation.x = lerpf(_body.rotation.x, lean_x, minf(1.0, delta * 6.0))
		# ковзання ще й ледь похитує корпусом з боку в бік — інакше поза мертва;
		# на кроці корпус КРЕНИТЬ на частоті циклу (те саме робить таз рига)
		_body.rotation.z = sin(_t * TAU * SLIDE_ROLL_HZ) * SLIDE_ROLL * _duck_blend \
			+ (sin(phase) * GAIT_HIP_ROLL if galloping else 0.0)
		# копитця на підлозі: нахили (спринт, дибки, підскоки) крутять тіло навколо ЙОГО центру
		# й топлять лапки — додаємо підйом ДО ЦІЛІ лерпа (а не поверх нього, інакше тіло
		# ганялося б саме за собою). Рахується після нахилу — з нього ж і береться базис
		_body.position.y = lerpf(_body.position.y, body_y + _voxel_ground_lift(body_y),
			minf(1.0, delta * 16.0))
		# ракета трясе тіло: 1–2 см по x/z, 20 разів на секунду
		var shake := float(prof["shake"])
		if shake > 0.0:
			_shake_t += delta
			if _shake_t >= 1.0 / SHAKE_HZ:
				_shake_t = 0.0
				_shake_off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_AMP * shake
			_body.position.x = _shake_off.x
			_body.position.z = _shake_off.y
		else:
			# z тримає компенсацію шарніра дибки (body_z), поза привітанням це просто нуль
			_body.position.x = lerpf(_body.position.x, 0.0, minf(1.0, delta * 10.0))
			_body.position.z = lerpf(_body.position.z, body_z, minf(1.0, delta * 10.0))
		# танець: виляння ±spin_y навколо вертикалі (ліворуч — назад — праворуч — назад).
		# Кут АБСОЛЮТНИЙ, не накопичений: обірваний посеред такту танець не лишає героя
		# розвернутим, а _exit_anim(DANCE) ще й доводить залишок до нуля твіном
		if absf(float(prof["spin_y"])) > 0.0001:
			_body.rotation.y = sin(TAU * _dance_t / DANCE_SEC) * float(prof["spin_y"])
	# у спокої (меню/станція) інколи озирається
	if anim_state == Anim.IDLE and not running and not tumbling and not sitting:
		_look_t += delta
		if _look_t > 3.5:
			_look_t = randf_range(-2.0, 0.0)
			var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(_body, "rotation:y", randf_range(-0.5, 0.5), 0.4).set_trans(Tween.TRANS_SINE)
			tw.tween_interval(0.8)
			tw.tween_property(_body, "rotation:y", 0.0, 0.4).set_trans(Tween.TRANS_SINE)


## На скільки підняти ВОКСЕЛЬНЕ тіло, щоб найнижча його точка не тонула в землі.
## Геометрія відома точно, мешів ніхто не читає:
##   • кінчик лапки — точка (0, −LEG_H, 0) у координатах лапки (шарнір на висоті LEG_H);
##   • низ тулуба — чотири кути коробки на висоті TORSO_Y навколо TORSO_Z.
## Обидві групи проводимо через базис тіла (нахил, оберт, масштаб).
## У КОВЗАННІ підйом ПРАЦЮЄ (лапки розкидані вбоки й тонули б у дорозі), тому в рахунок
## іде й ТУЛУБ: живіт лягає на дорогу, але не крізь неї, і голова лишається над нею.
## У повітрі підйому нема: герой висить навмисно.
## У скелетного героя список лапок порожній — там те саме робить HeroRig._apply_ground_lift.
## `body_y` — ЦІЛЬОВЕ (а не поточне) зміщення тіла: беремо саме його, інакше підйом
## рахувався б від уже піднятого тіла й ганявся сам за собою. Опускання пози НАВМИСНЕ
## (спринт притискає героя до землі) — окрім ковзання, яке ми якраз і сторожимо.
const TORSO_HALF := 0.28          ## півширина/півглибина коробки тулуба (та сама, що в hit_box)


func _voxel_ground_lift(body_y: float) -> float:
	if _legs.is_empty() or is_airborne():
		return 0.0
	var sliding := _duck_blend > 0.01
	var lowest := 0.0
	for leg in _legs:
		if not is_instance_valid(leg):
			continue
		# тільки БАЗИС тіла (нахил, оберт, масштаб) — без його позиції
		lowest = minf(lowest, (_body.basis * (leg.transform * Vector3(0.0, -LEG_H, 0.0))).y)
	if sliding:
		# чотири кути дна тулуба — у ковзанні саме живіт найнижчий
		for i in range(4):
			var sx := TORSO_HALF if i % 2 == 0 else -TORSO_HALF
			var sz := TORSO_HALF if i < 2 else -TORSO_HALF
			lowest = minf(lowest, (_body.basis * Vector3(sx, TORSO_Y, TORSO_Z + sz)).y)
		# у ковзанні опускання враховуємо ПОВНІСТЮ: нижче нуля не можна нічому
		return ground_lift(lowest + body_y, GROUND_LIFT_MAX_SLIDE)
	# поза ковзанням опускання пози навмисне (спринт), тож у рахунок іде лише підйом
	return ground_lift(lowest + maxf(body_y, 0.0), GROUND_LIFT_MAX)


## Одне вухо сіпається (спокій).
func _ear_twitch() -> void:
	if _ears.is_empty():
		return
	var i := randi() % _ears.size()
	var e := _ears[i]
	if not is_instance_valid(e):
		return
	var base: Vector3 = _ear_base[i]
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(e, "rotation:z", base.z + 0.35, 0.09)
	tw.tween_property(e, "rotation:z", base.z, 0.25).set_trans(Tween.TRANS_ELASTIC)


func _blink() -> void:
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_blink_tween = tw
	for e in _eyes:
		tw.parallel().tween_property(e, "scale:y", 0.08, 0.06)
	tw.chain()
	for e in _eyes:
		tw.parallel().tween_property(e, "scale:y", _eye_scale_y, 0.08)
