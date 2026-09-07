## Самокат (Місто-парк): як Біг, але швидше, герой на самокаті, трампліни дають довгий політ, рейки — бонус.
class_name ScooterMode
extends RunMode


func mode_id() -> String:
	return "scooter"


func enter() -> void:
	hero.set_vehicle(true, "scooter")
	hero.set_duck(false)


func exit() -> void:
	hero.set_duck(false)
	hero.set_vehicle(false)


func tick(delta: float) -> float:
	# самокат на 15% швидший за біг того ж профілю (GDD §3)
	return speed * float(world.get("speed_factor", 1.15)) * delta


func assist_distance() -> float:
	return speed * float(world.get("speed_factor", 1.15)) * 0.45
