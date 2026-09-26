# -*- coding: utf-8 -*-
"""Спільне для родини яток awning_stall_* (моделі «за малюнком»): смугастий тент із
фестонами, стовпи, колода-балка з кілочками, прилавок (камінь або дошки) зі стільницею,
ящики, кошики, ліхтарик, овочі-фрукти. Кожна ятка (awning_stall_N.py) — палітра й розклад
цих заготовок за своїм малюнком. Фасад (покупець) — у −Y. Решта — kit.py."""
import math

import bpy
from mathutils import Matrix

import kit
from kit import arch_profile, box, cyl, prism, soften, sphere


def bev2():
    return min(2, kit.DET["bev"])


def flat(k, name, key, key2=None, z0=0.0, z1=1.0):
    """Рівний колір (або легкий перехід по висоті) — для дрібниць."""
    return k.mat_gradient(name, [(0.0, key), (1.0, key2 or key)], z0, z1, 0.05 if key2 else 0.0, 8.0)


def blob(name, mat, c, r, scale=(1, 1, 1), sub=None):
    """Кулька-ікосфера: 12 вершин (low/mid) або 42 (high) — овочі й квіти; UV-сфера на кожну
    дрібницю з'їдала б бюджет."""
    # дрібнота (яблучка, лимони) — завжди 12 вершин: гладкість на 5-сантиметровій кульці не видно
    s = sub if sub is not None else (2 if kit.DET["bev"] >= 3 and r >= 0.075 else 1)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=s, radius=r, location=c)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    ob.data.materials.append(mat)
    return ob


def slab(name, mat, x0, x1, p0, p1, t):
    """Плита між двома точками (y, z) перерізу, від x0 до x1, товщина t (верх — на лінії)."""
    (y0, z0), (y1, z1) = p0, p1
    ln = math.hypot(y1 - y0, z1 - z0)
    ang = math.atan2(z1 - z0, y1 - y0)
    ny, nz = -math.sin(ang), math.cos(ang)       # нормаль угору від лінії
    cy = (y0 + y1) * 0.5 - ny * t * 0.5
    cz = (z0 + z1) * 0.5 - nz * t * 0.5
    return box(name, mat, ((x0 + x1) * 0.5, cy, cz), (x1 - x0, ln, t), rot=(ang, 0.0, 0.0))


def awning(m_a, m_b, x0, x1, path, n, t=0.04, scallop=True, first_b=False, drop=None, bev=0.012):
    """Смугастий тент: n смуг від x0 до x1, переріз — ламана path [(y, z), …] від балки до
    переднього краю (дві-три ланки дають «пузо»). Смуги чергуються m_a / m_b; спереду під
    кожною смугою — фестон-півколо того ж кольору (drop — його глибина, за замовчуванням
    половина ширини смуги)."""
    w = (x1 - x0) / n
    made = []
    for i in range(n):
        mat = (m_b if (i % 2 == 0) == first_b else m_a)
        xa, xb = x0 + i * w, x0 + (i + 1) * w
        for j in range(len(path) - 1):
            s = slab("awn%d_%d" % (i, j), mat, xa, xb, path[j], path[j + 1], t)
            soften(s, bev, bev2())
            made.append(s)
        if scallop:
            (ya, za), (yb, zb) = path[-2], path[-1]
            r = w * 0.5
            dz = drop if drop is not None else r
            prof = [(r * math.cos(math.pi + math.pi * q / kit.DET["arch"]), -dz * math.sin(math.pi * q / kit.DET["arch"]))
                    for q in range(kit.DET["arch"] + 1)]
            prof = [(x + (xa + xb) * 0.5, z + zb + 0.005) for x, z in prof]
            sc = prism("scal%d" % i, mat, prof, yb - t * 0.5, yb + t * 0.5)
            made.append(sc)
    return made


def side_flap(mat, x, path, depth, t=0.03, name="flap", lean=0.0):
    """Бічний клапан тенту: смуга вздовж краю тенту від балки до переднього краю, що звисає
    на depth униз (тонка призма біля площини YZ на x). lean — на скільки низ клапана
    відхилений назовні по X (скат убік, як на awning_stall_2)."""
    import bmesh
    top = list(path)
    n = max(len(path) - 1, 1)
    bot = [(y, z - depth * (i / n) - 0.02) for i, (y, z) in enumerate(path)]
    prof = [(y, z, 0.0) for y, z in top] + [(y, z, lean * (i / n)) for i, (y, z) in reversed(list(enumerate(bot)))]
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    a = [bm.verts.new((x + dx - t * 0.5, y, z)) for y, z, dx in prof]
    b = [bm.verts.new((x + dx + t * 0.5, y, z)) for y, z, dx in prof]
    nn = len(prof)
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    for i in range(nn):
        j = (i + 1) % nn
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    return kit.link(me, name, mat)


def post(name, mat, x, y, z0, z1, s=0.1, bev=0.02):
    p = box(name, mat, (x, y, (z0 + z1) * 0.5), (s, s, z1 - z0))
    soften(p, bev, bev2())
    return p


def log_beam(name, mat, x0, x1, y, z, r, mat_end=None):
    """Колода-балка вздовж X із заокругленими торцями."""
    b = cyl(name, mat, ((x0 + x1) * 0.5, y, z), r, x1 - x0, rot=(0, math.pi / 2, 0), verts=max(8, kit.DET["cyl"] // 2 + 2))
    soften(b, min(0.02, r * 0.4), bev2())
    return b


def peg(name, mat, x, y, z, r, h):
    """Кілочок — торець стовпа над балкою (на малюнках стирчить угору)."""
    p = cyl(name, mat, (x, y, z + h * 0.5), r, h, verts=max(8, kit.DET["cyl"] // 2))
    soften(p, min(0.015, r * 0.3), bev2())
    return p


def brace(name, mat, x, y0, z0, y1, z1, s=0.05, axis="y"):
    """Підкіс між двома точками в площині YZ (axis="y") або XZ (axis="x")."""
    if axis == "y":
        ln = math.hypot(y1 - y0, z1 - z0)
        ang = math.atan2(z1 - z0, y1 - y0)
        return box(name, mat, (x, (y0 + y1) * 0.5, (z0 + z1) * 0.5), (s, ln, s), rot=(ang, 0, 0))
    ln = math.hypot(y1 - y0, z1 - z0)
    ang = math.atan2(z1 - z0, y1 - y0)
    return box(name, mat, ((y0 + y1) * 0.5, x, (z0 + z1) * 0.5), (ln, s, s), rot=(0, -ang, 0))


def crate(name, mat, c, size, fill=None, inner=None, slats=True):
    """Ящик із дощок: стінки + (якщо fill) шар овочів-кульок зверху. c — центр дна."""
    x, y, z = c
    sx, sy, sz = size
    made = []
    b = box(name, mat, (x, y, z + sz * 0.5), (sx, sy, sz))
    soften(b, 0.01, bev2())
    made.append(b)
    if inner is not None:
        made.append(box(name + "_in", inner, (x, y, z + sz - 0.004), (sx - 0.03, sy - 0.03, 0.01)))
    if slats:
        for dz in (0.25, 0.75):
            made.append(box(name + "_sl%.2f" % dz, mat, (x, y, z + sz * dz), (sx + 0.012, sy + 0.012, 0.018)))
    if fill:
        mats, r, n = fill
        i = 0
        cols = max(1, int(round(sx / (2 * r))))
        rows = max(1, int(round(sy / (2 * r))))
        for a in range(cols):
            for bb in range(rows):
                px = x - sx * 0.5 + (a + 0.5) * sx / cols
                py = y - sy * 0.5 + (bb + 0.5) * sy / rows
                made.append(blob(name + "_f%d" % i, mats[i % len(mats)], (px, py, z + sz + r * 0.35), r))
                i += 1
                if i >= n:
                    return made
    return made


def basket(name, mat, c, r, h, fill=None, band=None):
    """Круглий кошик-відерце: злегка розширений догори циліндр, обідок; кульки зверху."""
    x, y, z = c
    bpy.ops.mesh.primitive_cone_add(vertices=max(10, kit.DET["cyl"]), radius1=r * 0.85, radius2=r, depth=h,
                                    location=(x, y, z + h * 0.5))
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(mat)
    soften(ob, 0.012, bev2())
    made = [ob]
    if band is not None:
        made.append(cyl(name + "_band", band, (x, y, z + h * 0.35), r * 0.94, 0.03, verts=max(10, kit.DET["cyl"])))
    if fill:
        mats, rr, n = fill
        for i in range(n):
            a = 2 * math.pi * i / max(n - 1, 1)
            d = 0 if i == n - 1 else r * 0.5
            made.append(blob(name + "_f%d" % i, mats[i % len(mats)], (x + d * math.cos(a), y + d * math.sin(a), z + h + rr * 0.2), rr))
    return made


def lantern(name, m_frame, m_glass, m_cap, c, s=1.0, hook=True):
    """Ліхтарик: кришка-конус, скляний корпус у рамці, денце; кільце-гачок угорі.
    c — точка підвісу (верх гачка)."""
    x, y, z = c
    made = []
    hz = z - 0.03 * s
    if hook:
        ts, tr = kit.DET["tor"]
        bpy.ops.mesh.primitive_torus_add(major_radius=0.02 * s, minor_radius=0.005 * s + 0.002, major_segments=max(8, ts // 2),
                                         minor_segments=max(3, tr // 2), location=(x, y, hz), rotation=(math.pi / 2, 0, 0))
        ob = bpy.context.active_object
        ob.name = name + "_hook"
        ob.data.materials.append(m_frame)
        made.append(ob)
    top = hz - 0.02 * s
    bpy.ops.mesh.primitive_cone_add(vertices=max(8, kit.DET["cyl"] // 2), radius1=0.07 * s, radius2=0.025 * s, depth=0.05 * s,
                                    location=(x, y, top - 0.025 * s))
    ob = bpy.context.active_object
    ob.name = name + "_cap"
    ob.data.materials.append(m_cap)
    made.append(ob)
    made.append(cyl(name + "_rim", m_frame, (x, y, top - 0.055 * s), 0.06 * s, 0.02 * s, verts=max(8, kit.DET["cyl"] // 2)))
    made.append(cyl(name + "_glass", m_glass, (x, y, top - 0.12 * s), 0.045 * s, 0.11 * s, verts=max(8, kit.DET["cyl"] // 2)))
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        made.append(box(name + "_bar%d" % i, m_frame, (x + 0.047 * s * math.cos(a), y + 0.047 * s * math.sin(a), top - 0.12 * s),
                        (0.014 * s, 0.014 * s, 0.11 * s)))
    made.append(cyl(name + "_base", m_frame, (x, y, top - 0.185 * s), 0.058 * s, 0.03 * s, verts=max(8, kit.DET["cyl"] // 2)))
    return made


def place(obs, base, rot_z=0.0):
    """Перенести набір деталей, зібраних навколо (0,0,0), у base з поворотом навколо Z."""
    for ob in obs:
        ob.matrix_world = Matrix.Translation(base) @ Matrix.Rotation(rot_z, 4, "Z") @ ob.matrix_world
    return obs


def mat_stones(k, name, keys, scale=5.0):
    """Кладка з неправильного каменю: Вороной — плями-камені двох відтінків, шви темні."""
    m = k._new_mat(name)
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = scale
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    edge = nt.nodes.new("ShaderNodeTexVoronoi")
    edge.feature = "DISTANCE_TO_EDGE"
    edge.inputs["Scale"].default_value = scale
    nt.links.new(tc.outputs["Object"], edge.inputs["Vector"])
    tone = nt.nodes.new("ShaderNodeValToRGB")
    els = tone.color_ramp.elements
    els[0].position, els[0].color = 0.0, kit.rgb(kit.PAL[keys[1]])
    els[1].position, els[1].color = 1.0, kit.rgb(kit.PAL[keys[2]])
    nt.links.new(vor.outputs["Color"], tone.inputs["Fac"])
    seam = nt.nodes.new("ShaderNodeMapRange")
    seam.inputs["From Min"].default_value = 0.0
    seam.inputs["From Max"].default_value = 0.06
    nt.links.new(edge.outputs["Distance"], seam.inputs["Value"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = kit.rgb(kit.PAL[keys[0]])
    nt.links.new(seam.outputs["Result"], mix.inputs["Factor"])
    nt.links.new(tone.outputs["Color"], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


def tri_panel(name, mat, a, b, c, t=0.03):
    """Тонка трикутна панель (бічний скат тенту-«вальми»): вершини a, b, c — точки (x, y, z),
    товщина t по нормалі."""
    import bmesh
    from mathutils import Vector
    va, vb, vc = Vector(a), Vector(b), Vector(c)
    n = (vb - va).cross(vc - va).normalized() * (t * 0.5)
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    top = [bm.verts.new(v + n) for v in (va, vb, vc)]
    bot = [bm.verts.new(v - n) for v in (va, vb, vc)]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(3):
        j = (i + 1) % 3
        bm.faces.new((top[i], top[j], bot[j], bot[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    return kit.link(me, name, mat)
