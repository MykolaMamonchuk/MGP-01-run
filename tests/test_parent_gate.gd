## Перевіряє чисту функцію ParentGate.make_question().
extends GutTest


func test_options_are_four_unique_positive_ints() -> void:
	var q := ParentGate.make_question(42)
	var options: Array = q["options"]
	assert_eq(options.size(), 4, "має бути 4 варіанти")
	var unique := {}
	for opt in options:
		assert_true(opt > 0, "варіант має бути додатним: %s" % opt)
		unique[opt] = true
	assert_eq(unique.size(), 4, "усі варіанти унікальні")


func test_options_contain_answer() -> void:
	var q := ParentGate.make_question(42)
	var options: Array = q["options"]
	assert_true(options.has(q["answer"]), "варіанти містять правильну відповідь")


func test_answer_matches_text() -> void:
	var q := ParentGate.make_question(7)
	var parts := String(q["text"]).replace("?", "").replace("=", "+").split("+")
	assert_eq(parts.size(), 3, "текст має вигляд 'a + b = ?'")
	var a := int(parts[0].strip_edges())
	var b := int(parts[1].strip_edges())
	assert_eq(q["answer"], a + b, "answer == a + b з тексту питання")


func test_same_seed_gives_same_question() -> void:
	var q1 := ParentGate.make_question(123)
	var q2 := ParentGate.make_question(123)
	assert_eq(q1["text"], q2["text"], "однаковий сід — однаковий текст")
	assert_eq(q1["answer"], q2["answer"], "однаковий сід — однакова відповідь")
	assert_eq(q1["options"], q2["options"], "однаковий сід — однакові варіанти")
