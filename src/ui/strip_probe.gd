## ПРОГІН ПО ВАРІАНТАХ СЦЕНИ прямо на пристрої: сам вимикає шматки й сам друкує час кадру.
##
## Навіщо. Кадр на Redmi 8A — 133 мс, і розкласти його можна лише дослідом. Робити шість
## дослідів шістьма збірками — півгодини й шість різних APK, які вже не зовсім порівнянні.
## Тут одна збірка проганяє всі варіанти поспіль, тими самими очима й на тій самій сцені.
##
## Живе в src/ui/, а не в src/debug/: друга тека ВИКЛЮЧЕНА з експорту (docs/web.md), тож на
## пристрої її просто не було б.
##
## Вмикається прапорцем збірки "strip_probe" — його ставлять у пресет на час замірів.
extends Node

## Скільки чекати після зміни варіанта, перш ніж почати міряти: сцені треба перемалюватись,
## а драйверу — дійти до сталого стану. На семи кадрах за секунду це помітний час.
const SETTLE_SEC := 5.0
## Скільки міряти кожен варіант.
const MEASURE_SEC := 7.0

## ОБОВ'ЯЗКОВО ПОВТОРЮВАТИ БАЗУ В КІНЦІ. Adreno 505 дроселює: заміряно, що за десять
## хвилин прогону CPU падає з 2,02 до 1,30 ГГц, і той самий варіант дає 94 мс на початку
## й 130 у середині. Без контрольного заміру наприкінці неможливо відрізнити «стало гірше
## від зміни» від «телефон нагрівся». Це та сама вимога, що й контрольний прогін проби на
## Маку (docs/MEMORY.md), тільки причина фізична.
## Перший прогін (21.09.2026) показав: декор і забудова коштують 39 мс зі 133, тіні 22, а
## кількість викликів і примітивів майже ні до чого (половина забудови дала лише 2,8 мс).
## Отже лишається 94 мс НА ПОРОЖНІЙ сцені, і саме їх шукає цей набір: повноекранні ефекти
## (світіння, кольорокорекція, туман) і великі поверхні (вода, небо).
const STEPS := [
	{"назва": "усе як є", "flags": []},
	{"назва": "масштаб 0.7", "flags": ["scale7"]},
	{"назва": "масштаб 0.5", "flags": ["scale5"]},
	{"назва": "мінімум", "flags": ["water", "fog", "shadows", "decor", "glow", "adjust", "sky"]},
	{"назва": "мінімум + масштаб 0.5", "flags": ["water", "fog", "shadows", "decor", "glow", "adjust", "sky", "scale5"]},
	{"назва": "без тіней + масштаб 0.7", "flags": ["shadows", "scale7"]},
	{"назва": "усе як є (контроль)", "flags": []},
]

var run: Node

var _step := -1
var _t := 0.0
var _measuring := false
var _frames := 0
var _sum := 0.0
var _rows: Array = []


func _ready() -> void:
	print("СТРИП-ПРОГІН: %d варіантів по %.0f с" % [STEPS.size(), SETTLE_SEC + MEASURE_SEC])
	_next_step()


func _next_step() -> void:
	if _step >= 0:
		_record()
	_step += 1
	if _step >= STEPS.size():
		_report()
		queue_free()
		return
	var flags := PackedStringArray()
	for f in (STEPS[_step]["flags"] as Array):
		flags.append(String(f))
	run.call("debug_strip", flags)
	_t = 0.0
	_measuring = false
	_frames = 0
	_sum = 0.0


func _process(delta: float) -> void:
	_t += delta
	if not _measuring:
		if _t >= SETTLE_SEC:
			_measuring = true
			_t = 0.0
		return
	_frames += 1
	_sum += delta
	if _t >= MEASURE_SEC:
		_next_step()


## Окрім часу кадру пишемо ще виклики й примітиви: без них «стало швидше» не пояснює, ЧОМУ.
func _record() -> void:
	var ms := 1000.0 * _sum / float(maxi(1, _frames))
	_rows.append({
		"назва": STEPS[_step]["назва"],
		"мс": snappedf(ms, 0.1),
		"кс": snappedf(1000.0 / maxf(0.001, ms), 0.1),
		"виклики": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"примітиви": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
	})
	print("СТРИП %-26s %6.1f мс  %4.1f к/с  виклики %4d  примітиви %7d" % [
		_rows[-1]["назва"], _rows[-1]["мс"], _rows[-1]["кс"],
		_rows[-1]["виклики"], _rows[-1]["примітиви"]])


func _report() -> void:
	print("СТРИП-ПІДСУМОК ==========================================")
	var base := float((_rows[0] as Dictionary)["мс"]) if not _rows.is_empty() else 0.0
	for r in _rows:
		var d: Dictionary = r
		var gain := base - float(d["мс"])
		print("СТРИП %-26s %6.1f мс  (%+6.1f)  виклики %4d  примітиви %7d" % [
			d["назва"], float(d["мс"]), -gain, int(d["виклики"]), int(d["примітиви"])])
	print("СТРИП-ПІДСУМОК ==========================================")
