# CartoonEye3D — Godot 4.5

Replacement for the previous flat Quad-based eye.

This version uses real 3D geometry so the eye can be embedded into the character head and look like part of the model.

## Structure

```text
CartoonEye3D
├── Socket
├── Eyeball
├── IrisPivot
│   ├── Iris
│   ├── Pupil
│   ├── HighlightBig
│   └── HighlightSmall
├── UpperLid
└── LowerLid
```

## Why it looks more integrated

The eyeball is a flattened 3D sphere.

The important property is:

`embed_depth`

It pushes most of the eye sphere into the character head, leaving only the front lens visible.

The `Socket` is slightly larger than the eyeball and hides the seam where the eye intersects the head.

## Recommended setup

For each character:

1. Add `CartoonEye3D.tscn` under the FaceRig.
2. Move it onto the face.
3. Rotate it to follow the local head surface.
4. Increase `embed_depth` until roughly 30–60% of the eye is inside the head.
5. Tune width / height / depth.
6. Set `socket_color` close to the character fur/skin color or slightly darker.
7. Repeat independently for left and right eye.

Example:

```text
Fox
└── FaceRig
    ├── LeftEyeSocket
    │   └── CartoonEye3D
    └── RightEyeSocket
        └── CartoonEye3D
```

## Inspector controls

Eyeball:
- width
- height
- depth
- embed depth

Socket:
- enabled
- thickness
- scale
- color

Iris/Pupil:
- colors
- sizes
- iris surface offset

Highlights:
- sizes
- positions

Gaze:
- gaze X/Y
- max gaze range

Blink:
- manual blink
- automatic blink
- interval
- duration

## Runtime

```gdscript
eye.look_at_offset(Vector2(0.6, -0.2))
eye.blink()
```

## Demo

Open:

`demo.tscn`

It includes a simple 3D head sphere with the eye partially embedded in it, plus gaze and blink animation.

## Important

This component does not boolean-cut an actual eye socket into the Meshy head.

It visually integrates by:
- embedding the eye geometry into the head,
- matching the socket color,
- following the face surface rotation,
- hiding the intersection seam.

For most stylized mobile characters this is much cheaper and simpler than modifying the original Meshy topology.
