## Реклама: ТІЛЬКИ rewarded video, ТІЛЬКИ COPPA-сертифіковані мережі (рішення №10).
## Це заглушка-інтерфейс. Реальний SDK підключається у вертикальному зрізі (Android), у веб-білді вимкнено.
## Autoload: Ads.
extends Node

const DAILY_LIMIT := 3

signal rewarded_finished(placement: String, success: bool)

func is_available() -> bool:
	if Purchase.is_full_game():
		return false
	return false  # заглушка: SDK не підключено

func views_today() -> int:
	var d := SaveService.data.get("ads", {})
	if d.get("day", "") != Time.get_date_string_from_system():
		return 0
	return int(d.get("views", 0))

func can_show() -> bool:
	return is_available() and views_today() < DAILY_LIMIT

## Показ rewarded. Батьківський бар'єр вбудований — окремо викликати ParentGate не треба.
func show_rewarded(placement: String) -> void:
	if not can_show():
		rewarded_finished.emit(placement, false)
		return
	ParentGate.request("settings", _do_show.bind(placement))

func _do_show(placement: String) -> void:
	_record_view()
	# SDK-заглушка: реального показу ще немає, тому success = false.
	rewarded_finished.emit(placement, false)

func _record_view() -> void:
	var today := Time.get_date_string_from_system()
	var d: Dictionary = SaveService.data.get("ads", {})
	if d.get("day", "") != today:
		d = {"day": today, "views": 0}
	d["views"] = int(d["views"]) + 1
	SaveService.data["ads"] = d
	SaveService.save_game()
