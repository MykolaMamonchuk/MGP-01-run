#!/usr/bin/env python3
"""Meshy .glb/.obj -> воксельні частини героя (data/voxels/*.json) + MagicaVoxel .vox.

Приклад (v2 — дрібна сітка, габарити підганяються в метрах):
    python3 tools/voxelize.py docs/refs/models/fox.glb --hero lys --height 0.98 --pitch 0.04 \
        --out data/voxels --vox docs/refs/models/out/

Приклад (v3, --exact — модель УЖЕ воксельна: кубики на рівній сітці):
    python3 tools/voxelize.py docs/refs/models/fox_voxel.glb --exact --name fox_voxel \
        --height 0.98 --out data/voxels --vox docs/refs/models/out/
У цьому режимі сітку не вигадуємо, а знаходимо: розмір кубика беремо з самої геометрії,
кольори — зі справжніх кольорів моделі (vertex colors / текстура / матеріал).

Формат виходу збігається з VoxelBuilder (addons/mgp_core/voxel/voxel_builder.gd):
    layers[y][z][x]  ->  y знизу вгору, z від переду (-Z) до заду (+Z), x зліва (-X) направо (+X).
Герой дивиться в -Z (Hero3D.FACE_Z = -0.425), тому перший рядок кожного шару — морда.
"""

from __future__ import annotations

import argparse
import json
import math
import struct
import sys
from collections import Counter, deque
from pathlib import Path

try:
    import numpy as np
except ImportError:  # pragma: no cover - дружнє повідомлення замість трейсбека
    sys.exit("Потрібні залежності. Встанови їх:\n    pip3 install trimesh numpy")


# ---------- константи гри (мають збігатися з Hero3D) ----------

ROOT = Path(__file__).resolve().parents[1]
EMPTY = "."

LEG_H = 0.225          # Hero3D.LEG_H
TORSO_Y = 0.225        # Hero3D.TORSO_Y
TORSO_TOP = 0.60       # Hero3D.TORSO_TOP
BODY_H = TORSO_TOP - TORSO_Y   # 0.375
HEAD_H = 0.45          # Hero3D.HEAD_H
HEAD_HALF_D = 0.225    # Hero3D.HEAD_HALF_D — глибина голови 2 × 0,225 (там сидять очі/окуляри)
HEAD_TOP = 0.98        # Hero3D.HEAD_TOP
TAIL_LEN = 0.35        # Hero3D.TAIL_LEN — довжина слота хвоста від шарніра назад
MAX_PART_M = 0.6       # tests/test_heroes_v15.gd: dims.x*size < 0.6 і dims.y*size < 0.6
MAX_W_M = 0.58         # ширина, до якої тиснемо самі: 2 см запасу до межі тесту
EAR_MAX_H = 0.22       # стеля висоти вуха
DEFAULT_PITCH = 0.04   # v2: голова ≈ 11 вокселів заввишки — деталі AI-моделі виживають
## Стеля для уступу «тут починається хвіст»: частка від найтовщого перерізу тулуба.
## Хвіст — тонкий відросток; звуження до 58 % (круп) хвостом не вважаємо.
TAIL_STEP_CEIL = 0.5

## Палітра-заготовка арт-біблії ч.2 (docs/refs/README.md §Персонажі). Hero3D підміняє ці ключі.
PAL_CREAM = "#F6E3C2"
PAL_DARK = "#4A2C2A"
PAL_PINK = "#F04F86"
PAL_FALLBACK_O = "#F08A3C"

## Мітки сегментації.
L_NONE, L_TORSO, L_HEAD, L_TAIL = 0, 1, 2, 3
L_FL, L_FR, L_BL, L_BR = 4, 5, 6, 7
L_EAR_L, L_EAR_R = 8, 9
LEG_LABELS = {"FL": L_FL, "FR": L_FR, "BL": L_BL, "BR": L_BR}
LABEL_CHAR = {
    L_NONE: " ", L_TORSO: "t", L_HEAD: "h", L_TAIL: "a",
    L_FL: "1", L_FR: "2", L_BL: "3", L_BR: "4", L_EAR_L: "e", L_EAR_R: "E",
}

## Контракт --fit (v2) — у МЕТРАХ, а не в кількості вокселів.
## Кількість вокселів вільна: скільки їх буде, вирішує --pitch. Тест звіряє габарит у метрах
## із допуском в один воксель, тож дрібніший --pitch = більше деталей і та сама геометрія.
##   exact_* — точний габарит (± один воксель), max_* — стеля.
## Осі: x — ширина, y — висота, z — глибина (перед -Z → зад +Z).
FIT_M = {
    "body": {"exact_y": BODY_H, "max_x": MAX_W_M, "max_z": 0.70},
    "head": {"exact_y": HEAD_H, "exact_z": HEAD_HALF_D * 2.0, "max_x": MAX_W_M},
    "leg": {"exact_y": LEG_H, "max_x": 0.20, "max_z": 0.20},
    "ear": {"max_y": EAR_MAX_H, "max_x": 0.30, "max_z": 0.30},
    # хвіст не розтягуємо: коротший добиваємо порожніми рядами ззаду, щоб довжина слота
    # завжди дорівнювала Hero3D.TAIL_LEN — тоді шарнір стоїть за константою, без читання габаритів
    "tail": {"exact_z": TAIL_LEN, "pad_z": True, "max_y": 0.40, "max_x": 0.40},
}


# ---------- дрібні утиліти ----------

def hex_to_rgb(s: str) -> tuple[int, int, int]:
    s = s.strip().lstrip("#")
    return int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16)


def rgb_to_hex(rgb) -> str:
    return "#%02X%02X%02X" % (int(rgb[0]), int(rgb[1]), int(rgb[2]))


def darken(hex_color: str, k: float) -> str:
    """Як Color.darkened(k) у Godot — множення каналів на (1 - k)."""
    r, g, b = hex_to_rgb(hex_color)
    return rgb_to_hex((round(r * (1.0 - k)), round(g * (1.0 - k)), round(b * (1.0 - k))))


def load_hero(hero_id: str) -> dict:
    path = ROOT / "data" / "heroes.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except OSError:
        print(f"[!] не читається {path} — беру кольори за замовчуванням")
        return {}
    d = data.get(hero_id)
    return d if isinstance(d, dict) else {}


# ---------- 1. меш ----------

def load_mesh(path: Path, height: float, front: str | None, verbose: bool = True,
              up: str = "auto"):
    """Завантажує glb/obj, ставить Y угору, центрує по x/z, база на y = 0, масштабує до height."""
    try:
        import trimesh
    except ImportError:  # pragma: no cover
        sys.exit("Потрібні залежності. Встанови їх:\n    pip3 install trimesh numpy")

    mesh = trimesh.load(str(path), force="mesh")
    if mesh is None or getattr(mesh, "faces", None) is None or len(mesh.faces) == 0:
        sys.exit(f"[!] не вдалось прочитати меш із {path}")
    mesh = mesh.copy()

    ext = mesh.extents
    # --up y|z вимикає евристику: у довгого звірятка (лисеня) глибина буває більша за зріст,
    # і автовизначення Z-up помилково клало б модель на бік
    zup = (ext[2] > ext[1] * 1.15) if up == "auto" else (up == "z")
    if zup:
        # Z-up (частий експорт) -> повертаємо в Y-up: (x, y, z) -> (x, z, -y)
        mesh.apply_transform(trimesh.transformations.rotation_matrix(-math.pi / 2.0, [1, 0, 0]))
        if verbose:
            print("[i] бачу Z-up — повернув модель у Y-up")

    _recenter(mesh)
    sign, axis = _detect_front(mesh) if front in (None, "auto") else _parse_front(front)
    angle = _front_angle(axis, sign)
    if angle != 0.0:
        mesh.apply_transform(trimesh.transformations.rotation_matrix(angle, [0, 1, 0]))
        _recenter(mesh)
    if verbose:
        src = "задано" if front not in (None, "auto") else "евристика"
        print(f"[i] перед моделі: {'+' if sign > 0 else '-'}{axis} ({src}) -> повернув у -Z")

    cur_h = float(mesh.extents[1])
    if cur_h <= 1e-9:
        sys.exit("[!] нульова висота меша")
    mesh.apply_scale(height / cur_h)
    _recenter(mesh)
    if verbose:
        e = mesh.extents
        print(f"[i] габарит після нормалізації: {e[0]:.3f} × {e[1]:.3f} × {e[2]:.3f} м")
    return mesh


def _recenter(mesh) -> None:
    lo, hi = mesh.bounds
    mesh.apply_translation([-(lo[0] + hi[0]) * 0.5, -lo[1], -(lo[2] + hi[2]) * 0.5])


def _parse_front(front: str) -> tuple[int, str]:
    f = front.lower().replace(" ", "")
    if f not in ("+z", "-z", "+x", "-x"):
        sys.exit("[!] --front очікує +z|-z|+x|-x")
    return (1 if f[0] == "+" else -1), f[1]


def _front_angle(axis: str, sign: int) -> float:
    """Кут повороту навколо Y, щоб заданий бік став -Z. Ry: x' = x·cos + z·sin, z' = -x·sin + z·cos."""
    if axis == "z":
        return math.pi if sign > 0 else 0.0
    return math.pi / 2.0 if sign > 0 else -math.pi / 2.0


def _detect_front(mesh) -> tuple[int, str]:
    """Евристика: голова стирчить уперед, тож маса верхніх 45 % висоти зсунута в бік морди.

    Рахуємо зсув окремо по x і по z (у частках габариту) і беремо вісь із більшим зсувом.
    """
    v = np.asarray(mesh.vertices, dtype=float)
    hi = v[:, 1].max()
    top = v[v[:, 1] >= hi * 0.55]
    if len(top) < 8:
        top = v
    ext = mesh.extents
    shift = {}
    for axis, col in (("x", 0), ("z", 2)):
        span = float(ext[col]) or 1.0
        shift[axis] = float(top[:, col].mean() - v[:, col].mean()) / span
    axis = "x" if abs(shift["x"]) > abs(shift["z"]) else "z"
    if abs(shift[axis]) < 0.02:
        print("[!] перед визначено ненадійно — глянь --dry-run, за потреби задай --front")
    return (1 if shift[axis] >= 0 else -1), axis


# ---------- 2. воксeлізація ----------

def voxelize(mesh, pitch: float, verbose: bool = True) -> np.ndarray:
    """-> булева сітка occ[x, y, z]; occ[:, 0, :] — нижній шар (база меша на y = 0)."""
    import trimesh  # локально: без нього сюди не дійдемо

    grid = trimesh.voxel.creation.voxelize(mesh, pitch)
    try:
        filled = grid.fill()
        if filled is not None:
            grid = filled
    except Exception as exc:  # pragma: no cover - деякі версії не вміють fill
        print(f"[!] заливка порожнин не вдалась ({exc}) — лишаю оболонку")

    pts = np.asarray(grid.points, dtype=float)
    if len(pts) == 0:
        sys.exit("[!] воксeлізація дала 0 вокселів — зменш --pitch")
    # центри вокселів лежать на ґратці з кроком pitch, тож (p - min) / pitch — цілі
    idx = np.rint((pts - pts.min(axis=0)) / pitch).astype(int)
    shape = tuple(idx.max(axis=0) + 1)
    occ = np.zeros(shape, dtype=bool)
    occ[idx[:, 0], idx[:, 1], idx[:, 2]] = True
    if verbose:
        print(f"[i] сітка {shape[0]}×{shape[1]}×{shape[2]}, вокселів: {int(occ.sum())}")
    return occ


# ---------- 3. сегментація ----------

def _components(mask: np.ndarray, offsets) -> list[np.ndarray]:
    """Зв'язні компоненти булевої маски (свій BFS — без scipy). -> список масок, більші спершу."""
    seen = np.zeros(mask.shape, dtype=bool)
    out = []
    for start in map(tuple, np.argwhere(mask)):
        if seen[start]:
            continue
        comp = np.zeros(mask.shape, dtype=bool)
        q = deque([start])
        seen[start] = True
        comp[start] = True
        while q:
            cur = q.popleft()
            for off in offsets:
                nxt = tuple(c + o for c, o in zip(cur, off))
                if any(n < 0 or n >= s for n, s in zip(nxt, mask.shape)):
                    continue
                if mask[nxt] and not seen[nxt]:
                    seen[nxt] = True
                    comp[nxt] = True
                    q.append(nxt)
        out.append(comp)
    out.sort(key=lambda m: int(m.sum()), reverse=True)
    return out


OFF2 = [(1, 0), (-1, 0), (0, 1), (0, -1)]
OFF3 = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]


def segment(occ: np.ndarray, pitch: float, opts) -> tuple[np.ndarray, dict]:
    """-> (labels[x, y, z], info). Порядок: лапки -> голова (+вуха) -> хвіст -> тулуб."""
    nx, ny, nz = occ.shape
    labels = np.where(occ, L_TORSO, L_NONE).astype(np.int8)
    info: dict = {}

    # --- лапки: нижня смуга, 4 зв'язні колонки, підпис за квадрантом (перед = -Z, ліво = -X) ---
    leg_top = min(ny, max(1, int(round(LEG_H * 1.1 / pitch))))
    seed_top = min(leg_top, max(1, int(round(LEG_H * 0.6 / pitch))))
    foot = occ[:, :seed_top, :].any(axis=1)
    comps = [c for c in _components(foot, OFF2) if int(c.sum()) >= max(1, opts.min_leg)]
    info["leg_components"] = len(comps)
    if len(comps) < 4:
        print(f"[!] знайшов {len(comps)} опор замість 4 — ділю нижню смугу на квадранти "
              f"(підправ --pitch або відредагуй .vox вручну)")
        comps = _quadrant_footprint(foot)
    comps = comps[:4]
    centroids = []
    for c in comps:
        pts = np.argwhere(c)
        centroids.append((pts[:, 0].mean(), pts[:, 1].mean()))
    cx = float(np.mean([p[0] for p in centroids])) if centroids else nx / 2.0
    cz = float(np.mean([p[1] for p in centroids])) if centroids else nz / 2.0
    used = set()
    for comp, (mx, mz) in zip(comps, centroids):
        name = ("F" if mz < cz else "B") + ("L" if mx < cx else "R")
        while name in used:                      # два центри в одному квадранті — беремо вільний
            name = next(n for n in ("FL", "FR", "BL", "BR") if n not in used)
        used.add(name)
        col = np.zeros(occ.shape, dtype=bool)
        col[:, :leg_top, :] = occ[:, :leg_top, :] & comp[:, None, :]
        labels[col] = LEG_LABELS[name]
    info["legs"] = sorted(used)

    # --- голова: над «шиєю» (мінімум площі перерізу між 45 % і 75 % висоти) ---
    neck = opts.neck if opts.neck is not None else _neck_y(occ)
    neck = int(min(max(neck, 1), ny - 2))
    info["neck_y"] = neck
    above = occ.copy()
    above[:, :neck, :] = False
    head = np.zeros(occ.shape, dtype=bool)
    if above.any():
        comps3 = _components(above, OFF3)
        front_z = min(int(np.argwhere(c)[:, 2].min()) for c in comps3)
        head = next(c for c in comps3 if int(np.argwhere(c)[:, 2].min()) == front_z)
        # обрізаємо задній «хребет», якщо компонента злилась зі спиною
        depth = opts.head_depth if opts.head_depth else int(round(HEAD_H / pitch))
        zs = np.argwhere(head)[:, 2]
        if int(zs.max() - zs.min() + 1) > depth:
            cut = int(zs.min()) + depth
            head[:, :, cut:] = False
            print(f"[i] голова була глибша за {depth} вокселів — обрізав до z < {cut}")
    labels[head] = L_HEAD
    info["head_voxels"] = int(head.sum())

    # --- вуха: колонки голови, чия маківка вища за медіану + lift ---
    # поріг вуха задаємо в метрах (0,10 м над маківкою), інакше дрібніший --pitch ловив би шум
    lift = int(opts.ear_lift) if opts.ear_lift else max(1, int(round(0.10 / pitch)))
    info["ear_lift"] = lift
    ear_l, ear_r = _split_ears(head, lift)
    labels[ear_l] = L_EAR_L
    labels[ear_r] = L_EAR_R

    # --- хвіст: позаду задньої площини тулуба АБО піднятий над крупом ---
    rest = (labels == L_TORSO)
    tail = np.zeros(occ.shape, dtype=bool)
    per_z = None
    if rest.any():
        per_z = rest.sum(axis=(0, 1))
        peak = int(np.argmax(per_z))
        thr = max(1.0, per_z.max() * opts.tail_frac)
        # Тулуб — суцільна смуга від піку назад. Обриваємо її там, де переріз або падає під
        # поріг, або РІЗКО звужується: хвіст завжди тонший за тулуб, і саме цей уступ надійніший
        # за абсолютний поріг. Пухнастий хвіст (лисеня) буває товщий за tail_frac від піку —
        # на порозі його не спіймати, на уступі видно одразу.
        # Сам по собі уступ ще не хвіст: тулуб теж звужується за крупом (у лисеняти 140 -> 81).
        # Хвіст — ТОНКИЙ відросток, тож після уступу має лишитись менш ніж пів піку; інакше
        # це просто талія, і задня площина з'їхала б уперед, забравши в хвіст третину тулуба.
        thin = per_z.max() * TAIL_STEP_CEIL
        back = peak
        for z in range(peak, nz - 1):
            nxt = per_z[z + 1]
            if nxt < thr or (nxt <= per_z[z] * opts.tail_step and nxt < thin):
                break
            back = z + 1
        if opts.tail_z is not None:
            back = int(opts.tail_z) - 1
        info["torso_back_z"] = back
        info["per_z"] = per_z.tolist()
        tail = _tail_mask(rest, back)
    labels[tail] = L_TAIL
    if not tail.any():
        print("[!] хвоста не видно — задай --tail-z <індекс z>, послаб --tail-step / --tail-frac"
              " або лиши дефолтний хвіст у heroes.json")
        if per_z is not None:
            print("    переріз тулуба по z (перед→зад):", " ".join(str(int(v)) for v in per_z))
            print(f"    задня площина тулуба зараз на z = {info.get('torso_back_z')}")

    info["counts"] = {LABEL_CHAR[k]: int((labels == k).sum()) for k in LABEL_CHAR if k != L_NONE}
    return labels, info


def _quadrant_footprint(foot: np.ndarray) -> list[np.ndarray]:
    """Запасний план: ділимо слід на 4 квадранти від центроїда."""
    pts = np.argwhere(foot)
    if len(pts) == 0:
        return []
    cx, cz = pts[:, 0].mean(), pts[:, 1].mean()
    out = []
    for sx in (-1, 1):
        for sz in (-1, 1):
            m = np.zeros(foot.shape, dtype=bool)
            sel = pts[((pts[:, 0] < cx) == (sx < 0)) & ((pts[:, 1] < cz) == (sz < 0))]
            if len(sel) == 0:
                continue
            m[sel[:, 0], sel[:, 1]] = True
            out.append(m)
    return out


def _neck_y(occ: np.ndarray) -> int:
    ny = occ.shape[1]
    lo, hi = int(ny * 0.45), max(int(ny * 0.75), int(ny * 0.45) + 1)
    area = occ.sum(axis=(0, 2))
    band = area[lo:hi]
    if len(band) == 0 or band.max() == 0:
        return int(ny * 0.55)
    return lo + int(np.argmin(band))


def _tail_mask(rest: np.ndarray, back: int) -> np.ndarray:
    """Хвіст: усе позаду задньої площини тулуба ПЛЮС піднятий хвіст над крупом.

    Лисеня з Meshy тримає хвіст угору-назад, тож за спину він майже не виступає — самої
    площини мало (перший запуск дав порожньо). Тому беремо кандидатів «позаду площини
    АБО вище за медіанну лінію спини в задніх 25 % тулуба», ділимо на зв'язні компоненти
    й лишаємо ті, чий центроїд за площиною (z > back − 1) і які торкаються тих задніх 25 %.
    Компоненту, більшу за половину решти вокселів, відкидаємо — це сам тулуб.
    """
    empty = np.zeros(rest.shape, dtype=bool)
    pts = np.argwhere(rest)
    if len(pts) == 0:
        return empty
    ny, nz = int(rest.shape[1]), int(rest.shape[2])
    z0 = int(pts[:, 2].min())
    span = max(1, back - z0 + 1)
    z_back = max(z0, back - max(1, int(round(span * 0.25))) + 1)   # початок задніх 25 % тулуба
    zz = np.arange(nz)[None, None, :]
    yy = np.arange(ny)[None, :, None]
    behind = rest & (zz > back)
    core = np.argwhere(rest & (zz <= back))
    tops: dict = {}
    for x, y, z in core:
        tops[(int(x), int(z))] = max(tops.get((int(x), int(z)), -1), int(y))
    back_top = int(np.median(list(tops.values()))) if tops else ny
    raised = rest & (zz >= z_back) & (yy > back_top)
    cand = behind | raised
    if not cand.any():
        return empty
    out = empty.copy()
    limit = int(rest.sum()) * 0.5
    for comp in _components(cand, OFF3):
        p = np.argwhere(comp)
        if int(comp.sum()) > limit:
            continue
        if float(p[:, 2].mean()) <= back - 1:
            continue
        if not (p[:, 2] >= z_back).any():
            continue
        out |= comp
    return out


def _split_ears(head: np.ndarray, lift: int) -> tuple[np.ndarray, np.ndarray]:
    """Вуха — колонки голови, верх яких вищий за медіанну маківку на lift вокселів."""
    empty = np.zeros(head.shape, dtype=bool)
    if not head.any():
        return empty, empty.copy()
    tops = {}
    for x, y, z in np.argwhere(head):
        tops[(x, z)] = max(tops.get((x, z), -1), int(y))
    med = int(np.median(list(tops.values())))
    cols = [c for c, t in tops.items() if t > med + lift]
    if not cols:
        return empty, empty.copy()
    mask = np.zeros(head.shape, dtype=bool)
    for x, z in cols:
        mask[x, med + 1:, z] = head[x, med + 1:, z]
    if not mask.any():
        return empty, empty.copy()
    cx = float(np.argwhere(mask)[:, 0].mean())
    left, right = mask.copy(), mask.copy()
    xs = np.arange(head.shape[0])[:, None, None]
    left[np.broadcast_to(xs >= cx, head.shape)] = False
    right[np.broadcast_to(xs < cx, head.shape)] = False
    # Чубчик між вухами теж вищий за медіанну маківку, тож лишається в цих мітках навмисно:
    # так він не роздуває бокс голови (інакше голова = 5 шарів мозку + 6 шарів шпиля).
    # Вирізати з мітки будемо лише найбільший зв'язний виступ — див. main().
    return left, right


def _largest_blob(mask: np.ndarray) -> np.ndarray:
    """Найбільша зв'язна компонента маски (решту відкидаємо)."""
    if not mask.any():
        return mask
    comps = list(_components(mask, OFF3))
    if len(comps) <= 1:
        return mask
    return max(comps, key=lambda c: int(c.sum()))


# ---------- 4. кольори-символи ----------

def colorize(labels: np.ndarray, pitch: float, opts) -> np.ndarray:
    """-> сітка символів палітри ('.' — порожньо). Символи, а не hex: Hero3D підміняє їх на колір героя."""
    sym = np.full(labels.shape, EMPTY, dtype="<U1")
    sym[labels != L_NONE] = "o"

    torso = labels == L_TORSO
    if torso.any():
        ys = np.argwhere(torso)[:, 1]
        lo, hi = int(ys.min()), int(ys.max())
        span = max(1, hi - lo + 1)
        if opts.dark_top:
            band = (np.arange(labels.shape[1]) >= hi - max(0, int(span * 0.3) - 1))
        else:
            band = (np.arange(labels.shape[1]) <= lo + max(0, int(span * 0.3) - 1))
        sym[torso & band[None, :, None]] = "d"

    head = labels == L_HEAD
    if head.any():
        # Зони в ЧАСТКАХ голови, а не в вокселях: на дрібній сітці (--pitch 0.04) морда
        # й очі мають лишатись такими самими за пропорцією, а не займати пів голови.
        pts = np.argwhere(head)
        x0, x1 = int(pts[:, 0].min()), int(pts[:, 0].max())
        y0, y1 = int(pts[:, 1].min()), int(pts[:, 1].max())
        z0, z1 = int(pts[:, 2].min()), int(pts[:, 2].max())
        w_h, h_h, d_h = x1 - x0 + 1, y1 - y0 + 1, z1 - z0 + 1
        zz = np.arange(labels.shape[2])[None, None, :]
        yy = np.arange(labels.shape[1])[None, :, None]
        # морда: передні 40 % глибини й нижні 55 % висоти
        z_cut = z0 + max(0, int(math.ceil(d_h * 0.40)) - 1)
        y_cut = y0 + max(0, int(math.ceil(h_h * 0.55)) - 1)
        muzzle = head & (zz <= z_cut) & (yy <= y_cut)
        sym[muzzle] = "c"
        # носик 2×1×1 по центру передньої грані у верхньому ряду морди
        mp = np.argwhere(muzzle)
        if len(mp):
            top_y = int(mp[:, 1].max())
            row = mp[mp[:, 1] == top_y]
            row = row[row[:, 2] == int(row[:, 2].min())]
            cx = (x0 + x1) * 0.5
            for x, y, z in row[np.argsort(np.abs(row[:, 0] - cx))][:2]:
                sym[x, y, z] = "k"
        # темні очні западини 2×2 на передній грані: 60–75 % висоти голови, ±25 % по x.
        # Hero3D кладе поверх власні очі-зіниці з бліком на FACE_Z, тож западина лише «садить» їх.
        if opts.eyes:
            ey0 = y0 + int(round(h_h * 0.60))
            ey1 = min(y1, max(ey0 + 1, y0 + int(round(h_h * 0.75)) - 1))
            off = max(1, int(round(w_h * 0.25)))
            cxi = (x0 + x1) // 2
            for side in (-1, 1):
                for step in (0, 1):
                    x = cxi + side * (off + step)
                    if x < x0 or x > x1:
                        continue
                    for y in range(ey0, ey1 + 1):
                        col = np.argwhere(head[x, y, :])
                        if len(col):
                            sym[x, y, int(col.min())] = "d"

    # копитце — нижні ~6 см лапки (у вокселях залежить від --pitch, у метрах — ні)
    hoof = max(1, int(round(0.06 / pitch)))
    for lbl in (L_FL, L_FR, L_BL, L_BR):
        leg = labels == lbl
        if leg.any():
            y0 = int(np.argwhere(leg)[:, 1].min())
            band = np.arange(labels.shape[1]) < y0 + hoof
            sym[leg & band[None, :, None]] = "k"

    for lbl in (L_EAR_L, L_EAR_R):
        ear = labels == lbl
        if not ear.any():
            continue
        # Рожева СЕРЕДИНКА, а не вся передня грань: інакше вухо читається суцільною
        # рожевою пластиною (пор. hero_ear_fox.json — там "io", тобто облямівка лишається
        # кольору героя). Знімаємо крайні колонки по x і верхній ряд — кінчик теж лишається o.
        pts = np.argwhere(ear)
        z0 = int(pts[:, 2].min())
        x0, x1 = int(pts[:, 0].min()), int(pts[:, 0].max())
        y1 = int(pts[:, 1].max())
        xx = np.arange(labels.shape[0])[:, None, None]
        yy = np.arange(labels.shape[1])[None, :, None]
        zz = np.arange(labels.shape[2])[None, None, :]
        front = ear & (zz == z0)
        inner = front & (xx > x0) & (xx < x1) & (yy < y1)
        if not inner.any():
            inner = front & (yy < y1)          # вухо у 1–2 колонки: лишаємо хоч кінчик
        if not inner.any():
            inner = front
        sym[inner] = "i"

    tail = labels == L_TAIL
    if tail.any():
        zs = np.argwhere(tail)[:, 2]
        z0, z1 = int(zs.min()), int(zs.max())
        tip = z1 - max(0, int(math.ceil((z1 - z0 + 1) * 0.35)) - 1)
        sym[tail & (np.arange(labels.shape[2]) >= tip)[None, None, :]] = "t"     # кінчик

    if opts.marks and torso.any():
        pts = np.argwhere(torso)
        cx = float(pts[:, 0].mean())
        tops: dict = {}
        for x, y, z in pts:
            if abs(x - cx) <= 1.0:
                tops[(int(x), int(z))] = max(tops.get((int(x), int(z)), -1), int(y))
        for (x, z), y in tops.items():
            sym[x, y, z] = "m"                                                   # смужка на спині
    return sym


# ---------- 5. вирізання частин і запис JSON ----------

def _span(i: int, n_t: int, n_s: int) -> tuple[int, int]:
    a0 = i * n_s // n_t
    return a0, min(n_s, max(a0 + 1, (i + 1) * n_s // n_t))


def resample(sym: np.ndarray, target, thresh: float = 0.25) -> np.ndarray:
    """Пересемплювання найближчим сусідом (v2) із запобіжником проти дірок.

    Беремо символ із центра блока-джерела — так деталі AI-моделі не «замилюються» в
    найчастіший колір, а при збільшенні (--pitch дрібніший за ціль) це чистий nearest.
    Якщо центр порожній, але блок заповнений хоча б на thresh, ставимо найчастіший
    непорожній символ — інакше при зменшенні в частині з'являлись би дірки.
    """
    src = sym.shape
    target = tuple(int(max(1, t)) for t in target)
    if target == tuple(src):
        return sym
    out = np.full(target, EMPTY, dtype="<U1")
    for i in range(target[0]):
        a0, a1 = _span(i, target[0], src[0])
        for j in range(target[1]):
            b0, b1 = _span(j, target[1], src[1])
            for k in range(target[2]):
                c0, c1 = _span(k, target[2], src[2])
                mid = sym[(a0 + a1 - 1) // 2, (b0 + b1 - 1) // 2, (c0 + c1 - 1) // 2]
                if mid != EMPTY:
                    out[i, j, k] = mid
                    continue
                block = sym[a0:a1, b0:b1, c0:c1].ravel()
                full = [s for s in block if s != EMPTY]
                if not full or len(full) < thresh * block.size:
                    continue
                out[i, j, k] = Counter(full).most_common(1)[0][0]
    if not (out != EMPTY).any():                # усе стерли — краще лишити як було
        return sym
    return out


def cut_part(sym: np.ndarray, mask: np.ndarray) -> np.ndarray | None:
    """Вирізає частину й переносить у власні координати (min = 0 по кожній осі)."""
    if not mask.any():
        return None
    pts = np.argwhere(mask)
    lo = pts.min(axis=0)
    hi = pts.max(axis=0) + 1
    sub = np.full(tuple(hi - lo), EMPTY, dtype="<U1")
    sel = sym[lo[0]:hi[0], lo[1]:hi[1], lo[2]:hi[2]]
    msk = mask[lo[0]:hi[0], lo[1]:hi[1], lo[2]:hi[2]]
    sub[msk] = sel[msk]
    return sub


def _voxels(metres: float, size: float) -> int:
    """Скільки вокселів розміром size лягає в metres (мінімум один)."""
    return max(1, int(round(metres / size)))


def _voxels_max(metres: float, size: float) -> int:
    """Те саме, але для СТЕЛІ: скільки вокселів рівно вміщується, без округлення вгору.
    Стеля вуха 0,22 м при --pitch 0,04 — це 5,5 вокселя; round дав би 6 і габарит 0,24 м,
    тобто інструмент сам порушував би межу, про яку потім і попереджав.
    """
    return max(1, int(math.floor(metres / size + 1e-9)))


def fit_part(sub: np.ndarray, kind: str, size: float) -> np.ndarray:
    """Приводить частину до габаритів Hero3D **у метрах** (v2), а не до фіксованих вокселів.

    Точна вісь (exact_*) задає масштаб, вільні осі тягнуться за ним — пропорції не пливуть.
    Стелі (max_*) тиснуть уже після цього. Хвіст не розтягуємо: коротший добиваємо
    порожніми рядами ззаду, щоб довжина слота дорівнювала Hero3D.TAIL_LEN.
    """
    rule = FIT_M.get(kind, {})
    tgt = list(sub.shape)
    k = 1.0
    if "exact_y" in rule:
        tgt[1] = _voxels(rule["exact_y"], size)
        k = tgt[1] / float(sub.shape[1])
    elif "max_y" in rule:
        tgt[1] = min(sub.shape[1], _voxels_max(rule["max_y"], size))
        k = tgt[1] / float(sub.shape[1])
    for i, axis in ((0, "x"), (2, "z")):
        exact = rule.get("exact_" + axis)
        tgt[i] = _voxels(exact, size) if exact is not None else max(1, int(round(sub.shape[i] * k)))
        cap = rule.get("max_" + axis)
        if cap is not None:
            tgt[i] = min(tgt[i], _voxels_max(cap, size))
    pad_z = 0
    if rule.get("pad_z") and tgt[2] > sub.shape[2]:
        pad_z = tgt[2] - sub.shape[2]
        tgt[2] = sub.shape[2]
    out = resample(sub, tuple(tgt))
    if pad_z:
        tailpad = np.full((out.shape[0], out.shape[1], pad_z), EMPTY, dtype="<U1")
        out = np.concatenate([out, tailpad], axis=2)
    return out


def to_def(sub: np.ndarray, size: float, palette: dict, note: str) -> dict:
    """Символьна сітка -> JSON у форматі VoxelBuilder: layers[y][z] = рядок по x."""
    nx, ny, nz = sub.shape
    used = sorted({s for s in sub.ravel() if s != EMPTY})
    layers = []
    for y in range(ny):
        layers.append(["".join(sub[x, y, z] for x in range(nx)) for z in range(nz)])
    return {
        "_note": note,
        "size": round(float(size), 4),
        "palette": {k: palette[k] for k in used if k in palette},
        "layers": layers,
    }


def check_part(kind: str, sub: np.ndarray, size: float) -> None:
    """Попередження за контрактом tests/test_heroes_v15.gd — у метрах, допуск один воксель."""
    rule = FIT_M.get(kind, {})
    tol = size + 1e-6
    for i, axis, label in ((0, "x", "ширина"), (1, "y", "висота"), (2, "z", "глибина")):
        m = sub.shape[i] * size
        exact = rule.get("exact_" + axis)
        if exact is not None and abs(m - exact) > tol:
            print(f"[!] {kind}: {label} {m:.3f} м ≠ {exact:.3f} ± {size:.3f} м — тест впаде. "
                  f"Скористайся --fit")
        cap = rule.get("max_" + axis)
        if cap is not None and m > cap + 1e-6:
            print(f"[!] {kind}: {label} {m:.3f} м > стелі {cap:.3f} м. Скористайся --fit")
    if sub.shape[0] * size >= MAX_PART_M:
        print(f"[!] {kind}: ширина {sub.shape[0] * size:.3f} м ≥ {MAX_PART_M} м — тест впаде")
    if sub.shape[1] * size >= MAX_PART_M:
        print(f"[!] {kind}: висота {sub.shape[1] * size:.3f} м ≥ {MAX_PART_M} м — тест впаде")


# ---------- 6. MagicaVoxel .vox ----------

def _chunk(cid: bytes, content: bytes, children: bytes = b"") -> bytes:
    return cid + struct.pack("<ii", len(content), len(children)) + content + children


def write_vox(path: Path, sym: np.ndarray, palette: dict) -> None:
    """Мінімальний VOX 150: MAIN / SIZE / XYZI / RGBA. Осі: vox(x, y, z) = наші (x, z, y)."""
    nx, ny, nz = sym.shape
    if max(nx, ny, nz) > 255:
        print("[!] .vox не пишу: модель більша за 255 вокселів по осі")
        return
    used = sorted({s for s in sym.ravel() if s != EMPTY})
    index = {s: i + 1 for i, s in enumerate(used[:255])}
    voxels = bytearray()
    n = 0
    for x, y, z in np.argwhere(sym != EMPTY):
        s = sym[x, y, z]
        if s not in index:
            continue
        voxels += bytes((int(x), int(z), int(y), index[s]))
        n += 1
    rgba = bytearray(1024)
    for s, i in index.items():
        r, g, b = hex_to_rgb(palette.get(s, PAL_FALLBACK_O))
        rgba[(i - 1) * 4:(i - 1) * 4 + 4] = bytes((r, g, b, 255))
    body = (_chunk(b"SIZE", struct.pack("<iii", nx, nz, ny))
            + _chunk(b"XYZI", struct.pack("<i", n) + bytes(voxels))
            + _chunk(b"RGBA", bytes(rgba)))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"VOX " + struct.pack("<i", 150) + _chunk(b"MAIN", b"", body))
    print(f"[+] {path}  ({n} вокселів, {len(index)} кольорів)")


def read_vox(path: Path) -> tuple[np.ndarray, list]:
    """-> (сітка індексів кольору [x, y, z], палітра [(r, g, b), ...] за індексом 1..255)."""
    data = path.read_bytes()
    if data[:4] != b"VOX ":
        sys.exit(f"[!] {path} — не MagicaVoxel .vox")
    pos, size, xyzi, pal = 8, None, None, None
    while pos + 12 <= len(data):
        cid = data[pos:pos + 4]
        n_c, _n_k = struct.unpack("<ii", data[pos + 4:pos + 12])
        content = data[pos + 12:pos + 12 + n_c]
        pos += 12 + n_c                     # у children заходимо тим самим лінійним проходом
        if cid == b"SIZE" and size is None:
            size = struct.unpack("<iii", content[:12])
        elif cid == b"XYZI" and xyzi is None:
            xyzi = content
        elif cid == b"RGBA" and pal is None:
            pal = content
    if size is None or xyzi is None:
        sys.exit(f"[!] {path}: нема SIZE/XYZI")
    palette = [(0, 0, 0)] * 256
    if pal is not None:
        for i in range(255):
            r, g, b, _a = pal[i * 4:i * 4 + 4]
            palette[i + 1] = (r, g, b)
    else:
        print("[!] у файлі нема RGBA — кольори будуть сірі, задай --palette")
    count = struct.unpack("<i", xyzi[:4])[0]
    grid = np.zeros((size[0], size[2], size[1]), dtype=np.int16)   # наші (x, y, z)
    for i in range(count):
        vx, vy, vz, ci = xyzi[4 + i * 4:8 + i * 4]
        grid[vx, vz, vy] = ci
    return grid, palette


# ---------- 7. ASCII для --dry-run ----------

def ascii_slices(labels: np.ndarray) -> str:
    nx, ny, nz = labels.shape
    out = [f"сегментація {nx}×{ny}×{nz} (рядок = z, перед зверху; колонка = x)"]
    for y in range(ny - 1, -1, -1):
        out.append(f"--- y = {y} ---")
        for z in range(nz):
            out.append("  " + "".join(LABEL_CHAR[int(labels[x, y, z])] for x in range(nx)))
    out.append("  t тулуб · h голова · e/E вуха · a хвіст · 1 FL · 2 FR · 3 BL · 4 BR")
    return "\n".join(out)


# ---------- 8. --exact: модель УЖЕ воксельна ----------
#
# Зовнішній воксeлізатор (MagicaVoxel, Blender remesh, онлайн-сервіс) віддає .glb із кубиків
# на рівній сітці. Проганяти його через trimesh.voxelize зайве й шкідливо: сітка «попливе»,
# а кольори загубляться. Тому в --exact ми сітку ЗНАХОДИМО, а не будуємо.

EXACT_GREY = "#B0B0B0"
## Символи для справжніх кольорів моделі. o d c k i t m пропущені навмисно:
## саме їх Hero3D підміняє кольорами героя, і справжній колір моделі зник би.
EXACT_SYMBOLS = "abefghjlnpqrsuvwxyz0123456789"
EXACT_MAX_COLORS = 16
## Скільки рівнів на канал лишає квантування (32 рівні = крок 8 із 255).
EXACT_LEVELS = 32


def _edge_mode_size(mesh) -> tuple[float, float] | None:
    """Мода довжин ребер трикутників -> (розмір, частка ребер такої довжини).

    У сітці з кубиків більшість ребер — це рівно ребро кубика (діагоналі граней довші в √2).
    """
    v = np.asarray(mesh.vertices, dtype=float)
    f = np.asarray(mesh.faces)
    if len(f) == 0:
        return None
    e = np.concatenate([v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 1]], v[f[:, 0]] - v[f[:, 2]]])
    lens = np.linalg.norm(e, axis=1)
    lens = lens[lens > 1e-9]
    if len(lens) == 0:
        return None
    # Округлюємо відносно МЕДІАННОГО ребра (1e-4 від нього). Дрібніше не можна: у .glb вершини
    # лежать у float32, тож однакові ребра приходять із похибкою ~1e-7 і мода б розсипалась.
    step = max(float(np.median(lens)) * 1e-4, 1e-12)
    keys = np.rint(lens / step).astype(np.int64)
    key, n = Counter(keys.tolist()).most_common(1)[0]
    # довжину беремо середню по «кошику», а не округлену — так розмір кубика точний
    return float(lens[keys == key].mean()), n / float(len(lens))


def _bbox_step_size(mesh) -> float | None:
    """Найменший ненульовий крок між координатами вершин по осях габариту."""
    v = np.asarray(mesh.vertices, dtype=float)
    best = None
    for col in range(3):
        u = np.unique(np.round(v[:, col], 9))
        if len(u) < 2:
            continue
        d = np.diff(u)
        d = d[d > 1e-9]
        if len(d) == 0:
            continue
        cur = float(d.min())
        best = cur if best is None else min(best, cur)
    return best


def detect_cube_size(mesh, forced: float = 0.0, verbose: bool = True) -> float:
    """Розмір кубика сітки, у метрах (модель уже масштабована під --height)."""
    if forced > 0.0:
        if verbose:
            print(f"[i] розмір кубика задано вручну: {forced:.5f} м")
        return float(forced)
    mode = _edge_mode_size(mesh)
    step = _bbox_step_size(mesh)
    size = None
    if mode is not None and mode[0] > 1e-9 and mode[1] >= 0.10:
        size = mode[0]
        if verbose:
            print(f"[i] розмір кубика (мода довжин ребер): {size:.5f} м "
                  f"({mode[1] * 100:.0f} % ребер)")
    elif step is not None and step > 1e-9:
        size = step
        if verbose:
            print(f"[i] мода ребер ненадійна — беру найменший крок габариту: {size:.5f} м")
    if size is None or size <= 1e-9:
        sys.exit("[!] не бачу регулярної сітки — це не воксельна модель. "
                 "Прибери --exact або задай --cube-size")
    ext = mesh.extents
    if verbose:
        cells = tuple(int(round(float(e) / size)) for e in ext)
        print(f"[i] габарит у кубиках: {cells[0]}×{cells[1]}×{cells[2]}")
        if cells[1] < 4 or max(cells) > 512:
            print("[!] кількість кубиків підозріла — звір --cube-size вручну")
    return float(size)


def face_colors(mesh, verbose: bool = True) -> tuple[np.ndarray, str]:
    """-> ((F, 3) uint8 — колір кожного трикутника, звідки взяли)."""
    import trimesh

    n = len(mesh.faces)
    vis = getattr(mesh, "visual", None)
    kind = getattr(vis, "kind", None)
    grey = np.tile(np.array(hex_to_rgb(EXACT_GREY), dtype=np.uint8), (n, 1))

    if kind == "face":
        try:
            fc = np.asarray(vis.face_colors, dtype=np.int32)[:, :3]
            if len(fc) == n:
                return fc.astype(np.uint8), "face_colors"
        except Exception:
            pass
    if kind in ("vertex", "face"):
        try:
            vc = np.asarray(vis.vertex_colors, dtype=np.int32)[:, :3]
        except Exception:
            vc = None
        if vc is not None and len(vc) == len(mesh.vertices):
            tri = vc[np.asarray(mesh.faces)]              # (F, 3, 3)
            out = np.empty((n, 3), dtype=np.uint8)
            # більшість граней одноколірні — беремо їх пачкою, мода потрібна лише на межах
            same = (tri[:, 0] == tri[:, 1]).all(axis=1) & (tri[:, 1] == tri[:, 2]).all(axis=1)
            out[same] = tri[same, 0]
            for i in np.nonzero(~same)[0]:
                # мода трьох вершин: на межі двох кольорів грань дістає той, якого двоє
                out[i] = Counter(map(tuple, tri[i].tolist())).most_common(1)[0][0]
            return out, "vertex_colors"
    if kind == "texture":
        mat = getattr(vis, "material", None)
        img = getattr(mat, "image", None) or getattr(mat, "baseColorTexture", None)
        uv = getattr(vis, "uv", None)
        if img is not None and uv is not None:
            try:
                fuv = np.asarray(uv, dtype=float)[np.asarray(mesh.faces)].mean(axis=1)
                cols = np.asarray(trimesh.visual.color.uv_to_color(fuv, img), dtype=np.int32)
                if len(cols) == n:
                    return cols[:, :3].astype(np.uint8), "текстура (UV центроїда грані)"
            except Exception as exc:  # pragma: no cover
                print(f"[!] текстуру прочитати не вдалось ({exc})")
    mat = getattr(vis, "material", None)
    for attr in ("baseColorFactor", "main_color", "diffuse", "ambient"):
        val = getattr(mat, attr, None)
        if val is None:
            continue
        arr = np.asarray(val, dtype=float).ravel()
        if len(arr) < 3:
            continue
        rgb = arr[:3] * (255.0 if arr.max() <= 1.0 + 1e-9 else 1.0)
        return np.tile(np.clip(rgb, 0, 255).astype(np.uint8), (n, 1)), f"матеріал ({attr})"
    if verbose:
        print(f"[!] у моделі нема кольорів (visual.kind = {kind}) — беру сірий {EXACT_GREY}")
    return grey, "нема (сірий)"


def snap_faces(mesh, size: float) -> tuple[np.ndarray, np.ndarray]:
    """Індекси кубика для кожного трикутника + форма сітки.

    Центр кубика = центроїд грані мінус нормаль × size/2 (беремо бік ВСЕРЕДИНУ кубика).
    """
    lo = np.asarray(mesh.bounds[0], dtype=float)
    ext = np.asarray(mesh.extents, dtype=float)
    shape = np.maximum(np.rint(ext / size).astype(int), 1)
    tri = np.asarray(mesh.triangles, dtype=float)
    cent = tri.mean(axis=1)
    centres = cent - np.asarray(mesh.face_normals, dtype=float) * (size * 0.5)
    idx = np.rint((centres - lo - size * 0.5) / size).astype(int)
    idx = np.clip(idx, 0, shape - 1)
    return idx, shape


def voxelize_aligned(mesh, size: float, shape: np.ndarray) -> np.ndarray | None:
    """trimesh.voxelize з тим самим кроком і початком у bbox_min + size/2 -> occ[x, y, z]."""
    import trimesh

    try:
        grid = trimesh.voxel.creation.voxelize(mesh, pitch=size)
        pts = np.asarray(grid.points, dtype=float)
    except Exception as exc:  # pragma: no cover - деякі версії падають на дірявих мешах
        print(f"[!] trimesh.voxelize не спрацював ({exc})")
        return None
    if len(pts) == 0:
        return None
    lo = np.asarray(mesh.bounds[0], dtype=float)
    idx = np.clip(np.rint((pts - lo - size * 0.5) / size).astype(int), 0, shape - 1)
    occ = np.zeros(tuple(shape), dtype=bool)
    occ[idx[:, 0], idx[:, 1], idx[:, 2]] = True
    return occ


def exact_grid(mesh, size: float, fcol: np.ndarray, source: str = "auto",
               verbose: bool = True) -> tuple[np.ndarray, dict]:
    """-> (occ[x, y, z], {(x, y, z): (r, g, b)}). Порівнює снап граней і trimesh.voxelize."""
    idx, shape = snap_faces(mesh, size)
    occ_snap = np.zeros(tuple(shape), dtype=bool)
    occ_snap[idx[:, 0], idx[:, 1], idx[:, 2]] = True
    buckets: dict = {}
    for (x, y, z), rgb in zip(map(tuple, idx), map(tuple, fcol.tolist())):
        buckets.setdefault((int(x), int(y), int(z)), Counter())[rgb] += 1
    colors = {k: c.most_common(1)[0][0] for k, c in buckets.items()}

    n_snap = int(occ_snap.sum())
    occ_tri = voxelize_aligned(mesh, size, shape) if source != "faces" else None
    n_tri = int(occ_tri.sum()) if occ_tri is not None else 0
    if verbose:
        print(f"[i] вокселів: снап граней {n_snap}, trimesh.voxelize {n_tri or '—'} "
              f"(сітка {shape[0]}×{shape[1]}×{shape[2]})")

    occ = occ_snap
    used = "снап граней"
    # Снап граней точніший (він читає саме кубики моделі), тож перемикаємось на trimesh
    # лише коли снап явно розсипався: порожньо або менш ніж пів того, що бачить trimesh.
    if source == "trimesh" and occ_tri is not None:
        occ, used = occ_tri, "trimesh.voxelize (задано --grid trimesh)"
    elif source == "auto" and occ_tri is not None and (n_snap == 0 or n_snap < 0.5 * n_tri):
        occ, used = occ_tri, "trimesh.voxelize (снап граней виглядає дірявим)"
    if not occ.any():
        sys.exit("[!] сітка порожня — перевір --cube-size")
    if verbose:
        print(f"[i] беру: {used}")
    if occ is not occ_snap:
        # кубикам, яких не бачив снап, даємо найчастіший колір моделі
        fallback = Counter(colors.values()).most_common(1)[0][0] if colors else hex_to_rgb(EXACT_GREY)
        for p in map(tuple, np.argwhere(occ)):
            colors.setdefault(p, fallback)
    for p in list(colors):
        if not occ[p]:
            del colors[p]
    return occ, colors


def quantize_colors(colors: dict, max_colors: int = EXACT_MAX_COLORS,
                    verbose: bool = True) -> dict:
    """Округляє канали до EXACT_LEVELS рівнів, лишає топ-N за частотою, решту — до найближчого."""
    step = 256 // EXACT_LEVELS

    def bucket(rgb):
        return tuple(min(EXACT_LEVELS - 1, int(c) // step) for c in rgb)

    def to_rgb(b):
        return tuple(min(255, v * step + step // 2) for v in b)

    freq = Counter(bucket(c) for c in colors.values())
    keep = [b for b, _ in freq.most_common(max(1, max_colors))]
    remap: dict = {}
    for b in freq:
        if b in keep:
            remap[b] = b
            continue
        remap[b] = min(keep, key=lambda k: sum((a - c) ** 2 for a, c in zip(k, b)))
    if verbose:
        print(f"[i] кольорів: {len(freq)} після округлення -> {len(keep)} у палітрі")
    return {p: to_rgb(remap[bucket(c)]) for p, c in colors.items()}


def symbolize(occ: np.ndarray, colors: dict) -> tuple[np.ndarray, dict]:
    """-> (сітка символів [x, y, z], палітра {символ: #RRGGBB}). Символи за частотою кольору."""
    sym = np.full(occ.shape, EMPTY, dtype="<U1")
    freq = Counter(colors.values())
    palette: dict = {}
    mapping: dict = {}
    for i, (rgb, _n) in enumerate(freq.most_common()):
        if i >= len(EXACT_SYMBOLS):
            print(f"[!] кольорів більше за {len(EXACT_SYMBOLS)} — зайві зіллються з останнім")
            mapping[rgb] = EXACT_SYMBOLS[-1]
            continue
        s = EXACT_SYMBOLS[i]
        mapping[rgb] = s
        palette[s] = rgb_to_hex(rgb)
    for p, rgb in colors.items():
        sym[p] = mapping[rgb]
    return sym, palette


def ascii_color_slices(sym: np.ndarray, palette: dict) -> str:
    """Зрізи з символами кольорів (--dry-run у режимі --exact)."""
    nx, ny, nz = sym.shape
    out = [f"сітка {nx}×{ny}×{nz} (рядок = z, перед зверху; колонка = x)"]
    for y in range(ny - 1, -1, -1):
        out.append(f"--- y = {y} ---")
        for z in range(nz):
            out.append("  " + "".join(sym[x, y, z] for x in range(nx)))
    out.append("  палітра: " + ", ".join(f"{k} = {v}" for k, v in sorted(palette.items())))
    return "\n".join(out)


def report_exact_part(kind: str, sub: np.ndarray, size: float) -> None:
    """У --exact частини НЕ пересемплюються — лише звіряємо їх із константами Hero3D."""
    rule = FIT_M.get(kind, {})
    tol = size + 1e-6
    dims = {"x": sub.shape[0] * size, "y": sub.shape[1] * size, "z": sub.shape[2] * size}
    print(f"[i] {kind}: {sub.shape[0]}×{sub.shape[1]}×{sub.shape[2]} × {size:.4f} м = "
          f"{dims['x']:.3f} × {dims['y']:.3f} × {dims['z']:.3f} м")
    for axis, label in (("x", "ширина"), ("y", "висота"), ("z", "глибина")):
        exact = rule.get("exact_" + axis)
        if exact is not None:
            ok = abs(dims[axis] - exact) <= tol
            print(f"    {label}: {dims[axis]:.3f} м проти Hero3D {exact:.3f} ± {size:.3f} — "
                  f"{'збігається' if ok else 'НЕ збігається (tests/test_heroes_v15.gd впаде)'}")
        cap = rule.get("max_" + axis)
        if cap is not None and dims[axis] > cap + 1e-6:
            print(f"    [!] {label} {dims[axis]:.3f} м > стелі Hero3D {cap:.3f} м")
    if max(dims["x"], dims["y"]) >= MAX_PART_M:
        print(f"    [!] габарит ≥ {MAX_PART_M} м — tests/test_heroes_v15.gd впаде")


def main_exact(opts, model: Path) -> int:
    """--exact: готова воксельна модель -> наш JSON (+ .vox) без пересемплювання."""
    mesh = load_mesh(model, opts.height, opts.front, up=opts.up)
    size = detect_cube_size(mesh, opts.cube_size)
    fcol, src = face_colors(mesh)
    print(f"[i] джерело кольорів: {src}")
    occ, raw = exact_grid(mesh, size, fcol, opts.grid)
    colors = quantize_colors(raw, opts.max_colors)
    sym, palette = symbolize(occ, colors)
    name = opts.name or model.stem

    if opts.parts == "none":
        if opts.dry_run:
            print(ascii_color_slices(sym, palette))
            return 0
        _emit(opts, {"whole": sym}, palette, {"whole": size},
              {"whole": f"Ціла воксельна модель. VoxelBuilder.instance(\"{name}\")."},
              sym, name_of=lambda _k: name, vox_name=name)
        print(f"\nПодивитись у грі:\n  VOXEL={name} godot res://src/debug/voxel_preview.tscn")
        return 0

    labels, info = segment(occ, size, opts)
    print("[i] вокселів на частину:", ", ".join(f"{k}={v}" for k, v in info["counts"].items() if v))
    print(f"[i] шия на y = {info['neck_y']}, лапки: {', '.join(info['legs']) or '—'}, "
          f"задня площина тулуба z = {info.get('torso_back_z')}")
    if opts.dry_run:
        print(ascii_slices(labels))
        print(ascii_color_slices(sym, palette))
        return 0

    part_sym, part_pal = sym, palette
    if opts.zones:
        # --zones: справжні кольори замінюємо зонами o/d/c/k/i/t, які Hero3D підмінює
        part_sym = colorize(labels, size, opts)
        part_pal = build_palette(load_hero(opts.hero))
        print("[i] --zones: у JSON частин ідуть символи o d c k i t (кольори героя), "
              "справжні кольори лишились у .vox")
    masks = {
        "body": labels == L_TORSO,
        "head": labels == L_HEAD,
        "leg": labels == L_FL,
        "tail": labels == L_TAIL,
        "ear": _largest_blob(labels == L_EAR_R),
    }
    if not masks["ear"].any():
        masks["ear"] = _largest_blob(labels == L_EAR_L)
    notes = {
        "body": "Тулуб. Ряди — від грудей (-Z) до хвоста (+Z).",
        "head": "Голова. Ряди — від морди (-Z) до потилиці (+Z).",
        "leg": "Лапка (передня ліва як шаблон для всіх чотирьох).",
        "ear": "Вухо; друге Hero3D дзеркалить (scale.x = -1).",
        "tail": "Хвіст: ряд 0 — передня грань біля шарніра, росте назад (+Z).",
    }
    subs, sizes = {}, {}
    for kind, mask in masks.items():
        sub = cut_part(part_sym, mask)
        if sub is None:
            print(f"[!] частина '{kind}' порожня — у heroes.json лиши стару назву для неї")
            continue
        report_exact_part(kind, sub, size)     # без --fit: справжня кількість вокселів
        subs[kind] = sub
        sizes[kind] = size
    _emit(opts, subs, part_pal, sizes, notes, sym,
          name_of=lambda k: f"hero_{k}_{name}", vox_palette=palette, vox_name=name)
    return 0


# ---------- 9. CLI ----------

def build_palette(hero: dict) -> dict:
    base = str(hero.get("color") or PAL_FALLBACK_O)
    return {
        "o": base.upper(),
        "d": darken(base, 0.22),
        "c": PAL_CREAM,
        "k": PAL_DARK,
        "i": PAL_PINK,
        "t": str(hero.get("accent") or PAL_CREAM).upper(),
        "m": str(hero.get("mark") or darken(base, 0.30)).upper(),
    }


def make_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Meshy .glb/.obj -> воксельні частини героя")
    p.add_argument("model", help="шлях до .glb / .obj")
    p.add_argument("--hero", default="lys", help="id героя з data/heroes.json (кольори)")
    p.add_argument("--height", type=float, default=HEAD_TOP, help="зріст у метрах (типово 0.98)")
    p.add_argument("--pitch", type=float, default=DEFAULT_PITCH,
                   help="розмір вокселя, м (типово 0.04 — голова ≈ 11 шарів); "
                        "--fit тримає габарити частин у метрах, тож дрібніший pitch = більше деталей")
    p.add_argument("--out", default="data/voxels", help="куди класти JSON частин")
    p.add_argument("--vox", default="", help="куди класти .vox цілої моделі")
    p.add_argument("--parts", choices=["hero", "none"], default=None,
                   help="hero — 5 частин; none — одна ціла модель (типово hero, а з --exact — none)")
    p.add_argument("--front", default="auto", help="+z|-z|+x|-x — де перед у вихідній моделі")
    p.add_argument("--up", choices=["auto", "y", "z"], default="auto",
                   help="куди дивиться «вгору» у вихідній моделі (auto — за габаритом)")
    # --- --exact: модель уже воксельна ---
    p.add_argument("--exact", action="store_true",
                   help="модель УЖЕ з кубиків на рівній сітці: знайти крок сітки й справжні "
                        "кольори, нічого не пересемплювати")
    p.add_argument("--name", default="", help="ім'я вокселя для --exact (типово — ім'я файлу)")
    p.add_argument("--cube-size", type=float, default=0.0,
                   help="розмір кубика в метрах вручну (0 — визначити з геометрії)")
    p.add_argument("--grid", choices=["auto", "faces", "trimesh"], default="auto",
                   help="звідки брати зайнятість у --exact: снап граней, trimesh.voxelize або авто")
    p.add_argument("--max-colors", type=int, default=EXACT_MAX_COLORS,
                   help=f"скільки кольорів лишати після квантування (типово {EXACT_MAX_COLORS})")
    p.add_argument("--zones", action="store_true",
                   help="--exact --parts hero: замінити справжні кольори на зони o/d/c/k/i/t, "
                        "які Hero3D підмінює кольорами героя")
    p.add_argument("--fit", dest="fit", action="store_true", default=True,
                   help="підганяти частини під габарити Hero3D У МЕТРАХ (типово увімкнено)")
    p.add_argument("--no-fit", dest="fit", action="store_false", help="лишити як є (тести можуть впасти)")
    p.add_argument("--marks", action="store_true", help="дозволити символ m (смужка на спині)")
    p.add_argument("--dark-top", action="store_true", help="d на спині, а не на животі (як hero_body.json)")
    p.add_argument("--eyes", dest="eyes", action="store_true", default=True, help="темні очні западини")
    p.add_argument("--no-eyes", dest="eyes", action="store_false")
    p.add_argument("--neck", type=int, default=None, help="індекс y шиї вручну")
    p.add_argument("--head-depth", type=int, default=0, help="глибина голови у вокселях")
    p.add_argument("--tail-z", type=int, default=None,
                   help="індекс z, з якого починається хвіст (беруть зі зрізів --dry-run, "
                        "коли автопошук хвоста промахнувся)")
    p.add_argument("--tail-frac", type=float, default=0.30, help="поріг задньої площини тулуба")
    p.add_argument("--tail-step", type=float, default=0.60,
                   help="наскільки різко переріз має звузитись, щоб це вважалось початком хвоста (0.6 = на 40%%)")
    p.add_argument("--ear-lift", type=int, default=0,
                   help="на скільки вокселів вухо вище за маківку (0 — авто, 0,10 м)")
    p.add_argument("--min-leg", type=int, default=1, help="мінімум клітинок сліду для лапки")
    p.add_argument("--ear-size", type=float, default=0.0, help="розмір вокселя вуха (типово --pitch)")
    p.add_argument("--tail-size", type=float, default=0.0, help="розмір вокселя хвоста (типово --pitch)")
    p.add_argument("--suffix", default="_ai", help="суфікс імен файлів")
    p.add_argument("--dry-run", action="store_true", help="лише показати сегментацію, нічого не писати")
    return p


def main(argv=None) -> int:
    opts = make_parser().parse_args(argv)
    model = Path(opts.model)
    if not model.exists():
        model = ROOT / opts.model
    if not model.exists():
        sys.exit(f"[!] нема файлу {opts.model}")
    # у --exact ціла модель типово одним файлом, у звичайному режимі — п'ять частин героя
    if opts.parts is None:
        opts.parts = "none" if opts.exact else "hero"
    if opts.exact:
        return main_exact(opts, model)
    if opts.zones:
        print("[!] --zones працює лише з --exact — ігнорую")

    hero = load_hero(opts.hero)
    palette = build_palette(hero)
    mesh = load_mesh(model, opts.height, opts.front, up=opts.up)
    occ = voxelize(mesh, opts.pitch)

    if opts.parts == "none":
        sym = np.full(occ.shape, EMPTY, dtype="<U1")
        sym[occ] = "o"
        _emit(opts, {opts.hero: sym}, palette, {opts.hero: opts.pitch}, {opts.hero: ""}, sym)
        return 0

    labels, info = segment(occ, opts.pitch, opts)
    print("[i] вокселів на частину:", ", ".join(f"{k}={v}" for k, v in info["counts"].items() if v))
    print(f"[i] шия на y = {info['neck_y']}, лапки: {', '.join(info['legs']) or '—'}, "
          f"поріг вуха {info.get('ear_lift')}, задня площина тулуба z = {info.get('torso_back_z')}")
    if opts.dry_run:
        print(ascii_slices(labels))
        return 0

    sym = colorize(labels, opts.pitch, opts)
    # v2: розмір вокселя в JSON = --pitch. Контракт із Hero3D тепер у метрах, тож дрібніша
    # сітка не ламає габарити — вона просто дає більше вокселів на ту саму висоту.
    part_size = opts.pitch
    ear_size = opts.ear_size or part_size          # вуха й хвіст — тієї ж крупності, що тулуб
    tail_size = opts.tail_size or part_size
    # ліве вухо Hero3D дзеркалить (scale.x = -1), тож віддаємо вухо з боку +X — його він ставить як є
    masks = {
        "body": labels == L_TORSO,
        "head": (labels == L_HEAD),
        "leg": labels == L_FL,
        "tail": labels == L_TAIL,
        # вухо — ОДИН зв'язний виступ: у мітці лежить ще й чубчик між вухами, і обгортка
        # обох шматків давала вухо 7 вокселів завширшки з діркою посередині
        "ear": _largest_blob(labels == L_EAR_R),
    }
    if not masks["ear"].any():
        masks["ear"] = _largest_blob(labels == L_EAR_L)
    sizes = {"body": part_size, "head": part_size, "leg": part_size,
             "ear": ear_size, "tail": tail_size}
    notes = {
        "body": "Тулуб. Ряди — від грудей (-Z) до хвоста (+Z).",
        "head": "Голова. Ряди — від морди (-Z) до потилиці (+Z).",
        "leg": "Лапка (передня ліва як шаблон для всіх чотирьох).",
        "ear": "Вухо; друге Hero3D дзеркалить (scale.x = -1).",
        "tail": "Хвіст: ряд 0 — передня грань біля шарніра, росте назад (+Z), кінчик t.",
    }
    subs = {}
    for kind, mask in masks.items():
        sub = cut_part(sym, mask)
        if sub is None:
            print(f"[!] частина '{kind}' порожня — у heroes.json лиши стару назву для неї")
            continue
        if opts.fit:
            sub = fit_part(sub, kind, sizes[kind])
        check_part(kind, sub, sizes[kind])
        subs[kind] = sub
    _emit(opts, subs, palette, sizes, notes, sym)
    return 0


def _emit(opts, subs: dict, palette: dict, sizes: dict, notes: dict, whole: np.ndarray,
          name_of=None, vox_palette: dict | None = None, vox_name: str = "") -> None:
    """name_of / vox_name — власні імена файлів (--exact); без них — старі правила з --hero і --suffix."""
    out_dir = ROOT / opts.out if not Path(opts.out).is_absolute() else Path(opts.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    names = {}
    for kind, sub in subs.items():
        if name_of is not None:
            name = name_of(kind)
        else:
            name = (f"hero_{kind}_{opts.hero}{opts.suffix}" if opts.parts == "hero"
                    else f"{opts.hero}{opts.suffix}")
        path = out_dir / f"{name}.json"
        d = to_def(sub, sizes.get(kind, opts.pitch), palette,
                   f"{notes.get(kind, '')} Згенеровано tools/voxelize.py з {Path(opts.model).name}.")
        path.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        nx, ny, nz = sub.shape
        s = sizes.get(kind, opts.pitch)
        print(f"[+] {path}  ({nx}×{ny}×{nz} × {s:.3f} м = "
              f"{nx * s:.3f} × {ny * s:.3f} × {nz * s:.3f} м)")
        names[kind] = name
    if opts.vox:
        vox_dir = ROOT / opts.vox if not Path(opts.vox).is_absolute() else Path(opts.vox)
        stem = vox_name or f"{opts.hero}{opts.suffix}"
        # у --exact .vox завжди зі СПРАВЖНІМИ кольорами, навіть коли в JSON пішли зони
        write_vox(vox_dir / f"{stem}.vox", whole, vox_palette or palette)
    if opts.parts == "hero" and names:
        block = {k: names.get(k, f"hero_{k}") for k in ("body", "head", "leg", "tail", "ear")}
        print("\nВстав у data/heroes.json у героя '%s':\n  \"parts\": %s"
              % (opts.hero, json.dumps(block, ensure_ascii=False)))


if __name__ == "__main__":
    raise SystemExit(main())
