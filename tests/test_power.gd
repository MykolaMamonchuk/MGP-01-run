## Суперсили героїв (GDD v1.6 §3c): чиста математика заряду, дані heroes.json/profiles.json
## і кнопка PowerButton у дереві. Гру не запускаємо — лише чисті функції й віджет.
extends GutTest

const RunScript := preload("res://src/run3d/run3d.gd")

## Рівно ці дев'ять id знає і кнопка (PowerButton.GLYPHS), і Run3D.activate_power().
const POWER_IDS := ["fox_leap", "deer_charge", "dog_sniff", "bunny_double",
	"cat_lives", "bear_hug", "unicorn_rainbow", "dolphin_wave", "turtle_shield"]
const DURATION_MIN := 4.0
const DURATION_MAX := 8.0
const CHARGE_MIN := 60
const CHARGE_MAX := 150
const AGE_KEYS := ["young", "mid", "older"]


var _all: Dictionary = {}       ## увесь heroes.json
var _animals: Dictionary = {}   ## лише звірята з каруселі (без legacy й службових ключів)


func before_all() -> void:
	var f := FileAccess.open("res://data/heroes.json", FileAccess.READ)
	assert_not_null(f, "data/heroes.json читається")
	var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
	_all = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	_animals = {}
	for k in _all.keys():
		var key := String(k)
		if key.begins_with("_") or key == "growth":
			continue
		var def = _all[k]
		if typeof(def) == TYPE_DICTIONARY and not Hero3D.is_legacy(def):
			_animals[key] = def


# ---------- чисті функції Rules ----------

func test_charge_needed_prefers_profile() -> void:
	assert_eq(Rules.power_charge_needed(60, 100), 60, "профіль головніший за дані героя")
	assert_eq(Rules.power_charge_needed(0, 100), 100, "нема в профілі — беремо з героя")
	assert_eq(Rules.power_charge_needed(-5, 120), 120, "від'ємне в профілі — теж «нема»")
	assert_eq(Rules.power_charge_needed(0, 0), Rules.POWER_CHARGE_DEFAULT, "нема ніде — запасне")


func test_progress_is_clamped_and_safe() -> void:
	assert_eq(Rules.power_progress(0, 100), 0.0)
	assert_almost_eq(Rules.power_progress(30, 100), 0.3, 0.001)
	assert_eq(Rules.power_progress(100, 100), 1.0)
	assert_eq(Rules.power_progress(250, 100), 1.0, "більше за потрібне — все одно 1")
	assert_eq(Rules.power_progress(-10, 100), 0.0, "від'ємний заряд не буває")
	assert_eq(Rules.power_progress(5, 0), 1.0, "нуль у знаменнику не ронить гру")


func test_progress_grows_monotonically() -> void:
	var prev := -1.0
	for c in [0, 10, 25, 50, 99, 100]:
		var p := Rules.power_progress(int(c), 100)
		assert_gte(p, prev, "заряд росте — кільце не відкочується")
		prev = p


# ---------- дані героїв ----------

func test_every_animal_hero_has_a_power() -> void:
	assert_gt(_animals.size(), 6, "у каруселі семеро звірят")
	for id in _animals.keys():
		var p = (_animals[id] as Dictionary).get("power", null)
		assert_true(typeof(p) == TYPE_DICTIONARY, "%s: має бути словник power" % id)


func test_power_fields_are_in_range() -> void:
	for id in _animals.keys():
		var p: Dictionary = (_animals[id] as Dictionary).get("power", {})
		var pid := String(p.get("id", ""))
		assert_has(POWER_IDS, pid, "%s: невідомий id сили «%s»" % [id, pid])
		var dur := float(p.get("duration", 0.0))
		assert_between(dur, DURATION_MIN, DURATION_MAX, "%s: тривалість сили" % id)
		var charge := int(p.get("charge", 0))
		assert_between(charge, CHARGE_MIN, CHARGE_MAX, "%s: заряд сили" % id)
		assert_ne(String(p.get("name_uk", "")), "", "%s: сила без назви українською" % id)
		assert_eq(String(p.get("voice", "")), "power_%s" % pid, "%s: рядок озвучки за id" % id)


func test_powers_are_unique() -> void:
	var seen := {}
	for id in _animals.keys():
		var pid := String(((_animals[id] as Dictionary).get("power", {}) as Dictionary).get("id", ""))
		assert_false(seen.has(pid), "сила «%s» повторюється у двох героїв" % pid)
		seen[pid] = id
	assert_eq(seen.size(), POWER_IDS.size(), "кожна сила зі списку комусь дісталась")


func test_legacy_heroes_have_no_power() -> void:
	for k in _all.keys():
		var def = _all[k]
		if typeof(def) == TYPE_DICTIONARY and Hero3D.is_legacy(def):
			assert_false((def as Dictionary).has("power"), "старому пухнастику %s сила не потрібна" % k)


# ---------- профілі ----------

func test_young_charges_faster_and_fires_itself() -> void:
	var p := AgeAdapt.load_profiles()
	assert_eq(int((p["young"] as Dictionary).get("power_charge", 0)), 60, "малятам потрібно 60 злитків")
	assert_true(bool((p["young"] as Dictionary).get("power_auto", false)), "малятам сила вмикається сама")
	for key in ["mid", "older"]:
		assert_false(bool((p[key] as Dictionary).get("power_auto", true)), "%s: силу вмикає дитина" % key)
		assert_eq(int((p[key] as Dictionary).get("power_charge", 0)), 0,
			"%s: свого заряду в профілі нема — береться з героя" % key)


func test_young_needs_less_than_heroes_default() -> void:
	var p := AgeAdapt.load_profiles()
	for key in AGE_KEYS:
		var needed := Rules.power_charge_needed(int((p[key] as Dictionary).get("power_charge", 0)), 100)
		assert_between(needed, CHARGE_MIN, CHARGE_MAX, "%s: заряд у розумних межах" % key)
	var young := Rules.power_charge_needed(int((p["young"] as Dictionary).get("power_charge", 0)), 100)
	var older := Rules.power_charge_needed(int((p["older"] as Dictionary).get("power_charge", 0)), 100)
	assert_lt(young, older, "малятам сила має спрацьовувати частіше")


# ---------- кнопка ----------

func test_button_knows_every_power() -> void:
	for pid in POWER_IDS:
		assert_has(PowerButton.GLYPHS, pid, "кнопка не вміє малювати «%s»" % pid)
	assert_eq(PowerButton.GLYPHS.size(), POWER_IDS.size(), "зайвих гліфів теж нема")


func test_button_builds_and_draws_every_glyph() -> void:
	for pid in POWER_IDS:
		var b := PowerButton.new()
		add_child_autofree(b)
		b.set_power(pid, Palette.LIME)
		b.set_progress(0.5)
		b.queue_redraw()
		assert_eq(b.power_id, pid)
		assert_almost_eq(b.progress, 0.5, 0.001)
		assert_eq(b.size, Vector2(PowerButton.PX, PowerButton.PX), "кнопка квадратна 120×120")


func test_button_states() -> void:
	var b := PowerButton.new()
	add_child_autofree(b)
	b.set_power("cat_lives", Palette.LIME)
	assert_false(b.ready_on, "нова кнопка не заряджена")
	b.set_progress(2.0)
	assert_eq(b.progress, 1.0, "заповнення затиснуте до 1")
	b.set_ready(true)
	assert_true(b.ready_on)
	b.fire()
	assert_false(b.ready_on, "спрацювала — більше не світиться")
	b.set_active(0.5)
	assert_almost_eq(b.active, 0.5, 0.001)
	b.reset()
	assert_lt(b.active, 0.0, "сила скінчилась — кільце не в режимі стікання")
	assert_eq(b.progress, 0.0, "після сили заряд збирається наново")


func test_button_emits_only_when_ready() -> void:
	var b := PowerButton.new()
	add_child_autofree(b)
	watch_signals(b)
	b.tap()
	assert_signal_not_emitted(b, "pressed", "незаряджена кнопка мовчить")
	b.set_ready(true)
	b.tap()
	assert_signal_emitted(b, "pressed", "заряджена кнопка озивається на тап")


func test_young_button_is_visible_but_not_tappable() -> void:
	var b := PowerButton.new()
	add_child_autofree(b)
	b.set_interactive(false)
	assert_eq(b.mouse_filter, Control.MOUSE_FILTER_IGNORE, "малятам кнопка не ловить тапи")
	b.set_interactive(true)
	assert_eq(b.mouse_filter, Control.MOUSE_FILTER_STOP)


# ---------- сусідні системи не зачепило ----------

func test_resolve_anim_priority_unchanged() -> void:
	assert_eq(Hero3D.resolve_anim({"hit": true, "rocket": true, "charge": true}), Hero3D.Anim.HIT)
	assert_eq(Hero3D.resolve_anim({"rocket": true, "charge": true}), Hero3D.Anim.ROCKET)
	assert_eq(Hero3D.resolve_anim({"charge": true, "sprint": true}), Hero3D.Anim.CHARGE)
	assert_eq(Hero3D.resolve_anim({"sprint": true, "limp": true}), Hero3D.Anim.SPRINT)
	assert_eq(Hero3D.resolve_anim({"limp": true, "running": true}), Hero3D.Anim.LIMP)
	assert_eq(Hero3D.resolve_anim({"running": true}), Hero3D.Anim.RUN)
	assert_eq(Hero3D.resolve_anim({}), Hero3D.Anim.IDLE)


## EDD §2: великий злиток більше не заряджає силу з одного дотику.
func test_big_ingot_no_longer_fills_the_power_ring() -> void:
	assert_eq(Spawner3D.BIG_VALUE, 20, "номінал великого злитка зрізано 100 → 20")
	assert_eq(Ingot3D.BIG_VALUE, Spawner3D.BIG_VALUE, "модель «великого» злитка збігається зі спавнером")
	var cap := int(RunScript.POWER_CHARGE_PER_PICKUP)
	assert_eq(cap, 20, "один злиток дає в заряд не більше 20")
	# найдешевший заряд (малята, 60) — і той треба збирати щонайменше трьома злитками
	var young := Rules.power_charge_needed(60, 100)
	assert_gte(ceili(float(young) / float(cap)), 3, "сила — нагорода за гру, а не за одну монету")
	assert_gte(ceili(float(Rules.POWER_CHARGE_DEFAULT) / float(cap)), 5, "mid: щонайменше 5 великих злитків")


func test_breakable_actions_are_low_bars_and_boxes() -> void:
	assert_has(Spawner3D.BREAKABLE_ACTIONS, "jump", "низький бар'єр ламається")
	assert_has(Spawner3D.BREAKABLE_ACTIONS, "side", "X-ящик ламається")
	assert_false(Spawner3D.BREAKABLE_ACTIONS.has("duck"), "верхню балку не проб'єш — під нею присідають")
	assert_false(Spawner3D.BREAKABLE_ACTIONS.has("boost"), "трамплін — не перешкода")
	assert_gt(Spawner3D.BREAK_REWARD, 0, "за розбиту перешкоду дають злитки")
