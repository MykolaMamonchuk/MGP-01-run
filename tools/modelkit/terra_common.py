# -*- coding: utf-8 -*-
"""Спільне для будиночків house_terra_* (моделі «за малюнком»): корпус зі щипцями на боках
(±X, гребінь уздовж X — фасад −Y під карнизом), двоматеріальні стіни (бік у тіні, як на
малюнку) і двоскатний дах плитами. Решта — kit.py."""
import math

import bmesh
import bpy

import kit


def two_mats(ob, side_mat, axis="x"):
    """Грані з нормаллю ±X (боки) — другим матеріалом: фасад світлий, бік — у тіні, як на
    малюнку (рендер-порівняння світить спереду зліва, тож тінь малюнка запечено в колір)."""
    ob.data.materials.append(side_mat)
    for p in ob.data.polygons:
        n = p.normal.x if axis == "x" else p.normal.y
        if abs(n) > 0.7:
            p.material_index = 1


def prism_x(name, mat, profile, x0, x1):
    """Призма: 2D-профіль у площині YZ, витягнутий уздовж X (щипці — на боках ±X)."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    a = [bm.verts.new((x0, y, z)) for y, z in profile]
    b = [bm.verts.new((x1, y, z)) for y, z in profile]
    n = len(profile)
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    return kit.link(me, name, mat)


def gable_roof_x(mat, W, D, H, PEAK, t, over_y, over_x, bev=0.03, name="roof"):
    """Двоскатний дах уздовж X: дві плити зі звисом over_y над фасадом/тилом і over_x над
    щипцями; спід плит — на лінії щипця."""
    hd = D * 0.5
    slope = math.atan2(PEAK - H, hd)
    run = math.hypot(hd, PEAK - H) + over_y
    out = []
    for side in (-1, 1):
        # центр плити — посередині між гребенем і (краєм стіни + звис)
        along = run * 0.5 - 0.01
        cy = side * math.cos(slope) * along
        cz = PEAK - math.sin(slope) * along + (t * 0.5) / math.cos(slope)
        r = kit.box("%s%d" % (name, side), mat, (0.0, cy, cz), (W + 2 * over_x, run, t), rot=(-side * slope, 0.0, 0.0))
        kit.soften(r, bev)
        out.append(r)
    return out


def mat_blocks(name, keys, brick_w=0.36, row_h=0.14, mortar=0.012):
    """Кладка блоками (цоколь): Brick-текстура на площині (x + y, z) — однаково лягає і на
    фасад, і на бік; ключі палітри — (шов, блок, блок_світлий)."""
    m = kit._new_mat(name)
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    nt.links.new(sep.outputs["X"], add.inputs[0])
    nt.links.new(sep.outputs["Y"], add.inputs[1])
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(add.outputs["Value"], comb.inputs["X"])
    nt.links.new(sep.outputs["Z"], comb.inputs["Y"])
    br = nt.nodes.new("ShaderNodeTexBrick")
    br.offset = 0.5
    br.inputs["Scale"].default_value = 1.0
    br.inputs["Brick Width"].default_value = brick_w
    br.inputs["Row Height"].default_value = row_h
    br.inputs["Mortar Size"].default_value = mortar
    br.inputs["Mortar Smooth"].default_value = 0.3
    br.inputs["Color1"].default_value = kit.rgb(kit.PAL[keys[1]])
    br.inputs["Color2"].default_value = kit.rgb(kit.PAL[keys[2]])
    br.inputs["Mortar"].default_value = kit.rgb(kit.PAL[keys[0]])
    nt.links.new(comb.outputs["Vector"], br.inputs["Vector"])
    nt.links.new(br.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


def shade_along(m, key, a, b, axis="X", start=0.0):
    """Затінити готовий матеріал уздовж осі: від a до b множник кольору плавно йде від 1 до
    кольору key (множення). Для даху terra 6: на малюнку правий край ската в тіні."""
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    link = bsdf.inputs["Base Color"].links[0]
    src = link.from_socket
    nt.links.remove(link)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = a
    mr.inputs["From Max"].default_value = b
    nt.links.new(sep.outputs[axis], mr.inputs["Value"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    nt.links.new(mr.outputs["Result"], mix.inputs["Factor"])
    nt.links.new(src, mix.inputs["A"])
    mix.inputs["B"].default_value = kit.rgb(kit.PAL[key])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    return m


def blob(name, mat, c, r):
    """Дешева кулька (ікосфера, 12 вершин) — для квітів у ящиках: UV-сфер по 60 вершин на
    кожну квітку з'їдали половину бюджету моделі."""
    import bpy
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=c)
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(mat)
    return ob
