## Зірочка. Магнітиться до героя (star_magnet), збирається на дотик.
extends Area2D
class_name Star

var speed := 400.0
var magnet := 1.0
var _hero: Node2D
var _t := 0.0

func setup(spd: float, mag: float, hero: Node2D) -> void:
	speed = spd
	magnet = mag
	_hero = hero
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 34.0
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_t += delta
	global_position.x -= speed * delta
	if _hero and magnet > 1.0:
		var d := _hero.global_position + Vector2(0, -55) - global_position
		if d.length() < 140.0 * magnet:
			global_position += d.normalized() * 600.0 * delta
	rotation = sin(_t * 4.0) * 0.2
	if global_position.x < -100:
		queue_free()
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body is Hero:
		Events.star_collected.emit(1)
		AudioMgr.sfx("star", randf_range(0.9, 1.2))
		queue_free()

func _draw() -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var r := 30.0 if i % 2 == 0 else 13.0
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, Color("#FFD54F"))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#F9A825"), 3.0)
