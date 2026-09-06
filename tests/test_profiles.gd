## Перевіряє data/profiles.json через AgeAdapt.load_profiles().
extends GutTest

const VALID_OBSTACLES := ["stump", "branch", "puddle"]
const AGE_KEYS := ["young", "mid", "older"]

var _profiles: Dictionary


func before_each() -> void:
	_profiles = AgeAdapt.load_profiles()


func test_has_all_required_keys() -> void:
	assert_true(_profiles.has("young"), "має бути профіль young")
	assert_true(_profiles.has("mid"), "має бути профіль mid")
	assert_true(_profiles.has("older"), "має бути профіль older")
	assert_true(_profiles.has("age_adapt"), "має бути секція age_adapt")


func test_each_profile_shape() -> void:
	for key in AGE_KEYS:
		var p: Dictionary = _profiles.get(key, {})
		assert_true(p.has("speed"), "%s: має бути speed" % key)
		assert_true(typeof(p.get("speed")) in [TYPE_INT, TYPE_FLOAT], "%s: speed — число" % key)

		assert_true(p.has("jump_velocity"), "%s: має бути jump_velocity" % key)
		assert_true(typeof(p.get("jump_velocity")) in [TYPE_INT, TYPE_FLOAT], "%s: jump_velocity — число" % key)

		var interval = p.get("obstacle_interval", [])
		assert_true(typeof(interval) == TYPE_ARRAY and interval.size() == 2,
			"%s: obstacle_interval — масив із 2 чисел" % key)
		if typeof(interval) == TYPE_ARRAY and interval.size() == 2:
			assert_lt(float(interval[0]), float(interval[1]), "%s: min < max в obstacle_interval" % key)

		var types = p.get("obstacle_types", [])
		assert_true(typeof(types) == TYPE_ARRAY and types.size() > 0,
			"%s: obstacle_types не порожній" % key)
		if typeof(types) == TYPE_ARRAY:
			for t in types:
				assert_true(VALID_OBSTACLES.has(t), "%s: невідомий тип перешкоди %s" % [key, t])

		var assist = p.get("auto_assist_chance", -1)
		assert_true(typeof(assist) in [TYPE_INT, TYPE_FLOAT], "%s: auto_assist_chance — число" % key)
		assert_between(float(assist), 0.0, 1.0, "%s: auto_assist_chance в [0,1]" % key)

		var magnet = p.get("star_magnet", 0)
		assert_true(typeof(magnet) in [TYPE_INT, TYPE_FLOAT], "%s: star_magnet — число" % key)
		assert_gte(float(magnet), 1.0, "%s: star_magnet >= 1" % key)

		var minutes = p.get("session_minutes", 0)
		assert_true(typeof(minutes) in [TYPE_INT, TYPE_FLOAT], "%s: session_minutes — число" % key)
		assert_gt(float(minutes), 0.0, "%s: session_minutes > 0" % key)


func test_speed_increases_with_age() -> void:
	var young_speed := float(_profiles["young"]["speed"])
	var mid_speed := float(_profiles["mid"]["speed"])
	var older_speed := float(_profiles["older"]["speed"])
	assert_lt(young_speed, mid_speed, "young < mid за швидкістю")
	assert_lt(mid_speed, older_speed, "mid < older за швидкістю")
