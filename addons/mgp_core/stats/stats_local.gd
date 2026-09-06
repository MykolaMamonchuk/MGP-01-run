## Анонімні локальні лічильники для екрану батьків. Нікуди не відправляються.
## Autoload: Stats.
extends Node

var counters: Dictionary = {}

func _ready() -> void:
	counters = SaveService.data.get("stats", {})
	Events.star_collected.connect(func(n): inc("stars", n))
	Events.hero_tumbled.connect(func(_k): inc("tumbles"))
	Events.obstacle_passed.connect(func(_k): inc("obstacles_passed"))
	Events.session_finished.connect(func(): inc("sessions_finished_by_sleep"))

func inc(key: String, n: int = 1) -> void:
	counters[key] = int(counters.get(key, 0)) + n
	SaveService.data["stats"] = counters

func get_value(key: String) -> int:
	return int(counters.get(key, 0))

func flush() -> void:
	SaveService.data["stats"] = counters
	SaveService.save_game()
