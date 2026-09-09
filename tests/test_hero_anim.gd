## Словник анімацій героя (GDD v1.6 §5): моторні профілі станів і пріоритет станів.
## Чисті статичні функції Hero3D — без сцени й без вокселів.
extends GutTest

const ALL_STATES := [
	Hero3D.Anim.IDLE, Hero3D.Anim.RUN, Hero3D.Anim.SPRINT, Hero3D.Anim.LIMP,
	Hero3D.Anim.DUCK, Hero3D.Anim.JUMP, Hero3D.Anim.ROCKET, Hero3D.Anim.CHARGE,
	Hero3D.Anim.DANCE, Hero3D.Anim.WAVE, Hero3D.Anim.HIT,
	Hero3D.Anim.FLY, Hero3D.Anim.GLIDE, Hero3D.Anim.HOP,
]
const EAR_MODES := ["up", "back", "down", "free"]
## "spin" більше нема: він крутив хвіст навколо не тієї осі, і той тонув у тулубі.
## Танець тепер тримає хвіст угорі й виляє ним навколо вертикалі — це режим "wag_up",
## а ракета ЗВИСАЄ хвостом донизу — режим "down".
const TAIL_MODES := ["wag", "up", "down", "straight", "wag_up"]


# ---------- профілі ----------

func test_every_state_has_every_key() -> void:
	for s in ALL_STATES:
		var p := Hero3D.profile_for(s)
		for k in Hero3D.PROFILE_KEYS:
			assert_true(p.has(k), "стан %s: нема ключа %s" % [Hero3D.ANIM_NAMES[int(s)], k])
		assert_eq(p.size(), Hero3D.PROFILE_KEYS.size(),
			"стан %s: у профілі зайві ключі" % Hero3D.ANIM_NAMES[int(s)])


func test_names_cover_all_states() -> void:
	assert_eq(Hero3D.ANIM_NAMES.size(), ALL_STATES.size(), "імена станів і enum розійшлись")
	for s in ALL_STATES:
		assert_ne(String(Hero3D.ANIM_NAMES[int(s)]), "", "стан без імені")


func test_modes_are_from_the_vocabulary() -> void:
	for s in ALL_STATES:
		var p := Hero3D.profile_for(s)
		assert_has(EAR_MODES, String(p["ears"]), "вуха: невідомий режим у %s" % Hero3D.ANIM_NAMES[int(s)])
		assert_has(TAIL_MODES, String(p["tail"]), "хвіст: невідомий режим у %s" % Hero3D.ANIM_NAMES[int(s)])


func test_values_are_sane() -> void:
	for s in ALL_STATES:
		var p := Hero3D.profile_for(s)
		var who: String = Hero3D.ANIM_NAMES[int(s)]
		assert_between(float(p["leg_amp"]), 0.0, 1.6, "%s: розмах лапок" % who)
		assert_between(float(p["leg_freq"]), 0.0, 2.0, "%s: частота лапок" % who)
		assert_between(float(p["shake"]), 0.0, 1.0, "%s: тремтіння" % who)
		assert_between(float(p["hop"]), 0.0, 1.0, "%s: підскоки" % who)
		assert_between(float(p["body_y"]), -0.4, 0.4, "%s: зсув тіла" % who)
		var limp := int(p["limp_leg"])
		assert_true(limp == -1 or (limp >= 0 and limp <= 3), "%s: хвора лапка поза 0..3" % who)


func test_run_and_sprint_differ() -> void:
	var run := Hero3D.profile_for(Hero3D.Anim.RUN)
	var sprint := Hero3D.profile_for(Hero3D.Anim.SPRINT)
	assert_gt(float(sprint["leg_amp"]), float(run["leg_amp"]), "спринт крокує ширше")
	assert_gt(float(sprint["leg_freq"]), float(run["leg_freq"]), "спринт частіший")
	assert_gt(float(sprint["body_pitch"]), 0.0, "спринт нахиляє ніс униз")
	assert_lt(float(sprint["body_y"]), 0.0, "спринт притискає героя до землі")
	assert_eq(String(sprint["ears"]), "back", "на спринті вуха назад")


func test_limp_is_a_limp() -> void:
	var p := Hero3D.profile_for(Hero3D.Anim.LIMP)
	var run := Hero3D.profile_for(Hero3D.Anim.RUN)
	assert_eq(int(p["limp_leg"]), Hero3D.LIMP_LEG, "кульгає передня ліва")
	assert_lt(float(p["leg_amp"]), float(run["leg_amp"]), "кроки коротші за біг")
	assert_lt(float(p["leg_freq"]), float(run["leg_freq"]), "темп нижчий за біг")
	assert_gt(float(p["head_pitch"]), 0.0, "голова опущена")
	assert_eq(String(p["ears"]), "down", "вуха звисають")


func test_rocket_shakes_and_dance_spins() -> void:
	var rocket := Hero3D.profile_for(Hero3D.Anim.ROCKET)
	assert_gt(float(rocket["shake"]), 0.0, "ракета трясе")
	assert_gt(float(rocket["body_y"]), 0.0, "ракета піднімає тіло")
	assert_eq(String(rocket["tail"]), "down", "у польоті хвіст ЗВИСАЄ, а не стирчить угору")
	var dance := Hero3D.profile_for(Hero3D.Anim.DANCE)
	# spin_y — АМПЛІТУДА виляння, а не швидкість: танець хитається на ±90° і повертається
	# в нуль, повний оберт за 2,4 с читався як «героя перекрутило»
	assert_almost_eq(float(dance["spin_y"]), PI * 0.5, 0.001,
		"танець виляє на ±90°, а не крутить повний оберт")
	assert_lte(float(dance["spin_y"]), PI, "виляння танцю не більше за півоберта")
	assert_gt(float(dance["hop"]), 0.0, "танець підскакує")
	assert_eq(String(dance["tail"]), "wag_up", "хвіст у танці тримається вгорі й виляє, а не крутиться")


## Ракета: лапки НЕ теліпаються навколо нуля, а звисають униз-назад (оленята Санти).
## У профілі лишається тільки розмах ПОХИТУВАННЯ; сама поза — в константах Hero3D.
func test_rocket_legs_hang_back() -> void:
	var rocket := Hero3D.profile_for(Hero3D.Anim.ROCKET)
	assert_almost_eq(float(rocket["leg_amp"]), Hero3D.ROCKET_LEG_SWAY, 0.0001,
		"leg_amp ракети — це розмах похитування, а не мах галопу")
	assert_eq(float(rocket["leg_freq"]), 0.0, "похитування має власну частоту, не від бігу")
	assert_lt(Hero3D.ROCKET_LEG_SWAY, 0.2, "похитування ледь помітне")
	assert_gt(Hero3D.ROCKET_LEG_BACK, 0.0, "лапки відведені назад від вертикалі")
	assert_gt(Hero3D.ROCKET_LEG_BACK_FRONT, Hero3D.ROCKET_LEG_BACK, "передні відведені більше")
	assert_lt(Hero3D.ROCKET_LEG_BACK_FRONT, PI * 0.5, "лапки звисають назад, а не задираються вгору")
	assert_almost_eq(Hero3D.ROCKET_LEG_BACK, 0.35, 0.0001, "задні звисають ПРЯМІШЕ (було 0,55)")


## Ракета: хвіст ЗВИСАЄ ВНИЗ і повільно похитується (а не стирчить угору, як лякливий).
func test_rocket_tail_hangs_down() -> void:
	assert_lt(Hero3D.ROCKET_TAIL_DOWN, 0.0, "мінус — це вниз")
	assert_almost_eq(Hero3D.ROCKET_TAIL_DOWN, -0.8, 0.0001)
	assert_almost_eq(Hero3D.ROCKET_TAIL_DOWN, HeroRig.ROCKET_TAIL_DOWN, 0.0001,
		"риг і вокселі — ті самі числа")
	assert_lt(Hero3D.ROCKET_TAIL_HZ, Hero3D.TAIL_IDLE_HZ, "похитування ПОВІЛЬНЕ")
	assert_lt(Hero3D.ROCKET_TAIL_SWAY, absf(Hero3D.ROCKET_TAIL_DOWN),
		"розмах менший за сам звис — хвіст не підстрибує вище горизонталі")
	assert_almost_eq(Hero3D.ROCKET_LEG_BACK, HeroRig.ROCKET_LEG_BACK, 0.0001)


## Ковзання на животі (присід): корпус РІВНИЙ і на землі, лапки розкидані вбоки.
func test_duck_is_a_belly_slide() -> void:
	var duck := Hero3D.profile_for(Hero3D.Anim.DUCK)
	assert_almost_eq(float(duck["body_pitch"]), 0.0, 0.0001,
		"ковзання не нахиляє корпус — це не присід навпочіпки")
	assert_almost_eq(float(duck["body_y"]), Hero3D.SLIDE_BODY_Y, 0.0001, "тіло лягає на землю")
	assert_lt(Hero3D.SLIDE_BODY_Y, -0.2, "живіт справді біля землі")
	assert_eq(String(duck["ears"]), "back", "вуха прищулені")
	assert_eq(String(duck["tail"]), "straight", "хвіст витягнутий назад")
	assert_almost_eq(float(duck["leg_amp"]), 0.0, 0.0001, "лапки не махають — вони розкинуті")
	assert_gt(Hero3D.SLIDE_SPLAY, 0.5, "розкид лапок помітний")
	assert_lt(Hero3D.SLIDE_SPLAY, PI * 0.5, "але не вивертає їх на 90°")
	assert_almost_eq(Hero3D.SLIDE_SPLAY, HeroRig.SLIDE_SPLAY, 0.0001, "риг і вокселі однаково")
	assert_almost_eq(Hero3D.SLIDE_HEAD_PITCH, HeroRig.SLIDE_HEAD_PITCH, 0.0001)
	assert_gt(Hero3D.SLIDE_ROLL, 0.0, "корпус ледь похитує")
	assert_lt(Hero3D.SLIDE_ROLL, 0.2, "похитування ледь помітне, а не перекид")
	assert_gt(Hero3D.SLIDE_DUST_SEC, 0.0, "пилюка з боків має період")


## Копитця на підлозі: підйом обмежений і однаковий у ригу й у вокселів.
func test_ground_lift_is_clamped() -> void:
	assert_gt(Hero3D.GROUND_LIFT_MAX, 0.0)
	assert_lt(Hero3D.GROUND_LIFT_MAX, 0.3, "підйом не має підкидати героя в небо")
	assert_almost_eq(Hero3D.GROUND_LIFT_MAX, HeroRig.GROUND_LIFT_MAX, 0.0001)
	assert_almost_eq(Hero3D.GROUND_EPS, HeroRig.GROUND_EPS, 0.0001)
	assert_lt(Hero3D.GROUND_EPS, Hero3D.GROUND_LIFT_MAX, "поріг менший за сам підйом")


## Хвіст у танці: тримається ВГОРІ й виляє навколо вертикалі — і ніколи не нижче горизонталі.
func test_dance_tail_stays_up() -> void:
	assert_gt(Hero3D.DANCE_TAIL_LIFT, 0.0, "хвіст піднятий")
	assert_lte(Hero3D.DANCE_TAIL_LIFT, PI * 0.5, "підйом не перекидає хвіст на спину")
	assert_gt(Hero3D.DANCE_TAIL_WAG, 0.0, "виляє")
	assert_lt(Hero3D.DANCE_TAIL_WAG, Hero3D.DANCE_TAIL_LIFT,
		"розмах виляння менший за підйом — хвіст не падає нижче горизонталі")
	assert_gt(Hero3D.DANCE_TAIL_HZ, Hero3D.DANCE_BPS, "виляє швидше, ніж б'є біт")


## Танець ЗГЛАДЖЕНИЙ: підскок без гострих розворотів, лапки перекочують вагу.
func test_dance_is_smooth() -> void:
	assert_almost_eq(Hero3D.DANCE_SEC, 3.0, 0.0001, "танець триває 3 секунди")
	assert_almost_eq(Hero3D.DANCE_BPS, 1.5, 0.0001, "півтора біти на секунду")
	assert_almost_eq(Hero3D.DANCE_SEC, HeroRig.DANCE_SEC, 0.0001, "риг і вокселі — ті самі числа")
	assert_almost_eq(Hero3D.DANCE_BPS, HeroRig.DANCE_BPS, 0.0001)
	assert_almost_eq(Hero3D.DANCE_LEG_EASE, 0.2, 0.0001, "перекочування ваги — 0,2 с")
	assert_lt(Hero3D.DANCE_LEG_EASE, 1.0 / Hero3D.DANCE_BPS, "згладжування коротше за такт")
	# підскок: тільки додатний, від нуля до одиниці, і БЕЗ зламу на нулі (smoothstep)
	var bps := Hero3D.DANCE_BPS
	assert_almost_eq(HeroRig.dance_bounce(0.0, bps), 0.0, 0.0001, "такт починається на землі")
	assert_almost_eq(HeroRig.dance_bounce(0.25 / bps, bps), 1.0, 0.0001, "вершина підскоку")
	assert_almost_eq(HeroRig.dance_bounce(0.75 / bps, bps), 0.0, 0.0001, "друга половина — на землі")
	for k in range(200):
		var v := HeroRig.dance_bounce(float(k) / 200.0 * 2.0, bps)
		assert_between(v, 0.0, 1.0, "підскок ніколи не від'ємний і не вище одиниці")
	# головне: на ВІДРИВІ й на ПРИЗЕМЛЕННІ крива полога. У старого |sin| там був злам,
	# і саме він читався як смикання (за 4 мс |sin| дає вже 0,038, smoothstep — 0,004)
	var eps := 0.004
	assert_lt(HeroRig.dance_bounce(eps, bps), 0.01, "відрив плавний, а не ривком")
	assert_lt(HeroRig.dance_bounce(0.5 / bps - eps, bps), 0.01, "приземлення теж м'яке")
	# лапки чергуються: на початку такту вага в однієї, на наступному — у другої
	assert_almost_eq(HeroRig.dance_leg_weight(0.9 / bps, 0, bps, Hero3D.DANCE_LEG_EASE), 1.0, 0.0001,
		"нульовий такт — піднята передня ліва")
	assert_almost_eq(HeroRig.dance_leg_weight(1.9 / bps, 0, bps, Hero3D.DANCE_LEG_EASE), 0.0, 0.0001,
		"наступний такт — вона вже опущена")
	assert_almost_eq(HeroRig.dance_leg_weight(1.9 / bps, 1, bps, Hero3D.DANCE_LEG_EASE), 1.0, 0.0001,
		"…а піднята друга")
	# на самій зміні такту ваги рівно навпіл — жодного клацання
	for i in range(2):
		var mid := HeroRig.dance_leg_weight(1.0 / bps + Hero3D.DANCE_LEG_EASE * 0.5, i, bps,
			Hero3D.DANCE_LEG_EASE)
		assert_almost_eq(mid, 0.5, 0.05, "лапка %d: вага перекочується, а не клацає" % i)
	# сума ваг завжди одиниця: скільки одна лапка взяла, стільки друга віддала
	for k in range(40):
		var t := float(k) * 0.05
		var sum := HeroRig.dance_leg_weight(t, 0, bps, Hero3D.DANCE_LEG_EASE) \
			+ HeroRig.dance_leg_weight(t, 1, bps, Hero3D.DANCE_LEG_EASE)
		assert_almost_eq(sum, 1.0, 0.0001, "вага не з'являється й не зникає")


## Привітання: герой ЗВОДИТЬСЯ ДИБКИ на задні лапки, а морда лишається в камері.
func test_wave_rears_up() -> void:
	var p := Hero3D.profile_for(Hero3D.Anim.WAVE)
	assert_lt(float(p["body_pitch"]), 0.0, "ніс угору (у наших знаках + = ніс униз)")
	assert_lte(float(p["body_pitch"]), -0.8, "це справжня дибка (≈50°), а не легкий нахил")
	assert_lt(float(p["body_y"]), 0.0, "таз сідає на задні лапки")
	assert_gt(float(p["head_pitch"]), 0.0, "голова доверстує КОНТР-нахилом (+ = морда вниз)")
	assert_lt(float(p["head_pitch"]), -float(p["body_pitch"]),
		"контр-нахил менший за нахил тіла — морда дивиться в камеру, а не в землю")
	assert_eq(String(p["ears"]), "up")
	assert_eq(String(p["tail"]), "down", "у дибках хвіст донизу")
	assert_almost_eq(float(p["leg_amp"]), absf(Hero3D.WAVE_LIFT), 0.0001,
		"leg_amp — РОЗМАХ лапки-«привіт» (знак у самій константі)")
	assert_lt(Hero3D.WAVE_LIFT, Hero3D.WAVE_LIFT_TUCK,
		"лапка, що махає, звисає нижче за підібгану другу")
	assert_between(Hero3D.WAVE_LIFT - Hero3D.WAVE_LIFT_SWING, -1.45, -1.35, "нижня межа помаху ≈ −1,4")
	assert_between(Hero3D.WAVE_LIFT + Hero3D.WAVE_LIFT_SWING, -1.05, -0.95, "верхня межа помаху ≈ −1,0")
	assert_almost_eq(Hero3D.WAVE_HZ, 3.0, 0.0001, "махає 3 рази на секунду")
	assert_gt(Hero3D.WAVE_HIND, 0.0, "задні лапки йдуть УПЕРЕД — під тіло")
	assert_gt(Hero3D.WAVE_EASE, 0.0, "у позу входимо й виходимо плавно")
	assert_almost_eq(Hero3D.WAVE_EASE, 0.3, 0.0001)
	assert_lt(Hero3D.WAVE_EASE, Hero3D.WAVE_ANIM_SEC, "згладжування коротше за саме привітання")
	# шарнір нахилу — стегно ЗАДНІХ лапок, інакше зад провалюється під підлогу
	assert_almost_eq(Hero3D.WAVE_PIVOT.y, Hero3D.LEG_H, 0.0001)
	assert_almost_eq(Hero3D.WAVE_PIVOT.z, Hero3D.HIP_Z_BACK, 0.0001)
	# і сама компенсація: точка шарніра після нахилу лишається на місці
	var comp := Hero3D.pivot_offset(Hero3D.WAVE_BODY_PITCH, Hero3D.WAVE_PIVOT)
	var moved := Basis(Vector3.RIGHT, Hero3D.WAVE_BODY_PITCH) * Hero3D.WAVE_PIVOT + comp
	assert_almost_eq(moved.y, Hero3D.WAVE_PIVOT.y, 0.0001, "шарнір не поїхав по висоті")
	assert_almost_eq(moved.z, Hero3D.WAVE_PIVOT.z, 0.0001, "шарнір не поїхав по глибині")
	assert_almost_eq(Hero3D.pivot_offset(0.0, Hero3D.WAVE_PIVOT).length(), 0.0, 0.0001,
		"без нахилу компенсації нема")
	# обидва тіла читають ОДНІ Й ТІ САМІ числа
	assert_almost_eq(Hero3D.WAVE_BODY_PITCH, HeroRig.WAVE_BODY_PITCH, 0.0001)
	assert_almost_eq(Hero3D.WAVE_BODY_Y, HeroRig.WAVE_BODY_Y, 0.0001)
	assert_almost_eq(Hero3D.WAVE_HEAD_PITCH, HeroRig.WAVE_HEAD_PITCH, 0.0001)
	assert_almost_eq(Hero3D.WAVE_LIFT, HeroRig.WAVE_LIFT, 0.0001)
	assert_almost_eq(Hero3D.WAVE_LIFT_TUCK, HeroRig.WAVE_LIFT_TUCK, 0.0001)
	assert_almost_eq(Hero3D.WAVE_LIFT_SWING, HeroRig.WAVE_LIFT_SWING, 0.0001)
	assert_almost_eq(Hero3D.WAVE_HIND, HeroRig.WAVE_HIND, 0.0001)
	assert_almost_eq(Hero3D.WAVE_HZ, HeroRig.WAVE_HZ, 0.0001)
	assert_almost_eq(Hero3D.WAVE_YAW, HeroRig.WAVE_YAW, 0.0001)


# ---------- хода: природний 4-тактний крок ----------

## Порядок постановки лап: задня ліва → передня ліва → задня права → передня права,
## рівними чвертями циклу. Індекси лапок: 0 fl · 1 fr · 2 bl · 3 br.
func test_gait_phase_table() -> void:
	# [bl, fl, br, fr] = [0, 0.25, 0.5, 0.75]
	assert_almost_eq(Hero3D.gait_phase(2), 0.0, 0.0001, "перша — задня ліва")
	assert_almost_eq(Hero3D.gait_phase(0), 0.25, 0.0001, "далі передня ліва")
	assert_almost_eq(Hero3D.gait_phase(3), 0.5, 0.0001, "далі задня права")
	assert_almost_eq(Hero3D.gait_phase(1), 0.75, 0.0001, "остання — передня права")
	# рівні чверті, усі чотири різні, і жодної діагональної пари в фазі (це вже не рись)
	var seen := {}
	for i in range(4):
		var ph := Hero3D.gait_phase(i)
		assert_between(ph, 0.0, 0.75, "зсув фази — частка циклу")
		assert_false(seen.has(ph), "лапки %d і %s ставляться одночасно" % [i, seen.get(ph, -1)])
		seen[ph] = i
	assert_ne(Hero3D.gait_phase(0), Hero3D.gait_phase(3), "fl і br більше НЕ в фазі (була рись)")
	assert_ne(Hero3D.gait_phase(1), Hero3D.gait_phase(2), "fr і bl теж")
	# індекс поза межами не валить гру
	assert_almost_eq(Hero3D.gait_phase(-1), 0.0, 0.0001)
	assert_almost_eq(Hero3D.gait_phase(9), 0.0, 0.0001)
	# одне джерело на обидва тіла
	for i in range(4):
		assert_almost_eq(Hero3D.gait_phase(i), HeroRig.gait_phase(i), 0.0001,
			"риг і вокселі крокують з однієї таблиці")


## Підйом копитця: лапка відривається від землі САМЕ в махові (коли йде вперед).
func test_gait_lift_only_in_swing() -> void:
	assert_almost_eq(Hero3D.gait_lift(0.0), 1.0, 0.0001, "початок маху — найвищий підйом")
	assert_almost_eq(Hero3D.gait_lift(PI), 0.0, 0.0001, "поштовх — лапка пряма")
	assert_almost_eq(Hero3D.gait_lift(PI * 0.5), 0.0, 0.0001, "межа маху й контакту")
	assert_eq(Hero3D.gait_lift(PI * 0.75), 0.0, "на контакті підйому нема взагалі")
	for k in range(16):
		var v := Hero3D.gait_lift(TAU * float(k) / 16.0)
		assert_between(v, 0.0, 1.0, "підйом — частка 0…1")
	assert_gt(HeroRig.GAIT_LOWER_BEND, 0.0, "нижня ланка згинається")
	assert_lte(HeroRig.GAIT_LOWER_BEND, 0.5, "але не більше ніж на 0,5 рад")
	assert_gt(HeroRig.GAIT_PAW_LIFT, 0.0, "воксельна лапка підіймається зсувом")
	assert_lt(HeroRig.GAIT_PAW_LIFT, 0.1, "підйом малий — це крок, а не стрибок")
	assert_almost_eq(Hero3D.GAIT_PAW_LIFT, HeroRig.GAIT_PAW_LIFT, 0.0001)


## Погойдування корпусу на кроці: крен тазу, хвиля хребта на 2× і відмах хвоста.
func test_gait_body_sway_is_subtle() -> void:
	assert_almost_eq(HeroRig.GAIT_HIP_ROLL, 0.03, 0.0001)
	assert_almost_eq(HeroRig.GAIT_SPINE_FLEX, 0.04, 0.0001)
	assert_almost_eq(HeroRig.GAIT_TAIL_YAW, 0.1, 0.0001)
	assert_lt(HeroRig.GAIT_HIP_ROLL, HeroRig.GAIT_TAIL_YAW, "хвіст урівноважує сильніше за крен")
	# обидва тіла читають ті самі числа (у Hero3D це псевдоніми констант HeroRig)
	assert_almost_eq(Hero3D.GAIT_HIP_ROLL, HeroRig.GAIT_HIP_ROLL, 0.0001)
	assert_almost_eq(Hero3D.GAIT_SPINE_FLEX, HeroRig.GAIT_SPINE_FLEX, 0.0001)
	assert_almost_eq(Hero3D.GAIT_TAIL_YAW, HeroRig.GAIT_TAIL_YAW, 0.0001)
	assert_almost_eq(Hero3D.GAIT_LOWER_BEND, HeroRig.GAIT_LOWER_BEND, 0.0001)


func test_charge_and_duck() -> void:
	var charge := Hero3D.profile_for(Hero3D.Anim.CHARGE)
	assert_gt(float(charge["leg_spread"]), 0.0, "на розгоні лапки ширше")
	assert_gt(float(charge["head_pitch"]), 0.0, "голова вниз")
	assert_eq(String(charge["ears"]), "back")
	var duck := Hero3D.profile_for(Hero3D.Anim.DUCK)
	assert_lt(float(duck["body_y"]), -0.1, "присід (ковзання) опускає тіло")
	# нахилу тіла в ковзанні нема — див. test_duck_is_a_belly_slide


func test_idle_is_calm() -> void:
	var p := Hero3D.profile_for(Hero3D.Anim.IDLE)
	assert_lt(float(p["leg_amp"]), 0.15, "у спокої лапки майже не рухаються")
	assert_eq(float(p["bob_amp"]), 0.0, "у спокої бобу нема")
	assert_eq(int(p["limp_leg"]), -1)


func test_reserved_states_have_profiles_too() -> void:
	# fly / glide / hop — поки лише словник, але профіль має бути повний
	for s in [Hero3D.Anim.FLY, Hero3D.Anim.GLIDE, Hero3D.Anim.HOP]:
		var p := Hero3D.profile_for(s)
		assert_false(p.is_empty(), "зарезервований стан без профілю")


# ---------- пріоритет станів ----------

func test_priority_hit_wins_over_everything() -> void:
	assert_eq(Hero3D.resolve_anim({
		"hit": true, "rocket": true, "charge": true, "sprint": true,
		"limp": true, "running": true}), Hero3D.Anim.HIT)


func test_priority_rocket_over_charge() -> void:
	assert_eq(Hero3D.resolve_anim({
		"rocket": true, "charge": true, "sprint": true, "limp": true, "running": true}),
		Hero3D.Anim.ROCKET)


func test_priority_charge_over_sprint() -> void:
	assert_eq(Hero3D.resolve_anim({
		"charge": true, "sprint": true, "limp": true, "running": true}), Hero3D.Anim.CHARGE)


func test_priority_sprint_over_limp() -> void:
	assert_eq(Hero3D.resolve_anim({"sprint": true, "limp": true, "running": true}),
		Hero3D.Anim.SPRINT)


func test_priority_limp_over_run() -> void:
	assert_eq(Hero3D.resolve_anim({"limp": true, "running": true}), Hero3D.Anim.LIMP)


func test_run_and_idle() -> void:
	assert_eq(Hero3D.resolve_anim({"running": true}), Hero3D.Anim.RUN)
	assert_eq(Hero3D.resolve_anim({"running": false}), Hero3D.Anim.IDLE)
	assert_eq(Hero3D.resolve_anim({}), Hero3D.Anim.IDLE, "порожні прапорці — спокій")


func test_resolver_ignores_unknown_flags() -> void:
	assert_eq(Hero3D.resolve_anim({"дзиґа": true, "running": true}), Hero3D.Anim.RUN)


# ---------- дані пікапа-супернапою ----------

func test_potion_pickup_speeds_up() -> void:
	var def := Pickup3D.def_of("potion")
	assert_false(def.is_empty(), "у data/pickups.json має бути пікап 'potion'")
	assert_gt(float(def.get("speed_mult", 0.0)), 1.0, "супернапій розганяє")
	assert_gt(float(def.get("seconds", 0.0)), 0.0, "супернапій має тривалість")
	assert_ne(String(def.get("letter", "")), "", "іконка HUD малює літеру")
	assert_true(FileAccess.file_exists("res://data/voxels/%s.json" % String(def.get("voxel", ""))),
		"воксель супернапою має існувати")


func test_potion_is_rare() -> void:
	var data := Pickup3D.load_all()
	var rates: Dictionary = (data.get("per_minute", {}) as Dictionary).get("young", {})
	assert_true(rates.has("potion"), "супернапій має бути в per_minute кожного профілю")
	for k in rates.keys():
		if String(k) == "potion":
			continue
		assert_lte(float(rates["potion"]), float(rates[k]), "супернапій — найрідший пікап")
