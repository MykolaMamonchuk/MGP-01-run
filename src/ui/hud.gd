## HUD: зірочки, кнопка батьків, станція, підказка, сон.
## Будується кодом. Кожен дитячий елемент має намальовану іконку (src/ui/icons.gd), текст — лише другорядний.
extends CanvasLayer

var stars_label: Label
var profile_label: Label
var hint: Control
var station_panel: Control
var sleep_panel: Control
var yawn_panel: Control
var parents_open := false

var _root: Control
var _hint_t := 0.0
var _sleep_button: Button
var _parents_panel: Control
var _quest_box: HBoxContainer
var _quest_label: Label
var _quest_icon: Control
var _fork_box: HBoxContainer
var _fork_cb: Callable

func _ready() -> void:
	# HUD має жити й тоді, коли дерево на паузі (станція, сон, екран батьків).
	process_mode = Node.PROCESS_MODE_ALWAYS
	# над меню (5) і каруселлю героїв (6): екран батьків не перекривається
	layer = 10

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var stars_box := HBoxContainer.new()
	stars_box.position = Vector2(1000, 24)
	stars_box.add_theme_constant_override("separation", 10)
	stars_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(stars_box)
	stars_box.add_child(Icons.StarIcon.new(56.0))
	stars_label = UIKit.title("0", 48)
	stars_box.add_child(stars_label)

	Events.star_collected.connect(_on_star_collected)
	Events.checkpoint_reached.connect(_on_checkpoint_reached)

	profile_label = Label.new()
	profile_label.position = Vector2(560, 24)
	profile_label.add_theme_font_size_override("font_size", 20)
	profile_label.modulate.a = 0.5
	_root.add_child(profile_label)

	var parents := Button.new()
	parents.position = Vector2(24, 24)
	parents.custom_minimum_size = Vector2(96, 96)
	parents.tooltip_text = "Для батьків"
	parents.pressed.connect(_request_parents)
	_root.add_child(parents)
	var parent_icon := Icons.ParentIcon.new(64.0)
	parent_icon.position = Vector2(16, 16)
	parents.add_child(parent_icon)

	hint = Icons.HandIcon.new(96.0)
	hint.position = Vector2(300, 300)
	hint.visible = false
	_root.add_child(hint)

	station_panel = _panel(_root, Icons.StationIcon.new(96.0), "Станція!\nКуди далі?")
	yawn_panel = _panel(_root, Icons.MoonIcon.new(96.0), "Герой втомлюється…")
	sleep_panel = _panel(_root, Icons.MoonIcon.new(96.0), "На добраніч!")

	# мінізавдання (від mid): іконка + прогрес, під зірочками
	_quest_box = HBoxContainer.new()
	_quest_box.position = Vector2(1000, 96)
	_quest_box.add_theme_constant_override("separation", 10)
	_quest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_box.visible = false
	_root.add_child(_quest_box)
	_quest_label = Label.new()
	_quest_label.add_theme_font_size_override("font_size", 28)
	_quest_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quest_box.add_child(_quest_label)

	# Розвилка: контейнер під дверима, ховається
	_fork_box = HBoxContainer.new()
	_fork_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_fork_box.add_theme_constant_override("separation", 48)
	_fork_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_fork_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_fork_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_fork_box.offset_top = -40
	_fork_box.offset_bottom = -40
	_fork_box.visible = false
	_root.add_child(_fork_box)
	_refresh()

func _panel(parent: Control, icon: Control, text: String) -> Control:
	var p := PanelContainer.new()
	ParentGate._center(p, Vector2(600, 300))
	p.visible = false
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	row.add_child(icon)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 44)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	parent.add_child(p)
	return p

## Текстова частина панелі (іконка — перша дитина рядка).
func _panel_label(p: Control) -> Label:
	return p.get_child(0).get_child(1) as Label

func _process(delta: float) -> void:
	if hint.visible:
		_hint_t += delta
		hint.position.y = 300 + sin(_hint_t * 6.0) * 20.0
		if _hint_t > 2.5:
			hint.visible = false

func _on_star_collected(_n: int) -> void:
	call_deferred("_refresh")

func _on_checkpoint_reached(_i: int) -> void:
	call_deferred("_refresh")

func _refresh() -> void:
	stars_label.text = "%d" % SaveService.stars()

var _profile_name := ""
var _world_name := ""

func set_profile(profile_name: String) -> void:
	_profile_name = profile_name
	_refresh_caption()

func set_world(world_name: String) -> void:
	_world_name = world_name
	_refresh_caption()

func _refresh_caption() -> void:
	profile_label.text = "%s · профіль: %s" % [_world_name, _profile_name]

func show_hint() -> void:
	_hint_t = 0.0
	hint.visible = true

func show_yawn() -> void:
	yawn_panel.visible = true
	get_tree().create_timer(2.0).timeout.connect(_end_yawn)

func _end_yawn() -> void:
	if is_instance_valid(yawn_panel):
		yawn_panel.visible = false

func show_station(i: int) -> void:
	_panel_label(station_panel).text = "Станція %d!\n+20   Куди далі?" % i
	station_panel.visible = true
	# панель станції піднімаємо, щоб не перекривати двері Розвилки
	station_panel.offset_top = -200
	station_panel.offset_bottom = -200

func hide_station() -> void:
	station_panel.visible = false
	hide_fork()

## Розвилка: великі двері-кнопки. options = [{"id","name_uk","accent"}], cb(id).
func show_fork(options: Array, cb: Callable) -> void:
	_fork_cb = cb
	for c in _fork_box.get_children():
		c.queue_free()
	for opt in options:
		var id := String(opt.get("id", "meadow"))
		var b := UIKit.button("", Color(String(opt.get("accent", "#F06292"))).lightened(0.15), Vector2(250, 270))
		b.pressed.connect(_on_fork_pressed.bind(id))
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var ic := Icons.WorldIcon.new(id, 140.0)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var l := UIKit.title(String(opt.get("name_uk", id)), 36)
		v.add_child(l)
		_fork_box.add_child(b)
	_fork_box.visible = true
	call_deferred("_pop_fork")

func _pop_fork() -> void:
	var i := 0
	for b in _fork_box.get_children():
		UIKit.pop_in(b, 0.1 * i)
		i += 1

func _on_fork_pressed(id: String) -> void:
	hide_fork()
	if _fork_cb.is_valid():
		_fork_cb.call(id)

func hide_fork() -> void:
	_fork_box.visible = false

func fork_visible() -> bool:
	return _fork_box.visible

## Меню/герої: ховаємо ігрові елементи, лишаємо зірочки й кнопку батьків.
func set_gameplay_visible(on: bool) -> void:
	profile_label.visible = on
	if not on:
		_quest_box.visible = false
		hint.visible = false

## Великий напис по центру з пружиною (відлік «3 2 1 Біжимо!», «Станція!»).
func flash(text: String, seconds: float = 0.7, color: Color = Color.WHITE) -> void:
	var l := UIKit.title(text, 140, color)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(l)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2.ZERO
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.05, seconds - 0.45))
	tw.tween_property(l, "scale", Vector2.ONE * 1.4, 0.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.2)
	tw.finished.connect(l.queue_free)

## Зірочка летить з місця збору до лічильника.
func fly_star(from_screen: Vector2) -> void:
	var s := Icons.StarIcon.new(40.0)
	s.position = from_screen - Vector2(20, 20)
	_root.add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "position", stars_label.get_global_rect().position - Vector2(50, 0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(s, "scale", Vector2(0.6, 0.6), 0.45)
	tw.finished.connect(func():
		s.queue_free()
		_bump_counter())

func _bump_counter() -> void:
	var box := stars_label.get_parent() as Control
	box.pivot_offset = box.size * 0.5
	var tw := create_tween()
	tw.tween_property(box, "scale", Vector2(1.25, 1.25), 0.08)
	tw.tween_property(box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC)

## Мінізавдання: kind ("stars"/"passed"/"events"), прогрес/ціль. target 0 — сховати.
func set_quest(kind: String, value: int, target: int) -> void:
	if target <= 0:
		_quest_box.visible = false
		return
	if _quest_icon == null or _quest_icon.get("kind") != kind:
		if _quest_icon:
			_quest_icon.queue_free()
		_quest_icon = Icons.QuestIcon.new(kind, 40.0)
		_quest_box.add_child(_quest_icon)
		_quest_box.move_child(_quest_icon, 0)
	_quest_label.text = "%d / %d" % [value, target]
	_quest_box.visible = true

## Завдання виконано: підсвітка + панель на секунду.
func show_quest_done(reward: int) -> void:
	_quest_label.text = "+%d" % reward
	var tw := create_tween()
	tw.tween_property(_quest_box, "scale", Vector2(1.3, 1.3), 0.15)
	tw.tween_property(_quest_box, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC)

func show_sleep(on_parent_continue: Callable) -> void:
	sleep_panel.visible = true
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.05, 0.05, 0.2, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	move_child(dim, 0)
	_sleep_button = Button.new()
	_sleep_button.text = "Батьки: продовжити"
	_sleep_button.position = Vector2(480, 560)
	_sleep_button.custom_minimum_size = Vector2(320, 80)
	_sleep_button.add_theme_font_size_override("font_size", 24)
	_sleep_button.pressed.connect(on_parent_continue)
	_root.add_child(_sleep_button)

func hide_sleep() -> void:
	sleep_panel.visible = false
	if has_node("Dim"):
		get_node("Dim").queue_free()
	if is_instance_valid(_sleep_button):
		_sleep_button.queue_free()
	_sleep_button = null

## Безпечний доступ до сцени бігу (може не бути батьком у тестах).
func _run() -> Node:
	var p := get_parent()
	if is_instance_valid(p) and p.has_method("_leave_station"):
		return p
	return null

func _run_is_busy() -> bool:
	var r := _run()
	if r == null:
		return false
	return bool(r.get("paused_at_station")) or bool(r.get("sleeping"))

func _request_parents() -> void:
	# поки бар'єр відкритий, гра стоїть (інакше герой біжить за затемненням)
	parents_open = true
	get_tree().paused = true
	ParentGate.closed.connect(_on_gate_closed, CONNECT_ONE_SHOT)
	ParentGate.request("settings", _open_parents)

## Бар'єр закрився: якщо екран батьків не відкрився (натиснуто «Назад») — знімаємо паузу.
## При успіху _open_parents викликається одразу після цього і ставить паузу знову.
func _on_gate_closed() -> void:
	if not is_instance_valid(_parents_panel):
		_close_parents()

func _request_buy() -> void:
	ParentGate.request("money", Purchase.buy_full_game)

func _set_session_minutes(m: int) -> void:
	SaveService.set_setting("session_minutes", m)
	SessionTimer.start(float(m))

func _close_parents() -> void:
	parents_open = false
	if is_instance_valid(_parents_panel):
		_parents_panel.queue_free()
	_parents_panel = null
	if has_node("ParentsDim"):
		get_node("ParentsDim").queue_free()
	if not _run_is_busy():
		get_tree().paused = false

func _open_parents() -> void:
	var s := SaveService
	parents_open = true
	get_tree().paused = true
	# затемнення + блокування кліків по грі під панеллю
	var dim := ColorRect.new()
	dim.name = "ParentsDim"
	dim.color = Color(0.05, 0.05, 0.15, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var p := PanelContainer.new()
	ParentGate._center(p, Vector2(800, 480))
	add_child(p)
	_parents_panel = p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(Icons.ParentIcon.new(48.0))
	var t := Label.new()
	t.text = "Екран батьків"
	t.add_theme_font_size_override("font_size", 36)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(t)
	var info := Label.new()
	info.text = "Зірочок: %d   Пройдено перешкод: %d   Падінь: %d   Сесій завершено сном: %d\nПрофіль віку: %s (авто)\nПовна гра: %s" % [
		s.stars(), Stats.get_value("obstacles_passed"), Stats.get_value("tumbles"),
		Stats.get_value("sessions_finished_by_sleep"), AgeAdapt.current, "так" if Purchase.is_full_game() else "ні — 4,99 $ разово, без реклами назавжди"]
	info.add_theme_font_size_override("font_size", 22)
	v.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var l := Label.new()
	l.text = "Сесія, хв:"
	l.add_theme_font_size_override("font_size", 24)
	row.add_child(l)
	for m in [10, 15, 20, 30]:
		var b := Button.new()
		b.text = str(m)
		b.custom_minimum_size = Vector2(90, 70)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_set_session_minutes.bind(int(m)))
		row.add_child(b)
	var buy := Button.new()
	buy.text = "Купити «Повну гру» (4,99 $)"
	buy.custom_minimum_size = Vector2(400, 80)
	buy.add_theme_font_size_override("font_size", 24)
	buy.pressed.connect(_request_buy)
	v.add_child(buy)
	var back := Button.new()
	back.text = "Назад"
	back.custom_minimum_size = Vector2(200, 80)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(_close_parents)
	v.add_child(back)
