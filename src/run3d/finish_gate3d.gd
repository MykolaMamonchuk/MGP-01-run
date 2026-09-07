## Ворота фінішу: два воксельні стовпчики, смугастий банер на всю ширину дороги, прапорці, іскри.
## Дитина Spawner3D — їде разом зі світом (advance), без зіткнень; Spawner3D.check() ловить момент проходу.
class_name FinishGate3D
extends Node3D

const POLE_H := 2.4

var passed := false

var _t := 0.0
var _flags: Array[Node3D] = []
var _banner: Node3D


## lanes — кількість доріжок: ширина банера = Track.LANES_W * lanes / 3.
func setup(lanes: int) -> void:
	var width := Track.LANES_W * float(lanes) / 3.0
	var half := width * 0.5 + 0.35
	for side in [-1.0, 1.0]:
		# стовпчик із «кубиків»
		var pole := Node3D.new()
		pole.position = Vector3(side * half, 0.0, 0.0)
		var n := 6
		var seg_h := POLE_H / float(n)
		for i in range(n):
			var c := Palette.GATE_POST if i % 2 == 0 else Palette.GATE_POST_ALT
			var b := Mats.box(Vector3(0.24, seg_h, 0.24), c)
			b.position.y = seg_h * (float(i) + 0.5)
			pole.add_child(b)
		var cap := Mats.box(Vector3(0.34, 0.16, 0.34), Palette.GATE_CAP)
		cap.position.y = POLE_H + 0.08
		pole.add_child(cap)
		add_child(pole)
		# прапорець на верхівці — розвернутий назовні
		var flag := Node3D.new()
		flag.position = Vector3(side * half, POLE_H + 0.3, 0.0)
		var f := Mats.box(Vector3(0.5, 0.3, 0.04), Palette.GATE_FLAG_LEFT if side < 0.0 else Palette.GATE_FLAG_RIGHT)
		f.position.x = side * 0.3
		flag.add_child(f)
		add_child(flag)
		_flags.append(flag)
	# смугастий банер між стовпчиками
	_banner = Node3D.new()
	_banner.position.y = POLE_H - 0.35
	add_child(_banner)
	var segs := maxi(6, lanes * 2)
	var seg_w := (half * 2.0) / float(segs)
	for i in range(segs):
		var c := Palette.GATE_CHECKER if i % 2 == 0 else Palette.GATE_CHECKER_ALT
		var b := Mats.box(Vector3(seg_w, 0.5, 0.08), c)
		b.position.x = -half + seg_w * (float(i) + 0.5)
		_banner.add_child(b)
	# іскри вздовж банера
	var sp := FX.sparkles(self, half, 24)
	sp.position.y = POLE_H - 0.35


func _process(delta: float) -> void:
	_t += delta
	# прапорці тріпочуть, банер злегка гойдається
	for i in range(_flags.size()):
		_flags[i].rotation.y = sin(_t * 6.0 + float(i) * 1.7) * 0.35
	if _banner:
		_banner.rotation.x = sin(_t * 2.0) * 0.05
		_banner.scale.y = 1.0 + sin(_t * 4.0) * 0.04
