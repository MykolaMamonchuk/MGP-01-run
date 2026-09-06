## Перешкода. Рухається вліво. Зіткнення з героєм: tumble або бризки (без шкоди).
extends Area2D
class_name Obstacle

var kind := "stump"
var speed := 400.0
var tumble := true
var size := Vector2(90, 70)
var color := Color("#8D6E63")
var auto_assist := false
var hero_x := 340.0
var _hit := false
var _passed := false

func setup(k: String, cfg: Dictionary, spd: float, assist: bool, hero_pos_x: float = 340.0) -> void:
	kind = k
	speed = spd
	auto_assist = assist
	hero_x = hero_pos_x
	size = Vector2(float(cfg["w"]), float(cfg["h"]))
	color = Color(String(cfg["color"]))
	tumble = bool(cfg.get("tumble", true))
	position.y += float(cfg.get("y_off", 0))
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size * Vector2(0.8, 0.9)
	cs.shape = rs
	cs.position = Vector2(0, -size.y / 2.0)
	add_child(cs)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _process(delta: float) -> void:
	position.x -= speed * delta
	if not _passed and global_position.x < hero_x - size.x:
		_passed = true
		# перешкода вважається пройденою завжди — навіть якщо було зіткнення
		Events.obstacle_passed.emit(kind)
	if position.x < -300:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if _hit or not (body is Hero):
		return
	_hit = true
	if tumble:
		body.tumble()
		Events.hero_tumbled.emit(kind)
		AudioMgr.sfx("tumble")
	else:
		AudioMgr.sfx("splash")
		modulate = Color(1, 1, 1, 0.6)

func _draw() -> void:
	var r := Rect2(Vector2(-size.x / 2.0, -size.y), size)
	draw_rect(r, color.darkened(0.2))
	draw_rect(r.grow(-6), color)
