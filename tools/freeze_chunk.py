#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""freeze_chunk.py — перетворити процедурне оздоблення цеглинки на МАРКЕРИ СЦЕНИ.

Навіщо. Процедурний декоратор зручний, поки світу мало, але має дві вади, і обидві заміряні:

  ВІН НЕСТАЛИЙ. Рівень 2, два прогони з різними зернами: 3042 і 3018 предметів, однакових
  лише 868. Найгірше з будинками (house_small 21↔30, house_teal 32↔24) і містками (104↔98) —
  вони йдуть лічильниками, тобто залежать від історії прогону, а не від місця.

  ЙОГО НЕ ВИДНО В РЕДАКТОРІ. Те, що він поставив, не можна ні посунути, ні прибрати, ні
  побачити, доки не запустиш гру. Через це предмети налазять одне на одне (дерево в будинку,
  тюки один на одному), і полагодити це нічим.

Заморожування прибирає обидві: оздоблення стає звичайними маркерами, які видно у сцені й
можна правити мишею, а рівень із `"authored": true` більше нічого не досипає.

Заморожуємо саме ЦЕГЛИНКУ, а не рівень: рівень тепер складається з цеглинок, і та сама
цеглинка стоїть на різних метрах різних рівнів. Тоді вона виглядає однаково скрізь.

Маркери лягають у теку «Декор» — ту саму, що й рукотворний декор: сторож
`tests/test_level_chunk_groups.gd` вимагає теку за РОЛЛЮ, а не за походженням.

Результат лягає в `dress_<світ>.tscn` ПОРУЧ із `chunk.tscn`, а не всередину нього. Так
рукотворне лишається в маленькому файлі, який можна читати очима, а вісім сотень маркерів
оздоблення — у своєму, куди зазирають лише за потреби.

    python3 tools/freeze_chunk.py meadow_village          # усі світи цеглинки
    python3 tools/freeze_chunk.py --all                   # усі цеглинки бібліотеки
    python3 tools/freeze_chunk.py meadow_village --world meadow

Запускати з кореня проєкту.
"""
import argparse
import glob
import json
import os
import re
import struct
import subprocess
import tempfile

GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
ROOT = "levels/chunks"
HEAD = '''[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://src/run3d/level_marker_3d.gd" id="1"]
[ext_resource type="Script" path="res://src/run3d/level_layout.gd" id="2"]

[node name="LevelLayout" type="Node3D"]
script = ExtResource("2")

[node name="Декор" type="Node3D" parent="."]
'''


def freeze(chunk, world, out_json):
    env = dict(os.environ, CHUNK=chunk, WORLD=world, OUT=out_json)
    env.pop("GAME_SEED", None)          # зерно ставить сам інструмент, стале
    subprocess.run([GODOT, "--headless", "--path", ".", "res://src/debug/freeze_chunk.tscn"],
                   env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    with open(out_json) as f:
        return json.load(f)


## --- сліди пропсів і відсів накладок -----------------------------------------------------
##
## Заморожене оздоблення мусить ПОСТУПАТИСЯ рукотворному. Декоратор не знає нічого про
## маркери, які автор поставив у chunk.tscn, і кидає дерева просто у вежу-орієнтир. Тому після
## заморожування ми викидаємо ті предмети оздоблення, що налазять на рукотворні.
##
## Листя з листям не рахуємо: із цього й складається лісова стіна та кущі.
FOLIAGE = {"tree", "tree_round", "pine_3", "wall_tree_tall", "bush", "bush_cube", "bush_flower",
           "flower", "flower_pink", "flower_yellow", "mushroom", "mushroom_red", "mossrock",
           "rock", "rock_grey", "canopy_leaves", "garden", "branch"}


def glb_size(path):
    d = open(path, "rb").read()
    if d[:4] != b"glTF":
        return None
    n = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + n])
    mn = [9e9] * 3
    mx = [-9e9] * 3
    for m in j.get("meshes", []):
        for p in m["primitives"]:
            a = j["accessors"][p["attributes"]["POSITION"]]
            for i in range(3):
                mn[i] = min(mn[i], a["min"][i])
                mx[i] = max(mx[i], a["max"][i])
    return [mx[i] - mn[i] for i in range(3)]


def prop_sizes():
    """Габарити кожного виду з його ж .glb — не здогад, а факт моделі."""
    out = {}
    for kind, v in json.load(open("data/props.json")).items():
        if kind.startswith("_"):
            continue
        paths = [v] if isinstance(v, str) else (
            [x if isinstance(x, str) else x.get("path", "") for x in v] if isinstance(v, list)
            else [v.get("path", "")])
        best = None
        for p in paths:
            f = p[6:] if p.startswith("res://") else ""
            if f and os.path.exists(f):
                sz = glb_size(f)
                if sz and (best is None or sz[0] * sz[2] > best[0] * best[2]):
                    best = sz
        if best:
            out[kind] = best
    return out


def hand_markers(path):
    """Рукотворні маркери цеглинки: [{kind, x, y, z, w, d, h}]. Перешкоди не рахуємо —
    вони живуть у смугах і оздоблення туди не кладеться."""
    out = []
    if not os.path.exists(path):
        return out
    for b in open(path).read().split("[node ")[1:]:
        if "script = ExtResource" not in b:
            continue
        role = (re.search(r'role = "(\w+)"', b) or [None, "decor"])[1]
        # Рукотворне лишається рукотворним: заморожуємо лише ОЗДОБЛЕННЯ. Золото тут разом
        # із перешкодами й пікапами — воно теж авторське, і підміняти його процедурним
        # декором не можна (kind у нього не пропс, а фігура: line/climb/arc/cluster).
        if role in ("obstacle", "pickup", "gold"):
            continue
        kind = (re.search(r'kind = "([\w_]+)"', b) or [None, ""])[1]
        tr = re.search(r"Transform3D\(([^)]*)\)", b)
        if not kind or not tr:
            continue
        a = [float(x) for x in tr.group(1).split(",")]
        sc = float((re.search(r"scale_mul = ([\d.]+)", b) or [None, 1.0])[1])
        yaw = float((re.search(r"yaw_deg = (-?[\d.]+)", b) or [None, 0.0])[1])
        out.append({"kind": kind, "x": a[9], "y": a[10], "z": -a[11], "s": sc, "yaw": yaw})
    return out


def boxed(m, sizes):
    w, h, d = sizes.get(m["kind"], [0.0, 0.0, 0.0])
    q = round(abs(m.get("yaw", 0.0)) / 90.0) % 2      # поворот на 90° міняє ширину з глибиною
    m["w"] = (d if q else w) * m["s"]
    m["d"] = (w if q else d) * m["s"]
    m["h"] = h * m["s"]
    return m


def hits(a, b):
    if a["kind"] in FOLIAGE and b["kind"] in FOLIAGE:
        return False
    if abs(b["x"] - a["x"]) >= (a["w"] + b["w"]) * 0.5:
        return False
    if abs(b["z"] - a["z"]) >= (a["d"] + b["d"]) * 0.5:
        return False
    return not (a["y"] > b["y"] + b["h"] or b["y"] > a["y"] + a["h"])


def drop_clashes(records, hand, sizes):
    """Викинути оздоблення, що налазить на рукотворне або на іншу будівлю оздоблення."""
    hand = [boxed(dict(m), sizes) for m in hand]
    kept = []
    for r in records:
        if not r.get("kind") or r["kind"] == "?" or r["kind"] not in sizes:
            kept.append(r)
            continue
        m = boxed({"kind": r["kind"], "x": float(r["x_m"]), "y": float(r.get("y_m", 0.0)),
                   "z": float(r["z_m"]), "s": float(r.get("scale", 1.0)),
                   "yaw": float(r.get("yaw_deg", 0.0))}, sizes)
        if any(hits(m, o) for o in hand):
            continue
        if any(hits(m, o) for o in kept if o.get("_box")):
            continue
        m["_box"] = True
        m.update({"z_m": r["z_m"], "x_m": r["x_m"], "y_m": r.get("y_m", 0.0),
                  "yaw_deg": r.get("yaw_deg", 0.0), "scale": r.get("scale", 1.0)})
        kept.append(m)
    return kept


def scene_text(records):
    out = [HEAD]
    for i, r in enumerate(records):
        if not r.get("kind") or r["kind"] == "?":
            continue          # декоратор не назвав вид — такий маркер нічого не намалює
        # Роль завжди «decor»: журнал декоратора не розрізняє забудову й дрібницю, а для
        # Track вони й так ідуть одним шляхом (_add_decor). Роль тут потрібна лише щоб
        # LevelTimeline поклав запис у потрібний масив.
        out.append('\n[node name="D%d_%s" type="Node3D" parent="Декор"]\n' % (i + 1, r["kind"]))
        out.append('script = ExtResource("1")\n')
        out.append('role = "decor"\n')
        out.append('kind = "%s"\n' % r["kind"])
        if abs(float(r.get("yaw_deg", 0.0))) > 0.01:
            out.append("yaw_deg = %.1f\n" % float(r["yaw_deg"]))
        if abs(float(r.get("scale", 1.0)) - 1.0) > 0.001:
            out.append("scale_mul = %.3f\n" % float(r["scale"]))
        out.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.2f, %.2f, %.2f)\n"
                   % (float(r["x_m"]), float(r.get("y_m", 0.0)), -float(r["z_m"])))
    return "".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("chunks", nargs="*")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--world", default="")
    a = ap.parse_args()

    ids = a.chunks
    if a.all:
        ids = sorted(os.path.basename(os.path.dirname(p))
                     for p in glob.glob("%s/*/chunk.json" % ROOT))
    if not ids:
        raise SystemExit("треба назвати цеглинку або --all")

    sizes = prop_sizes()
    tmp = tempfile.mkdtemp(prefix="freeze_")
    for chunk in ids:
        desc_path = "%s/%s/chunk.json" % (ROOT, chunk)
        if not os.path.exists(desc_path):
            print("  ПРОПУЩЕНО %s — нема опису" % chunk)
            continue
        with open(desc_path) as f:
            desc = json.load(f)
        worlds = [a.world] if a.world else list(desc.get("worlds", []))
        for world in worlds:
            data = freeze(chunk, world, os.path.join(tmp, "%s_%s.json" % (chunk, world)))
            before = len(data["decor"])
            data["decor"] = drop_clashes(data["decor"],
                                         hand_markers("%s/%s/chunk.tscn" % (ROOT, chunk)), sizes)
            dropped = before - len(data["decor"])
            out = "%s/%s/dress_%s.tscn" % (ROOT, chunk, world)
            with open(out, "w") as f:
                f.write(scene_text(data["decor"]))
            print("  %-22s %-8s %4d маркерів (відсіяно накладок: %d)"
                  % (chunk, world, len(data["decor"]), dropped))


main()
