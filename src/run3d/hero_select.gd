## Вибір героя: 3D-карусель пухнастиків на дорозі + UI (ім'я, як відкрити, стрілки, «Обрати»).
## Свайпи приходять із Run3D (move), тап по героєві — погладити.
class_name HeroSelect
extends Node3D

signal chosen(hero_id: String)
signal closed

const SPACING := 1.7
const ROW_Z := -2.3
const PODIUM_H := 0.18

var heroes: Dictionary = {}
var ids: Array = []          # у порядку "order"
var index := 0

var _row: Node3D
var _previews: Array[Hero3D] = []
var _ui: CanvasLayer
var _name: Label
var _unlock_box: HBoxContainer
var _unlock_label: Label
var _choose: Button
var _left: Button
var _right: Button
var _back: Button
var _lock_icons: Array[Control] = []
var _camera: Camera3D


func _ready() -> void:
	visible = false
	heroes = load_heroes()
	ids = order_ids(heroes)
	_row = Node3D.new()
	_row.position.z = ROW_Z
	add_child(_row)
	for i in range(ids.size()):
		var id := String(ids[i])
		var h: Dictionary = heroes[id]
		var p := Hero3D.new()
		_row.add_child(p)
		p.set_hero(id, String(h.get("color", "#FFB84D")), String(h.get("feature", "tuft")))
		p.position.x = float(i) * SPACING
		p.x_target = p.position.x   # інакше _process героя стягне всіх у x = 0
		p.position.y = PODIUM_H
		p.ground_y = PODIUM_H
		p.rotation.y = PI          # обличчям до камери
		_previews.append(p)
		# подіум стоїть НА землі (не врізається — інакше z-fighting «блимає»)
		var podium := Mats.box(Vector3(1.1, PODIUM_H, 1.1), Color(String(h.get("color", "#FFB84D"))).lightened(0.35))
		podium.position = Vector3(float(i) * SPACING, PODIUM_H * 0.5 + 0.005, 0.0)
		_row.add_child(podium)
	_build_ui()


static func load_heroes() -> Dictionary:
	var f := FileAccess.open("res://data/heroes.json", FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Чиста функція: ідентифікатори героїв у порядку каруселі (без службових ключів).
static func order_ids(h: Dictionary) -> Array:
	var out := []
	for k in h.keys():
		if String(k).begins_with("_") or k == "growth":
			continue
		out.append(k)
	out.sort_custom(func(a, b): return int(h[a].get("order", 99)) < int(h[b].get("order", 99)))
	return out


## Чиста функція: чи відкритий герой за станом гри. Використовує лише передані числа — для тестів.
static func is_unlocked(def: Dictionary, stars: int, checkpoints: int, full_game: bool, growth_stage: int = 1) -> bool:
	var u: Dictionary = def.get("unlock", {})
	match String(u.get("type", "start")):
		"start": return true
		"stars", "rewarded_or_stars": return stars >= int(u.get("amount", 0))
		"checkpoints": return checkpoints >= int(u.get("amount", 0))
		"growth": return growth_stage >= int(u.get("stage", 2))
		"full_game": return full_game
	return false


## Текст-підказка «як відкрити» (порожній — відкрито).
static func unlock_hint(def: Dictionary) -> String:
	var u: Dictionary = def.get("unlock", {})
	match String(u.get("type", "start")):
		"stars", "rewarded_or_stars": return "%d" % int(u.get("amount", 0))
		"checkpoints": return "%d станції" % int(u.get("amount", 0))
		"growth": return "виростити героя"
		"full_game": return "разом з батьками"
	return ""


func _unlocked(id: String) -> bool:
	return is_unlocked(heroes[id], SaveService.stars(), int(SaveService.child().get("checkpoints", 0)), Purchase.is_full_game())


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 6
	_ui.visible = false
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	_name = UIKit.title("", 72)
	_name.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_name.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_name.offset_top = 40
	_name.offset_bottom = 40
	root.add_child(_name)

	_unlock_box = HBoxContainer.new()
	_unlock_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_unlock_box.add_theme_constant_override("separation", 10)
	_unlock_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_unlock_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_unlock_box.offset_top = 130
	_unlock_box.offset_bottom = 130
	_unlock_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_unlock_box)
	_unlock_box.add_child(Icons.StarIcon.new(44.0))
	_unlock_label = UIKit.title("", 34, Color("#FFF8E1"))
	_unlock_box.add_child(_unlock_label)

	_left = UIKit.button("‹", Color("#42A5F5"), Vector2(110, 110), 64)
	_left.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_left.grow_vertical = Control.GROW_DIRECTION_BOTH
	_left.offset_left = 30
	_left.offset_right = 30
	_left.pressed.connect(func(): move(-1))
	root.add_child(_left)
	_right = UIKit.button("›", Color("#42A5F5"), Vector2(110, 110), 64)
	_right.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_right.grow_vertical = Control.GROW_DIRECTION_BOTH
	_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_right.offset_left = -30
	_right.offset_right = -30
	_right.pressed.connect(func(): move(1))
	root.add_child(_right)

	_choose = UIKit.button("Обрати", Color("#66BB6A"), Vector2(340, 120), 48)
	_choose.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_choose.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_choose.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choose.offset_top = -40
	_choose.offset_bottom = -40
	_choose.pressed.connect(_on_choose)
	root.add_child(_choose)

	_back = UIKit.button("‹ Назад", Color("#8D6E63"), Vector2(200, 80), 30)
	_back.position = Vector2(140, 32)   # праворуч від кнопки батьків у HUD
	_back.pressed.connect(func(): AudioMgr.sfx("ui_tap"); close())
	root.add_child(_back)


func open(camera: Camera3D, current_id: String) -> void:
	_camera = camera
	visible = true
	_ui.visible = true
	index = maxi(0, ids.find(current_id))
	_row.position.x = -float(index) * SPACING
	_refresh(true)
	AudioMgr.voice("choose_hero")


func close() -> void:
	visible = false
	_ui.visible = false
	closed.emit()


func move(dir: int) -> void:
	var next := clampi(index + dir, 0, ids.size() - 1)
	if next == index:
		# край каруселі — легкий відскок
		var tw := create_tween()
		tw.tween_property(_row, "position:x", -float(index) * SPACING - float(dir) * 0.25, 0.1)
		tw.tween_property(_row, "position:x", -float(index) * SPACING, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	index = next
	AudioMgr.sfx("ui_swipe")
	var tw := create_tween()
	tw.tween_property(_row, "position:x", -float(index) * SPACING, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_refresh(false)


func _refresh(instant: bool) -> void:
	var id := String(ids[index])
	var h: Dictionary = heroes[id]
	var unlocked := _unlocked(id)
	_name.text = String(h.get("name_uk", id))
	_unlock_box.visible = not unlocked
	var hint := unlock_hint(h)
	_unlock_label.text = hint
	# зірочка — лише коли ціна в зірочках
	(_unlock_box.get_child(0) as Control).visible = hint.is_valid_int()
	_choose.text = "Обрати" if unlocked else "Ще не відкрито"
	_choose.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.75)
	_left.visible = index > 0
	_right.visible = index < ids.size() - 1
	for i in range(_previews.size()):
		var p := _previews[i]
		var target := Vector3.ONE * (1.0 if i == index else 0.78)
		p.set_locked_look(not _unlocked(String(ids[i])))
		if instant:
			p.scale = target
		else:
			var tw := create_tween()
			tw.tween_property(p, "scale", target, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if unlocked:
		_previews[index].wave_hello()
	if not instant:
		UIKit.pop_in(_name)


func _on_choose() -> void:
	var id := String(ids[index])
	if not _unlocked(id):
		UIKit.shake(_choose)
		AudioMgr.sfx("locked")
		AudioMgr.voice("locked")
		return
	AudioMgr.sfx("ui_play")
	_previews[index].cheer()
	FX.confetti(_row, Vector3(float(index) * SPACING, 1.0, 0.0), 50)
	SaveService.child()["hero"] = id
	SaveService.save_game()
	get_tree().create_timer(0.5).timeout.connect(func():
		chosen.emit(id)
		close())


## Тап по екрану: якщо влучив у героя — погладити.
func tap(screen_pos: Vector2) -> void:
	if _camera == null:
		return
	for i in range(_previews.size()):
		var p := _previews[i]
		var sp := _camera.unproject_position(p.global_position + Vector3(0, 0.6, 0))
		if sp.distance_to(screen_pos) < 110.0:
			p.pet()
			if i != index:
				move(i - index)
			return
