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

## УСІ варіанти води. Контракт має триматись на кожному, а не лише на повному: у стані
## «Плавно» типово малюється `water_unlit`, і прибиті до `water.gdshader` перевірки його
## просто не бачили. Рецензія це й показала.
const ALL_SHADERS := [
	"res://src/run3d/water.gdshader",
	"res://src/run3d/water_cheap.gdshader",
	"res://src/run3d/water_unlit.gdshader",
	"res://src/run3d/water_opaque.gdshader",
]
## Де `unshaded` — СВІДОМЕ рішення, а не недогляд: воно коштує 13,6 мс на пляжі, і ціна у
## вигляді (нема реакції на колір сонця й зблиску) прийнята замовником.
const UNSHADED_OK := [
	"res://src/run3d/water_unlit.gdshader",
	"res://src/run3d/water_opaque.gdshader",
]

var _track: Track


func _world(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/worlds/%s.json" % name, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func before_each() -> void:
	_track = Track.new()
	add_child_autofree(_track)
	await wait_process_frames(2)


func _code_of(path: String) -> String:
	var code_lines := PackedStringArray()
	for line in (load(path) as Shader).code.split("\n"):
		if not String(line).strip_edges().begins_with("//"):
			code_lines.append(line)
	return "\n".join(code_lines)


func _code_lines() -> String:
	# Шапка файлу СВІДОМО згадує ці слова — там пояснено, чому саме такі готові шейдери
	# відкинули. Тож перевіряємо не весь текст, а лише рядки коду (без "//"-коментарів).
	var code_lines := PackedStringArray()
	for line in (load(SHADER_PATH) as Shader).code.split("\n"):
		if not String(line).strip_edges().begins_with("//"):
			code_lines.append(line)
	return "\n".join(code_lines)


func test_shader_avoids_mobile_unsafe_features() -> void:
	# Кольоровий SCREEN_TEXTURE нам не потрібен (лише глибина), blend_add — те, через що
	# раніше відкидались готові шейдери спільноти. Перевіряємо ВСІ варіанти, бо в «Плавно»
	# малюється не той, що лежав тут раніше.
	for path in ALL_SHADERS:
		var code := _code_of(path)
		for banned in ["hint_screen_texture", "blend_add"]:
			assert_eq(code.find(banned), -1,
				"%s: %s не повинен використовуватись" % [path.get_file(), banned])
		if not UNSHADED_OK.has(path):
			assert_eq(code.find("unshaded"), -1,
				"%s: unshaded тут не свідоме рішення, а недогляд" % path.get_file())


## hint_depth_texture ТЕПЕР дозволено (виправлене правило), але лише якщо шейдер малюється у
## прозорому проході — інакше DEPTH_TEXTURE читає сам себе замість дна/предмета за водою
## (нотатка продюсера: ця помилка вже коштувала два заходи поспіль).
func test_depth_texture_used_only_in_transparent_pass() -> void:
	# Правило перевіряємо на КОЖНОМУ варіанті: хто читає глибину — мусить бути в прозорому
	# проході. `water_opaque` глибини не читає саме тому, що з прозорого проходу вийшов.
	for path in ALL_SHADERS:
		var code := _code_of(path)
		if code.find("hint_depth_texture") == -1:
			continue
		assert_ne(code.find("blend_mix"), -1,
			"%s: DEPTH_TEXTURE безпечний лише в прозорому проході" % path.get_file())
		assert_ne(code.find("depth_draw_never"), -1,
			"%s: вода не повинна сама писати в буфер глибини" % path.get_file())
		assert_ne(code.find("ALPHA = 1.0"), -1,
			"%s: прозорий прохід не має зробити воду видимо прозорою" % path.get_file())
	# І окремо: хоча б один варіант глибину читає, інакше піна зникла й тест стереже порожнечу.
	var readers := 0
	for path in ALL_SHADERS:
		if _code_of(path).find("hint_depth_texture") != -1:
			readers += 1
	assert_gt(readers, 0, "прибережна піна має лишатись хоча б в одному варіанті")


func test_shader_exposes_uniforms_track_gd_relies_on() -> void:
	for path in ALL_SHADERS:
		_assert_uniforms(path)


func _assert_uniforms(path: String) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load(path)
	# track.gd керує водою саме через ці імена (_water_mat.set_shader_parameter(...) і
	# _layout_canal()) — якщо їх перейменують у шейдері, гра мовчки лишиться без кольору
	# й хвиль, а помилки ніхто не побачить (сеттер неіснуючого параметра не падає).
	var names: Array = []
	for u in mat.shader.get_shader_uniform_list():
		names.append(u.get("name", ""))
	for expected in ["color", "color_light", "scroll", "amplitude", "flow"]:
		assert_true(names.has(expected),
			"%s має uniform '%s'" % [path.get_file(), expected])


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


## Море й канали беруть шейдер З ОДНОГО НАБОРУ, але НЕ обов'язково той самий — і це зміна
## наміру, а не послаблення сторожа. У «Плавно» канали ще й НЕПРОЗОРІ (Quality.OPAQUE_CANAL):
## прозорий прохід не пише глибину, і все за водою малюється теж; непрозорість це знімає,
## але забирає прибережну піну навколо перешкод. У морі перешкоди є — там піна потрібна; у
## каналах їх немає ЖОДНОЇ, тож там ця ціна не платиться. Заміряно: -1,6 мс, вигляд не
## відрізнити.
##
## БУВ ВАКУУМНИМ — удруге в цьому файлі. `before_each` створює голу трасу без `rebuild()`,
## тож `_canal_mats` порожній і цикл по каналах не виконувався ЖОДНОГО разу: тест лишався
## зеленим і тоді, коли канали брали геть інший шейдер. Виявилось це так, що правка, яка
## МУСИЛА його зламати, його не зламала.
func test_sea_and_canal_water_share_same_shader() -> void:
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_gt(_track._canal_mats.size(), 0,
		"у цьому світі є канали, інакше сторож знову перевіряє порожнечу")
	var cheap := not Quality.real_water_of(Quality.effective())
	var want_sea := "res://src/run3d/water_unlit.gdshader" if cheap else SHADER_PATH
	var want_canal := want_sea
	if cheap and Quality.opaque_canal_of(Quality.effective()):
		want_canal = "res://src/run3d/water_opaque.gdshader"
	assert_eq(_track._water_mat.shader.resource_path, want_sea,
		"море лишається прозорим — навколо перешкод у ньому потрібна піна")
	for m in _track._canal_mats:
		assert_eq(m.shader.resource_path, want_canal,
			"канал бере той шейдер, який каже стан якості")


## І окремо: канал мусить бути правильним ВІДРАЗУ ПІСЛЯ СТВОРЕННЯ, а не лише після
## наступної зміни якості. Перша редакція саме цим і схибила: `_layout_canal` заводив
## матеріал, не сказавши, що це канал, тож у грі, де дорослий якість не чіпає, правка не
## діяла б зовсім.
func test_kanal_pravylnyi_vidrazu_pislia_stvorennia() -> void:
	if Quality.real_water_of(Quality.effective()):
		return
	var fresh := Track.new()
	add_child_autofree(fresh)
	await wait_process_frames(2)
	fresh.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_gt(fresh._canal_mats.size(), 0, "канали заведено")
	var want := "res://src/run3d/water_opaque.gdshader" \
		if Quality.opaque_canal_of(Quality.effective()) \
		else "res://src/run3d/water_unlit.gdshader"
	for m in fresh._canal_mats:
		assert_eq((m as ShaderMaterial).shader.resource_path, want,
			"без жодного перемикання якості")


## І дешевий шейдер мусить отримати запечену текстуру — інакше вода буде порожньою.
func test_deshevyi_shejder_maie_zapechenyi_vizerunok() -> void:
	if Quality.real_water_of(Quality.effective()):
		return
	await wait_frames(3)
	var tex = _track._water_mat.get_shader_parameter("layer_tex")
	assert_not_null(tex, "дешевій воді потрібен запечений візерунок")



## Море й канали мусять узяти РІЗНІ запечені візерунки: інакше вся вода в грі має однаковий
## малюнок, і це видно там, де море й канал в одному кадрі.
## БУВ ВАКУУМНИМ. `before_each` створює голий Track без `rebuild()`, тож `_canal_mats`
## порожній і цикл по каналах не виконувався ЖОДНОГО разу — рецензія довела це, зробивши
## `water_layer_tex` завжди нульовим: тест лишався зеленим. Тепер піднімаємо світ із
## каналами, і лише тоді перевіряємо.
func test_more_i_kanaly_berut_rizni_vizerunky() -> void:
	if Quality.real_water_of(Quality.effective()):
		return
	var worlds: Dictionary = load("res://src/run3d/run3d.gd").load_worlds()
	var meadow: Dictionary = worlds.get("meadow", {})
	assert_false(meadow.is_empty(), "світ «meadow» є в даних")
	_track.rebuild(meadow, false)
	await wait_frames(3)
	assert_gt(_track._canal_mats.size(), 0,
		"у цьому світі мають бути канали, інакше сторож знову перевіряє порожнечу")
	var sea = _track._water_mat.get_shader_parameter("layer_tex")
	assert_not_null(sea, "морю потрібен запечений візерунок")
	for m in _track._canal_mats:
		var t = (m as ShaderMaterial).get_shader_parameter("layer_tex")
		assert_not_null(t, "каналові теж")
		assert_ne(t, sea, "канал не має брати той самий візерунок, що й море")
