## Узбіччя й покриття дороги з даних (GDD v1.5 §3) — чисті помічники Track.
## Тут перевіряємо саме правила, а не картинку: кольори покриття, боки каналу,
## смуга пропсів (у 0–0,3 м від дороги нічого нема) і те, що містки не лізуть на дорогу.
extends GutTest


func test_surface_colors_are_two_shades_per_kind() -> void:
	for kind in ["slabs", "planks", "sand_planks", "cobble", "cloud"]:
		var c: Array = Track.surface_colors(kind)
		assert_eq(c.size(), 2, "%s: два відтінки покриття" % kind)
		assert_ne(c[0], c[1], "%s: відтінки різні — плити читаються окремо" % kind)
	assert_eq(Track.surface_colors("slabs"), Track.surface_colors("невідоме"), "запасне покриття — плити")
	assert_eq((Track.surface_colors("slabs") as Array)[0], Palette.W_SLAB)
	assert_eq((Track.surface_colors("planks") as Array)[0], Palette.W_WOOD)
	assert_eq((Track.surface_colors("cobble") as Array)[0], Palette.W_COBBLE)


func test_tile_color_is_stable_and_within_surface() -> void:
	# малюнок не мерехтить: той самий ряд і та сама доріжка — той самий колір
	assert_eq(Track.tile_color("slabs", 12345, 2), Track.tile_color("slabs", 12345, 2))
	var a := Track.tile_color("slabs", 7, 0)
	var lo: Color = (Track.surface_colors("slabs") as Array)[0]
	var hi: Color = (Track.surface_colors("slabs") as Array)[1]
	assert_between(a.r, minf(lo.r, hi.r) - 0.001, maxf(lo.r, hi.r) + 0.001, "плита — суміш двох відтінків")
	# дошки — смуги поперек дороги: у межах ряду колір однаковий на всіх доріжках
	assert_eq(Track.tile_color("planks", 4, 0), Track.tile_color("planks", 4, 5), "дошка йде через усю дорогу")
	assert_ne(Track.tile_color("planks", 4, 0), Track.tile_color("planks", 5, 0), "сусідні ряди — різні дошки")
	# пісок + дошки: планка кожен третій ряд
	assert_eq(Track.tile_color("sand_planks", 3, 1), Palette.W_WOOD, "кожен третій ряд — дошка")
	assert_eq(Track.tile_color("sand_planks", 4, 1), Palette.SAND, "решта — пісок")


func test_canal_sides() -> void:
	assert_eq(Track.canal_sides({"side": "both"}), [-1.0, 1.0])
	assert_eq(Track.canal_sides({"side": "left"}), [-1.0])
	assert_eq(Track.canal_sides({"side": "right"}), [1.0])
	assert_eq(Track.canal_sides({"side": "none"}), [])
	assert_eq(Track.canal_sides({}), [], "нема каналу — нема боків")


func test_is_open_world() -> void:
	assert_true(Track.is_open({"roadside": "open"}))
	assert_false(Track.is_open({"roadside": "walls"}))
	assert_false(Track.is_open({}), "без поля — стіни впритул, як було до v1.5")


func test_prop_x_keeps_the_first_30_cm_clear() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var edge := 1.6
	for i in range(200):
		var left := Track.prop_x(-1.0, edge, rng)
		var right := Track.prop_x(1.0, edge, rng)
		assert_between(absf(left), edge + Track.PROP_NEAR, edge + Track.PROP_FAR, "лівий пропс у смузі 0,3–1,4 м")
		assert_between(right, edge + Track.PROP_NEAR, edge + Track.PROP_FAR, "правий пропс у смузі 0,3–1,4 м")
		assert_lt(left, 0.0, "бік −1 — ліворуч від дороги")
		assert_gt(right, 0.0, "бік +1 — праворуч від дороги")


func test_bridge_stays_out_of_the_road() -> void:
	assert_almost_eq(Track.bridge_deck_len(1.2), 1.2 + Track.BRIDGE_MARGIN, 0.001)
	assert_true(Track.bridge_clears_road(1.6, 2.0, 1.2), "Лужок: канал за 2 м — місток не заходить на дорогу")
	assert_true(Track.bridge_clears_road(1.6, 1.8, 3.0), "Пляж: широкий канал теж поза дорогою")
	assert_false(Track.bridge_clears_road(1.6, 0.1, 1.2), "канал упритул — місток ліг би на дорогу")


func test_track_builds_open_world_without_walls() -> void:
	var t := Track.new()
	add_child_autofree(t)
	t.rebuild({
		"id": "test_open", "roadside": "open", "road_surface": "slabs",
		"canal": {"side": "both", "offset": 2.0, "width": 1.2}, "bridges_every": 9,
		"props_side": ["flower"], "buildings_far": ["tree"],
		"walls_near": ["fence"], "cliff": ["#C9784F", "#A55B3A", "#7A4128"],
	}, false)
	assert_eq(t.lanes, 3, "дорога лишилась на 3 доріжки")
	assert_gt(t.get_child_count(), 0, "полотно, канал і береги створені")
	# у відкритому світі стіни впритул не беруться навіть із даних
	assert_true(Track.is_open(t.world))


## Орієнтир (вежа, ворота, млин) не має стояти у воді. До 17.09.2026 стояв: у захисті
## забули edge, і формула рахувала відступ від КРАЮ ДОРОГИ так, ніби це відстань від осі.
## Гравець прислав знімок, де вежа Лужка стоїть просто в каналі.
func test_landmark_never_stands_in_the_canal() -> void:
	var f := FileAccess.open("res://data/worlds/meadow.json", FileAccess.READ)
	var w: Dictionary = JSON.parse_string(f.get_as_text())
	var canal: Dictionary = w.get("canal", {})
	var c_off := float(canal.get("offset", 1.5))
	var c_w := float(canal.get("width", 3.0))
	var edge := 3.0 * Hero3D.LANE_W * 0.5 + 0.1        # три доріжки, як на першому рівні
	var half := 0.79                                    # пів ширини вежі на масштабі 1.2

	var off := Track.landmark_offset(edge, c_off, c_w, half, true)
	# Ближній бік вежі мусить лишитися ЗА дальнім берегом каналу.
	assert_gte(off - half, edge + c_off + c_w,
		"вежа стоїть за каналом (канал %.2f..%.2f від осі, вежа від %.2f)"
		% [edge + c_off, edge + c_off + c_w, off - half])

	# Борт без каналу нічим не обмежений — там орієнтир стоїть одразу за дорогою.
	assert_almost_eq(Track.landmark_offset(edge, c_off, c_w, half, false),
		edge + Track.LANDMARK_INSET, 0.001, "без каналу — звичайний відступ")

	# Вузький канал не має відсувати орієнтир далі, ніж треба.
	var near := Track.landmark_offset(edge, 0.2, 0.3, half, true)
	assert_lt(near, off, "вужчий канал — ближчий орієнтир")


## Олівкова смужка полотна дороги НЕ МУСИТЬ визирати з-під трави. Полотно ширше за плитку
## покриття на 0,10 м з кожного боку (road_width() = смуги × 1,0 + 0,2, а плитка вкриває рівно
## смуги). Напуск трави на дорогу був випадковий від нуля, тож на рядах, де він виходив
## меншим за 0,10, смужка визирала — і ряд за рядом то з'являлась, то зникала. На відстані це
## читалось як пунктир, що мигтить між зеленим і коричневим: рівно те, на що замовник
## показував два дні.
func test_grass_edge_always_covers_the_road_canvas_border() -> void:
	var border := 0.1                      # (road_width() - смуги × LANE_W) / 2
	assert_gte(Track.EDGE_OVERLAP_MIN, border,
		"найменший напуск трави мусить покривати олівкову смужку полотна, інакше вона визирає")
	assert_gt(Track.EDGE_OVERLAP, Track.EDGE_OVERLAP_MIN,
		"але напуск лишається ВИПАДКОВИМ у діапазоні — інакше край дороги стане лінійкою")


## Та сама арифметика для всіх ширин дороги: смужка полотна завжди 0,10 м, бо +0,2 у
## road_width() не залежить від кількості смуг.
func test_canvas_border_is_the_same_for_every_road_width() -> void:
	var t := Track.new()
	add_child_autofree(t)
	for n in [3, 5, 7]:
		t.lanes = n
		var border: float = (t.road_width() - float(n) * Hero3D.LANE_W) * 0.5
		assert_almost_eq(border, 0.1, 0.0001,
			"при %d смугах смужка полотна теж 0,10 м" % n)
