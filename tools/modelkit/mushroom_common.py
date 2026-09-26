# -*- coding: utf-8 -*-
"""Родина грибів-мухоморів за малюнками mushroom_red_*.png: червона шапка-купол з білими
плямами, кремові пластинки під нею, товста кремова ніжка, що розширюється донизу.

Модель лише задає параметри P і палітру PAL (кольори — окремими ключами: шапка, плями,
пластинки, ніжка), тож перефарбувати гриб — змінити PAL, геометрія та сама.

Форма — ПРОФІЛЬ силуету, знятий з малюнка: півширина на 21 рівні зверху донизу в частках
висоти (prof), і номер рівня, з якого починається ніжка (stem_i). Шапка й ніжка — тіла
обертання за цим профілем.

Шапка — ОКРЕМА частина «cap» (об'єкти part_cap__…): kit відокремлює її після запікання й
ставить початок координат у точку PIVOT — верх ніжки / низ шапки. У сцені шапка «дихає»
(масштаб до 1,06 по колу й 1,03 по висоті навколо PIVOT). Щоб вона не відривалась і не
провалювалась: ніжка заходить у шапку на 0,07 висоти вище PIVOT, а внутрішній край пластинок —
ВСЕРЕДИНІ ніжки (0,9 її радіуса), тож і при 1,06 щілини нема (check_cap() це перевіряє числами).
"""
import math

import bpy

import kit
import smallprop_common as sp

DETAIL = sp.DETAIL


def materials(k, P):
    H = P["H"]
    return {
        "cap": k.mat_gradient("cap", [(0.0, "cap_lo"), (0.45, "cap"), (1.0, "cap_hi")],
                              H * 0.45, H, 0.18, 5.0),
        "spot": sp.mat_flat(k, "spot", "spot", "spot_lo", H * 0.4, H, 0.1),
        "gill": sp.mat_radial(k, "gill", ("gill_line", "gill", "gill_hi"), P.get("gills", 22)),
        "stem": k.mat_gradient("stem", [(0.0, "stem_lo"), (0.55, "stem"), (1.0, "stem_hi")],
                               0.0, H * 0.55, 0.15, 5.0),
    }


def geometry(P):
    """Числа форми: z рівнів, край шапки, точка обертання, радіус верху ніжки."""
    H, prof, si = P["H"], P["prof"], P["stem_i"]
    n = len(prof) - 1
    z = [H * (1 - i / n) for i in range(n + 1)]
    r = [p * H for p in prof]
    z_rim = H * (1 - (si - 0.5) / n)          # нижній край шапки — між останнім рівнем шапки й першим ніжки
    r_rim = r[si - 1] * P.get("rim_in", 0.96)
    r_stem = r[si] * 0.97
    z_piv = z_rim + H * P.get("gill_rise", 0.05)
    return dict(H=H, z=z, r=r, n=n, z_rim=z_rim, r_rim=r_rim, r_stem=r_stem, z_piv=z_piv)


def build(m, k, P):
    g = geometry(P)
    H, z, r, n, si = g["H"], g["z"], g["r"], g["n"], P["stem_i"]
    seg = sp.D("seg")

    # Ніжка — «body»: від верху (всередині шапки) донизу за профілем, денце пласке.
    ztop = g["z_piv"] + H * 0.07
    prof = [(0.0, ztop), (g["r_stem"] * 0.85, ztop), (g["r_stem"], g["z_piv"])]
    rows = range(si, n) if sp.D("seg") >= 16 else range(si, n, 2)   # mid/low — через рівень
    for i in rows:
        if z[i] < g["z_piv"] - 1e-6:
            prof.append((r[i] * 0.98, z[i]))
    rb = r[n - 1] * 0.98
    prof += [(rb * 0.9, H * 0.03), (rb * 0.72, H * 0.008), (rb * 0.4, 0.0), (0.0, 0.0)]   # кругле денце, як на малюнках
    stem = sp.lathe("body", m["stem"], prof, seg)

    # Шапка: верхівка → рівні шапки → заокруглений край → закривається всередину.
    step = 1 if seg >= 16 else 2
    cp = [(0.0, H)]
    for i in list(range(1, si - 1, step)) + [si - 1]:
        cp.append((r[i], z[i]))
    lip = P.get("lip", 0.035) * H
    cp += [(g["r_rim"], g["z_rim"] + lip * 0.3), (g["r_rim"] * 0.93, g["z_rim"] + lip),
           (0.0, g["z_piv"] + H * 0.02)]
    wav = P.get("wave", 0.0)

    def mod(i, a, rr, zz):   # легка хвиля краю шапки (ручна ліпка)
        if wav and i >= len(cp) - 4:
            return rr * (1 + wav * math.sin(3 * a + 0.7)), zz + wav * H * 0.4 * math.sin(3 * a + 0.7)
        return rr, zz
    segc = seg * 5 // 4    # на куполі кроки видно по краю силуету — трохи густіше
    cap = sp.lathe("part_cap__dome", m["cap"], cp, segc, mod)

    # Пластинки: кільце-конус від краю шапки до ніжки (внутрішній край — у ніжці).
    ro, ri_ = g["r_rim"] * 0.93, g["r_stem"] * 0.9
    zo = g["z_rim"] + lip * 0.8
    gp = [(ro, zo), (ri_, g["z_piv"]), (ri_, g["z_piv"] + H * 0.015), (ro * 0.97, zo + H * 0.012), (ro, zo)]
    sp.lathe("part_cap__gills", m["gill"], gp, segc)

    # Плями — «наліпки» по кривині шапки: (кут навколо, від фронту −Y; кут над горизонтом; розмір).
    cz = g["z_rim"] + (H - g["z_rim"]) * 0.2
    spots = P["spots"] if sp.D("seg") >= 12 else [s for s in P["spots"] if s[2] >= P.get("low_min", 0.07)]
    for j, (az, el, size) in enumerate(spots):
        a, e = math.radians(az), math.radians(el)
        d = (math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))
        origin = (d[0] * H * 3, d[1] * H * 3, cz + d[2] * H * 3)
        pos, nor = sp.ray_hit(cap, origin, (-d[0], -d[1], -d[2]))
        if pos is None:
            continue
        rs = size * H
        big = rs > 0.05 * H
        # Велика пляма — густіша (3 кільця): її хорди інакше перетинали ребра граней купола
        # й крізь білу пляму просвічували червоні трикутнички.
        sp.decal_on("part_cap__spot%d" % j, m["spot"], cap, pos, nor, rs, thick=0.005 * H,
                    seg=max(6, seg * 3 // 4) if big else max(6, seg // 2),
                    rings=3 if big and seg >= 12 else 2, dome=0.04)
    tilt = P.get("tilt", 0.0)   # шапка трохи набік (mushroom_red_2): поворот навколо PIVOT
    if tilt:
        from mathutils import Matrix
        rot = (Matrix.Translation((0, 0, g["z_piv"])) @ Matrix.Rotation(math.radians(tilt), 4, "Y")
               @ Matrix.Translation((0, 0, -g["z_piv"])))
        for ob in bpy.data.objects:
            if ob.name.startswith("part_cap__"):
                ob.matrix_world = rot @ ob.matrix_world
    return {"parts": {"cap": (0.0, 0.0, g["z_piv"])}}


def check_cap(P, scale=(1.06, 1.06, 1.03)):
    """Числами: при масштабі шапки навколо PIVOT ніжка не вилазить з-під неї і між ними немає
    щілини. Повертає (запас_угору, запас_по_радіусу) у частках висоти — обидва мають бути > 0."""
    g = geometry(P)
    H = g["H"]
    ztop = g["z_piv"] + H * 0.07
    # верх ніжки має лишатися під куполом: купол над віссю на висоті H·sz
    margins = []
    for s in (1.0, scale[2]):
        dome_top = g["z_piv"] + (H - g["z_piv"]) * s
        margins.append((dome_top - ztop) / H)
    rad = []
    for s in (1.0, scale[0]):
        rad.append((g["r_stem"] - g["r_stem"] * 0.9 * s) / H)
    return min(margins), min(rad)
