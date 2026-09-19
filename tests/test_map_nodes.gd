## Вузли мапи не налазять один на одного — інакше рівень «не купується».
##
## Скарга замовника: «Не можу купити рівень». Стан збереження був справний (рівень 2
## пройдено на зірку, 628 зірочок, ціна 80), плашка «★ 80» малювалась, і open_state() чесно
## віддавав "buyable". Заважала РОЗКЛАДКА: вузли стояли через рівний x, і на злеті хвилі крок
## сходився до 69 px між колами діаметром 96. Вісім пар із шістнадцяти налазили. Сусідній
## вузол додається в дерево ПІЗНІШЕ, отже лежить зверху й забирає тап собі — замкнений
## рівень 4 накривав половину купованого рівня 3 разом із плашкою ціни, і тап по ціні давав
## трясіння «замкнено» замість купівлі.
##
## Тому тут два сторожі: геометричний (кола не перетинаються) і той, що ловить саму ваду —
## точка в центрі вузла належить ЙОМУ, а не сусідові, що лежить зверху.
extends GutTest

## Розміри полотна, у яких гра справді живе: вікно проєкту й телефонні співвідношення, які
## дає розтяг "expand" (див. tests/test_safe_area.gd).
const SIZES := [Vector2(1336, 720), Vector2(1560, 720), Vector2(1280, 800), Vector2(2000, 900)]


func _levels() -> int:
	return LevelManager.load_levels().size()


func test_nodes_never_overlap() -> void:
	var n := _levels()
	assert_gt(n, 1, "рівні читаються — інакше сторож стереже порожнечу")
	for size in SIZES:
		var pts := MapScreen.node_positions(n, size)
		assert_eq(pts.size(), n, "точок стільки ж, скільки рівнів")
		var r := MapScreen.node_radius(pts)
		var worst := INF
		var worst_pair := ""
		for i in range(n - 1):
			var d: float = (pts[i] as Vector2).distance_to(pts[i + 1] as Vector2)
			if d < worst:
				worst = d
				worst_pair = "%d→%d" % [i + 1, i + 2]
		assert_gte(worst, r * 2.0,
			"%s: вузли %s стоять на %.1f px, а це менше за діаметр %.1f"
			% [size, worst_pair, worst, r * 2.0])


## Не тільки сусіди: перевіряємо ВСІ пари, бо хвиля може звести докупи й далекі вузли.
func test_no_two_nodes_touch_at_all() -> void:
	var n := _levels()
	for size in SIZES:
		var pts := MapScreen.node_positions(n, size)
		var r := MapScreen.node_radius(pts)
		var bad := []
		for i in range(n):
			for j in range(i + 1, n):
				if (pts[i] as Vector2).distance_to(pts[j] as Vector2) < r * 2.0:
					bad.append("%d↔%d" % [i + 1, j + 1])
		assert_eq(bad.size(), 0, "%s: вузли налазять: %s" % [size, bad])


## Уся стежка лишається на екрані: вузол, що виїхав за край, теж не натиснеш.
func test_nodes_stay_on_screen() -> void:
	var n := _levels()
	for size in SIZES:
		var pts := MapScreen.node_positions(n, size)
		var r := MapScreen.node_radius(pts)
		for i in range(n):
			var p: Vector2 = pts[i]
			assert_between(p.x, r, size.x - r, "%s: вузол %d по x" % [size, i + 1])
			# зверху над вузлом ще стоїть рядок зірок (−32) і заголовок мапи
			assert_between(p.y, r + 100.0, size.y - r, "%s: вузол %d по y" % [size, i + 1])


## Радіус меншає лише тоді, коли інакше вузли налізли б — і не менший за палець.
func test_radius_shrinks_only_when_it_must() -> void:
	var n := _levels()
	var roomy := MapScreen.node_positions(n, Vector2(2000, 900))
	assert_eq(MapScreen.node_radius(roomy), MapScreen.NODE_R,
		"на просторому екрані вузол повного розміру")
	var tight := MapScreen.node_positions(n, Vector2(960, 540))
	var r := MapScreen.node_radius(tight)
	assert_lt(r, MapScreen.NODE_R, "на тісному екрані вузол меншає")
	assert_gte(r, MapScreen.NODE_R_MIN, "але не менше за нижню межу тапу")


## Сама вада, дослівно: тап у центр вузла має дістатись ЙОМУ. Рахуємо так само, як рушій:
## перемога за тим, хто в дереві ПІЗНІШЕ, тобто за більшим номером.
func test_tap_in_the_centre_reaches_its_own_node() -> void:
	var n := _levels()
	for size in SIZES:
		var pts := MapScreen.node_positions(n, size)
		var r := MapScreen.node_radius(pts)
		var stolen := []
		for i in range(n):
			var c: Vector2 = pts[i]
			for j in range(i + 1, n):
				var rect := Rect2((pts[j] as Vector2) - Vector2(r, r), Vector2(r * 2.0, r * 2.0))
				if rect.has_point(c):
					stolen.append("вузол %d крав тап у вузла %d" % [j + 1, i + 1])
		assert_eq(stolen.size(), 0, "%s: %s" % [size, stolen])


## Плашка «★ ціна» мусить лишатись усередині свого вузла — інакше тап по написаній ціні
## (найприродніший жест: там і написано, скільки коштує) летить повз кнопку.
func test_price_badge_stays_inside_its_node() -> void:
	var n := _levels()
	for size in SIZES + [Vector2(960, 540)]:
		var pts := MapScreen.node_positions(n, size)
		var r := MapScreen.node_radius(pts)
		var badge := PriceBadge.new(80,
			minf(1.0, (r * 2.0 - MapScreen.BADGE_INSET * 2.0) / PriceBadge.BASE.x))
		var pos := Vector2(r - badge.size.x * 0.5, r * 2.0 - MapScreen.BADGE_INSET - badge.size.y)
		assert_gte(pos.x, 0.0, "%s: плашка не вилазить ліворуч" % size)
		assert_lte(pos.x + badge.size.x, r * 2.0, "%s: і праворуч" % size)
		assert_lte(pos.y + badge.size.y, r * 2.0, "%s: і донизу" % size)
		assert_gt(badge.size.x, 0.0, "%s: плашка не зникла" % size)
		badge.free()
