# Prop prompts — copy & paste

Ready-to-paste prompts for the world 1 props (riverside town). Each block is complete —
subject plus the canonical style tail. Nothing to assemble.

Ukrainian version with sizes, gameplay actions and the queue: `docs/tasks/props.md`.
Canonical style source: `docs/refs/README.md` §0.

## Generator settings

| | |
|---|---|
| Mode | Image to 3D (preferred) or Text to 3D |
| Quality | high |
| Topology | quad |
| Polycount | ≤ 12k |
| Texture | **on** (props and buildings keep their texture; heroes do not) |
| Rig | **off** for every prop below except `goose` |

## Hard requirements

- **One mesh, one material.** Decor is drawn in `MultiMesh` batches and only the first
  `MeshInstance3D` is taken — a model split into parts loses everything else.
- **Origin at the bottom centre** — props are placed on the ground.
- **No baked eyes** on animals. Eyes are drawn by our own face overlay and painted ones
  show through it.
- Size does not need to be exact. Proportions matter; the final scale and rotation are
  tuned in `data/props.json` (`scale`, `yaw_deg`).

---

## 1. `crate` — jump over

> A cute wooden crate with warm brown planks and simple iron corner braces, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

## 2. `barrel` — dodge sideways

> A cute wooden barrel with warm brown staves and darker metal hoops, standing upright, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

## 3. `cart_market` — dodge sideways

> A cute small wooden market cart on two wheels, loaded with crates and baskets of fruit under a striped cloth, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

## 4. `fence_low` — jump over

> A cute low wooden picket gate with a short fence section on each side, warm brown planks, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

## 5. `puddle` — safe to run through

> A cute shallow puddle of clear water with a soft ripple and a gentle highlight, flat and low on the ground, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

## 6. `bush_flower` — safe to run through

> A cute rounded leafy bush covered in tiny white blossoms, two tones of green, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

## 7. `clothesline` — duck under

> A cute laundry line strung between two wooden poles, with a few small colourful clothes pegged to it, the line high enough to run under, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

## 8. `banner_line` — duck under

> A cute string of small triangular festival flags strung across a village street between two wooden poles, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

## 9. `goose` — dodge sideways · **rig: quadruped / animal, legs apart**

> A cute plump white goose with an orange beak and orange feet, standing with both legs clearly apart, no eyes drawn on the face, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

## 10. `xbox_red` — dodge sideways

> A cute red wooden crate with a big white X painted across the front, warm brown edges, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

---

## Next two — they carry the whole street

These repeat almost every metre of road; without them the level does not read as a street.

## 11. `bridge_plank` — one plank of a canal bridge

> A cute short wooden plank bridge across a narrow canal, warm brown planks with simple side rails, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

## 12. `fence_rail` — rail fence along the canal bank

> A cute low wooden rail fence section running along a grassy canal bank, warm brown posts with two horizontal rails, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

---

## Several different models for one kind

A key may hold a **list** — these are different *types* of the same kind:

```json
"barrel": [
  "res://assets/props/barrel.glb",
  "res://assets/props/barrel_2.glb",
  {"path": "res://assets/props/barrel_3.glb", "scale": 1.1}
]
```

Naming: `barrel.glb` is the first type, then `barrel_2.glb`, `barrel_3.glb`. The suffix means
a DIFFERENT TYPE (a different barrel) — not a variant of the same model and not a second
attempt. Same for crates, rocks, bushes.

**One map, one type.** Types differ in proportion as well as in look (bank rails come at
0.26 m and at 0.41 m tall), so mixing them along one street reads as a bug. Variety belongs
BETWEEN levels: the town gets its own barrels, the forest gets others. The choice is derived
from the map name, so obstacles and decor always agree and it never changes mid-run.

Level markers know nothing about types: the marker still just says `barrel`.

## Putting a finished model into the game

1. Save it as `assets/props/<id>.glb` — the `id` is the heading name above.
2. Add one line to `data/props.json`:
   ```json
   "crate": "res://assets/props/crate.glb"
   ```
   or, if the size or rotation needs tuning:
   ```json
   "crate": {"path": "res://assets/props/crate.glb", "scale": 1.3, "yaw_deg": 90.0}
   ```
3. Open Godot once so it imports the file.

Nothing else changes — level layout, markers and gameplay stay as they are. A prop with no
entry keeps drawing its old placeholder, so the list can be closed one model at a time.
