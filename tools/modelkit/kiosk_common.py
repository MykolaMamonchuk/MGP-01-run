# -*- coding: utf-8 -*-
"""Спільне для родини кіосків (kiosk_1/2/3), придатне й для інших круглих будиночків.

Кут на стіні циліндра: 0 — перед (−Y), додатний — проти годинникової стрілки згори, тобто
праворуч, якщо дивитись спереду (так само, як у face_on). Камера заміру стоїть під кутом az
(refs/<модель>.json), тож деталь, яку на малюнку видно під кутом «s» від середини, має кут
s + az — див. cam_ang / cam_xy: розставляємо деталі так, як їх видно на малюнку.

  cam_ang, cam_xy — кут на стіні / точка підлоги деталі «як видно на малюнку» (з az камери);
  face_on     — поставити деталь, зібрану лицем до −Y, на стіну циліндра чи грань;
  shift       — зсунути зібрану деталь уздовж грані перед face_on;
  place       — вільно: поворот + зсув (вивіска, горщик, мольберт, димар);
  mat_stripes — смуги поперек грані під будь-яким кутом (маркіза): kit уміє лише осі;
  revolve     — тіло обертання за профілем (r, z) з модуляцією: пелюстки купола, фестони,
                гранчастий корпус (seg=6, phase); нормалі — за побудовою, без recalc;
  lobes       — функція пелюсток для revolve (подушечки між швами);
  ellipse_prof — профіль купола чвертю еліпса;
  plank_body  — корпус «body» (головний об'єкт для join_all), круглий чи гранчастий;
  stepped_cone — конусний дах «сходинками» зі спідницею-фестонами;
  finial      — маківка: фігурна шапочка + кулька або шпиль;
  pot_plant   — горщик із кущиком / листям.
"""
import math

import bmesh
import bpy
from mathutils import Matrix

import kit


# ---------- розстановка «як на малюнку» ----------

def cam_ang(az, screen_deg):
    """Кут на стіні (для face_on) деталі, яку на малюнку видно під screen_deg від середини."""
    return math.radians(screen_deg + az)


def cam_xy(az, sx, sf):
    """Точка підлоги: sx — праворуч на малюнку, sf — до глядача (м), у світові x, y."""
    a = math.radians(az)
    fx, fy = math.sin(a), -math.cos(a)      # до камери
    rx, ry = math.cos(a), math.sin(a)       # праворуч на кадрі
    return (sx * rx + sf * fx, sx * ry + sf * fy)


def face_on(obs, ang, r):
    """Деталі, зібрані лицем до −Y у (0,0,z), — на стіну циліндра радіуса r під кутом ang."""
    for ob in obs:
        ob.matrix_world = Matrix.Rotation(ang, 4, "Z") @ Matrix.Translation((0.0, -r, 0.0)) @ ob.matrix_world
    return obs


def shift(obs, dx=0.0, dy=0.0, dz=0.0):
    """Зсунути зібрані деталі (до face_on/place): уздовж грані — dx, від стіни — −dy."""
    for ob in obs:
        ob.matrix_world = Matrix.Translation((dx, dy, dz)) @ ob.matrix_world
    return obs


def place(obs, xy, ang):
    """Деталі, зібрані довкола (0,0), — повернути на ang і поставити в точку xy підлоги."""
    for ob in obs:
        ob.matrix_world = Matrix.Translation((xy[0], xy[1], 0.0)) @ Matrix.Rotation(ang, 4, "Z") @ ob.matrix_world
    return obs


# ---------- матеріали ----------

def mat_stripes(k, name, keys, period, ang):
    """Смуги вздовж горизонтального напрямку ang (кут грані, як у face_on): смуга — поперек
    грані, як на маркізі. period — ширина пари смуг, м. kit.mat_door уміє лише осі X/Y/Z,
    а грань шестигранника стоїть навскоси."""
    m = k._new_mat(name)
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Rotation"].default_value = (0.0, 0.0, -ang)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(mp.outputs["Vector"], sep.inputs["Vector"])
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = 1.0 / period
    nt.links.new(sep.outputs["X"], mul.inputs[0])
    fr = nt.nodes.new("ShaderNodeMath")
    fr.operation = "FRACT"
    nt.links.new(mul.outputs["Value"], fr.inputs[0])
    r = k._ramp(nt, [(0.0, keys[0]), (0.5, keys[1])])
    r.color_ramp.interpolation = "CONSTANT"
    nt.links.new(fr.outputs["Value"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


# ---------- тіла обертання ----------

def lobes(n, depth, power=0.5, phase=0.0):
    """Множник радіуса для n пелюсток: 1 посередині пелюстки, 1-depth на шві."""
    def f(phi):
        t = (n * phi / (2 * math.pi) + phase) % 1.0
        return 1.0 - depth * (1.0 - math.sin(math.pi * t) ** power)
    return f


def revolve(name, mat, prof, seg, rmod=None, zmod=None, cap_bottom=True, cap_top=True, phase=0.0):
    """Тіло обертання: prof — [(r, z), …] знизу вгору. rmod(phi, i) — множник радіуса,
    zmod(phi, i) — зсув висоти для точки i профілю. Кришки — віялом до осі. phase — поворот
    першої вершини кільця (для гранчастих: seg=6 — шестигранник вершиною під кутом phase)."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = []
    for i, (r, z) in enumerate(prof):
        if r < 1e-5:
            # вістря на осі — одна вершина, а не seg однакових
            v = bm.verts.new((0.0, 0.0, z + (zmod(0.0, i) if zmod else 0.0)))
            rings.append([v] * seg)
            continue
        ring = []
        for j in range(seg):
            phi = 2 * math.pi * j / seg + phase
            rr = r * (rmod(phi, i) if rmod else 1.0)
            zz = z + (zmod(phi, i) if zmod else 0.0)
            ring.append(bm.verts.new((rr * math.sin(phi), -rr * math.cos(phi), zz)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for j in range(seg):
            k = (j + 1) % seg
            q = []
            for v in (a[j], a[k], b[k], b[j]):
                if v not in q:
                    q.append(v)
            if len(q) >= 3:
                bm.faces.new(q)
    # Нормалі — за побудовою, без recalc (на відкритих мешах він вгадує навмання, а Godot
    # відсікає задні грані): назовні — ліворуч від напрямку профілю, тобто профіль, що йде
    # вгору, дивиться назовні, а той, що йде вниз, — досередини (спід даху).
    for ring, want, (r, z), top in ((rings[0], cap_bottom, prof[0], False), (rings[-1], cap_top, prof[-1], True)):
        if want and r > 1e-4:
            zc = sum(v.co.z for v in ring) / seg
            c = bm.verts.new((0.0, 0.0, zc))
            for j in range(seg):
                a, b = ring[j], ring[(j + 1) % seg]
                bm.faces.new((a, b, c) if top else (b, a, c))
    bm.to_mesh(me)
    bm.free()
    return kit.link(me, name, mat)


def ellipse_prof(r, h, z0, n, r_top=0.0):
    """Профіль купола: чверть еліпса від (r, z0) до (r_top, z0+h), n кроків."""
    out = []
    for i in range(n + 1):
        a = 0.5 * math.pi * i / n
        out.append((max(r_top, r * math.cos(a)), z0 + h * math.sin(a)))
    return out


def plank_body(mat, R, z0, H, seg, phase=0.0):
    """Корпус — «body» (головний об'єкт для join_all): відкритий циліндр (або гранчастий —
    seg=6 і phase), дошки — текстурою. Верх і низ відкриті: їх ховають дах і цоколь."""
    return revolve("body", mat, [(R, z0), (R, z0 + H * 0.5), (R, z0 + H)], seg,
                   cap_bottom=False, cap_top=False, phase=phase)


def stepped_cone(name, mat, r0, z0, r1, z1, steps, seg, lip=0.014, scallops=0, scallop_h=0.0, skirt_h=0.0,
                 bulge=True):
    """Конусний дах «сходинками»: steps кілець, кожне трохи нависає над нижчим (лусочка), знизу —
    опційна спідниця-фестони (scallops півкіл заввишки scallop_h, смуга заввишки skirt_h).
    r0/z0 — низ (край спідниці або першої сходинки), r1/z1 — пласка верхівка.
    bulge=False — без опуклої середини кільця (на третину менше вершин, для mid/low)."""
    prof = []
    zb = z0
    if skirt_h > 0:
        prof += [(r0 - 0.035, z0 + 0.012), (r0, z0), (r0 - 0.008, z0 + skirt_h * 0.5)]
        zb = z0 + skirt_h
        rb = r0 - 0.03
    else:
        rb = r0
        prof += [(rb - 0.03, z0 + 0.01), (rb, z0)]
    dr = (rb - r1) / steps
    dz = (z1 - zb) / steps
    for k in range(steps):
        ra, za = rb - k * dr, zb + k * dz
        if k > 0 or skirt_h > 0:
            prof += [(ra - lip, za + 0.004), (ra, za)]          # спід лусочки (нормаль донизу)
        if bulge:
            prof.append((ra - dr * 0.25, za + dz * 0.35))       # опукла середина кільця
    prof.append((r1, z1))
    zm = None
    if scallops and scallop_h > 0:
        f = lobes(scallops, 1.0, 0.5)
        zm = lambda phi, i: (1.0 - f(phi)) * scallop_h if i < 2 else 0.0   # вершини між фестонами — вище
    return revolve(name, mat, prof, seg, zmod=zm)


# ---------- дрібниці ----------

def finial(m_cap, m_ball, z, r, h, seg, n_lobes=0, lobe_depth=0.0, ball_r=0.035, spire=0.0, rings=4):
    """Маківка: фігурна шапочка-купол (з пелюстками чи гладка) і кулька або шпиль над нею."""
    prof = [(r * 0.55, z), (r, z + h * 0.18)] + ellipse_prof(r, h * 0.82, z + h * 0.18, rings)[1:]
    rm = (lambda phi, i, f=lobes(n_lobes, lobe_depth): f(phi)) if n_lobes else None
    obs = [revolve("finial_cap", m_cap, prof, seg, rmod=rm)]
    top = z + h
    if spire > 0:
        # шпиль: шийка, кулька, гострий кінчик (як на kiosk_2)
        sp = [(ball_r * 0.9, top - 0.01), (ball_r * 0.45, top + spire * 0.25),
              (ball_r, top + spire * 0.45), (ball_r * 0.8, top + spire * 0.6),
              (ball_r * 0.3, top + spire * 0.75), (0.0, top + spire)]
        obs.append(revolve("finial_spire", m_ball, sp, max(8, seg // 2)))
    else:
        obs.append(kit.cyl("finial_neck", m_ball, (0, 0, top + ball_r * 0.3), ball_r * 0.45, ball_r * 0.9,
                           verts=max(6, seg // 3)))
        obs.append(kit.sphere("finial_ball", m_ball, (0, 0, top + ball_r * 1.3), ball_r))
    return obs


def pot_plant(m_pot, m_leaf, r, h, seg, kind="bush", leaf_h=0.1, n_leaves=7):
    """Горщик (у (0,0), дно на z=0) і рослина: «bush» — кущик-копичка, «leaves» — віяло листя."""
    obs = [revolve("pot", m_pot, [(r * 0.75, 0.0), (r, h * 0.55), (r * 0.98, h), (r * 0.85, h)], seg)]
    if kind == "bush":
        prof = [(r * 0.9, h), (r * 0.95, h + leaf_h * 0.35)] + ellipse_prof(r * 0.95, leaf_h * 0.65, h + leaf_h * 0.35, 3)[1:]
        obs.append(revolve("pot_bush", m_leaf, prof, seg, rmod=lambda phi, i, f=lobes(7, 0.08): f(phi)))
    else:
        for i in range(n_leaves):
            a = 2 * math.pi * i / n_leaves
            tilt = 0.35 + 0.15 * (i % 2)
            lf = kit.box("pot_leaf", m_leaf, (0, 0, leaf_h * 0.5), (r * 0.32, 0.018, leaf_h))
            lf.matrix_world = (Matrix.Translation((0, 0, h * 0.8)) @ Matrix.Rotation(a, 4, "Z")
                               @ Matrix.Rotation(tilt, 4, "X") @ lf.matrix_world)
            obs.append(lf)
    return obs
