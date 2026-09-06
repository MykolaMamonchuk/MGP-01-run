## Головне меню поверх живої 3D-сцени: заголовок-хвиля, «Біжимо!», «Герої». Батьки — кнопка HUD (лишається).
class_name MenuLayer
extends CanvasLayer

signal play_pressed
signal heroes_pressed

const TITLE := "Біжи-біжи"
const LETTER_COLORS := ["#FF7043", "#FFCA28", "#66BB6A", "#42A5F5", "#AB47BC", "#EC407A", "#26C6DA", "#FFA726", "#8D6E63"]

var _root: Control
var _title_box: HBoxContainer
var _subtitle: Label
var _buttons: VBoxContainer
var _play: Button
var _heroes: Button
var _hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# заголовок: кожна літера — окремий Control, щоб пружинити незалежно від контейнера
	_title_box = HBoxContainer.new()
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_box.add_theme_constant_override("separation", 2)
	_title_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title_box.offset_top = 36
	_title_box.offset_bottom = 36
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title_box)
	var i := 0
	for ch in TITLE:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(72 if ch != "-" else 40, 130)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_title_box.add_child(slot)
		var l := UIKit.title(ch, 104, Color(String(LETTER_COLORS[i % LETTER_COLORS.size()])))
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.add_child(l)
		_bounce_letter(l, i)
		i += 1

	_subtitle = UIKit.title("дорога-пригода для малят", 30, Color("#FFF8E1"))
	_subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_subtitle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subtitle.offset_top = 170
	_subtitle.offset_bottom = 170
	_root.add_child(_subtitle)

	_buttons = VBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.add_theme_constant_override("separation", 22)
	_buttons.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_buttons.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_buttons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_buttons.offset_top = -48
	_buttons.offset_bottom = -48
	_root.add_child(_buttons)

	_play = UIKit.button("Біжимо!", Color("#66BB6A"), Vector2(420, 150), 62)
	_play.pressed.connect(func(): AudioMgr.sfx("ui_play"); play_pressed.emit())
	_buttons.add_child(_play)
	_heroes = UIKit.button("Герої", Color("#FFA726"), Vector2(300, 104), 42)
	_heroes.pressed.connect(func(): AudioMgr.sfx("ui_tap"); heroes_pressed.emit())
	_heroes.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_buttons.add_child(_heroes)

	_hint = UIKit.title("торкнись героя — він зрадіє", 24, Color("#FFF8E1"))
	_hint.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_hint.grow_vertical = Control.GROW_DIRECTION_BOTH
	_hint.offset_left = 40
	_hint.offset_right = 40
	_hint.offset_top = 120
	_hint.offset_bottom = 120
	_hint.modulate.a = 0.85
	_root.add_child(_hint)
	UIKit.wobble(_hint, 0.03, 2.4)


var _letter_tweens: Array[Tween] = []

func _bounce_letter(l: Control, index: int) -> void:
	var tw := create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_letter_tweens.append(tw)
	tw.tween_interval(0.07 * index)
	tw.tween_property(l, "position:y", -18.0, 0.32).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", 18.0, 0.32).as_relative().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.0, 1.6 - 0.07 * index))


func show_menu() -> void:
	visible = true
	for tw in _letter_tweens:
		tw.play()
	_play.disabled = false
	_heroes.disabled = false
	for c in [_title_box, _subtitle, _play, _heroes, _hint]:
		c.visible = true
	# розміри контролів відомі після кадру розкладки
	call_deferred("_pop_all")


func _pop_all() -> void:
	UIKit.pop_in(_play, 0.15)
	UIKit.pop_in(_heroes, 0.3)
	UIKit.pop_in(_subtitle, 0.05)
	UIKit.pop_in(_hint, 0.45)


func hide_menu() -> void:
	_play.disabled = true
	_heroes.disabled = true
	for c in [_play, _heroes, _subtitle, _hint]:
		UIKit.pop_out(c)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_title_box, "modulate:a", 0.0, 0.3)
	tw.finished.connect(func():
		visible = false
		_title_box.modulate.a = 1.0
		for lt in _letter_tweens:
			lt.pause())
