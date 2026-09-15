#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""prop_textures_vram.py — увімкнути стиснення в відеопам'яті для текстур пропсів.

Навіщо. Godot типово імпортує текстуру «без втрат»: у відеопам'яті вона лежить розпакованою,
2048×2048 RGBA з мипмапами — це 22 МБ на КОЖНУ карту. У пропса їх три (колір, шорсткість,
нормаль), і дев'ять карт на три паркани з'їдають близько 200 МБ. Зі стисненням — 25 МБ.
Виміряно: на знімку зблизька різниця 0,3% яскравості, тобто її не видно.

Чому окремим скриптом, а не руками. Ці налаштування живуть у .import-файлах, які Godot
переписує, коли переімпортовує .glb. Забути повернути їх легко, і пам'ять тихо виросте
вчетверо — без жодної помилки в консолі. Тому: додав пропс — прогнав скрипт.

ВАЖЛИВО: самої правки .import мало. Godot не переімпортовує через зміну налаштувань, і
готовий файл лишається старим (перевірено: байт у байт). Тому скрипт ще й прибирає
закешований результат.

    python3 tools/prop_textures_vram.py
    /Applications/Godot.app/Contents/MacOS/Godot --headless --import
"""
import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    changed = []
    for path in sorted(glob.glob(os.path.join(ROOT, "assets/props/*.import"))):
        text = open(path, encoding="utf-8").read()
        if "CompressedTexture2D" not in text:
            continue
        out = text.replace("compress/mode=0", "compress/mode=2")
        # нормаль має свій канальний розклад: без цієї позначки стиснення псує їй освітлення
        if "_normal." in os.path.basename(path):
            out = out.replace("compress/normal_map=0", "compress/normal_map=2")
        if out == text:
            continue
        open(path, "w", encoding="utf-8").write(out)
        changed.append(os.path.basename(path))
        # прибрати закешований результат, інакше Godot лишить старий
        for dest in re.findall(r'res://(\.godot/imported/[^"]+)', out):
            for stale in glob.glob(os.path.join(ROOT, dest.rsplit("-", 1)[0]) + "-*"):
                os.remove(stale)

    if not changed:
        print("усі текстури пропсів уже стиснені")
        return
    print("увімкнено стиснення для %d текстур:" % len(changed))
    for name in changed:
        print("  " + name)
    print("тепер: Godot --headless --import")


main()
