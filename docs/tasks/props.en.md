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
| Topology | **triangles** — quads matter only for models that deform; ours do not |
| Polycount | **1 500–3 000** — measured: rails at 5 796 tris × 78 segments were 452k of the 595k on screen |
| Texture | **on** (props and buildings keep their texture; heroes do not) |
| Rig | **off** for every prop below except `goose` |
| Background | **none** — a single isolated object, no ground, no shadow, no base |

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

> A cute wooden crate with warm brown planks and simple iron corner braces, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

## 2. `barrel` — dodge sideways

> A cute wooden barrel with warm brown staves and darker metal hoops, standing upright, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

## 3. `cart_market` — dodge sideways

> A cute small wooden market cart on two wheels, loaded with crates and baskets of fruit under a striped cloth, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

## 4. `fence_low` — jump over

> A cute low wooden picket gate with a short fence section on each side, warm brown planks, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

## 5. `puddle` — safe to run through

> A cute shallow puddle of clear water with a soft ripple and a gentle highlight, flat and low on the ground, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

## 6. `bush_flower` — safe to run through

> A cute rounded leafy bush covered in tiny white blossoms, two tones of green, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

## 7. `clothesline` — duck under

> A cute laundry line strung between two wooden poles, with a few small colourful clothes pegged to it, the line high enough to run under, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

## 8. `banner_line` — duck under

> A cute string of small triangular festival flags strung across a village street between two wooden poles, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

## 9. `goose` — dodge sideways · **rig: quadruped / animal, legs apart**

> A cute plump white goose with an orange beak and orange feet, standing with both legs clearly apart, no eyes drawn on the face, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

## 10. `xbox_red` — dodge sideways

> A cute red wooden crate with a big white X painted across the front, warm brown edges, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

---

## Next two — they carry the whole street

These repeat almost every metre of road; without them the level does not read as a street.

## 11. `bridge_plank` — one plank of a canal bridge

> A cute short wooden plank bridge across a narrow canal, warm brown planks with simple side rails, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

## 12. `fence_rail` — rail fence along the canal bank

> A cute low wooden rail fence section running along a grassy canal bank, warm brown posts with two horizontal rails, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

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

## Level 1 buildings — what is left for full likeness
The level already matches the reference at 90%. The one difference still visible is that our
houses are plain blocks without windows, while the reference has timber framing, shutters and
awnings. These four close exactly that gap. Generator: Image to 3D, texture ON, rig OFF, triangles,
1 500–3 000 tris, no background. Do not chase the size — it is fitted during processing.

### 1. `house_red`

> A cute two-storey riverside townhouse with a steep red tile roof, cream plaster walls with dark brown timber framing, small shuttered windows with flower boxes, and a little wooden door, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 2. `house_terra`

> A cute narrow riverside townhouse with a terracotta tile roof, warm sandy plaster walls, tall blue-shuttered windows and a small balcony with a flower box, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 3. `awning_stall`

> A cute small market stall with a green and white striped fabric awning, a wooden counter piled with fruit and vegetable baskets, and a hanging lantern, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 4. `kiosk`

> A cute tiny corner kiosk with a round teal roof, an open wooden serving window with a small counter, and a hand-painted sign board, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.


## Queue for removing voxels — ranked by MEASURED share of the frame

Right now level 1 draws **7 of 44 kinds** with real models; the rest are still voxels. The
order below is not a guess: it is the number of items the track actually places in frame
(`WORLD=meadow DUMP=1 godot res://src/debug/track_shot.tscn` — 215 items in total).

Trees dominate: `pine_3` and `tree_round` together are 37 of those 215 — more than every
other voxel combined.

| # | `kind` | items in frame | what it is |
|---|---|---|---|
| 1 | `tree_round` | 18 | — |
| 2 | `pine_3` | 19 | — |
| 3 | `hay_bale` | 15 | — |
| 4 | `house_terra` | 4 | — |
| 5 | `hut` | 6 | — |
| 6 | `flower_yellow` | 5 | — |
| 7 | `flower_pink` | 5 | — |
| 8 | `mushroom_red` | 5 | — |
| 9 | `rock_grey` | 3 | — |
| 10 | `mill` | 3 | — |
| 11 | `kiosk` | 3 | — |
| 12 | `well` | 2 | — |


### 1. `tree_round` (18 in frame)

> A cute round leafy tree with a chunky brown trunk and a soft rounded crown in two tones of green, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 2. `pine_3` (19 in frame)

> A cute small pine tree with three soft tiers of dark green needles and a short brown trunk, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 3. `hay_bale` (15 in frame)

> A cute round bale of golden hay tied with two rope bands, resting on its side, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 4. `house_terra` (4 in frame)

> A cute narrow riverside townhouse with a terracotta tile roof, warm sandy plaster walls, tall blue-shuttered windows and a small balcony with a flower box, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 5. `hut` (6 in frame)

> A cute tiny cottage with a thatched straw roof, cream plaster walls, one round window and a small wooden door, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 6. `flower_yellow` (5 in frame)

> A cute single cheerful yellow flower with a slim green stem and two small leaves, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 7. `flower_pink` (5 in frame)

> A cute single cheerful pink flower with a slim green stem and two small leaves, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 8. `mushroom_red` (5 in frame)

> A cute plump mushroom with a red cap dotted with white spots and a short cream stem, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 9. `rock_grey` (3 in frame)

> A cute rounded grey boulder with soft facets and a patch of moss on top, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 10. `mill` (3 in frame)

> A cute small windmill with a cream stone tower, a red conical roof and four wooden sails, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 11. `kiosk` (3 in frame)

> A cute tiny corner kiosk with a round teal roof, an open wooden serving window and a small sign, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 12. `well` (2 in frame)

> A cute round stone well with a small wooden roof, a rope and a hanging bucket, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.


## What is still needed — as of 16.09.2026

**Eight kinds already came from you** and are in the game: `barrel` ×3, `crate` ×3,
`fence_low` ×3, `fence_rail` ×3, `cart_market` ×3, `bush_flower` ×2, `bridge_plank`,
`puddle`.

Everything else is currently a **placeholder** built by script (`tools/make_house.py`,
`tools/make_nature.py`): geometry from primitives, no textures. It holds the style and the
weight, but it is not real art. Measured: placeholders are **56% of the items on screen**
(668 of 1187 across all five worlds).

The order below is by MEASURED count on screen, not by feel. The first four close a third
of everything visible.

| # | `kind` | items on screen | types worth making | what it is |
|---|---|---|---|---|
| 1 | `tree_round + tree` | 130 | 3 | round leafy tree |
| 2 | `wall_house` | 95 | 3 | tall street house |
| 3 | `bush` | 75 | 2 | bush |
| 4 | `flower` | 65 | 3 | flower |
| 5 | `mushroom` | 57 | 2 | mushroom |
| 6 | `pine_3` | 40 | 2 | pine tree |
| 7 | `wall_tree_tall` | 39 | 2 | tall background tree |
| 8 | `rock` | 85 | 3 | rock |
| 9 | `awning_stall` | 12 | 2 | market stall |
| 10 | `hut` | 11 | 2 | cottage |
| 11 | `kiosk` | 9 | 1 | corner kiosk |
| 12 | `hay_bale` | 8 | 2 | hay bale |
| 13 | `goose` | 4 | 1 | goose · **rig: quadruped, legs apart** |
| 14 | `mill` | 3 | 1 | windmill |

**"Types worth making"** is how many DIFFERENT models of one kind make sense: a map draws a
single type, so three trees mean three distinct towns, not three trees on one street.

Generator settings and the processing pipeline are earlier in this file. Drop files into
`docs/refs/incoming/<kind>/` — they swap in with no code changes.

### 1. `tree_round + tree` — round leafy tree (130 on screen)

> A cute round leafy tree with a chunky brown trunk and a soft rounded crown in two tones of green, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 2. `wall_house` — tall street house (95 on screen)

> A cute tall two-storey riverside townhouse with a steep red tile roof, cream plaster walls with dark timber framing, shuttered windows with flower boxes and a striped awning over the door, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 3. `bush` — bush (75 on screen)

> A cute rounded leafy bush in two tones of green, dense and soft, no flowers, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 4. `flower` — flower (65 on screen)

> A cute single cheerful flower with a slim green stem, two small leaves and rounded petals, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 5. `mushroom` — mushroom (57 on screen)

> A cute plump mushroom with a rounded cap and a short cream stem, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 6. `pine_3` — pine tree (40 on screen)

> A cute small pine tree with soft tiers of dark green needles and a short brown trunk, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 7. `wall_tree_tall` — tall background tree (39 on screen)

> A cute tall slender tree with a narrow rounded crown, used as a background wall of a forest road, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 8. `rock` — rock (85 on screen)

> A cute rounded boulder with soft facets, warm grey stone, a patch of moss on one side, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 9. `awning_stall` — market stall (12 on screen)

> A cute small market stall with a green and white striped fabric awning, a wooden counter piled with baskets of fruit and vegetables, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 10. `hut` — cottage (11 on screen)

> A cute tiny cottage with a thatched straw roof, cream plaster walls, one round window and a small wooden door, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 11. `kiosk` — corner kiosk (9 on screen)

> A cute tiny corner kiosk with a round teal roof, an open wooden serving window and a hand-painted sign, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 12. `hay_bale` — hay bale (8 on screen)

> A cute round bale of golden hay tied with two rope bands, resting on its side, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 13. `goose` — goose · **rig: quadruped, legs apart** (4 on screen)

> A cute plump white goose with an orange beak and orange feet, standing with both legs clearly apart, no eyes drawn on the face, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.

### 14. `mill` — windmill (3 on screen)

> A cute small windmill with a cream stone tower, a red conical roof and four wooden sails, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures. ISOLATED ASSET: the object alone on a plain empty background, nothing else in frame — no scenery, no ground, no grass, no floor plane, no cast shadow, no base, no pedestal, no props around it, no other objects, no text. One single object, centred, fully visible.


## Налаштування Meshy — підібрані ВИМІРЮВАННЯМ, не з документації

| поле | що ставити | чому саме так |
|---|---|---|
| Режим | Image to 3D (краще) або Text to 3D | з картинки виходить те, що ти бачив; з тексту — лотерея |
| Topology | **Triangles** | квади потрібні лише тому, що деформують. Наші пропси не гнуться; для гри трикутники — стандарт, і Godot усе одно тріангулює |
| Target Polycount | **1 500–3 000** | не 12 тисяч. Заміряно: поручні по 5 796 трикутників × 78 ланок = 452 тисячі з 595 у кадрі. Це вбивало телефон. Мої згенеровані будинки коштують 188 |
| Texture | **on** | пропси й будівлі живуть кольором. Виняток — герої: їм обличчя малює гра |
| Rig | **off** | ріг згинає суцільну шкіру. Ящик або стоїть, або розлітається шматками — і те, й те без рига. Виняток один: гуска (quadruped, лапки нарізно) |
| Формат | **GLB** | один файл із текстурами всередині |

### Про роздільність текстур

Meshy віддає **4096×4096 на кожну з трьох карт** (колір, шорсткість, нормаль) і змінити це
в ньому не можна. Саме через це пакет гри важив 296 МБ. Ми зменшуємо їх самі при обробці
(`--tex-size 512`), тож просто вивантажуй як є — конвеєр упорається.

Виміряно, чому 512 достатньо: на знімку зблизька (×3) 2048 проти 4096 дали 37 різних
пікселів із 435 600, а 1024 — 1381. На ігровій відстані пропс займає сотню пікселів.

### Три вимоги, які ламають усе, якщо їх не дотримати

1. **Один меш, один матеріал.** Гра бере ПЕРШИЙ меш зі сцени й малює його пачкою; модель,
   розбита на частини, втрачає все, крім першої. Якщо Meshy віддав кілька — об'єднай перед
   вивантаженням.
2. **Без вмальованих очей** на тваринах. Обличчя малює сама гра поверх, і намальовані очі
   проступають крізь нього.
3. **Розмір і початок координат не вгадуй.** Ми їх виправляємо самі (`prop_prepare.py`):
   модель має мати правильні ПРОПОРЦІЇ, решта доводиться.

Джерела: [Meshy: low poly](https://www.meshy.ai/tutorials/make-low-poly-3d-models) ·
[Meshy: retopology](https://www.meshy.ai/features/ai-retopology) ·
[Meshy → Unity workflow](https://www.meshy.ai/tutorials/3d-model-for-unity-workflow)

## The rest of the game: worlds 2–5 — as of 2026-09-17

World 1 is finished: **29 kinds out of 29 have real models**. The rest of the game does not,
and that is now the main thing standing between us and a demo. Counted from
`data/worlds/*.json` against `data/props.json`:

| world | levels | kinds total | have a model | still voxel |
|---|---|---|---|---|
| Meadow `meadow` | 1–4 | 29 | **29** | 0 |
| City `city` | 12–14 | 20 | 16 | 4 |
| Forest `forest` | 5–8 | 19 | 15 | 4 |
| Beach `beach` | 9–11 | 14 | 5 | **9** |
| Clouds `clouds` | 15–17 | 11 | 2 | **9** |

Nine levels out of seventeen — more than half the game — are still made of cubes, even
though voxels were dropped as a style.

### The queue, ordered by MEASURED weight on screen

The number is how many of that kind the track actually places in one frame (`DUMP=1` in
`src/debug/track_shot.tscn`, `ADVANCE=60`). The bigger the number, the more the model shows.

| # | kind | per frame | world | what it is |
|---|---|---|---|---|
| 1 | `cloud` | 48 | Clouds | cloud islet you run across |
| 2 | `buoy` | 43 | Beach | buoy floating on water |
| 3 | `wall_cloud` | 21 | Clouds | cloud wall on the horizon |
| 4 | `canopy_leaves` | 15 | Forest | leaf canopy over the road |
| 5 | `lamp` | 13 | City | street lamp |
| 6 | `logpile` | 12 | Forest | stack of logs |
| 7 | `cart` | 11 | City | handcart |
| 8 | `stump` | 10 | Forest | tree stump (also an obstacle) |
| 9 | `star` | 9 | Beach + Clouds | star |
| 10 | `lantern_post` | 9 | City + Forest | lantern post |
| 11 | `fountain` | 8 | City | fountain |
| 12 | `signpost` | 6 | Forest | signpost |
| 13 | `moonswing` | 4 | Clouds | swing hanging from the moon |
| 14 | `umbrella` | 3 | Beach + City | parasol |
| 15 | `planet` | 3 | Clouds | little planet |
| 16 | `balloon` | 2 | Clouds | balloon |
| 17 | `raincloud` | 2 | Clouds | rain cloud |
| 18 | `cloud_arch` | 1 | Clouds | cloud archway landmark |

These six never appear on screen at all right now (see "Decide first" below), but they are
described in the beach data and will be needed once that question is settled: `beach_hut`,
`palm`, `sandcastle`, `shell`, `crab`, `umbrella_stripe`, `cloud_house`.

### Decide BEFORE generating — these are art calls, not code

Three questions the code cannot answer for us:

1. **Beach — is there a shore at all?** The `beach` world has `"sea": true` (surf mode): the
   road under the hero is invisible and they ride a board across open water. There is no
   shore anywhere. Because of that the code never places `walls_near` at sea — yet
   `beach.json` lists `palm`, `sandcastle`, `umbrella`, `shell` there. Half the beach list
   therefore never appears. Either the beach needs a distant shore (new geometry), or those
   kinds should be replaced with things that belong in water: buoys, rocks, planks, floats,
   a crab on a log.
   *(Buildings and the lighthouse tower that used to stand in the open sea are already gone —
   commit "у морському світі забудова й орієнтир більше не стоять у воді".)*

2. **Clouds — 78 wooden railings in the sky.** `clouds.json` describes a canal
   (`"canal": {...}`) with bridges across it, and a canal drags in `fence_rail` and
   `bridge_plank` — the same brown wooden railings as the riverside town. There are 78 of
   them in frame, the most numerous object in that world, plus a brick `tower_terracotta`
   among the landmarks. None of it suits a sky world; what to put instead is an art call.

3. **Forest and City — four kinds each.** Nothing open here: `canopy_leaves`, `logpile`,
   `stump`, `signpost`, `lantern_post` (forest) and `lamp`, `cart`, `fountain`,
   `lantern_post` (city). These two worlds go voxel-free the moment the models exist.

### Cheapest path to a demo

If the game has to be shown soon, **Forest and City** are by far the cheapest: eight kinds
between them cover seven levels (5–8 and 12–14). Beach and Clouds cost nine kinds each and
additionally run into questions 1 and 2 above.
