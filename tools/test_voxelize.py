#!/usr/bin/env python3
"""Тести tools/voxelize.py на синтетичному звірятку з коробок trimesh.

Запуск:  python3 tools/test_voxelize.py
Без GUT і без pytest — самі assert'и, щоб працювало будь-де, де є trimesh + numpy.

Головне, що перевіряємо, — мапінг координат VoxelBuilder.parse (GDScript):
    for y in layers:  for z in rows:  for x in row:  cells[Vector3i(x, y, z)]
тобто layers[y][z][x]: індекс шару -> y (знизу вгору), індекс рядка -> z,
позиція символу в рядку -> x. Ряд z = 0 — перед моделі (-Z), бо VoxelBuilder
центрує меш по x/z, а Hero3D тримає морду на FACE_Z = -0.425 (тобто в -Z).
Нижче ця логіка повторена в parse_def() і звірена з тим, що пише voxelize.py.
"""

from __future__ import annotations

import math
import sys
import tempfile
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import voxelize as vz  # noqa: E402

MAX_PART_M = 0.6      # tests/test_heroes_v15.gd
PALETTE_KEYS = set("odckitm")
PITCH = vz.DEFAULT_PITCH      # 0,04 м — сітка v2


# ---------- копія VoxelBuilder.parse() у Python ----------

def parse_def(d: dict) -> dict:
    """Те саме, що VoxelBuilder.parse(): -> {"cells": {(x, y, z): "#hex"}, "size": (w, h, dep)}."""
    palette = d.get("palette", {})
    layers = d.get("layers", [])
    cells, w, dep = {}, 0, 0
    for y, rows in enumerate(layers):
        dep = max(dep, len(rows))
        for z, row in enumerate(rows):
            w = max(w, len(row))
            for x, ch in enumerate(row):
                if ch in (".", " "):
                    continue
                assert ch in palette, f"символ '{ch}' не в палітрі"
                cells[(x, y, z)] = palette[ch]
    return {"cells": cells, "size": (w, len(layers), dep)}


# ---------- синтетичне звірятко ----------

def toy_quadruped(tail: str = "back"):
    """Чотирилапе з коробок, морда в -Z. -> trimesh.Trimesh.

    tail="back"   — хвіст стирчить позаду тулуба (легкий випадок);
    tail="raised" — хвіст піднятий над крупом, як у лисеняти з Meshy: за спину майже
                    не виступає, тож самої «задньої площини тулуба» для нього мало.
    """
    import trimesh

    def box(w, h, d, x, y, z):
        m = trimesh.creation.box(extents=[w, h, d])
        m.apply_translation([x, y + h / 2.0, z])
        return m

    parts = [
        box(0.45, 0.375, 0.60, 0.0, 0.225, 0.05),          # тулуб
        box(0.50, 0.450, 0.45, 0.0, 0.530, -0.20),         # голова (попереду)
        box(0.09, 0.250, 0.09, -0.15, 0.980, -0.20),       # ліве вухо
        box(0.09, 0.250, 0.09, 0.15, 0.980, -0.20),        # праве вухо
    ]
    if tail == "raised":
        parts.append(box(0.14, 0.280, 0.12, 0.0, 0.570, 0.33))   # хвіст угору над крупом
    else:
        parts.append(box(0.15, 0.150, 0.20, 0.0, 0.400, 0.45))   # хвіст позаду
    for sx in (-0.15, 0.15):
        for sz in (-0.14, 0.26):
            parts.append(box(0.15, 0.225, 0.15, sx, 0.0, sz))
    return trimesh.util.concatenate(parts)


def default_opts():
    return vz.make_parser().parse_args(["toy.glb"])


# ---------- тести ----------

def test_helpers():
    assert vz.hex_to_rgb("#F08A3C") == (240, 138, 60)
    assert vz.rgb_to_hex((240, 138, 60)) == "#F08A3C"
    # як Color.darkened(0.22) у Godot — множення каналів
    assert vz.darken("#646464", 0.5) == "#323232"
    assert vz._parse_front("+x") == (1, "x")
    # кут повороту: заданий бік має стати -Z
    assert math.isclose(vz._front_angle("z", -1), 0.0)
    assert math.isclose(vz._front_angle("z", 1), math.pi)
    print("ok  helpers")


def test_mapping_layers_y_rows_z_cols_x():
    """to_def має писати layers[y][z][x] — інакше герой буде розвернутий або дзеркальний."""
    sym = np.full((3, 2, 4), vz.EMPTY, dtype="<U1")
    sym[2, 1, 0] = "k"     # x = 2, y = 1, z = 0 (перед)
    sym[0, 0, 3] = "o"     # x = 0, y = 0, z = 3 (зад)
    d = vz.to_def(sym, 0.075, {"o": "#F08A3C", "k": "#4A2C2A"}, "тест")
    assert len(d["layers"]) == 2, "шарів = y"
    assert len(d["layers"][0]) == 4, "рядків у шарі = z"
    assert len(d["layers"][0][0]) == 3, "довжина рядка = x"
    assert d["layers"][1][0] == "..k", "y = 1, z = 0, x = 2"
    assert d["layers"][0][3] == "o..", "y = 0, z = 3, x = 0"
    cells = parse_def(d)["cells"]
    assert cells == {(2, 1, 0): "#4A2C2A", (0, 0, 3): "#F08A3C"}, "round-trip через parse()"
    assert parse_def(d)["size"] == (3, 2, 4)
    print("ok  мапінг layers[y][z][x]")


def test_front_rotation_puts_face_at_minus_z():
    """Модель, що дивиться в +X, після load_mesh має дивитись у -Z."""
    import trimesh

    toy = toy_quadruped()
    # розвертаємо іграшку мордою в +X: -Z -> +X, тобто поворот на -90° навколо Y
    toy.apply_transform(trimesh.transformations.rotation_matrix(-math.pi / 2.0, [0, 1, 0]))
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "toy_x.glb"
        toy.export(str(path))
        mesh = vz.load_mesh(path, 0.98, "auto", verbose=False)
    v = np.asarray(mesh.vertices)
    top = v[v[:, 1] >= v[:, 1].max() * 0.55]
    assert top[:, 2].mean() < v[:, 2].mean(), "голова має бути в -Z"
    assert math.isclose(float(mesh.extents[1]), 0.98, abs_tol=1e-6), "висота = --height"
    lo, hi = mesh.bounds
    assert math.isclose(lo[1], 0.0, abs_tol=1e-6), "база на y = 0"
    assert math.isclose(lo[0] + hi[0], 0.0, abs_tol=1e-6), "центр по x"
    print("ok  перед моделі -> -Z, база на y = 0")


def test_z_up_is_rotated():
    """Експорт із Z-up (висота вздовж Z) має автоматично лягти в Y-up."""
    import trimesh

    toy = toy_quadruped()
    toy.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [1, 0, 0]))
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "toy_zup.glb"
        toy.export(str(path))
        mesh = vz.load_mesh(path, 0.98, "auto", verbose=False)
    assert math.isclose(float(mesh.extents[1]), 0.98, abs_tol=1e-6), "після повороту висота по Y"
    assert mesh.extents[1] > mesh.extents[0], "зростом угору, а не вбік"
    print("ok  Z-up -> Y-up")


def segment_toy(pitch=PITCH, tail="back"):
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "toy.glb"
        toy_quadruped(tail).export(str(path))
        mesh = vz.load_mesh(path, 0.98, "-z", verbose=False)
    occ = vz.voxelize(mesh, pitch, verbose=False)
    opts = default_opts()
    labels, info = vz.segment(occ, pitch, opts)
    return occ, labels, info, opts


def test_segmentation():
    occ, labels, info, _opts = segment_toy()
    ny = occ.shape[1]

    assert sorted(info["legs"]) == ["BL", "BR", "FL", "FR"], f"чотири лапки, а не {info['legs']}"
    for lbl in (vz.L_FL, vz.L_FR, vz.L_BL, vz.L_BR):
        assert (labels == lbl).any(), "кожна лапка має вокселі"
    # передні лапки попереду задніх (менший z)
    fz = np.argwhere(labels == vz.L_FL)[:, 2].mean()
    bz = np.argwhere(labels == vz.L_BL)[:, 2].mean()
    assert fz < bz, "FL має бути попереду BL (менший z)"
    # ліві лапки ліворуч від правих (менший x — як -HIP_X у Hero3D)
    lx = np.argwhere(labels == vz.L_FL)[:, 0].mean()
    rx = np.argwhere(labels == vz.L_FR)[:, 0].mean()
    assert lx < rx, "FL ліворуч від FR (менший x)"

    head = np.argwhere(labels == vz.L_HEAD)
    assert len(head) > 0, "голова знайшлась"
    assert 0 < info["neck_y"] < ny - 1
    assert head[:, 1].min() >= info["neck_y"], "уся голова вище за шию"
    torso = np.argwhere(labels == vz.L_TORSO)
    assert head[:, 1].mean() > torso[:, 1].mean(), "голова вище за тулуб"
    assert head[:, 2].mean() < torso[:, 2].mean(), "голова попереду тулуба (менший z)"

    ears = np.argwhere((labels == vz.L_EAR_L) | (labels == vz.L_EAR_R))
    assert len(ears) > 0, "вуха знайшлись"
    assert (labels == vz.L_EAR_L).any() and (labels == vz.L_EAR_R).any(), "вуха розділені по x"
    el = np.argwhere(labels == vz.L_EAR_L)[:, 0].mean()
    er = np.argwhere(labels == vz.L_EAR_R)[:, 0].mean()
    assert el < er, "L-вухо ліворуч"

    tail = np.argwhere(labels == vz.L_TAIL)
    assert len(tail) > 0, "хвіст знайшовся"
    assert tail[:, 2].min() > torso[:, 2].max(), "хвіст позаду тулуба"
    print(f"ok  сегментація: {info['counts']}, шия y = {info['neck_y']}")


def test_tail_raised_over_rump():
    """Піднятий хвіст (лисеня) має знайтись, хоч за спину майже не виступає."""
    _occ, labels, info, _opts = segment_toy(tail="raised")
    tail = np.argwhere(labels == vz.L_TAIL)
    assert len(tail) > 0, "піднятий хвіст знайшовся (перший запуск давав порожньо)"
    torso = np.argwhere(labels == vz.L_TORSO)
    assert tail[:, 1].mean() > torso[:, 1].mean(), "хвіст вище за тулуб"
    assert tail[:, 2].mean() > info["torso_back_z"] - 1, "хвіст у задній чверті тулуба"
    # хвіст — не половина тулуба: евристика не мала з'їсти круп
    assert len(tail) < len(torso), "хвіст менший за тулуб"
    print(f"ok  піднятий хвіст: {len(tail)} вокселів, задня площина z = {info['torso_back_z']}")


def test_tail_json_grows_backwards():
    """Ряд 0 хвоста — передня грань біля шарніра, кінчик t — у найдальших рядах."""
    _occ, labels, _info, opts = segment_toy()
    sym = vz.colorize(labels, PITCH, opts)
    sub = vz.fit_part(vz.cut_part(sym, labels == vz.L_TAIL), "tail", PITCH)
    assert math.isclose(sub.shape[2] * PITCH, vz.TAIL_LEN, abs_tol=PITCH), \
        "довжина хвоста = Hero3D.TAIL_LEN ± воксель (Hero3D зсуває меш на пів довжини)"
    solid = np.argwhere(sub != vz.EMPTY)[:, 2]
    assert int(solid.min()) == 0, "ряд 0 — передня грань біля шарніра (порожні ряди лише ззаду)"
    zs = np.argwhere(sub == "t")[:, 2]
    assert len(zs) and zs.mean() >= solid.mean(), "кінчик t — у найдальших рядах, а не біля шарніра"
    print(f"ok  хвіст росте назад: {sub.shape[2]} рядів × {PITCH} м")


def test_colors():
    _occ, labels, _info, opts = segment_toy()
    sym = vz.colorize(labels, PITCH, opts)
    used = {s for s in sym.ravel() if s != vz.EMPTY}
    assert used <= PALETTE_KEYS, f"символи поза палітрою Hero3D: {used - PALETTE_KEYS}"
    assert "o" in used and "d" in used, "основний і темніший є"
    assert "c" in used, "кремова морда є"
    assert "k" in used, "темне (носик/копитця) є"
    assert "t" in used, "кінчик хвоста є"
    assert "m" not in used, "m лише з --marks"
    # копитця — найнижчий шар лапки
    leg = np.argwhere(labels == vz.L_FL)
    y0 = leg[:, 1].min()
    assert all(sym[x, y, z] == "k" for x, y, z in leg[leg[:, 1] == y0]), "низ лапки — копитце"
    # кінчик хвоста — найдальші вокселі
    tail = np.argwhere(labels == vz.L_TAIL)
    z1 = tail[:, 2].max()
    assert all(sym[x, y, z] == "t" for x, y, z in tail[tail[:, 2] == z1]), "кінчик хвоста — t"
    print(f"ok  кольори-символи: {''.join(sorted(used))}")


def test_parts_json_fits_game_rules():
    """Кожна частина після --fit проходить перевірки tests/test_heroes_v15.gd.

    Контракт v2 — у МЕТРАХ: висота частини = константа Hero3D з допуском в один воксель,
    кількість вокселів вільна (її задає --pitch). Тому тут немає жодного 6×5×8.
    """
    _occ, labels, _info, opts = segment_toy()
    sym = vz.colorize(labels, PITCH, opts)
    palette = vz.build_palette({"color": "#F08A3C", "accent": "#F6E3C2"})
    masks = {
        "body": labels == vz.L_TORSO,
        "head": labels == vz.L_HEAD,
        "leg": labels == vz.L_FL,
        "tail": labels == vz.L_TAIL,
        "ear": labels == vz.L_EAR_R,
    }
    exact_h = {"body": vz.BODY_H, "head": vz.HEAD_H, "leg": vz.LEG_H}
    for kind, mask in masks.items():
        sub = vz.cut_part(sym, mask)
        assert sub is not None, f"{kind}: частина не порожня"
        sub = vz.fit_part(sub, kind, PITCH)
        assert (sub != vz.EMPTY).any(), f"{kind}: після --fit лишились вокселі"
        size = PITCH
        d = vz.to_def(sub, size, palette, "тест")

        widths = {len(row) for layer in d["layers"] for row in layer}
        assert len(widths) == 1, f"{kind}: усі рядки однакової довжини"
        assert set(d["palette"]) <= PALETTE_KEYS, f"{kind}: ключі палітри Hero3D підмінює"
        parsed = parse_def(d)                       # кине assert, якщо символ не в палітрі
        assert len(parsed["cells"]) == int((sub != vz.EMPTY).sum()), f"{kind}: round-trip без утрат"
        w, h, dep = parsed["size"]
        assert (w, h, dep) == (sub.shape[0], sub.shape[1], sub.shape[2]), f"{kind}: габарит зберігся"
        assert w * size < MAX_PART_M, f"{kind}: не ширше за {MAX_PART_M} м"
        assert h * size < MAX_PART_M, f"{kind}: не вище за {MAX_PART_M} м"
        if kind in exact_h:
            # допуск — рівно один воксель: контракт у метрах, а не в кількості вокселів
            assert math.isclose(h * size, exact_h[kind], abs_tol=size), \
                f"{kind}: висота {h * size:.3f} ≠ {exact_h[kind]} ± {size} — тест гри впаде"
        if kind == "head":
            assert math.isclose(dep * size, vz.HEAD_HALF_D * 2.0, abs_tol=size), \
                "head: глибина = 2 × HEAD_HALF_D ± воксель — інакше очі Hero3D потонуть у голові"
        if kind == "ear":
            assert h * size <= vz.EAR_MAX_H + 1e-6, f"ear: не вище за {vz.EAR_MAX_H} м"
        if kind == "tail":
            assert math.isclose(dep * size, vz.TAIL_LEN, abs_tol=size), \
                "tail: довжина = Hero3D.TAIL_LEN ± воксель"
    print("ok  JSON частин проходить правила test_heroes_v15.gd (контракт у метрах)")


def test_fit_is_metres_not_voxels():
    """Той самий бокс на різних --pitch дає ту саму висоту в метрах, але різну кількість шарів."""
    sub = np.full((7, 9, 7), "o", dtype="<U1")
    counts = {}
    for pitch in (0.075, 0.05, 0.04):
        out = vz.fit_part(sub, "head", pitch)
        counts[pitch] = out.shape[1]
        assert math.isclose(out.shape[1] * pitch, vz.HEAD_H, abs_tol=pitch), \
            f"pitch {pitch}: висота голови {out.shape[1] * pitch:.3f} ≠ {vz.HEAD_H}"
        assert math.isclose(out.shape[2] * pitch, vz.HEAD_HALF_D * 2.0, abs_tol=pitch)
        assert out.shape[0] * pitch < 0.6, "ширина в межах правила гри"
    assert counts[0.04] > counts[0.075], "дрібніший pitch = більше вокселів на ту саму висоту"
    print(f"ok  --fit у метрах: шарів голови {counts}")


def test_vox_round_trip():
    sym = np.full((3, 2, 4), vz.EMPTY, dtype="<U1")
    sym[2, 1, 0] = "k"
    sym[0, 0, 3] = "o"
    palette = {"o": "#F08A3C", "k": "#4A2C2A"}
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "t.vox"
        vz.write_vox(path, sym, palette)
        assert path.read_bytes()[:4] == b"VOX "
        grid, vox_pal = vz.read_vox(path)
    assert grid.shape == sym.shape, "осі .vox повернулись у наші (x, y, z)"
    back = {tuple(p): vz.rgb_to_hex(vox_pal[grid[tuple(p)]]) for p in np.argwhere(grid > 0)}
    assert back == {(2, 1, 0): "#4A2C2A", (0, 0, 3): "#F08A3C"}, "кольори й позиції збіглись"
    print("ok  .vox запис/читання")


def test_resample_keeps_shape_and_content():
    sub = np.full((4, 6, 4), "o", dtype="<U1")
    out = vz.resample(sub, (2, 3, 2))
    assert out.shape == (2, 3, 2)
    assert (out == "o").all(), "суцільний блок лишився суцільним"
    empty = np.full((4, 4, 4), vz.EMPTY, dtype="<U1")
    empty[0, 0, 0] = "o"
    # усе б стерлось — resample повертає оригінал, щоб частина не зникла
    assert vz.resample(empty, (1, 1, 1)).shape in ((1, 1, 1), (4, 4, 4))
    print("ok  resample")


def voxel_blob(size: float = 0.05):
    """Готова «воксельна» модель: кубики size на рівній сітці, два кольори. -> (mesh, {(x,y,z): rgb})."""
    import trimesh

    cells = [(0, 0, 0), (1, 0, 0), (2, 0, 0), (0, 1, 0), (1, 1, 0), (1, 1, 1), (1, 2, 0)]
    red, blue = (200, 40, 40, 255), (40, 80, 200, 255)
    parts, want = [], {}
    for c in cells:
        box = trimesh.creation.box(extents=[size, size, size])
        box.apply_translation([(c[0] + 0.5) * size, (c[1] + 0.5) * size, (c[2] + 0.5) * size])
        rgba = red if c[1] == 0 else blue          # нижній ряд червоний, решта синя
        box.visual.vertex_colors = np.tile(np.array(rgba, dtype=np.uint8), (len(box.vertices), 1))
        parts.append(box)
        want[c] = rgba[:3]
    return trimesh.util.concatenate(parts), want


def test_exact_grid_detection():
    """--exact: крок сітки, кількість кубиків і кольори читаються з готової воксельної моделі."""
    size = 0.05
    mesh, want = voxel_blob(size)

    got = vz.detect_cube_size(mesh, verbose=False)
    assert math.isclose(got, size, rel_tol=1e-6), f"розмір кубика {got} ≠ {size}"

    fcol, src = vz.face_colors(mesh, verbose=False)
    # trimesh після concatenate віддає ColorVisuals або по вершинах, або по гранях — годиться і те, і те
    assert src in ("vertex_colors", "face_colors"), f"кольори прийшли з «{src}», а не з моделі"
    assert len(fcol) == len(mesh.faces)

    occ, colors = vz.exact_grid(mesh, got, fcol, "faces", verbose=False)
    assert occ.shape == (3, 3, 2), f"сітка {occ.shape} ≠ (3, 3, 2)"
    assert int(occ.sum()) == len(want), f"кубиків {int(occ.sum())} ≠ {len(want)}"
    assert {tuple(int(v) for v in p) for p in np.argwhere(occ)} == set(want), "позиції кубиків"
    for cell, rgb in want.items():
        assert colors[cell] == rgb, f"колір кубика {cell}: {colors.get(cell)} ≠ {rgb}"

    quant = vz.quantize_colors(colors, 16, verbose=False)
    assert len(set(quant.values())) == 2, "після квантування лишилось два кольори"
    sym, palette = vz.symbolize(occ, quant)
    assert len(palette) == 2, f"палітра з двох символів, а не {palette}"
    assert not (set(palette) & set("odckitm")), "символи не перетинаються з підміною Hero3D"
    assert int((sym != vz.EMPTY).sum()) == len(want), "символ у кожному кубику"
    print(f"ok  --exact: кубик {got:.3f} м, {int(occ.sum())} вокселів, "
          f"кольори {''.join(sorted(palette))}")


def main() -> int:
    try:
        import trimesh  # noqa: F401
    except ImportError:
        print("Потрібні залежності. Встанови їх:\n    pip3 install trimesh numpy")
        return 1
    test_helpers()
    test_mapping_layers_y_rows_z_cols_x()
    test_resample_keeps_shape_and_content()
    test_vox_round_trip()
    test_front_rotation_puts_face_at_minus_z()
    test_z_up_is_rotated()
    test_exact_grid_detection()
    test_segmentation()
    test_tail_raised_over_rump()
    test_tail_json_grows_backwards()
    test_colors()
    test_fit_is_metres_not_voxels()
    test_parts_json_fits_game_rules()
    print("\nусі тести пройшли")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
