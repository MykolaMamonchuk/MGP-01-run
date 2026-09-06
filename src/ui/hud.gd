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

func _ready() -> void:
	# HUD має жити й тоді, коли дерево на паузі (станція, сон, екран батьків).
	process_mode = Node.PROCESS_MODE_ALWAYS

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
	stars_label = Label.new()
	stars_label.add_theme_font_size_override("font_size", 44)
	stars_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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

	station_panel = _panel(_root, Icons.StationIcon.new(96.0), "Станція!\nТап — біжимо далі")
	yawn_panel = _panel(_root, Icons.MoonIcon.new(96.0), "Герой втомлюється…")
	sleep_panel = _panel(_root, Icons.MoonIcon.new(96.0), "На добраніч!")
	_refresh()

func _panel(parent: Control, icon: Control, text: String) -> Control:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.position = Vector2(340, 200)
	p.custom_minimum_size = Vector2(600, 300)
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

func set_profile(profile_name: String) -> void:
	profile_label.text = "профіль: %s" % profile_name

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
	_panel_label(station_panel).text = "Станція %d!\n+20   Тап — біжимо далі" % i
	station_panel.visible = true

func hide_station() -> void:
	station_panel.visible = false

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
	ParentGate.request("settings", _open_parents)

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
	if not _run_is_busy():
		get_tree().paused = false

func _open_parents() -> void:
	var s := SaveService
	parents_open = true
	get_tree().paused = true
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.position = Vector2(240, 120)
	p.custom_minimum_size = Vector2(800, 480)
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
