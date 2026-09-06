## Авто-вік: спостерігає за грою і пропонує профіль young/mid/older.
## Правила — у data/profiles.json → "age_adapt". Перемикання тільки на станції.
## Autoload: AgeAdapt.
extends Node

const PROFILES := ["young", "mid", "older"]
## Скільки часу до перешкоди дитина ще не мусить реагувати (загроза «видима», але далеко).
const REACTION_LEAD_SEC := 1.0
## Санкція за перешкоду, на яку взагалі не зреагували.
const MISSED_REACTION_MS := 2000.0

var rules: Dictionary = {}
var current: String = "young"

# вікно спостереження
var _reactions_ms: Array[float] = []
var _obstacles: int = 0
var _collisions: int = 0
var _pending_threat_time: float = -1.0
## Номер поточного вікна спостереження: таймери зі старого вікна ігноруються.
var _window_id: int = 0

func _ready() -> void:
	var cfg := load_profiles()
	rules = cfg.get("age_adapt", {})
	current = String(SaveService.child().get("profile", "young"))
	Events.obstacle_spawned.connect(_on_obstacle_spawned)
	Events.hero_tumbled.connect(func(_k): _collisions += 1)
	Events.obstacle_passed.connect(func(_k): _obstacles += 1)
	Events.gameplay_input.connect(_on_input)
	Events.checkpoint_reached.connect(func(_i): evaluate_and_apply())

static func load_profiles() -> Dictionary:
	var f := FileAccess.open("res://data/profiles.json", FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _on_obstacle_spawned(_kind: String, seconds_to_hero: float) -> void:
	# на попередню перешкоду не відповіли — рахуємо як пропущену реакцію
	if _pending_threat_time > 0:
		_reactions_ms.append(MISSED_REACTION_MS)
		_pending_threat_time = -1.0
	# загроза стає «актуальною» лише коли до неї лишається ~1 с
	get_tree().create_timer(max(0.0, seconds_to_hero - REACTION_LEAD_SEC)).timeout.connect(
		_arm_threat.bind(_window_id)
	)

func _arm_threat(wid: int) -> void:
	# вікно спостереження змінилося (станція) — таймер застарілий
	if wid != _window_id:
		return
	_pending_threat_time = Time.get_ticks_msec()

func _on_input() -> void:
	if _pending_threat_time > 0:
		_reactions_ms.append(Time.get_ticks_msec() - _pending_threat_time)
		_pending_threat_time = -1.0

## Чиста функція для тестів: повертає новий профіль за статистикою вікна.
static func decide(profile: String, obstacles: int, collisions: int, avg_reaction_ms: float, r: Dictionary) -> String:
	if obstacles < int(r.get("min_obstacles", 8)):
		return profile
	var idx := PROFILES.find(profile)
	var rate := float(collisions) / float(max(1, obstacles))
	if rate > float(r.get("down_collision_rate", 0.4)) and avg_reaction_ms > float(r.get("down_reaction_ms", 900)):
		return PROFILES[max(0, idx - 1)]
	if rate < float(r.get("up_collision_rate", 0.1)) and avg_reaction_ms < float(r.get("up_reaction_ms", 450)):
		return PROFILES[min(PROFILES.size() - 1, idx + 1)]
	return profile

func evaluate_and_apply() -> void:
	if bool(SaveService.child().get("profile_locked", false)):
		_reset_window()
		return
	var avg := 0.0
	if _reactions_ms.size() > 0:
		var s := 0.0
		for v in _reactions_ms: s += v
		avg = s / _reactions_ms.size()
	var next := decide(current, _obstacles, _collisions, avg, rules)
	_reset_window()
	if next != current:
		set_profile(next)

func set_profile(p: String) -> void:
	current = p
	SaveService.child()["profile"] = p
	SaveService.save_game()
	Events.profile_changed.emit(p)

func _reset_window() -> void:
	_window_id += 1
	_reactions_ms.clear()
	_obstacles = 0
	_collisions = 0
	_pending_threat_time = -1.0
