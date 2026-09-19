## Дорога й декор малюються пачками MultiMesh (docs/optimisation OPT-01, OPT-02).
## Тут стережемо інваріанти: скільки предметів записано в ряди — стільки й видно в шарах,
## і жоден предмет не загубився при перевкладанні рядів.
extends GutTest

var _track: Track


func _world(name: String) -> Dictionary:
	var f := FileAccess.open("res://data/worlds/%s.json" % name, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func before_each() -> void:
	_track = Track.new()
	add_child_autofree(_track)
	await wait_process_frames(2)


func _layers() -> Array:
	var out := []
	for c in _track.get_children():
		if c is MultiMeshInstance3D:
			out.append(c)
	return out


func _records() -> int:
	var n := 0
	for ids in _track._decor_ids:
		n += (ids as PackedInt32Array).size()
	return n


func _visible() -> int:
	var n := 0
	for mi in _track._decor_mm:
		n += (mi.multimesh as MultiMesh).visible_instance_count
	return n


func test_road_is_four_layers_covering_every_row() -> void:
	var centre_even := (_track._mm_center[0].multimesh as MultiMesh).instance_count
	var centre_odd := (_track._mm_center[1].multimesh as MultiMesh).instance_count
	assert_eq(centre_even + centre_odd, Track.ROWS, "центр покриває всі ряди двома шарами (смугастість)")
	# по ДВА інстанси на ряд: узбіччя розрізане на смугу до води й смугу за водою, а між
	# ними проріз під канал. Без каналу друга смуга просто нульова — інстансів так само два,
	# тобто пачка не залежить від того, чи є в світі вода
	for mi in _track._mm_side:
		assert_eq((mi.multimesh as MultiMesh).instance_count, Track.ROWS * 2,
			"узбіччя — дві смуги на ряд (проріз під канал)")


func test_decor_layers_show_exactly_what_rows_hold() -> void:
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	# відкрите узбіччя (v1.5): пропси рідші за стіни впритул, але лужок усе одно засаджений
	assert_gt(_records(), 60, "лужок засаджений декором")
	assert_eq(_visible(), _records(), "видимих інстансів рівно стільки, скільки предметів у рядах")


func test_rows_wrapping_does_not_lose_or_double_decor() -> void:
	_track.rebuild(_world("forest"), false)
	await wait_process_frames(2)
	# проїхати більше, ніж довжина траси: кожен ряд перевкладеться щонайменше раз
	for i in range(Track.ROWS + 8):
		_track.advance(1.0)
	await wait_process_frames(2)
	assert_eq(_visible(), _records(), "після перевкладання рядів облік збігається")


func test_switching_world_reuses_layers_and_clears_old_ones() -> void:
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	var after_meadow := _layers().size()
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_eq(_layers().size(), after_meadow, "той самий світ не плодить нові шари")
	_track.rebuild(_world("beach"), false)
	await wait_process_frames(2)
	assert_eq(_visible(), _records(), "після зміни світу старі шари не показують зайвого")


## Хмари (OPT-03): 24 клубки — це ОДНА пачка, а не 24 вузли.
func test_clouds_are_one_batch_not_twenty_four_nodes() -> void:
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_eq((_track._mm_clouds.multimesh as MultiMesh).instance_count,
		Track.CLOUDS * Track.PUFFS_PER_CLOUD, "усі клубки хмар в одній пачці")
	# стара хмара була вузлом Node3D рівно з трьома мешами-клубками всередині
	var loose := 0
	for c in _track._far.get_children():
		if c is MultiMeshInstance3D or c is MeshInstance3D:
			continue
		var puffs := 0
		for g in (c as Node).get_children():
			if g is MeshInstance3D:
				puffs += 1
		if puffs == Track.PUFFS_PER_CLOUD:
			loose += 1
	assert_eq(loose, 0, "хмар-вузлів по три клубки в далекому плані не лишилось")


## Клубки різного розміру, але меш один: різницю робить масштаб інстанса. Якщо всі
## розміри збіглися — значить розмір загубився й хмари стали однаковими цеглинками.
func test_puffs_keep_their_own_size_through_the_batch() -> void:
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_eq(_track._puff_size.size(), Track.CLOUDS * Track.PUFFS_PER_CLOUD,
		"розмір записано на кожен клубок")
	var seen := {}
	for s in _track._puff_size:
		assert_gt(s.x, 0.0, "клубок не нульового розміру")
		seen[snappedf(s.x, 0.001)] = true
	assert_gt(seen.size(), 1, "клубки різної ширини, а не однакові")


## Пагорби НАВМИСНО лишились вузлами: MultiMesh крутить нормаль базисом інстанса, і
## еліпсоїдний пагорб від цього темнішає (заміряно 6 433 пікселі). Сторож, щоб наступний
## захід «дооптимізувати далекий план» не зробив цього не глянувши.
func test_hills_stay_separate_nodes_on_purpose() -> void:
	_track.rebuild(_world("meadow"), false)
	await wait_process_frames(2)
	assert_eq(_track._hills.size(), Track.HILLS, "пагорби лишаються окремими вузлами")
	for h in _track._hills:
		assert_true((h as MeshInstance3D).mesh is SphereMesh, "пагорб — своя куля зі своїми нормалями")


# --- хто кидає тінь -----------------------------------------------------------------------
#
# Прохід карти тіней малює кожен тінекидач ДРУГИЙ РАЗ, і коштує він 111 draw calls із 295
# (заміряно 19.09.2026 вимкненням shadow_enabled: 295 → 184). Тому склад тінекидачів — це
# бюджет, а не дрібниця, і кожне рішення тут заміряне на пікселях.

func test_far_plane_and_water_do_not_cast_shadows() -> void:
	var t := Track.new()
	add_child_autofree(t)
	await wait_process_frames(2)
	for h in t._hills:
		assert_eq(h.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"пагорб далекого плану тіні не кидає: −8 draw calls при ДВОХ різних пікселях")
	for w in t._side_water:
		assert_eq(w.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"бічна вода тіні не кидає — це пласка площина")


## А ось це — навпаки: сторож проти «дооптимізації». Обидві спроби зняти тінь звідси вже
## робились і обидві заміряні як ПОГАНІ, тож наступний захід має спершу прочитати числа.
func test_road_canvas_and_banks_still_cast_shadows_on_purpose() -> void:
	var t := Track.new()
	add_child_autofree(t)
	await wait_process_frames(2)
	assert_ne(t._mm_center[0].cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		("полотно дороги тінь КИДАЄ навмисно: плато затінює траву й воду обабіч, і без цього "
		+ "кадр міняється на 12% пікселів заради −61 draw call"))
	if not t._canal_banks.is_empty():
		assert_ne(t._canal_banks[0].cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			("стінка берега тінь КИДАЄ навмисно: вона лягає в канал, а канал у кадрі — "
			+ "0.52% пікселів заради −12 draw calls"))


## Будівля не дихає ніде, тож і шар у неї ОДИН.
##
## Гойдалку («дихання» 2% масштабу й нахил 2°) вирішує місце постановки: біля дороги кущ
## хитається, у стіні лісу — ні, і це правильно. Але будівлю розділення за місцем коштувало
## двічі. По-перше, два MultiMesh на той самий меш: house_terra_7 і house_terra_7#wall — це
## зайвий draw call у кольоровому проході й ЩЕ ОДИН у тіньовому. По-друге, заморожене
## оздоблення пише всім маркерам role = "decor", тож у грі будинки з цеглинок таки дихали —
## а про дахи на тлі неба код сам попереджає в _sync_decor.
##
## Заміряно 19.09.2026 на рівні 1: шарів у кадрі 48 → 36, подвоєних будівель 12 → 0,
## draw calls 258 → 226, primitives 184 094 → 171 866.
func test_a_building_gets_one_layer_not_two() -> void:
	var kind := String(Track.NEVER_SWAYS[0])
	var swaying := _track._decor_layer(kind, {}, 0, false)
	var still := _track._decor_layer(kind, {}, 0, true)
	assert_eq(swaying, still, "%s: той самий шар, хоч як його поставили" % kind)
	assert_true(_track._decor_no_sway[swaying], "і цей шар не дихає")


## А те, що МАЄ хитатись біля дороги й завмирати у стіні, і далі дістає два шари — інакше
## кущ уздовж дороги завмер би разом із лісовою стіною.
func test_foliage_still_splits_by_placement() -> void:
	assert_false(Track.NEVER_SWAYS.has("bush"), "кущ не в списку нерухомих")
	var road := _track._decor_layer("bush", {}, 0, false)
	var wall := _track._decor_layer("bush", {}, 0, true)
	assert_ne(road, wall, "кущ біля дороги й кущ у стіні — різні шари")


## І список нерухомих не бреше: кожен вид у ньому справді існує.
func test_never_sways_names_real_kinds() -> void:
	var missing := []
	for kind in Track.NEVER_SWAYS:
		if not _track._kind_exists(String(kind)):
			missing.append(kind)
	assert_eq(missing.size(), 0, "у списку нерухомих є неіснуючі види: %s" % [missing])
