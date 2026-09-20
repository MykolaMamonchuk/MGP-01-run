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

**Час кадру з самого Android, а не з накладки:**

```bash
adb shell dumpsys gfxinfo com.selectoglobal.bizhybizhy framestats
```

Дає покадрову таблицю з розподілом на draw / prepare / process / execute — тобто той самий
поділ «CPU чи GPU», якого на Маку бракувало. Скинути лічильники перед заміром:
`adb shell dumpsys gfxinfo com.selectoglobal.bizhybizhy reset`.

**Пам'ять:** `adb shell dumpsys meminfo com.selectoglobal.bizhybizhy`.

**Консоль гри:** `adb logcat -s godot:V` (усе інше відсіюється).

**Кадр:** `adb exec-out screencap -p > /tmp/phone.png`.

**Без кабелю:** `adb tcpip 5555` один раз по USB, далі
`adb connect <ip-телефона>:5555` — і кабель можна прибрати.

## Чого НЕ робити

Не порівнювати числа телефона з числами `tools/probe/` на Маку напряму: різні рушії, різні
роздільності, різний масштаб рендера. Телефон порівнюють САМ ІЗ СОБОЮ — «до» й «після»
однієї правки, тим самим рівнем і тим самим профілем. Правило контрольного прогону з
`docs/MEMORY.md` тут діє так само, і навіть сильніше: телефон ще й гріється, тож третій
прогін поспіль повільніший за перший просто так.
