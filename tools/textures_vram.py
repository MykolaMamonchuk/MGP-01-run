#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""textures_vram.py — увімкнути стиснення в відеопам'яті для текстур моделей.

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

    python3 tools/textures_vram.py
    /Applications/Godot.app/Contents/MacOS/Godot --headless --import
"""
import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

## Герої йдуть у ЯКІСНОМУ режимі, пропси — у звичайному, і це не перестраховка.
## Звичайне стиснення тримає колір грубо, і на м'яких градієнтах хутра з'являються смуги:
## на черепасі середнє відхилення вийшло 8,4 при власному шумі знімка 1,3. Якісний режим
## дав 4,96, а в зоопарку (нормальна ігрова відстань) — 0,97 при шумі 0,73, тобто вже
## нерозрізненно. Пропсам це не потрібно: дерево й камінь градієнтів не мають, там
## звичайного режиму вистачило з відхиленням 0,3%, а пам'яті він бере вдвічі менше.
HIGH_QUALITY = ("assets/models",)

## Стеля роздільності при ІМПОРТІ. Саме так, а не переекспортом моделі: герої риговані, і
## прогін .glb через Blender може перетасувати кістки, від яких залежить уся анімація.
## Godot же просто зменшує картинку на вході, джерело лишається недоторканим.
##
## Пропсам стеля 512, і це не «на око». Міряти треба ЩІЛЬНІСТЬ ТЕКСЕЛІВ — пікселів текстури
## на метр моделі, — бо саме вона вирішує, розмито чи ні. Габарити взято рушієм
## (`tools/vram/prop_closeup.gd` друкує їх): віз 0,95 м, бочка 0,70 м, будинок 2,06 м.
## При 512 віз має 539 пк/м, бочка 731 — більше за будинок на 1024 (497 пк/м), який ми
## визнали добрим. Тобто 512 для метрового пропса це НЕ економія за рахунок вигляду.
SIZE_LIMIT = {"assets/models": 1024, "assets/props": 512}

## Виняток зі стелі 512: те, що більше за півтора метра. При 512 будинок мав би 248 пк/м —
## удвічі менше, ніж він займає на екрані, і це видно: 19.09.2026 у кадрі рівня 2 різьблення
## віконних рам розмилося, 15,9% ділянки будинку за порогом 4/255 (середнє 2,46, найбільше
## 89) при НУЛЬОВОМУ шумі між двома однаковими прогонами. Числом воно ще проходило (95,3%
## за порогом 12), але оком — ні, а приймає замовник оком.
KEEP_FULL_SIZE = ("house_terra",)


def main():
    changed = []
    targets = []
    for folder in ("assets/props", "assets/models"):
        targets += sorted(glob.glob(os.path.join(ROOT, folder, "*.import")))
    for path in targets:
        text = open(path, encoding="utf-8").read()
        if "CompressedTexture2D" not in text:
            continue
        out = text.replace("compress/mode=0", "compress/mode=2")
        if any(folder in path for folder in HIGH_QUALITY):
            out = out.replace("compress/high_quality=false", "compress/high_quality=true")
        if not any(big in os.path.basename(path) for big in KEEP_FULL_SIZE):
            for folder, limit in SIZE_LIMIT.items():
                if folder in path:
                    out = re.sub(r"process/size_limit=\d+", "process/size_limit=%d" % limit, out)
        # Нормаль має свій канальний розклад: її беруть двоканальним RGTC/EAC, а не
        # кольоровим DXT1. `compress/normal_map` — це перелік «Detect, Enable, Disabled»,
        # тобто потрібна ОДИНИЦЯ. Двійка — «Disabled», і саме вона тут стояла до 19.09.2026:
        # десять карт нормалей лягли в пам'ять як DXT1 (fmt=17, 565 без альфи) замість
        # RGTC_RG (fmt=21). Видно заміром `tools/vram/vram_audit.gd` — формат друкується.
        if "_normal." in os.path.basename(path):
            out = re.sub(r"compress/normal_map=[02]", "compress/normal_map=1", out)
        if out == text:
            continue
        open(path, "w", encoding="utf-8").write(out)
        changed.append(os.path.basename(path))
        # прибрати закешований результат, інакше Godot лишить старий
        for dest in re.findall(r'res://(\.godot/imported/[^"]+)', out):
            for stale in glob.glob(os.path.join(ROOT, dest.rsplit("-", 1)[0]) + "-*"):
                os.remove(stale)

    if not changed:
        print("усі текстури моделей уже стиснені")
        return
    print("увімкнено стиснення для %d текстур:" % len(changed))
    for name in changed:
        print("  " + name)
    print("тепер: Godot --headless --import")


main()
