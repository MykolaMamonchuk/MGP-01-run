## Батьківський бар'єр. "settings" — утримати кнопку 3 с; "money" — розв'язати приклад.
## Використання: ParentGate.request("money", func(): ...)
## Autoload: ParentGate.
extends CanvasLayer

const HOLD_SECONDS := 3.0
const MAX_FAILS := 2
const LOCK_MSEC := 30000

var _on_success: Callable
var _layer: Control
var _hold_time := 0.0
var _holding := false
var _answer := 0
var _fails := 0
var _locked_until := 0

func _ready() -> void:
	# бар'єр працює й тоді, коли дерево на паузі (станція, сон, екран батьків)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = false

## Чи діє тимчасове блокування після кількох невірних відповідей.
func is_locked() -> bool:
	return Time.get_ticks_msec() < _locked_until

func request(kind: String, on_success: Callable) -> void:
	if is_locked():
		_on_success = Callable()
		_build_locked()
		visible = true
		return
	_on_success = on_success
	_build(kind)
	visible = true

## Чиста функція для тестів.
static func make_question(rng_seed: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	var a := rng.randi_range(2, 9)
	var b := rng.randi_range(2, 9)
	var wrong := []
	while wrong.size() < 3:
		var w := a + b + rng.randi_range(-4, 4)
		if w != a + b and w > 0 and not wrong.has(w):
			wrong.append(w)
	var options := wrong.duplicate()
	options.append(a + b)
	# перемішування власним rng: із заданим seed результат відтворюваний у тестах
	for i in range(options.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = options[i]
		options[i] = options[j]
		options[j] = tmp
	return {"text": "%d + %d = ?" % [a, b], "answer": a + b, "options": options}

func _build(kind: String) -> void:
	if _layer:
		_layer.queue_free()
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(640, 360)
	panel.position = Vector2(320, 180)
	_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Для батьків"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	if kind == "money":
		var q := make_question()
		_answer = q["answer"]
		var lbl := Label.new()
		lbl.text = q["text"]
		lbl.add_theme_font_size_override("font_size", 48)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(lbl)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		box.add_child(row)
		for opt in q["options"]:
			var b := Button.new()
			b.text = str(opt)
			b.custom_minimum_size = Vector2(110, 96)
			b.add_theme_font_size_override("font_size", 36)
			b.pressed.connect(_on_answer.bind(int(opt)))
			row.add_child(b)
	else:
		var hint := Label.new()
		hint.text = "Утримуй кнопку 3 секунди"
		hint.add_theme_font_size_override("font_size", 28)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(hint)
		var hold := Button.new()
		hold.text = "Тримай…"
		hold.custom_minimum_size = Vector2(320, 110)
		hold.add_theme_font_size_override("font_size", 36)
		hold.button_down.connect(_on_hold_down)
		hold.button_up.connect(_on_hold_up)
		box.add_child(hold)
	var cancel := Button.new()
	cancel.text = "Назад"
	cancel.custom_minimum_size = Vector2(200, 80)
	cancel.add_theme_font_size_override("font_size", 28)
	cancel.pressed.connect(close)
	box.add_child(cancel)

func _on_hold_down() -> void:
	_holding = true
	_hold_time = 0.0

func _on_hold_up() -> void:
	_holding = false
	_hold_time = 0.0

## Коротка панель для стану блокування.
func _build_locked() -> void:
	if _layer:
		_layer.queue_free()
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(640, 260)
	panel.position = Vector2(320, 230)
	_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	panel.add_child(box)
	var msg := Label.new()
	msg.text = "Спробуйте пізніше"
	msg.add_theme_font_size_override("font_size", 40)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(msg)
	var cancel := Button.new()
	cancel.text = "Назад"
	cancel.custom_minimum_size = Vector2(200, 80)
	cancel.add_theme_font_size_override("font_size", 28)
	cancel.pressed.connect(close)
	box.add_child(cancel)

func _process(delta: float) -> void:
	if visible and _holding:
		_hold_time += delta
		if _hold_time >= HOLD_SECONDS:
			_holding = false
			_succeed()

func _on_answer(value: int) -> void:
	if value == _answer:
		_fails = 0
		_succeed()
	else:
		_fails += 1
		if _fails >= MAX_FAILS:
			_locked_until = Time.get_ticks_msec() + LOCK_MSEC
			_fails = 0
		close()

func _succeed() -> void:
	var cb := _on_success
	close()
	if cb.is_valid():
		cb.call()

func close() -> void:
	visible = false
	_holding = false
	if _layer:
		_layer.queue_free()
		_layer = null
