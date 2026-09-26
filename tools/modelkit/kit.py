# -*- coding: utf-8 -*-
"""modelkit — спільна частина для моделей «за малюнком» (Blender headless).

Кожна модель (tools/modelkit/<назва>.py) — це палітра PAL, словник DETAIL (або стандартний)
і функція build(m, kit), що збирає геометрію з заготовок нижче. Решту робить kit:
матеріали для запікання, об'єднання в один меш, запікання кольору × м'якого затінення (AO),
три розміри текстури й експорт. Див. tools/modelkit/build.py.

Перед будь-якої моделі — −Y у Blender, тобто +Z у Godot, як у решти хат.
"""
import math
import os

import bpy
import bmesh
from mathutils import Matrix, Vector

PAL = {}
DETAIL = {
    #        скіс   дуга  бублик    сфера   арка вікна  циліндр  переріз рамок (0 — квадрат)
    "high": dict(bev=3, arch=12, tor=(24, 8), sph=(10, 6), win=10, cyl=20, tube=3),
    "mid": dict(bev=2, arch=6, tor=(12, 5), sph=(8, 4), win=6, cyl=12, tube=1),
    "low": dict(bev=1, arch=4, tor=(8, 3), sph=(4, 3), win=3, cyl=6, tube=0),
}
DET = DETAIL["high"]
MODEL_NAME = "model"


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb(hexcode):
    h = hexcode.lstrip("#")
    return tuple(srgb_to_linear(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (1.0,)


# ---------- матеріали (процедурні, лише для запікання) ----------

def _new_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    return m


def _ramp(nt, stops):
    r = nt.nodes.new("ShaderNodeValToRGB")
    els = r.color_ramp.elements
    while len(els) < len(stops):
        els.new(0.5)
    for el, (pos, key) in zip(els, stops):
        el.position = pos
        el.color = rgb(PAL[key])
    return r


def _height(nt, z0, z1):
    """0..1 по висоті об'єкта між z0 і z1."""
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = z0
    mr.inputs["From Max"].default_value = z1
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    return mr.outputs["Result"], tc


def _jitter(nt, value_socket, tc, amount, scale):
    """Нерівність ліплення: висота трохи «гуляє» плямами — перехід не лінійка."""
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 2.0
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    sub = nt.nodes.new("ShaderNodeMath")
    sub.operation = "SUBTRACT"
    nt.links.new(noise.outputs["Fac"], sub.inputs[0])
    sub.inputs[1].default_value = 0.5
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    nt.links.new(sub.outputs["Value"], mul.inputs[0])
    mul.inputs[1].default_value = amount
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    nt.links.new(value_socket, add.inputs[0])
    nt.links.new(mul.outputs["Value"], add.inputs[1])
    return add.outputs["Value"]


def mat_gradient(name, stops, z0, z1, jitter=0.25, scale=6.0):
    m = _new_mat(name)
    nt = m.node_tree
    h, tc = _height(nt, z0, z1)
    r = _ramp(nt, stops)
    nt.links.new(_jitter(nt, h, tc, jitter, scale), r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


def mat_roof(name, keys=("roof_edge", "roof", "roof_hi", "roof_line"), rows_scale=9.0, seams=16.0, direction="Z"):
    """Черепиця: ряди вздовж схилу; кожен ряд світлий угорі й темніший до нижнього краю
    (так «лусочки» читаються об'ємом), між лусочками — тонкий шов."""
    m = _new_mat(name)
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    rows = nt.nodes.new("ShaderNodeTexWave")
    rows.wave_type = "BANDS"
    rows.bands_direction = direction
    rows.wave_profile = "SAW"
    rows.inputs["Scale"].default_value = rows_scale
    rows.inputs["Distortion"].default_value = 0.5
    nt.links.new(tc.outputs["Object"], rows.inputs["Vector"])
    shade = _ramp(nt, [(0.0, keys[0]), (0.55, keys[1]), (1.0, keys[2])])
    nt.links.new(rows.outputs["Fac"], shade.inputs["Fac"])
    if seams <= 0:
        # Без окремих лусочок — лише ряди (гладкі «подушки», як у hut_2).
        nt.links.new(shade.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
        return m
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = seams
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    seam = nt.nodes.new("ShaderNodeMapRange")
    seam.inputs["From Min"].default_value = 0.0
    seam.inputs["From Max"].default_value = 0.05
    nt.links.new(vor.outputs["Distance"], seam.inputs["Value"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["B"].default_value = rgb(PAL[keys[3]])
    nt.links.new(shade.outputs["Color"], mix.inputs["A"])
    inv = nt.nodes.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    nt.links.new(seam.outputs["Result"], inv.inputs[1])
    nt.links.new(inv.outputs["Value"], mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


def mat_door(name, keys=("door_line", "door", "door_hi"), planks=5.5, direction="X"):
    """Дошки: кожна світліша посередині й темніша до шва; зверху трохи світліше."""
    m = _new_mat(name)
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = direction
    wave.inputs["Scale"].default_value = planks
    wave.inputs["Distortion"].default_value = 0.4
    nt.links.new(tc.outputs["Object"], wave.inputs["Vector"])
    r = _ramp(nt, [(0.04, keys[0]), (0.18, keys[1]), (0.6, keys[2])])
    nt.links.new(wave.outputs["Fac"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


def mat_glass(name, keys=("glass", "glass_hi")):
    """Скло блакитне, з косим білим відблиском: темне скло малюнка в грі читалось діркою."""
    m = _new_mat(name)
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "DIAGONAL"
    wave.inputs["Scale"].default_value = 6.0
    nt.links.new(tc.outputs["Object"], wave.inputs["Vector"])
    r = _ramp(nt, [(0.78, keys[0]), (0.86, keys[1])])
    nt.links.new(wave.outputs["Fac"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


# ---------- геометрія ----------

def link(me, name, mat):
    ob = bpy.data.objects.new(name, me)
    me.materials.append(mat)
    bpy.context.collection.objects.link(ob)
    return ob


def soften(ob, width=0.02, segments=None):
    """Пластилін: скошені, заокруглені краї. У найпростішому варіанті дрібні деталі без
    скосу: на відстані, де він стоїть, заокруглення в 1-2 см не видно."""
    if DET["bev"] <= 1 and width < 0.03:
        return
    bv = ob.modifiers.new("bevel", "BEVEL")
    bv.width = width
    bv.segments = segments if segments is not None else DET["bev"]
    bv.limit_method = "ANGLE"


def prism(name, mat, profile, y0, y1):
    """Призма: 2D-профіль у площині XZ, витягнутий від y0 до y1. Нормалі — назовні."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    front = [bm.verts.new((x, y0, z)) for x, z in profile]
    back = [bm.verts.new((x, y1, z)) for x, z in profile]
    n = len(profile)
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    return link(me, name, mat)


def box(name, mat, c, size, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=c, rotation=rot)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(mat)
    return ob


def cyl(name, mat, c, r, depth, rot=(0, 0, 0), verts=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts or DET["cyl"], radius=r, depth=depth,
                                        location=c, rotation=rot)
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(mat)
    return ob


def sphere(name, mat, c, r, scale=(1, 1, 1)):
    s, rings = DET["sph"]
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=s, ring_count=rings, location=c)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    ob.data.materials.append(mat)
    return ob


def arch_profile(w, h_side, steps):
    """Прямокутник + півколо зверху: профіль арки шириною w, бічні стінки h_side."""
    r = w * 0.5
    prof = [(-r, 0.0), (r, 0.0)]
    for i in range(0, steps + 1):
        a = math.pi * i / steps
        prof.append((r * math.cos(a), h_side + r * math.sin(a)))
    return prof


def arch_curve(name, mat, w, h_side, y, thick, z0=0.0):
    """Арочна рамка: П-подібний шлях (бік — дуга — бік) з круглим перерізом."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = thick
    cu.bevel_resolution = DET["tube"]
    cu.resolution_u = 2
    sp = cu.splines.new("POLY")
    r = w * 0.5
    steps = DET["arch"]
    pts = [(-r, z0), (-r, z0 + h_side)]
    for i in range(1, steps):
        a = math.pi - math.pi * i / steps
        pts.append((r * math.cos(a), z0 + h_side + r * math.sin(a)))
    pts += [(r, z0 + h_side), (r, z0)]
    sp.points.add(len(pts) - 1)
    for p, (x, z) in zip(sp.points, pts):
        p.co = (x, y, z, 1.0)
    ob = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob


FRAME_T = 0.024   # товщина (радіус) рамки вікна


def window(name, m, base, facing, w=0.2, h_side=0.16):
    """Арочне вікно лицем до −Y у початку координат, повернуте на свою стіну.
    Скло — ДО СЕРЕДИНИ рамки (замовник 26.09: «синє скло трішки менше за саме вікно»)."""
    made = []
    made.append(prism(name + "_glass", m["glass"], arch_profile(w, h_side, DET["win"]), 0.002, 0.014))
    made.append(arch_curve(name + "_frame", m["frame"], w, h_side, -0.006, FRAME_T))
    r = w * 0.5
    made.append(box(name + "_v", m["frame"], (0.0, -0.01, (h_side + r) * 0.5), (0.022, 0.02, h_side + r)))
    # Горизонтальна планка на 3 мм попереду вертикальної: коли їхні лиця в одній площині,
    # перетин запікався чорним квадратиком посередині хрестовини (рецензія 26.09).
    made.append(box(name + "_h", m["frame"], (0.0, -0.013, h_side * 0.8), (w, 0.02, 0.022)))
    sill = box(name + "_sill", m["frame"], (0.0, -0.035, -0.02), (w + 0.09, 0.07, 0.035))
    soften(sill, 0.012, min(2, DET["bev"]))
    made.append(sill)
    rot = {"-y": 0.0, "+x": math.pi / 2, "-x": -math.pi / 2, "+y": math.pi}[facing]
    for ob in made:
        ob.matrix_world = Matrix.Translation(base) @ Matrix.Rotation(rot, 4, "Z") @ ob.matrix_world
    return made


def join_all():
    bpy.ops.object.select_all(action="DESELECT")
    for ob in list(bpy.data.objects):
        if ob.type == "CURVE":
            bpy.context.view_layer.objects.active = ob
            ob.select_set(True)
            bpy.ops.object.convert(target="MESH")
            ob.select_set(False)
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            bpy.context.view_layer.objects.active = ob
            for md in list(ob.modifiers):
                bpy.ops.object.modifier_apply(modifier=md.name)
    # Рухомі частини (крила млина тощо) звуться «part_<назва>__…»: їхні вершини йдуть у групу
    # <назва>, щоб після спільного запікання відокремити частину назад (separate_parts).
    for ob in bpy.data.objects:
        if ob.type == "MESH" and ob.name.startswith("part_"):
            g = ob.name[5:].split("__")[0]
            vg = ob.vertex_groups.new(name=g)
            vg.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            ob.select_set(True)
    # Головний об'єкт — «body» (стоїть у початку координат без повороту), а не перший за
    # абеткою: рецензія 26.09 знайшла, що ним ставало back_win_frame — повернутий на 180° і
    # зсунутий, і вся модель у .glb стояла задом наперед, а переходи кольору по висоті з'їхали.
    mains = [o for o in bpy.data.objects if o.type == "MESH" and not o.name.startswith("part_")]
    if not mains:
        raise RuntimeError("модель без головного меша: усі об'єкти — рухомі частини")
    bpy.context.view_layer.objects.active = next((o for o in mains if o.name == "body"), mains[0])
    bpy.ops.object.join()
    hut = bpy.context.active_object
    # І незалежно від того, хто головний, — трансформацію в геометрію: об'єкт стоїть у
    # (0,0,0) без повороту, тож «Object»-координати матеріалів = світові.
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    hut.name = MODEL_NAME
    for p in hut.data.polygons:
        p.use_smooth = True
    return hut


def bake(hut, size):
    """Колір і затінення (AO) — два запікання, а в текстуру йде колір × м'яке затінення."""
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 32
    sc.render.bake.margin = 6
    # Світ — рівне світле тло, щоб AO рахувався від неба, а не від чорноти.
    w = bpy.data.worlds.new("bake")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    imgs = {}
    for kind in ("color", "ao"):
        img = bpy.data.images.new(MODEL_NAME + "_" + kind, size, size)
        for mat in hut.data.materials:
            nt = mat.node_tree
            node = nt.nodes.get("bake_target") or nt.nodes.new("ShaderNodeTexImage")
            node.name = "bake_target"
            node.image = img
            nt.nodes.active = node
        bpy.ops.object.select_all(action="DESELECT")
        hut.select_set(True)
        bpy.context.view_layer.objects.active = hut
        if kind == "color":
            sc.render.bake.use_pass_direct = False
            sc.render.bake.use_pass_indirect = False
            sc.render.bake.use_pass_color = True
            bpy.ops.object.bake(type="DIFFUSE")
        else:
            bpy.ops.object.bake(type="AO")
        imgs[kind] = img
    # колір × (0,78 + 0,22 · AO): затінення в кутках і під звисом, але не чорнота — гра
    # кладе ще й своє світло, і сильніше затінення робило хатинку брунатною
    import numpy as np
    n = size * size * 4
    col = np.empty(n, dtype=np.float32)
    ao = np.empty(n, dtype=np.float32)
    imgs["color"].pixels.foreach_get(col)
    imgs["ao"].pixels.foreach_get(ao)
    col = col.reshape(-1, 4)
    k = 0.78 + 0.22 * ao.reshape(-1, 4)[:, :1]
    col[:, :3] *= k
    col[:, 3] = 1.0
    final = bpy.data.images.new(MODEL_NAME + "_tex", size, size)
    final.pixels.foreach_set(col.ravel())
    return final




def separate_parts(obj, parts):
    """Відокремити рухомі частини (після запікання — текстура в них та сама) і поставити
    початок координат у точку обертання: {назва: (x, y, z)}. Повертає {назва: об'єкт}."""
    out = {}
    for name, pivot in parts.items():
        vg = obj.vertex_groups.get(name)
        if vg is None:
            raise RuntimeError("рухома частина «%s»: немає об'єктів part_%s__… — опечатка в назві?" % (name, name))
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="DESELECT")
        obj.vertex_groups.active_index = vg.index
        bpy.ops.object.vertex_group_select()
        bpy.ops.mesh.separate(type="SELECTED")
        bpy.ops.object.mode_set(mode="OBJECT")
        part = [o for o in bpy.context.selected_objects if o != obj][0]
        part.name = name
        bpy.context.scene.cursor.location = Vector(pivot)
        bpy.ops.object.select_all(action="DESELECT")
        part.select_set(True)
        bpy.context.view_layer.objects.active = part
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        out[name] = part
    for o in [obj] + list(out.values()):
        for vg in list(o.vertex_groups):
            o.vertex_groups.remove(vg)
    return out


def add_rig(obj, bones):
    """Скелет для гойдання (дерево на вітрі): bones — [(назва, голова, хвіст, батько)].
    Ваги — автоматичні (теплові), як робить художник кнопкою «With Automatic Weights»."""
    arm_data = bpy.data.armatures.new("rig")
    arm = bpy.data.objects.new("rig", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    for name, head, tail, parent in bones:
        b = arm_data.edit_bones.new(name)
        b.head = head
        b.tail = tail
        if parent:
            b.parent = made[parent]
            b.use_connect = True
        made[name] = b
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    return arm


def finish(obj, img, out_dir, base, tex_size, parts=None, rig=None):
    """Спільний кінець: один матеріал із запеченою текстурою, рухомі частини, скелет, три
    розміри текстури окремими файлами (для сцени порівняння) і .glb."""
    import numpy as np
    if tex_size not in (256, 512, 1024, 2048):
        raise RuntimeError("розмір текстури %d: лише 256/512/1024/2048 (менші рахуються усередненням)" % tex_size)
    out_mat = bpy.data.materials.new(base + "_baked")
    out_mat.use_nodes = True
    b = out_mat.node_tree.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.9
    tex = out_mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    out_mat.node_tree.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    obj.data.materials.clear()
    obj.data.materials.append(out_mat)
    made = separate_parts(obj, parts or {})
    if rig:
        add_rig(obj, rig)
    os.makedirs(out_dir, exist_ok=True)
    # Менші текстури — усередненням пікселів (як mipmap), а не копією зображення: копія
    # згенерованого в Blender зображення приходить порожньою.
    full = np.empty(tex_size * tex_size * 4, dtype=np.float32)
    img.pixels.foreach_get(full)
    full = full.reshape(tex_size, tex_size, 4)
    for size in (1024, 512, 256):
        if size > tex_size:
            continue   # більшого за запечений не буває
        f = tex_size // size
        arr = full.reshape(size, f, size, f, 4).mean(axis=(1, 3)) if f > 1 else full
        im = bpy.data.images.new("%s_%d" % (base, size), size, size)
        im.pixels.foreach_set(arr.astype(np.float32).ravel())
        im.filepath_raw = os.path.join(out_dir, "%s_%d.jpg" % (base, size))
        im.file_format = "JPEG"
        im.save()
    img.pack()
    out = os.path.join(out_dir, base + ".glb")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="JPEG",
                              export_jpeg_quality=90, export_skins=True, export_animations=False)
    print("OUT", out, os.path.getsize(out), "частини:", list(made.keys()), "скелет:", bool(rig))
    return out
