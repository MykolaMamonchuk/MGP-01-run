## Перевіряє чисту функцію AgeAdapt.decide().
extends GutTest

var _rules: Dictionary


func before_each() -> void:
	_rules = {
		"min_obstacles": 8,
		"down_collision_rate": 0.4,
		"down_reaction_ms": 900,
		"up_collision_rate": 0.1,
		"up_reaction_ms": 450,
	}


func test_too_few_obstacles_keeps_profile() -> void:
	var result := AgeAdapt.decide("mid", 3, 3, 2000.0, _rules)
	assert_eq(result, "mid", "замало перешкод — профіль не змінюється")


func test_mid_struggles_goes_down_to_young() -> void:
	var result := AgeAdapt.decide("mid", 10, 6, 1200.0, _rules)
	assert_eq(result, "young", "багато зіткнень і повільна реакція — знижуємо до young")


func test_mid_excels_goes_up_to_older() -> void:
	var result := AgeAdapt.decide("mid", 10, 0, 300.0, _rules)
	assert_eq(result, "older", "мало зіткнень і швидка реакція — підвищуємо до older")


func test_young_cannot_go_below_young() -> void:
	var result := AgeAdapt.decide("young", 10, 8, 1500.0, _rules)
	assert_eq(result, "young", "young — нижня межа, нижче не буває")


func test_older_cannot_go_above_older() -> void:
	var result := AgeAdapt.decide("older", 10, 0, 200.0, _rules)
	assert_eq(result, "older", "older — верхня межа, вище не буває")


func test_middle_values_keep_profile() -> void:
	var result := AgeAdapt.decide("mid", 10, 2, 600.0, _rules)
	assert_eq(result, "mid", "середні показники — профіль не змінюється")
