# CartoonEye — Godot 4.5

Reusable 3D cartoon eye component for character faces.

## Install

Copy this folder to:

res://components/cartoon_eye/

Then instantiate:

res://components/cartoon_eye/CartoonEye.tscn

under your character FaceRig.

Example:

Character
└── FaceRig
    ├── LeftEye  -> CartoonEye.tscn
    └── RightEye -> CartoonEye.tscn

## Inspector controls

Eye:
- sclera color
- rim color
- width / height

Iris:
- color
- size

Pupil:
- color
- size

Highlights:
- color
- positions
- sizes

Gaze:
- gaze_x
- gaze_y

Blink:
- manual blink amount
- automatic blink
- blink interval
- blink duration

## Runtime API

```gdscript
$FaceRig/LeftEye.look_at_offset(Vector2(0.5, -0.2))
$FaceRig/RightEye.look_at_offset(Vector2(0.5, -0.2))

$FaceRig/LeftEye.blink()
$FaceRig/RightEye.blink()
```

Expressions:

```gdscript
$FaceRig/LeftEye.set_expression_surprised()
$FaceRig/RightEye.set_expression_surprised()
```

## Important

This component is a flat 3D eye surface intended to sit slightly in front
of the character's head mesh.

For each character:
1. Position the eye manually.
2. Rotate it to match the face.
3. Scale it to fit the head.
4. Tune width, height, iris size and colors in Inspector.

For mirrored placement, duplicate/instantiate a second eye and rotate/position it
on the opposite side of the face.

If z-fighting appears, move EyeSurface a few millimeters outward from the head.
