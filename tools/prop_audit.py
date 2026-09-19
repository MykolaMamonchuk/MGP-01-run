#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""prop_audit.py — звірка УСІХ моделей гри з їхніми джерелами в docs/refs/incoming/.

Навіщо. Модель проходить довгий шлях: генератор → `docs/refs/incoming/<вид>/…_mesh.glb` →
запікання або спрощення → `assets/props/…glb` → рядок у `data/props.json`. На кожному кроці
щось може відстати: джерело оновили, а в грі лишилась стара; модель запекли, але схожість
просіла нижче 80%; джерело поклали, а в гру не поставили зовсім.

Поштучно це не видно, бо кроки різні й у різних теках. Тут — одна таблиця:

  ЗВІРЕНО      джерело і модель гри знайшли одне одного; поруч ваги й схожість
  НЕ В ГРІ     джерело є, моделі гри під нього нема — не поставили
  БЕЗ ДЖЕРЕЛА  модель гри є, джерела нема — зроблена інакше (tools/make_house.py, воксель)

Схожість нижче `--min` (типово 80, вимога замовника) позначається окремо.

    python3 tools/prop_audit.py                 # усе; схожість рахується — це кілька хвилин
    python3 tools/prop_audit.py --fast          # без схожості, лише ваги й відповідність
    python3 tools/prop_audit.py --only cart     # лише ті, чиє ім'я містить «cart»

Запускати з кореня проєкту.
"""
import argparse
import glob
import json
import os
import re
import struct
import subprocess

INCOMING = "docs/refs/incoming"
PROPS = "assets/props"

## Моделі, у яких низька схожість — хиба ПРИЛАДУ, а не вада. Перевірено очима 19.09.2026,
## порівнянням джерела й моделі гри поруч. Без цього списку звірка кричала б на них щоразу, і
## справжню ваду в шумі було б не помітити.
KNOWN_LOW = {
    "bridge_plank": "модель навмисно повернуто на 90° (prop_prepare --yaw 90), бо джерело "
                    "лежить уздовж іншої осі; прилад знімає з фіксованого ракурсу й бачить "
                    "поворот як іншу річ",
    "bush_flower_1": "листя: запікання зсуває дрібний візерунок, і прилад це систематично "
                     "занижує — про це сказано і в tools/prop_similarity.py",
    "bush_flower_2": "те саме, і додатково джерело ригнуте (_rigi) — приходить в іншій позі",
}


def stat(path):
    """(трикутники, байти) з .glb без Blender — читаємо JSON-шматок файлу."""
    data = open(path, "rb").read()
    if data[:4] != b"glTF":
        return 0, os.path.getsize(path)
    n = struct.unpack("<I", data[12:16])[0]
    j = json.loads(data[20:20 + n])
    tris = 0
    for m in j.get("meshes", []):
        for p in m["primitives"]:
            if "indices" in p:
                tris += j["accessors"][p["indices"]]["count"] // 3
    return tris, os.path.getsize(path)


def base_name(file_name):
    """cart_market_1_mesh.glb → cart_market_1; bush_flower_2_mesh_rigi.glb → bush_flower_2."""
    n = file_name[:-4] if file_name.endswith(".glb") else file_name
    return re.sub(r"_mesh(_rigi)?$", "", n)


def game_for(stem, have):
    """Яку модель гри вважати парою до джерела. Точний збіг, інакше без хвостового «_1»."""
    if stem in have:
        return stem
    short = re.sub(r"_\d+$", "", stem)
    return short if short in have else ""


def similarity(src, dst):
    out = subprocess.run(["python3", "tools/prop_similarity.py", src, dst],
                         capture_output=True, text=True)
    m = re.search(r"схожість\s+([\d.]+)%.*?ділянка\s+([\d.]+)%", out.stdout)
    return (float(m.group(1)), float(m.group(2))) if m else (None, None)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--fast", action="store_true")
    ap.add_argument("--min", type=float, default=80.0)
    a = ap.parse_args()

    have = {os.path.basename(p)[:-4] for p in glob.glob("%s/*.glb" % PROPS)}
    if not have:
        raise SystemExit("моделей гри не знайдено — запускати з кореня проєкту")
    referenced = open("data/props.json").read()

    sources = sorted(glob.glob("%s/*/*.glb" % INCOMING))
    if a.only:
        sources = [s for s in sources if a.only in s]
        have = {h for h in have if a.only in h}

    print("ЗВІРЕНО — джерело й модель гри знайшли одне одного")
    print("  %-22s %-24s %18s   %18s   %s"
          % ("джерело", "у грі", "граней", "МБ", "схожість"))
    matched = set()
    low = []
    for src in sources:
        stem = base_name(os.path.basename(src))
        game = game_for(stem, have)
        if not game:
            continue
        matched.add(game)   # саме ім'я В ГРІ: джерело зветься інакше (house_terra_8 → house_terra)
        dst = "%s/%s.glb" % (PROPS, game)
        st, sb = stat(src)
        dt, db = stat(dst)
        sim = ""
        if not a.fast:
            whole, worst = similarity(src, dst)
            if whole is None:
                sim = "не порахувалась"
            else:
                sim = "%5.1f%% (найгірша %4.1f%%)" % (whole, worst)
                if whole < a.min:
                    if game in KNOWN_LOW:
                        sim += "   (перевірено оком — хиба приладу)"
                    else:
                        sim += "   ← НИЖЧЕ %d%%" % a.min
                        low.append((game, whole))
        print("  %-22s %-24s %8d → %-7d %8.2f → %-7.2f %s"
              % (os.path.basename(src)[:-4], game, st, dt, sb / 1e6, db / 1e6, sim))

    idle = [base_name(os.path.basename(s)) for s in sources
            if not game_for(base_name(os.path.basename(s)), have)]
    if idle:
        print("\nНЕ В ГРІ — джерело лежить, моделі під нього нема")
        for n in sorted(idle):
            print("  %s" % n)

    own = sorted(h for h in have if h not in matched)
    if own:
        print("\nБЕЗ ДЖЕРЕЛА — зроблені інакше (генератор у tools/, воксель) або джерело не зберегли")
        for n in own:
            t, b = stat("%s/%s.glb" % (PROPS, n))
            mark = "" if n in referenced else "   ← І НЕ ЗГАДАНА в data/props.json"
            print("  %-26s %6d гр.  %.2f МБ%s" % (n, t, b / 1e6, mark))

    print("\nразом: джерел %d, звірено %d, не в грі %d, без джерела %d"
          % (len(sources), len(matched), len(idle), len(own)))
    if low:
        print("нижче %d%% схожості: %s" % (a.min, ", ".join("%s %.0f%%" % x for x in low)))
    else:
        print("нижче %d%% схожості: нема (крім відомих хиб приладу — див. KNOWN_LOW)" % a.min)

    # Моделі, що пройшли повз спрощення: у джерела й у грі однакове число граней. Текстури
    # при цьому стиснулись, тому за розміром файлу цього не видно зовсім.
    print("")
    for src in sources:
        stem = base_name(os.path.basename(src))
        game = game_for(stem, have)
        if not game:
            continue
        st, _ = stat(src)
        dt, _ = stat("%s/%s.glb" % (PROPS, game))
        if st == dt and st > 0:
            print("НЕ СПРОЩУВАЛАСЬ: %-18s %d граней — стільки ж, скільки в джерелі" % (game, dt))


main()
