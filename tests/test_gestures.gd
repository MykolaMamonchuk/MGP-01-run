## Жести одного пальця: тап / утримання / свайп — чисті функції Gestures.
extends GutTest


func test_short_release_is_tap() -> void:
	assert_eq(Gestures.on_release(0.1, false), "tap")


func test_long_release_without_swipe_is_hold_end() -> void:
	assert_eq(Gestures.on_release(0.6, false), "hold_end")


func test_release_after_swipe_is_nothing() -> void:
	assert_eq(Gestures.on_release(0.1, true), "", "свайп уже спрацював — на відпусканні нічого")


func test_small_move_is_not_swipe() -> void:
	assert_eq(Gestures.swipe_dir(Vector2(100, 100), Vector2(130, 110)), "", "тремтіння пальця — не свайп")


func test_swipe_directions() -> void:
	var s := Vector2(300, 300)
	assert_eq(Gestures.swipe_dir(s, s + Vector2(120, 10)), "swipe_right")
	assert_eq(Gestures.swipe_dir(s, s + Vector2(-120, 10)), "swipe_left")
	assert_eq(Gestures.swipe_dir(s, s + Vector2(10, -120)), "swipe_up")
	assert_eq(Gestures.swipe_dir(s, s + Vector2(10, 120)), "swipe_down")


func test_hold_starts_only_after_tap_window_and_once() -> void:
	assert_false(Gestures.hold_started(0.1, false, false), "ще тап")
	assert_true(Gestures.hold_started(0.3, false, false), "довше за тап — утримання")
	assert_false(Gestures.hold_started(0.3, true, false), "після свайпу утримання не починається")
	assert_false(Gestures.hold_started(0.9, false, true), "уже тримаємо — не повторюємо")


func test_steer_side_by_screen_half() -> void:
	assert_eq(Gestures.steer_side(Vector2(100, 400), 1280.0), -1)
	assert_eq(Gestures.steer_side(Vector2(1000, 400), 1280.0), 1)
