## Стилі розмальовки скелетних героїв («текстура» без текстури).
##
## HeroRig фарбує модель ГРАНЯМИ: кожна грань іде за своєю кісткою в зону
## (морда / животик / копитця / вухо / хвіст…), зона → символ палітри (o d c k i e t m) →
## колір із heroes.json. Цього досить для звірятка «одного кольору з деталями», але не для
## єдинорога: там треба веселка вздовж гриви й хвоста, золоті смужки на розі та рідкі
## зірочки на боках. Щоб не заганяти це в HeroRig умовами «якщо єдиноріг», стиль винесено
## в дані: герой має поле `"rig_style": "unicorn"`, а тут лежить сам словник правил.
##
## Стиль може робити три речі (усе необов'язкове):
##   1. `palette`   — підмінити КОЛІР символа палітри (тіло `o` → біле, животик `d` →
##                    бузковий, писок `c` → рожево-білий, серединка вуха `i` → рожева).
##                    Символи ті самі, тож жодна зона в HeroRig не змінюється —
##                    змінюється лише фарба у відерці.
##   2. `zone_swap` — підмінити САМ СИМВОЛ, який повернула зона: {"k": "m"} робить копитця
##                    (і кінчик носа) кольором `mark`, тобто рожевими.
##   3. `face_paint(...)` — повернути ГОТОВИЙ колір для грані, повз усі зони: пояси гриви й
##                    хвоста, смужки на розі, копитця по лапках, сердечко на грудях,
##                    пастельні латки на боках, зірочки-блискітки.
##
## Плюс запасна ГЕОМЕТРИЧНА розкладка нових ролей (`mane`, `horn`) — поки Nick не вписав
## `rig_bones` після прев'ю, грива й ріг знаходяться самі, за положенням грані в коробці
## голови/шиї (див. remap_role).
##
## Новий герой зі своїм стилем = новий запис у RIG_STYLES + `"rig_style"` у heroes.json.
## Коду в HeroRig чіпати не треба.
class_name RigStyles
extends RefCounted

## Веселка гриви й хвоста: 6 стопів від носа до кінчика. Смуги ДИСКРЕТНІ (кожна грань цілком
## одного кольору) — так само, як усе інше в ригу: пласке затінення, різкі межі зон.
## Єдиноріг за замовчуванням веселкою НЕ фарбується (див. `bands` нижче), але веселка
## лишається доступною будь-якому стилю: `"rainbow": true` (грива й хвіст) або список ролей.
const RAINBOW := ["#FF5E7E", "#FFA94D", "#FFE66D", "#7CE38B", "#5DC8F5", "#B18CFF"]

## Ролі, які бере `"rainbow": true` (коротка форма замість списку).
const RAINBOW_ROLES := ["mane", "tail"]

## Скільки граней тулуба стають зірочками (0.03 = 3 %) — і сід, щоб малюнок не мерехтів
## між запусками (кожна грань має свій детермінований «кидок кубика», див. _rand01).
const SPARKLE_SEED := 20260908

## Символ зони «темне копитце» з HeroRig.ZONE_DARK. Дубль навмисно: HeroRig посилається
## на RigStyles, тож зворотнє посилання дало б циклічну залежність class_name.
const HOOF_ZONE := "k"

## Стилі. Ключ — значення поля `"rig_style"` у data/heroes.json.
const RIG_STYLES := {
	## Єдиноріг за референсом Nick: біле тіло з пастельними акцентами, а не веселка.
	"unicorn": {
		## тіло біле, животик бузково-білий, писок рожево-білий, серединка вуха рожева
		"palette": {"o": "#FFFFFF", "d": "#F3EEF8", "c": "#FBE9F0", "i": "#F48FB1"},
		## грива й хвіст: рожеві та коралові пояси по 25 % ланцюжка + рідкі помаранчеві грані
		"bands": {"roles": ["mane", "tail"], "colors": ["#F48FB1", "#FF9E7A"], "band": 0.25,
			"accent": "#FFB36B", "accent_chance": 0.12},
		## ріг: кремова й помаранчева смуги, що чергуються кожні 12 % його висоти
		"horn": {"colors": ["#F6E3C2", "#FFB36B"], "band": 0.12},
		## копитця: бірюза й м'ята НАВХРЕСТ (як діагональні пари рисі) — замість темних `k`
		"hooves": {"fl": "#5CC8B8", "br": "#5CC8B8", "fr": "#7ED9A0", "bl": "#7ED9A0"},
		## сердечко на грудях: передні 25 % глибини тулуба, ±30 % ширини від центру,
		## 40…80 % висоти (коробка тулуба рахується РАЗОМ із шиєю). Було вдвічі менше й
		## сиділо під пасмами гриви — 09.09 збільшили й підняли пріоритет (див. mark_paint).
		## Поки стиль має `chest_heart`, пошук ТОРБИНКИ вимкнено — інакше геометрія бачила б
		## «сумку» там, де просто широкі груди
		"chest_heart": {"color": "#E9B7F2", "depth": 0.25, "width": 0.6, "y": [0.40, 0.80]},
		## дві пастельні латки на боках тулуба (ліворуч ззаду й праворуч спереду), ≈ 6 % граней
		## кожна. Смуги — частки габариту ТУЛУБА в метрах героя: z = 1 перед, x < 0.5 ліворуч.
		## Права латка НЕ доходить до передніх 25 % глибини — там тепер сердечко
		"patches": [
			{"color": "#7ED9A0", "side": "left", "z": [0.05, 0.35], "y": [0.28, 0.66]},
			{"color": "#5CC8B8", "side": "right", "z": [0.50, 0.72], "y": [0.28, 0.66]},
		],
		## запасна геометрія гриви: задні 35 % глибини й верхні 40 % висоти голови/шиї.
		## `always` — працює НАВІТЬ коли кістки гриви задані: у моделі грива на потилиці й
		## гребінь уздовж шиї власних кісток не мають, кісткова гичка звисає лише спереду
		"mane_fallback": {"depth": 0.35, "height": 0.4, "always": true},
		## запасна геометрія рога: верхні 18 % голови, вужче за 15 % півширини, передня половина
		"horn_fallback": {"top": 0.18, "width": 0.15, "front": 0.5},
	},
}


## Стиль героя або {} (стилю нема — риг фарбується як завжди). Чиста функція.
static func for_def(def: Dictionary) -> Dictionary:
	var name := String(def.get("rig_style", ""))
	if name == "" or not RIG_STYLES.has(name):
		return {}
	return RIG_STYLES[name]


## Колір веселки за нормалізованим положенням уздовж ланцюжка (0 — основа, 1 — кінчик).
## Смуги дискретні: t ділиться на RAINBOW.size() рівних поясів, тож на 0, 0.5 і 1 повертаються
## РІВНО стопи (перший, четвертий, останній). Чиста функція.
static func rainbow(t: float) -> Color:
	var n := RAINBOW.size()
	var i := clampi(int(floor(clampf(t, 0.0, 1.0) * float(n))), 0, n - 1)
	return Color(String(RAINBOW[i]))


## Кольори героя + підміни стилю: {символ: Color}. Оригінал не змінюється. Чиста функція.
static func palette_of(style: Dictionary, colors: Dictionary) -> Dictionary:
	var out := colors.duplicate()
	var pal = style.get("palette", {})
	if typeof(pal) == TYPE_DICTIONARY:
		for k in (pal as Dictionary).keys():
			out[String(k)] = Color(String((pal as Dictionary)[k]))
	return out


## Підміна символа зони (копитця `k` → `m`). Нема правила — символ лишається. Чиста функція.
static func swap_zone(style: Dictionary, zone: String) -> String:
	var sw = style.get("zone_swap", {})
	if typeof(sw) == TYPE_DICTIONARY and (sw as Dictionary).has(zone):
		return String((sw as Dictionary)[zone])
	return zone


## Запасна ГЕОМЕТРИЧНА розкладка ролей `horn` і `mane`, поки їх нема в `rig_bones`.
## `local` — частки габариту коробки РОЛІ (див. HeroRig.local_of): x зліва направо,
## y знизу вгору, z від потилиці до переду.
## Повертає {"role": роль, "local": частки}. Для рога частки перераховуються під САМ РІГ
## (нижні 18 % коробки голови розтягуються на 0..1), інакше смужки по 12 % не помістились би.
## Чиста функція.
static func remap_role(style: Dictionary, role: String, local: Vector3,
		has_mane: bool, has_horn: bool) -> Dictionary:
	var out := {"role": role, "local": local}
	if style.is_empty():
		return out
	if role == "head" and not has_horn:
		var hf = style.get("horn_fallback", {})
		if typeof(hf) == TYPE_DICTIONARY and not (hf as Dictionary).is_empty():
			var top := float((hf as Dictionary).get("top", 0.18))
			if local.y >= 1.0 - top \
					and absf(local.x - 0.5) <= float((hf as Dictionary).get("width", 0.15)) \
					and local.z >= float((hf as Dictionary).get("front", 0.5)):
				var ly := (local.y - (1.0 - top)) / maxf(top, 0.0001)
				return {"role": "horn", "local": Vector3(local.x, clampf(ly, 0.0, 1.0), local.z)}
	if role == "head" or role == "neck":
		var mf = style.get("mane_fallback", {})
		if typeof(mf) == TYPE_DICTIONARY and not (mf as Dictionary).is_empty() \
				and (not has_mane or bool((mf as Dictionary).get("always", false))):
			# `always`: грива буває й там, де кісток нема (гребінь на потилиці й уздовж шиї),
			# тож у єдинорога геометрія працює ПОРУЧ із кістковим ланцюжком, а не замість нього
			if local.z <= float((mf as Dictionary).get("depth", 0.35)) \
					and local.y >= 1.0 - float((mf as Dictionary).get("height", 0.4)):
				return {"role": "mane", "local": local}
	return out


## Колір ПОЯСА вздовж ланцюжка: `t` (0 основа … 1 кінчик) ділиться на пояси завширшки
## `band`, кольори чергуються по колу. Чиста функція (пара до rainbow, тільки з даних стилю).
static func band_color(colors: Array, band: float, t: float) -> Color:
	if colors.is_empty():
		return Color.WHITE
	var w := maxf(band, 0.01)
	var i := int(floor(clampf(t, 0.0, 0.9999) / w)) % colors.size()
	return Color(String(colors[i]))


## Готовий колір грані повз зони + мітка для прев'ю — або {}, і тоді працює звичайне
## правило зони.
##   `role`    — роль грані (уже після remap_role);
##   `local`   — частки габариту зони;
##   `chain_t` — положення вздовж ланцюжка кісток, 0 основа … 1 кінчик; −1 = невідоме
##               (одна кістка на всю гриву/хвіст) — тоді беремо 1 − local.z, тобто «від переду
##               до потилиці/кінчика»;
##   `key`     — детермінований сід грані (HeroRig рахує його з центроїда), щоб зірочки
##               й акцентні грані лягали в тих самих місцях при кожному запуску;
##   `torso`   — частки габариту ТУЛУБА (x = 0 ліворуч … 1 праворуч, y знизу вгору,
##               z = 1 перед героя); (−1, −1, −1) — грань не з тулуба;
##   `zone`    — символ зони, який уже порахував HeroRig (потрібен копитцям: `k`).
## Повертає {} або {"color": Color, "tag": String}. Чиста функція.
static func face_paint(style: Dictionary, role: String, local: Vector3, chain_t: float,
		key: int, torso: Vector3 = Vector3(-1.0, -1.0, -1.0), zone: String = "") -> Dictionary:
	if style.is_empty():
		return {}
	# ── ріг: дві смуги, що чергуються кожні `band` висоти ──
	if role == "horn":
		var h = style.get("horn", {})
		if typeof(h) == TYPE_DICTIONARY and not (h as Dictionary).is_empty():
			var list: Array = (h as Dictionary).get("colors", ["#F6E3C2"])
			var band := maxf(float((h as Dictionary).get("band", 0.12)), 0.01)
			var i := int(floor(clampf(local.y, 0.0, 0.9999) / band)) % maxi(list.size(), 1)
			return {"color": Color(String(list[i])), "tag": "h"}
	# ── грива й хвіст: двоколірні пояси вздовж ланцюжка + рідкі акцентні грані ──
	var bd = style.get("bands", {})
	if typeof(bd) == TYPE_DICTIONARY and not (bd as Dictionary).is_empty() \
			and (((bd as Dictionary).get("roles", []) as Array).has(role)):
		var t := chain_t if chain_t >= 0.0 else 1.0 - local.z
		var acc := float((bd as Dictionary).get("accent_chance", 0.0))
		if acc > 0.0 and _rand01(key) < acc:
			return {"color": Color(String((bd as Dictionary).get("accent", "#FFB36B"))), "tag": "w"}
		return {"color": band_color((bd as Dictionary).get("colors", []) as Array,
			float((bd as Dictionary).get("band", 0.25)), t), "tag": "w"}
	# ── грива й хвіст веселкою (опція: `"rainbow": true` або список ролей) ──
	if _rainbow_has(style, role):
		return {"color": rainbow(chain_t if chain_t >= 0.0 else 1.0 - local.z), "tag": "w"}
	# ── копитця: свій колір на кожну лапку (замість темної зони `k`) ──
	var hv = style.get("hooves", {})
	if zone == HOOF_ZONE and typeof(hv) == TYPE_DICTIONARY and (hv as Dictionary).has(role):
		return {"color": Color(String((hv as Dictionary)[role])), "tag": "p"}
	# ── позначки на тулубі (сердечко, латки) ──
	var mk := mark_paint(style, torso)
	if not mk.is_empty():
		return mk
	# ── зірочки-блискітки на боках ──
	var sp = style.get("sparkle", {})
	if typeof(sp) == TYPE_DICTIONARY and not (sp as Dictionary).is_empty():
		var roles: Array = (sp as Dictionary).get("roles", [])
		if roles.has(role) and _rand01(key) < float((sp as Dictionary).get("chance", 0.0)):
			return {"color": Color(String((sp as Dictionary).get("color", "#FFF6B0"))), "tag": "s"}
	return {}


## ПОЗНАЧКИ НА ТУЛУБІ — сердечко на грудях і пастельні латки на боках. Винесено з face_paint
## окремо навмисно: HeroRig питає позначки ПЕРШИМИ, ще до поясів гриви й хвоста.
## Урок 09.09: пасма гриви єдинорога (Bone_034…031) звисають по ПЕРЕДУ шиї, тобто рівно на
## груди, роль у тих граней `mane` — і поки позначки рахувались після поясів, сердечко щоразу
## зафарбовувалось кораловою смугою гриви (виглядало як «сердечка нема взагалі»).
##   `torso` — частки габариту ТУЛУБА (x 0 ліворуч … 1 праворуч, y знизу вгору, z = 1 перед
##             героя); (−1, −1, −1) — грань не з тулуба, позначок нема.
## Повертає {} або {"color": Color, "tag": "r" сердечко / "g" латка}. Чиста функція.
static func mark_paint(style: Dictionary, torso: Vector3) -> Dictionary:
	if style.is_empty() or torso.x < 0.0:
		return {}
	# ── сердечко на грудях: передня грань грудей по центру ──
	var ch = style.get("chest_heart", {})
	if typeof(ch) == TYPE_DICTIONARY and not (ch as Dictionary).is_empty():
		var d := float((ch as Dictionary).get("depth", 0.25))
		var w2 := float((ch as Dictionary).get("width", 0.6)) * 0.5
		if torso.z >= 1.0 - d and absf(torso.x - 0.5) <= w2 \
				and _in_band((ch as Dictionary).get("y", null), torso.y):
			return {"color": Color(String((ch as Dictionary).get("color", "#E9B7F2"))), "tag": "r"}
	# ── пастельні латки на боках ──
	for item in (style.get("patches", []) as Array):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = item
		var left := String(p.get("side", "left")) == "left"
		if left != (torso.x < 0.5):
			continue
		if not _in_band(p.get("y", null), torso.y) or not _in_band(p.get("z", null), torso.z):
			continue
		return {"color": Color(String(p.get("color", "#7ED9A0"))), "tag": "g"}
	return {}


## Тільки колір (без мітки) — зручна обгортка над face_paint. Чиста функція.
static func face_color(style: Dictionary, role: String, local: Vector3, chain_t: float,
		key: int, torso: Vector3 = Vector3(-1.0, -1.0, -1.0), zone: String = "") -> Variant:
	var out := face_paint(style, role, local, chain_t, key, torso, zone)
	return out.get("color", null)


## Чи фарбується роль веселкою: `"rainbow": true` — грива й хвіст, список — саме ці ролі.
static func _rainbow_has(style: Dictionary, role: String) -> bool:
	var rb = style.get("rainbow", null)
	if typeof(rb) == TYPE_BOOL:
		return bool(rb) and RAINBOW_ROLES.has(role)
	return typeof(rb) == TYPE_ARRAY and (rb as Array).has(role)


## Значення в смузі [lo, hi] (null або не пара чисел — смуги нема, підходить усе).
static func _in_band(band, value: float) -> bool:
	if typeof(band) != TYPE_ARRAY or (band as Array).size() < 2:
		return true
	var a := float((band as Array)[0])
	var b := float((band as Array)[1])
	return value >= minf(a, b) and value <= maxf(a, b)


## Детермінований «кидок кубика» 0..1 за сідом грані: та сама грань — та сама зірочка
## при кожному запуску гри. Не RandomNumberGenerator, а цілочисельне перемішування
## (splitmix-подібне): кличеться на КОЖНУ грань тулуба, тож ані об'єктів, ані стану.
## Чиста функція.
static func _rand01(key: int) -> float:
	var h := key ^ SPARKLE_SEED
	h = (h ^ (h >> 16)) * 0x45d9f3b
	h = (h ^ (h >> 16)) * 0x45d9f3b
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777216.0
