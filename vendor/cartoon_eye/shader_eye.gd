## Вендорний компонент ока (плаский квад + шейдер), принесений на пробу — ще НЕ інтегрований
## з Hero3D. Наш робочий CartoonEye (src/run3d/eye/) лишається; це — окрема, незалежна
## сцена для порівняння. Клас навмисно НЕ "CartoonEye" — це ім'я вже зайняте нашим.
@tool
extends Node3D
class_name ShaderEye

@export_group("Eye")
@export var sclera_color := Color(1.0, 0.98, 0.95):
    set(value):
        sclera_color = value
        _set_shader("sclera_color", value)

@export var rim_color := Color("#33211A"):
    set(value):
        rim_color = value
        _set_shader("rim_color", value)

@export_range(0.5, 1.5, 0.01) var eye_width := 1.0:
    set(value):
        eye_width = value
        _set_shader("eye_width", value)

@export_range(0.5, 1.6, 0.01) var eye_height := 1.0:
    set(value):
        eye_height = value
        _set_shader("eye_height", value)

@export_group("Iris")
@export var iris_color := Color("#6B3D26"):
    set(value):
        iris_color = value
        _set_shader("iris_color", value)

@export_range(0.2, 0.95, 0.01) var iris_size := 0.67:
    set(value):
        iris_size = value
        _set_shader("iris_size", value)

@export_group("Pupil")
@export var pupil_color := Color("#1B0E0A"):
    set(value):
        pupil_color = value
        _set_shader("pupil_color", value)

@export_range(0.1, 0.9, 0.01) var pupil_size := 0.55:
    set(value):
        pupil_size = value
        _set_shader("pupil_size", value)

@export_group("Highlights")
@export var highlight_color := Color.WHITE:
    set(value):
        highlight_color = value
        _set_shader("highlight_color", value)

@export var big_highlight_pos := Vector2(-0.28, -0.28):
    set(value):
        big_highlight_pos = value
        _set_shader("big_highlight_pos", value)

@export_range(0.01, 0.35, 0.01) var big_highlight_size := 0.13:
    set(value):
        big_highlight_size = value
        _set_shader("big_highlight_size", value)

@export var small_highlight_pos := Vector2(0.30, 0.28):
    set(value):
        small_highlight_pos = value
        _set_shader("small_highlight_pos", value)

@export_range(0.005, 0.2, 0.005) var small_highlight_size := 0.055:
    set(value):
        small_highlight_size = value
        _set_shader("small_highlight_size", value)

@export_group("Gaze")
@export_range(-1.0, 1.0, 0.01) var gaze_x := 0.0:
    set(value):
        gaze_x = value
        _update_gaze()

@export_range(-1.0, 1.0, 0.01) var gaze_y := 0.0:
    set(value):
        gaze_y = value
        _update_gaze()

@export_group("Blink")
@export_range(0.0, 1.0, 0.01) var blink_amount := 0.0:
    set(value):
        blink_amount = value
        _set_shader("blink", value)

@export var auto_blink := true
@export_range(1.0, 10.0, 0.1) var blink_interval_min := 2.0
@export_range(1.0, 10.0, 0.1) var blink_interval_max := 5.5
@export_range(0.05, 0.5, 0.01) var blink_duration := 0.16

@export_group("Depth")
## На скільки метрів око «виграє» перевірку глибини в сусідньої геометрії. Потрібно, бо око —
## пласке, а голова опукла: власна випуклість очниці моделі інакше пробиває його наскрізь.
## Завелике — око почне визирати з-за писка в профіль (перевірено: на 0.015 вже помітно).
## Для лиса вивірено 0.005: далеке око видно цілим, і воно ще не «наїжджає» на морду.
@export_range(0.0, 0.05, 0.001) var depth_bias := 0.005:
    set(value):
        depth_bias = value
        _set_shader("depth_bias", value)

@onready var eye_surface: MeshInstance3D = $EyeSurface

var _material: ShaderMaterial
var _blink_timer := 0.0

func _ready() -> void:
    _ensure_material()
    _sync_all()
    _schedule_next_blink()

func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        return

    if auto_blink:
        _blink_timer -= delta
        if _blink_timer <= 0.0:
            blink()
            _schedule_next_blink()

func look_at_offset(offset: Vector2) -> void:
    gaze_x = clamp(offset.x, -1.0, 1.0)
    gaze_y = clamp(offset.y, -1.0, 1.0)

func blink() -> void:
    if not is_inside_tree():
        return

    var tween := create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)

    tween.tween_property(self, "blink_amount", 1.0, blink_duration * 0.5)
    tween.tween_property(self, "blink_amount", 0.0, blink_duration * 0.5)

func set_expression_neutral() -> void:
    eye_width = 1.0
    eye_height = 1.0
    pupil_size = 0.55

func set_expression_surprised() -> void:
    # той самий відносний "витяг" вгору, що й був (×1.05 / ×1.113 від нейтрального),
    # просто нейтральне тепер кругле (1.0/1.0), а не овальне (1.0/1.15)
    eye_width = 1.05
    eye_height = 1.11
    pupil_size = 0.42

func _schedule_next_blink() -> void:
    _blink_timer = randf_range(blink_interval_min, blink_interval_max)

func _ensure_material() -> void:
    if not is_instance_valid(eye_surface):
        return

    var current := eye_surface.get_active_material(0)
    if current is ShaderMaterial:
        # Duplicate so every instantiated eye has independent runtime parameters.
        _material = current.duplicate() as ShaderMaterial
        eye_surface.material_override = _material

func _set_shader(parameter: StringName, value: Variant) -> void:
    if not is_instance_valid(_material):
        if is_inside_tree():
            _ensure_material()
        else:
            return

    if is_instance_valid(_material):
        _material.set_shader_parameter(parameter, value)

func _update_gaze() -> void:
    _set_shader("gaze", Vector2(gaze_x, gaze_y))

func _sync_all() -> void:
    _set_shader("sclera_color", sclera_color)
    _set_shader("rim_color", rim_color)
    _set_shader("eye_width", eye_width)
    _set_shader("eye_height", eye_height)
    _set_shader("iris_color", iris_color)
    _set_shader("iris_size", iris_size)
    _set_shader("pupil_color", pupil_color)
    _set_shader("pupil_size", pupil_size)
    _set_shader("highlight_color", highlight_color)
    _set_shader("big_highlight_pos", big_highlight_pos)
    _set_shader("big_highlight_size", big_highlight_size)
    _set_shader("small_highlight_pos", small_highlight_pos)
    _set_shader("small_highlight_size", small_highlight_size)
    _update_gaze()
    _set_shader("blink", blink_amount)
    _set_shader("depth_bias", depth_bias)
