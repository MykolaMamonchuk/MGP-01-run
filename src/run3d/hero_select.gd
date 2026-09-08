## Вибір героя: 3D-карусель пухнастиків на дорозі + UI (ім'я, характеристики, як відкрити, стрілки, «Обрати»)
## + крамниця (5 вкладок-слотів, предмети картинками, приміряти безплатно, купити за зірочки).
## Крамниця — ПО-ГЕРОЯМ (GDD v1.3 §5): стрічка показує куплене/одягнуте героєм у центрі; купівля — йому.
## Стрічка предметів — компонент ItemStrip (src/ui/components): гортання, сторінки й свайп живуть там.
## Свайпи каруселі приходять із Run3D (move), тап по героєві — погладити.
class_name HeroSelect
extends Node3D

signal chosen(hero_id: String)
signal closed

const SPACING := 1.7
const ROW_Z := -2.3
const PODIUM_H := 0.18
const STAT_KINDS := ["hearts", "magnet", "speed", "luck"]

var heroes: Dictionary = {}
var ids: Array = []          # у порядку "order"
var index := 0

var _row: Node3D
var _previews: Array[Hero3D] = []
var _ui: CanvasLayer
var _name: Label
var _stats_box: HBoxContainer
var _unlock_box: HBoxContainer
var _unlock_label: Label
var _choose: Button
var _left: Button
var _right: Button
var _back: Button
var _camera: Camera3D
# крамниця
var _shop_btn: Button
var _shop_box: VBoxContainer
var _tabs: HBoxContainer
var _strip: ItemStrip          # стрічка предметів слота (гортання — усередині компонента)
var _buy_btn: Button
var _buy_label: Label
var _items: Array = []
var _slot := "hat"
var _preview_id := ""      # приміряний, але ще не куплений (лише на герої в центрі)
## Карусель і її UI будуються при першому відкритті — див. _build().
var _built := false


func _ready() -> void:
	visible = false
	heroes = load_heroes()
	ids = order_ids(heroes)


## Карусель важка (8 героїв із подіумами — близько 150 мешів і 250 вузлів), а відкривають її
## далеко не щоразу. Тому будуємо при першому open(), а не на старті гри (docs/optimisation OPT-04).
func _build() -> void:
	if _built:
		return
	_built = true
	_row = Node3D.new()
	_row.position.z = ROW_Z
	add_child(_row)
	for i in range(ids.size()):
		var id := String(ids[i])
		var h: Dictionary = heroes[id]
		var color := Palette.of(h.get("color"), Palette.HERO_DEFAULT)
		var p := Hero3D.new()
		_row.add_child(p)
		p.set_hero(id, color, String(h.get("feature", "tuft")))
		p.position.x = float(i) * SPACING
		p.x_target = p.position.x   # інакше _process героя стягне всіх у x = 0
		p.position.y = PODIUM_H
		p.ground_y = PODIUM_H
		p.rotation.y = PI          # обличчям до камери
		_previews.append(p)
		# подіум стоїть НА землі (не врізається — інакше z-fighting «блимає»)
		var podium := Mats.box(Vector3(1.1, PODIUM_H, 1.1), color.lightened(0.35))
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
## Старі пухнастики v1.4 (`"legacy": true`) у каруселі не показуємо — вони лишились у даних лише
## заради збережень (Hero3D малює замість них першого звірятка), тому карусель — це шість нових героїв.
static func order_ids(h: Dictionary) -> Array:
	var out := []
	for k in h.keys():
		if String(k).begins_with("_") or k == "growth":
			continue
		var def = h[k]
		if typeof(def) == TYPE_DICTIONARY and bool((def as Dictionary).get("legacy", false)):
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


## Чиста функція: характеристики героя (GDD v1.3 §5) з дефолтами {hearts 3, magnet 1.0, speed 1.0, luck 1.0}.
static func stats_of(heroes_dict: Dictionary, id: String) -> Dictionary:
	var out := {"hearts": 3, "magnet": 1.0, "speed": 1.0, "luck": 1.0}
	var h = heroes_dict.get(id, {})
	if typeof(h) != TYPE_DICTIONARY:
		return out
	var s = (h as Dictionary).get("stats", {})
	if typeof(s) != TYPE_DICTIONARY:
		return out
	for k in out.keys():
		if (s as Dictionary).has(k):
			out[k] = int(s[k]) if k == "hearts" else float(s[k])
	return out


## Чиста функція: скільки крапок (1..4) показати для характеристики: серця — кількість; інші — (v − 0,9) / 0,1.
static func stat_dots(kind: String, value: float) -> int:
	if kind == "hearts":
		return clampi(roundi(value), 1, 4)
	return clampi(roundi((value - 0.9) / 0.1 + 0.0001), 1, 4)


## Характеристики героя в центрі каруселі.
func current_stats() -> Dictionary:
	if ids.is_empty():
		return stats_of(heroes, "")
	return stats_of(heroes, String(ids[index]))


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

	# характеристики: іконка + крапки, без тексту
	_stats_box = HBoxContainer.new()
	_stats_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_stats_box.add_theme_constant_override("separation", 22)
	_stats_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_stats_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stats_box.offset_top = 132
	_stats_box.offset_bottom = 132
	_stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stats_box)

	_unlock_box = HBoxContainer.new()
	_unlock_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_unlock_box.add_theme_constant_override("separation", 10)
	_unlock_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_unlock_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_unlock_box.offset_top = 184
	_unlock_box.offset_bottom = 184
	_unlock_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_unlock_box)
	_unlock_box.add_child(Icons.StarIcon.new(44.0))
	_unlock_label = UIKit.title("", 34, Palette.TEXT_LIGHT)
	_unlock_box.add_child(_unlock_label)

	_left = UIKit.button("‹", Palette.BTN_NAV, Vector2(110, 110), 64)
	_left.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_left.grow_vertical = Control.GROW_DIRECTION_BOTH
	_left.offset_left = 30
	_left.offset_right = 30
	_left.pressed.connect(func(): move(-1))
	root.add_child(_left)
	_right = UIKit.button("›", Palette.BTN_NAV, Vector2(110, 110), 64)
	_right.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_right.grow_vertical = Control.GROW_DIRECTION_BOTH
	_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_right.offset_left = -30
	_right.offset_right = -30
	_right.pressed.connect(func(): move(1))
	root.add_child(_right)

	_choose = UIKit.button("Обрати", Palette.BTN_PRIMARY, Vector2(340, 120), 48)
	_choose.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_choose.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_choose.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choose.offset_top = -40
	_choose.offset_bottom = -40
	_choose.pressed.connect(_on_choose)
	root.add_child(_choose)

	# крамниця: кнопка-перемикач (праворуч угорі) і панель унизу замість «Обрати»
	_shop_btn = UIKit.button("Крамниця", Palette.BTN_SHOP, Vector2(260, 84), 30)
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
		var tab := UIKit.button("", Palette.BTN_NAV, Vector2(88, 88), 20)
		tab.tooltip_text = _slot_name(slot)
		var ic := Icons.SlotIcon.new(slot, 60.0)
		ic.position = Vector2(14, 12)
		tab.add_child(ic)
		tab.pressed.connect(_select_slot.bind(slot))
		_tabs.add_child(tab)

	_strip = ItemStrip.new()
	_shop_box.add_child(_strip)

	# «Купити N★»: велика кнопка з зірочкою і числом, без слів
	_buy_btn = UIKit.button("", Palette.BTN_HEROES, Vector2(300, 96), 34)
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

	_back = UIKit.button("‹ Назад", Palette.BTN_BACK, Vector2(200, 80), 30)
	_back.position = Vector2(140, 32)   # праворуч від кнопки батьків у HUD
	_back.pressed.connect(func(): AudioMgr.sfx("ui_tap"); close())
	root.add_child(_back)


func open(camera: Camera3D, current_id: String) -> void:
	_build()
	_camera = camera
	visible = true
	_ui.visible = true
	index = maxi(0, ids.find(current_id))
	_row.position.x = -float(index) * SPACING
	_shop_box.visible = false
	_buy_btn.visible = false
	_choose.visible = true
	_preview_id = ""
	_refresh(true)
	AudioMgr.voice("choose_hero")


func close() -> void:
	visible = false
	if not _built:
		closed.emit()
		return
	_ui.visible = false
	# приміряне, але не куплене — знімаємо; кожному герою — його власне
	_revert_try_on()
	_preview_id = ""
	closed.emit()


func move(dir: int) -> void:
	if not _built:
		return   # карусель будується лише при open()
	var next := clampi(index + dir, 0, ids.size() - 1)
	if next == index:
		# край каруселі — легкий відскок
		var tw := create_tween()
		tw.tween_property(_row, "position:x", -float(index) * SPACING - float(dir) * 0.25, 0.1)
		tw.tween_property(_row, "position:x", -float(index) * SPACING, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	# приміряне на попередньому герої — знімаємо
	_revert_try_on()
	index = next
	AudioMgr.sfx("ui_swipe")
	var tw := create_tween()
	tw.tween_property(_row, "position:x", -float(index) * SPACING, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_refresh(false)
	# крамниця відкрита — стрічка показує спорядження нового героя
	if _shop_box.visible:
		_rebuild_strip()
		call_deferred("_pop_items")


## Зняти приміряне (лише з героя в центрі) і сховати «Купити».
func _revert_try_on() -> void:
	if _preview_id != "":
		Shop.apply_to(_previews[index])
		_preview_id = ""
	_buy_btn.visible = false


func _refresh(instant: bool) -> void:
	var id := String(ids[index])
	var h: Dictionary = heroes[id]
	var unlocked := _unlocked(id)
	_name.text = String(h.get("name_uk", id))
	_fill_stats(stats_of(heroes, id))
	_unlock_box.visible = not unlocked
	var hint := unlock_hint(h)
	_unlock_label.text = hint
	# зірочка — лише коли ціна в зірочках
	(_unlock_box.get_child(0) as Control).visible = hint.is_valid_int()
	_choose.text = "Обрати" if unlocked else "Ще не відкрито"
	_choose.modulate = Palette.WHITE if unlocked else Color(1, 1, 1, 0.75)
	_left.visible = index > 0
	_right.visible = index < ids.size() - 1
	for i in range(_previews.size()):
		var p := _previews[i]
		# кожен прев'ю носить лише СВОЄ спорядження (нічого чужого не «перетікає»)
		Shop.apply_to(p)
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
		UIKit.pop_in(_stats_box, 0.05)


## Ряд характеристик: іконка + 1–4 крапки на кожну.
func _fill_stats(st: Dictionary) -> void:
	for c in _stats_box.get_children():
		_stats_box.remove_child(c)
		c.queue_free()
	for k in STAT_KINDS:
		var kind := String(k)
		var cell := HBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 6)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := Icons.StatIcon.new(kind, 36.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(ic)
		var dots := Icons.StatDots.new(stat_dots(kind, float(st.get(kind, 1.0))), 14.0)
		dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(dots)
		_stats_box.add_child(cell)


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


## Герой, для якого зараз крамниця (у центрі каруселі).
func _shop_hero() -> String:
	return String(ids[index]) if not ids.is_empty() else "lys"


## Показати/сховати панель крамниці (замість «Обрати» — щоб не перекривати героя).
func _toggle_shop() -> void:
	AudioMgr.sfx("ui_tap")
	if _shop_box.visible:
		_shop_box.visible = false
		_choose.visible = true
		# приміряне й не куплене — знімаємо
		_revert_try_on()
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
		_revert_try_on()
	_slot = slot
	var i := 0
	for t in _tabs.get_children():
		var active := String(Shop.SLOTS[i]) == slot
		(t as Control).modulate = Palette.WHITE if active else Color(0.8, 0.8, 0.8, 0.85)
		UIKit.frame(t as Button, Palette.TAB_ACTIVE if active else Palette.CLEAR)
		i += 1
	_rebuild_strip()


## Стрічка предметів слота для героя в центрі: картинка + ціна (є — без ціни; одягнуто — зелена рамка). Без назв.
## reset — стати на початок стрічки; false — лишитись там, де були (після купівлі/одягання).
func _rebuild_strip(reset: bool = true) -> void:
	var cards: Array[Control] = []
	var hid := _shop_hero()
	var owned := Shop.owned(hid)
	var current := Shop.equipped(hid, _slot)
	for it in Shop.by_slot(_items, _slot):
		var id := String(it["id"])
		var is_owned := Shop.is_owned(it, owned)
		var b := UIKit.button("", Palette.PANEL, Vector2(124, 132), 20)
		b.tooltip_text = String(it.get("name_uk", id))
		b.mouse_filter = Control.MOUSE_FILTER_PASS   # свайп по кнопці доходить до стрічки
		UIKit.frame(b, Palette.ITEM_EQUIPPED if id == current else (Palette.ITEM_OWNED if is_owned else Palette.ITEM_PLAIN))
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 4)
		b.add_child(col)
		var pic := Icons.VoxelIcon.new(String(it.get("voxel", "")), 72.0, Palette.of(it.get("color"), Palette.CLEAR))
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
		cards.append(b)
	_strip.set_cards(cards, reset)


## Пружна поява карток після відкриття крамниці / зміни вкладки.
func _pop_items() -> void:
	_strip.pop_in_cards()


func _on_item_tap(id: String) -> void:
	if _strip.drag_moved():
		return   # це був свайп стрічки, не тап
	var def := Shop.find(_items, id)
	if def.is_empty():
		return
	var hid := _shop_hero()
	var p := _previews[index]
	Shop.apply_item(p, _slot, def)      # приміряти можна завжди (лише герой у центрі)
	p.cheer()
	if Shop.is_owned_by(def, hid):
		Shop.equip(hid, _slot, id)
		_preview_id = ""
		_buy_btn.visible = false
		AudioMgr.sfx("ui_play")
		_rebuild_strip(false)   # нове «одягнуто», місце в стрічці не втрачаємо
	else:
		_preview_id = id
		_buy_label.text = str(int(def.get("price", 0)))
		_buy_btn.visible = true
		UIKit.pop_in(_buy_btn)
		AudioMgr.voice("try_on")


func _on_buy() -> void:
	if _preview_id == "":
		return
	var hid := _shop_hero()
	var def := Shop.find(_items, _preview_id)
	if Shop.buy(def, hid):
		Shop.equip(hid, _slot, _preview_id)
		Events.star_collected.emit(0)   # HUD перерахує зірочки
		FX.confetti(_row, Vector3(float(index) * SPACING, 1.2, 0.0), 60)
		AudioMgr.sfx("confetti")
		AudioMgr.voice("new_hat")
		_preview_id = ""
		_buy_btn.visible = false
		_rebuild_strip(false)
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
