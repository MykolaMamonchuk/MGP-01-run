## Веселка-портал на одній доріжці: пробіг крізь неї — політ і дуга зірочок; не хочеш — оминаєш.
## Їде зі світом (дитина Spawner3D), спрацьовує в Spawner3D.check().
class_name Rainbow3D
extends Node3D

const COLORS := Palette.RAINBOW
const RADIUS := 1.15

var lane := 0
var used := false


func _ready() -> void:
	var r := RADIUS
	for i in range(COLORS.size()):
		var mi := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = r - 0.09
		t.outer_radius = r
		t.rings = 40
		t.ring_segments = 8
		mi.mesh = t
		var m := StandardMaterial3D.new()
		m.albedo_color = COLORS[i]
		m.roughness = 0.9
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 0.3
		mi.material_override = m
		mi.rotation.x = PI * 0.5   # вертикальне кільце поперек дороги
		mi.position.y = RADIUS * 0.55
		add_child(mi)
		r -= 0.1
	FX.sparkles(self, 0.9, 16).position.y = RADIUS * 0.55
	scale = Vector3(0.01, 0.01, 0.01)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	rotation.z += delta * 0.6   # повільно крутиться — «магічне» кільце
