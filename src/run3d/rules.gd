## Правила рівня (GDD v1.4 §3, §10) — чисті функції без сцени, щоб їх могли перевірити тести.
## Гра без програшу: серця не перезапускають рівень, а перетворюються на зірки фінішу;
## коли серця скінчились — сорока краде половину злитків, далі кожен удар коштує −10%.
class_name Rules
extends RefCounted

## Зірок за рівень: скільки лишилось сердець (1..3).
const STARS_MIN := 1
const STARS_MAX := 3
## Скільки злитків забирає сорока при нулі сердець.
const STEAL_SHARE := 0.5
## Скільки коштує кожен наступний удар після крадіжки.
const HIT_SHARE := 0.1
## Множник росте на +1 «рівень» за кожні стільки перешкод, пройдених без удару.
const STREAK_STEP := 5
## Пікап «×2» подвоює множник.
const X2 := 2


## Зірки фінішу = серця, що лишились (мінімум 1, максимум 3).
static func stars_from_hearts(hearts: int) -> int:
	return clampi(hearts, STARS_MIN, STARS_MAX)


## Множник злитків: номер рівня × (1 + серія_без_удару / 5), ×2 з пікапом «×2».
static func multiplier(level: int, streak: int, x2: bool) -> int:
	var m := maxi(1, level) * (1 + maxi(0, streak) / STREAK_STEP)
	return m * (X2 if x2 else 1)


## Скільки злитків краде сорока (половина, донизу).
static func steal_amount(coins: int) -> int:
	return int(floor(float(maxi(0, coins)) * STEAL_SHARE))


## Скільки коштує удар після крадіжки (10%, донизу; ніколи менше 0).
static func hit_penalty(coins: int) -> int:
	return int(floor(float(maxi(0, coins)) * HIT_SHARE))
