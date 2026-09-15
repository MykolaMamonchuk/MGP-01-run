# CartoonMouth3DIntegrated — Godot 4.5

Improved 3D mouth component designed to visually merge with a Meshy animal face.

## Structure

```text
CartoonMouth3DIntegrated
├── Socket
├── MouthInside
├── UpperLip
└── LowerJawPivot
    ├── LowerLip
    └── Tongue
```

## Main improvement

The component is meant to be partially embedded into the character muzzle.

Use:

`embed_depth`

to push the mouth back into the face.

Use:

`socket_color`

to match the character muzzle/fur color.

The socket is slightly larger than the mouth and hides the seam around the attachment.

## Recommended setup per character

1. Add the component under `MouthSocket`.
2. Position it on the muzzle.
3. Rotate it to match the local face surface.
4. Set `socket_color` close to the character's muzzle color.
5. Increase `embed_depth` until the mouth no longer looks detached.
6. Tune `mouth_width`, `mouth_height`, `mouth_depth`.
7. Test opening and chewing from the side camera too.

Example:

```text
Fox
└── FaceRig
    ├── LeftEyeSocket
    │   └── CartoonEye3D
    ├── RightEyeSocket
    │   └── CartoonEye3D
    └── MouthSocket
        └── CartoonMouth3DIntegrated
```

## Runtime API

```gdscript
mouth.open()
mouth.close()
mouth.bite()
mouth.chew(3)
mouth.lick()
mouth.smile()
mouth.neutral()
mouth.eat(3)
```

## Feeding events

```gdscript
mouth.bite_point_reached.connect(_on_bite)
mouth.swallow_finished.connect(_on_swallow)
```

## Important limitation

This does not deform the original Meshy head mesh.

It visually integrates by:
- embedding the component into the muzzle,
- matching the surrounding socket color,
- hiding the seam,
- using real 3D lower-jaw movement.

If you later need the original fox snout itself to bend/deform, that should be done with a jaw bone or blend shapes in the character model.
