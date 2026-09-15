## Візуальний джойстик під пальцем: кільце з мітками і кружечок-ручка.
## Лише картинка — логіку відхилення тримає той, хто його показує.
class_name StickView
extends Control

const RING := Color(1, 1, 1, 0.18)
const RING_EDGE := Color(1, 1, 1, 0.55)
const RING_MARK := Color(1, 1, 1, 0.5)

var offset := Vector2.ZERO
var radius := 78.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(radius * 2.6, radius * 2.6)
	pivot_offset = size * 0.5
	visible = false


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, radius, RING)
	draw_arc(c, radius, 0.0, TAU, 48, RING_EDGE, 6.0, true)
	# чотири мітки-напрямки
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		var p := c + Vector2(cos(a), sin(a)) * (radius - 14.0)
		draw_circle(p, 6.0, RING_MARK)
	var knob := c + offset.limit_length(radius * 0.8)
	draw_circle(knob, 30.0, Palette.STICK)
	draw_circle(knob, 22.0, Palette.STICK_KNOB)
