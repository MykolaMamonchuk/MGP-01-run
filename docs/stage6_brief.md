# Етап 6 (v0.9.0) — спільний бриф для агентів

Godot 4.7, GDScript 4, Mobile renderer. Godot **не можна запустити** — пишемо обережний валідний код, коментарі в коді короткі українською. Тести — GUT (`tests/*.gd`, `extends GutTest`, `func test_*`). Кольори у `src/` — тільки через `Palette` (`src/ui/theme/palette.gd`), hex-літерали лише в palette.gd (тест `test_palette.gd`). Вокселі — JSON у `data/voxels/*.json`, будує `VoxelBuilder` (`addons/mgp_core/voxel/`).

Обов'язково прочитати: `docs/MEMORY.md` (уроки — Meshy-чекліст, sRGB, процес), `README.md`, `docs/CHANGELOG.md` (верх), `docs/refs/README.md` (розділи «Арт-біблія ч.1» і «ч.2 — БАЗА»), референси-картинки `docs/refs/want/world+items+atmosphere/*.jpg` і `docs/refs/want/characters/*.jpg` (дивитись через Read — вони визначають вигляд).

## Що вже є (v0.8.0)
- Світ рухається на героя (+Z), `Track` — пул рядів + MultiMesh (дорога/декор/кліфи), `walls_near`, `landmarks`, кліфи з `world.cliff`, вода `cliff_water`.
- `Spawner3D` — перешкоди (`Obstacle3D` shape/marker), `Ingot3D`, `Tier2Segment`, пікапи, `spawn_obstacle_kind`.
- `Hero3D` — тіло-воксель + окремі очі/рот/риса/лапки; API: `set_hero(id,color,feature)`, `set_accessory(slot,voxel,opts)`, `set_hat`, `hit_reaction`, `tumble`, `duck`, `jump`, `hearts`, `face_camera`, `wave_hello`, `stop_fly`, `set_shield`.
- `CameraRig.apply(preset: Dictionary{pos,look,fov,ortho}, duration)`, пресети `PRESET_MENU`, `PRESET_HEROES`; світи мають `camera.pos/look/fov`.
- `Diorama` (`src/run3d/diorama.gd`) — острів 3×3, `data/buildings.json`.
- Стан гри у `run3d.gd`: MENU → HOME → COUNTDOWN → RUN → FINISH → HOME.

## Цільова картинка (GDD v1.5 §3, Додаток Д)
- Камера 3/4 зверху-ззаду: `pos (0, 3.8, 4.6)`, `look (0, 0.5, -5)`, fov 52; герой ≈ 1/6 висоти. DOF (тілт-шифт) + легкий блум, перемикач у налаштуваннях.
- Узбіччя по світах: meadow/beach/clouds — `roadside: "open"` (трава одразу за дорогою, пропси, канал води паралельно на 1.5–2.5 м у теракотових берегах, містки поперек, будинки другим планом 2–4 м); forest/city — `roadside: "walls"` (як зараз, 0.8–1.2 м).
- Покриття дороги по світу: плити пісочні / дошки / пісок+дошки / брук / хмарні плити; край нерівний.
- Палітра: трава `#7DC242` (тінь `#5E9E33`), дерево `#C4813F`/`#8F5A2A`, ящик `#D9A05B`, дахи `#D9503A`/`#C56A3A`/`#3E9A8F`/`#C9A45C`, стіни `#F1E4C8`, балки `#7A4A2A`, валун `#9AA5B1`, вода `#38B6E0`, береги теракота `#C9784F→#A55B3A→#7A4128`, плити `#E9CF8A`/`#D9B96F`, брук `#CFC8B8`, небо `#BFE3F7`, злиток `#F5C43C`/`#C98A12`. Герої: основний + крем `#F6E3C2` + темний `#4A2C2A` + акцент (`#F04F86`, `#6B4FBF`, `#3FC1B0`, `#F6C445`).
- Герої — чотирилапі звірята: голова ≈ 45 % висоти, кубічна морда з кремовою мордочкою, великі чорні очі з бліком, темний носик, вуха з рожевою серединкою, 4 короткі лапки з темними копитцями, хвіст із кольоровим кінчиком.

## Правила співпраці
- Кожен агент править **лише свої файли** (список у завданні). Нові Palette-токени додає **тільки агент A** у `palette.gd` — інші використовують імена з таблиці нижче (A створює їх першим ділом, у перші хвилини):
  `Palette.W_GRASS, W_GRASS_SHADOW, W_WOOD, W_WOOD_DARK, W_CRATE, W_ROOF_RED, W_ROOF_TERRA, W_ROOF_TEAL, W_ROOF_STRAW, W_WALL, W_BEAM, W_ROCK, W_WATER, W_BANK_1, W_BANK_2, W_BANK_3, W_SLAB, W_SLAB_DARK, W_COBBLE, W_SKY, INGOT, INGOT_EDGE, H_CREAM, H_DARK, H_ACC_PINK, H_ACC_VIOLET, H_ACC_TEAL, H_ACC_YELLOW`.
  У JSON-вокселях hex дозволено (палітра вокселя).
- API інших модулів не міняти; якщо треба нове — додати метод, старі лишити.
- У кінці: дописати пункти в `docs/CHANGELOG.md` під `## 0.9.0 (у роботі)` (створити секцію, якщо нема), тести на свої чисті функції/дані, короткий звіт: файли, нове API, припущення.
