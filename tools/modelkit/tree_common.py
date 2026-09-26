# -*- coding: utf-8 -*-
"""tree_common — одна параметрична «родина» дерев за малюнками (pine_3_N, tree_round_N,
wall_tree_tall_N). Модель лише задає параметри (яруси, крона-кулі, стовбур) і палітру; решта —
тут. Заготовки kit.py не чіпаємо (спільні), беремо з нього матеріали й DETAIL.

Кольори — лише з PAL: хвоя/листя й кора — окремі матеріали й окремі острови розгортки, тож
перефарбування (осінь, сніг, інший відтінок) — це новий модуль з іншою PAL:

    from pine_3_4 import *          # tools/modelkit/pine_3_4_autumn.py
    PAL = dict(PAL, leaf="#D98A3A", …)

«Грані» низькополігонального малюнка — не розрізані вершини (дорого: ×3 вершин і рвані ваги
скелета), а намальовані в текстурі: колір залежить від справжньої нормалі грані (True Normal)
до умовного світла зліва-згори-спереду. Геометрія гладка, спільні вершини.

Скелет: ланцюжок кісток уздовж осі (стовбур → яруси/крона), ваги — автоматичні (kit.add_rig).

Фронт — у −Y (як у kit).
"""
import math

import bpy
import bmesh
from mathutils import Matrix, Vector, noise

import kit

H_DEFAULT = 2.2
LIGHT = Vector((-0.45, -0.55, 0.7)).normalized()   # умовне світло малюнків: зліва-спереду-згори

def lathe(name, mat, prof, seg, mod=None, rot0=0.0):
    """Тіло обертання навколо Z: prof — [(r, z), …] від верхньої точки до нижньої; перша й
    остання точки з r=0 стають полюсами. mod(i, a, r, z) -> (r, z) — зміна кільця i (індекс у
    prof) під кутом a: так робимо фестони краю ярусу чи хвилясту шапку."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rows = []
    for i, (r, z) in enumerate(prof):
        if r <= 1e-6:
            rows.append(bm.verts.new((0.0, 0.0, z)))
            continue
        row = []
        for s in range(seg):
            a = rot0 + 2 * math.pi * s / seg
            rr, zz = mod(i, a, r, z) if mod else (r, z)
            row.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), zz)))
        rows.append(row)
    for i in range(len(rows) - 1):
        A, B = rows[i], rows[i + 1]
        for s in range(seg):
            t = (s + 1) % seg
            if isinstance(A, list) and isinstance(B, list):
                bm.faces.new((A[s], B[s], B[t], A[t]))
            elif isinstance(B, list):
                bm.faces.new((A, B[s], B[t]))
            elif isinstance(A, list):
                bm.faces.new((A[s], B, A[t]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    return kit.link(me, name, mat)


def faceted(ob):
    """Видимі грані без розрізання меша: усі ребра — «гострі» (sharp). Вершини лишаються
    спільними (автоматичні ваги скелета рахуються — з розрізаним мешем теплові ваги не
    знаходять розв'язку, рецензія 26.09 на pine_3_4), а нормалі при експорті діляться по
    гострих ребрах — у Godot грань пласка. Ціна — вершини: ×~3 на цьому меші."""
    for e in ob.data.edges:
        e.use_edge_sharp = True
    return ob


def lobe_wave(a, n, style):
    """Хвиля краю ярусу 0..1 під кутом a, n лопатей по колу.
    round — круглі фестони (лусочки), leaf — листки з гострим кінчиком, point — зубці,
    flat — рівний край."""
    x = (a * n / (2 * math.pi)) % 1.0          # 0..1 у межах однієї лопаті
    if style == "round":
        return math.sin(math.pi * x)            # горб, між горбами — вузький виріз
    if style == "leaf":
        return (1.0 - abs(2.0 * x - 1.0)) ** 0.6   # листок: опуклі боки, гострий кінчик
    if style == "point":
        return 1.0 - abs(2.0 * x - 1.0) ** 0.7  # гострий кінчик посередині лопаті
    return 0.0


def tier(name, mat, z_rim, z_apex, r_rim, seg, rings=4, power=1.0, lobes=0, style="round",
         drop=0.05, bulge=0.04, thick=0.05, rot0=0.0, shoulder=None, rows=(), row_lip=0.03, ridge=0.0):
    """Ярус сосни: конус від верхівки до краю (power > 1 — увігнутий схил, як у ялинки),
    край — лопатями (lobes штук, стиль lobe_wave: опускаються на drop і виступають на bulge),
    товщина краю thick, спід — пологий конус угору до стовбура.
    shoulder=(частка висоти, частка радіуса) — злам схилу (плечі низькополігональної ялинки).
    rows — частки висоти, де на схилі ще один ряд лусочок (невеликий уступ із фестонами).
    ridge — лопаті продовжуються вгору по схилу «пальцями» (частка радіуса біля краю)."""
    def rad(f):
        if shoulder:
            fz, fr = shoulder
            return r_rim * (fr * (f / fz) if f <= fz else fr + (1 - fr) * (f - fz) / (1 - fz))
        return r_rim * f ** power

    def zf(f):
        return z_apex - (z_apex - z_rim) * f
    fs = sorted(set([i / rings for i in range(1, rings + 1)]) | set(rows))
    prof = [(0.0, z_apex)]
    lips = set()
    fr = {}
    for f in fs:
        fr[len(prof)] = f
        prof.append((rad(f), zf(f)))
        if f in rows and f < 1.0:
            lips.add(len(prof))
            prof.append((rad(f) + row_lip, zf(f) - row_lip * 0.5))
            prof.append((rad(f) + row_lip * 0.2, zf(f) - row_lip * 1.2))
    rim_i = len(prof) - 1
    prof.append((r_rim * 0.97, z_rim - thick))
    prof.append((r_rim * 0.35, z_rim + thick * 1.2))
    prof.append((0.0, z_rim + thick * 2.0))

    def mod(i, a, r, z):
        if not lobes:
            return r, z
        w = lobe_wave(a - rot0, lobes, style)
        if i in (rim_i, rim_i + 1):
            return r * (1.0 + bulge * w), z - drop * w
        if i in lips:
            w2 = lobe_wave(a - rot0 + math.pi / lobes, lobes, style)
            return r + row_lip * 0.6 * w2, z - row_lip * 0.8 * w2
        if ridge and i in fr:
            return r * (1.0 + ridge * w * fr[i] ** 1.5), z
        if i == rim_i - 1 and i - 1 not in lips:
            return r * (1.0 + bulge * 0.3 * w), z - drop * 0.3 * w
        return r, z
    return lathe(name, mat, prof, seg, mod, rot0)


# ---------- деталізація ----------

DETAIL = {   # kit.DETAIL + своє: lobe — сегментів на лопать краю, rings — кілець схилу ярусу,
             # trunk — граней стовбура, ico — поділ кулі крони (1 — 20 граней, 2 — 80, 3 — 320), trunk_rings — кілець стовбура
    "high": dict(kit.DETAIL["high"], lobe=4, rings=4, trunk=10, ico=3, trunk_rings=5),
    "mid": dict(kit.DETAIL["mid"], lobe=3, rings=3, trunk=8, ico=2, trunk_rings=3),
    "low": dict(kit.DETAIL["low"], lobe=2, rings=2, trunk=6, ico=1, trunk_rings=2),
}


# ---------- матеріали ----------

def _math(nt, op, a, b):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    for i, v in enumerate((a, b)):
        if isinstance(v, (int, float)):
            n.inputs[i].default_value = v
        else:
            nt.links.new(v, n.inputs[i])
    return n.outputs["Value"]


def mat_facet(name, stops, z0, z1, facet=0.45, jitter=0.15, scale=5.0):
    """Колір за висотою (z0..z1) плюс «грань»: справжня нормаль грані до умовного світла
    LIGHT. fac = (1 − facet)·висота + facet·освітленість грані → рампа stops з PAL."""
    m = kit._new_mat(name)
    nt = m.node_tree
    h, tc = kit._height(nt, z0, z1)
    h = kit._jitter(nt, h, tc, jitter, scale)
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    dot = nt.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    nt.links.new(geo.outputs["True Normal"], dot.inputs[0])
    dot.inputs[1].default_value = tuple(LIGHT)
    lit = _math(nt, "MULTIPLY_ADD", dot.outputs["Value"], 0.5)
    lit.node.inputs[2].default_value = 0.5
    fac = _math(nt, "ADD", _math(nt, "MULTIPLY", h, 1.0 - facet), _math(nt, "MULTIPLY", lit, facet))
    r = kit._ramp(nt, stops)
    nt.links.new(fac, r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


LEAF_STOPS = [(0.0, "leaf_dark"), (0.3, "leaf_lo"), (0.62, "leaf"), (1.0, "leaf_hi")]
BARK_STOPS = [(0.0, "bark_lo"), (0.5, "bark"), (1.0, "bark_hi")]


def materials(k, P):
    H = P.get("H", H_DEFAULT)
    tr = P["trunk"]
    m = {"bark": mat_facet("bark", BARK_STOPS, 0.0, tr["top"] * H, P.get("bark_facet", 0.5), 0.1, 4.0)}
    for i, t in enumerate(P.get("tiers", [])):
        # кожен ярус окремо: темніший край — світліша верхівка
        m["leaf%d" % i] = mat_facet("leaf%d" % i, P.get("leaf_stops", LEAF_STOPS),
                                    t["rim"] * H - 0.06, t["apex"] * H, P.get("facet", 0.4))
    if P.get("balls"):
        zs = [b[2] - b[3] for b in P["balls"]] + [b[2] + b[3] for b in P["balls"]]
        m["crown"] = mat_facet("crown", P.get("leaf_stops", LEAF_STOPS), min(zs) * H, max(zs) * H,
                               P.get("facet", 0.5), 0.12, 3.0)
    return m


# ---------- геометрія ----------

def trunk(name, mat, k, H, top, r0, r1, flare=0.0, roots=0, root_amp=0.0, sides=None, sink=0.0):
    """Стовбур-тіло обертання (частки висоти H): від r0 унизу до r1 на висоті top, з
    розширенням комля flare і коренями roots (горби внизу по колу)."""
    sides = sides or k.DET["trunk"]
    n = k.DET["trunk_rings"]
    zt = top * H
    prof = [(0.0, zt), (r1 * H, zt)]
    zs = [zt * (1 - (i / n) ** 0.6) for i in range(1, n + 1)]   # густіше внизу — там комель
    for z in zs:
        f = 1 - z / zt
        r = (r1 + (r0 - r1) * f + flare * math.exp(-z / (0.05 * H) if H else 0)) * H
        prof.append((r, z))
    prof.append((0.0, 0.0))

    def mod(i, a, r, z):
        if roots and 1 < i < len(prof) - 1:
            w = lobe_wave(a, roots, "round")
            return r * (1.0 + root_amp * w * math.exp(-z / (0.06 * H))), z
        return r, z
    ob = lathe(name, mat, prof, sides, mod, rot0=0.2)
    if sink:
        ob.location.z -= sink * H
    return ob


def ball(name, mat, k, c, r, seed=0, amp=0.08, squash=1.0):
    """Куля крони: ікосфера, трохи «горбата» шумом (не ідеальна куля — ліплена)."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=k.DET["ico"], radius=1.0, location=(0, 0, 0))
    ob = bpy.context.active_object
    ob.name = name
    off = Vector((seed * 7.31, seed * 3.17, seed * 5.53))
    for v in ob.data.vertices:
        p = v.co.normalized()
        d = 1.0 + amp * noise.noise(p * 1.7 + off)
        v.co = Vector((p.x * r * d, p.y * r * d, p.z * r * d * squash))
    ob.location = c
    ob.data.materials.append(mat)
    return ob


def union(obs):
    """Кулі крони — в ОДИН суцільний меш (булеве об'єднання): окремі кулі збоку від осі
    автоматичні ваги не «бачать» — у mid/low частина вершин лишалась без ваг і експорт додавав
    neutral_bone (перевірка 26.09). Зайві внутрішні грані теж зникають."""
    first = obs[0]
    for o in obs[1:]:
        md = first.modifiers.new("u_" + o.name, "BOOLEAN")
        md.operation = "UNION"
        md.solver = "EXACT"
        md.object = o
    bpy.context.view_layer.objects.active = first
    for md in list(first.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    for o in obs[1:]:
        bpy.data.objects.remove(o, do_unlink=True)
    return first


def build_tree(m, k, P):
    """Зібрати дерево з параметрів P (усе — частки висоти H):
      trunk: {top, r0, r1, flare, roots, root_amp, facets}
      tiers: [{rim, apex, r, power, lobes, style, drop, bulge, thick, rows, row_lip, shoulder, sides,
              facets, lobe_seg, ridge, dx, dy, tilt}]
      balls: [(x, y, z, r, seed)] — крона з куль
      bones: [z, …] — межі кісток знизу вгору (перша 0, остання — верх дерева)."""
    H = P.get("H", H_DEFAULT)
    d = k.DET
    tr = P["trunk"]
    body = trunk("body", m["bark"], k, H, tr["top"], tr["r0"], tr["r1"], tr.get("flare", 0.0),
                 tr.get("roots", 0), tr.get("root_amp", 0.0))
    if tr.get("facets"):
        faceted(body)
    for i, t in enumerate(P.get("tiers", [])):
        lobes = t.get("lobes", 0)
        if t.get("sides"):
            seg = t["sides"]
        else:
            # lobe_seg=2 — рівно зубець/виріз: дрібна бахрома без зайвих вершин
            seg = max(d["cyl"], lobes * t.get("lobe_seg", d["lobe"]))
        rows = t.get("rows", ()) if d["bev"] >= 2 else ()
        ob = tier("tier%d" % i, m["leaf%d" % i], t["rim"] * H, t["apex"] * H, t["r"] * H, seg,
             rings=t.get("rings", d["rings"]), power=t.get("power", 1.0), lobes=lobes,
             style=t.get("style", "round"), drop=t.get("drop", 0.05) * H, bulge=t.get("bulge", 0.04),
             thick=t.get("thick", 0.022) * H, rot0=t.get("rot", 0.37 * i), shoulder=t.get("shoulder"),
             rows=rows, row_lip=t.get("row_lip", 0.012) * H, ridge=t.get("ridge", 0.0))
        if t.get("tilt"):
            # нахил ярусу навколо осі Y через центр його краю (права лапа нижче за ліву)
            zc = t["rim"] * H
            ob.matrix_world = (Matrix.Translation((0, 0, zc)) @ Matrix.Rotation(t["tilt"], 4, "Y")
                               @ Matrix.Translation((0, 0, -zc)) @ ob.matrix_world)
        if t.get("dx") or t.get("dy"):
            ob.location.x += t.get("dx", 0.0) * H   # несиметричне дерево: ярус трохи вбік
            ob.location.y += t.get("dy", 0.0) * H
        if t.get("facets"):
            faceted(ob)   # справжні грані: лише для малих ярусів (вершин ×~4)
    balls = []
    for i, b in enumerate(P.get("balls", [])):
        x, y, z, r = b[:4]
        balls.append(ball("ball%d" % i, m["crown"], k, (x * H, y * H, z * H), r * H, seed=b[4] if len(b) > 4 else i,
                          amp=P.get("ball_amp", 0.08), squash=P.get("ball_squash", 1.0)))
    if len(balls) > 1:
        union(balls)
    return {"rig": rig(P["bones"], H, P.get("bone_names"))}


def rig(zs, H, names=None):
    """Ланцюжок кісток уздовж осі Z: [(назва, голова, хвіст, батько), …] для kit.add_rig."""
    names = names or (["trunk"] + ["crown%d" % i for i in range(len(zs) - 2)])
    out = []
    for i in range(len(zs) - 1):
        out.append((names[i], (0, 0, zs[i] * H), (0, 0, zs[i + 1] * H), names[i - 1] if i else None))
    return out
