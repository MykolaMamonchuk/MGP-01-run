extends Node

## ПРОГІН УСІХ РІВНІВ ПІДРЯД — щоб шукати ривки й провали там, де їх бачить дитина, а не
## лише на одному зручному відрізку.
##
## Навіщо окремо від `strip_probe`. Та проба міряє СИСТЕМИ: заморожує світ на одній точці й
## порівнює варіанти між собою. Тут інше питання — «де в грі погано»: кожен рівень має свій
## біом, свою щільність забудови й свої події, і провал може бути в одному з сімнадцяти.
## Тому тут нічого не заморожується й не вимикається: гра йде як є, а ми лише дивимось.
##
## ГЕРОЙ НЕ ГИНЕ. Кожен кадр йому продовжують невразливість: інакше замір рівня обірвався б
## на першій перешкоді, і довші рівні ніколи б не дійшли до щільних ділянок.
##
## Живе в `src/ui/`, а не в `src/debug/`: друга тека виключена з експорту, тож у збірку
## звідти вона б не потрапила.
##
## Вмикається прапорцем збірки `sweep` (tools/probe_build.py sweep Android).
##
## ВІДОМА ПРОГАЛИНА: РІВЕНЬ 14 ЦЯ ПРОБА НЕ МІРЯЄ. Він стабільно випадає в кожному прогоні
## зі станом 8 («сон»), бо туди його відправляє таймер СЕАНСУ, а не вада рівня — це вже
## з'ясовано окремо. Проба про це голосно каже й чисел не вигадує, але один рівень із
## сімнадцяти лишається поза наглядом, і жоден висновок «по всіх рівнях» його не враховує.
##
## Свідомо НЕ лагодимо тут: скидати таймер сеансу означало б міряти не ту гру, в яку грає
## дитина. Якщо колись знадобиться приймальний прогін із повним покриттям — це окремий
## сценарій, який заморожує сон, а не правка цієї проби.

## Скільки тримати кожен рівень. Сорок секунд — це 150-250 метрів залежно від швидкості
## профілю, тобто повз кілька цеглинок, а не одну.
const SEC_PER_LEVEL := 40.0
## Прогрів після старту рівня, що НЕ рахується: перші кадри несуть читання цеглинки й
## побудову пропсів, і без цього кожен рівень виглядав би гіршим, ніж він є.
const WARM_SEC := 4.0
## Кадр вважаємо ривком, якщо він довший за медіану в стільки разів.
const HITCH_K := 2.5

var run: Node = null

var _level := 0
var _t := 0.0
var _ms: Array[float] = []
var _rows: Array[String] = []
var _started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(3.0).timeout
	# ВІДМИКАЄМО ЗАМКИ. Без цього _start_level() для непройденого рівня мовчки відсилає на
	# мапу й виходить — а проба цього не бачить і сорок секунд міряє ЕКРАН МАПИ. Саме так
	# перший прогін дав для рівнів 8-17 однакові 66,7 мс і світ «forest»: то була мапа.
	if run != null:
		run.set("_demo_any_level", true)
	_next_level()


func _next_level() -> void:
	if _started:
		_report_level()
	_level += 1
	var total: int = 17
	if run != null and run.get("lm") != null:
		total = int(run.lm.count())
	if _level > total:
		_report_all()
		return
	_ms.clear()
	_t = 0.0
	_started = true
	run.call("_start_level", _level)
	print("ПРОГІН: рівень %d із %d" % [_level, total])


## Чи справді почався рівень, а не екран мапи. Стан 5 — «біг», 4 — «відлік» (див.
## DebugOverlay.state_names). Якщо проба цього не перевіряє, вона мовчки міряє не те.
func _really_running() -> bool:
	var st := int(run.get("state"))
	return st == 4 or st == 5


func _process(delta: float) -> void:
	if not _started or run == null:
		return
	# Тримаємо героя живим. Значення з запасом на кадр: перешкоди знімають серце самі,
	# і достатньо, щоб невразливість не встигла спасти між кадрами.
	var h = run.get("hero")
	if h != null and h.has_method("set_invulnerable"):
		h.set_invulnerable(1.0)
	_t += delta
	if _t < WARM_SEC:
		return
	if not _really_running():
		# Рівень не почався (замок, фініш, пауза) — міряти нема чого, йдемо далі й КАЖЕМО
		# про це, а не мовчки пишемо в таблицю чужі числа.
		print("ПРОГІН рівень %2d ПРОПУЩЕНО: гра не в бігу (стан %d)"
			% [_level, int(run.get("state"))])
		_ms.clear()
		_next_level()
		return
	_ms.append(delta * 1000.0)
	if _t >= WARM_SEC + SEC_PER_LEVEL:
		_next_level()


func _report_level() -> void:
	if _ms.is_empty():
		return
	var v: Array[float] = _ms.duplicate()
	v.sort()
	var med: float = v[v.size() / 2]
	var p95: float = v[mini(v.size() - 1, int(float(v.size()) * 0.95))]
	var worst: float = v[v.size() - 1]
	var hitches := 0
	for x in v:
		if x > med * HITCH_K:
			hitches += 1
	var world := "?"
	var lanes := 0
	if run.get("world_id") != null:
		world = String(run.get("world_id"))
		lanes = int(run.get("lanes"))
	var line := ("рівень %2d %-8s доріжок %d  мед %6.1f  p95 %6.1f  найгірший %7.1f"
		+ "  ривків %3d із %4d  к/с %4.1f") % [
		_level, world, lanes, med, p95, worst, hitches, v.size(), 1000.0 / maxf(med, 0.01)]
	_rows.append(line)
	print("ПРОГІН ", line)


func _report_all() -> void:
	print("ПРОГІН ================ ПІДСУМОК ================")
	for r in _rows:
		print("ПРОГІН ", r)
	print("ПРОГІН ================ КІНЕЦЬ ================")
	_started = false
