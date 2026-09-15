extends Node3D

@onready var eye: CartoonEye3D = $CartoonEye3D

func _ready() -> void:
	await get_tree().create_timer(0.8).timeout

	while true:
		eye.look_at_offset(Vector2(-0.8, 0.2))
		await get_tree().create_timer(0.8).timeout

		eye.look_at_offset(Vector2(0.8, 0.2))
		await get_tree().create_timer(0.8).timeout

		eye.look_at_offset(Vector2.ZERO)
		await get_tree().create_timer(0.6).timeout

		eye.blink()
		await get_tree().create_timer(0.7).timeout
