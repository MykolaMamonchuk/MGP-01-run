## Кнопка суперсили героя (GDD v1.6 §3c) — «Mario-Kart»-віджет знизу праворуч.
## Сірий диск + кільце, що заповнюється кольором героя в міру збирання злитків;
## усередині — намальований гліф сили (свій на кожен id). Заряджена — світиться й пульсує;
## тап — сигнал `pressed`. Поки сила діє, кільце СТІКАЄ назад до нуля, після чого диск тьмяніє.
##
## Віджет нічого не знає про гру: усі числа приходять ззовні (Run3D → HUD → сюди).
##   set_power(id, color) · set_progress(0..1) · set_ready(on) · set_active(0..1) · fire() · reset()
class_name PowerButton
extends Control

## Розмір кнопки (квадрат).
const PX := 120.0
## Товщина кільця у частках радіуса.
const RING_W := 0.18
## Пульсація зарядженої кнопки: від 1,0 до цього й назад, PULSE_HZ разів на секунду.
const PULSE_MAX := 1.08
const PULSE_HZ := 1.4
## Прозорість диска, поки сила ще не набралась.
const DIM_ALPHA := 0.55

signal pressed()

## Гліфи, які вміє малювати кнопка (порядок = порядок героїв у каруселі).
const GLYPHS := ["fox_leap", "deer_charge", "dog_sniff", "bunny_double",
	"cat_lives", "bear_hug", "unicorn_rainbow", "dolphin_wave", "turtle_shield"]

var power_id := ""
var color := Palette.LIME
var progress := 0.0        ## 0..1 — скільки набралось
var ready_on := false      ## заряджена (кільце повне)
var active := -1.0         ## 0..1, поки сила ДІЄ (кільце стікає); < 0 — не діє

var _t := 0.0


func _init(px: float = PX) -> void:
	custom_minimum_size = Vector2(px, px)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


## Чия сила: id гліфа й колір героя.
func set_power(id: String, col: Color) -> void:
	power_id = id
	color = col
	queue_redraw()


## Заповнення кільця, 0..1.
func set_progress(p: float) -> void:
	var v := clampf(p, 0.0, 1.0)
	if is_equal_approx(v, progress):
		return
	progress = v
	queue_redraw()


## Заряджена: світиться, пульсує, приймає тап.
func set_ready(on: bool) -> void:
	if ready_on == on:
		return
	ready_on = on
	if not on:
		scale = Vector2.ONE
	queue_redraw()


## Сила діє: t — скільки її лишилось, 0..1 (кільце стікає). Менше нуля — не діє.
func set_active(t: float) -> void:
	active = t if t >= 0.0 else -1.0
	queue_redraw()


## Спалах на активації (кнопку натиснули або вона спрацювала сама).
func fire() -> void:
	set_ready(false)
	pivot_offset = size * 0.5
	scale = Vector2.ONE
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(self, "scale", Vector2(1.35, 1.35), 0.1)
	tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC)


## Кінець сили: кільце порожнє, диск тьмяніє.
func reset() -> void:
	active = -1.0
	set_ready(false)
	progress = 0.0
	scale = Vector2.ONE
	queue_redraw()


## Малятам кнопка ВИДНА, але не натискається (сила вмикається сама).
func set_interactive(on: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not ready_on or active >= 0.0:
		return
	_t += delta
	var k := 1.0 + (PULSE_MAX - 1.0) * (0.5 + 0.5 * sin(_t * TAU * PULSE_HZ))
	pivot_offset = size * 0.5
	scale = Vector2(k, k)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var tapped := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if not tapped:
		return
	# подію треба з'їсти В БУДЬ-ЯКОМУ разі: інакше тап по кнопці долетить до Run3D._unhandled_input
	# і герой заразом стрибне
	accept_event()
	tap()


## Тап по кнопці (з екрана або з тесту): заряджена — сигнал, ні — тиша.
func tap() -> void:
	if ready_on:
		pressed.emit()


# ---------- малювання ----------

func _draw() -> void:
	var c := size * 0.5
	var r: float = min(size.x, size.y) * 0.46
	var filled := active if active >= 0.0 else progress
	# ореол зарядженої кнопки — під диском, щоб не з'їдати гліф
	if ready_on and active < 0.0:
		draw_circle(c, r * 1.18, Color(Palette.LIME, 0.35))
		draw_arc(c, r * 1.12, 0.0, TAU, 40, Palette.WHITE, r * 0.06)
	# сірий диск (тьмяніший, поки не набралось)
	var disc := Palette.BTN_SETTINGS
	disc.a = 1.0 if (ready_on or active >= 0.0) else DIM_ALPHA
	draw_circle(c, r, disc)
	# кільце: сіра доріжка + дуга кольору героя від «12 годин» за годинниковою
	var rw := r * RING_W
	var rr := r - rw * 0.5
	draw_arc(c, rr, 0.0, TAU, 40, Palette.ICON_EDGE, rw)
	if filled > 0.001:
		draw_arc(c, rr, -PI * 0.5, -PI * 0.5 + TAU * filled, 40, color, rw)
	_draw_glyph(c, r * 0.62)


## Гліф сили: кожен — кілька ліній і полігонів у колі радіуса r навколо точки c.
func _draw_glyph(c: Vector2, r: float) -> void:
	var ink := Palette.WHITE
	var w := r * 0.2
	match power_id:
		"fox_leap":
			# дуга стрибка з лапкою на злеті
			var pts := PackedVector2Array()
			for i in range(13):
				var t := float(i) / 12.0
				pts.append(c + Vector2(lerpf(-r, r, t), r * 0.55 - sin(t * PI) * r * 1.2))
			draw_polyline(pts, ink, w)
			draw_circle(c + Vector2(-r, r * 0.55), w * 0.9, ink)
		"deer_charge":
			# роги: стовбур і по дві гілки з кожного боку
			for s in [-1.0, 1.0]:
				var base := c + Vector2(s * r * 0.3, r * 0.7)
				var top := c + Vector2(s * r * 0.6, -r * 0.9)
				draw_line(base, top, ink, w)
				draw_line(c + Vector2(s * r * 0.42, r * 0.05), c + Vector2(s * r * 1.0, -r * 0.2), ink, w * 0.8)
				draw_line(c + Vector2(s * r * 0.52, -r * 0.45), c + Vector2(s * r * 1.05, -r * 0.7), ink, w * 0.8)
		"dog_sniff":
			# носик: закруглений трикутник і дві ніздрі
			var nose := PackedVector2Array([
				c + Vector2(-r * 0.85, -r * 0.45),
				c + Vector2(r * 0.85, -r * 0.45),
				c + Vector2(0.0, r * 0.85),
			])
			draw_colored_polygon(nose, ink)
			draw_circle(c + Vector2(-r * 0.32, -r * 0.12), r * 0.16, Palette.BTN_SETTINGS)
			draw_circle(c + Vector2(r * 0.32, -r * 0.12), r * 0.16, Palette.BTN_SETTINGS)
		"bunny_double":
			# дві стрілки вгору (другий стрибок)
			for i in range(2):
				var o := c + Vector2(0.0, r * 0.55 - float(i) * r * 0.75)
				draw_colored_polygon(PackedVector2Array([
					o + Vector2(0.0, -r * 0.5),
					o + Vector2(-r * 0.6, r * 0.2),
					o + Vector2(r * 0.6, r * 0.2),
				]), ink)
		"cat_lives":
			# два сердечка — «ще одне життя»
			_heart(c + Vector2(-r * 0.38, r * 0.05), r * 0.55, ink)
			_heart(c + Vector2(r * 0.38, -r * 0.15), r * 0.55, ink)
		"bear_hug":
			# обійми: дві дуги-лапи назустріч
			draw_arc(c + Vector2(-r * 0.35, 0.0), r * 0.8, -PI * 0.45, PI * 0.45, 20, ink, w)
			draw_arc(c + Vector2(r * 0.35, 0.0), r * 0.8, PI * 0.55, PI * 1.45, 20, ink, w)
		"unicorn_rainbow":
			# веселка: концентричні дуги кольорами палітри
			var n: int = Palette.RAINBOW.size()
			for i in range(n):
				var rad := r * (1.0 - float(i) * 0.13)
				draw_arc(c + Vector2(0.0, r * 0.5), rad, PI, TAU, 24, Palette.RAINBOW[i], r * 0.13)
		"dolphin_wave":
			# хвиля: дві дуги-гребені одна над одною
			draw_arc(c + Vector2(0.0, r * 0.15), r * 0.8, PI * 1.15, PI * 1.85, 20, ink, w)
			draw_arc(c + Vector2(0.0, -r * 0.45), r * 0.55, PI * 1.15, PI * 1.85, 20, ink, w * 0.8)
		"turtle_shield":
			# панцир: шестикутник із перетинками, як черепаховий щит
			var pts := PackedVector2Array()
			for i in range(6):
				var a := -PI * 0.5 + float(i) * TAU / 6.0
				pts.append(c + Vector2(cos(a), sin(a)) * r * 0.85)
			draw_colored_polygon(pts, ink)
			for i in range(6):
				draw_line(c, pts[i], Palette.BTN_SETTINGS, w * 0.5)
		_:
			# невідома сила — просто зірочка-крапка, щоб кнопка не була порожня
			draw_circle(c, r * 0.4, ink)


## Сердечко: два кола й трикутник (та сама форма, що й у HeartIcon).
func _heart(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c + Vector2(-r * 0.4, -r * 0.3), r * 0.45, col)
	draw_circle(c + Vector2(r * 0.4, -r * 0.3), r * 0.45, col)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.82, -r * 0.15),
		c + Vector2(r * 0.82, -r * 0.15),
		c + Vector2(0.0, r * 0.85),
	]), col)
