## Інтерфейс дім-діорами (GDD v1.4 §10): лічильник злитків, кругла «назад», великі ◀ ▶ між світами,
## ряд фішок рівнів цього світу і зелена «Біжимо!». Плюс підтвердження купівлі будиночка.
## Малює лише UI — усе, що знає про світ і рівні, приходить ззовні (Diorama).
## Кнопки — не менші за 96 px (дитячий палець), кольори — з Palette, стилі — з UIKit.
class_name DioramaUI
extends CanvasLayer

signal back_pressed
signal go_pressed
signal level_pressed(num: int)
signal world_arrow(dir: int)
signal buy_confirmed
signal buy_cancelled

const CHIP := Vector2(112, 112)
const ARROW := Vector2(120, 120)
const ROUND := Vector2(96, 96)

var _root: Control
var _ingot_label: Label
var _title: Label
var _back: Button
var _left: Button
var _right: Button
var _go: Button
var _chips: HBoxContainer
var _dim: Control
var _panel: Panel
var _panel_pic: Control
var _panel_name: Label
var _panel_price: Label
var _panel_box: VBoxContainer
## Ділянки замкнених світів: стрілка є, але з замочком — тап лише трясе.
var _left_open := true
var _right_open := true
## «Біжимо!» дихає вічним твіном — заводимо його лише при першому відкритті.
var _pulsing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 7
	visible = false
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# ліворуч угорі — скільки всього злитків
	var purse := HBoxContainer.new()
	purse.position = Vector2(32, 28)
	purse.add_theme_constant_override("separation", 8)
	purse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purse.add_child(Icons.VoxelIcon.new("ingot", 56.0))
	_ingot_label = UIKit.title("0", 44)
	purse.add_child(_ingot_label)
	_root.add_child(purse)

	# праворуч угорі — кругла «назад» (у меню)
	_back = UIKit.button("‹", Palette.BTN_BACK, ROUND, 48)
	_round(_back)
	_back.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_back.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_back.offset_left = -32
	_back.offset_right = -32
	_back.offset_top = 28
	_back.offset_bottom = 28
	_back.tooltip_text = "Назад у меню"
	_back.pressed.connect(func(): AudioMgr.sfx("ui_tap"); back_pressed.emit())
	_root.add_child(_back)

	_title = UIKit.title("", 56)
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.offset_top = 28
	_title.offset_bottom = 28
	_root.add_child(_title)

	_left = _arrow("◀", -1)
	_left.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_left.grow_vertical = Control.GROW_DIRECTION_BOTH
	_left.offset_left = 30
	_left.offset_right = 30
	_root.add_child(_left)
	_right = _arrow("▶", 1)
	_right.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_right.grow_vertical = Control.GROW_DIRECTION_BOTH
	_right.offset_left = -30
	_right.offset_right = -30
	_root.add_child(_right)

	# знизу: ряд фішок рівнів світу, під ним — велика зелена кнопка
	_chips = HBoxContainer.new()
	_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_chips.add_theme_constant_override("separation", 18)
	_chips.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_chips.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_chips.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_chips.offset_top = -196
	_chips.offset_bottom = -196
	_root.add_child(_chips)

	_go = UIKit.button("Біжимо!", Palette.BTN_PRIMARY, Vector2(360, 128), 52)
	_go.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_go.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_go.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_go.offset_top = -40
	_go.offset_bottom = -40
	_go.pressed.connect(func(): AudioMgr.sfx("ui_play"); go_pressed.emit())
	_root.add_child(_go)

	_build_confirm()


func _arrow(glyph: String, dir: int) -> Button:
	var b := UIKit.button(glyph, Palette.BTN_NAV, ARROW, 56)
	_round(b)
	b.pressed.connect(_on_arrow.bind(dir))
	return b


## Кругла кнопка: радіус = половина сторони.
static func _round(b: Button) -> void:
	var r := int(minf(b.custom_minimum_size.x, b.custom_minimum_size.y) * 0.5)
	for sname in ["normal", "hover", "pressed"]:
		var sb := b.get_theme_stylebox(sname)
		if sb is StyleBoxFlat:
			(sb as StyleBoxFlat).set_corner_radius_all(r)


func _on_arrow(dir: int) -> void:
	var ok := _left_open if dir < 0 else _right_open
	if not ok:
		UIKit.shake(_left if dir < 0 else _right)
		AudioMgr.sfx("locked")
		AudioMgr.voice("locked")
		return
	AudioMgr.sfx("ui_swipe")
	world_arrow.emit(dir)


# ---------- підтвердження купівлі ----------

func _build_confirm() -> void:
	# затемнення перехоплює тапи, доки відкрите питання
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Palette.SHADOW
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	_root.add_child(_dim)

	_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PANEL
	sb.set_corner_radius_all(28)
	sb.set_content_margin_all(24)
	sb.shadow_color = Palette.SHADOW
	sb.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.custom_minimum_size = Vector2(560, 480)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.offset_left = -280
	_panel.offset_right = 280
	_panel.offset_top = -240
	_panel.offset_bottom = 240
	_panel.visible = false
	_root.add_child(_panel)

	_panel_box = VBoxContainer.new()
	_panel_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel_box.add_theme_constant_override("separation", 14)
	_panel_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_panel_box)

	_panel_pic = Icons.VoxelIcon.new("", 160.0)
	_panel_pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel_box.add_child(_panel_pic)

	_panel_name = UIKit.title("", 40, Palette.TEXT)
	_panel_box.add_child(_panel_name)

	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 8)
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_row.add_child(Icons.VoxelIcon.new("ingot", 52.0))
	_panel_price = UIKit.title("0", 44, Palette.TEXT)
	price_row.add_child(_panel_price)
	_panel_box.add_child(price_row)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	_panel_box.add_child(buttons)
	var no := UIKit.button("Ні", Palette.BTN_BACK, Vector2(180, 104), 40)
	no.pressed.connect(func(): AudioMgr.sfx("ui_tap"); hide_confirm(); buy_cancelled.emit())
	buttons.add_child(no)
	var yes := UIKit.button("Так!", Palette.BTN_PRIMARY, Vector2(220, 104), 40)
	yes.pressed.connect(func(): buy_confirmed.emit())
	buttons.add_child(yes)


func show_confirm(name_uk: String, price: int, voxel: String) -> void:
	var pic := Icons.VoxelIcon.new(voxel, 160.0)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel_box.remove_child(_panel_pic)
	_panel_pic.queue_free()
	_panel_pic = pic
	_panel_box.add_child(pic)
	_panel_box.move_child(pic, 0)
	_panel_name.text = name_uk
	_panel_price.text = str(price)
	_dim.visible = true
	_panel.visible = true
	UIKit.pop_in(_panel)


func hide_confirm() -> void:
	_dim.visible = false
	_panel.visible = false


func popup_open() -> bool:
	return _panel != null and _panel.visible


## «Не вистачає злитків»: трясемо панель і підсвічуємо ціну.
func flash_not_enough() -> void:
	UIKit.shake(_panel if popup_open() else _go)
	var tw := _ingot_label.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_ingot_label, "modulate", Palette.MAP_BADGE_FLASH, 0.12)
	tw.tween_interval(0.2)
	tw.tween_property(_ingot_label, "modulate", Palette.WHITE, 0.2)


func shake_go() -> void:
	UIKit.shake(_go)


# ---------- дані ззовні ----------

func open() -> void:
	visible = true
	hide_confirm()
	# «дихання» кнопки — вічний твін, тож заводимо його рівно один раз
	if not _pulsing:
		_pulsing = true
		UIKit.pulse(_go, 0.05, 1.3)


func close() -> void:
	hide_confirm()
	visible = false


func set_stars(n: int) -> void:
	_ingot_label.text = str(n)


## Заголовок світу і чи є куди йти стрілками (замкнений сусід — стрілка з замочком).
func set_world(title: String, prev_open: bool, next_open: bool) -> void:
	_title.text = title
	_left_open = prev_open
	_right_open = next_open
	_lock_arrow(_left, prev_open)
	_lock_arrow(_right, next_open)


func _lock_arrow(b: Button, is_open: bool) -> void:
	b.modulate = Palette.WHITE if is_open else Color(1, 1, 1, 0.75)
	for c in b.get_children():
		if c is LockIcon:
			b.remove_child(c)
			(c as Node).queue_free()
	if not is_open:
		var lock := LockIcon.new()
		lock.position = Vector2(ARROW.x * 0.5 - 14.0, ARROW.y * 0.5 - 16.0)
		b.add_child(lock)


## Фішки рівнів світу: [{num, state ("open"/"buyable"/"locked"), stars, price, color}].
func set_levels(rows: Array) -> void:
	for c in _chips.get_children():
		_chips.remove_child(c)
		c.queue_free()
	for r in rows:
		var row: Dictionary = r
		var num := int(row.get("num", 0))
		var state := String(row.get("state", "locked"))
		var stars := int(row.get("stars", 0))
		var col: Color = row.get("color", Palette.WORLD_ACCENT)
		var b := UIKit.button(str(num) if state == "open" else "", col if state != "locked" else Palette.LOCKED, CHIP, 44)
		b.tooltip_text = String(row.get("name_uk", ""))
		if state == "open":
			b.pressed.connect(_on_chip.bind(num))
		else:
			b.pressed.connect(_on_chip_locked.bind(b))
			var lock := LockIcon.new()
			lock.position = Vector2(CHIP.x * 0.5 - 14.0, CHIP.y * 0.5 - 16.0)
			b.add_child(lock)
			if state == "buyable":
				var badge := PriceBadge.new(int(row.get("price", 0)))
				badge.position = Vector2(CHIP.x * 0.5 - badge.size.x * 0.5, CHIP.y - 26.0)
				b.add_child(badge)
		if stars > 0:
			var srow := HBoxContainer.new()
			srow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			srow.add_theme_constant_override("separation", 2)
			srow.position = Vector2(CHIP.x * 0.5 - 13.0 * stars, 2.0)
			for i in range(stars):
				srow.add_child(Icons.StarIcon.new(24.0))
			b.add_child(srow)
		_chips.add_child(b)
		UIKit.pop_in(b, 0.04 * float(_chips.get_child_count()))


func _on_chip(num: int) -> void:
	AudioMgr.sfx("ui_play")
	level_pressed.emit(num)


## Закритий рівень відкривають на мапі — тут лише «ще рано».
func _on_chip_locked(b: Button) -> void:
	UIKit.shake(b)
	AudioMgr.sfx("locked")
	AudioMgr.voice("locked")
