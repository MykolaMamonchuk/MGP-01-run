# Експорт

## Android

1. Project → Export → Add → Android.
2. Renderer: Mobile (project вже налаштований на "mobile").
3. Orientation: landscape (уже задано в project.godot).
4. Min SDK: 24.
5. Package name: `com.mgp.run` (заміни на фінальний перед релізом).
6. Target audience: Everyone / mixed audience (без реклами для дорослих, COPPA-сумісно).

## Web

Пресет уже є в `export_presets.cfg`, і збирається він однією командою — увесь рецепт разом
із сервером, дебаг-накладкою і перевіркою в headless-браузері описано окремо:
**[web.md](web.md)**.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --export-release "Web" export/Bizhy-Bizhy.html
python3 tools/serve_web.py
```

Що варто знати наперед:

- **Рушій у браузері інший.** Проєкт стоїть на `mobile`, але браузер Vulkan не має, тож
  веб-збірка йде на Compatibility (WebGL 2). Малюється те саме, а от ЧИСЛА з дебаг-накладки
  веб-збірки не порівнюються з числами `tools/probe/` на Маку — це різні рушії.
- **Потоки вимкнено** (`variant/thread_support=false`): збірці не потрібен SharedArrayBuffer,
  тож її віддасть будь-який статичний хостинг, зокрема itch.io.
- **Міст MCP виключено** з пресета — див. web.md і `tests/test_export_presets.gd`.
