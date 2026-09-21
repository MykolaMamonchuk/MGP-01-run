## ДОГЛЯД ЗА ДРУЗЯМИ: чи не ламає він те, на чому тримається економіка.
##
## Догляд — це новий СІНК злитків, і саме сінки найлегше зробити токсичними. EDD (Confluence
## 2424833) забороняє прямо: жодних таймерів, жодних штрафів у мінус, жодного «не погодував
## — друг сумує», і ціна ніколи не блокує сюжет. Для 3–7 років смужка, що падає сама, — це
## не мотивація, а провина; з неї починається все, за що батьки ставлять конкурентам одну
## зірку. Тому тут стережуться не «красиві числа», а межі, за які не можна.
extends GutTest

const CARE := "res://data/care.json"
const HOMES := "res://data/homes.json"
## Заробіток за пробіг із моделі EDD §2.2: найбідніший рівень і найбагатший.
const RUN_MIN := 428
const RUN_MAX := 1584
## Скільки злитків дає один прохід усіх 17 рівнів на 2★.
const FULL_PASS := 16200

var _care: Dictionary = {}


func before_all() -> void:
	_care = _json(CARE)


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "%s на місці" % path)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _sum(items: Array, key: String) -> int:
	var n := 0
	for i in items:
		n += int((i as Dictionary).get(key, 0))
	return n


func test_dani_chytaiutsia() -> void:
	assert_gt((_care.get("daily", []) as Array).size(), 2, "щоденні дії є")
	assert_gt((_care.get("gifts", []) as Array).size(), 1, "подарунки є")
	assert_gt((_care.get("friendship", []) as Array).size(), 3, "рівні дружби є")


## ЩОДЕННИЙ ДОГЛЯД мусить бути по кишені ОДРАЗУ після пробігу — у цьому весь сенс: дитина
## повертається з рівня й може щось зробити негайно, не збираючи. Але й не копійчаним:
## дія, що коштує один відсоток пробігу, не читається як вибір.
func test_shchodennyi_dohliad_po_kysheni_odrazu() -> void:
	var round_cost := _sum(_care["daily"], "price")
	assert_lte(round_cost, RUN_MIN / 2,
		"повне коло догляду (%d) не дорожче за половину найбіднішого пробігу (%d)"
			% [round_cost, RUN_MIN / 2])
	assert_gte(round_cost, RUN_MIN / 10,
		"і не дешевше за десяту частину — інакше це не вибір, а дрібниця")


## Жодна дія не безкоштовна: безкоштовне не читається як турбота, і з нього не виходить
## сінка. І жодна не від'ємна — EDD забороняє будь-що, що лишає дитину в мінусі.
func test_zhodna_diia_ne_bezkoshtovna() -> void:
	for group in ["daily", "gifts"]:
		for a in (_care[group] as Array):
			var d: Dictionary = a
			assert_gt(int(d.get("price", 0)), 0, "«%s» коштує більше за нуль" % d.get("id"))
			assert_gt(int(d.get("friendship", 0)), 0, "«%s» дає дружбу" % d.get("id"))


## Подарунки дорожчі за щоденне, інакше драбина «зробив зараз / збираю на потім» зникає.
func test_podarunky_dorozhchi_za_shchodenne() -> void:
	var daily_max := 0
	for a in (_care["daily"] as Array):
		daily_max = maxi(daily_max, int((a as Dictionary)["price"]))
	for g in (_care["gifts"] as Array):
		assert_gt(int((g as Dictionary)["price"]), daily_max * 3,
			"подарунок «%s» помітно дорожчий за щоденну дію" % (g as Dictionary)["id"])


## ДОГЛЯД НЕ КОНКУРУЄ З СЮЖЕТОМ. Разові на всіх друзів не мають перевищувати один прохід
## гри більш ніж трохи: разові сінки вже займають 19 940 проти 16 200 за прохід, і якщо
## догляд додасть ще стільки ж, дитина перестане бачити, на що взагалі збирає.
func test_dohliad_ne_konkuruie_z_siuzhetom() -> void:
	var friends := (_json(HOMES).get("homes", []) as Array).size()
	assert_gt(friends, 0, "друзі знайшлись")
	var per_friend := _sum(_care["gifts"], "price")
	var total := per_friend * friends
	assert_lte(total, FULL_PASS * 2,
		"разові на %d друзів (%d) не перевищують двох проходів гри" % [friends, total])
	assert_gte(total, FULL_PASS / 4,
		"і не такі дрібні, щоб закритись за чверть проходу")


## ДО ОСТАННЬОГО РІВНЯ ДРУЖБИ НЕ МОЖНА ДОЙТИ САМИМИ ПОКУПКАМИ. Друг має бути довгим
## проєктом, а не покупкою: якщо всі подарунки одразу дають п'ятий рівень, дитина «закриває»
## друга за один вечір, і догляд перестає бути причиною повертатись.
func test_druh_ne_kupuietsia_odnym_rakhunkom() -> void:
	var levels: Array = _care["friendship"]
	var top := int((levels[-1] as Dictionary)["need"])
	var from_gifts := _sum(_care["gifts"], "friendship")
	assert_lt(from_gifts, top,
		"самі подарунки (+%d) не дають останнього рівня (%d)" % [from_gifts, top])


## Рівні дружби йдуть угору й починаються з нуля: перший рівень має бути в кожного, кого
## впустили у двір, інакше «друг оселився, але ще не друг» — незрозуміло дитині.
func test_rivni_druzhby_rostut_vid_nulia() -> void:
	var levels: Array = _care["friendship"]
	assert_eq(int((levels[0] as Dictionary)["need"]), 0, "перший рівень безкоштовний")
	var prev := -1
	for l in levels:
		var need := int((l as Dictionary)["need"])
		assert_gt(need, prev, "пороги дружби зростають")
		prev = need
		assert_ne(String((l as Dictionary).get("unlock", "")), "",
			"кожен рівень щось відмикає — інакше нема за чим його досягати")


## СМАКИ НЕ БЛОКУЮТЬ. Улюблене частування лише подвоює приріст; кожен друг мусить мати
## смак, і кожен смак — існувати як ресурс світу. Смак, що вказує в нікуди, тихо забрав би
## у друга половину дружби назавжди.
func test_smaky_ne_blokuiut_i_vkazuiut_kudy_treba() -> void:
	var tastes: Dictionary = _care.get("tastes", {})
	var resources: Dictionary = _care.get("resources", {})
	var ids := {}
	for w in resources:
		ids[String((resources[w] as Dictionary)["id"])] = true
	var homes := _json(HOMES).get("homes", []) as Array
	var missing := []
	for h in homes:
		var id := String((h as Dictionary)["id"])
		if not tastes.has(id):
			missing.append("%s без смаку" % id)
		elif not ids.has(String(tastes[id])):
			missing.append("%s любить «%s», а такого ресурсу нема" % [id, tastes[id]])
	assert_eq(missing, [], "смаки узгоджені з ресурсами: %s" % [missing])


## Ресурси прив'язані до СВІТІВ, які існують: ресурс неіснуючого світу не принесе ніхто.
func test_resursy_nalezhat_spravzhnim_svitam() -> void:
	var bad := []
	for w in (_care.get("resources", {}) as Dictionary):
		if not FileAccess.file_exists("res://data/worlds/%s.json" % String(w)):
			bad.append(String(w))
	assert_eq(bad, [], "світи ресурсів існують: %s" % [bad])


## І головне, чого не видно в числах: у даних НЕМА нічого, що тікає саме по собі. Жодного
## ключа про спад, таймер чи покарання — саме з них починається тиск на дитину, і EDD
## забороняє їх окремим пунктом. Сторож на НАЗВИ навмисно: він має впасти тоді, коли
## хтось спробує додати смужку голоду, навіть із найкращими намірами.
func test_u_dohliadi_nema_taimeriv_i_pokaran() -> void:
	var f := FileAccess.open(CARE, FileAccess.READ)
	var text := f.get_as_text().to_lower()
	var forbidden := ["decay", "timer", "cooldown", "hunger", "penalty", "expire", "hours"]
	var found := []
	for word in forbidden:
		if text.contains(word):
			found.append(word)
	assert_eq(found, [], "у догляді нема механік тиску: %s" % [found])
