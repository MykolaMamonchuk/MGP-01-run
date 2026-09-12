## Правила рівня (GDD v1.4 §3, §10) — чисті функції без сцени, щоб їх могли перевірити тести.
## Гра без програшу: серця не перезапускають рівень, а перетворюються на зірки фінішу;
## коли серця скінчились — сорока краде 30 % злитків (але не більше 150), далі кожен удар −10%.
class_name Rules
extends RefCounted

## Зірок за рівень: скільки лишилось сердець (1..3).
const STARS_MIN := 1
const STARS_MAX := 3
## Скільки злитків забирає сорока при нулі сердець (EDD §2: було 0.5 — для 4-річної дитини
## «минус половина всього» найболючіший момент гри; лишили покарання, зменшили число).
const STEAL_SHARE := 0.3
## Стеля крадіжки: більше за стільки злитків сорока не забирає ніколи.
const STEAL_CAP := 150
## Скільки коштує кожен наступний удар після крадіжки.
const HIT_SHARE := 0.1
## Множник росте на +1 за кожні стільки перешкод, пройдених без удару.
const STREAK_STEP := 10
## Стеля множника (EDD §2: без стелі серія на 17-му рівні давала ×1500).
const MULT_CAP := 3
## Пікап «×2» подвоює множник.
const X2 := 2
## Бонус фінішу: стільки злитків за кожен номер рівня.
const FINISH_PER_LEVEL := 20
## Бонус фінішу: стільки злитків за кожну зірку.
const FINISH_PER_STAR := 10


## Зірки фінішу = серця, що лишились (мінімум 1, максимум 3).
static func stars_from_hearts(hearts: int) -> int:
	return clampi(hearts, STARS_MIN, STARS_MAX)


## Множник злитків: 1 + серія_без_удару / 10, стеля ×3, ×2 з пікапом «×2».
## Номер рівня в множнику НЕ бере участі (EDD §2): масштаб по рівнях дає довжина,
## щільність дороги й другий ярус, а не арифметика. Параметр level лишився заради
## сумісності викликів і навмисно не використовується.
static func multiplier(_level: int, streak: int, x2: bool) -> int:
	var m := clampi(1 + maxi(0, streak) / STREAK_STEP, 1, MULT_CAP)
	return m * (X2 if x2 else 1)


## Скільки злитків краде сорока: 30 % (донизу), але не більше за STEAL_CAP.
static func steal_amount(coins: int) -> int:
	return mini(int(floor(float(maxi(0, coins)) * STEAL_SHARE)), STEAL_CAP)


## Бонус фінішу рівня: 20 × номер рівня + 10 × зірки (EDD §2).
## Плаский бонус «20 + 10×зірки» на 17-му рівні важив 0,03 % доходу — «дійшов до кінця»
## нічого не значило; тепер фініш росте разом із рівнем.
static func finish_bonus(level: int, stars: int) -> int:
	return FINISH_PER_LEVEL * maxi(1, level) + FINISH_PER_STAR * clampi(stars, STARS_MIN, STARS_MAX)


## Скільки коштує удар після крадіжки (10%, донизу; ніколи менше 0).
static func hit_penalty(coins: int) -> int:
	return int(floor(float(maxi(0, coins)) * HIT_SHARE))


# ---------- суперсила героя (GDD v1.6 §3c) ----------

## Запасний заряд, якщо його нема ні в профілі, ні в даних героя.
const POWER_CHARGE_DEFAULT := 100


## Скільки злитків треба на суперсилу. Профіль ГОЛОВНІШИЙ за дані героя
## (малятам ставимо менше — 60, щоб сила спрацьовувала частіше); 0 або менше в профілі
## означає «нема свого значення, бери з даних героя».
static func power_charge_needed(profile_charge: int, data_charge: int) -> int:
	if profile_charge > 0:
		return profile_charge
	if data_charge > 0:
		return data_charge
	return POWER_CHARGE_DEFAULT


## Заповнення кільця кнопки, 0..1 (ділення на нуль неможливе).
static func power_progress(charge: int, needed: int) -> float:
	if needed <= 0:
		return 1.0
	return clampf(float(maxi(0, charge)) / float(needed), 0.0, 1.0)
