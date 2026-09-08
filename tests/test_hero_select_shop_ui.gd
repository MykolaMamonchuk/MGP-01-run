## Жива крамниця в каруселі героїв: сцена будується, стрічка предметів працює
## на кожній вкладці й переживає зміну героя. Тут колись падало «_strip == null» на старті.
extends GutTest

var _scene: Node
var _hs: HeroSelect


func before_each() -> void:
	_scene = load("res://src/run3d/run3d.tscn").instantiate()
	add_child(_scene)
	await wait_process_frames(10)
	_hs = _scene.get_node("HeroSelect") as HeroSelect


func after_each() -> void:
	_scene.free()
	_scene = null
	_hs = null


func test_carousel_is_not_built_until_opened() -> void:
	# важку карусель (6 звірят із подіумами; пуфи — legacy) не будуємо на старті гри — OPT-04
	assert_not_null(_hs, "HeroSelect у сцені")
	assert_eq(_hs.get_child_count(), 0, "до відкриття карусель не займає нічого")
	assert_eq(_hs.ids.size(), 6, "але список героїв уже прочитано — він потрібен геймплею")
	assert_null(_hs._strip, "UI крамниці теж чекає на перше відкриття")


func test_opening_builds_carousel_once() -> void:
	_hs.open(null, "lys")
	await wait_process_frames(4)
	assert_eq(_hs._previews.size(), 6, "усі герої на місці")
	assert_not_null(_hs._strip, "стрічка предметів зібралася разом із UI")
	assert_true(_hs._strip.fits(), "порожня стрічка вміщується")
	var children := _hs.get_child_count()
	_hs.close()
	await wait_process_frames(2)
	_hs.open(null, "lys")
	await wait_process_frames(2)
	assert_eq(_hs.get_child_count(), children, "друге відкриття не будує карусель наново")
	assert_eq(_hs._previews.size(), 6)


func test_shop_fills_strip_for_every_slot() -> void:
	_hs.open(null, "puf")
	await wait_process_frames(4)
	_hs._toggle_shop()
	await wait_process_frames(4)
	for slot in Shop.SLOTS:
		_hs._select_slot(String(slot))
		await wait_process_frames(2)
		assert_gt(_hs._strip.cards().size(), 0, "вкладка «%s»: у стрічці є предмети" % slot)


func test_switching_hero_keeps_strip_alive() -> void:
	_hs.open(null, "puf")
	await wait_process_frames(4)
	_hs._toggle_shop()
	await wait_process_frames(4)
	var before := _hs._strip.cards().size()
	_hs.move(1)
	await wait_process_frames(6)
	assert_eq(_hs._strip.cards().size(), before, "стрічка перебудувалась під нового героя, а не подвоїлась")
	_hs.close()
	await wait_process_frames(2)
