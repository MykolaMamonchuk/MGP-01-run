## Стрічка карток із гортанням: ‹ [вікно] ›.
## Компонент знає лише про розкладку й гортання; ЩО намальовано на картках — справа власника (set_cards).
## Гортання: стрілки листають на сторінку, свайп тягне за пальцем із «гумовими» краями.
## Стрілки з'являються, лише коли вміст не вміщується.
class_name ItemStrip
extends HBoxContainer

## Вікно стрічки: 900 + дві стрілки вміщуються у 1280.
const VIEW := Vector2(900, 150)
## Зсув, після якого рух вважаємо свайпом, а не тапом по картці.
const DRAG_THRESHOLD := 12.0
const ARROW := Vector2(96, 96)
const CARD_GAP := 10

var _view: Control            # вікно, що обрізає
var _rail: HBoxContainer      # сама стрічка, рухається по x
var _left: Button
var _right: Button
var _tween: Tween
var _drag_active := false
var _drag_moved := false
var _drag_origin := 0.0
var _drag_start_x := 0.0


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 14)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	_left = UIKit.button("‹", Palette.BTN_NAV, ARROW, 56)
	_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_left.pressed.connect(_page.bind(-1))
	add_child(_left)

	_view = Control.new()
	_view.custom_minimum_size = VIEW
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.gui_input.connect(_on_input)
	add_child(_view)

	_rail = HBoxContainer.new()
	_rail.alignment = BoxContainer.ALIGNMENT_BEGIN
	_rail.add_theme_constant_override("separation", CARD_GAP)
	_rail.mouse_filter = Control.MOUSE_FILTER_PASS
	_view.add_child(_rail)

	_right = UIKit.button("›", Palette.BTN_NAV, ARROW, 56)
	_right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_right.pressed.connect(_page.bind(1))
	add_child(_right)

	# Сигнали розкладки чіпляємо ОСТАННІМИ: add_child() вище одразу міняє розміри,
	# і _layout() побачив би ще порожні _rail/_left/_right (звідси й падало).
	_view.resized.connect(_layout.bind(false))
	_rail.minimum_size_changed.connect(_layout.bind(false))


# ───────────────────────────── чисті функції ─────────────────────────────

## x стрічки в межах вікна: вміщується — по центру; ні — від (view_w − content_w) до 0.
static func clamp_x(x: float, content_w: float, view_w: float) -> float:
	if content_w <= view_w:
		return (view_w - content_w) * 0.5
	return clampf(x, view_w - content_w, 0.0)


## x після перелистування на одну сторінку (dir −1/+1 — вліво/вправо по вмісту).
static func page_x(x: float, dir: int, content_w: float, view_w: float) -> float:
	return clamp_x(x - float(dir) * view_w, content_w, view_w)


# ───────────────────────────── публічний API ─────────────────────────────

## Замінити вміст. reset — стати на початок; інакше лишаємось на місці (у межах).
func set_cards(cards: Array, reset: bool = true) -> void:
	_kill_tween()
	for c in _rail.get_children():
		_rail.remove_child(c)   # одразу з контейнера, інакше кадр подвійної стрічки
		c.queue_free()
	for c in cards:
		_rail.add_child(c)
	_layout(reset)


func cards() -> Array:
	return _rail.get_children()


## Пружна поява карток по черзі.
func pop_in_cards() -> void:
	var i := 0
	for c in _rail.get_children():
		UIKit.pop_in(c, 0.04 * i)
		i += 1


## Чи щойно був свайп — тоді тап по картці ігнорують.
func drag_moved() -> bool:
	return _drag_moved


## Чи вміст уміщується у вікно (тоді стрілки сховані).
func fits() -> bool:
	return _content_w() <= _view_w() + 0.5


## Зсув стрічки по x (0 — початок; від'ємний — прогорнуто вправо).
func offset_x() -> float:
	return _rail.position.x


# ───────────────────────────── розкладка ─────────────────────────────────

func _content_w() -> float:
	return _rail.get_combined_minimum_size().x


func _view_w() -> float:
	return _view.size.x if _view.size.x > 0.0 else VIEW.x


## Розмір стрічки = мінімальний; x — у межах; стрілки лише коли не вміщується.
func _layout(reset: bool = false) -> void:
	if _rail == null or _view == null:
		return   # ще будуємось — розкладати нічого
	var cw := _content_w()
	var vw := _view_w()
	var vh: float = _view.size.y if _view.size.y > 0.0 else VIEW.y
	_rail.size = Vector2(cw, vh)
	_rail.position.y = 0.0
	var x := 0.0 if reset else _rail.position.x
	_rail.position.x = clamp_x(x, cw, vw)
	_update_arrows()


func _update_arrows() -> void:
	var cw := _content_w()
	var vw := _view_w()
	var inside := cw <= vw + 0.5
	_left.visible = not inside
	_right.visible = not inside
	if inside:
		return
	var x := _rail.position.x
	_left.modulate = Color(1, 1, 1, 1.0 if x < -0.5 else 0.45)
	_right.modulate = Color(1, 1, 1, 1.0 if x > vw - cw + 0.5 else 0.45)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


## Плавно доїхати до x і оновити стрілки.
func _glide(to_x: float, dur: float = 0.3) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_rail, "position:x", to_x, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.step_finished.connect(func(_i): _update_arrows())
	_tween.finished.connect(_update_arrows)


## Стрілки ‹ ›: на сторінку (ширину вікна) з обмеженням країв.
func _page(dir: int) -> void:
	AudioMgr.sfx("ui_tap")
	var target := page_x(_rail.position.x, dir, _content_w(), _view_w())
	if is_equal_approx(target, _rail.position.x):
		UIKit.shake(_left if dir < 0 else _right)
		return
	_glide(target)


## Свайп: тягнемо за пальцем (без інерції), відпустили — доїжджаємо до краю.
## Тап (< DRAG_THRESHOLD) лишається кнопці-картці.
func _on_input(ev: InputEvent) -> void:
	var pressed_down := false
	var released := false
	var pos_x := 0.0
	var is_motion := false
	var touch := ev as InputEventScreenTouch
	var mb := ev as InputEventMouseButton
	var sdrag := ev as InputEventScreenDrag
	var mm := ev as InputEventMouseMotion
	if touch != null:
		pressed_down = touch.pressed
		released = not touch.pressed
		pos_x = touch.position.x
	elif mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		pressed_down = mb.pressed
		released = not mb.pressed
		pos_x = mb.position.x
	elif sdrag != null:
		is_motion = true
		pos_x = sdrag.position.x
	elif mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		is_motion = true
		pos_x = mm.position.x
	else:
		return
	if pressed_down:
		_drag_active = true
		_drag_moved = false
		_drag_origin = pos_x
		_drag_start_x = _rail.position.x
		return
	if released:
		var was_drag := _drag_moved
		_drag_active = false
		if was_drag:
			_glide(clamp_x(_rail.position.x, _content_w(), _view_w()), 0.25)
			_view.accept_event()
		# _drag_moved скидаємо наступного кадру: кнопка під пальцем обробляє відпускання раніше за нас або пізніше
		call_deferred("_reset_drag_moved")
		return
	if is_motion and _drag_active:
		var dx := pos_x - _drag_origin
		if not _drag_moved and absf(dx) > DRAG_THRESHOLD:
			_drag_moved = true
			_kill_tween()
		if _drag_moved:
			var raw := _drag_start_x + dx
			var clamped := clamp_x(raw, _content_w(), _view_w())
			_rail.position.x = clamped + (raw - clamped) * 0.3   # «гумовий» край
			_update_arrows()
			_view.accept_event()


func _reset_drag_moved() -> void:
	_drag_moved = false
