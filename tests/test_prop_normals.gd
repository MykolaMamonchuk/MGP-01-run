## Сторож: пропси оточення НЕ мають карт нормалей і НЕ двосторонні.
##
## Заміряно 22.09.2026 на Redmi 8A сходами масштабу рендера: карти нормалей коштують
## 36 одиниць показника зі 194, тобто 19% усієї ціни декору, — і це найбільша окрема стаття
## в матеріалах. Для порівняння, шорсткість, метал і затінення коштують нуль, а зрізання 94%
## вершин з моделі — теж нуль.
##
## Сторож потрібен, бо вимкнення живе в PropLibrary, а моделі приходять від художника ІЗ
## картами. Достатньо комусь додати новий шлях завантаження меша повз бібліотеку — і третина
## виграшу тихо повернеться назад.
extends GutTest


## Скільки пропсів із текстурами взагалі оглянуто — без цього числа сторож може бути
## зелений просто тому, що нічого не знайшов (див. урок «сторож, що перевіряє порожнечу»).
var _seen := 0
var _textured := 0


func _props_with_normals() -> Array:
	var bad: Array = []
	_seen = 0
	_textured = 0
	var f := FileAccess.open("res://data/props.json", FileAccess.READ)
	if f == null:
		return bad
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return bad
	for kind in (data as Dictionary).keys():
		if String(kind).begins_with("_"):
			continue
		var m := PropLibrary.mesh(String(kind))
		if m == null:
			continue
		_seen += 1
		for si in range(m.get_surface_count()):
			var bm := m.surface_get_material(si) as BaseMaterial3D
			if bm == null:
				continue
			if bm.albedo_texture != null:
				_textured += 1
			if bm.normal_enabled or bm.normal_texture != null:
				bad.append("нормаль:%s#%d" % [kind, si])
			if bm.cull_mode == BaseMaterial3D.CULL_DISABLED:
				bad.append("двосторонній:%s#%d" % [kind, si])
	return bad


## Обидві правки живуть в одному місці (PropLibrary) і стережуться разом: кожна дає ~19%
## ціни декору, і кожну легко втратити, додавши новий шлях завантаження меша повз бібліотеку.
func test_propsy_otochennia_bez_kart_normalei() -> void:
	var bad := _props_with_normals()
	assert_gt(_seen, 30, "сторож справді оглянув пропси, а не порожнечу")
	assert_gt(_textured, 5, "серед оглянутих є ТЕКСТУРНІ — саме в них були карти нормалей")
	assert_eq(bad, [], "пропси з картами нормалей (мають бути вимкнені в PropLibrary): %s" % [bad])
