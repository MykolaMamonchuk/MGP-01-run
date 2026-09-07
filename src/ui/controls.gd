## Керування для малят: великі кнопки-стрілки (знизу) і візуальний джойстик під пальцем.
## Стрілки шлють ті самі жести, що й свайпи: swipe_left/right/up, hold_start/hold_end.
## Джойстик — лише картинка: логіка «відхилив — дія, повернув — знову можна» живе в Run3D.
class_name ControlsLayer
extends CanvasLayer

signal action(kind: String)

const BTN := 118.0

var _root: Control
var _arrows: Control
var _stick: StickView
var _hint: Label


class StickView:
	extends Control
	var offset := Vector2.ZERO
	var radius := 78.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(radius * 2.6, radius * 2.6)
		pivot_offset = size * 0.5
		visible = false
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, radius, Color(1, 1, 1, 0.18))
		draw_arc(c, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 6.0, true)
		# чотири мітки-напрямки
		for a in [0.0, PI * 0.5, PI, PI * 1.5]:
			var p := c + Vector2(cos(a), sin(a)) * (radius - 14.0)
			draw_circle(p, 6.0, Color(1, 1, 1, 0.5))
		var knob := c + offset.limit_length(radius * 0.8)
		draw_circle(knob, 30.0, Color(1, 1, 1, 0.9))
		draw_circle(knob, 22.0, Color("#FFB84D"))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 4
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_arrows = Control.new()
	_arrows.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_arrows.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_arrows.offset_left = 28
	_arrows.offset_top = -(BTN * 2 + 40)
	_arrows.offset_right = 28 + BTN * 3 + 24
	_arrows.offset_bottom = -28
	_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_arrows)
	var c := Color("#42A5F5")
	_arrow("↑", c, Vector2(BTN + 12, 0), "swipe_up")
	_arrow("←", c, Vector2(0, BTN + 12), "swipe_left")
	_arrow("↓", c, Vector2(BTN + 12, BTN + 12), "swipe_down", true)
	_arrow("→", c, Vector2(BTN * 2 + 24, BTN + 12), "swipe_right")
	_arrows.visible = false

	_stick = StickView.new()
	_root.add_child(_stick)


func _arrow(text: String, color: Color, pos: Vector2, kind: String, hold: bool = false) -> void:
	var b := UIKit.button(text, color, Vector2(BTN, BTN), 60)
	b.position = pos
	if hold:
		# ↓ — тримаєш, поки хочеш присідати
		b.button_down.connect(func(): action.emit("hold_start"))
		b.button_up.connect(func(): action.emit("hold_end"))
	else:
		b.pressed.connect(func(): action.emit(kind))
	_arrows.add_child(b)


func set_arrows_visible(on: bool) -> void:
	_arrows.visible = on


func stick_show(pos: Vector2) -> void:
	_stick.position = pos - _stick.size * 0.5
	_stick.offset = Vector2.ZERO
	_stick.visible = true
	_stick.queue_redraw()


func stick_update(offset: Vector2) -> void:
	_stick.offset = offset
	_stick.queue_redraw()


func stick_hide() -> void:
	_stick.visible = false
