#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""make_hut.py — зібрати «пластиліновий» будиночок за малюнком (Blender headless).

Навіщо. Замовник дав малюнок (docs/refs/incoming/hut/hut_test_draw.jpg) і спитав, чи можна
з картинки зробити будинок із текстурами. Згенерована нейромережею модель — це мільйон
трикутників і «суп» граней, який не спрощується; а будиночок із малюнка — річ регулярна:
корпус із щипцем, крутий дах зі звисом, димар, кругле вікно, арочні двері. Це чесно
будується геометрією, а «пластилін» дають скошені краї, згладжування й запечена текстура
(черепиця, дошки, легка нерівність ліплення).

    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/make_hut.py -- \\
        --out assets/props/_exp/hut/hut_test.glb --tex 1024

Кольори зняті з малюнка піпеткою. Перед будинку — −Y у Blender, тобто +Z у Godot: так само,
як у решти хат (фасадом до дороги після повороту маркера).

Результат — ОДИН меш з ОДНИМ матеріалом і запеченою текстурою кольору: так його малює
MultiMesh декору, як і запечені house_terra.
"""
import argparse
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

PAL = {
    "wall": "#F2D7A8",
    "roof": "#F8E4B0",
    "roof_line": "#E4BD85",
    "chimney": "#EDD0A0",
    "cap": "#B65E3E",
    "door": "#8F472E",
    "door_line": "#6E3320",
    "frame": "#A85538",
    "glass": "#7FB6D3",
    "glass_hi": "#D8F0FA",
    "step": "#B4B0B0",
    "stone": "#8F7B7C",
    "lantern": "#C4854D",
}


def parse_args(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/props/_exp/hut/hut_test.glb")
    ap.add_argument("--tex", type=int, default=1024)
    ap.add_argument("--blend", default="")
    return ap.parse_args(argv)


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb(hexcode):
    h = hexcode.lstrip("#")
    return tuple(srgb_to_linear(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (1.0,)


# ---------- матеріали для запікання (процедурні) ----------

def mat_flat(name, key):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = rgb(PAL[key])
    b.inputs["Roughness"].default_value = 0.9
    return m


def _mix_noise(m, base_key, amount, scale):
    """Легка «ліпна» нерівність: колір трохи гуляє плямами, як пальцями по пластиліну."""
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 2.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    c = rgb(PAL[base_key])
    dark = tuple(max(0.0, v * (1.0 - amount)) for v in c[:3]) + (1.0,)
    ramp.color_ramp.elements[0].color = dark
    ramp.color_ramp.elements[1].color = c
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[1].position = 0.65
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    return ramp


def mat_clay(name, key, amount=0.06, scale=6.0):
    m = mat_flat(name, key)
    ramp = _mix_noise(m, key, amount, scale)
    m.node_tree.links.new(ramp.outputs["Color"], m.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    return m


def mat_roof(name):
    """Черепиця «лусочками»: ряди вздовж схилу (хвиля по V) + зсунуті дуги (Вороний по U)."""
    m = mat_flat(name, "roof")
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "Z"
    wave.inputs["Scale"].default_value = 9.0
    wave.inputs["Distortion"].default_value = 0.6
    nt.links.new(tc.outputs["Object"], wave.inputs["Vector"])
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = 16.0
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    mx = nt.nodes.new("ShaderNodeMath")
    mx.operation = "MINIMUM"
    nt.links.new(wave.outputs["Fac"], mx.inputs[0])
    nt.links.new(vor.outputs["Distance"], mx.inputs[1])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = rgb(PAL["roof_line"])
    ramp.color_ramp.elements[1].color = rgb(PAL["roof"])
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[1].position = 0.05
    nt.links.new(mx.outputs["Value"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    return m


def mat_door(name):
    """Дошки дверей: темні вертикальні шви."""
    m = mat_flat(name, "door")
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "X"
    wave.inputs["Scale"].default_value = 5.5
    wave.inputs["Distortion"].default_value = 0.4
    nt.links.new(tc.outputs["Object"], wave.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = rgb(PAL["door_line"])
    ramp.color_ramp.elements[1].color = rgb(PAL["door"])
    ramp.color_ramp.elements[0].position = 0.05
    ramp.color_ramp.elements[1].position = 0.16
    nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    return m


def mat_glass(name):
    """Скло, яке читається як скло: блакитне, світліше вгорі, з косим білим відблиском.
    Темно-брунатне скло з малюнка в грі виглядало діркою або ґудзиком (замовник 26.09)."""
    m = mat_flat(name, "glass")
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "DIAGONAL"
    wave.inputs["Scale"].default_value = 6.0
    nt.links.new(tc.outputs["Object"], wave.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = rgb(PAL["glass"])
    ramp.color_ramp.elements[1].color = rgb(PAL["glass_hi"])
    ramp.color_ramp.elements[0].position = 0.78
    ramp.color_ramp.elements[1].position = 0.86
    nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    return m


# ---------- геометрія ----------

def link(me, name, mat, smooth=True):
    ob = bpy.data.objects.new(name, me)
    me.materials.append(mat)
    bpy.context.collection.objects.link(ob)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    return ob


def soften(ob, width=0.02, segments=2, subsurf=0):
    """Пластилін: скошені, заокруглені краї; за потреби — ще й згладжування."""
    bv = ob.modifiers.new("bevel", "BEVEL")
    bv.width = width
    bv.segments = segments
    bv.limit_method = "ANGLE"
    if subsurf:
        ss = ob.modifiers.new("subsurf", "SUBSURF")
        ss.levels = subsurf
        ss.render_levels = subsurf


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


def cyl(name, mat, c, r, depth, rot=(0, 0, 0), verts=20):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=c, rotation=rot)
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(mat)
    return ob


def arch_curve(name, mat, w, h_side, y, thick, depth, z0=0.0):
    """Арочна рамка: П-подібний шлях (бік — дуга — бік) з круглим перерізом."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = thick
    cu.bevel_resolution = 3
    cu.resolution_u = 6
    sp = cu.splines.new("POLY")
    r = w * 0.5
    pts = [(-r, z0), (-r, z0 + h_side)]
    for i in range(1, 12):
        a = math.pi - math.pi * i / 12.0
        pts.append((r * math.cos(a), z0 + h_side + r * math.sin(a)))
    pts += [(r, z0 + h_side), (r, z0)]
    sp.points.add(len(pts) - 1)
    for p, (x, z) in zip(sp.points, pts):
        p.co = (x, y, z, 1.0)
    ob = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob


def window(name, m, base, facing, w=0.2, h_side=0.16):
    """Арочне вікно, збудоване лицем до −Y у початку координат і повернуте на свою стіну.
    base — середина низу вікна на площині стіни."""
    made = []
    r = w * 0.5
    prof = [(-r, 0.0), (r, 0.0)]
    for i in range(0, 11):
        ang = math.pi * i / 10.0
        prof.append((r * math.cos(ang), h_side + r * math.sin(ang)))
    made.append(prism(name + "_glass", m["glass"], [(x * 0.9, z * 0.95 + 0.005) for x, z in prof], 0.004, 0.016))
    made.append(arch_curve(name + "_frame", m["frame"], w, h_side, -0.006, 0.024, 0.0))
    made.append(box(name + "_v", m["frame"], (0.0, -0.01, (h_side + r) * 0.5), (0.022, 0.02, h_side + r)))
    made.append(box(name + "_h", m["frame"], (0.0, -0.01, h_side * 0.8), (w, 0.02, 0.022)))
    sill = box(name + "_sill", m["frame"], (0.0, -0.035, -0.02), (w + 0.09, 0.07, 0.035))
    soften(sill, 0.012, 2)
    made.append(sill)
    rot = {"-y": 0.0, "+x": math.pi / 2, "-x": -math.pi / 2, "+y": math.pi}[facing]
    for ob in made:
        # Повернути навколо початку координат і перенести на стіну — однаково для всіх частин.
        mw = ob.matrix_world.copy()
        ob.matrix_world = (__import__("mathutils").Matrix.Translation(base)
                           @ __import__("mathutils").Matrix.Rotation(rot, 4, "Z") @ mw)
    return made


def main():
    a = parse_args(sys.argv)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    m = {
        "wall": mat_clay("wall", "wall", 0.07, 5.0),
        "roof": mat_roof("roof"),
        "chimney": mat_clay("chimney", "chimney", 0.07, 7.0),
        "cap": mat_clay("cap", "cap", 0.08, 9.0),
        "door": mat_door("door"),
        "frame": mat_clay("frame", "frame", 0.08, 9.0),
        "glass": mat_glass("glass"),
        "step": mat_clay("step", "step", 0.1, 8.0),
        "stone": mat_clay("stone", "stone", 0.12, 10.0),
        "lantern": mat_clay("lantern", "lantern", 0.08, 9.0),
    }

    W, D = 1.0, 0.95          # корпус: ширина (X) і глибина (Y)
    H = 0.78                  # висота стіни до карниза
    PEAK = 1.42               # гребінь щипця
    hw, hd = W * 0.5, D * 0.5
    # Корпус із щипцем, трохи ширший унизу — «ліплений», а не з лінійки.
    prof = [(-hw - 0.03, 0.0), (hw + 0.03, 0.0), (hw, H), (0.0, PEAK), (-hw, H)]
    body = prism("body", m["wall"], prof, -hd, hd)
    soften(body, 0.035, 3)

    # Дах: два товсті скати зі звисом, круті (як на малюнку, ~58°).
    slope = math.atan2(PEAK - H, hw)
    run = math.hypot(hw, PEAK - H) + 0.2
    for side in (-1, 1):
        cx = side * (hw * 0.5 + 0.05)
        cz = (H + PEAK) * 0.5 + 0.06
        # Знак: поворот навколо Y на −θ піднімає кінець +X. Лівий скат (side −1) має
        # підніматися до гребеня, тобто до +X, — отже кут side·θ.
        r = box("roof%d" % side, m["roof"], (cx, 0.0, cz), (run, D + 0.26, 0.09),
                rot=(0.0, side * slope, 0.0))
        soften(r, 0.03, 3)
    # Гребінь — заокруглений валик, щоб скати не сходились гострим кутом.
    # Гребеня-циліндра нема: скати перекриваються на вершині самі, а в циліндра торці
    # запікались чорним (крихітні острівці розгортки).

    # Димар ліворуч, ближче до фасаду (як на малюнку), крізь скат; шапка — брунатний «гриб».
    ch = box("chimney", m["chimney"], (-0.33, -0.08, 1.18), (0.2, 0.2, 0.62))
    soften(ch, 0.04, 3)
    cap = cyl("cap", m["cap"], (-0.33, -0.08, 1.52), 0.15, 0.07, verts=18)
    soften(cap, 0.02, 2)
    cap2 = cyl("cap2", m["cap"], (-0.33, -0.08, 1.58), 0.09, 0.07, verts=16)
    soften(cap2, 0.02, 2)

    fy = -hd - 0.012          # передня площина стіни (−Y — фасад)

    # Кругле вікно в щипці: рамка-бублик, темне скло, хрест.
    bpy.ops.mesh.primitive_torus_add(major_radius=0.12, minor_radius=0.035, major_segments=24,
                                     minor_segments=8, location=(0.0, fy, 1.0), rotation=(math.pi / 2, 0, 0))
    ring = bpy.context.active_object
    ring.name = "win_ring"
    ring.data.materials.append(m["frame"])
    # Скло трохи втоплене за рамку, хрестовина — перед склом і товща: так вікно має глибину.
    cyl("win_glass", m["glass"], (0.0, fy + 0.012, 1.0), 0.1, 0.012, rot=(math.pi / 2, 0, 0), verts=20)
    box("win_v", m["frame"], (0.0, fy - 0.008, 1.0), (0.026, 0.024, 0.2))
    box("win_h", m["frame"], (0.0, fy - 0.008, 1.0), (0.2, 0.024, 0.026))

    # Віддушина під гребенем: коротка брунатна планка з поличкою.
    box("vent", m["frame"], (0.0, fy, 1.27), (0.025, 0.03, 0.12))
    box("vent_b", m["frame"], (0.0, fy - 0.01, 1.2), (0.07, 0.04, 0.025))

    # Арочні двері: дошки (профіль — прямокутник + півколо) і товста рамка.
    dw, dh = 0.34, 0.36
    door_prof = [(-dw / 2, 0.0), (dw / 2, 0.0)]
    for i in range(0, 13):
        ang = math.pi * i / 12.0
        door_prof.append((dw / 2 * math.cos(ang), dh + dw / 2 * math.sin(ang)))
    door_prof = [door_prof[0], door_prof[1]] + door_prof[2:]
    door = prism("door", m["door"], door_prof, fy - 0.02, fy + 0.02)
    soften(door, 0.012, 2)
    arch_curve("door_frame", m["frame"], dw + 0.05, dh, fy - 0.015, 0.035, 0.0)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.025, segments=10, ring_count=6, location=(0.1, fy - 0.035, 0.26))
    bpy.context.active_object.data.materials.append(m["frame"])

    # Поріг — сірий заокруглений брусок перед дверима.
    st = box("step", m["step"], (0.0, fy - 0.08, 0.04), (0.46, 0.16, 0.08))
    soften(st, 0.035, 3)

    # Ліхтарик ліворуч від дверей, камінь, втоплений у стіну, і віконце-віконниця праворуч.
    ln = box("lantern", m["lantern"], (-0.34, fy - 0.03, 0.47), (0.07, 0.06, 0.1))
    soften(ln, 0.012, 2)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.07, segments=10, ring_count=6, location=(-0.36, fy + 0.005, 0.22))
    stone = bpy.context.active_object
    stone.scale = (0.9, 0.35, 1.2)
    stone.data.materials.append(m["stone"])
    # Вікна по боках і ззаду (замовник 26.09: «має бути по боках»): арочні, з рамкою,
    # хрестовиною, втопленим склом і підвіконням.
    for sx in (-1, 1):
        for wy in (-0.2, 0.22):
            window("side_win", m, (sx * (hw + 0.02), wy, 0.3), "+x" if sx > 0 else "-x")
    window("back_win", m, (0.0, hd + 0.012, 0.3), "+y")
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.05, segments=10, ring_count=6, location=(0.34, fy + 0.005, 0.44))
    peb = bpy.context.active_object
    peb.scale = (0.7, 0.3, 1.0)
    peb.data.materials.append(m["stone"])

    # ---------- зібрати в один меш ----------
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
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            ob.select_set(True)
    bpy.context.view_layer.objects.active = [o for o in bpy.data.objects if o.name == "body"][0]
    bpy.ops.object.join()
    hut = bpy.context.active_object
    hut.name = "hut"
    for p in hut.data.polygons:
        p.use_smooth = True
    hut.data.calc_loop_triangles()
    print("трикутників:", len(hut.data.loop_triangles))

    # ---------- розгортка й запікання кольору в одну текстуру ----------
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    img = bpy.data.images.new("hut_color", a.tex, a.tex)
    for mat in hut.data.materials:
        nt = mat.node_tree
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        nt.nodes.active = node
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 16
    sc.render.bake.use_pass_direct = False
    sc.render.bake.use_pass_indirect = False
    sc.render.bake.use_pass_color = True
    sc.render.bake.margin = 6
    bpy.ops.object.select_all(action="DESELECT")
    hut.select_set(True)
    bpy.context.view_layer.objects.active = hut
    bpy.ops.object.bake(type="DIFFUSE")

    # Один матеріал із запеченою текстурою замість десяти процедурних.
    out_mat = bpy.data.materials.new("hut_baked")
    out_mat.use_nodes = True
    b = out_mat.node_tree.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.9
    tex = out_mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    out_mat.node_tree.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    hut.data.materials.clear()
    hut.data.materials.append(out_mat)

    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    # Текстуру окремим файлом не пишемо: експортер вшиває її в .glb (JPEG), а Godot при
    # імпорті сам кладе її поруч.
    img.pack()
    if a.blend:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(a.blend))
    bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", export_image_format="JPEG",
                              export_jpeg_quality=90)
    print("OUT", a.out, os.path.getsize(a.out))


main()
