## Якість зображення — вибір дорослого, а не прибите число в project.godot.
## Autoload: Quality.
##
## ЧОМУ ЦЕ НАЛАШТУВАННЯ. Згладжування країв MSAA 4× тримає в відеопам'яті ще один,
## учетверо більший буфер кадру: заміряно двічі пробою (рівень 2, 2400 кадрів, М1,
## кадр 2880×1552) — `texture_mem_mb` 342,8 при 4× проти 189,3 без MSAA, `video_mem`
## 558,5 → 405,1. Тобто саме згладжування коштує ~153 МБ — учетверо більше, ніж уся
## графіка гри разом (36,7 МБ). На телефоні з екраном 1080×2400 це буде близько 80 МБ,
## але порядок той самий. Подробиці: docs/optimisation/2026-09-19-texture-vram.md, OPT-11.
##
## ЩО САМЕ ПЕРЕМИКАЄМО. Лише `msaa_3d` в'юпорта. FXAA (`screen_space_aa=1`) лишається
## увімкненим у всіх станах: він не тримає зайвого буфера, тобто згладжування в грі є
## завжди, навіть у найдешевшому стані — просто м'якше.
##
## ЗАСТОСУВАННЯ БЕЗ ПЕРЕЗАПУСКУ. `msaa_3d` — властивість в'юпорта, а не лише параметр
## проєкту: `get_viewport().msaa_3d = ...` діє з наступного кадру, і на вже відкритій
## сцені гри теж. Тому кнопка на екрані батьків міняє картинку одразу.
extends Node

## Ключі станів у збереженні. Рядки, а не числа: у save.json їх видно оком.
const SMOOTH := "smooth"
const MIDDLE := "middle"
const PRETTY := "pretty"

## Порядок для інтерфейсу: від найдешевшого до найгарнішого.
const ORDER: Array[String] = [SMOOTH, MIDDLE, PRETTY]

## Ключ у settings збереження.
const KEY := "quality"

## ТИПОВЕ — «Плавно». Гра мобільна й для малят: рівний біг важливіший за чіткий край.
## Дитина 3–6 років не бачить сходинок на поручні, але одразу бачить ривок — а ривок на
## бігунці це промах по перешкоді й сльози. До того ж 153 МБ відеопам'яті на дешевому
## телефоні — це різниця між «працює» і «система вбиває застосунок». Дорослий, у якого
## телефон сильний, вмикає «Гарно» двома дотиками.
const DEFAULT := SMOOTH

## Стан → значення Viewport.msaa_3d.
const MSAA := {
	SMOOTH: Viewport.MSAA_DISABLED,
	MIDDLE: Viewport.MSAA_2X,
	PRETTY: Viewport.MSAA_4X,
}

## Стан → підпис для батьків. Без слова «MSAA»: воно нічого не каже тому, хто обирає.
const LABEL := {
	SMOOTH: "Плавно",
	MIDDLE: "Середнє",
	PRETTY: "Гарно",
}

## Один рядок пояснення під кнопками — теж мовою батьків.
const HINT := "«Плавно» — рівніший біг на слабшому телефоні; «Гарно» — чіткіші краї, але більше навантаження."


func _ready() -> void:
	apply()


## Чинний стан. Невідоме або зіпсоване значення в збереженні — це DEFAULT, а не збій.
func current() -> String:
	var v := String(SaveService.setting(KEY, DEFAULT))
	return v if ORDER.has(v) else DEFAULT


## Вибрати стан: зберегти й застосувати одразу. Невідому назву тихо не ковтаємо.
func set_current(name: String) -> void:
	if not ORDER.has(name):
		push_warning("Quality: невідомий стан «%s», лишаю %s" % [name, current()])
		return
	SaveService.set_setting(KEY, name)
	apply()


## Застосувати чинний стан до в'юпорта. Викликається на старті й після кожного вибору.
func apply() -> void:
	apply_state(current())


## Застосувати ЗАДАНИЙ стан, не чіпаючи збереження — для замірів (tools/probe, QUALITY=).
func apply_state(name: String) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var st := name if ORDER.has(name) else current()
	vp.msaa_3d = msaa_of(st) as Viewport.MSAA
	# Тіні — властивість СВІТЛА, а не в'юпорта, тож шукаємо сонце в дереві. Якщо сцена без
	# нього (меню, тести), просто нічого не робимо.
	for l in _lights(vp):
		l.shadow_enabled = shadows_of(st)


static func _lights(n: Node) -> Array:
	var out: Array = []
	if n is DirectionalLight3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_lights(c))
	return out


## Чи малювати ТІНІ В ЦЬОМУ СТАНІ. Чиста функція, як і msaa_of — щоб перевірялась тестом.
##
## Заміряно на Redmi 8A (Adreno 505, Compatibility), двома контрольними точками з
## контролями в 0,06-0,08%: прохід тіней коштує 21-24 мс, тобто ЧВЕРТЬ кадру. Для порівняння
## ціла гра Luanti з лісом, водою й туманом іде на тому самому телефоні за 16,7 мс — і має
## `enable_dynamic_shadows = false` за замовчуванням.
##
## Чому це не забирає з гри найважливішого. У героя є ВЛАСНИЙ намальований овал тіні
## (`Hero3D._shadow`), а не справжня тінь від сонця. Підказка «де я стою» лишається в усіх
## станах; зникають лише тіні будинків і пропсів на землі.
##
## Перевірено, що інші ручки тіней не дають нічого: дальність 22 м проти 1 м — однаково,
## роздільність карти 2048 / 1024 / 512 — у межах шуму. Тобто коштує САМ ПРОХІД, і половинчасті
## заходи тут не працюють.
const SHADOWS := {
	SMOOTH: false,     # слабкий телефон: -22 мс, лишається овал під героєм
	MIDDLE: true,
	PRETTY: true,
}


static func shadows_of(name: String) -> bool:
	return bool(SHADOWS.get(name, SHADOWS[DEFAULT]))


## Скільки коштує стан у значеннях рушія. Чиста функція — саме її перевіряють тести.
static func msaa_of(name: String) -> int:
	return int(MSAA.get(name, MSAA[DEFAULT]))


## Підпис стану для інтерфейсу.
static func label_of(name: String) -> String:
	return String(LABEL.get(name, name))
