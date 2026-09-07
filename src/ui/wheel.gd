## Колесо станції: після рівня один оберт — 10–50 зірочок або капелюшок-сюрприз. Без витрат (GDD §7).
class_name WheelLayer
extends CanvasLayer

signal finished(reward: Dictionary)   # {"stars": int, "hat": String}

const SECTORS := [
	{"stars": 10, "color": "#42A5F5"},
	{"stars": 20, "color": "#66BB6A"},
	{"stars": 10, "color": "#FFCA28"},
	{"stars": 50, "color": "#EF5350"},
	{"stars": 20, "color": "#26C6DA"},
	{"stars": 30, "color": "#FFA726"},
	{"hat": true, "color": "#AB47BC"},
	{"stars": 20, "color": "#EC407A"},
]

var _root: Control
var _disc: WheelDisc
var _title: Label
var _result: Label
var _spinning := false


class WheelDisc:
	extends Control
	var angle := 0.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(420, 420)
		pivot_offset = size * 0.5
	func _draw() -> void:
		var c := size * 0.5
		var r := 200.0
		var n := SECTORS.size()
		for i in range(n):
			var a0 := angle + TAU * float(i) / float(n)
			var a1 := a0 + TAU / float(n)
			var pts := PackedVector2Array([c])
			for k in range(9):
				var a := lerpf(a0, a1, float(k) / 8.0)
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, Color(String(SECTORS[i]["color"])))
			var mid := (a0 + a1) * 0.5
			var p := c + Vector2(cos(mid), sin(mid)) * r * 0.65
			if SECTORS[i].has("hat"):
				draw_rect(Rect2(p + Vector2(-22, -6), Vector2(44, 12)), Color.WHITE)
				draw_rect(Rect2(p + Vector2(-12, -26), Vector2(24, 20)), Color.WHITE)
			else:
				draw_string(ThemeDB.fallback_font, p + Vector2(-20, 12), str(int(SECTORS[i]["stars"])), HORIZONTAL_ALIGNMENT_CENTER, 40, 34, Color.WHITE)
		draw_arc(c, r, 0.0, TAU, 64, Color("#FFF8E1"), 10.0, true)
		draw_circle(c, 26.0, Color("#FFF8E1"))
		# стрілка зверху
		var tip := c + Vector2(0, -r - 4)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(0, 26), tip + Vector2(-20, -14), tip + Vector2(20, -14)]), Color("#3E2723"))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 9
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.15, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_title = UIKit.title("Колесо станції!", 56)
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.offset_top = 40
	_title.offset_bottom = 40
	_root.add_child(_title)
	_disc = WheelDisc.new()
	_disc.custom_minimum_size = Vector2(420, 420)
	_disc.set_anchors_preset(Control.PRESET_CENTER)
	_disc.offset_left = -210
	_disc.offset_right = 210
	_disc.offset_top = -190
	_disc.offset_bottom = 230
	_root.add_child(_disc)
	_result = UIKit.title("", 64, Color("#FFD54F"))
	_result.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_result.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_result.offset_top = -60
	_result.offset_bottom = -60
	_root.add_child(_result)


## Чиста функція: сектор під стрілкою для кута (стрілка зверху = -PI/2).
static func sector_at(angle: float, n: int) -> int:
	var a := fposmod(-PI * 0.5 - angle, TAU)
	return int(floor(a / (TAU / float(n)))) % n


func spin() -> void:
	if _spinning:
		return
	visible = true
	_spinning = true
	_result.text = ""
	_disc.angle = 0.0
	_disc.scale = Vector2.ZERO
	var target_sector := randi() % SECTORS.size()
	# кут, за якого центр сектора target опиниться під стрілкою (+ 3 повні оберти)
	var sector_mid := TAU * (float(target_sector) + 0.5) / float(SECTORS.size())
	var final_angle := -PI * 0.5 - sector_mid + TAU * 3.0
	AudioMgr.sfx("wheel_start")
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_disc, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(a: float):
		_disc.angle = a
		_disc.queue_redraw(), 0.0, final_angle, 2.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_on_stop.bind(target_sector))


func _on_stop(sector: int) -> void:
	var s: Dictionary = SECTORS[sector]
	var reward := {"stars": int(s.get("stars", 0)), "hat": ""}
	if s.has("hat"):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		reward["hat"] = Hats.random_unowned(Hats.load_all(), Hats.owned(), rng)
		if reward["hat"] == "":
			reward["stars"] = 50   # усі капелюшки вже є — зірочки
	if reward["hat"] != "":
		_result.text = "Новий капелюшок!"
	else:
		_result.text = "+%d" % int(reward["stars"])
	UIKit.pop_in(_result)
	AudioMgr.sfx("wheel_win")
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(1.4)
	tw.tween_property(_disc, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		visible = false
		_spinning = false
		finished.emit(reward))
