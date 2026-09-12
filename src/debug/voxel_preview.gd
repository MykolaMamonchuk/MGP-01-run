## Debug-сцена: показує ОДИН воксель із data/voxels у порожній кімнаті — або цілого героя
## зі скелетним ригом. У грі не використовується.
## Потрібна, щоб швидко глянути на щойно згенеровану модель (tools/voxelize.py --exact)
## чи на .glb-рига, не чіпаючи data/heroes.json.
##
## Запуск:
##     godot res://src/debug/voxel_preview.tscn                          # fox_voxel
##     VOXEL=fox_voxel godot res://src/debug/voxel_preview.tscn          # будь-яке ім'я з data/voxels
##     RIG=fox_no_voxel godot res://src/debug/voxel_preview.tscn         # герой зі скелетом (біжить)
##     RIG=fox_no_voxel HERO=lys godot res://src/debug/voxel_preview.tscn
##     HERO=olen godot res://src/debug/voxel_preview.tscn                # ВОКСЕЛЬНИЙ герой (без RIG)
##
## У режимі героя (RIG= або HERO=): пробіл — стрибок, D — присід (утримувати), H — удар,
## W — привітатись, R — зупинити/пустити біг, M — підсвітити знайдені бічні нарости
## (сумки: магента — фарбуємо, темно-фіолетовий — купка замала), 1..9 — примусовий стан анімації
## (GDD v1.6 §5: 1 idle · 2 run · 3 sprint · 4 limp · 5 rocket · 6 charge · 7 dance · 8 wave · 9 hit).
## Клавіші 3…7 показують ПОЗУ стану (Hero3D.preview_pose) без геймплейних наслідків —
## ракета в прев'ю висить на 0,25 м, а не злітає на FLY_HEIGHT і не тікає з кадру.
## На старті друкуються всі імена кісток моделі та розкладка ролей — саме їх вписують у
## `rig_bones`, коли автомапа промазала (див. docs/tasks/rig.md).
##
## Якщо файлу нема, VoxelBuilder показує рожевий кубик — це видно одразу.
## Esc — вийти. Воксель повільно крутиться, щоб було видно з усіх боків.
extends Node3D

const DEFAULT_VOXEL := "fox_voxel"
const SPIN_SPEED := 0.5            ## рад/с
## Клавіші 1..9 → примусовий стан анімації (GDD v1.6 §5).
var _state_keys := {
	KEY_1: Hero3D.Anim.IDLE, KEY_2: Hero3D.Anim.RUN, KEY_3: Hero3D.Anim.SPRINT,
	KEY_4: Hero3D.Anim.LIMP, KEY_5: Hero3D.Anim.ROCKET, KEY_6: Hero3D.Anim.CHARGE,
	KEY_7: Hero3D.Anim.DANCE, KEY_8: Hero3D.Anim.WAVE, KEY_9: Hero3D.Anim.HIT,
}
const KEYS_LINE := "  клавіші: Space стрибок · D ковзання (присід) · H удар · W привітання · R біг вкл/викл · P заморозити кістки · M підсвітити бічні нарости (сумки) · 1 idle · 2 run · 3 sprint · 4 limp · 5 rocket · 6 charge · 7 dance · 8 wave · 9 hit · миша/стрілки обертати · 0 скинути · Esc вихід"

var _pivot: Node3D
var _hero: Hero3D


func _ready() -> void:
	var rig := OS.get_environment("RIG")
	var env_name := OS.get_environment("VOXEL")
	var voxel := env_name if env_name != "" else DEFAULT_VOXEL

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.608, 0.867, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.93, 1.0)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, -0.6, 0.0)
	sun.light_energy = 1.1
	add_child(sun)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.7, 2.2)
	cam.rotation = Vector3(-0.1, 0.0, 0.0)
	cam.fov = 55.0
	add_child(cam)
	cam.current = true

	# HERO= без RIG= — воксельний герой (напр. HERO=olen): ті самі клавіші, просто без кісток
	if rig != "" or OS.get_environment("HERO") != "":
		_build_hero_preview(rig)
		return

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_pivot.add_child(VoxelBuilder.instance(voxel))
	print("voxel_preview: %s  (VOXEL=<ім'я> — інший воксель, RIG=<ім'я> — герой зі скелетом, Esc — вийти)" % voxel)


## Живий герой у прев'ю. rig ≠ "" — шукаємо героя з цим ригом (id із HERO сильніший);
## rig == "" — просто воксельний герой HERO=<id>.
func _build_hero_preview(rig: String) -> void:
	var all := Hero3D.defs()
	var id := OS.get_environment("HERO")
	if id == "":
		for k in all.keys():
			var def = all[k]
			if typeof(def) == TYPE_DICTIONARY and String((def as Dictionary).get("rig", "")) == rig:
				id = String(k)
				break
	if id == "":
		id = Hero3D.first_animal_id(all)
	var def2 := Hero3D.resolve_def(all, id)

	_hero = Hero3D.new()
	add_child(_hero)
	_hero.set_hero(id, Palette.of(def2.get("color"), Palette.HERO_DEFAULT),
		String(def2.get("feature", "fox")))
	_hero.ground_y = 0.0
	_hero.x_target = 0.0
	_hero.set_running(true)
	_hero.rotation.y = PI          # мордою до камери

	# основний колір друкуємо як є: у меші має бути рівно він, без «вибілення»
	print("voxel_preview %s герой '%s', основний колір #%s" % [
		("RIG=%s," % rig) if rig != "" else "воксельний",
		id, Palette.of(def2.get("color"), Palette.HERO_DEFAULT).to_html(false)])
	if rig == "":
		print("  воксельне тіло (RIG= не задано)")
		print(KEYS_LINE)
		return
	if not HeroRig.rig_exists(rig):
		push_warning("voxel_preview: нема %s — скопіюй .glb (див. docs/tasks/rig.md)" % HeroRig.rig_path(rig))
		print("  ФАЙЛУ НЕМА: %s — показую воксельні частини" % HeroRig.rig_path(rig))
		print(KEYS_LINE)
		return
	var r := _hero.rig()
	if r == null:
		print("  риг не зібрався (нема Skeleton3D?) — показую воксельні частини")
		print(KEYS_LINE)
		return
	print("  кістки моделі (%d), позиції спокою в см (перед героя = -z):" % r.bone_names().size())
	for line in r.bone_dump():
		print("    %s" % line)
	# ролі: hips/spine/neck/head/fl/fr/bl/br/ear_l/ear_r/tail + малярські tuft/nose/mane/horn
	print("  розкладка ролей: %s" % r.bone_map())
	if r.style_name() != "":
		print("  стиль розмальовки: %s (див. src/run3d/rig_styles.gd)" % r.style_name())
		for role in ["mane", "horn"]:
			if not r.bone_map().has(role):
				print("    роль '%s' кістками не задана — працює геометричний запасний варіант" % role)
	# скільки ГРАНЕЙ у кожній зоні: o основний · d животик · c морда й кінчик хвоста ·
	# k копитця й носик · i серединка вуха · e зовнішній бік вуха · t чубчик ·
	# u основа чубчика (обідок між вухами) · m торбинка,
	# і зони стилю: w пояси/веселка (грива й хвіст) · h ріг · p копитця стилю ·
	# r сердечко на грудях · g пастельні латки · s зірочки.
	# Нуль у "c" — морда не пофарбувалась, нуль у "m" — торбинку не знайшли (rig_zones.bag_x),
	# усе в "o" — ролі кісток не розклались (див. rig_bones у docs/tasks/rig.md)
	var zc := r.zone_counts()
	var parts := PackedStringArray()
	for sym in ["o", "d", "c", "k", "i", "e", "t", "u", "m", "w", "h", "p", "r", "g", "s", "M"]:
		if zc.has(sym):
			parts.append("%s=%d" % [sym, int(zc[sym])])
	print("  грані по зонах: %s" % ", ".join(parts))
	print("  %s" % r.face_report())
	print(KEYS_LINE)


## Обертання мишкою (ліва кнопка + рух) і стрілками — навколо X і Y; P — заморозити кістки в позі спокою.
var _orbit := Vector2.ZERO
var _dragging := false


func _process(delta: float) -> void:
	if _pivot != null and not _dragging and _orbit == Vector2.ZERO:
		_pivot.rotation.y += SPIN_SPEED * delta
	var target: Node3D = _pivot if _pivot != null else _hero
	if target != null and _orbit != Vector2.ZERO:
		target.rotation.x = _orbit.x
		target.rotation.y = _orbit.y + (PI if _hero != null else 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		return
	if event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_orbit.y += mm.relative.x * 0.01
		_orbit.x = clampf(_orbit.x - mm.relative.y * 0.01, -1.4, 1.4)   # тягнемо вниз — фігура нахиляється вниз
		return
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if k.pressed and not k.echo:
		match k.keycode:
			KEY_LEFT: _orbit.y -= 0.2
			KEY_RIGHT: _orbit.y += 0.2
			KEY_UP: _orbit.x = clampf(_orbit.x - 0.2, -1.4, 1.4)
			KEY_DOWN: _orbit.x = clampf(_orbit.x + 0.2, -1.4, 1.4)
			KEY_P:
				if _hero != null and _hero.rig() != null:
					_hero.rig().frozen = not _hero.rig().frozen
					print("  кістки %s" % ("заморожені (поза спокою)" if _hero.rig().frozen else "анімуються"))
			KEY_M:
				# діагностика пошуку сумок: купки бічних наростів — магентою, замалі
				# кандидати — темно-фіолетовим (див. HeroRig.toggle_debug_sides)
				if _hero != null and _hero.rig() != null:
					var on: bool = _hero.rig().toggle_debug_sides()
					print("  підсвітка бічних наростів %s" % ("УВІМКНЕНА" if on else "вимкнена"))
					for item in _hero.rig().side_info():
						var c: Dictionary = item
						print("    купка: %d граней, бік %s, %s" % [
							int(c["n"]), "лівий" if int(c["side"]) < 0 else "правий",
							"фарбуємо" if bool(c["ok"]) else "замала (див. SIDE_MIN_FACES)"])
			KEY_0: _orbit = Vector2.ZERO
	if k.keycode == KEY_ESCAPE and k.pressed:
		get_tree().quit()
		return
	if _hero == null:
		return
	if k.keycode == KEY_D:
		_hero.set_duck(k.pressed)      # присід — поки тримають клавішу
		return
	if not k.pressed or k.echo:
		return
	if _state_keys.has(k.keycode):
		_force_state(int(_state_keys[k.keycode]))
		return
	match k.keycode:
		KEY_SPACE: _hero.jump()
		KEY_H: _hero.hit_reaction(1)
		KEY_W: _hero.wave_hello()
		KEY_R: _hero.set_running(not _hero.running)


## Примусовий стан анімації з клавіш 1..9 — виключно через публічний API героя.
## Клавіші 3…7 показують ПОЗУ стану (`Hero3D.preview_pose`), а не запускають геймплей:
## інакше «5 ракета» кликала б `fly()` і герой злітав би на FLY_HEIGHT = 1,9 м за межі кадру.
## Тут поза тримається, поки не натиснуть іншу клавішу, — так її зручно роздивлятись.
func _force_state(a: int) -> void:
	if _hero == null:
		return
	if a == Hero3D.Anim.HIT:
		_hero.hit_reaction(1)
	elif a == Hero3D.Anim.WAVE:
		_reset_anim_flags(false)
		_hero.wave_hello()
	elif a == Hero3D.Anim.DANCE:
		_reset_anim_flags(false)
		_hero.preview_pose(Hero3D.Anim.DANCE)
	elif a == Hero3D.Anim.CHARGE:
		_reset_anim_flags(true)
		_hero.preview_pose(Hero3D.Anim.CHARGE)
	elif a == Hero3D.Anim.ROCKET:
		_reset_anim_flags(true)
		_hero.preview_pose(Hero3D.Anim.ROCKET)
	elif a == Hero3D.Anim.LIMP:
		_reset_anim_flags(true)
		_hero.preview_pose(Hero3D.Anim.LIMP)
	elif a == Hero3D.Anim.SPRINT:
		_reset_anim_flags(true)
		_hero.preview_pose(Hero3D.Anim.SPRINT)
	elif a == Hero3D.Anim.RUN:
		_reset_anim_flags(true)
	else:
		_reset_anim_flags(false)
	# каденція фіксована (GDD v1.7): показуємо її прямо тут, щоб було з чим звіряти око
	print("  стан: %s, каденція %.2f Гц" % [_hero.anim_name(), _hero.cadence()])


func _reset_anim_flags(run: bool) -> void:
	_hero.stop_fly()
	_hero.set_sprint(false)
	_hero.set_limp(false)
	_hero.set_running(run)
