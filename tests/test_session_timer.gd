## Перевіряє addons/mgp_core/session/session_timer.gd через сигнали шини Events.
extends GutTest

var _timer: Node


func before_each() -> void:
	_timer = load("res://addons/mgp_core/session/session_timer.gd").new()
	add_child_autofree(_timer)
	# у тестах час рухаємо вручну через tick(): вимикаємо власний _process таймера
	_timer.set_process(false)
	watch_signals(Events)


func test_short_session_warns_once_and_finishes() -> void:
	_timer.start(0.05) # 0.05 хв = 3 с
	_timer.tick(1.0)
	_timer.tick(1.0)
	_timer.tick(1.0)
	_timer.tick(1.0)

	# сесія коротша за 2 хв: попередження «за 2 хв» пропускається, лишається лише «за 1 хв»
	assert_signal_emitted_with_parameters(Events, "session_warning", [60], 0)
	assert_signal_emitted(Events, "session_finished")
	assert_false(_timer.running, "таймер має зупинитися після завершення")


func test_full_session_warns_at_120_then_60() -> void:
	_timer.start(10.0) # 10 хв = 600 с
	_timer.tick(479.0) # лишилось 121 с — ще без попереджень
	_timer.tick(1.5)   # лишилось 119.5 с — попередження «за 2 хв»
	_timer.tick(60.0)  # лишилось 59.5 с — попередження «за 1 хв»

	assert_signal_emitted_with_parameters(Events, "session_warning", [120], 0)
	assert_signal_emitted_with_parameters(Events, "session_warning", [60], 1)
	assert_true(_timer.running, "сесія ще триває")
