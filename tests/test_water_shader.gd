## Вода каналу (src/run3d/water.gdshader) — адаптований шейдер спільноти (Wind Waker Water,
## NekotoArts, CC0, див. шапку файлу). Тут не міряємо картинку (для цього — знімки й
## visual-check), а стережемо контракт, яким користується track.gd, і мобільні обмеження:
##   - кольори різні для різних світів (Лужок/Пляж/Хмаринки не повинні злитись в один колір);
##   - набір uniform-ів, які виставляє track.gd (color, color_light, scroll, amplitude, flow),
##     не загубився при правках шейдера;
##   - жодних hint_screen_texture/unshaded/blend_add — те, через що раніше відкидались готові
##     шейдери спільноти, не повинно непомітно закрастись назад.
##   - hint_depth_texture — ОНОВЛЕНО 17.09.2026: правило «ніякого DEPTH_TEXTURE на мобільному»
##     було хибним (спростовано дослідом), шейдер тепер СВІДОМО читає глибину для прибережної
##     піни навколо перешкод у воді. Тест більше не забороняє це, а стежить, щоб читання було
##     БЕЗПЕЧНИМ: матеріал мусить лишатись у прозорому проході (blend_mix, depth_draw_never),
##     інакше DEPTH_TEXTURE бачить сам себе й піна бреше (та сама помилка, що вже сталась
##     двічі поспіль — див. нотатку продюсера).
extends GutTest

const SHADER_PATH := "res://src/run3d/water.gdshader"

var _track: Track


func _world(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/worlds/%s.json" % name, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func before_each() -> void:
	_track = Track.new()
	add_child_autofree(_track)
	await wait_process_frames(2)


func _code_lines() -> String:
	# Шапка файлу СВІДОМО згадує ці слова — там пояснено, чому саме такі готові шейдери
	# відкинули. Тож перевіряємо не весь текст, а лише рядки коду (без "//"-коментарів).
	var code_lines := PackedStringArray()
	for line in (load(SHADER_PATH) as Shader).code.split("\n"):
		if not String(line).strip_edges().begins_with("//"):
			code_lines.append(line)
	return "\n".join(code_lines)


func test_shader_avoids_mobile_unsafe_features() -> void:
	var code := _code_lines()
	# Кольоровий SCREEN_TEXTURE нам не потрібен (лише глибина), unshaded/blend_add — те, через
	# що раніше відкидались готові шейдери спільноти.
	for banned in ["hint_screen_texture", "unshaded", "blend_add"]:
		assert_eq(code.find(banned), -1, "мобільний рендерер: %s не повинен використовуватись" % banned)


## hint_depth_texture ТЕПЕР дозволено (виправлене правило), але лише якщо шейдер малюється у
## прозорому проході — інакше DEPTH_TEXTURE читає сам себе замість дна/предмета за водою
## (нотатка продюсера: ця помилка вже коштувала два заходи поспіль).
func test_depth_texture_used_only_in_transparent_pass() -> void:
	var code := _code_lines()
	assert_ne(code.find("hint_depth_texture"), -1, "прибережна піна: шейдер має читати глибину сцени")
	assert_ne(code.find("blend_mix"), -1, "DEPTH_TEXTURE безпечний лише в прозорому проході (render_mode blend_mix)")
	assert_ne(code.find("depth_draw_never"), -1, "вода не повинна сама писати в буфер глибини (depth_draw_never)")
	assert_ne(code.find("ALPHA = 1.0"), -1, "прозорий прохід не повинен зробити воду видимо прозорою (ALPHA = 1.0)")


func test_shader_exposes_uniforms_track_gd_relies_on() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH)
	# track.gd керує водою саме через ці імена (_water_mat.set_shader_parameter(...) і
	# _layout_canal()) — якщо їх перейменують у шейдері, гра мовчки лишиться без кольору
	# й хвиль, а помилки ніхто не побачить (сеттер неіснуючого параметра не падає).
	var names: Array = []
	for u in mat.shader.get_shader_uniform_list():
		names.append(u.get("name", ""))
	for expected in ["color", "color_light", "scroll", "amplitude", "flow"]:
		assert_true(names.has(expected), "шейдер має uniform '%s'" % expected)


## Замовник помітив на око: обидва боки каналу текли візуально ОДНАКОВО (дзеркальна копія),
## бо геометрія обох боків локально та сама (лише зсунута по X), а _canal_mats діставали
## однаковий scroll. flow — множник, свій для кожного матеріалу (track.gd: _layout_canal),
## має різнити боки і знаком (напрямок), і довжиною (швидкість) — інакше вада повернеться.
func test_canal_sides_flow_differently() -> void:
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_eq(_track._canal_mats.size(), 2, "обидва боки каналу заведено")
	var flow_a: float = _track._canal_mats[0].get_shader_parameter("flow")
	var flow_b: float = _track._canal_mats[1].get_shader_parameter("flow")
	assert_ne(signf(flow_a), signf(flow_b), "боки каналу мають текти в різні боки")
	assert_ne(absf(flow_a), absf(flow_b), "боки каналу мають текти з різною швидкістю")


## Лужок і Хмаринки — вода каналу (_canal_mats, обидва боки), Пляж — море на всю ширину
## (_water_mat, sea: true). Це різні меші з тим самим шейдером, тож колір читаємо з того,
## який світ насправді вмикає — саме так це й працює в грі (track.gd: _layout_canal і
## rebuild()).
func test_worlds_get_different_water_colors() -> void:
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	var meadow_color: Color = _track._canal_mats[0].get_shader_parameter("color")
	_track.rebuild(_world("beach"), false)
	await wait_process_frames(2)
	var beach_color: Color = _track._water_mat.get_shader_parameter("color")
	_track.rebuild(_world("clouds"), false)
	await wait_process_frames(2)
	var clouds_color: Color = _track._canal_mats[0].get_shader_parameter("color")
	assert_ne(meadow_color, beach_color, "Лужок і Пляж — різна вода")
	assert_ne(meadow_color, clouds_color, "Лужок і Хмаринки — різна вода")
	assert_ne(beach_color, clouds_color, "Пляж і Хмаринки — різна вода")


func test_canal_water_uses_world_color_not_shader_default() -> void:
	# _canal_water (бічні канали вздовж дороги, _layout_canal) — саме та вода, яку видно на
	# знімках meadow_before/after; кожен світ тримає свій колір, а не запасний зі схеми
	# uniform-а (значення "за замовчуванням" у самому .gdshader, якщо set_shader_parameter
	# з якоїсь причини не спрацював би).
	var default_color := Color(0.31, 0.76, 0.97, 1.0)
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_gt(_track._canal_mats.size(), 0, "канал заведено")
	for m in _track._canal_mats:
		var c: Color = m.get_shader_parameter("color")
		assert_false(c.is_equal_approx(default_color), "колір каналу з water.json, не запасний")


## Море й канали беруть ОДИН І ТОЙ САМИЙ шейдер — який саме, залежить від стану якості
## (у «Плавно» дешевий із запеченим візерунком), але він мусить бути спільний. Раніше тут
## стояв прибитий шлях, і тест падав від самої появи дешевого варіанта, хоч намір —
## «однаковий у моря й каналів» — не порушено.
func test_sea_and_canal_water_share_same_shader() -> void:
	var want := SHADER_PATH if Quality.real_water_of(Quality.effective()) \
		else "res://src/run3d/water_cheap.gdshader"
	assert_eq(_track._water_mat.shader.resource_path, want)
	for m in _track._canal_mats:
		assert_eq(m.shader.resource_path, want,
			"канал має той самий шейдер, що й море")


## І дешевий шейдер мусить отримати запечену текстуру — інакше вода буде порожньою.
func test_deshevyi_shejder_maie_zapechenyi_vizerunok() -> void:
	if Quality.real_water_of(Quality.effective()):
		return
	await wait_frames(3)
	var tex = _track._water_mat.get_shader_parameter("layer_tex")
	assert_not_null(tex, "дешевій воді потрібен запечений візерунок")
