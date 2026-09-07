## Вибір героя: 3D-карусель пухнастиків на дорозі + UI (ім'я, як відкрити, стрілки, «Обрати»)
## + крамниця (5 вкладок-слотів, предмети картинками, приміряти безплатно, купити за зірочки).
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
# крамниця
var _shop_btn: Button
var _shop_box: VBoxContainer
var _tabs: HBoxContainer
var _scroll: ScrollContainer
var _strip: HBoxContainer
var _buy_btn: Button
var _buy_label: Label
var _items: Array = []
var _slot := "hat"
var _preview_id := ""      # приміряний, але ще не куплений


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

	# крамниця: кнопка-перемикач (праворуч угорі) і панель унизу замість «Обрати»
	_shop_btn = UIKit.button("Крамниця", Color("#AB47BC"), Vector2(260, 84), 30)
	_shop_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_shop_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_shop_btn.offset_left = -30
	_shop_btn.offset_right = -30
	_shop_btn.offset_top = 120
	_shop_btn.offset_bottom = 120
	_shop_btn.pressed.connect(_toggle_shop)
	var shop_glyph := Icons.SlotIcon.new("hat", 44.0)
	shop_glyph.position = Vector2(14, 20)
	_shop_btn.add_child(shop_glyph)
	root.add_child(_shop_btn)

	_shop_box = VBoxContainer.new()
	_shop_box.alignment = BoxContainer.ALIGNMENT_END
	_shop_box.add_theme_constant_override("separation", 10)
	_shop_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_shop_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_shop_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_shop_box.offset_top = -16
	_shop_box.offset_bottom = -16
	_shop_box.visible = false
	root.add_child(_shop_box)
	_tabs = HBoxContainer.new()
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs.add_theme_constant_override("separation", 12)
	_shop_box.add_child(_tabs)
	for s in Shop.SLOTS:
		var slot := String(s)
		var tab := UIKit.button("", Color("#42A5F5"), Vector2(88, 88), 20)
		tab.tooltip_text = _slot_name(slot)
		var ic := Icons.SlotIcon.new(slot, 60.0)
		ic.position = Vector2(14, 12)
		tab.add_child(ic)
		tab.pressed.connect(_select_slot.bind(slot))
		_tabs.add_child(tab)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(1100, 150)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_shop_box.add_child(_scroll)
	_strip = HBoxContainer.new()
	_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_strip.add_theme_constant_override("separation", 10)
	_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_strip)

	# «Купити N★»: велика кнопка з зірочкою і числом, без слів
	_buy_btn = UIKit.button("", Color("#FFA726"), Vector2(300, 96), 34)
	_buy_btn.tooltip_text = "Купити за зірочки"
	_buy_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_buy_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_buy_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# праворуч над панеллю (панель ≈ 250 px знизу), героя в центрі не перекриває
	_buy_btn.offset_left = 300
	_buy_btn.offset_right = 600
	_buy_btn.offset_top = -380
	_buy_btn.offset_bottom = -284
	_buy_btn.visible = false
	_buy_btn.pressed.connect(_on_buy)
	var buy_row := HBoxContainer.new()
	buy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buy_row.add_theme_constant_override("separation", 10)
	buy_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	buy_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buy_btn.add_child(buy_row)
	buy_row.add_child(Icons.StarIcon.new(48.0))
	_buy_label = UIKit.title("0", 44)
	_buy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy_row.add_child(_buy_label)
	root.add_child(_buy_btn)

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
	for p in _previews:
		Shop.apply_to(p)
	_shop_box.visible = false
	_buy_btn.visible = false
	_choose.visible = true
	_preview_id = ""
	_refresh(true)
	AudioMgr.voice("choose_hero")


func close() -> void:
	visible = false
	_ui.visible = false
	# приміряне, але не куплене — знімаємо
	for p in _previews:
		Shop.apply_to(p)
	_preview_id = ""
	closed.emit()


func move(dir: int) -> void:
	var next := clampi(index + dir, 0, ids.size() - 1)
	if next == index:
		# край каруселі — легкий відскок
		var tw := create_tween()
		tw.tween_property(_row, "position:x", -float(index) * SPACING - float(dir) * 0.25, 0.1)
		tw.tween_property(_row, "position:x", -float(index) * SPACING, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	# приміряне на попередньому герої — знімаємо
	if _preview_id != "":
		Shop.apply_to(_previews[index])
		_preview_id = ""
		_buy_btn.visible = false
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


# ---------- крамниця ----------

static func _slot_name(slot: String) -> String:
	match slot:
		"face": return "Окуляри"
		"neck": return "Шарфики"
		"back": return "На спину"
		"trail": return "Слід"
	return "Капелюшки"


## Показати/сховати панель крамниці (замість «Обрати» — щоб не перекривати героя).
func _toggle_shop() -> void:
	AudioMgr.sfx("ui_tap")
	if _shop_box.visible:
		_shop_box.visible = false
		_buy_btn.visible = false
		_choose.visible = true
		# приміряне й не куплене — знімаємо
		if _preview_id != "":
			Shop.apply_to(_previews[index])
			_preview_id = ""
		return
	_items = Shop.load_all()
	_choose.visible = false
	_shop_box.visible = true
	_select_slot(_slot)
	call_deferred("_pop_items")


## Вкладка слота: підсвітити вкладку й перебудувати стрічку предметів.
func _select_slot(slot: String) -> void:
	if slot != _slot:
		AudioMgr.sfx("ui_tap")
		if _preview_id != "":
			Shop.apply_to(_previews[index])
			_preview_id = ""
		_buy_btn.visible = false
	_slot = slot
	var i := 0
	for t in _tabs.get_children():
		var active := String(Shop.SLOTS[i]) == slot
		(t as Control).modulate = Color.WHITE if active else Color(0.8, 0.8, 0.8, 0.85)
		_frame(t as Button, Color("#FFF8E1") if active else Color(0, 0, 0, 0))
		i += 1
	_rebuild_strip()


## Стрічка предметів слота: картинка + ціна (є — без ціни; одягнуто — зелена рамка). Без назв, лише підказка.
func _rebuild_strip() -> void:
	for c in _strip.get_children():
		_strip.remove_child(c)   # одразу з контейнера, інакше кадр подвійної стрічки
		c.queue_free()
	var owned := Shop.owned()
	var current := Shop.equipped(_slot)
	for it in Shop.by_slot(_items, _slot):
		var id := String(it["id"])
		var is_owned := Shop.is_owned(it, owned)
		var b := UIKit.button("", Color("#FFF8E1"), Vector2(124, 132), 20)
		b.tooltip_text = String(it.get("name_uk", id))
		_frame(b, Color("#66BB6A") if id == current else (Color("#90CAF9") if is_owned else Color("#CFD8DC")))
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 4)
		b.add_child(col)
		var pic := Icons.VoxelIcon.new(String(it.get("voxel", "")), 72.0, Color(String(it.get("color", "#00000000"))))
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(pic)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 4)
		row.custom_minimum_size = Vector2(0, 30)
		col.add_child(row)
		if not is_owned:
			row.add_child(Icons.StarIcon.new(26.0))
			row.add_child(UIKit.title(str(int(it.get("price", 0))), 26))
		elif id == current:
			row.add_child(CheckIcon.new(26.0))
		b.pressed.connect(_on_item_tap.bind(id))
		_strip.add_child(b)


## Рамка кнопки предмета (зелена — одягнуто).
static func _frame(b: Button, col: Color) -> void:
	for st in ["normal", "hover", "pressed"]:
		var sb := b.get_theme_stylebox(st)
		if sb is StyleBoxFlat:
			var s := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			s.set_border_width_all(6)
			s.border_color = col
			b.add_theme_stylebox_override(st, s)


## Галочка «одягнуто».
class CheckIcon:
	extends Control
	func _init(px: float = 26.0) -> void:
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var u: float = min(size.x, size.y) / 26.0
		draw_polyline(PackedVector2Array([Vector2(4, 14) * u, Vector2(10, 21) * u, Vector2(23, 5) * u]), Color("#66BB6A"), 5.0 * u)


func _pop_items() -> void:
	var i := 0
	for b in _strip.get_children():
		UIKit.pop_in(b, 0.04 * i)
		i += 1


func _on_item_tap(id: String) -> void:
	var def := Shop.find(_items, id)
	if def.is_empty():
		return
	var p := _previews[index]
	Shop.apply_item(p, _slot, def)      # приміряти можна завжди
	p.cheer()
	if Shop.is_owned(def, Shop.owned()):
		Shop.equip(_slot, id)
		_preview_id = ""
		_buy_btn.visible = false
		AudioMgr.sfx("ui_play")
		_rebuild_strip()   # нове «одягнуто»
	else:
		_preview_id = id
		_buy_label.text = str(int(def.get("price", 0)))
		_buy_btn.visible = true
		UIKit.pop_in(_buy_btn)
		AudioMgr.voice("try_on")


func _on_buy() -> void:
	if _preview_id == "":
		return
	var def := Shop.find(_items, _preview_id)
	if Shop.buy(def):
		Shop.equip(_slot, _preview_id)
		Events.star_collected.emit(0)   # HUD перерахує зірочки
		FX.confetti(_row, Vector3(float(index) * SPACING, 1.2, 0.0), 60)
		AudioMgr.sfx("confetti")
		AudioMgr.voice("new_hat")
		_preview_id = ""
		_buy_btn.visible = false
		_rebuild_strip()
	else:
		UIKit.shake(_buy_btn)
		AudioMgr.sfx("locked")
		AudioMgr.voice("not_enough")


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
