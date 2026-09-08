## HUD-мінімум (GDD v1.4 §10, реф. §6): ліворуч угорі — злиток і монети рівня, під ним серця;
## по центру — великий лаймовий ×N і маленька швидкість; праворуч — кругла пауза.
## Загальні зірочки під час бігу не показуються (вони живуть у меню/діорамі/героях).
## Знизу по центру — смужка пікапа; ліворуч під серцями — мінізавдання; знизу ліворуч — кнопка батьків.
## Будується кодом. Кожен дитячий елемент має намальовану іконку (src/ui/components/icons.gd), текст — лише другорядний.
extends CanvasLayer

## Пауза: гру ставить/знімає Run3D, HUD лише повідомляє.
signal pause_pressed()
signal resume_pressed()
signal menu_pressed()

## Знак пікапа, якщо в data/pickups.json його нема (колір — Palette.PICKUP_DEFAULT).
const PICKUP_FALLBACK_LETTER := "?"
## Воксель злитка для іконки монет рівня.
const INGOT_VOXEL := "ingot"
## Пульс лічильника швидкості — на кожному перетині чергових +10 км/год.
const SPEED_PULSE_STEP := 10
## Миттєвий пікап (seconds 0): іконка підскакує й ховається через стільки секунд.
const PICKUP_POP_SEC := 0.8

var stars_label: Label
var profile_label: Label
var hint: Control
var station_panel: Control
var sleep_panel: Control
var yawn_panel: Control
var parents_open := false

var _root: Control
var _hint_t := 0.0
var _sleep_button: Button
var _parents_panel: Control
var _hint_arrow: Control
var _hint_label: Label
var _finish_panel: Control
var _quest_box: HBoxContainer
var _quest_label: Label
var _quest_icon: Control
var _fork_box: HBoxContainer
var _fork_cb: Callable
# v1.3: серця, швидкість, пікап, лічильник рівня
var _tally := 0
var _tally_box: HBoxContainer
var _tally_label: Label
var _hearts_box: HBoxContainer
var _hearts: Array[Control] = []
var _hearts_n := 3
var _speed_box: HBoxContainer
var _speed_label: Label
var _speed_kmh := -1
var _pickup_box: HBoxContainer
var _pickup_icon: Control
var _pickup_bar: Control
var _pickup_kind := ""
var _pickup_total := 0.0
var _pickup_left := 0.0
var _pickup_pop_tw: Tween
# v1.4: множник, пауза, загальні зірочки як окремий блок
var _stars_box: HBoxContainer
var _mult := 1
var _mult_label: Label
var _pause_btn: Button
var _pause_panel: Control
var _tally_tw: Tween


## Кругла сіра кнопка паузи: коло з двома білими рисками.
class PauseGlyph:
	extends Control

	func _init(px: float = 88.0) -> void:
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r: float = min(size.x, size.y) * 0.46
		draw_circle(c, r, Palette.BTN_SETTINGS)
		draw_arc(c, r, 0.0, TAU, 32, Palette.ICON_EDGE, r * 0.1)
		var w := r * 0.22
		var h := r * 0.9
		draw_rect(Rect2(c + Vector2(-w * 2.0, -h * 0.5), Vector2(w, h)), Palette.WHITE)
		draw_rect(Rect2(c + Vector2(w, -h * 0.5), Vector2(w, h)), Palette.WHITE)


func _ready() -> void:
	# HUD має жити й тоді, коли дерево на паузі (станція, сон, екран батьків).
	process_mode = Node.PROCESS_MODE_ALWAYS
	# над меню (5) і каруселлю героїв (6): екран батьків не перекривається
	layer = 10

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# загальні зірочки — лише поза бігом (меню, герої, фініш); у RUN ховаються
	_stars_box = HBoxContainer.new()
	_stars_box.position = Vector2(1000, 24)
	_stars_box.add_theme_constant_override("separation", 10)
	_stars_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stars_box)
	_stars_box.add_child(Icons.StarIcon.new(56.0))
	stars_label = UIKit.title("0", 48)
	_stars_box.add_child(stars_label)

	# ліворуч угорі: злиток + монети цього рівня
	_tally_box = HBoxContainer.new()
	_tally_box.position = Vector2(28, 20)
	_tally_box.add_theme_constant_override("separation", 10)
	_tally_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tally_box)
	_tally_box.add_child(Icons.VoxelIcon.new(INGOT_VOXEL, 56.0))
	_tally_label = UIKit.title("0", 48, Palette.STAR)
	_tally_box.add_child(_tally_label)

	# по центру вгорі: великий лаймовий множник, під ним маленька швидкість
	var center_box := VBoxContainer.new()
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	center_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center_box.grow_vertical = Control.GROW_DIRECTION_END
	center_box.offset_top = 12
	center_box.offset_bottom = 12
	center_box.add_theme_constant_override("separation", 0)
	center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center_box)
	_mult_label = UIKit.title("×1", 72, Palette.LIME)
	_mult_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_mult_label.resized.connect(func(): _mult_label.pivot_offset = _mult_label.size * 0.5)
	center_box.add_child(_mult_label)
	_speed_box = HBoxContainer.new()
	_speed_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_speed_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_speed_box.add_theme_constant_override("separation", 6)
	_speed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_box.add_child(_speed_box)
	_speed_label = UIKit.title("0", 20)
	_speed_label.resized.connect(func(): _speed_label.pivot_offset = _speed_label.size * 0.5)
	_speed_box.add_child(_speed_label)
	var kmh := UIKit.title("км/год", 20, Palette.TEXT_LIGHT)
	_speed_box.add_child(kmh)

	# праворуч угорі: кругла пауза
	_pause_btn = Button.new()
	_pause_btn.position = Vector2(1164, 24)
	_pause_btn.custom_minimum_size = Vector2(88, 88)
	_pause_btn.size = _pause_btn.custom_minimum_size
	_pause_btn.focus_mode = Control.FOCUS_NONE
	_pause_btn.tooltip_text = "Пауза"
	for st in ["normal", "hover", "pressed", "focus"]:
		_pause_btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_pause_btn.pressed.connect(_on_pause_button)
	_root.add_child(_pause_btn)
	_pause_btn.add_child(PauseGlyph.new(88.0))

	Events.star_collected.connect(_on_star_collected)
	Events.checkpoint_reached.connect(_on_checkpoint_reached)
	Events.hearts_changed.connect(_on_hearts_changed)
	Events.pickup_started.connect(show_pickup)
	Events.pickup_ended.connect(_on_pickup_ended)

	profile_label = Label.new()
	profile_label.position = Vector2(440, 686)
	profile_label.add_theme_font_size_override("font_size", 18)
	profile_label.modulate.a = 0.5
	_root.add_child(profile_label)

	# кнопка батьків переїхала вниз ліворуч — угорі ліворуч тепер злиток і серця
	var parents := Button.new()
	parents.position = Vector2(24, 600)
	parents.custom_minimum_size = Vector2(96, 96)
	parents.tooltip_text = "Для батьків"
	parents.pressed.connect(_request_parents)
	_root.add_child(parents)
	var parent_icon := Icons.ParentIcon.new(64.0)
	parent_icon.position = Vector2(16, 16)
	parents.add_child(parent_icon)

	# серця — під лічильником злитків
	_hearts_box = HBoxContainer.new()
	_hearts_box.position = Vector2(32, 92)
	_hearts_box.add_theme_constant_override("separation", 6)
	_hearts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hearts_box)
	_build_hearts(_hearts_n)

	# пікап: іконка + смужка часу, знизу по центру (ховається, коли нічого не діє)
	_pickup_box = HBoxContainer.new()
	_pickup_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_pickup_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pickup_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_pickup_box.offset_left = 0
	_pickup_box.offset_right = 0
	_pickup_box.offset_top = -24
	_pickup_box.offset_bottom = -24
	_pickup_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_pickup_box.add_theme_constant_override("separation", 12)
	_pickup_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pickup_box.visible = false
	_root.add_child(_pickup_box)
	_pickup_icon = PickupIcon.new(Palette.PICKUP_DEFAULT, PICKUP_FALLBACK_LETTER)
	_pickup_box.add_child(_pickup_icon)
	_pickup_bar = PickupBar.new(Palette.PICKUP_DEFAULT)
	_pickup_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pickup_box.add_child(_pickup_bar)

	# підказка-жест: велика стрілка + слово, над героєм (замість незрозумілої «лапки»)
	hint = VBoxContainer.new()
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_CENTER)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BOTH
	hint.offset_top = -120
	hint.offset_bottom = -120
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.visible = false
	_root.add_child(hint)
	_hint_arrow = Icons.GestureIcon.new("tap", 120.0)
	_hint_arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hint.add_child(_hint_arrow)
	_hint_label = UIKit.title("Тапни!", 44, Palette.TEXT_HINT)
	hint.add_child(_hint_label)

	station_panel = _panel(_root, Icons.StationIcon.new(96.0), "Станція!\nКуди далі?")
	yawn_panel = _panel(_root, Icons.MoonIcon.new(96.0), "Герой втомлюється…")
	sleep_panel = _panel(_root, Icons.MoonIcon.new(96.0), "На добраніч!")

	# мінізавдання (від mid): маленька коробочка під серцями
	_quest_box = HBoxContainer.new()
	_quest_box.position = Vector2(32, 148)
	_quest_box.add_theme_constant_override("separation", 8)
	_quest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_box.visible = false
	_root.add_child(_quest_box)
	_quest_label = Label.new()
	_quest_label.add_theme_font_size_override("font_size", 22)
	_quest_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quest_box.add_child(_quest_label)

	# Розвилка: контейнер під дверима, ховається
	_fork_box = HBoxContainer.new()
	_fork_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_fork_box.add_theme_constant_override("separation", 48)
	_fork_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_fork_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_fork_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_fork_box.offset_top = -40
	_fork_box.offset_bottom = -40
	_fork_box.visible = false
	_root.add_child(_fork_box)
	_refresh()

func _panel(parent: Control, icon: Control, text: String) -> Control:
	var p := PanelContainer.new()
	ParentGate._center(p, Vector2(600, 300))
	p.visible = false
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	row.add_child(icon)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 44)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	parent.add_child(p)
	return p

## Текстова частина панелі (іконка — перша дитина рядка).
func _panel_label(p: Control) -> Label:
	return p.get_child(0).get_child(1) as Label

func _process(delta: float) -> void:
	if hint.visible:
		_hint_t += delta
		hint.offset_top = -120 + sin(_hint_t * 6.0) * 16.0
		hint.offset_bottom = hint.offset_top
		if _hint_t > 2.4:
			hint.visible = false
	# смужка пікапа тане (лише коли гра йде — на паузі таймер у Run3D теж стоїть)
	if _pickup_box.visible and _pickup_total > 0.0 and not get_tree().paused:
		_pickup_left = maxf(0.0, _pickup_left - delta)
		_pickup_bar.set_ratio(_pickup_left / _pickup_total)
		if _pickup_left <= 0.0:
			hide_pickup()


# ---------- v1.3: серця, швидкість, монети рівня, пікап ----------

## Ряд сердець заново (n = максимум героя, 3–4).
func _build_hearts(n: int) -> void:
	for c in _hearts_box.get_children():
		c.queue_free()
	_hearts.clear()
	for i in range(maxi(1, n)):
		var h := HeartIcon.new(44.0)
		_hearts_box.add_child(h)
		_hearts.append(h)
	_hearts_n = _hearts.size()


## Events.hearts_changed: більше за ряд — це новий максимум (старт рівня), перебудова;
## інакше — повне/порожнє з підскоком на +1 і трясінням на −1.
## Новий максимум (інший герой): перебудувати ряд на n сердець.
func set_max_hearts(n: int) -> void:
	if n != _hearts.size():
		_build_hearts(n)


func _on_hearts_changed(hearts: int) -> void:
	if hearts > _hearts.size():
		_build_hearts(hearts)
	var prev := 0
	for h in _hearts:
		if (h as HeartIcon).full:
			prev += 1
	for i in range(_hearts.size()):
		var h := _hearts[i] as HeartIcon
		var was := h.full
		var now := i < hearts
		h.set_full(now)
		if now and not was:
			# підскок
			h.pivot_offset = h.size * 0.5
			var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(h, "scale", Vector2(1.4, 1.4), 0.12)
			tw.tween_property(h, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC)
		elif was and not now:
			# сіріє зі стисканням (position у HBox не трясти — контейнер перекладе)
			h.pivot_offset = h.size * 0.5
			var tw2 := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw2.tween_property(h, "scale", Vector2(0.7, 0.7), 0.1)
			tw2.tween_property(h, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	if hearts < prev and hearts >= 0:
		# і весь ряд здригається
		UIKit.shake(_hearts_box)


## Монети, зібрані на цьому рівні (Run3D.level_coins).
func set_tally(n: int) -> void:
	_tally = maxi(0, n)
	_tally_label.text = "%d" % _tally


## Лічильник злитків плавно з'їжджає до to (сорока вкрала) — seconds секунд, з трясінням.
func tween_tally(to: int, seconds: float = 1.0) -> void:
	if _tally_tw:
		_tally_tw.kill()
	var from := float(_tally)
	var target := float(maxi(0, to))
	_tally_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tally_tw.tween_method(_set_tally_f, from, target, maxf(0.05, seconds))
	UIKit.shake(_tally_box)


func _set_tally_f(v: float) -> void:
	set_tally(int(round(v)))


## Великий лаймовий множник ×N у центрі (GDD v1.4 §10); змінився — пульсує.
func set_multiplier(n: int) -> void:
	var v := maxi(1, n)
	if v == _mult:
		return
	_mult = v
	_mult_label.text = "×%d" % v
	_mult_label.pivot_offset = _mult_label.size * 0.5
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_mult_label, "scale", Vector2(1.35, 1.35), 0.1)
	tw.tween_property(_mult_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC)


func multiplier() -> int:
	return _mult


## Спливаючий напис біля героя («+100×3» на великому злитку). screen_pos — екранні координати.
func pop_text(screen_pos: Vector2, text: String) -> void:
	var l := UIKit.title(text, 56, Palette.LIME)
	l.position = screen_pos - Vector2(120.0, 40.0)
	l.size = Vector2(240.0, 80.0)
	_root.add_child(l)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.4, 0.4)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - 90.0, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.finished.connect(l.queue_free)


# ---------- пауза (GDD v1.4 §10) ----------

func _on_pause_button() -> void:
	AudioMgr.sfx("ui_tap")
	pause_pressed.emit()


## Панель «Пауза» з кнопками «Далі» і «Меню». Гру ставить на паузу Run3D.
func show_pause() -> void:
	hide_pause()
	var dim := ColorRect.new()
	dim.name = "PauseDim"
	dim.color = Palette.SHADOW
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(dim)
	var p := PanelContainer.new()
	ParentGate._center(p, Vector2(560, 340))
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.set_corner_radius_all(36)
	style.set_content_margin_all(28)
	style.shadow_size = 16
	style.shadow_color = Palette.SHADOW
	p.add_theme_stylebox_override("panel", style)
	add_child(p)
	_pause_panel = p
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 24)
	p.add_child(v)
	v.add_child(UIKit.title("Пауза", 64, Palette.LEVEL_DONE))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	v.add_child(row)
	var m := UIKit.button("Меню", Palette.BTN_NAV, Vector2(220, 100), 40)
	m.pressed.connect(func(): AudioMgr.sfx("ui_tap"); menu_pressed.emit())
	row.add_child(m)
	var go := UIKit.button("Далі", Palette.BTN_PRIMARY, Vector2(260, 110), 46)
	go.pressed.connect(func(): AudioMgr.sfx("ui_play"); resume_pressed.emit())
	row.add_child(go)
	call_deferred("_pop_pause")


func _pop_pause() -> void:
	if is_instance_valid(_pause_panel):
		UIKit.pop_in(_pause_panel)


func hide_pause() -> void:
	if is_instance_valid(_pause_panel):
		_pause_panel.queue_free()
	_pause_panel = null
	if has_node("PauseDim"):
		get_node("PauseDim").queue_free()


func pause_visible() -> bool:
	return is_instance_valid(_pause_panel)


## Швидкість у клітинках/с → «км/год» (×10); пульс на кожних нових +10.
func set_speed(cells: float) -> void:
	var kmh := int(round(maxf(0.0, cells) * 10.0))
	if kmh == _speed_kmh:
		return
	var crossed := _speed_kmh >= 0 and kmh / SPEED_PULSE_STEP != _speed_kmh / SPEED_PULSE_STEP
	_speed_kmh = kmh
	_speed_label.text = "%d" % kmh
	if crossed and _speed_box.visible:
		_speed_label.pivot_offset = _speed_label.size * 0.5
		var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(_speed_label, "scale", Vector2(1.3, 1.3), 0.1)
		tw.tween_property(_speed_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC)


## Показати пікап: іконка (колір/знак з data/pickups.json) + смужка на seconds. seconds 0 — лише підскок іконки.
func show_pickup(kind: String, seconds: float) -> void:
	var def := Pickup3D.def_of(kind)
	var color := Palette.of(def.get("color"), Palette.PICKUP_DEFAULT)
	var letter := String(def.get("letter", PICKUP_FALLBACK_LETTER))
	# миттєвий пікап (сердечко) під час дії тривалого — не ховаємо чужу смужку, лише підскок
	if seconds <= 0.0 and _pickup_total > 0.0 and _pickup_box.visible and kind != _pickup_kind:
		if is_instance_valid(_pickup_icon):
			var tw0 := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw0.tween_property(_pickup_icon, "scale", Vector2(1.3, 1.3), 0.1)
			tw0.tween_property(_pickup_icon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC)
		return
	if _pickup_pop_tw:
		_pickup_pop_tw.kill()
		_pickup_pop_tw = null
	var same := kind == _pickup_kind and _pickup_box.visible
	if not same:
		if is_instance_valid(_pickup_icon):
			_pickup_icon.queue_free()
		_pickup_icon = PickupIcon.new(color, letter)
		_pickup_box.add_child(_pickup_icon)
		_pickup_box.move_child(_pickup_icon, 0)
		(_pickup_bar as PickupBar).color = color
	_pickup_kind = kind
	_pickup_box.visible = true
	_pickup_box.modulate.a = 1.0
	if seconds <= 0.0:
		# миттєвий (сердечко): підскок і геть
		_pickup_total = 0.0
		_pickup_left = 0.0
		_pickup_bar.visible = false
		_pop_pickup_icon()
		_pickup_pop_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_pickup_pop_tw.tween_interval(PICKUP_POP_SEC)
		_pickup_pop_tw.tween_callback(hide_pickup)
		return
	_pickup_bar.visible = true
	if same and seconds <= _pickup_left + 0.05:
		# той самий ефект, менше часу (інший скінчився) — смужка не стрибає до повної
		_pickup_left = seconds
	else:
		_pickup_total = seconds
		_pickup_left = seconds
		_pop_pickup_icon()
	_pickup_bar.set_ratio(_pickup_left / maxf(0.01, _pickup_total))


func _pop_pickup_icon() -> void:
	if not is_instance_valid(_pickup_icon):
		return
	_pickup_icon.pivot_offset = _pickup_icon.size * 0.5
	_pickup_icon.scale = Vector2(0.3, 0.3)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_pickup_icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_pickup() -> void:
	if _pickup_pop_tw:
		_pickup_pop_tw.kill()
		_pickup_pop_tw = null
	_pickup_kind = ""
	_pickup_total = 0.0
	_pickup_left = 0.0
	_pickup_box.visible = false


## Events.pickup_ended: Run3D сам вирішує, що показувати далі (show_pickup/hide_pickup); тут — лише той самий вид.
func _on_pickup_ended(kind: String) -> void:
	if kind == _pickup_kind and _pickup_total > 0.0:
		hide_pickup()


func _on_star_collected(_n: int) -> void:
	call_deferred("_refresh")

func _on_checkpoint_reached(_i: int) -> void:
	call_deferred("_refresh")

func _refresh() -> void:
	stars_label.text = "%d" % SaveService.stars()

var _profile_name := ""
var _world_name := ""

func set_profile(profile_name: String) -> void:
	_profile_name = profile_name
	_refresh_caption()

func set_world(world_name: String) -> void:
	_world_name = world_name
	_refresh_caption()

func _refresh_caption() -> void:
	profile_label.text = "%s · профіль: %s" % [_world_name, _profile_name]

## Підказка-жест: kind — "tap" | "left" | "right" | "up" | "down" | "hold"; text — коротке слово.
func show_hint(kind: String = "tap", text: String = "Тапни!") -> void:
	_hint_t = 0.0
	if _hint_arrow:
		_hint_arrow.queue_free()
	_hint_arrow = Icons.GestureIcon.new(kind, 120.0)
	_hint_arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hint.add_child(_hint_arrow)
	hint.move_child(_hint_arrow, 0)
	_hint_label.text = text
	hint.visible = true


## Фініш рівня: «Ура!», зірки 1–3 з пружиною, «Далі» / «Мапа».
func show_finish(level_num: int, stars: int, on_next: Callable, on_map: Callable, show_map_button: bool = true) -> void:
	hide_finish()
	var p := PanelContainer.new()
	ParentGate._center(p, Vector2(760, 440))
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.set_corner_radius_all(36)
	style.set_content_margin_all(28)
	style.shadow_size = 16
	style.shadow_color = Palette.SHADOW
	p.add_theme_stylebox_override("panel", style)
	add_child(p)
	_finish_panel = p
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	p.add_child(v)
	v.add_child(UIKit.title("Ура! Рівень %d" % level_num, 60, Palette.LEVEL_DONE))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	for i in range(3):
		var s := Icons.StarIcon.new(110.0)
		if i >= stars:
			s.modulate = Color(0.75, 0.75, 0.75, 0.6)
		row.add_child(s)
		if i < stars:
			s.pivot_offset = s.size * 0.5
			s.scale = Vector2.ZERO
			var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_interval(0.35 + 0.3 * i)
			tw.tween_callback(func(): AudioMgr.sfx("star_big", 1.0 + 0.15 * i))
			tw.tween_property(s, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 28)
	v.add_child(buttons)
	if show_map_button:
		var m := UIKit.button("Мапа", Palette.BTN_NAV, Vector2(220, 100), 40)
		m.pressed.connect(func(): AudioMgr.sfx("ui_tap"); on_map.call())
		buttons.add_child(m)
	var nxt := UIKit.button("Далі!", Palette.BTN_PRIMARY, Vector2(300, 110), 48)
	nxt.pressed.connect(func(): AudioMgr.sfx("ui_play"); on_next.call())
	buttons.add_child(nxt)
	call_deferred("_pop_finish")


func _pop_finish() -> void:
	if is_instance_valid(_finish_panel):
		UIKit.pop_in(_finish_panel)


func hide_finish() -> void:
	if is_instance_valid(_finish_panel):
		_finish_panel.queue_free()
	_finish_panel = null

func show_yawn() -> void:
	yawn_panel.visible = true
	get_tree().create_timer(2.0).timeout.connect(_end_yawn)

func _end_yawn() -> void:
	if is_instance_valid(yawn_panel):
		yawn_panel.visible = false

func show_station(i: int) -> void:
	_panel_label(station_panel).text = "Станція %d!\n+20   Куди далі?" % i
	station_panel.visible = true
	# панель станції піднімаємо, щоб не перекривати двері Розвилки
	station_panel.offset_top = -200
	station_panel.offset_bottom = -200

func hide_station() -> void:
	station_panel.visible = false
	hide_fork()

## Розвилка: великі двері-кнопки. options = [{"id","name_uk","accent"}], cb(id).
func show_fork(options: Array, cb: Callable) -> void:
	_fork_cb = cb
	for c in _fork_box.get_children():
		c.queue_free()
	for opt in options:
		var id := String(opt.get("id", "meadow"))
		var b := UIKit.button("", Palette.of(opt.get("accent"), Palette.WORLD_ACCENT).lightened(0.15), Vector2(250, 270))
		b.pressed.connect(_on_fork_pressed.bind(id))
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var ic := Icons.WorldIcon.new(id, 140.0)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var l := UIKit.title(String(opt.get("name_uk", id)), 36)
		v.add_child(l)
		_fork_box.add_child(b)
	_fork_box.visible = true
	call_deferred("_pop_fork")

func _pop_fork() -> void:
	var i := 0
	for b in _fork_box.get_children():
		UIKit.pop_in(b, 0.1 * i)
		i += 1

func _on_fork_pressed(id: String) -> void:
	hide_fork()
	if _fork_cb.is_valid():
		_fork_cb.call(id)

func hide_fork() -> void:
	_fork_box.visible = false

func fork_visible() -> bool:
	return _fork_box.visible

## Меню/герої/діорама: ховаємо ігрові елементи, показуємо загальні зірочки й кнопку батьків.
## У бігу — навпаки: загальний лічильник зірочок зникає (GDD v1.4 §10, HUD-мінімум).
func set_gameplay_visible(on: bool) -> void:
	profile_label.visible = on
	_hearts_box.visible = on
	_speed_box.visible = on
	_tally_box.visible = on
	_mult_label.visible = on
	_pause_btn.visible = on
	_stars_box.visible = not on
	if not on:
		_quest_box.visible = false
		hint.visible = false
		hide_pickup()
		hide_pause()

## Великий напис по центру з пружиною (відлік «3 2 1 Біжимо!», «Станція!»).
func flash(text: String, seconds: float = 0.7, color: Color = Palette.WHITE) -> void:
	var l := UIKit.title(text, 140, color)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(l)
	l.pivot_offset = l.size * 0.5
	l.resized.connect(func(): l.pivot_offset = l.size * 0.5)
	l.scale = Vector2.ZERO
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.05, seconds - 0.45))
	tw.tween_property(l, "scale", Vector2.ONE * 1.4, 0.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.2)
	tw.finished.connect(l.queue_free)

## Зірочка летить з місця збору до лічильника монет рівня.
func fly_star(from_screen: Vector2) -> void:
	var s := Icons.StarIcon.new(40.0)
	s.position = from_screen - Vector2(20, 20)
	_root.add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "position", _tally_label.get_global_rect().position - Vector2(44, 0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(s, "scale", Vector2(0.6, 0.6), 0.45)
	tw.finished.connect(func():
		s.queue_free()
		_bump_counter())

func _bump_counter() -> void:
	var box := _tally_box as Control
	box.pivot_offset = box.size * 0.5
	var tw := create_tween()
	tw.tween_property(box, "scale", Vector2(1.25, 1.25), 0.08)
	tw.tween_property(box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC)

## Мінізавдання: kind ("stars"/"passed"/"events"), прогрес/ціль. target 0 — сховати.
func set_quest(kind: String, value: int, target: int) -> void:
	if target <= 0:
		_quest_box.visible = false
		return
	if _quest_icon == null or _quest_icon.get("kind") != kind:
		if _quest_icon:
			_quest_icon.queue_free()
		_quest_icon = Icons.QuestIcon.new(kind, 32.0)
		_quest_box.add_child(_quest_icon)
		_quest_box.move_child(_quest_icon, 0)
	_quest_label.text = "%d / %d" % [value, target]
	_quest_box.visible = true

## Завдання виконано: підсвітка + панель на секунду.
func show_quest_done(reward: int) -> void:
	_quest_label.text = "+%d" % reward
	var tw := create_tween()
	tw.tween_property(_quest_box, "scale", Vector2(1.3, 1.3), 0.15)
	tw.tween_property(_quest_box, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC)

func show_sleep(on_parent_continue: Callable) -> void:
	sleep_panel.visible = true
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.05, 0.05, 0.2, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	move_child(dim, 0)
	_sleep_button = Button.new()
	_sleep_button.text = "Батьки: продовжити"
	_sleep_button.position = Vector2(480, 560)
	_sleep_button.custom_minimum_size = Vector2(320, 80)
	_sleep_button.add_theme_font_size_override("font_size", 24)
	_sleep_button.pressed.connect(on_parent_continue)
	_root.add_child(_sleep_button)

func hide_sleep() -> void:
	sleep_panel.visible = false
	if has_node("Dim"):
		get_node("Dim").queue_free()
	if is_instance_valid(_sleep_button):
		_sleep_button.queue_free()
	_sleep_button = null

## Безпечний доступ до сцени бігу (може не бути батьком у тестах).
func _run() -> Node:
	var p := get_parent()
	if is_instance_valid(p) and p.has_method("_leave_station"):
		return p
	return null

func _run_is_busy() -> bool:
	var r := _run()
	if r == null:
		return false
	return bool(r.get("paused_at_station")) or bool(r.get("sleeping")) or bool(r.get("paused_by_button"))

func _request_parents() -> void:
	# поки бар'єр відкритий, гра стоїть (інакше герой біжить за затемненням)
	parents_open = true
	get_tree().paused = true
	ParentGate.closed.connect(_on_gate_closed, CONNECT_ONE_SHOT)
	ParentGate.request("settings", _open_parents)

## Бар'єр закрився: якщо екран батьків не відкрився (натиснуто «Назад») — знімаємо паузу.
## При успіху _open_parents викликається одразу після цього і ставить паузу знову.
func _on_gate_closed() -> void:
	if not is_instance_valid(_parents_panel):
		_close_parents()

func _request_buy() -> void:
	ParentGate.request("money", Purchase.buy_full_game)

func _set_session_minutes(m: int) -> void:
	SaveService.set_setting("session_minutes", m)
	SessionTimer.start(float(m))

func _close_parents() -> void:
	parents_open = false
	if is_instance_valid(_parents_panel):
		_parents_panel.queue_free()
	_parents_panel = null
	if has_node("ParentsDim"):
		get_node("ParentsDim").queue_free()
	if not _run_is_busy():
		get_tree().paused = false

func _open_parents() -> void:
	var s := SaveService
	parents_open = true
	get_tree().paused = true
	# затемнення + блокування кліків по грі під панеллю
	var dim := ColorRect.new()
	dim.name = "ParentsDim"
	dim.color = Color(0.05, 0.05, 0.15, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var p := PanelContainer.new()
	ParentGate._center(p, Vector2(800, 480))
	add_child(p)
	_parents_panel = p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(Icons.ParentIcon.new(48.0))
	var t := Label.new()
	t.text = "Екран батьків"
	t.add_theme_font_size_override("font_size", 36)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(t)
	var info := Label.new()
	info.text = "Зірочок: %d   Пройдено перешкод: %d   Падінь: %d   Сесій завершено сном: %d\nПрофіль віку: %s (авто)\nПовна гра: %s" % [
		s.stars(), Stats.get_value("obstacles_passed"), Stats.get_value("tumbles"),
		Stats.get_value("sessions_finished_by_sleep"), AgeAdapt.current, "так" if Purchase.is_full_game() else "ні — 4,99 $ разово, без реклами назавжди"]
	info.add_theme_font_size_override("font_size", 22)
	v.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var l := Label.new()
	l.text = "Сесія, хв:"
	l.add_theme_font_size_override("font_size", 24)
	row.add_child(l)
	for m in [10, 15, 20, 30]:
		var b := Button.new()
		b.text = str(m)
		b.custom_minimum_size = Vector2(90, 70)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_set_session_minutes.bind(int(m)))
		row.add_child(b)
	# керування: стрілки / джойстик / скинути підказки
	var ctl := HBoxContainer.new()
	ctl.add_theme_constant_override("separation", 12)
	v.add_child(ctl)
	var arrows_on := bool(s.setting("arrows", AgeAdapt.current == "young"))
	var joy_on := bool(s.setting("joystick", true))
	var b_arrows := Button.new()
	b_arrows.text = "Стрілки: %s" % ("увімк" if arrows_on else "вимк")
	b_arrows.custom_minimum_size = Vector2(220, 64)
	b_arrows.add_theme_font_size_override("font_size", 22)
	b_arrows.pressed.connect(func():
		s.set_setting("arrows", not bool(s.setting("arrows", AgeAdapt.current == "young")))
		b_arrows.text = "Стрілки: %s" % ("увімк" if bool(s.setting("arrows", true)) else "вимк"))
	ctl.add_child(b_arrows)
	var b_joy := Button.new()
	b_joy.text = "Джойстик: %s" % ("увімк" if joy_on else "вимк")
	b_joy.custom_minimum_size = Vector2(220, 64)
	b_joy.add_theme_font_size_override("font_size", 22)
	b_joy.pressed.connect(func():
		s.set_setting("joystick", not bool(s.setting("joystick", true)))
		b_joy.text = "Джойстик: %s" % ("увімк" if bool(s.setting("joystick", true)) else "вимк"))
	ctl.add_child(b_joy)
	# розмиття планів + блум (GDD v1.5 §3): «гарно» на новіших пристроях, «швидко» — на слабких
	var blur_on := bool(s.setting("fx_blur", true))
	var b_blur := Button.new()
	b_blur.text = "Розмиття (гарно/швидко): %s" % ("гарно" if blur_on else "швидко")
	b_blur.custom_minimum_size = Vector2(320, 64)
	b_blur.add_theme_font_size_override("font_size", 22)
	b_blur.pressed.connect(func():
		var on := not bool(s.setting("fx_blur", true))
		s.set_setting("fx_blur", on)
		var run := get_parent()
		if run != null and run.has_method("set_fx_blur"):
			run.call("set_fx_blur", on)
		b_blur.text = "Розмиття (гарно/швидко): %s" % ("гарно" if on else "швидко"))
	ctl.add_child(b_blur)
	var b_tut := Button.new()
	b_tut.text = "Скинути підказки"
	b_tut.custom_minimum_size = Vector2(240, 64)
	b_tut.add_theme_font_size_override("font_size", 22)
	b_tut.pressed.connect(func():
		s.child()["learned"] = {}
		s.save_game()
		b_tut.text = "Скинуто ✓")
	ctl.add_child(b_tut)
	var buy := Button.new()
	buy.text = "Купити «Повну гру» (4,99 $)"
	buy.custom_minimum_size = Vector2(400, 80)
	buy.add_theme_font_size_override("font_size", 24)
	buy.pressed.connect(_request_buy)
	v.add_child(buy)
	var back := Button.new()
	back.text = "Назад"
	back.custom_minimum_size = Vector2(200, 80)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(_close_parents)
	v.add_child(back)
