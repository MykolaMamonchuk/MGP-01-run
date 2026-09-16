# Пропси: що згенерувати для першої мапи

## Де ми зараз

Розкладка рівнів **уже в сценах**: `levels/level_01/chunk_00..02.tscn` — це вузли
`LevelMarker3D` із полями `role` / `kind` / `lane` / позиція. Рівень 1 — 305 м, 51 маркер,
світ «Лужок» (`data/worlds/meadow.json`), 3 доріжки, 80 секунд.

Генерується не розкладка, а **сама геометрія**. Кожен `kind` — це ім'я файлу
`data/voxels/<kind>.json`, з якого `VoxelBuilder` збирає воксельний меш просто під час гри
(`addons/mgp_core/voxel/voxel_builder.gd`). Тому дерева, каміння й будівлі виглядають як
кубики: жодної моделі для пропсів у проєкті нема — `.glb` є тільки в героїв.

Окремо варто знати: **узбіччя рівня 1 теж генерується випадково.** Маркери описують дорогу
й перешкоди, а «стіни світу» обабіч (`walls_near` / `walls_far`), дрібниці (`props_side`),
далекі будівлі (`buildings_far`) і орієнтири Track розставляє сам, випадково, зі списків у
`meadow.json`. Тобто навіть коли моделі з'являться, перший рівень ще не буде «зробленим» —
це другий крок, див. «Порядок робіт».

## Як модель підміняє воксель

Шов уже готовий — `src/run3d/prop_library.gd`. Щоб замінити воксель справжньою моделлю:

1. покласти файл у `res://assets/props/<ім'я>.glb`;
2. дописати рядок у `data/props.json`:
   ```json
   "tree": "res://assets/props/tree_oak.glb",
   "rock_grey": {"path": "res://assets/props/rock_a.glb", "scale": 1.2, "yaw_deg": 90.0}
   ```
3. усе. Розкладку рівнів, маркери й `kind` міняти НЕ треба.

Виду нема в `props.json` або файл відсутній — малюється воксель, як і раніше. Тобто список
нижче можна закривати по одному пропсу, і гра лишається робочою на кожному кроці.

### Кілька різних моделей на один вид

Під ключем можна дати СПИСОК — це різні **типи** того самого виду:

```json
"barrel": [
  "res://assets/props/barrel.glb",
  "res://assets/props/barrel_2.glb",
  {"path": "res://assets/props/barrel_3.glb", "scale": 1.1}
]
```

Домовленість про назви: `barrel.glb` — перший тип, далі `barrel_2.glb`, `barrel_3.glb`.
Суфікс означає ІНШИЙ ТИП (інша бочка), а не інший варіант тієї самої моделі й не спробу
номер два. Те саме для ящиків, каміння, кущів.

**Одна мапа — один тип.** Типи різняться не лише малюнком, а й пропорціями (поручні бувають
0,26 і 0,41 м заввишки), тож змішані на одній вулиці вони читаються як помилка. Тому
різноманіття йде МІЖ рівнями: у містечку свої бочки, у лісі інші. Вибір рахується від назви
мапи, тобто однаковий у перешкод і в декору й не міняється посеред гри.

Маркери рівнів про типи не знають: у них як був `barrel`, так і лишається.

### Як провести модель від генератора до гри

```sh
B=/Applications/Blender.app/Contents/MacOS/Blender

# 1. розмір, початок координат, текстури
$B --background --python tools/prop_prepare.py -- \
    --in docs/refs/incoming/fence_low/fence_low_1_mesh.glb \
    --out assets/props/fence_low_1.glb \
    --box 0.95x0.70x0.30 --tex-size 2048

# 2. дописати шлях у data/props.json
# 3. стиснення текстур у відеопам'яті + імпорт
python3 tools/textures_vram.py
godot --headless --import
```

`--box` бере габарити **з таблиці нижче**. Розмір задають ширина й висота: смуга в грі
рівно 1,0 м, і модель, ширша за бокс, залазить на сусідню — дитина бачить перешкоду там,
де насправді вільно. Глибина лише перевіряється й друкує попередження: бокси писали під
геймплей, і в круглої бочки бокс 0,70 × 0,70 × 0,50 означає не форму, а скільки метрів
дороги вона займає.

Якщо після цього намальоване не сходиться з боксом — міняти треба **бокс у світі**, а не
розтягувати модель. Так уже зроблено для паркану (висота 0,70 → 0,55) і бочки
(глибина 0,50 → 0,60): інакше лишається невидиме зіткнення, і дитина втрачає життя там,
де на екрані порожньо.

### Декор, що тягнеться суцільно

Поручні вздовж берега (`fence_rail`) і настил містка — не окремі предмети, а **стрічка**.
Для них `--box` не годиться, бо він вписує модель і може зменшити її ще й по висоті. Треба
`--width 1.0`: ряд траси рівно метр, і секція мусить бути рівно такою ж, інакше між
ланками лишаються щілини й огорожа читається пунктиром.

```sh
$B --background --python tools/prop_prepare.py -- \
    --in docs/refs/incoming/fence_rail/fence_rail_1_mesh.glb \
    --out assets/props/fence_rail_1.glb --width 1.0 --tex-size 2048
```

Перевіряти стики — `src/debug/track_shot.tscn`:

```sh
WORLD=meadow VIEW=bank OUT=/tmp/bank.png godot res://src/debug/track_shot.tscn
```

На знімку ОДНОГО пропса щілина між ланками невидима в принципі, тож `prop_shot` тут не
допоможе — потрібен саме вигляд уздовж берега.

`tools/textures_vram.py` обходить і `assets/props`, і `assets/models`. Герої йдуть у
ЯКІСНОМУ режимі стиснення, пропси — у звичайному: у хутра м'які градієнти, і грубе
стиснення їх смугує (на черепасі середнє відхилення 8,4 при власному шумі знімка 1,3;
якісний режим дав 0,97 у зоопарку при шумі 0,73 — нерозрізненно). Дереву й каменю це не
потрібно, там звичайного вистачило з відхиленням 0,3%, а пам'яті він бере вдвічі менше.
Разом на п'ятьох героях і п'ятьох пропсах: 684 МБ відеопам'яті → 135 МБ.

`--tex-size 2048` обов'язковий: генератор віддає 4096×4096 на кожну з трьох карт, тобто
близько 200 МБ відеопам'яті на три паркани. Виміряно на знімку зблизька (×3): 2048 проти
4096 — 37 різних пікселів із 435 600, а 1024 вже 1381. Тому 2048, не менше.

### Розмір моделі можна не вгадувати

Габарити в таблиці — це **бокси зіткнень у грі**, а не вимога до самого `.glb`. Модель має
мати правильні ПРОПОРЦІЇ; точний розмір і розворот доводяться в `data/props.json`:

```json
"crate": {"path": "res://assets/props/crate.glb", "scale": 1.3, "yaw_deg": 90.0}
```

`scale` домножується до масштабу зі світу, `yaw_deg` додається до повороту. Працює і для
перешкод, і для декору. Тобто якщо модель приїхала вдвічі більшою або лежить боком — це
правиться одним числом, без переекспорту.

> **Готові промпти англійською, по блоку на кожен пропс** — `docs/tasks/props.en.md`.
> Там кожен блок уже зібраний (об'єкт + канонічний хвіст), копіюй і вставляй.

### Промпт для генерації

Береться ДОСЛІВНО, міняється лише перше речення (канонічне джерело — `docs/refs/README.md` §0):

> A cute &lt;об'єкт&gt;, chunky low-poly toy, soft rounded edges, simple readable shapes.
> Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly,
> gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens,
> turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel
> magical accents. Single clean silhouette, slightly exaggerated for gameplay readability.
> Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished.
> **No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.**
 Ключове:
**чарівний казковий світ, м'який low-poly**, і обов'язковий негативний хвіст
«no voxels, no cubes, no blocky or pixelated geometry». Без нього генератор збивається
на кубики — саме так виглядає все, що зараз у грі, і саме це ми прибираємо.

Промпти з Confluence («Каталог асетів і промти Meshy») **застаріли** — вони писались під
старий воксельний напрям.

### Вимоги до моделі

| | |
|---|---|
| **Один меш, один матеріал** | Декор малюється `MultiMesh`-пачками (сотні копій одним викликом). Бібліотека бере **перший** `MeshInstance3D` зі сцени — модель із кількох частин втратить усе, крім першої. |
| **Масштаб** | Доріжка — рівно **1 метр**. Герой — 0,98 м заввишки. Габарити перешкод у таблиці — це їхні реальні бокси зіткнення. |
| **Початок координат** | У низу моделі (пропс ставиться на землю), по центру. |
| **Орієнтація** | «Передом» до дороги. Track сам довертає бічний декор на 0 або 180°; тонке доведення — `yaw_deg` у `props.json`. |
| **Без запечених очей** | Для звірят (корова, зайчик) — та сама пастка, що була з лисом: намальовані в текстурі очі просвічують крізь накладку. Очі має малювати наша накладка. |
| **Стиль** | Той самий, що в героїв: низькополігональний, матовий, великі плями кольору, без дрібної деталізації — на швидкості її однаково не видно. |


## Референс рівня 1

`docs/refs/want/world+items+atmosphere/lucid-origin_…colorful_riverside_-0…-3.jpg` —
**село над каналом**: піщано-плитчаста доріжка посередині, по обидва боки вода в зелених
берегах, поперек неї дерев'яні містки, обабіч будиночки з черепицею й смугастими маркізами.

**Добра новина: структура вже є в грі.** `meadow.json` уже описує саме це —
`road_surface: "slabs"`, `canal: {side: "both", offset: 2.0, width: 1.2}`, `bridges_every: 9`,
і `Track` уміє малювати і канал, і береги, і містки. Тобто нічого нового програмувати не
треба: бракує **лише моделей** — зараз усе це кубики з `data/voxels/`.

### Що в референсі робить найбільше роботи

Дві речі повторюються майже в кожному метрі й самі по собі перетворюють смугу на вулицю:

| `kind` | що це | чому перше |
|---|---|---|
| `bridge_plank` | дошка дерев'яного містка | містки кожні 9 рядів — їх видно постійно |
| `fence_rail` | **дерев'яні поручні вздовж берега** | суцільно тягнуться обабіч усієї дороги |

`fence_rail` у списку нижче не було — це нове, і воно найважливіше після перешкод.

### Що вже в грі

| `kind` | типів | розмір у грі |
|---|---|---|
| `barrel` | 3 | 0,59–0,63 × 0,70 × 0,59–0,63 |
| `crate` | 3 | 0,70 × 0,49–0,52 × 0,70 |
| `fence_low` | 3 | 0,95 × 0,50–0,57 × 0,16–0,22 |
| `fence_rail` | 3 | 1,00 (стик у стик) × 0,26–0,41 |
| `bridge_plank` | 1 | 2,20 базових, траса підганяє під ширину каналу |
| `puddle` | 1 | 0,80 × 0,12 × 0,83 |
| `cart_market` | 1 | 0,80 заввишки |

Бокси у `data/worlds/meadow.json` доведені під намальоване, а не навпаки: ящик 0,70 → 0,52
заввишки, бочка 0,70 → 0,65 завширшки, калюжа 0,60 → 0,82 завглибшки, паркан 0,70 → 0,55.
Інакше лишалось невидиме зіткнення — у ящика воно було аж 19 см.

Лишилось згенерувати: `bush_flower`, `clothesline`, `banner_line`, `goose`, `xbox_red`.

### Берег і дрібниці (з референсу)

| `kind` | що це |
|---|---|
| `rock_grey` | сірий камінь — і на березі, і у воді |
| `bush_flower` | кущ із білими квіточками |
| `grass_tuft` | пучок трави |
| `barrel` | бочка |
| `crate` | дерев'яний ящик |
| `lantern` | вуличний ліхтар |
| `signpost` | вказівник |
| `flower_box` | ящик-клумба з квітами |
| `bench` | лавка |

### Будівлі (з референсу)

| `kind` | що це |
|---|---|
| `house_timber` | фахверковий будиночок із черепичним дахом |
| `house_shop` | крамниця зі смугастою маркізою |
| `market_stall` | відкритий прилавок із товаром |
| `house_small` | простий будиночок |
| `windmill` | вітряк — орієнтир на горизонті |

### Про текстури

Моделі з Meshy приходять **із вшитою текстурою** в самому `.glb` — окремо нічого
підкладати не треба. `PropLibrary` бере перший `MeshInstance3D` зі сцени разом із його
матеріалом, тож текстура їде з моделлю. Єдина вимога лишається та сама: **один меш і один
матеріал** на пропс, бо декор малюється пачками `MultiMesh`.

### Що вирішити перед генерацією

Наш світ 1 зараз — **лужок** (пеньки, гілки, корова, вулик, віз сіна), а референс — **село
над каналом** (ящики, візок, каміння, поручні). Структура збігається, набір перешкод — ні.

Два шляхи:

1. **Перетемувати світ 1 під референс.** Перешкоди беремо ті, що видно в референсі
   (ящик, візок, камінь, калюжа, паркан, кущ), решту лужкових лишаємо для інших рівнів.
   Габарити зіткнень не міняються — міняється лише те, який `voxel` до якого `kind`.
2. **Лишити лужок як є**, а село зробити окремим світом для пізніших рівнів.

Від цього залежить, які саме 10 перешкод генерувати першими.

## Світ 1 — річкове містечко: ЩО ГЕНЕРУВАТИ ПЕРШИМ

Рішення (15.09.2026): світ 1 стає новим першим рівнем за референсом — річкове містечко.
Окремий світ під лужок робитимемо пізніше.

**Габарити зіткнень міняти НЕ можна** — на них зав'язані стрибок, присід і ухиляння, і вони
вже налаштовані під вік гравця. Тому нижче кожен новий пропс успадковує габарит того, кого
заміщає. Дію теж не чіпаємо: гравець уже вчиться «низьке — перестрибнути, високе — пригнути,
збоку — обійти».

### Перші десять (пріоритет 1)

| новий `kind` | що це | дія | габарит Ш×В×Г, м | заміщає |
|---|---|---|---|---|
| `crate` | дерев'яний ящик | перестрибнути | 0.70 × 0.70 × 0.70 | `stump` |
| `barrel` | бочка | обійти збоку | 0.70 × 0.70 × 0.50 | `beehive` |
| `cart_market` | візок із товаром | обійти збоку | 0.80 × 0.80 × 0.50 | `haycart` |
| `fence_low` | низька хвіртка-паркан | перестрибнути | 0.95 × 0.70 × 0.30 | `fence` |
| `puddle` | калюжа | можна пробігти | 0.80 × 0.20 × 0.60 | лишається |
| `bush_flower` | кущ із білими квіточками | можна пробігти | 0.80 × 0.50 × 0.60 | `bush` |
| `clothesline` | мотузка з білизною | пригнутися | 1.20 × 0.50 × 0.30, висить на 1.00 | лишається |
| `banner_line` | святкова гірлянда впоперек вулиці | пригнутися | 1.10 × 0.40 × 0.30, висить на 1.05 | `branch` |
| `goose` | гуска, що переходить дорогу | обійти збоку | 0.80 × 0.60 × 0.50 | `cow` |
| `xbox_red` | червоний ящик сороки | обійти збоку | 0.75 × 1.00 × 0.60 | лишається |

`xbox_red` — сюжетний (сорока кидає їх героєві під ноги), тому лишається попри зміну світу.

### Одразу після них — два, що роблять картинку

Повторюються майже в кожному метрі, і без них вулиця не читається як вулиця:

| `kind` | що це |
|---|---|
| `bridge_plank` | дошка дерев'яного містка через канал |
| `fence_rail` | дерев'яні поручні вздовж берега |

### Промпт

Дослівно з `docs/refs/README.md` §0, міняється лише перше речення. Приклад для ящика:

> A cute wooden crate with warm brown planks and simple iron corners, chunky low-poly toy,
> soft rounded edges… (далі канонічний хвіст, включно з «no voxels, no cubes, no blocky or
> pixelated geometry»)

---

## Що потрібно рівню 1 (поточний набір «лужок»)

### Пріоритет 1 — перешкоди (гравець дивиться на них щосекунди)

Це те, з чим герой стикається. Габарити — з `meadow.json`, змінювати їх не можна: на них
зав'язана гра (стрибок, присід, ухиляння).

| `kind` | воксель | що це | дія гравця | габарит Ш×В×Г, м | у рівні 1 |
|---|---|---|---|---|---|
| `stump` | stump | пеньок | перестрибнути | 0.70 × 0.70 × 0.70 | 2 |
| `puddle` | puddle | калюжа | можна пробігти | 0.80 × 0.20 × 0.60 | 2 |
| `branch` | branch | гілка над дорогою | пригнутися | 1.10 × 0.40 × 0.30, висить на 1.05 | 2 |
| `clothesline` | clothesline | мотузка з білизною | пригнутися | 1.20 × 0.50 × 0.30, висить на 1.00 | 2 |
| `haycart` | haycart | віз сіна | обійти збоку | 0.80 × 0.80 × 0.50 | 6 |
| `cow` | cow | корова | обійти збоку | 0.80 × 0.60 × 0.50 | 2 |
| `beehive` | beehive | вулик | обійти збоку | 0.70 × 0.70 × 0.50 | 6 |
| `xbox` | **xbox_red** | червоний ящик сороки | обійти збоку | 0.75 × 1.00 × 0.60 | 2 |
| `fence` | fence | низький паркан | перестрибнути | 0.95 × 0.70 × 0.30 | 6 |
| `bush` | bush | кущ | можна пробігти | 0.80 × 0.50 × 0.60 | 6 |

Увага: `xbox` → файл називається **`xbox_red`** (перешкода й воксель мають різні імена, див.
`obstacles.xbox.voxel` у `meadow.json`). У `props.json` ключ має бути `xbox_red`.

### Пріоритет 2 — дрібний декор упритул до дороги

| `kind` | що це | у рівні 1 |
|---|---|---|
| `tree` | дерево (основне для лужка) | 5 |
| `flower` | квітка | 5 |
| `mushroom` | гриб | 4 |

`flower` фарбується на місці (`decor_colors`: рожевий, жовтий, фіолетовий, кораловий) — тож
модель має бути **світлою/нейтральною**, колір накладається зверху.

### Пріоритет 3 — узбіччя (видно постійно, але здалеку)

«Стіни світу» обабіч дороги — саме вони дають відчуття, що рівень не порожній.
`walls_near` лужка: `fence`, `bush`, `wall_hedge`, `haycart`, `beehive`, `mushroom`, `tree`
(шість із семи вже є вище — новий тільки один).

| `kind` | що це |
|---|---|
| `wall_hedge` | суцільний живопліт — головна «стіна» узбіччя |

Далі — дрібниці, які Track розкидає по узбіччю (`props_side`):

| `kind` | що це |
|---|---|
| `hay_bale` | тюк сіна |
| `rock_grey` | сірий камінь |
| `crate` | дерев'яний ящик |
| `barrel` | бочка |
| `fence_low` | низька секція паркану |
| `bush_cube` | кущ-кубик (дрібніший за `bush`) |
| `mushroom_red` | червоний гриб |
| `flower_yellow` | жовта квітка |
| `flower_pink` | рожева квітка |

### Пріоритет 4 — фон і горизонт

Далекі будівлі (`buildings_far`) — те, що читається як «село за полем». Їх видно здалеку,
тож деталізація мінімальна, а силует має бути виразний.

| `kind` | що це |
|---|---|
| `house_red` | хата з червоним дахом |
| `house_terra` | хата теракотова |
| `house_straw` | хата під соломою |
| `well` | криниця |
| `tree_round` | кругле дерево (фонове) |
| `pine_3` | ялинка |

Плюс `walls_far` — те саме `tree` й `haycart`, але масштабовані в 1.4–2.0 раза.

### Пріоритет 5 — орієнтири й жива дрібнота

Орієнтири (`landmarks`) трапляються рідко, зате великі й помітні — герой пробігає крізь них.

| `kind` | що це |
|---|---|
| `arch_terracotta` | теракотова арка над дорогою (є в рівні 1, 1 шт.) |
| `tower_terracotta` | вежа |
| `gate_wood` | дерев'яна брама |

| `kind` | що це |
|---|---|
| `bunny` | зайчик, що стрибає узбіччям |
| `bird` | пташка |
| `bridge_plank` | дошка містка (канал обабіч дороги, місток кожні 9 рядів) |

Арка масштабується під ширину дороги автоматично — робити її треба на 3 доріжки (≈3 м) і
з запасом по висоті.

## Скільки це разом

**37 моделей** на повністю «зроблений» лужок. Але грати стане помітно краще вже після
**пріоритету 1 (10 штук)** — це те, на що гравець дивиться впритул.

Лужок — світ рівнів 1–4, тож ці 37 моделей окупляться одразу на чотирьох рівнях. Далі
йдуть `forest` (5–8), `beach`, `city`, `clouds` — у кожного свій набір, але частина
повторюється (`tree`, `rock`, `fence`, `xbox_red`, `puddle`).

## Порядок робіт

1. **Пріоритет 1** — 10 перешкод. Після кожної можна одразу дивитись у грі: воксель
   підміняється однією строкою в `data/props.json`.
2. **Пріоритет 2–3** — декор і узбіччя. Тут рівень уперше почне виглядати як місце, а не
   як смуга.
3. **Авторська розстановка узбіччя.** Зараз воно випадкове. Коли моделі будуть, має сенс
   розставити його маркерами в `levels/level_01/chunk_*.tscn` — як уже розставлені
   перешкоди, — щоб перший рівень був зробленим, а не згенерованим. Це окрема задача:
   `role: "wall_near"` і `role: "building"` маркери вже підтримуються
   (`src/run3d/level_chunk_loader.gd`), просто ними ще ніхто не користувався.
4. **Пріоритет 4–5** — фон, орієнтири, дрібнота.

## Перевірка

Після кожної підміни:

```sh
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=tests/.gutconfig.json -gexit
```

`tests/test_prop_library.gd` стежить за головним: поки моделі нема, все малюється вокселем
рівно як раніше, а зламаний шлях у `props.json` не роняє гру.

Подивитись рівень: `godot --path .` і пройти перший рівень. Окремо на пропс —
`VOXEL=<ім'я> godot res://src/debug/model_preview.tscn`.

## Забудова першого рівня — те, що лишилось до повної схожості
Рівень уже на 90% схожий на референс. Вся різниця, яка ще помітна оком, — це те, що наші
будинки досі воксельні блоки без вікон, а в референсі вони з фахверком, віконницями й
маркізами. Чотири моделі нижче закривають саме це. Генератор: Image to 3D, texture ON,
rig OFF, quad, ≤ 12k. Розмір не вгадуй — доводиться при обробці.

### 1. `house_red` — будинок із червоною черепицею

> A cute two-storey riverside townhouse with a steep red tile roof, cream plaster walls with dark brown timber framing, small shuttered windows with flower boxes, and a little wooden door, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 2. `house_terra` — будинок із теракотовим дахом

> A cute narrow riverside townhouse with a terracotta tile roof, warm sandy plaster walls, tall blue-shuttered windows and a small balcony with a flower box, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 3. `awning_stall` — ринкова ятка зі смугастою маркізою

> A cute small market stall with a green and white striped fabric awning, a wooden counter piled with fruit and vegetable baskets, and a hanging lantern, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 4. `kiosk` — кіоск на розі

> A cute tiny corner kiosk with a round teal roof, an open wooden serving window with a small counter, and a hand-painted sign board, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.


## Черга на позбавлення вокселя — за ВИМІРЯНОЮ вагою в кадрі

Станом на зараз на рівні 1 справжніх моделей **7 із 44 видів**: решта досі малюється
вокселем. Порядок нижче не на відчуття, а за кількістю предметів, які траса реально кладе
в кадр (`WORLD=meadow DUMP=1 godot res://src/debug/track_shot.tscn` — 215 предметів усього).

Дерева тут найважливіші з великим відривом: `pine_3` і `tree_round` разом дають 37
предметів із 215, тобто більше, ніж усе інше воксельне разом узяте.

| # | `kind` | штук у кадрі | що це |
|---|---|---|---|
| 1 | `tree_round` | 18 | кругле листяне дерево |
| 2 | `pine_3` | 19 | ялинка |
| 3 | `hay_bale` | 15 | сніп сіна |
| 4 | `house_terra` | 4 | будинок із теракотовим дахом |
| 5 | `hut` | 6 | хатинка |
| 6 | `flower_yellow` | 5 | жовта квітка |
| 7 | `flower_pink` | 5 | рожева квітка |
| 8 | `mushroom_red` | 5 | червоний гриб |
| 9 | `rock_grey` | 3 | сірий камінь |
| 10 | `mill` | 3 | вітряк |
| 11 | `kiosk` | 3 | кіоск |
| 12 | `well` | 2 | криниця |

Налаштування генератора й порядок обробки — вище в цьому файлі.

### 1. `tree_round` — кругле листяне дерево (18 шт.)

> A cute round leafy tree with a chunky brown trunk and a soft rounded crown in two tones of green, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 2. `pine_3` — ялинка (19 шт.)

> A cute small pine tree with three soft tiers of dark green needles and a short brown trunk, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 3. `hay_bale` — сніп сіна (15 шт.)

> A cute round bale of golden hay tied with two rope bands, resting on its side, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 4. `house_terra` — будинок із теракотовим дахом (4 шт.)

> A cute narrow riverside townhouse with a terracotta tile roof, warm sandy plaster walls, tall blue-shuttered windows and a small balcony with a flower box, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 5. `hut` — хатинка (6 шт.)

> A cute tiny cottage with a thatched straw roof, cream plaster walls, one round window and a small wooden door, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 6. `flower_yellow` — жовта квітка (5 шт.)

> A cute single cheerful yellow flower with a slim green stem and two small leaves, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 7. `flower_pink` — рожева квітка (5 шт.)

> A cute single cheerful pink flower with a slim green stem and two small leaves, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 8. `mushroom_red` — червоний гриб (5 шт.)

> A cute plump mushroom with a red cap dotted with white spots and a short cream stem, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 9. `rock_grey` — сірий камінь (3 шт.)

> A cute rounded grey boulder with soft facets and a patch of moss on top, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 10. `mill` — вітряк (3 шт.)

> A cute small windmill with a cream stone tower, a red conical roof and four wooden sails, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 11. `kiosk` — кіоск (3 шт.)

> A cute tiny corner kiosk with a round teal roof, an open wooden serving window and a small sign, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 12. `well` — криниця (2 шт.)

> A cute round stone well with a small wooden roof, a rope and a hanging bucket, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.


## Будинки робить скрипт, а не генератор

Забудова — найбільша частина кадру, і чекати на неї найдовше. Але будиночок — річ регулярна:
коробка, двосхилий дах, віконця, двері, фахверк. Усе це чесно збирається геометрією.

```sh
B=/Applications/Blender.app/Contents/MacOS/Blender
$B --background --python tools/make_house.py -- \
    --out assets/props/house_red.glb \
    --width 1.5 --depth 1.3 --height 1.5 --storeys 2 \
    --roof "#C1452F" --wall "#F4E8D0" --beam "#6E4326" --awning "#DCEBE0"
```

128–248 трикутників на будинок, без текстур — самими кольорами матеріалів. Вісім різних
будинків разом важать 112 КБ. Параметри (розмір, поверхи, кольори даху/стіни/балок, маркіза)
дають несхожі будинки з одного інструмента, тож вулиця не виглядає повтореною.

Що вже згенеровано: `house_red`, `house_terra`, `house_teal`, `house_straw`, `city_house_a`,
`city_house_b`, `hut`, `wall_house`.

Генератор моделей потрібен там, де форма НЕрегулярна: дерево, кущ, камінь, тварина. Там
скрипт не допоможе, і черга вище лишається в силі.


## Що ще потрібно згенерувати — станом на 16.09.2026

**Від тебе вже є 8 видів** і вони в грі: `barrel` ×3, `crate` ×3, `fence_low` ×3,
`fence_rail` ×3, `cart_market` ×3, `bush_flower` ×2, `bridge_plank`, `puddle`.

Решту я зробив скриптами (`tools/make_house.py`, `tools/make_nature.py`) — це **заглушки**:
вони тримають стиль і вагу, але це геометрія з примітивів без текстур. Зараз вони займають
**56% предметів у кадрі** (668 із 1187 по всіх п'яти світах).

Порядок нижче — за ВИМІРЯНОЮ кількістю в кадрі, а не за відчуттям. Перші чотири пункти
закривають третину всього, що видно.

| # | `kind` | штук у кадрі | типів варто | що це |
|---|---|---|---|---|
| 1 | `tree_round` | 130 | 3 | кругле листяне дерево |
| 2 | `wall_house` | 95 | 3 | високий будинок вулиці |
| 3 | `bush` | 75 | 2 | кущ |
| 4 | `flower` | 65 | 3 | квітка |
| 5 | `mushroom` | 57 | 2 | гриб |
| 6 | `pine_3` | 40 | 2 | ялинка |
| 7 | `wall_tree_tall` | 39 | 2 | високе дерево фону |
| 8 | `rock` | 85 | 3 | камінь |
| 9 | `awning_stall` | 12 | 2 | ринкова ятка |
| 10 | `hut` | 11 | 2 | хатинка |
| 11 | `kiosk` | 9 | 1 | кіоск |
| 12 | `hay_bale` | 8 | 2 | сніп сіна |
| 13 | `goose` | 4 | 1 | гуска · rig: quadruped |
| 14 | `mill` | 3 | 1 | вітряк |

«Типів варто» — скільки РІЗНИХ моделей одного виду має сенс зробити: на одній мапі гра бере
один тип, тож три дерева — це три несхожі містечка, а не три дерева на одній вулиці.

Налаштування генератора й порядок обробки — вище в цьому файлі. Кидай у
`docs/refs/incoming/<kind>/`, підміняються без правок коду.

### 1. `tree_round` — кругле листяне дерево (130 шт. у кадрі)

> A cute round leafy tree with a chunky brown trunk and a soft rounded crown in two tones of green, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 2. `wall_house` — високий будинок вулиці (95 шт. у кадрі)

> A cute tall two-storey riverside townhouse with a steep red tile roof, cream plaster walls with dark timber framing, shuttered windows with flower boxes and a striped awning over the door, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 3. `bush` — кущ (75 шт. у кадрі)

> A cute rounded leafy bush in two tones of green, dense and soft, no flowers, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 4. `flower` — квітка (65 шт. у кадрі)

> A cute single cheerful flower with a slim green stem, two small leaves and rounded petals, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 5. `mushroom` — гриб (57 шт. у кадрі)

> A cute plump mushroom with a rounded cap and a short cream stem, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 6. `pine_3` — ялинка (40 шт. у кадрі)

> A cute small pine tree with soft tiers of dark green needles and a short brown trunk, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 7. `wall_tree_tall` — високе дерево фону (39 шт. у кадрі)

> A cute tall slender tree with a narrow rounded crown, used as a background wall of a forest road, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 8. `rock` — камінь (85 шт. у кадрі)

> A cute rounded boulder with soft facets, warm grey stone, a patch of moss on one side, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 9. `awning_stall` — ринкова ятка (12 шт. у кадрі)

> A cute small market stall with a green and white striped fabric awning, a wooden counter piled with baskets of fruit and vegetables, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 10. `hut` — хатинка (11 шт. у кадрі)

> A cute tiny cottage with a thatched straw roof, cream plaster walls, one round window and a small wooden door, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 11. `kiosk` — кіоск (9 шт. у кадрі)

> A cute tiny corner kiosk with a round teal roof, an open wooden serving window and a hand-painted sign, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 12. `hay_bale` — сніп сіна (8 шт. у кадрі)

> A cute round bale of golden hay tied with two rope bands, resting on its side, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 13. `goose` — гуска · rig: quadruped (4 шт. у кадрі)

> A cute plump white goose with an orange beak and orange feet, standing with both legs clearly apart, no eyes drawn on the face, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.

### 14. `mill` — вітряк (3 шт. у кадрі)

> A cute small windmill with a cream stone tower, a red conical roof and four wooden sails, chunky low-poly toy, soft rounded edges, simple readable shapes. Children's premium 3D game art: a magical storybook world — soft handcrafted low-poly, gentle glow, whimsical fairy-tale charm. Bright saturated colours: emerald greens, turquoise water, warm brown wood, soft grey stone, cheerful yellow, pink and pastel magical accents. Single clean silhouette, slightly exaggerated for gameplay readability. Soft ambient lighting, gentle shadows, cosy cheerful atmosphere, family-friendly, polished. No voxels, no cubes, no blocky or pixelated geometry, no photorealism, no realistic textures.


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
