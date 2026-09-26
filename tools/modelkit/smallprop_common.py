# -*- coding: utf-8 -*-
"""smallprop_common — спільні заготовки для дрібних «живих» пропсів за малюнком: квітів,
грибів, каменів (родини flower_common, mushroom_common, rock_common).

Навіщо окремо від kit.py: kit спільний для всіх агентів і його не чіпаємо, а ці пропси
стоять у кадрі десятками — їм потрібна своя, ощадна деталізація (DETAIL нижче) і кілька
заготовок, яких у kit нема: тіло обертання за профілем, трубка, крапля на поверхні, «наліпка»
по кривині (плями гриба, мох), однотонний і радіальний матеріали.

Усе лицем до −Y (фронт моделі), як у kit.
"""
import math

import bpy
import bmesh
from mathutils import Matrix, Vector

import kit

# Ощадна деталізація: high ~1-1,5 тис. вершин у Blender, mid ~0,5-0,8, low ~0,2-0,4.
# Ключі kit (bev, arch, …) — щоб його заготовки теж працювали; свої — seg (кроків по колу),
# ico (поділ ікосфери каменя: у Blender 2 = 80 граней, 3 = 320), petal (сегменти пелюстки).
DETAIL = {
    "high": dict(bev=2, arch=6, tor=(12, 5), sph=(10, 6), win=6, cyl=16, tube=1, seg=16, ico=3, petal=(6, 8), leaf=6, dec=1.0),
    "mid": dict(bev=1, arch=4, tor=(10, 4), sph=(8, 4), win=4, cyl=10, tube=1, seg=12, ico=3, petal=(6, 5), leaf=4, dec=0.5),
    "low": dict(bev=1, arch=3, tor=(8, 3), sph=(6, 3), win=3, cyl=6, tube=0, seg=8, ico=2, petal=(4, 4), leaf=3, dec=1.0),
}


def D(key):
    return kit.DET[key]


# ---------- матеріали ----------

def mat_flat(k, name, key, key_lo=None, z0=0.0, z1=1.0, jitter=0.1, scale=8.0):
    """Однотонний (або м'який перехід знизу вгору) матеріал з ключа палітри."""
    return k.mat_gradient(name, [(0.0, key_lo or key), (1.0, key)], z0, z1, jitter, scale)


def mat_radial(k, name, keys, n, center=(0.0, 0.0)):
    """Радіальні смуги навколо осі Z (пластинки під шапкою гриба): n смуг по колу,
    keys = (шов, основний, світлий)."""
    m = k._new_mat(name)
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    sx = nt.nodes.new("ShaderNodeMath")
    sx.operation = "SUBTRACT"
    nt.links.new(sep.outputs["X"], sx.inputs[0])
    sx.inputs[1].default_value = center[0]
    sy = nt.nodes.new("ShaderNodeMath")
    sy.operation = "SUBTRACT"
    nt.links.new(sep.outputs["Y"], sy.inputs[0])
    sy.inputs[1].default_value = center[1]
    at = nt.nodes.new("ShaderNodeMath")
    at.operation = "ARCTAN2"
    nt.links.new(sy.outputs["Value"], at.inputs[0])
    nt.links.new(sx.outputs["Value"], at.inputs[1])
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    nt.links.new(at.outputs["Value"], mul.inputs[0])
    mul.inputs[1].default_value = n
    sn = nt.nodes.new("ShaderNodeMath")
    sn.operation = "SINE"
    nt.links.new(mul.outputs["Value"], sn.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -1.0
    mr.inputs["From Max"].default_value = 1.0
    nt.links.new(sn.outputs["Value"], mr.inputs["Value"])
    r = k._ramp(nt, [(0.0, keys[0]), (0.35, keys[1]), (1.0, keys[2])])
    nt.links.new(mr.outputs["Result"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


# ---------- геометрія ----------

def finish_bm(bm, name, mat):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return kit.link(me, name, mat)


def lathe(name, mat, prof, seg, mod=None, rot0=0.0):
    """Тіло обертання навколо Z: prof — [(r, z), …] від верхньої точки до нижньої; точки з r=0
    стають полюсами. mod(i, a, r, z) -> (r, z) — хвиля кільця i під кутом a."""
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
    return finish_bm(bm, name, mat)


def tube(name, mat, pts, thick, res=None, taper=None):
    """Трубка по ламаній pts [(x, y, z), …] — стебло, усмішка. taper — [радіус-множник на
    кожну точку] (стебло тоншає догори)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = thick
    cu.bevel_resolution = D("tube") if res is None else res
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for i, (p, (x, y, z)) in enumerate(zip(sp.points, pts)):
        p.co = (x, y, z, 1.0)
        if taper:
            p.radius = taper[i]
    ob = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob


def blob(name, mat, c, r, scale=(1, 1, 1), seg=None):
    """Приплюснута крапля (очі, плями, мох-цятки): UV-сфера."""
    s, rings = seg or D("sph")
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=s, ring_count=rings, location=c)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    ob.data.materials.append(mat)
    return ob


def orient(ob, pos, normal, spin=0.0):
    """Поставити об'єкт (зібраний навколо початку, «вгору» = +Z) у точку pos, +Z — по нормалі."""
    bpy.context.view_layer.update()   # інакше matrix_world ще без щойно заданого ob.scale
    q = Vector(normal).to_track_quat("Z", "Y")
    ob.matrix_world = Matrix.Translation(pos) @ q.to_matrix().to_4x4() @ Matrix.Rotation(spin, 4, "Z") @ ob.matrix_world
    return ob


def ray_hit(target, origin, direction):
    """Точка й нормаль поверхні меша target (об'єкт стоїть у початку без повороту й масштабу
    або з будь-якою трансформацією — рахуємо через матрицю)."""
    bpy.context.view_layer.update()
    mw = target.matrix_world
    inv = mw.inverted()
    ok, loc, nor, _ = target.ray_cast(inv @ Vector(origin), (inv.to_3x3() @ Vector(direction)).normalized())
    if not ok:
        return None, None
    return mw @ loc, (mw.to_3x3().inverted().transposed() @ nor).normalized()


def decal_on(name, mat, target, pos, nor, radius, thick=0.004, seg=None, rings=2, dome=0.0,
             wobble=0.0, lobes=0, seed=0.0, spin=0.0, center=None):
    """«Наліпка» на поверхню target у точці pos з нормаллю nor: диск радіуса radius, кожну
    вершину якого променем покладено НА поверхню (плями гриба, мох на камені) — тож наліпка
    лежить по кривині будь-якої форми, не зависає краєм і не тоне. Верх піднятий на thick
    (+ dome·radius посередині), бортик іде під поверхню — зблизька видно товщину, а щілини нема.
    lobes / wobble — хвилястий край (мох-зірочка). Низу нема: зсередини шапки/каменя не видно.
    center — класти вершини променем ДО ЦЕНТРУ тіла, а не паралельно нормалі: велика наліпка на
    опуклій брилі (шапка моху) інакше краями «стікала» по боках вертикальною шторою."""
    seg = seg or max(6, D("seg") // 2)
    n = Vector(nor).normalized()
    q = n.to_track_quat("Z", "Y").to_matrix() @ Matrix.Rotation(spin, 3, "Z")
    bm = bmesh.new()
    pts = [((0.0, 0.0), thick + dome * radius)]
    for ri in range(1, rings + 1):
        f = ri / rings
        for sgi in range(seg):
            a = 2 * math.pi * sgi / seg
            rr = radius * f * ((1.0 + wobble * math.sin(a * lobes + seed)) if lobes else 1.0)
            pts.append(((rr * math.cos(a), rr * math.sin(a)), thick + dome * radius * (1 - f * f)))
    for sgi in range(seg):   # бортик — той самий край, трохи під поверхнею
        (x, y), _ = pts[1 + (rings - 1) * seg + sgi]
        pts.append(((x, y), -thick * 0.8))
    bpy.context.view_layer.update()
    for (x, y), off in pts:
        p = Vector(pos) + q @ Vector((x, y, 0.0))
        if center is not None:
            c = Vector(center)
            dirv = (p - c).normalized()
            hit, hn = ray_hit(target, c + dirv * radius * 20, -dirv)
        else:
            hit, hn = ray_hit(target, p + n * radius, -n)
        if hit is None:
            hit, hn = p, n
        bm.verts.new(hit + hn * off)
    bm.verts.ensure_lookup_table()
    V = bm.verts
    for sgi in range(seg):
        t = (sgi + 1) % seg
        bm.faces.new((V[0], V[1 + sgi], V[1 + t]))
        for ri in range(1, rings):
            o0, o1 = 1 + (ri - 1) * seg, 1 + ri * seg
            bm.faces.new((V[o0 + sgi], V[o1 + sgi], V[o1 + t], V[o0 + t]))
        oe, os_ = 1 + (rings - 1) * seg, 1 + rings * seg
        bm.faces.new((V[oe + sgi], V[os_ + sgi], V[os_ + t], V[oe + t]))
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    # нормалі — назовні (від поверхні): перевернути, якщо центральна грань дивиться всередину
    bm.faces.ensure_lookup_table()
    f0 = bm.faces[0]
    if f0.normal.dot(n) < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    return kit.link(me, name, mat)


def faceted(ob):
    """Грані окремо (вершини не спільні) — «низькополігональний» вигляд малюнка:
    join_all робить усе гладким, а з роз'єднаними гранями гладкість нічого не згладжує."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.split_edges(bm, edges=bm.edges[:])
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def apply_mods(ob):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    for md in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)


def curve_to_mesh(ob):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return bpy.context.active_object


def interp(prof, t):
    """Лінійна інтерполяція списку чисел prof на рівномірній сітці 0..1."""
    t = min(max(t, 0.0), 1.0) * (len(prof) - 1)
    i = min(int(t), len(prof) - 2)
    f = t - i
    return prof[i] * (1 - f) + prof[i + 1] * f
