extends Node3D

@onready var mouth: CartoonMouth3DIntegrated = $CartoonMouth3DIntegrated

func _ready() -> void:
	await get_tree().create_timer(0.8).timeout

	while true:
		mouth.open()
		await get_tree().create_timer(0.45).timeout

		mouth.close()
		await get_tree().create_timer(0.45).timeout

		mouth.bite()
		await get_tree().create_timer(0.65).timeout

		mouth.chew(3)
		await get_tree().create_timer(1.2).timeout

		mouth.lick()
		await get_tree().create_timer(0.85).timeout

		mouth.smile()
		await get_tree().create_timer(1.0).timeout

		mouth.neutral()
		await get_tree().create_timer(1.0).timeout
