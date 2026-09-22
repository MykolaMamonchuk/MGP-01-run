# Android: зібрати, поставити, заміряти

Навіщо. Гра мобільна, а всі числа досі бралися з Мака. Веб-збірка (`docs/web.md`) дає
відчути гру пальцем, але міряти нею не можна: у браузері Compatibility (WebGL 2), інший
рушій, інші draw calls. На справжньому телефоні працює той самий мобільний рушій, що й у
релізі, — і лише там видно, у скільки насправді обходяться тіні, збирання цеглинки й час
кадру.

## Що має бути на машині

| | де | стан на 21.09.2026 |
|---|---|---|
| `adb` | `/Volumes/T7/Android/sdk/platform-tools/adb` | є |
| Android SDK | `/Volumes/T7/Android/sdk` | є, **на зовнішньому диску T7** |
| Java 17 | `/usr/local/Cellar/openjdk@17/…/Home` | є |
| `debug.keystore` | `~/.android/debug.keystore` | є |
| шаблони експорту | `~/Library/Application Support/Godot/export_templates/4.7.2.stable/android_*.apk` | докачано окремо |

**T7 — зовнішній диск.** Не під'єднаний — Android-збірки не буде, і помилка про це скаже не
одразу, а вже під час експорту.

Шляхи живуть у налаштуваннях РЕДАКТОРА, не в проєкті:
`~/Library/Application Support/Godot/editor_settings-4.7.tres` →
`export/android/android_sdk_path`, `export/android/java_sdk_path`.

## Що має зробити людина з телефоном

1. «Про телефон» → сім разів по «Номер збірки» → з'явиться «Для розробників».
2. Там увімкнути **Налагодження USB**.
3. Під'єднати кабелем і **погодитись на запит «Дозволити налагодження?»** на екрані
   телефона. Без цього `adb devices` показує `unauthorized`, а не пристрій.

Перевірка: `adb devices -l` має показати рядок із моделлю.

## Зібрати й поставити

```bash
export PATH="/Volumes/T7/Android/sdk/platform-tools:$PATH"
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --headless --path . --export-debug "Android" export/Bizhy-Bizhy.apk
adb install -r export/Bizhy-Bizhy.apk
adb shell monkey -p com.selectoglobal.bizhybizhy -c android.intent.category.LAUNCHER 1
```

Пресет `Android` — ВИПРОБУВАЛЬНИЙ: він несе прапорець `debug_hud`, тобто накладка з числами
доступна (`src/ui/debug_overlay.gd`, тап по кутку зліва вгорі). Коли дійде до збірки для
дитини, прапорець із неї має зникнути, а випробувальна лишиться окремим пресетом — це
стереже `tests/test_export_presets.gd` явним списком `DEBUG_HUD_PRESETS`.

Архітектура одна — `arm64-v8a`. Сенсу тягнути 32-бітну немає, а APK вдвічі легший.

## Заміряти — чим саме

**`dumpsys gfxinfo` для Godot НЕ ПРАЦЮЄ.** Це перше, що я спробував, і воно бреше: Godot
малює у власну поверхню повз Android'ів View, тож `gfxinfo` бачить лише вісім в'юшок
обгортки й нарахував шість кадрів за хвилину гри. Порада з першої редакції цього файлу була
неправильна.

**Міряти треба накладкою самої гри** (`src/ui/debug_overlay.gd`, вона є в цій збірці за
прапорцем `debug_hud`). Розгорнути її на телефоні:

```bash
adb shell input tap 30 30      # тап по кутку зліва вгорі; цикл: повний / лише к/с / сховано
adb exec-out screencap -p > /tmp/phone.png
```

Повна панель дає те, чого не дає ніщо інше на пристрої: к/с, кадр, 1% low, **ЦП рендера**,
draw calls, примітиви, відеопам'ять, текстури, стан гри, рівень, профіль і якість.

**Консоль гри:** `adb logcat -s godot:V` — тут видно, який рушій підхопився, і всі
попередження. **Пам'ять:** `adb shell dumpsys meminfo com.selectoglobal.bizhybizhy`.

### Час кадру тут КВАНТОВАНИЙ — і це вбиває порівняння наосліп

Час кадру за годинником на Android іде сходинками по **16,67 мс**, і пакує їх компонувальник
системи, а не гра. Вимкнути не вийде: `DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)`
приймається й мовчки не діє, `display/window/vsync/vsync_mode=0` теж, а часомір GPU
(`viewport_get_measured_render_time_gpu`) у бекенді Compatibility повертає нулі. Медіана й
p95 кванта не обходять — вони чесно показують квантоване число.

Через це **будь-яка різниця, менша за 16,67 мс, читається як нуль**, а та, що перескакує
межу, — як цілий квант. Одного дня це коштувало цілого набору хибних висновків: сім прогонів
підряд давали 133,1…133,6 мс на сценах із 251 і 187 викликами малювання (це рівно 8 × 16,67),
і з цього вийшло «виклики ні до чого» та «цей шар безкоштовний».

Тому порівнювати варіанти можна лише **сходами масштабу рендера**: той самий варіант
проганяється на 0.45 / 0.60 / 0.75 / 0.90 / 1.00, і порівнюється СУМА медіан. Це
порівняльний показник, а **не** мілісекунди в кадрі — різниця −157 у ньому не означає
157 мс. Для питання «чи тримає профіль 30 к/с» масштаб навпаки фіксують і дивляться частку
кадрів, що вклались у 33,4 мс. Інструмент — `src/ui/strip_probe.gd`; повний виклад методу —
сторінка «Метод заміру продуктивності на Android» у Confluence і запис у `docs/MEMORY.md`.

## Установка на Xiaomi/MIUI

`adb install` може впасти з `INSTALL_FAILED_USER_RESTRICTED: Install canceled by user` —
MIUI блокує мовчки, без діалогу на екрані. Обхідний шлях тим самим дозволеним каналом:

```bash
adb push export/Bizhy-Bizhy.apk /data/local/tmp/b.apk
adb shell pm install -r -t /data/local/tmp/b.apk
```

## Релізна збірка без релізного ключа

Для ЗАМІРІВ релізний шаблон можна підписати відлагоджувальним ключем — різниці в швидкості
це не дає, а справжній ключ заводити не треба (його втрата означає, що застосунок не
оновити в магазині ніколи). Ключі пресету `keystore/release*` ставити ТИМЧАСОВО й одразу
відкочувати: пароль не має потрапити в git.

## Чого НЕ робити

Не порівнювати числа телефона з числами `tools/probe/` на Маку напряму: різні рушії, різні
роздільності, різний масштаб рендера. Телефон порівнюють САМ ІЗ СОБОЮ — «до» й «після»
однієї правки, тим самим рівнем і тим самим профілем. Правило контрольного прогону з
`docs/MEMORY.md` тут діє так само, і навіть сильніше: телефон ще й гріється, тож третій
прогін поспіль повільніший за перший просто так.

## iOS: другий драйвер для перехресної перевірки

iPhone 11 тут не цільовий пристрій — він утричі потужніший за найслабший Android. Він
потрібен як ДРУГИЙ ДРАЙВЕР: ціна фонової забудови на Adreno 505 виявилась геометричною, і
чи це правда взагалі, а не особливість слабкого GLES-драйвера, видно лише на іншому
залізі. Плюс на iOS рушій іде через Metal (MoltenVK у збірці), де часомір GPU
`viewport_get_measured_render_time_gpu()` має працювати — на Android у Compatibility він
повертає нулі, і саме через це довелось міряти сходами масштабу.

```bash
xcrun devicectl list devices                      # телефон має бути "available (connected)"
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --headless --path . --export-release "iOS" export/ios/Bizhy.ipa
DEV=<Identifier зі списку>
xcrun devicectl device install app --device $DEV export/ios/Bizhy.ipa
xcrun devicectl device process launch --device $DEV --console com.selectoglobal.bizhybizhy
```

**Вивід Godot у консоль `devicectl` НЕ потрапляє.** На iOS він іде в системний журнал, а
`log stream` у свіжих macOS уже не вміє читати з пристрою (`--device-name` прибрано). Тому
проба пише звіт ще й у файл, і його забирають із контейнера застосунку:

```bash
xcrun devicectl device copy from --device $DEV \
  --domain-type appDataContainer --domain-identifier com.selectoglobal.bizhybizhy \
  --source Documents/strip_report.txt --destination /tmp/ios_strip.txt
```

На Android той самий файл дістається через `adb`:
`adb shell run-as com.selectoglobal.bizhybizhy cat files/strip_report.txt`.

Godot сам викликає `xcodebuild` і видає вже підписаний `.ipa` — окремого кроку в Xcode не
треба. Підпис бере наявний універсальний профіль тиму (`iOS Team Provisioning Profile: *`,
XP85F64TCF), тож реєструвати новий App ID не довелось. Паролів у пресеті iOS немає — на
відміну від Android, його можна тримати в git як є.

**Телефон має бути під'єднаний КАБЕЛЕМ.** Запис «available (paired)» у списку лишається й
від старого мережевого спарування, але установка через нього падає з таймаутом
(`Network.NWError 60`).

Шаблони експорту 4.7.2 містили тільки Android і веб; `ios.zip` довелось доставити з
офіційного `.tpz` (1,28 ГБ, з нього потрібен один файл).
