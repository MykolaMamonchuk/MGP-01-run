## Герой-пухнастик (заглушка: кульки з очима, малюється кодом). Без смерті: зіткнення = перекид.
extends CharacterBody2D
class_name Hero

signal landed

@export var jump_velocity := -760.0
@export var gravity := 1800.0
@export var body_color := Color("#FFB84D")

var is_tumbling := false
var is_ducking := false
var _tumble_t := 0.0
var _was_on_floor := true
var _squash := 1.0

@onready var body: Node2D = $Body
@onready var shape: CollisionShape2D = $CollisionShape2D

const H_STAND := 110.0
const H_DUCK := 60.0

func _ready() -> void:
	body.draw.connect(_draw_body)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	move_and_slide()
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_squash = 0.75
		landed.emit()
	_was_on_floor = on_floor
	_squash = lerp(_squash, 1.0, 10.0 * delta)

	if is_tumbling:
		_tumble_t -= delta
		body.rotation += delta * 14.0
		if _tumble_t <= 0.0:
			is_tumbling = false
			body.rotation = 0.0
	else:
		body.rotation = lerp(body.rotation, 0.0, 12.0 * delta)

	var target_h := H_DUCK if is_ducking else H_STAND
	var rect := shape.shape as RectangleShape2D
	# пишемо у форму лише коли висота реально змінилася (форма локальна для сцени)
	if rect and not is_equal_approx(rect.size.y, target_h):
		rect.size.y = target_h
		shape.position.y = -target_h / 2.0
		body.position.y = -target_h / 2.0
	body.scale = Vector2(1.0 / _squash, _squash) * (Vector2(1.2, 0.55) if is_ducking else Vector2.ONE)
	body.queue_redraw()

func jump() -> void:
	if is_on_floor() and not is_ducking and not is_tumbling:
		velocity.y = jump_velocity
		_squash = 1.2

func set_duck(on: bool) -> void:
	is_ducking = on and is_on_floor()

func tumble() -> void:
	if is_tumbling:
		return
	is_tumbling = true
	_tumble_t = 0.8
	set_duck(false)

func _draw_body() -> void:
	# тіло
	body.draw_circle(Vector2.ZERO, 52.0, body_color.darkened(0.25))
	body.draw_circle(Vector2.ZERO, 46.0, body_color)
	# вушка
	body.draw_circle(Vector2(-30, -40), 16.0, body_color)
	body.draw_circle(Vector2(30, -40), 16.0, body_color)
	# очі
	body.draw_circle(Vector2(-16, -8), 11.0, Color.WHITE)
	body.draw_circle(Vector2(16, -8), 11.0, Color.WHITE)
	var look := Vector2(3, 2) if velocity.y >= 0 else Vector2(3, -3)
	body.draw_circle(Vector2(-16, -8) + look, 6.0, Color("#3E2723"))
	body.draw_circle(Vector2(16, -8) + look, 6.0, Color("#3E2723"))
	# усмішка
	body.draw_arc(Vector2(0, 8), 14.0, 0.3, PI - 0.3, 12, Color("#3E2723"), 4.0)
