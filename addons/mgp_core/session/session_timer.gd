## Таймер сесії, вбудований у сюжет: за 2 хв — герой зіває, за 1 хв — «ще трошки і спатки», 0 — сон.
## Autoload: SessionTimer.
extends Node

var total_seconds: float = 600.0
var left: float = 600.0
var running: bool = false
var _warned_120 := false
var _warned_60 := false

func start(minutes: float) -> void:
	total_seconds = minutes * 60.0
	left = total_seconds
	running = true
	_warned_120 = false
	_warned_60 = false

func stop() -> void:
	running = false

func _process(delta: float) -> void:
	if running:
		tick(delta)

## Виділено для тестів.
func tick(delta: float) -> void:
	if not running:
		return
	left -= delta
	if not _warned_120 and left <= 120.0:
		_warned_120 = true
		# для дуже коротких сесій попередження «за 2 хв» не має сенсу — лишається тільки «за 1 хв»
		if left > 60.0:
			Events.session_warning.emit(120)
	if not _warned_60 and left <= 60.0:
		_warned_60 = true
		Events.session_warning.emit(60)
	if left <= 0.0:
		running = false
		Events.session_finished.emit()
