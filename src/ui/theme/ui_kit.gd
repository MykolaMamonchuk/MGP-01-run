## Дитячий UI-кіт: великі округлі кнопки з тінню, пружні появи, шрифт (якщо є файл).
## Використання: UIKit.button("Грати", Palette.BTN_PRIMARY, Vector2(360, 130), 48)
class_name UIKit
extends RefCounted

const FONT_PATH := "res://assets/fonts/kenney_mini_square.ttf"

static var _font: Font


static func font() -> Font:
	if _font == null and ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	return _font


static func label(text: String, size: int, color: Color = Palette.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := font()
	if f:
		l.add_theme_font_override("font", f)
	return l


## Заголовок з обведенням і тінню — читається на будь-якому тлі.
static func title(text: String, size: int, color: Color = Palette.TEXT_TITLE) -> Label:
	var l := label(text, size, color)
	l.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
	l.add_theme_constant_override("outline_size", int(size * 0.14))
	l.add_theme_color_override("font_shadow_color", Palette.TEXT_SHADOW)
	l.add_theme_constant_override("shadow_offset_y", int(size * 0.08))
	return l


static func _style(bg: Color, radius: int, shadow: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(16)
	s.shadow_color = Palette.SHADOW
	s.shadow_size = shadow
	s.shadow_offset = Vector2(0, shadow * 0.6)
	s.border_width_bottom = 6
	s.border_color = bg.darkened(0.25)
	return s


static func button(text: String, bg: Color, min_size: Vector2, font_size: int = 40) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Palette.WHITE)
	b.add_theme_color_override("font_pressed_color", Palette.WHITE)
	b.add_theme_color_override("font_hover_color", Palette.WHITE)
	b.add_theme_color_override("font_outline_color", bg.darkened(0.45))
	b.add_theme_constant_override("outline_size", int(font_size * 0.12))
	var f := font()
	if f:
		b.add_theme_font_override("font", f)
	var radius := int(minf(min_size.x, min_size.y) * 0.28)
	b.add_theme_stylebox_override("normal", _style(bg, radius, 10))
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.06), radius, 10))
	var pressed := _style(bg.darkened(0.12), radius, 3)
	pressed.border_width_bottom = 1
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pivot_offset = min_size * 0.5
	b.button_down.connect(func(): _press_anim(b, 0.94))
	b.button_up.connect(func(): _press_anim(b, 1.0))
	return b


## Кольорова рамка навколо кнопки (стан «одягнуто», «активна вкладка»).
## Прозорий колір знімає рамку візуально, не чіпаючи інші стилі.
static func frame(b: Button, col: Color) -> void:
	for st in ["normal", "hover", "pressed"]:
		var sb := b.get_theme_stylebox(st)
		if sb is StyleBoxFlat:
			var s := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			s.set_border_width_all(6)
			s.border_color = col
			b.add_theme_stylebox_override(st, s)


static func _press_anim(c: Control, to: float) -> void:
	var tw := c.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(c, "scale", Vector2.ONE * to, 0.08).set_trans(Tween.TRANS_SINE)


## Пружна поява (з нуля).
static func pop_in(c: Control, delay: float = 0.0) -> void:
	c.pivot_offset = c.size * 0.5
	# розмір може стати відомим пізніше — тримаємо центр (один конект на контрол)
	if not c.has_meta("pivot_follow"):
		c.set_meta("pivot_follow", true)
		c.resized.connect(func(): c.pivot_offset = c.size * 0.5)
	c.scale = Vector2.ZERO
	var tw := c.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(delay)
	tw.tween_property(c, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Зникнення (в нуль) з видаленням або приховуванням.
static func pop_out(c: Control, free_after: bool = false) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(c, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if free_after:
		tw.finished.connect(c.queue_free)
	else:
		tw.finished.connect(func(): c.visible = false; c.scale = Vector2.ONE)


## Вічне легке погойдування (заголовок, підказка).
static func wobble(c: Control, amount: float = 0.04, period: float = 1.6) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(c, "rotation", amount, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "rotation", -amount, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Дихання масштабом (кнопка «Грати»).
static func pulse(c: Control, amount: float = 0.05, period: float = 1.2) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(c, "scale", Vector2.ONE * (1.0 + amount), period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Трясіння «не можна» (замкнений герой).
static func shake(c: Control) -> void:
	var tw := c.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var x := c.position.x
	for d in [12.0, -12.0, 8.0, -8.0, 0.0]:
		tw.tween_property(c, "position:x", x + d, 0.05)
