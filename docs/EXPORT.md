# Експорт

## Android

1. Project → Export → Add → Android.
2. Renderer: Mobile (project вже налаштований на "mobile").
3. Orientation: landscape (уже задано в project.godot).
4. Min SDK: 24.
5. Package name: `com.mgp.run` (заміни на фінальний перед релізом).
6. Target audience: Everyone / mixed audience (без реклами для дорослих, COPPA-сумісно).

## Web (для itch.io)

1. Project → Export → Add → Web.
2. У пресеті зміни Renderer на Compatibility (Mobile не для Web-експорту).
3. Вимкни Threads (itch.io не підтримує multi-threaded WASM без спецзаголовків).
4. Export → перевір локально перед завантаженням на itch.io.
