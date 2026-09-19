## Приміряти на героя ЧУЖУ модель — без правок у heroes.json. Лише для debug-сцен
## (hero_lab, face_shot); у грі не використовується.
##
## Навіщо. Нову модель хочеться подивитись із усіма повзунками обличчя ЩЕ ДО того, як
## вирішено на неї переходити: перехід тягне за собою нові кістки, палітру й посадку
## обличчя, і робити це наосліп — марна робота.
##
## Запуск:  RIG=fox_meshy_clear godot res://src/debug/hero_lab.tscn
class_name RigTry
extends RefCounted

const BONES_PATH := "res://src/debug/rig_try_bones.json"


## Підмінити модель героя на ту, що в RIG=. Повертає рядок для рядка стану ("" — підміни нема).
##
## Заразом підставляємо розкладку кісток цієї моделі з rig_try_bones.json: `rig_bones` у
## heroes.json описує модель ПОТОЧНОГО героя, а на чужій імена кісток інші. Автопошук по
## геометрії (HeroRig.map_bones_by_geometry) вгадує більшість, але голову плутає з хребтом —
## і тоді обличчя сідає героєві на груди.
static func apply(hero_id: String) -> String:
	var rig := OS.get_environment("RIG")
	if rig == "":
		return ""
	var d: Dictionary = Hero3D.defs().get(hero_id, {})
	if d.is_empty():
		return ""
	d["rig"] = rig
	var f := FileAccess.open(BONES_PATH, FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has(rig):
			d["rig_bones"] = (parsed as Dictionary)[rig]
			return "модель %s (кістки з rig_try_bones.json)" % rig
	return "модель %s (кістки — автопошуком)" % rig
