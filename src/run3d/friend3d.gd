## Друг-пухнастик: біжить поруч, займає сусідню доріжку із запізненням, стрибає разом, потім тікає вперед.
class_name Friend3D
extends Node3D

var hero: Hero3D
var _puppet: Hero3D
var _target_x := 0.0
var _delay := 0.0
var _leaving := false
var _t := 0.0


func setup(h: Hero3D, color_hex: String, seconds: float, feat: String = "ears") -> void:
	hero = h
	_puppet = Hero3D.new()
	add_child(_puppet)
	_puppet.set_hero("friend", color_hex, feat)
	_puppet.scale = Vector3.ONE * 0.85
	_puppet.set_running(true)
	position = Vector3(hero.position.x + (1.0 if hero.position.x <= 0.0 else -1.0), 0.0, -0.9)
	_target_x = position.x
	hero.landed.connect(_on_hero_landed)
	get_tree().create_timer(seconds).timeout.connect(func(): _leaving = true)


func _on_hero_landed() -> void:
	if is_instance_valid(_puppet) and not _leaving:
		get_tree().create_timer(0.15).timeout.connect(func():
			if is_instance_valid(_puppet):
				_puppet.jump(0.7))


func _process(delta: float) -> void:
	_t += delta
	_delay += delta
	if _delay > 0.3:
		_delay = 0.0
		var side := 1.0 if hero.position.x <= 0.0 else -1.0
		_target_x = clampf(hero.position.x + side, -1.0, 1.0)
	position.x = lerpf(position.x, _target_x, minf(1.0, delta * 8.0))
	if _leaving:
		position.z -= delta * 6.0
		if position.z < -30.0:
			if is_instance_valid(hero) and hero.landed.is_connected(_on_hero_landed):
				hero.landed.disconnect(_on_hero_landed)
			queue_free()
