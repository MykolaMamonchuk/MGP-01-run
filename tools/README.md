# tools/

Допоміжні скрипти. У грі не використовуються — лише в редакторі й у терміналі.

| Файл | Що робить |
|---|---|
| `voxelize.py` | Meshy `.glb`/`.obj` → воксельні частини героя `data/voxels/*_ai.json` + `.vox` |
| `vox2json.py` | Зворотно: MagicaVoxel `.vox` → `data/voxels/<name>.json` |
| `test_voxelize.py` | Тести конвертера на синтетичному звірятку (`python3 tools/test_voxelize.py`) |
| `rig_fix.py` | Blender headless: прибрати зайві кістки з ригнутого `.glb` і віддати їхні ваги сусідній кістці (`--list` — тільки дамп дерева з вершинами) |
| `palette_hero.json` | Палітра героя `{символ: #hex}` для `vox2json.py --palette` |
| `perf/` | Сцена заміру FPS (Godot) |
| `../src/debug/voxel_preview.tscn` | Показати один воксель у порожній сцені: `VOXEL=<ім'я> godot res://src/debug/voxel_preview.tscn` |
| `shots/` | Сцена автознімків (Godot) |

## Воксельний пайплайн

```bash
pip3 install trimesh numpy
python3 tools/voxelize.py docs/refs/models/fox.glb --hero lys --height 0.98 --pitch 0.04 --dry-run
python3 tools/voxelize.py docs/refs/models/fox.glb --hero lys --height 0.98 --pitch 0.04 \
    --out data/voxels --vox docs/refs/models/out/
```

Покрокова інструкція (і таблиця «що робити, коли негарно») — `docs/tasks/voxelize.md`.

## Скелетна модель замість вокселів (без інструментів)

`.glb` зі **скелетом** воксeлізувати не треба взагалі: скопіюй його в `assets/models/`,
допиши герою `"rig": "<ім'я файлу без .glb>"` у `data/heroes.json` — і `Hero3D` малює
цю модель, анімуючи кістки процедурно й фарбуючи вершини за зонами
(`src/run3d/hero_rig.gd`). Покрокова інструкція — `docs/tasks/rig.md`.

Єдиний інструмент, який тут буває потрібен, — `rig_fix.py`, коли Meshy повісив шкіру
лапки на чуже пасмо чи аксесуар:

```bash
alias blender=/Applications/Blender.app/Contents/MacOS/Blender

# 1. подивитись дерево кісток і вершини на кожній (нічого не змінює)
blender --background --python tools/rig_fix.py -- --in assets/models/unicorn.glb --list

# 2. прибрати зайві кістки, ваги віддати найближчій задній лапці (пише .glb.bak)
blender --background --python tools/rig_fix.py -- \
    --in assets/models/unicorn.glb --out assets/models/unicorn.glb \
    --remove Bone_025 Bone_024 Bone_023 Bone_028 Bone_027 Bone_026 \
    --merge-into nearest-leg --report

# 3. переімпортувати й глянути
godot --headless --import
RIG=unicorn godot res://src/debug/voxel_preview.tscn
```

`--merge-into parent` — віддати ваги батькові видаленої кістки; `--legs` — свій список
ланцюжків для `nearest-leg`; `--dry-run` — не писати файл. `heroes.json` скрипт не чіпає:
що саме прибрати з `rig_bones` (`static`, зайві імена в `tail`), написано в
`docs/tasks/rig.md`, розділ «Чистка рига в Blender».

## Готовий воксельний GLB (`--exact`)

Коли `.glb` уже **воксельний** (кубики на рівній сітці — вихід MagicaVoxel, Blender-remesh
чи онлайн-воксeлізатора), проганяти його через `trimesh.voxelize` шкідливо: сітка «попливе»,
а кольори загубляться. Режим `--exact` сітку **знаходить**, а не будує.

```bash
# 1. подивитись (нічого не пишеться)
python3 tools/voxelize.py docs/refs/models/fox_voxel.glb --exact --name fox_voxel \
    --height 0.98 --out data/voxels --vox docs/refs/models/out/ --dry-run

# 2. те саме без --dry-run — пише data/voxels/fox_voxel.json і docs/refs/models/out/fox_voxel.vox
python3 tools/voxelize.py docs/refs/models/fox_voxel.glb --exact --name fox_voxel \
    --height 0.98 --out data/voxels --vox docs/refs/models/out/

# 3. глянути в грі, не чіпаючи heroes.json
VOXEL=fox_voxel godot res://src/debug/voxel_preview.tscn
```

Що робить `--exact`:

- **розмір кубика** = мода довжин ребер трикутників (запасний план — найменший крок габариту);
  друкується в консоль, задається вручну через `--cube-size`;
- **зайнятість** — центр кубика для кожної грані: `центроїд − нормаль × size/2` (бік усередину),
  індекси = `round((центр − bbox_min − size/2) / size)`. Паралельно рахується
  `trimesh.voxelize(pitch=size)` з тим самим початком; обидві кількості друкуються, береться
  снап граней (він точніший), а `trimesh` — лише якщо снап розсипався. Керується `--grid`;
- **кольори** — справжні: `vertex_colors` → мода кольорів вершин грані; текстура → `uv_to_color`
  в UV-центроїді грані; лише матеріал → його базовий колір; нічого — сірий `#B0B0B0`.
  Далі квантування (32 рівні на канал, топ-`--max-colors` = 16, решта до найближчого)
  й символи `a, b, e, f…` (`o d c k i t m` пропущені: їх Hero3D підміняє кольорами героя);
- `size` у JSON = знайдений розмір кубика після масштабування моделі до `--height` (типово 0.98);
- `.vox` пишеться **завжди зі справжніми кольорами**.

`--exact` типово працює з `--parts none` — один файл `<name>.json`, який показується як
`VoxelBuilder.instance("<name>")` (декор, звірятко, прев'ю). З `--parts hero` вмикається та сама
сегментація на знайденій сітці, але **без `--fit`**: частини лишаються зі справжньою кількістю
вокселів, а інструмент лише **звітує**, чи збігаються висоти з константами Hero3D. Кольори
лишаються справжніми; символи-зони `o/d/c/k/i/t` вмикає окремий прапорець `--zones`.

Ще прапорці: `--up y|z` (вимкнути автовизначення Z-up — у довгого звірятка глибина буває
більша за зріст), `--front`, `--name`.

**Формат виходу** збігається з `addons/mgp_core/voxel/voxel_builder.gd`:
`layers[y][z][x]` — шар це y (знизу вгору), рядок це z (перший рядок — **перед, -Z**),
символ у рядку це x. Герой дивиться в -Z (`Hero3D.FACE_Z = -0.425`).
Символи палітри Hero3D підміняє кольорами героя: `o` основний, `d` темніший,
`c` крем, `k` темне, `i` рожеве, `t` акцент, `m` плямки.

**Контракт габаритів — у метрах, а не в кількості вокселів (v2).** `--fit` (типово увімкнено)
приводить кожну частину до констант Hero3D із допуском в один воксель: голова 0,45 м заввишки
і 0,45 м завглибшки (2 × `HEAD_HALF_D` — інакше очі Hero3D потонуть у голові), тулуб 0,375 м,
лапка 0,225 м, вухо ≤ 0,22 м, хвіст рівно `TAIL_LEN` 0,35 м (коротший добивається порожніми
рядами ззаду, щоб Hero3D ставив шарнір за константою). Ширина всіх частин < 0,58 м.
Скільки в цих метрах вокселів — вирішує `--pitch`: **типово 0,04 м** (голова ≈ 11 шарів),
було 0,075 м (6 шарів) — саме через це деталі AI-моделі губились. Пропорції x/z тягнуться
за точною віссю, тож частина не плющиться. `tests/test_heroes_v15.gd` звіряє те саме в метрах.

`heroes.json` скрипти не редагують — блок `parts` друкується в консоль.
